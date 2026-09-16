"""Extract structured fields from raw OCR text."""

import re
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple
from loguru import logger

from src.ocr.ocr_engine import OCRBox, OCRResult


@dataclass
class DocumentField:
    """A single extracted field from the document."""
    field_name: str
    value: str
    confidence: float
    source_box: Optional[OCRBox] = None


@dataclass
class ParsedDocument:
    """Complete parsed document with structured fields."""
    fields: Dict[str, DocumentField]
    document_type: str
    overall_confidence: float
    raw_text: str
    unmatched_text: List[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "fields": {
                k: {"value": v.value, "confidence": round(v.confidence, 4)}
                for k, v in self.fields.items()
            },
            "document_type": self.document_type,
            "overall_confidence": round(self.overall_confidence, 4),
            "raw_text": self.raw_text,
            "unmatched_text": self.unmatched_text,
        }



# Indian Aadhaar Card
AADHAAR_PATTERNS = {
    "aadhaar_number": r"(?<![/\-\.])\b(\d{4}\s*\d{4}\s*\d{4})\b",
    "dob": r"\b(?:DOB|Date of Birth|Year of Birth)[:\s]*(\d{2}[/\-\.]\d{2}[/\-\.]\d{4})\b",
    "gender": r"\b(MALE|FEMALE|male|female|Male|Female)\b",
    "vid": r"\b(?:VID)[:\s]*(\d{4}\s?\d{4}\s?\d{4}\s?\d{4})\b",
}

# Indian PAN Card
PAN_PATTERNS = {
    "pan_number": r"\b[A-Z]{5}\d{4}[A-Z]\b",
    "dob": r"\b(\d{2}[/\-\.]\d{2}[/\-\.]\d{4})\b",
}

# US Driver's License (generic patterns)
DRIVERS_LICENSE_PATTERNS = {
    "license_number": r"\b(?:DL|LIC|LICENSE)[:\s#]*([A-Z0-9]{6,12})\b",
    "dob": r"\b(?:DOB|DATE OF BIRTH)[:\s]*(\d{2}[/\-]\d{2}[/\-]\d{4})\b",
    "expiry": r"\b(?:EXP|EXPIRES?)[:\s]*(\d{2}[/\-]\d{2}[/\-]\d{4})\b",
    "class": r"\b(?:CLASS)[:\s]*([A-Z])\b",
}

# Spanish DNI
SPANISH_DNI_PATTERNS = {
    "dni_number": r"\b(\d{8}[A-Z])\b",
    "name": r"(?:NOMBRE)[:\s]*([A-Za-z\s]+?)(?:\n|$)",
    "surname": r"(?:APELLIDOS|PRIMER APELLIDO)[:\s]*([A-Za-z\s]+?)(?:\n|$)",
    "dob": r"(?:FECHA DE NACIMIENTO|NACIMIENTO)[:\s]*(\d{2}[/\-\.]\d{2}[/\-\.]\d{4})\b",
    "sex": r"(?:SEXO)[:\s]*([MF])\b",
}

# Generic patterns that work across document types
GENERIC_PATTERNS = {
    "name": r"(?:Name|NAME)[:\s]*([A-Za-z\s\.]+?)(?:\n|$)",
    "dob": r"(?:DOB|Date of Birth|D\.O\.B|Birth)[:\s]*(\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4})",
    "address": r"(?:Address|ADDR|ADD)[:\s]*([\w\s,\.\-#]+?)(?:\n\n|$)",
    "phone": r"\b(?:\+?\d{1,3}[\s\-]?)?\(?\d{3}\)?[\s\-]?\d{3}[\s\-]?\d{4}\b",
    "email": r"\b[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Z|a-z]{2,}\b",
    "date_generic": r"\b\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4}\b",
}

