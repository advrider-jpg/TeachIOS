# Worklog

## 2026-06-04 — Class-set grading throughput

- Added a "Class Grading" hero to `ClassDetailRosterScreen`: a progress gauge ("X of Y approved" + percent), a **Continue** button that jumps to the next ungraded student's overview via `navigationDestination`, and class-scoped batch export (gradebook archive ZIP + gradebook CSV) with a Share action. Turns single-record grading into whole-class throughput.
- Added view-model support: `classAssignments(for:)` (records for a class, ordered by student), `nextUngradedAssignment(in:)` (first not-approved or stale), and `exportClassGradebookCSV(for:)` / `exportClassArchive(for:)` — class-scoped mirrors of the existing gradebook exports, routed through the same `authenticateForExportIfNeeded` gate so sensitive teacher-only exports keep their auth requirement.
- No new dependencies; reuses existing export plumbing (`CSVExportService`, `BundleExportService`, `ExportFileHardening`, export records). No new screen file (built into the existing class detail screen), so project membership and the screenshot manifest are unchanged.
- Validation: local guardrails pass (`check_xcode_project_membership`, `bad_string_scan`, `repo_health`). Xcode compile/tests run in CI (currently blocked by the GitHub Actions spending limit; PR left for CI before merge).

## 2026-06-04 — Markdown rubric parser now AST-driven (swift-markdown)

- `MarkdownRubricParser` previously parsed the rubric with swift-markdown and then discarded the result (`_ = Document(parsing: text)`), doing all real work with a hand-rolled line scanner — the reviewed dependency was decorative. Rewrote `candidateRows` to genuinely walk the swift-markdown `Document` AST: headings, tables (header + body rows, with the delimiter row handled natively rather than string-matched), lists, block quotes, and paragraphs.
- Paragraphs are split on `SoftBreak`/`LineBreak` so consecutive criterion lines without a blank line remain separate criteria (preserving existing behavior and the parser tests). Inline text is read via concrete node types (`Text.string`, `InlineCode.code`) with recursion through emphasis/strong/link containers, because `plainText` is not exposed on the `any Markup` existential in the resolved swift-markdown version. Point/title/ID/level extraction still reuses the shared `RubricParser` helpers, so downstream dedup, stable IDs, ordering, and issue reporting are unchanged.
- Net effect: more robust handling of real teacher markdown (multi-line tables, nested lists, emphasis spans) and swift-markdown is now a genuinely used dependency rather than a faked one.
- Validation: local guardrails pass (`bad_string_scan`, `check_xcode_project_membership`, `repo_health`); Xcode compile + the rubric-parser XCTests run in CI on this branch.

## 2026-06-04 — Rich PDF reports (TPPDF) and CSV dependency consolidation

- Reworked `Export/PDFExportService.swift` to render student and teacher reports with TPPDF: real heading hierarchy, inline `**bold**` emphasis, block quotes, indented (and nested) lists, a repeating page header/footer, page numbers, and automatic pagination. This replaces the prior single-font plain-text flattening. TPPDF was already an OSS-reviewed, app-linked dependency that the source had not yet used; it is now genuinely consumed.
- Kept the previous `UIGraphicsPDFRenderer` output as an internal fallback: if the styled layout pass throws for an unusual report, export still produces a valid PDF rather than failing. The public API, destination-URL contract, safe filenames, and `ExportFileHardening` protection are unchanged.
- Removed the **SwiftCSV** package: it is parse-only and lacks spreadsheet formula-injection hardening. CSV stays on the native `Export/CSVCodec.swift` + `Export/CSVExportService.swift` path, which both reads/writes RFC 4180 CSV and neutralizes formula-like cells (`=`, `+`, `-`, `@`). Unlinked SwiftCSV from the app target in `GradeDraft.xcodeproj/project.pbxproj`.
- Synced governance docs to match: `docs/OSS_REVIEW.md`, `docs/DEPENDENCIES.md`, and the `scripts/ci/check_release_readiness_static.py` package contract no longer list SwiftCSV; TPPDF entries now record actual PDF-rendering usage.
- Removed the **swift-dependencies** package and deleted `Core/AppDependencies.swift`. The Point-Free `Dependencies` container was defined but referenced nowhere; the app already uses initializer-based dependency injection throughout (`GradeDraftViewModel` takes its store, OCR, grading, file-manager, and export-authentication collaborators as `init` parameters). Removing the dead scaffolding leaves a single coherent DI style. Docs and the readiness package contract updated to match.
- Validation: all local guardrails pass (`no_network_scan`, `export_hardening_scan`, `check_release_readiness_static`, `check_xcode_project_membership`, `check_ci_contract`, `bad_string_scan`, `check_native_ui_refactor`, `repo_health`). Xcode compile/test runs in CI on this branch (no Apple SDK on the Windows dev host).

