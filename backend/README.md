# DocuNet — ID Card Tamper Detection & Robust OCR Pipeline

[![Python 3.10+](https://img.shields.io/badge/python-3.10%2B-blue.svg)](https://www.python.org/downloads/)
[![OpenCV](https://img.shields.io/badge/OpenCV-4.x-green.svg)](https://opencv.org)
[![PyTorch](https://img.shields.io/badge/PyTorch-2.x-red.svg)](https://pytorch.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## Business Problem

Banks, fintech companies, and government agencies process millions of identity documents daily — Aadhaar cards, PAN cards, driver's licenses. Manual verification doesn't scale, and naive OCR systems are trivially defeated by Photoshopped IDs where a name or photo has been replaced.

**DocuNet solves both problems simultaneously:**

1. **Tamper Detection** — Determines whether the document has been digitally altered, using four independent forensic techniques plus a deep learning classifier. A single method can be fooled; the ensemble makes forgeries significantly harder.
2. **Robust OCR** — Extracts structured fields (name, ID number, date of birth) from real-world captures that are blurry, glare-affected, or skewed. Real photos are not flatbed scans — the pipeline handles perspective distortion, uneven lighting, and lamination reflections before running OCR.

The system outputs a machine-readable JSON report per document, enabling automated decisioning in KYC/AML workflows.

---

## Technical Approach

### Architecture

```
Camera / Upload
      │
      ▼
┌────────────────────────────────────────────────────────────────────┐
│                        DocuNet Pipeline                             │
│                                                                    │
│  Quality Gate ──→ Rectification ──→ Glare Handler ──→ Enhancement  │
│  (Laplacian +     (Canny +          (HSV thresh +    (CLAHE LAB +  │
│   Tenengrad)       Hough Lines)      Telea inpaint)   NLM denoise) │
│       │                                       │                    │
│       ▼                                       ▼                    │
│  ┌──────────────────── Forensic Analysis Suite ──────────────────┐ │
│  │  ELA          SRM Noise       JPEG Ghost       Copy-Move      │ │
│  │  Detector     Residual        Detector          (ORB+RANSAC)  │ │
│  │  (JPEG re-    (Fridrich &     (Farid 2009)     (Amerini 2011) │ │
│  │   compress)    Kodovský 2012)                                 │ │
│  │       │                                                       │ │
│  │       ▼                                                       │ │
│  │  DL Tamper Classifier                                         │ │
│  │  MobileNetV3-Small, 4-ch (RGB + raw ELA gray)                │ │
│  │  Focal Loss · AMP · CosineAnnealingWarmRestarts              │ │
│  └───────────────────────────────────────────────────────────────┘ │
│       │                                                            │
│       ▼                                                            │
│  Multi-Engine OCR ──→ Field Parser                                 │
│  PaddleOCR (primary)   Aadhaar / PAN / DL regex                   │
│  EasyOCR  (fallback)   Spatial heuristics                          │
│  Confidence routing    Document type detection                     │
└────────────────────────────────────────────────────────────────────┘
      │
      ▼
  JSON Report + Annotated Images + Confidence Scores
```

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| **4-channel CNN** (RGB + raw ELA grayscale) | Raw ELA preserves the true recompression residual; JET colourmap injects arbitrary gradients the network must learn to ignore |
| **Focal Loss** (α=0.25, γ=2.0) | Down-weights easy negatives so the model focuses on hard tamper examples — critical when clean documents vastly outnumber forgeries |
| **Dual blur metric** (Laplacian + Tenengrad) | Sobel-gradient magnitude catches motion blur that Laplacian variance misses; dual scoring reduces false-accept rate |
| **Canny + Hough dual-strategy rectification** | If the card boundary is partially occluded (finger, shadow), contour detection fails; Hough line-based corner estimation provides a fallback |
| **CLAHE in LAB** colour space | Enhances luminance channel independently — avoids colour shifts that plague histogram equalisation in BGR/RGB |
| **Telea FMM inpainting** for glare | Fast-marching-method fills specular highlights from boundary pixels inward, preserving text under lamination reflections |
| **4 forensic detectors + 1 DL classifier** | No single forensic method is universal — ELA catches JPEG splice artifacts, SRM reveals noise inconsistencies, JPEG ghost finds double-compression, ORB+RANSAC finds copy-move; the CNN fuses visual + forensic features |
| **Poisson blending** for synthetic tampers | `cv2.seamlessClone` produces photorealistic spliced training pairs; hard-paste artifacts would be trivially detectable and wouldn't teach the model real forgeries |
| **PaddleOCR → EasyOCR confidence routing** | PaddleOCR is faster; EasyOCR is more robust on degraded inputs. Confidence threshold routes to whichever yields higher-quality extraction |
| **MPS device fallback** | `_resolve_device()` checks CUDA → MPS (Apple Silicon) → CPU, so training and inference use the best available accelerator without user configuration |

### Techniques & References

| Technique | Module | Reference |
|-----------|--------|-----------|
| Error Level Analysis | `ela_detector.py` | Krawetz, "A Picture's Worth...", Hacker Factor 2007 |
| SRM noise residuals | `noise_analyzer.py` | Fridrich & Kodovský, IEEE TIFS 2012 |
| JPEG ghost detection | `jpeg_ghost.py` | Farid, "Exposing Digital Forgeries from JPEG Ghosts", IEEE TIFS 2009 |
| Copy-move (ORB + RANSAC) | `copymove_detector.py` | Amerini et al., IEEE TIFS 2011 |
| Focal Loss | `tamper_classifier.py` | Lin et al., "Focal Loss for Dense Object Detection", ICCV 2017 |
| Grad-CAM | `tamper_classifier.py` | Selvaraju et al., ICCV 2017 |
| MobileNetV3 | `tamper_classifier.py` | Howard et al., ICCV 2019 |

---

## How to Run

### Prerequisites

- Python 3.10+
- (Optional) NVIDIA GPU with CUDA, or Apple Silicon Mac for MPS acceleration

### 1. Clone & Install

```bash
git clone https://github.com/<your-user>/docunet.git
cd docunet
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
```

### 2. CLI — Verify a Document

```bash
# Full pipeline: quality gate → rectification → ELA → OCR → field parse
python -m src.cli verify path/to/id_card.jpg

# ELA-only analysis
python -m src.cli ela path/to/document.jpg --output-dir ./ela_output

# Generate synthetic tampered training data (Poisson blending)
python -m src.cli generate --input-dir ./clean_ids --output-dir ./augmented --count 20

# Benchmark throughput on a folder
python -m src.cli benchmark ./test_images/
```

### 3. REST API

```bash
# Start FastAPI server (rate-limited, CORS-hardened)
python -m src.cli server --port 8000

# Single document verification
curl -X POST http://localhost:8000/api/v1/verify \
  -F "file=@id_card.jpg"

# Batch processing
curl -X POST http://localhost:8000/api/v1/batch \
  -F "files=@card1.jpg" -F "files=@card2.jpg"
```

### 4. Interactive Dashboard

```bash
streamlit run src/dashboard.py
```

### 5. Train the Tamper Classifier

```python
from src.config import TamperModelConfig
from src.models.tamper_classifier import TamperTrainer, TamperClassifier

config = TamperModelConfig(
    pretrained=True,
    learning_rate=1e-4,
    weight_decay=1e-4,
    batch_size=32,
    num_epochs=30,
)
model = TamperClassifier(config)
trainer = TamperTrainer(model, config)
trainer.train(
    train_dir="data/train/",
    val_dir="data/val/",
    output_dir="models/checkpoints/",
)
```

---

## Performance

### Pipeline Latency (single 640×400 ID card image)

| Stage | Time (ms) | Notes |
|-------|-----------|-------|
| Quality Gate | ~5 | Laplacian + Tenengrad + HSV checks |
| Rectification | ~25 | Canny contours → Hough fallback |
| Glare Removal | ~15 | HSV threshold + Telea inpainting |
| Enhancement | ~10 | CLAHE (LAB) + NLM denoise |
| ELA Detection | ~20 | JPEG round-trip + DCT block analysis |
| Noise Analysis | ~15 | SRM 3-kernel + block variance |
| JPEG Ghost | ~180 | 25-step quality sweep (Q=50..98) |
| Copy-Move | ~35 | 5000 ORB features + RANSAC |
| DL Classifier | ~30 | MobileNetV3-Small forward pass (CPU) |
| OCR | ~200 | PaddleOCR (GPU: ~80ms) |
| Field Parsing | ~2 | Regex + spatial heuristics |
| **Total** | **~540** | **GPU brings total below 300ms** |

### Model Specifications

| Property | Value |
|----------|-------|
| Backbone | MobileNetV3-Small (2.5M params) |
| Input | 4-channel: RGB (3) + raw ELA grayscale (1) |
| Input size | 224 × 224 |
| Loss | Focal Loss (α=0.25, γ=2.0) |
| Optimizer | AdamW (lr=1e-4, weight_decay=1e-4) |
| Scheduler | CosineAnnealingWarmRestarts (T₀=5, T_mult=2) |
| AMP | Enabled on CUDA (GradScaler) |
| Model selection | Best validation F1 score |

---

## Project Structure

```
docunet/
├── src/
│   ├── __init__.py                  # Package root, version, public exports
│   ├── config.py                    # 11 frozen dataclass configs, YAML/env loading
│   ├── pipeline.py                  # Orchestrator — chains all 7+ stages
│   ├── cli.py                       # Click + Rich CLI (verify, ela, generate, benchmark)
│   ├── dashboard.py                 # Streamlit interactive UI
│   ├── protocols.py                 # PEP 544 structural typing contracts
│   ├── exceptions.py                # Typed exception hierarchy with stage tracking
│   │
│   ├── preprocessing/
│   │   ├── quality_gate.py          # Laplacian + Tenengrad blur, HSV brightness/glare
│   │   ├── rectifier.py             # Canny contour + Hough line corner detection
│   │   ├── enhancement.py           # CLAHE (LAB), NLM denoise, Sauvola binarisation
│   │   └── glare_handler.py         # HSV glare mask + Telea FMM inpainting
│   │
│   ├── forensics/
│   │   ├── ela_detector.py          # ELA with DCT block analysis
│   │   ├── ela_utils.py             # Shared compute_ela_map (no duplication)
│   │   ├── noise_analyzer.py        # SRM high-pass residual + block-variance scoring
│   │   ├── jpeg_ghost.py            # Multi-quality re-compression sweep (Farid 2009)
│   │   └── copymove_detector.py     # ORB features + RANSAC affine verification
│   │
│   ├── models/
│   │   └── tamper_classifier.py     # MobileNetV3 4-ch, Focal Loss, AMP, Grad-CAM
│   │
│   ├── ocr/
│   │   ├── ocr_engine.py            # PaddleOCR + EasyOCR with confidence routing
│   │   └── field_parser.py          # Regex + spatial heuristics for ID fields
│   │
│   ├── synthetic/
│   │   └── generator.py             # Albumentations + Poisson blending augmentation
│   │
│   └── api/
│       └── server.py                # FastAPI + slowapi rate limiting + CORS + request IDs
│
├── .pre-commit-config.yaml          # ruff, mypy, bandit hooks
├── requirements.txt                 # Pinned runtime + dev dependencies
└── README.md
```

## Technologies

| Category | Stack |
|----------|-------|
| **Computer Vision** | OpenCV 4.x (Canny, Hough, CLAHE, morphology, Telea inpainting, `seamlessClone`, perspective transforms) |
| **Deep Learning** | PyTorch 2.x (MobileNetV3-Small, Focal Loss, AMP, CosineAnnealingWarmRestarts, Grad-CAM) |
| **Forensics** | ELA, SRM noise residuals, JPEG ghost analysis, ORB+RANSAC copy-move detection |
| **OCR** | PaddleOCR + EasyOCR (multi-engine, confidence-routed fallback) |
| **API** | FastAPI, slowapi rate limiting, env-driven CORS, X-Request-ID middleware |
| **CLI** | Click + Rich (formatted tables, panels, progress bars) |
| **Augmentation** | Albumentations (ISONoise, MotionBlur, JPEG compression) + Poisson blending |

| **Security** | Bandit static analysis, pip-audit, pre-commit hooks |

## License

MIT
