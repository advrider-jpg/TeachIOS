# OCR and Evidence Pipeline Report  
Local-First iOS/iPadOS Teacher Grading Assistant  

---

## Executive Summary

This report evaluates the realistic capabilities and limitations of Apple’s on-device OCR stack—primarily Apple Vision and VisionKit—and proposes a conservative, evidence-grounded pipeline suitable for a teacher grading assistant that must not overclaim recognition accuracy.

Key conclusions:

1. **Printed OCR is strong but not infallible.** High-quality typed documents captured via VisionKit and processed with Apple Vision typically achieve high accuracy under good lighting and minimal skew. However, classroom artifacts introduce layout complexity and degradation that materially reduce reliability.

2. **Confidence metadata is usable but coarse.** Apple Vision exposes per-observation confidence scores and candidate strings, but these are not calibrated probabilities. They must be treated as heuristics, not guarantees.

3. **Handwriting recognition is limited and inconsistent.** Apple Vision supports recognition of some handwriting styles on newer OS versions and hardware, but classroom handwriting variability makes it unsuitable for autonomous grading without teacher confirmation.

4. **Math notation, diagrams, and structured worksheets are not reliably solvable with general OCR.** They require domain-specific recognition or teacher-confirmed transcription.

5. **The grading system must be abstention-first.** The app must grade only teacher-confirmed text. All uncertain OCR must be blocked from grading until reviewed.

6. **Evidence traceability is essential.** Every quote used in grading must be traceable to: source file → page → bounding box → OCR span → teacher-confirmed text.

This report proposes a state machine, data model, review thresholds, abstention logic, test fixtures, and MVP acceptance criteria aligned with these constraints.

---

# 1. Apple OCR Capability Overview

## 1.1 Core Components

- **Text recognition:** Apple Vision (`VNRecognizeTextRequest`)
- **Document scanning UI:** VisionKit (`VNDocumentCameraViewController`)
- **PDF rendering:** PDFKit
- **Language processing:** NaturalLanguage, optional downstream

All recognition is on-device when using standard Vision APIs.

---

## 2. Apple OCR Capability Matrix

| Capability | Supported | Reliability (Practical) | Notes |
|-------------|------------|--------------------------|-------|
| Printed text (clean, typed) | Yes | High under good capture | RecognitionLevel `.accurate` preferred |
| Photographed pages | Yes | Medium–High | Dependent on lighting, blur, skew |
| Skewed documents | Partially | Medium | VisionKit auto-cropping helps; heavy skew degrades |
| Low-light scans | Yes | Medium–Low | Noise and blur reduce character accuracy |
| Multi-page scans | Yes | High workflow support | VisionKit returns array of images |
| PDF import (vector text) | Yes | Very High if text-based PDF | Prefer text extraction over OCR |
| Image-based PDF | Yes | Medium | Treated as images |
| Tables / columns | Not structured | Medium | Recognizes text but not table structure |
| Handwriting | Limited | Low–Medium | Highly dependent on legibility |
| Mixed handwriting + print | Yes | Low–Medium | Often inconsistent segmentation |
| Math notation | Not specialized | Low | No structural math model |
| Diagrams | No semantic recognition | Very Low | Text labels only |

---

## 3. Data Exposed by Apple Vision OCR

Using `VNRecognizeTextRequest`, Apple Vision provides:

### 3.1 Observation-Level Data
- `VNRecognizedTextObservation`
  - Bounding box (normalized coordinates)
  - Confidence (Float 0.0–1.0)
  - Candidate strings (top-N via `topCandidates(n)`)

### 3.2 Candidate-Level Data
- Recognized string
- Candidate-specific confidence
- Range-based bounding box for substrings

### 3.3 Language
- Detected language(s) per observation (if enabled)
- Language correction option

### 3.4 Reading Order
Vision does not guarantee document-true reading order in complex layouts. Results are roughly top-to-bottom, left-to-right, but multi-column layouts often require spatial sorting post-processing.

**Important limitation:** Confidence values are model-derived scores, not calibrated probabilities. A 0.92 score does not mean 92% correctness.

---

# 4. Reliability by Input Type

