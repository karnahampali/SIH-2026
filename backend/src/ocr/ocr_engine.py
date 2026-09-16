"""Multi-engine OCR text extraction with confidence-based fallback."""

import cv2
import json
import numpy as np
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import List, Optional, Tuple
from loguru import logger

from src.config import OCRConfig


@dataclass
class OCRBox:
    """A single detected text region."""
    text: str
    confidence: float
    bbox: List[List[int]]
    engine: str

    def to_dict(self) -> dict:
        return {
            "text": self.text,
            "confidence": round(self.confidence, 4),
            "bbox": self.bbox,
            "engine": self.engine,
        }


@dataclass
class OCRResult:
    """Complete OCR result for an image."""
    boxes: List[OCRBox]
    full_text: str
    avg_confidence: float
    engine_used: str
    raw_output: Optional[dict] = field(default=None, repr=False)

    def to_dict(self) -> dict:
        return {
            "boxes": [b.to_dict() for b in self.boxes],
            "full_text": self.full_text,
            "avg_confidence": round(self.avg_confidence, 4),
            "engine_used": self.engine_used,
        }


class BaseOCREngine(ABC):
    """Abstract base class for OCR engines."""

    @abstractmethod
    def extract(self, image: np.ndarray) -> OCRResult:
        """Run OCR on an image and return structured results."""
        pass


class PaddleOCREngine(BaseOCREngine):
    """PaddleOCR wrapper — primary OCR engine (DB + CRNN pipeline)."""

    def __init__(self, config: OCRConfig | None = None) -> None:
        self.config = config or OCRConfig()
        self._engine = None

    def _load_engine(self):
        """Lazy-load PaddleOCR to reduce startup time."""
        if self._engine is None:
            try:
                from paddleocr import PaddleOCR
                import logging as _logging
                _logging.getLogger("ppocr").setLevel(_logging.WARNING)
                try:
                    self._engine = PaddleOCR(
                        use_textline_orientation=True,
                        lang="en",
                        enable_mkldnn=False,
                    )
                except TypeError:
                    # PaddleOCR 2.x uses the older angle-classifier options.
                    self._engine = PaddleOCR(
                        use_angle_cls=True,
                        lang="en",
                        show_log=False,
                        enable_mkldnn=False,
                    )
                logger.info("PaddleOCR engine loaded successfully")
            except ImportError:
                logger.error(
                    "PaddleOCR not installed. Install with: pip install paddlepaddle paddleocr"
                )
                raise

    def extract(self, image: np.ndarray) -> OCRResult:
        """Run PaddleOCR on the image."""
        self._load_engine()

        if hasattr(self._engine, "predict"):
            results = self._engine.predict(image)
        else:
            # PaddleOCR 2.x exposes `ocr`, while 3.x exposes `predict`.
            results = self._engine.ocr(image, cls=True)

        boxes = []
        if results:
            for page in results:
                page_data = _result_to_dict(page)
                if not page_data:
                    page_data = _legacy_result_to_dict(page)
                texts = page_data.get("rec_texts", [])
                scores = page_data.get("rec_scores", [])
                polys = page_data.get("rec_polys", page_data.get("dt_polys", []))

                for text, score, poly in zip(texts, scores, polys):
                    confidence = float(score)
                    poly_arr = np.asarray(poly)
                    # Convert polygon to 4-point bbox
                    if poly_arr.ndim == 2 and poly_arr.shape[0] >= 4:
                        bbox = [[int(p[0]), int(p[1])] for p in poly_arr[:4]]
                    else:
                        x_min, y_min = int(poly_arr.min(axis=0)[0]), int(poly_arr.min(axis=0)[1])
                        x_max, y_max = int(poly_arr.max(axis=0)[0]), int(poly_arr.max(axis=0)[1])
                        bbox = [[x_min, y_min], [x_max, y_min], [x_max, y_max], [x_min, y_max]]

                    boxes.append(OCRBox(
                        text=str(text),
                        confidence=confidence,
                        bbox=bbox,
                        engine="paddleocr",
                    ))

        full_text = _boxes_to_lines(boxes)
        avg_conf = np.mean([b.confidence for b in boxes]) if boxes else 0.0

        logger.info(
            f"PaddleOCR: {len(boxes)} text regions, avg confidence: {avg_conf:.3f}"
        )

        return OCRResult(
            boxes=boxes,
            full_text=full_text,
            avg_confidence=float(avg_conf),
            engine_used="paddleocr",
        )


