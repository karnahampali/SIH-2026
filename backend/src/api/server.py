"""FastAPI REST + WebSocket API for DocuNet."""

import cv2
import numpy as np
import io
import os
import uuid
import base64
import time
import hashlib
import re
import asyncio
import importlib
import math
from typing import Optional, List
from pathlib import Path

from fastapi import FastAPI, File, UploadFile, WebSocket, WebSocketDisconnect, HTTPException, Request, Response
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from loguru import logger

from starlette.middleware.base import BaseHTTPMiddleware

from src.config import DocuNetConfig
from src.pipeline import DocuNetPipeline
from src.ledger import ledger_db


MAX_UPLOAD_BYTES = 10 * 1024 * 1024


def _compute_phash(image: np.ndarray) -> str:
    """Return a compact perceptual hash stable across small scan changes."""
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    resized = cv2.resize(gray, (32, 32), interpolation=cv2.INTER_AREA).astype(np.float32)
    dct = cv2.dct(resized)
    low_frequency = dct[:8, :8]
    threshold = float(np.median(low_frequency[1:, 1:]))
    bits = (low_frequency >= threshold).flatten()
    value = 0
    for bit in bits:
        value = (value << 1) | int(bit)
    return f"{value:016x}"


def _aadhaar_key(result_dict: dict) -> str:
    document = result_dict.get("document") or {}
    fields = document.get("fields") or {}
    value = fields.get("aadhaar_number", {}).get("value", "")
    return "".join(ch for ch in str(value) if ch.isdigit())


def _identity_fields(result_dict: dict) -> dict:
    fields = (result_dict.get("document") or {}).get("fields") or {}
    return {
        key: str(value.get("value", "")).strip().lower()
        for key, value in fields.items()
        if key in {"name", "dob", "gender", "aadhaar_number"} and isinstance(value, dict)
    }


class RequestIDMiddleware(BaseHTTPMiddleware):
    """Inject X-Request-ID into every request/response for log correlation."""

    async def dispatch(self, request: Request, call_next):
        request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
        with logger.contextualize(request_id=request_id):
            response: Response = await call_next(request)
            response.headers["X-Request-ID"] = request_id
            return response


app = FastAPI(
    title="DocuNet API",
    description="ID Card Tamper Detection & Robust OCR Pipeline",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# Environment-driven CORS
_allowed_origins = os.environ.get(
    "DOCUNET_CORS_ORIGINS", "http://localhost:3000,http://localhost:8501"
).split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in _allowed_origins],
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

app.add_middleware(RequestIDMiddleware)

# Rate limiting (requires slowapi)
try:
    from slowapi import Limiter, _rate_limit_exceeded_handler
    from slowapi.util import get_remote_address
    from slowapi.errors import RateLimitExceeded

    limiter = Limiter(key_func=get_remote_address, default_limits=["30/minute"])
    app.state.limiter = limiter
    app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
    _HAS_LIMITER = True
except ImportError:  # pragma: no cover
    _HAS_LIMITER = False
    logger.warning("slowapi not installed — API rate limiting disabled")

# Lazy-load the pipeline
_pipeline: Optional[DocuNetPipeline] = None


def get_pipeline() -> DocuNetPipeline:
    """Get or initialize the pipeline singleton."""
    global _pipeline
    if _pipeline is None:
        config = DocuNetConfig.default()
        _pipeline = DocuNetPipeline(config)
    return _pipeline


class VerifyResponse(BaseModel):
    success: bool
    stage_reached: str
    error_message: Optional[str] = None
    total_time_ms: float
    quality: Optional[dict] = None
    rectification: Optional[dict] = None
    glare: Optional[dict] = None
    tamper_detection: Optional[dict] = None
    dl_tamper: Optional[dict] = None
    noise_analysis: Optional[dict] = None
    jpeg_ghost: Optional[dict] = None
    copy_move: Optional[dict] = None
    ocr: Optional[dict] = None
    document: Optional[dict] = None
    timings: dict


class HealthResponse(BaseModel):
    status: str
    version: str
    pipeline_loaded: bool