| Input Type | Expected Character Accuracy | Risk Factors | Required Review? |
|------------|----------------------------|--------------|-------------------|
| Typed digital PDF | ~Near-perfect | Encoding anomalies | No (auto-pass allowed) |
| Clean printed scan | High | Skew, shadows | Partial |
| Phone photo of worksheet | Medium | Perspective distortion | Yes |
| Faint photocopy | Medium–Low | Noise, blur | Yes |
| Student handwriting (neat) | Low–Medium | Style variability | Yes (full review) |
| Student handwriting (messy) | Low | Character ambiguity | Yes (mandatory) |
| Math worksheet | Low structural fidelity | Superscripts, fractions | Yes |
| Mixed diagram + text | Text-only reliable | Arrows, spatial meaning | Yes |

The system must assume **error is present unless verified**.

---

# 5. Document Capture Workflow

## 5.1 Best Native Flow

1. Use VisionKit for live scanning.
   - Auto-detect edges
   - Perspective correction
   - Multi-page support

2. Store original captured images unmodified.

3. Run Apple Vision OCR asynchronously.

4. Allow manual photo import and PDF import.

5. If PDF contains embedded text:
   - Extract text directly via PDFKit.
   - Skip OCR.
   - Flag as “trusted digital text.”

---

# 6. OCR Review State Machine

### Document-Level States
- `NotProcessed`
- `Processing`
- `Processed`
- `NeedsReview`
- `Reviewed`
- `Blocked`
- `Failed`

### Line/Span-Level States
- `AutoAccepted`
- `NeedsReview`
- `TeacherCorrected`
- `TeacherConfirmed`
- `Rejected`
- `BlockedFromGrading`

### State Logic

- If average confidence < threshold → `NeedsReview`
- If any line flagged → Document becomes `NeedsReview`
- Grading allowed only when:
  - All relevant spans are `TeacherConfirmed` or `AutoAccepted`
  - No `BlockedFromGrading` spans referenced

---

# 7. Confidence Thresholds

Conservative defaults:

| Confidence | Action |
|------------|--------|
| ≥ 0.97 | Auto-accept unless layout risk |
| 0.90–0.97 | Needs review highlight |
| < 0.90 | Mandatory review |
| < 0.75 | Strong warning; default block |

Additionally, force review if:
- Handwriting detected
- Mixed layout
- Math symbols detected
- Multi-column ambiguity detected

Confidence must be treated as a heuristic gate, not proof of correctness.

---

# 8. Proposed Data Model

## 8.1 SourceFile
- id
- type (photo, PDF, scan)
- originalFileURL
- captureMetadata (device, timestamp)
- pageCount

## 8.2 OCRRun
- id
- sourceFileID
- engineVersion
- recognitionLevel
- languageHints
- timestamp

## 8.3 OCRPage
- id
- pageIndex
- imageReference
- dimensions

## 8.4 OCRLine
- id
- pageID
- boundingBox
- rawText
- topCandidates[]
- confidence
- detectedLanguage
- reviewState

## 8.5 OCRSpan
- lineID
- range
- boundingBox
- confidence
- reviewState
- correctedText
- teacherConfirmedText

## 8.6 EvidenceReference
- rubricCriterionID
- confirmedText
- sourceFileID
- pageIndex
- boundingBox
- ocrSpanID
- timestamp
- teacherConfirmationRequired (Bool)

---

# 9. Linking Grading Evidence to OCR

Every grading comment must store:

- Exact confirmed string
- Character offsets
- Bounding box coordinates
- Page number
- Screenshot snippet hash (optional)
- OCR version

If a teacher edits text, grading references must bind to the **confirmed text**, not raw OCR.

If OCR is re-run, previous evidence must either:
- Be version-locked
- Or marked “needs revalidation”

---

# 10. Handling Complex Worksheets

## 10.1 Columns and Tables
Vision does not return table structure. You must:
- Cluster bounding boxes spatially
- Detect column regions heuristically
- Require teacher confirmation for multi-column detection

## 10.2 Answer Blanks
Blank lines often not recognized. Require teacher to confirm extracted answer only.