## 2026-05-31 — Core page screenshot workflow

- Added a separate `GradeDraft Core Page Screenshots` GitHub Actions workflow that runs the screenshot XCTest suite on pull requests, pushes to `main`, and manual dispatch, then verifies and uploads the complete core-page PNG set.
- Expanded `GradeDraftScreenshotTests` from workflow-state screenshots to explicit coverage for every concrete core page under `GradeDraft/UI/Screens`, with a manifest check that fails if a screen file lacks a screenshot case.
- Updated CI documentation, test-plan notes, and the CI contract guardrail so the separate screenshot workflow stays tied to the real Xcode/simulator selectors and artifact outputs.

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
# 2026-05-31 — Core UI/UX defect remediation

- Fixed screenshot-audit UI defects across GradeDraft’s native app shell, shared rows/status chips, review queues, student work, scanned-text review, final review, rubric/templates, class roster, export/restore, and privacy surfaces.
- Kept success and readiness states tied to real assignment records, OCR/final-review gates, local export eligibility, and explicit teacher actions; no backend, cloud fallback, analytics, login, mocked persistence, or fake availability paths were added.
- Ran local static validation and line-ending checks; SwiftLint, `xcodebuild`, and simulator tests remain unavailable on this Windows host.

# 2026-05-31 — PR 21 CI and review-comment fixes

- Fixed export-auth actor isolation and test compile issues found by PR 21 CI.
- Fixed restore-as-copy roster preservation/remapping so local roster rows remain and copied assignments receive remapped roster entries.
- Preserved draft/final review records as stale when rubric text or structured rubric imports change, and reset cached structured criteria when applying rubric templates.
- Local static guardrails were run during the pass; Xcode/XCTest validation is tracked through GitHub Actions for PR 21 because local `xcrun` is unavailable in this Windows environment.

# 2026-05-31 — Mega production-readiness source review patch

- Added release configuration files, app-icon asset catalog, Face ID usage description, production static guardrails, curriculum catalog validator, and CI wiring for production readiness checks.
- Replaced the three-item hardcoded Australian Curriculum seed catalog with bundled generated Australian Curriculum Version 9.0 JSON resources, manifest, summary, and a Swift bundle loader plus searchable/map/unmap browser UI.
- Added local-data protection helper and applied backup exclusion/file protection to GRDB, fallback JSON persistence, staged backups, source images, and export hardening paths.
- Removed `MainActor.assumeIsolated` from document-scanner delegate handling.
- Updated prompt, grading-packet, export/audit, dependency, OSS, Australian Curriculum, and release documentation to preserve local-first, teacher-controlled, no-runtime-network boundaries.
- Xcode, package resolution, signing, archive, App Store Connect, and physical-device validation remain blocked in this Linux environment and are tracked in release docs.

# 2026-06-02 — Stationery redesign implementation

- Implemented the native SwiftUI stationery redesign across Mark My Work’s shared design system, dashboard/class/assignment/review/rubric/export/privacy surfaces, and local capability banner while preserving native `List`/`Form` roots and teacher-gated flows.
- Fixed hosted CI follow-up issues for the stationery redesign: a SwiftLint identifier violation and a rubric-instructions compile failure from an unclosed stationery page closure.
- Renamed the user-facing app, privacy prompts, report/export copy, content catalog, and curriculum attribution surfaces to Mark My Work while preserving internal GradeDraft project/module/schema identifiers.
- Ran local static validation and diff hygiene checks in this Windows environment; Xcode, XCTest, simulator, and SwiftLint validation remain unavailable because Apple tooling is not installed here.
