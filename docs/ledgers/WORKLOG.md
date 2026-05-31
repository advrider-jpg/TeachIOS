# Worklog

## 2026-05-31 — Production CI structure

- Replaced the MVP two-job CI workflow with layered `GradeDraft CI` jobs for static policy, workflow lint, SwiftLint, deterministic Xcode unit/integration tests, screenshot smoke tests, Release build verification, and a combined summary.
- Added shared CI scripts for Xcode 26+ selection, iOS 26+ simulator selection, bad-string scanning, Xcode project membership checks, and CI contract enforcement.
- Split `GradeDraftScreenshotTests` into one test method per captured screen so screenshot failures identify the broken surface.
- Added `GradeDraftProductionPathTests` for app-level export, restore-preview, stale-review, OCR-gating, local-AI-unavailable, and structured-rubric paths.
- Added `docs/CI.md` and updated the test plan with branch-protection guidance, artifacts, local reproduction commands, and the separated screenshot/release validation lanes.

## 2026-05-30 — Apple Intelligence typed grading implementation patch

- Replaced the production raw-JSON Foundation Models draft path with typed guided-generation scaffolding (`FoundationModelGradeProposalSchema.swift`), typed proposal adapters, local prompt budgeting (`GradingPromptBudgeter.swift`), explicit too-large handling, and per-criterion fallback behavior.
- Added selectable AI grading constraint templates (`GradingConstraintTemplates.swift`), local model audit metadata (`LocalModelDraftAudit`), packet-fingerprint participation, persistence fields (migration 007), teacher-audit report output, and UI controls in `RubricInstructionsScreen`.
- Added `FoundationModelErrorMapper.swift` for clean error mapping from Foundation Models errors to `GradeDraftError`.
- Hardened grading validation (`GradingService.swift`) for source-reference alignment, regex-based prohibited inference language, and final-grade language detection.
- Resolved naming conflict: patch's `TeacherInstructionTemplate` renamed to `GradingConstraintTemplate` to avoid collision with existing content-catalog `TeacherInstructionTemplate` in `Content/`.
- Added stale-draft fingerprint guard to `startFinalReviewFromLatestDraft` in `GradeDraftViewModel`.
- Added unit-test coverage (`AppleIntelligenceImplementationTests.swift`) for template selection, prompt inclusion, audit preservation, final-grade language rejection, source-reference review requirements, and budget planning.
- Static validation was run in this environment. Xcode build, XCTest execution, simulator, and real-device Foundation Models validation still require Apple SDK tooling (macOS/Xcode).

## 2026-05-29 — Restore-as-copy source path remap

- Fixed full-backup restore-as-copy so conflicting assignment source refs are remapped from `Sources/<originalAssignmentID>/...` to `Sources/<copiedAssignmentID>/...` and source files are restored under the copied assignment ID.
- Added XCTest coverage for the conflicting restore-as-copy source remap path.
- Ran available local static guardrails; Xcode/plugin validation is blocked in this environment because `xcodebuild` and `xcrun` are unavailable.

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
# 2026-05-31 — PR 21 CI and review-comment fixes

- Fixed export-auth actor isolation and test compile issues found by PR 21 CI.
- Fixed restore-as-copy roster preservation/remapping so local roster rows remain and copied assignments receive remapped roster entries.
- Preserved draft/final review records as stale when rubric text or structured rubric imports change, and reset cached structured criteria when applying rubric templates.
- Local static guardrails were run during the pass; Xcode/XCTest validation is tracked through GitHub Actions for PR 21 because local `xcrun` is unavailable in this Windows environment.