## 10.3 Mixed Print and Handwriting
Segment by bounding box size variance and stroke irregularity. Treat handwriting zones as “mandatory review.”

## 10.4 Diagrams and Arrows
Only extract text labels. Never infer relationships.

---

# 11. When OCR Fails

Failure conditions:
- Zero text detected
- Confidence below minimum threshold
- Excessive ambiguity (multiple equal candidates)

System response:
- Mark `Failed`
- Provide manual transcription mode
- Allow grading only from manually confirmed text

Never silently downgrade quality.

---

# 12. Handwriting Roadmap

Current capability in Apple Vision:
- Some handwriting recognition supported
- Performance highly variable

Future local approaches:
- Custom Core ML model trained on classroom handwriting
- Domain-specific character models
- On-device adaptation (if feasible)
- Stroke-based capture for iPad submissions using PencilKit

Realistic stance:
- Handwriting must require teacher confirmation.
- Do not claim reliable handwriting grading.

---

# 13. Math and Diagram Limitations

General OCR does not:
- Parse fractions structurally
- Distinguish superscripts reliably
- Interpret integrals, matrices, geometry diagrams
- Understand chemical subscripts consistently

Structural math recognition requires domain-specific models not included in Vision.

MVP should:
- Treat math-heavy pages as “review required”
- Allow manual correction
- Avoid semantic math grading claims

---

# 14. Teacher Review UX Patterns

## 14.1 Inline Confidence Highlighting
Color-coded confidence bands:
- Green: high
- Yellow: review suggested
- Red: mandatory review

## 14.2 Tap-to-Edit Lines
Teacher taps bounding box overlay → edit panel opens.

## 14.3 Side-by-Side View
Left: original image  
Right: editable text  
Scroll synchronized.

## 14.4 Quick Confirm Buttons
- “Confirm All High Confidence”
- “Mark Page Reviewed”

## 14.5 Evidence Locking Indicator
Show badge when grading uses unreviewed text.

Minimize friction while enforcing verification.

---

# 15. Test Fixture Plan

Create internal dataset:

### Categories
1. Clean typed essays
2. Skewed photos
3. Low-light images
4. Faint photocopies
5. Elementary handwriting
6. Middle-school cursive
7. Mixed worksheets
8. Math-heavy sheets
9. Multi-column layouts
10. Annotated pages with marginal notes

### Metrics
- Character error rate (CER)
- Word error rate (WER)
- Span-level confidence calibration
- Layout detection accuracy
- Review time per page

Create baseline error expectations and monitor regression per OS version.

---

# 16. Acceptance Criteria for MVP

The MVP is acceptable if:

1. All grading text is teacher-confirmed or digitally extracted from trusted PDFs.
2. Every evidence quote is traceable to bounding box and page.
3. OCR uncertainty always triggers visible review.
4. No math or diagram inference is claimed.
5. Handwriting always requires teacher confirmation.
6. Confidence thresholds are configurable.
7. OCR version is stored and auditable.

---

# 17. Product Claims: What to Avoid

Avoid:
- “Full OCR of student work”
- “Automatic handwriting grading”
- “Understands math diagrams”
- “Accurate transcription of worksheets”

Safer claims:
- “On-device text extraction”
- “Teacher-verified OCR”
- “Evidence-linked grading”
- “Human-in-the-loop review”

---

# 18. Future Research Questions

1. Can confidence scores be empirically calibrated using classroom corpora?
2. Can layout clustering improve multi-column reliability?
3. What is the practical handwriting error rate across grade levels?
4. Is math-specific OCR feasible locally via Core ML?
5. Can uncertainty estimation be improved via candidate entropy?
6. How does OCR performance vary across device generations?
7. How to detect when OCR silently omits faint text?

---

# Final Position

A responsible local-first grading assistant must:

- Assume OCR is fallible.
- Treat confidence as heuristic.
- Require explicit teacher confirmation for uncertain text.
- Maintain full evidence traceability.
- Abstain when extraction is unreliable.

Printed text can be supported with structured safeguards. Handwriting, math notation, diagrams, and complex worksheets must remain teacher-verified domains until specialized, validated models are introduced.
