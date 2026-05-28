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

## Important limitations

- The persistence layer remains JSON-based. It is sufficient for a starter scaffold but not a production-grade classroom database.
- Source image digests use the local `StableFingerprint` helper, not cryptographic SHA-256. This is an app-state fingerprint, not a security guarantee.
- OCR review is document-level in the UI. Per-line correction fields exist in the model, but the UI does not yet provide per-line editing.
- Evidence quotes are not yet linked to OCR bounding boxes or source spans.
- The rubric parser is intentionally simple. It detects lines such as `Claim: 0-4 points`; it does not fully parse arbitrary rubric tables.
- Export is Markdown only. PDF/CSV/ZIP bundle export remains future work.
- Foundation Models integration is still SDK-guarded and needs validation in Xcode 26+ on a compatible device.

## v4 priority order

1. Replace JSON persistence with SQLite or SwiftData-backed repositories.
2. Add migration tests and backup/restore preflight.
3. Add side-by-side source image and OCR review UI.
4. Add per-line OCR correction and teacher confirmation.
5. Link evidence quotes to OCR spans or teacher-confirmed text ranges.
6. Add PDF export with separate student and teacher-audit templates.
7. Add CSV export with spreadsheet formula-injection hardening.
8. Add UI tests for scan/import -> OCR review -> draft -> final -> export.
9. Confirm Foundation Models structured-output APIs in the installed SDK and replace free-form JSON parsing where possible.