def decode_upload(file_bytes: bytes) -> np.ndarray:
    """Decode uploaded file bytes to OpenCV image with size validation."""
    if len(file_bytes) > MAX_UPLOAD_BYTES:
        raise HTTPException(
            status_code=413,
            detail=f"Upload exceeds {MAX_UPLOAD_BYTES // (1024*1024)} MB limit.",
        )
    if len(file_bytes) == 0:
        raise HTTPException(status_code=400, detail="Empty file uploaded.")
    nparr = np.frombuffer(file_bytes, np.uint8)
    image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if image is None:
        raise HTTPException(
            status_code=400,
            detail="Could not decode image. Supported formats: JPEG, PNG, BMP.",
        )
    return image


def encode_image_base64(image: np.ndarray, format: str = ".jpg") -> str:
    """Encode OpenCV image to base64 string."""
    _, buffer = cv2.imencode(format, image)
    return base64.b64encode(buffer).decode("utf-8")


def _json_safe(value):
    """Replace NaN/Infinity values that strict mobile JSON decoders reject."""
    if isinstance(value, float):
        return value if math.isfinite(value) else None
    if isinstance(value, dict):
        return {key: _json_safe(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [_json_safe(item) for item in value]
    return value


@app.get("/api/v1/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint."""
    return HealthResponse(
        status="healthy",
        version="1.0.0",
        pipeline_loaded=_pipeline is not None,
    )


@app.post("/api/v1/verify", response_model=VerifyResponse)
async def verify_document(
    file: UploadFile = File(...),
    skip_quality_gate: bool = False,
):
    """Verify a single document image through the full pipeline."""
    logger.info(f"Received verification request: {file.filename}")

    # Read and decode
    file_bytes = await file.read()
    image = decode_upload(file_bytes)

    # Process
    pipeline = get_pipeline()
    result = pipeline.process(image, skip_quality_gate=skip_quality_gate)

    return VerifyResponse(**result.to_dict())


@app.post("/api/v1/ela-only")
async def ela_analysis(file: UploadFile = File(...)):
    """Run only ELA tamper detection (no OCR) and return a base64 heatmap."""
    file_bytes = await file.read()
    image = decode_upload(file_bytes)

    pipeline = get_pipeline()
    result = pipeline.process(image, skip_ocr=True, skip_quality_gate=True)

    response = {
        "tamper_detection": result.ela_result.to_dict() if result.ela_result else None,
    }

    if result.ela_result and result.ela_result.heatmap is not None:
        response["heatmap_base64"] = encode_image_base64(result.ela_result.heatmap)

    if "ela_overlay" in result.images:
        response["overlay_base64"] = encode_image_base64(result.images["ela_overlay"])

    return JSONResponse(content=response)


@app.post("/api/v1/batch")
async def batch_verify(files: List[UploadFile] = File(...)):
    """Batch verification of multiple document images."""
    logger.info(f"Received batch request: {len(files)} images")

    pipeline = get_pipeline()
    results = []

    for file in files:
        try:
            file_bytes = await file.read()
            image = decode_upload(file_bytes)
            result = pipeline.process(image)
            results.append({
                "filename": file.filename,
                "result": result.to_dict(),
            })
        except (ValueError, RuntimeError, cv2.error) as e:
            results.append({
                "filename": file.filename,
                "error": str(e),
            })

    return JSONResponse(content={"results": results, "total": len(results)})


class RegisterIdentityRequest(BaseModel):
    document_hash: str
    issuer_signature: str

class VerifyIdentityRequest(BaseModel):
    document_hash: str

@app.post("/api/v1/register_identity")
async def register_identity_endpoint(req: RegisterIdentityRequest):
    """Register a new identity hash into the blockchain ledger."""
    success = ledger_db.register_identity(req.document_hash, req.issuer_signature)
    if success:
        return JSONResponse(content={"success": True, "message": "Identity registered to ledger"})
    else:
        raise HTTPException(status_code=400, detail="Failed to register identity or already exists")

@app.post("/api/v1/verify_identity_hash")
async def verify_identity_hash_endpoint(req: VerifyIdentityRequest):
    """Verify if an identity hash exists in the blockchain ledger."""
    result = ledger_db.verify_identity(req.document_hash)
    return JSONResponse(content={"success": True, "ledger_result": result})


@app.post("/api/v1/register_from_image")
async def register_from_image_endpoint(
    request: Request,
    file: UploadFile = File(...),
):
    """
    Register identity using perceptual image hash (pHash).
    pHash is computed from image pixels — stable across multiple scans
    of the same physical document regardless of OCR quality.
    """
    file_bytes = await file.read()
    image = decode_upload(file_bytes)

    document_hash = _compute_phash(image)
    identity_key = request.headers.get("X-Identity-Key", "")
    registration_result = get_pipeline().process(image)
    registration_dict = registration_result.to_dict()
    if not identity_key:
        identity_key = _aadhaar_key(registration_dict)
    identity_fields = _identity_fields(registration_dict)
    signature = f"pramaan_issuer_{document_hash[:16]}"
    already_exists = not ledger_db.register_identity(
        document_hash, signature, identity_key, identity_fields
    )

    logger.info(f"register_from_image (pHash): hash={document_hash[:16]}... already_existed={already_exists}")
    return JSONResponse(content={
        "success": True,
        "document_hash": document_hash,
        "already_existed": already_exists,
        "method": "perceptual_hash",
    })


@app.post("/api/v1/verify_from_image")
async def verify_from_image_endpoint(file: UploadFile = File(...)):
    """
    One-shot endpoint: runs forensics + pHash ledger check.
    Flutter sends the image ONCE and gets both forensics result and
    ledger verification back. No separate hash step needed.
    """
    file_bytes = await file.read()
    image = decode_upload(file_bytes)

    # Run forensics pipeline
    pipeline = get_pipeline()
    result = pipeline.process(image)
    result_dict = result.to_dict()

    # Compute pHash and check ledger
    document_hash = _compute_phash(image)
    ledger_result = ledger_db.verify_identity(document_hash, _aadhaar_key(result_dict))
    current_fields = _identity_fields(result_dict)
    registered_fields = ledger_result.get("registered_fields", {})
    if ledger_result.get("is_registered") and not registered_fields and current_fields:
        ledger_db.update_identity_fields(document_hash, _aadhaar_key(result_dict), current_fields)
        registered_fields = current_fields
        ledger_result["registered_fields"] = registered_fields
    field_mismatches = {
        key: {"registered": registered_fields[key], "scanned": current_fields.get(key, "")}
        for key in registered_fields
        if key != "aadhaar_number"
        and current_fields.get(key)
        and current_fields.get(key) != registered_fields[key]
    }
    ledger_result["field_mismatches"] = field_mismatches
    ledger_result["fields_match"] = not field_mismatches
    result_dict['ledger_result'] = ledger_result
    result_dict['document_hash'] = document_hash

    logger.info(f"verify_from_image: hash={document_hash[:16]}... registered={ledger_result.get('is_registered')}")
    return JSONResponse(content=_json_safe(result_dict))


@app.post("/api/v1/compare_faces")
async def compare_faces_endpoint(
    id_photo: UploadFile = File(...),
    selfie: UploadFile = File(...),
):
    """
    Compare two face images and return similarity score.
    Uses OpenCV histogram comparison as a lightweight demo approach.
    """
    id_bytes = await id_photo.read()
    selfie_bytes = await selfie.read()

    id_img = decode_upload(id_bytes)
    selfie_img = decode_upload(selfie_bytes)

    def crop_face(img: np.ndarray, is_document: bool) -> tuple[np.ndarray, bool]:
        """Extract a portrait, using the Aadhaar front-card portrait zone as fallback."""
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        cascade = cv2.CascadeClassifier(
            cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
        )
        faces = cascade.detectMultiScale(
            gray, scaleFactor=1.08, minNeighbors=3, minSize=(35, 35)
        )
        if len(faces):
            x, y, w, h = max(faces, key=lambda face: face[2] * face[3])
            pad_x, pad_y = int(w * 0.35), int(h * 0.45)
            x1, y1 = max(0, x - pad_x), max(0, y - pad_y)
            x2, y2 = min(img.shape[1], x + w + pad_x), min(img.shape[0], y + h + pad_y)
            return img[y1:y2, x1:x2], True
        if is_document:
            # Standard Aadhaar front layout: portrait at upper-left of the card.
            h, w = img.shape[:2]
            crop = img[int(h * 0.12):int(h * 0.82), int(w * 0.03):int(w * 0.43)]
            return crop if crop.size else img, False
        return img, False

    try:
        # Try DeepFace if available (most accurate)
        DeepFace = importlib.import_module("deepface").DeepFace
        id_face, id_detected = crop_face(id_img, True)
        selfie_face, selfie_detected = crop_face(selfie_img, False)
        result = DeepFace.verify(id_face, selfie_face, model_name="Facenet", enforce_detection=False)
        similarity = round((1.0 - min(result['distance'], 1.0)) * 100, 1)
        is_match = result['verified']
        method = "DeepFace/Facenet"
    except Exception:
        # Fallback: compare detected/cropped portrait regions, never the whole card.
        face1, detected1 = crop_face(id_img, True)
        face2, detected2 = crop_face(selfie_img, False)
        face1 = cv2.resize(face1, (160, 200))
        face2 = cv2.resize(face2, (160, 200))
        gray1 = cv2.equalizeHist(cv2.cvtColor(face1, cv2.COLOR_BGR2GRAY))
        gray2 = cv2.equalizeHist(cv2.cvtColor(face2, cv2.COLOR_BGR2GRAY))
        hist1 = cv2.calcHist([gray1], [0], None, [32], [0, 256])
        hist2 = cv2.calcHist([gray2], [0], None, [32], [0, 256])
        cv2.normalize(hist1, hist1)
        cv2.normalize(hist2, hist2)
        hist_score = max(0.0, float(cv2.compareHist(hist1, hist2, cv2.HISTCMP_CORREL)))
        pixel_score = max(0.0, 1.0 - float(cv2.norm(gray1, gray2, cv2.NORM_L2)) / (255.0 * np.sqrt(gray1.size)))
        similarity = round((hist_score * 0.55 + pixel_score * 0.45) * 100, 1)
        is_match = similarity >= 50.0
        method = "OpenCV/PortraitFeatures"

    logger.info(f"Face compare: similarity={similarity}% match={is_match} method={method}")
    return JSONResponse(content={
        "success": True,
        "similarity_percent": similarity,
        "is_match": is_match,
        "method": method,
    })


@app.websocket("/ws/live-capture")
async def live_capture(websocket: WebSocket):
    """WebSocket endpoint for real-time camera quality feedback and smart capture."""
    await websocket.accept()

    pipeline = get_pipeline()
    quality_gate = pipeline.quality_gate

    logger.info("WebSocket live-capture session started")

    try:
        while True:
            data = await websocket.receive_text()

            try:
                img_bytes = base64.b64decode(data)
                nparr = np.frombuffer(img_bytes, np.uint8)
                frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

                if frame is None:
                    await websocket.send_json({
                        "type": "error",
                        "message": "Could not decode frame",
                    })
                    continue

                # Quick quality check
                report = quality_gate.evaluate(frame)

                if report.passed:
                    await websocket.send_json({
                        "type": "ready",
                        "message": "Quality OK — capturing...",
                        "quality": report.to_dict(),
                    })

                    result = pipeline.process(frame)

                    await websocket.send_json({
                        "type": "result",
                        "data": result.to_dict(),
                    })
                else:
                    await websocket.send_json({
                        "type": "guidance",
                        "quality": report.to_dict(),
                        "issues": report.issues,
                    })

            except Exception as e:
                await websocket.send_json({
                    "type": "error",
                    "message": str(e),
                })

    except WebSocketDisconnect:
        logger.info("WebSocket live-capture session ended")


def start_server(host: str = "0.0.0.0", port: int = 8000):
    """Start the API server."""
    import uvicorn
    uvicorn.run(app, host=host, port=port)


if __name__ == "__main__":
    start_server()
