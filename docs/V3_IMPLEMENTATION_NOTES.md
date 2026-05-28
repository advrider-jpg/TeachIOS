# GradeDraft v3 Implementation Notes

v3 is a truth-state and data-model hardening pass. It does not attempt handwriting, visual artifact grading, LMS sync, or cloud services.

## Completed in v3

- Source inputs are represented separately from OCR documents and reviewed student text.
- Image imports/scans are written to local Application Support under `Sources/<assignmentID>/`.
- Each source input stores page index, local relative path, image dimensions, and a deterministic content digest.
- OCR has an explicit review state. Scans/photos set `ocrReviewStatus = needsReview` and block draft grading until the teacher marks OCR reviewed.
- OCR lines now preserve raw text, optional corrected text, confidence, bounding box, and teacher-confirmed state.
- Rubrics are still stored as teacher-authored text, but v3 adds a simple parser for point-bearing criteria and stable criterion IDs.
- The grading packet fingerprint reflects the reviewed text, rubric, instructions, answer key, exemplar, OCR state, assignment metadata, and source references.
- Draft grades carry the packet fingerprint and are marked stale when inputs change.
- Final reviews carry their own packet fingerprint and become stale when inputs change.
- Final criterion scores now preserve both proposed points and teacher-final points.
- Student export and teacher-audit export are separate.
- Student export excludes private teacher notes.
- Teacher-audit export includes OCR state, source references, packet fingerprint, private notes, draft state, final state, and audit events.

## Completed in MVP completion pass (2026-05-28)

- **Manual grading path**: `startManualFinalReview()` in the ViewModel creates a `FinalGradeReview` from parsed rubric criteria or a single teacher-review-required criterion when no rubric is parsed. No AI draft required.
- **Manual grading UI**: "Start Manual Final Review" button is shown in the grading section when reviewed text and at least one grading standard exist, and OCR is not blocking. The button is available even when local AI is unavailable.
- **Full final-review editor**: All `FinalCriterionScore` fields are editable: criterion name, rating, final points, max points, explanation, evidence (add, remove, clear), teacher rationale, and approval toggle.
- **Criterion management**: Add Criterion (appends a blank criterion) and Delete Criterion (removes by ID) with live total recalculation.
- **OCR confirmation dialog**: "Mark OCR reviewed?" uses canonical Section 12.5 copy before calling `markOCRReviewed()`.
- **Approve Final Grade confirmation**: canonical Section 14.5 dialog before final approval.
- **Share-sheet warning**: canonical Section 18.9 dialog before opening `UIActivityViewController` share sheet (replaced raw `ShareLink`).
- **About/Local Privacy section**: in-app section listing what data is stored locally, confirmed-absent features, and deferred features.
- **Source file cleanup**: `deleteCurrentAssignment()` now removes the `Sources/<assignmentID>/` directory (best-effort; errors suppressed to avoid blocking deletion).
- **AI unavailability note**: grading section explicitly labels manual path when local AI is unavailable, with the canonical no-cloud-fallback message.
- **Export section note**: PDF and ZIP are stated as not available in this version.

## Current important limitations

- The persistence layer is GRDB-backed JSON payloads (not a normalized relational schema). Sufficient for MVP, not production-grade.
- Source image digests use `StableFingerprint` (FNV-1a 64-bit), not cryptographic hashing.
- OCR review is document-level only. Per-line correction UI is not implemented.
- Evidence quotes are not linked to OCR bounding boxes or source spans.
- The rubric parser handles `Criterion: 0-N points` patterns only; arbitrary table/markdown rubrics are not fully parsed.
- PDF and ZIP export are not implemented and not exposed in UI.
- Foundation Models integration is SDK-guarded; validation requires Xcode 26+ on a compatible device.
- xcodebuild and SwiftLint validation were not run in this environment (Windows).

## v4 priority order

1. Replace JSON payloads with normalized GRDB schema; add migration tests and backup/restore preflight.
2. Add side-by-side source image and OCR review UI with per-line correction.
3. Link evidence quotes to OCR spans or teacher-confirmed text ranges.
4. Add PDF export (student and teacher-audit templates).
5. Add UI tests for scan/import → OCR review → draft → final → export.
6. Confirm Foundation Models structured-output APIs in the installed SDK.
7. Typed `LocalAIStatus` reasons with canonical copy.