def _result_to_dict(result: object) -> dict:
    """Normalize PaddleOCR 2.x dictionaries and 3.x result objects."""
    if isinstance(result, dict):
        data = result
    else:
        data = getattr(result, "json", None)
        if callable(data):
            data = data()
        if isinstance(data, str):
            try:
                data = json.loads(data)
            except json.JSONDecodeError:
                data = None
        if not isinstance(data, dict):
            converter = getattr(result, "to_dict", None)
            data = converter() if callable(converter) else {}

    if isinstance(data, dict) and isinstance(data.get("res"), dict):
        return data["res"]
    return data if isinstance(data, dict) else {}


def _legacy_result_to_dict(result: object) -> dict:
    """Convert PaddleOCR 2.x's nested `[box, (text, score)]` output."""
    if not isinstance(result, list):
        return {}
    texts = []
    scores = []
    polygons = []
    for item in result:
        if not isinstance(item, (list, tuple)) or len(item) != 2:
            continue
        polygon, recognition = item
        if not isinstance(recognition, (list, tuple)) or len(recognition) != 2:
            continue
        polygons.append(polygon)
        texts.append(recognition[0])
        scores.append(recognition[1])
    return {"rec_texts": texts, "rec_scores": scores, "rec_polys": polygons}


class EasyOCREngine(BaseOCREngine):
    """EasyOCR wrapper — fallback engine (CRAFT + different recognition net)."""

    def __init__(self, config: OCRConfig | None = None) -> None:
        self.config = config or OCRConfig()
        self._engine = None

    def _load_engine(self):
        """Lazy-load EasyOCR."""
        if self._engine is None:
            try:
                import easyocr
                self._engine = easyocr.Reader(
                    self.config.languages,
                    gpu=self.config.use_gpu,
                )
                logger.info("EasyOCR engine loaded successfully")
            except ImportError:
                logger.error(
                    "EasyOCR not installed. Install with: pip install easyocr"
                )
                raise

    def extract(self, image: np.ndarray) -> OCRResult:
        """Run EasyOCR over several document-friendly preprocessing variants."""
        self._load_engine()

        h, w = image.shape[:2]
        scale = 2
        upscaled = cv2.resize(image, (w * scale, h * scale), interpolation=cv2.INTER_CUBIC)
        gray = cv2.cvtColor(upscaled, cv2.COLOR_BGR2GRAY)
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8)).apply(gray)
        adaptive = cv2.adaptiveThreshold(
            clahe, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
            cv2.THRESH_BINARY, 31, 7,
        )
        kernel = np.array([[0, -1, 0], [-1, 5, -1], [0, -1, 0]])
        sharpened = cv2.filter2D(upscaled, -1, kernel)

        boxes = []
        for variant in (sharpened, clahe, adaptive):
            results = self._engine.readtext(
                variant, paragraph=False, width_ths=0.5, add_margin=0.12,
            )
            for bbox, text, confidence in results:
                text = text.strip()
                if not text:
                    continue
                bbox_int = [[int(p[0] / scale), int(p[1] / scale)] for p in bbox]
                boxes.append(OCRBox(
                    text=text, confidence=float(confidence),
                    bbox=bbox_int, engine="easyocr",
                ))

        # Keep the strongest reading for each normalized text token.
        best_by_text = {}
        for box in boxes:
            key = " ".join(box.text.lower().split())
            if key not in best_by_text or box.confidence > best_by_text[key].confidence:
                best_by_text[key] = box
        boxes = list(best_by_text.values())

        full_text = " ".join(b.text for b in boxes)
        avg_conf = np.mean([b.confidence for b in boxes]) if boxes else 0.0

        logger.info(
            f"EasyOCR: {len(boxes)} text regions, avg confidence: {avg_conf:.3f}"
        )

        return OCRResult(
            boxes=boxes,
            full_text=full_text,
            avg_confidence=float(avg_conf),
            engine_used="easyocr",
        )


