# v2 Implementation Notes

v2 is intentionally more than a skeleton but still short of a finished classroom app.

## Completed in v2

- Assignment list and local persistence.
- Rubric templates.
- OCR metadata preserved on the assignment.
- OCR quality summary and low-confidence review cue.
- Foundation Models availability gate remains no-fallback.
- Strict JSON grading contract.
- Flexible model-output parser.
- Deterministic totals.
- Score bounds normalization.
- Missing-evidence review flags.
- Draft/final state separation.
- Local Markdown export.
- Expanded tests and docs.

## Most important next pass

### Criterion-level final editing

`FinalGradeReviewView` currently lets the teacher edit student feedback and private notes. The next pass should add safe criterion-level editing:

- Editable proposed points per criterion.
- Editable rating label.
- Editable explanation.
- Editable evidence lines.
- Add/remove criterion only behind an explicit “manual rubric override” affordance.
- Deterministic totals recalculated after every edit.
- `teacherEdited = true` whenever any final value changes.

### PDF export

Add a local PDF renderer using SwiftUI/ImageRenderer or UIKit PDF APIs. Do not add a server-side renderer.

### Better OCR review

Add side-by-side image preview and region-level highlights using stored bounding boxes.

### UI tests

Add XCTest UI tests for the no-network, unsupported-model, and template workflows.

### Real Xcode validation

Open in Xcode 26+ and validate the exact Foundation Models API surface against the installed SDK. Keep any SDK-specific adjustments local and do not add a cloud fallback.