# Keywords to identify document type
DOC_TYPE_KEYWORDS = {
    "aadhaar": ["aadhaar", "uidai", "unique identification", "आधार"],
    "pan": ["income tax", "permanent account", "pan card", "govt of india"],
    "drivers_license": ["driver", "license", "driving", "motor vehicle", "dmv"],
    "passport": ["passport", "republic of india", "nationality"],
    "spanish_dni": ["españa", "espana", "documento nacional de identidad", "dni"],
}


class FieldParser:
    """Extracts structured fields from raw OCR output."""

    def __init__(self) -> None:
        self.pattern_sets = {
            "aadhaar": AADHAAR_PATTERNS,
            "pan": PAN_PATTERNS,
            "drivers_license": DRIVERS_LICENSE_PATTERNS,
            "spanish_dni": SPANISH_DNI_PATTERNS,
        }

    def parse(self, ocr_result: OCRResult) -> ParsedDocument:
        """Parse OCR results into structured document fields."""
        full_text = self._normalise_text(ocr_result.full_text, ocr_result.boxes)
        boxes = ocr_result.boxes

        doc_type = self._detect_document_type(full_text)
        logger.info(f"Detected document type: {doc_type}")

        fields = {}

        if doc_type == "aadhaar":
            fields.update(self._extract_aadhaar_fields(full_text, boxes))
        elif doc_type in self.pattern_sets:
            type_fields = self._extract_with_patterns(
                full_text, self.pattern_sets[doc_type], boxes
            )
            fields.update(type_fields)

        if doc_type != "aadhaar":
            generic_fields = self._extract_with_patterns(
                full_text, GENERIC_PATTERNS, boxes
            )
            for key, value in generic_fields.items():
                if key not in fields:
                    fields[key] = value

        if "name" not in fields and doc_type != "aadhaar":
            name_field = self._extract_name_spatial(boxes)
            if name_field:
                fields["name"] = name_field

        matched_texts = {f.value.strip().lower() for f in fields.values()}
        unmatched = [
            b.text for b in boxes
            if b.text.strip().lower() not in matched_texts and len(b.text.strip()) > 2
        ]

        if fields:
            overall_conf = sum(f.confidence for f in fields.values()) / len(fields)
        else:
            overall_conf = 0.0

        return ParsedDocument(
            fields=fields,
            document_type=doc_type,
            overall_confidence=overall_conf,
            raw_text=full_text,
            unmatched_text=unmatched,
        )

    def _extract_aadhaar_fields(
        self, text: str, boxes: List[OCRBox]
    ) -> Dict[str, DocumentField]:
        """Extract Aadhaar fields without allowing generic date/phone matches."""
        fields = self._extract_with_patterns(text, AADHAAR_PATTERNS, boxes)
        if "name" in fields and not self._valid_name(fields["name"].value):
            del fields["name"]
        lines = self._ocr_lines(boxes)

        if "dob" not in fields:
            for line, confidence in lines:
                match = re.search(
                    r"(?:DOB|D[O0]B|D\.O\.B|DATE\s+OF\s+BIRTH|जन्म\s*तिथि)\D*(\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4})",
                    line,
                    re.IGNORECASE,
                )
                if match:
                    fields["dob"] = DocumentField("dob", match.group(1), confidence)
                    break

        if "dob" not in fields:
            # EasyOCR may split `DOB`, `:`, and the date into separate boxes.
            dates = re.findall(r"\b(\d{1,2}[/\-.]\d{1,2}[/\-.]\d{4})\b", text)
            if dates:
                # Aadhaar issue dates are commonly printed as older vertical dates;
                # prefer the date nearest a DOB token, otherwise use the latest date.
                dob_index = min(
                    (index for index in (text.upper().find("DOB"), text.upper().find("D0B")) if index >= 0),
                    default=-1,
                )
                selected = dates[0]
                if dob_index >= 0:
                    after_label = text[dob_index:]
                    nearby = re.search(r"\d{1,2}[/\-.]\d{1,2}[/\-.]\d{4}", after_label)
                    if nearby:
                        selected = nearby.group(0)
                elif len(dates) > 1:
                    selected = dates[-1]
                fields["dob"] = DocumentField("dob", selected, 0.5)

        if "gender" not in fields:
            for line, confidence in lines:
                match = re.search(r"\b(MALE|FEMALE)\b|\b(पुरुष|महिला)\b", line, re.IGNORECASE)
                if match:
                    value = next(group for group in match.groups() if group)
                    fields["gender"] = DocumentField("gender", value.upper(), confidence)
                    break

        if "gender" not in fields:
            match = re.search(r"\b(FEMALE|MALE|FEMA1E|MA1E)\b", text, re.IGNORECASE)
            if match:
                value = match.group(1).upper().replace("1", "L")
                fields["gender"] = DocumentField("gender", value, 0.5)

        if "name" not in fields:
            candidate = self._aadhaar_name(boxes, lines, text)
            if candidate:
                fields["name"] = candidate

        return fields

    @staticmethod
    def _ocr_lines(boxes: List[OCRBox]) -> List[Tuple[str, float]]:
        """Group OCR boxes into reading-order lines using their vertical centers."""
        if not boxes:
            return []
        ordered = sorted(boxes, key=lambda box: min(point[1] for point in box.bbox))
        lines: List[List[OCRBox]] = []
        for box in ordered:
            y = min(point[1] for point in box.bbox)
            target = next((line for line in lines if abs(
                y - min(point[1] for point in line[0].bbox)
            ) < 18), None)
            if target is None:
                lines.append([box])
            else:
                target.append(box)
        result = []
        for line in lines:
            line.sort(key=lambda box: min(point[0] for point in box.bbox))
            result.append((" ".join(box.text.strip() for box in line), max(box.confidence for box in line)))
        return result

    def _aadhaar_name(
        self, boxes: List[OCRBox], lines: List[Tuple[str, float]], text: str
    ) -> Optional[DocumentField]:
        """Choose a Latin name line while excluding card labels and metadata."""
        excluded = {
            "aadhaar", "uidai", "government", "india", "male", "female",
            "dob", "date", "birth", "address", "year", "issue", "unique",
            "identification", "government of india", "my aadhaar", "my identity",
        }
        candidates = list(lines)
        for line in text.splitlines():
            if line.strip() and (line.strip(), 0.5) not in candidates:
                candidates.append((line.strip(), 0.5))
        valid_candidates = []
        dob_line_index = next(
            (
                index
                for index, (line, _) in enumerate(candidates)
                if re.search(r"DOB|D[O0]B|DATE\s+OF\s+BIRTH|\d{1,2}[/\-.]\d{1,2}[/\-.]\d{4}", line, re.IGNORECASE)
            ),
            None,
        )
        for index, (line, confidence) in enumerate(candidates):
            value = line.strip()
            words = value.split()
            if len(words) < 2 or len(value) > 45:
                continue
            if not re.fullmatch(r"[A-Za-z][A-Za-z .'-]*", value):
                continue
            lower = value.lower()
            if any(token in lower for token in excluded):
                continue
            if re.search(r"\d|[/\-.]", value) or not self._valid_name(value):
                continue
            distance_bonus = 0
            if dob_line_index is not None:
                distance = dob_line_index - index
                if 1 <= distance <= 2:
                    distance_bonus = 2.0 - (distance * 0.25)
            valid_candidates.append((value, confidence, distance_bonus))
        if not valid_candidates:
            return None
        value, confidence, _ = max(
            valid_candidates,
            key=lambda item: (item[2], item[1], len(item[0].split())),
        )
        return DocumentField("name", value, confidence)

    @staticmethod
    def _valid_name(value: str) -> bool:
        """Reject OCR artifacts and keyboard sequences masquerading as names."""
        normalized = re.sub(r"\s+", "", value).lower()
        if not re.fullmatch(r"[a-z]+", normalized):
            return False
        if len(normalized) < 4 or len(set(normalized)) < 3:
            return False
        keyboard_runs = ("asdfghjkl", "qwertyuiop", "zxcvbnm")
        if any(run in normalized or normalized in run for run in keyboard_runs):
            return False
        return True

    def _detect_document_type(self, text: str) -> str:
        """Detect document type from keyword matching."""
        text_lower = text.lower()
        scores = {}

        for doc_type, keywords in DOC_TYPE_KEYWORDS.items():
            score = sum(1 for kw in keywords if kw in text_lower)
            if score > 0:
                scores[doc_type] = score

        if scores:
            return max(scores, key=scores.get)
        if re.search(r"\b\d{4}\s*\d{4}\s*\d{4}\b", text):
            return "aadhaar"
        return "unknown"

    @staticmethod
    def _normalise_text(text: str, boxes: List[OCRBox]) -> str:
        """Repair common OCR spacing errors in Aadhaar numbers before parsing."""
        normalised = re.sub(
            r"(?<!\d)(\d{4})\s*(\d{4})\s*(\d{4})(?!\d)",
            r"\1 \2 \3",
            text,
        )
        digit_text = " ".join(box.text for box in boxes)
        digit_match = re.search(r"(?<!\d)(\d{4})\D*(\d{4})\D*(\d{4})(?!\d)", digit_text)
        if digit_match and not re.search(r"\b\d{4}\s*\d{4}\s*\d{4}\b", normalised):
            normalised = f"{normalised}\nAadhaar {digit_match.group(1)} {digit_match.group(2)} {digit_match.group(3)}"
        return normalised

    def _extract_with_patterns(
        self,
        text: str,
        patterns: Dict[str, str],
        boxes: List[OCRBox],
    ) -> Dict[str, DocumentField]:
        """Extract fields using regex patterns, matching results to OCR boxes for confidence."""
        fields = {}

        for field_name, pattern in patterns.items():
            match = re.search(pattern, text, re.IGNORECASE | re.MULTILINE)
            if match:
                value = match.group(1) if match.lastindex else match.group(0)
                value = value.strip()

                confidence = self._find_box_confidence(value, boxes)

                fields[field_name] = DocumentField(
                    field_name=field_name,
                    value=value,
                    confidence=confidence,
                )

        return fields

    def _find_box_confidence(self, text: str, boxes: List[OCRBox]) -> float:
        """Find the OCR box best matching the extracted text and return its confidence."""
        if not boxes:
            return 0.5

        text_lower = text.lower().strip()
        best_confidence = 0.5

        for box in boxes:
            box_text = box.text.lower().strip()
            if text_lower in box_text or box_text in text_lower:
                best_confidence = max(best_confidence, box.confidence)

        return best_confidence

    def _extract_name_spatial(self, boxes: List[OCRBox]) -> Optional[DocumentField]:
        """Extract name field via spatial heuristics (top of document, longest alphabetic text)."""
        if not boxes:
            return None

        sorted_boxes = sorted(
            boxes, key=lambda b: min(pt[1] for pt in b.bbox)
        )

        cutoff = max(1, int(len(sorted_boxes) * 0.6))
        candidates = sorted_boxes[:cutoff]

        name_candidates = []
        for box in candidates:
            text = box.text.strip()
            alpha_ratio = sum(c.isalpha() or c.isspace() for c in text) / max(len(text), 1)

            if alpha_ratio > 0.8 and len(text) > 3:
                keywords = {
                    "name", "dob", "date", "address", "male", "female", "government",
                    "documento", "nacional", "identidad", "republica", "espana", "españa",
                    "signature", "firma"
                }
                if not any(kw in text.lower() for kw in keywords):
                    name_candidates.append(box)

        if not name_candidates:
            return None

        best = max(name_candidates, key=lambda b: len(b.text))

        return DocumentField(
            field_name="name",
            value=best.text.strip(),
            confidence=best.confidence,
            source_box=best,
        )
