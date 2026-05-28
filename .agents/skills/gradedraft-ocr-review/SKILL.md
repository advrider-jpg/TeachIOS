---
name: gradedraft-ocr-review
description: Keep OCR review and grading-gate behavior truthful, teacher-visible, and line-accurate.
---

Use this skill when working on OCR, source input, review states, or grading preconditions.

Required file context:
- `GradeDraft/Services/OCRService.swift`
- `GradeDraft/Models/GradeDraftModels.swift`
- `GradeDraft/Services/GradingService.swift`
- `README.md`
- `docs/ARCHITECTURE.md`

Core obligations:
- Treat `OCRDocument`, `OCRLine`, and `OCRReviewStatus` as authoritative text-for-grading source boundaries.
- Never grade from unreviewed OCR when source input came from scan/photo and review status requires it.
- Grade from `reviewedStudentText` only.

Implementation checks before editing:
- Verify OCR outputs carry page/line structure and confidence metadata in use.
- Verify image-to-text path preserves local source references and file persistence.
- Verify grading entry points check OCR status and report blocks in a first-class way.

Review-path behavior:
- If OCR was required but not reviewed, disable Draft Grade and any dependent action with a clear message.
- If OCR is reviewed, persist that state transition as part of local state.
- For low-confidence or unconfirmed lines, show explicit teacher-facing visibility before any grade generation.

Do not fake:
- Do not claim side-by-side review, bounding box links, or per-line corrections are implemented unless the UI and state model actually support them.
- Do not fabricate confidence thresholds or auto-approve behavior without an explicit persisted state change.

After any OCR-related change, ensure tests in `docs/TEST_PLAN.md` and code comments remain aligned to the blocking behavior.
