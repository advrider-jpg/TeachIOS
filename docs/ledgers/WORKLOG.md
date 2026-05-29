# Worklog

## 2026-05-29 — All-features completion source patch

### Baseline inspected

The uploaded `TeachIOS`/`GradeDraft` ZIP was unpacked and treated as the source-of-truth baseline. The requested app, persistence, export, rubric, OCR, view, test, and documentation files were inspected before edits.

### Source changes

- Added `RosterImportService.swift` for CSV roster preview, header/no-header handling, duplicate detection, rejected-row reasons, and normalized preview output.
- Added `CurriculumCatalogService.swift` for an offline curriculum catalog seeded from local Australian Curriculum source materials, filtering, provenance copy, and prompt/report labels.
- Expanded `GradeDraftModels.swift` with roster, curriculum, evidence, OCR rejection, parsed-rubric, backup/restore, source-reference, and export-record models.
- Hardened `GradeDraftViewModel.swift` with PDF import, PDF export, archive export, backup restore, OCR edit/confirm/reject, evidence linking, roster creation, curriculum mapping, rubric preview, and stale-state handling.
- Updated `ContentView.swift` with visible UI paths for import/export, side-by-side OCR review, final-review evidence, rubric preview, curriculum browsing/mapping, roster/gradebook, and backup/restore.
- Updated `PDFExportService.swift`, `BundleExportService.swift`, and `CSVExportService.swift` for real local export/archive behavior and sensitivity/source flags.
- Updated `MarkdownRubricParser.swift` for heading, list, table, points, levels, duplicate, warning, and preview behavior.
- Updated `Database.swift` and `GRDBAssignmentStore.swift` so normalized GRDB rows are written and read as the primary repository path.
- Updated the Xcode project file to include the new Swift source files and test ZIPFoundation linkage.

### Tests added or updated

The test suite now covers PDF exports, archive contents, backup restore, source restoration, PDF import metadata, OCR line edit/confirm/reject, evidence linking, bounding-box privacy, Markdown rubric parsing, curriculum catalog mapping, roster CSV preview, gradebook CSV, normalized DB save/load, compatibility-payload removal, export gating, and sensitivity flags.

### Documentation updated

README, architecture, data model, test plan, implementation notes, next-validation prompt, and ledgers now describe the source-implemented feature set, local-only posture, validation limits, and product boundaries.

### Validation notes

Patch application and static scripts are run on a clean copy after patch generation. Xcode build, XCTest execution, simulator/device smoke tests, SwiftUI runtime flows, Vision/VisionKit behavior, PDFKit/UIKit rendering, and Foundation Models behavior require macOS/Xcode or equivalent Apple tooling.
