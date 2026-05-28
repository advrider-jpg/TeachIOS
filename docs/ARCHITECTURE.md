# Architecture

GradeDraft v2 uses a local, teacher-controlled pipeline:

```text
Assignment setup
  -> rubric template or pasted rubric
  -> scan/import/paste student text
  -> Vision OCR
  -> teacher OCR review
  -> Foundation Models local prompt
  -> structured draft grade
  -> deterministic app normalization
  -> teacher final review
  -> local Markdown export
```

## Design principles

1. **No grading from raw image alone.** The grading service receives teacher-reviewed text, not unreviewed image data.
2. **No grading without a rubric.** The app blocks grade drafting until a rubric or answer key is present.
3. **Evidence-linked scoring.** Each criterion score must cite student text or identify missing evidence.
4. **Teacher final authority.** AI output is a draft only.
5. **Deterministic arithmetic.** The app, not the model, calculates totals.
6. **State separation.** OCR text, model draft, and teacher-final result are distinct fields.
7. **No network by design.** There is no online service adapter.
8. **No silent fallback.** If local AI is unavailable, the app does not call any remote model.

## Main source files

| File | Responsibility |
|---|---|
| `ContentView.swift` | Main SwiftUI workflow, assignment list, capture, rubric, grading, export. |
| `GradeDraftViewModel.swift` | Local app state, persistence orchestration, OCR/grading calls, finalization/export. |
| `Models/GradeDraftModels.swift` | Assignment, OCR, rubric template, grade draft, final review, and error models. |
| `Services/OCRService.swift` | Vision OCR service and reading-order sorting. |
| `Services/FoundationModelGradingService.swift` | Foundation Models capability checks, local grade draft call, JSON parsing. |
| `Services/PromptBuilder.swift` | Strict rubric-grading prompt contract. |
| `Services/GradingService.swift` | Protocols, local validator, model-output normalizer. |
| `Services/GradeTotals.swift` | Deterministic score arithmetic and formatting. |
| `Services/LocalJSONStore.swift` | Local JSON persistence and Markdown report export. |
| `Views/GradeResultView.swift` | Draft/final grade rendering and final-review editing shell. |

## Service boundaries

### OCRServicing

Converts images to an `OCRDocument` with pages, lines, confidence, and bounding boxes.

### GradingServicing

Converts `GradingInput` into a `GradeDraftResult`. The production implementation is `FoundationModelGradingService`.

### CapabilityChecking

Reports local AI availability so the UI can show an honest state.

### AssignmentStoring

Persists and loads assignment records locally. The default implementation stores a pretty-printed JSON file in Application Support.

## Failure behavior

The app fails closed for grading:

- Empty rubric -> no grade draft.
- Empty reviewed student text -> no grade draft.
- Foundation Models unavailable -> no grade draft and no network fallback.
- Malformed model JSON -> parse error.
- Missing evidence -> criterion marked for teacher review.
- Out-of-range score -> score clamped and compliance note added.
- Low-confidence OCR -> OCR review warning, prompt-level uncertainty, and teacher-facing status.

## Data-state separation

`AssignmentRecord` deliberately keeps these separate:

- `reviewedStudentText`: the teacher-reviewed grading input.
- `ocrDocument`: raw OCR lines and confidence metadata.
- `latestDraft`: model-generated draft plus compliance flags.
- `finalReview`: teacher-approved final state.

This prevents the UI from pretending that a model draft is a final grade.