def _boxes_to_lines(boxes: List[OCRBox]) -> str:
    """Preserve OCR reading lines so Aadhaar labels and values remain associated."""
    if not boxes:
        return ""
    lines: List[List[OCRBox]] = []
    for box in sorted(boxes, key=lambda item: min(point[1] for point in item.bbox)):
        y = min(point[1] for point in box.bbox)
        line = next((candidate for candidate in lines if abs(
            y - min(point[1] for point in candidate[0].bbox)
        ) < 18), None)
        if line is None:
            lines.append([box])
        else:
            line.append(box)
    return "\n".join(
        " ".join(box.text for box in sorted(line, key=lambda item: min(point[0] for point in item.bbox)))
        for line in lines
    )


class OCREngineManager:
    """Manages multiple OCR engines with confidence-based fallback."""

    def __init__(self, config: OCRConfig | None = None) -> None:
        self.config = config or OCRConfig()
        self._engines = {}

    def _get_engine(self, name: str) -> BaseOCREngine:
        """Get or create an OCR engine by name."""
        if name not in self._engines:
            if name == "paddleocr":
                self._engines[name] = PaddleOCREngine(self.config)
            elif name == "easyocr":
                self._engines[name] = EasyOCREngine(self.config)
            else:
                raise ValueError(f"Unknown OCR engine: {name}")
        return self._engines[name]

    def extract(self, image: np.ndarray) -> OCRResult:
        """Extract text and only load a fallback when the primary has no result."""
        paddle_result = OCRResult(boxes=[], full_text="", avg_confidence=0.0, engine_used="paddleocr")
        easy_result = OCRResult(boxes=[], full_text="", avg_confidence=0.0, engine_used="easyocr")

        # Try PaddleOCR
        primary = self._get_engine(self.config.engine)
        try:
            paddle_result = primary.extract(image)
        except Exception as e:
            logger.error(f"Primary OCR engine ({self.config.engine}) failed: {e}")

        if paddle_result.boxes and paddle_result.avg_confidence >= self.config.confidence_threshold:
            return paddle_result

        # Load the fallback only when the primary engine did not produce a usable result.
        fallback = self._get_engine(self.config.fallback_engine)
        try:
            easy_result = fallback.extract(image)
        except Exception as e:
            logger.error(f"Fallback OCR engine ({self.config.fallback_engine}) failed: {e}")

        # Merge: combine boxes from both, deduplicate by text similarity.
        all_boxes = list(easy_result.boxes)  # EasyOCR is more reliable on Windows
        seen_texts = {b.text.lower().strip() for b in all_boxes}
        for box in paddle_result.boxes:
            if box.text.lower().strip() not in seen_texts and box.confidence > 0.3:
                all_boxes.append(box)
                seen_texts.add(box.text.lower().strip())

        if not all_boxes:
            # Return whichever has more text
            return paddle_result if len(paddle_result.full_text) > len(easy_result.full_text) else easy_result

        full_text = " ".join(b.text for b in all_boxes)
        avg_conf = float(np.mean([b.confidence for b in all_boxes]))
        best_engine = "easyocr+paddleocr"

        logger.info(f"Merged OCR: {len(all_boxes)} regions, avg_conf={avg_conf:.3f}")
        return OCRResult(
            boxes=all_boxes,
            full_text=full_text,
            avg_confidence=avg_conf,
            engine_used=best_engine,
        )

    def extract_with_both(self, image: np.ndarray) -> Tuple[OCRResult, OCRResult]:
        """Run both engines and return both results (for benchmarking)."""
        primary = self._get_engine(self.config.engine)
        fallback = self._get_engine(self.config.fallback_engine)

        primary_result = primary.extract(image)
        fallback_result = fallback.extract(image)

        return primary_result, fallback_result


def draw_ocr_boxes(
    image: np.ndarray,
    boxes: List[OCRBox],
    color: Tuple[int, int, int] = (0, 255, 0),
    thickness: int = 2,
) -> np.ndarray:
    """Draw OCR bounding boxes and text on the image for visualization."""
    vis = image.copy()
    for box in boxes:
        pts = np.array(box.bbox, dtype=np.int32)
        cv2.polylines(vis, [pts], isClosed=True, color=color, thickness=thickness)

        text_pos = (pts[0][0], pts[0][1] - 5)
        label = f"{box.text} ({box.confidence:.2f})"
        cv2.putText(
            vis, label, text_pos,
            cv2.FONT_HERSHEY_SIMPLEX, 0.4, color, 1,
        )

    return vis
