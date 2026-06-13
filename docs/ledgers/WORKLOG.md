# Worklog

## 2026-06-13 — PR CI repair and release-gate split

- Repaired `GradeDraft.xcodeproj/project.pbxproj` by adding the missing file references for the split model files that GitHub Xcode rejected while resolving packages.
- Strengthened `scripts/ci/check_xcode_project_membership.py` so it fails on dangling project object references, not only Swift filenames missing from the project.
- Split ordinary PR/static health from explicit release readiness: `repo_health.py` now aggregates implementation/static guardrails, while `check_release_readiness_static.py` remains a fail-closed manual/scheduled release gate for `Package.resolved`, support/contact, and manual QA evidence.
- Validation: local non-Xcode guardrails pass after the repair; release readiness still fails correctly on unresolved release evidence blockers.

## 2026-06-13 — Audit leftovers: structural split, curriculum shards, OCR batching

- Split `GradeDraftViewModel.swift`, `GradeDraftModels.swift`, `GradeDraftTests.swift`, and `GradeDraftHardeningTests.swift` into domain files while preserving existing behavior and Xcode target membership.
- Replaced the remaining native UI source-shape snapshot helper with rendered hierarchy evidence only.
- Replaced the former large Australian Curriculum runtime catalog with a compact metadata shell, generated search index, and bounded source-key item shards; updated the generator, manifest checksums, project resources, static checks, and production tests for the split format.
- Added a real `OCRLineCorrection` batch mutation path and page-level "Save Page Corrections" review UI so multi-line OCR corrections persist once, with tests for single-save large-page correction, no-save unchanged batches, and failed-save reporting.
- Changed workflow timeline identity to use stable semantic IDs rather than position-derived IDs, with regression coverage.

## 2026-06-12 — Ridiculously close audit completion

- Fixed routed assignment screens to fail closed on stale IDs, scoped rubric previews/import confirmation to the target assignment, and replaced raw export URL sharing with typed prepared export artifacts.
- Hardened normalized GRDB persistence for rubric import state and OCR document/page metadata, blocked low-confidence OCR bulk confirmation, preserved mixed digital/scanned PDF pages, and rolled back newly persisted source files on failed imports.
- Made archive exports fail on requested missing source files, kept raw Shortcut-pasted student text out of `UserDefaults`, added the UserDefaults privacy reason, and tightened release-readiness/support docs so missing release artifacts block visibly.
- Added regression coverage and a route/export truthfulness guardrail wired into repo health and CI.
- Added `GradeDraftUITests/GradeDraftCoreLaneUITests` with a separate `ui-smoke` CI job, made deterministic unit tests skip UI automation explicitly, made release readiness fail on unrun manual QA evidence, and ignored generated Python cache files.

## 2026-06-05 — Local AI v2 readiness, packet preview, and prompt redaction

- Implemented the first production-safe Dream AI slice: deterministic AI readiness reports, local AI packet previews, model-visible identity redaction, prompt-injection risk flags, shared conservative budget planning for preview/generation, and prompt version `gradedraft.foundationmodels.typed.v2`.
- Added deterministic custom-instruction linting for unsafe teacher instruction patterns and wired prompt-safety guardrails into repo health.
- Added deterministic batch AI readiness rows and a static guardrail enforcing no background drafts, final approvals, or student-facing exports from batch readiness.
- Added the dedicated `AIPacketPreviewScreen` and routed `.packetPreview` launch requests to it instead of Final Review. The screen prepares and displays deterministic packet/readiness state only; it does not generate drafts, approve grades, export reports, upload data, or read other students. Added a static guardrail for that route and safety boundary.
- Expanded `LocalCapabilityBanner` copy so real Foundation Models availability messages explain Apple Intelligence disabled, ineligible device, model-not-ready, unavailable framework/OS, manual-review fallback, and Airplane Mode local-only QA reassurance without claiming device proof.
- Added an explicit teacher confirmation sheet before sensitive AI constraints such as EAL/D-sensitive assessment or adjustment context can be selected. The screen still allows immediate deselection, but selection requires confirming the context is teacher-provided, relevant, not inferred from student work, and not a hidden scoring adjustment.
- Expanded draft criterion cards in Final Review so raw local AI suggestions expose confidence, teacher-review reasons, exact evidence quotes, source-reference tags, reviewed-text navigation, and an "Accept, Edit, or Reject" path that starts the teacher-controlled final-review workflow rather than approving anything directly.
- Added runtime context-limit recovery for local drafting: if Foundation Models rejects a full or compact packet for context size, the service retries the next smaller honest mode without truncating reviewed student text or using cloud fallback; per-criterion context failure still fails visibly.
- Final Review can now prepare a packet preview that shows included grading materials, data excluded from the model-visible prompt, generation mode, estimated budget, prompt/packet fingerprints, and a technical prompt preview. Draft generation still calls the guarded local Foundation Models path and does not create final review state without teacher action.
- Hardened both typed Foundation Models prompts and the older canonical prompt renderer so student name, student ID/class identity, roster data, source filenames, and local file paths are not model-visible by default.
- Added local draft progress and cancellation: `GradeDraftViewModel` owns the active draft task, publishes app-controlled pipeline stages, exposes a cancel action, and prevents `latestDraft`/final-review writes when cancellation completes.
- Added focused XCTest coverage for identity redaction, prompt-injection boundaries, readiness flags, packet preview redaction, prompt versioning, and packet fingerprints.
- Added Foundation Models structured streaming requests for local drafts, per-criterion drafts, summary synthesis, and feedback rewrite, while still collecting and validating the final typed result before storage. Added deterministic rubric readiness checks, a read-only local AI tool policy/lookup layer with source-labeled snippets, call/output limits, and audit metadata, a local-only feedback rewrite path for in-progress final reviews, and safe App Intents for workflow handoff, packet preview, blank assignment creation, local title search, and redacted local assignment-entity selection. These paths do not approve grades, export reports, upload data, fetch the web, read other students, or bypass teacher review.
- Added focused XCTest coverage for identity redaction, prompt-injection boundaries, readiness flags, packet preview redaction, prompt versioning, packet fingerprints, local tool policy, rubric readiness, feedback rewrite validation/persistence, and pending App Intent handoff.
- Updated Apple Intelligence, architecture, offline capability, test-plan, and release-readiness docs. Field-by-field partial draft UI, direct Foundation Models tool-calling runtime proof, and physical-device/Airplane Mode proof remain explicit release-gated validation work.

## 2026-06-04 — Guided Grading Wizard (full-screen step-by-step flow)

- Added `GradeWizardView` (in `GradeDraft/Views/`, outside `UI/Screens/` so a scrolling content area is allowed and the screen-manifest/native-refactor checks do not apply): a full-screen, 6-step guided flow for grading one student — Setup → Student Work → Text Review → Rubric → Final Review → Export. A top step indicator shows progress and completion; Back/Next is gated on each step's completion; tapping a step pill jumps to it; the wizard opens at the first incomplete step.
- **Phase 1 (shell + deep-links):** each step shows its status and blocking reasons and offers an "Open …" button that deep-links into the existing focused screen (`StudentWorkScreen`, `ReviewScannedTextScreen`, `RubricInstructionsScreen`, `FinalReviewScreen`, `ExportsRestoreScreen`) via `navigationDestination`.
- **Phase 2 (inline lightweight steps):** Setup edits the assignment's title/student/class/subject/type inline; Export creates the student-facing PDF/Markdown inline (no auth required for student reports) with a Share action, plus a deep-link to all export options.
- **Phase 3 (primary grading entry):** launch points added — a prominent "Start Guided Grading" button on `AssignmentOverviewScreen` (`fullScreenCover`), the class roster's "Continue" now opens the wizard for the next ungraded student, and a context-menu quick-launch on `AssignmentsScreen` rows. The 5-tab bar is intentionally kept for navigation to non-grading areas (Classes/Exports/Settings); the wizard is the primary *grading* entry rather than a full replacement of tab navigation.
- **Phase 4 (tests + accessibility):** gating logic extracted to a pure, testable `GradeWizardProgress` type with `GradeWizardProgressTests` (setup/student-work/text-review/rubric/final-review/export gates, stale-approval handling, ordered first-incomplete, completed count). Step pills, progress, and actions carry VoiceOver labels/values/hints.
- No new dependencies. Native source-fingerprint snapshots for `AssignmentOverviewScreen` and `AssignmentsScreen` are unchanged (no new tracked control tokens or sections). Project membership updated for both new files (app + test target).
- Validation: all local guardrails pass (`check_native_ui_refactor`, `check_xcode_project_membership`, `bad_string_scan`, `check_release_readiness_static`, `check_ci_contract`, `no_network_scan`, `repo_health`). Xcode compile + the new unit tests run in CI (currently blocked by the GitHub Actions spending limit; PR left for CI before merge).

## 2026-06-04 — Fix native-UI guardrail false positive on ScrollViewReader

- `check_native_ui_refactor.py` flagged any `"ScrollView"` substring as a forbidden root scroll container, which falsely tripped on `ScrollViewReader` (added to `RubricInstructionsScreen` for tap-to-scroll). `ScrollViewReader`/`ScrollViewProxy` coordinate scrolling within a native `List`/`Form` and are not root containers. Switched the check to a word-boundary regex (`\bScrollView\b`) so it still forbids a real `ScrollView` container but allows the reader/proxy. No real `ScrollView` containers exist in `UI/Screens`.

## 2026-06-04 — Guided pipeline: explicit stage progress

- The per-assignment `AssignmentOverviewScreen` already implements the guided grading pipeline (a "Next up" card that routes to the correct next screen by status, a 6-step `WorkflowProgressRail`, and a blocking-issues card). The remaining gap was an explicit sense of position in the pipeline.
- Added a compact progress summary to the Timeline card: "Step N of 6" (or "All steps complete") with a percentage and a `ProgressView` bar, derived from how many workflow steps are in a completed state (`onTrack`/`approved`/`readyToExport`/`exported`). Purely additive; reuses the existing `workflowSteps` model and stationery theme.
- No new dependencies or screen files. The native source-fingerprint snapshot for this screen is unchanged (`ProgressView` is not a tracked control token; no new `Section`/headers).
- Validation: local guardrails pass (`repo_health`, `bad_string_scan`, `check_xcode_project_membership`). Xcode compile + the overview snapshot/screenshot tests run in CI (currently blocked by the GitHub Actions spending limit; PR left for CI before merge).
## 2026-06-04 — Final Review workspace: criteria progress + class throughput

- Added a "Criteria approved" count (approved / total) to the Teacher Approval card so the teacher can see review completeness at a glance, alongside the existing approval status and export-readiness rows.
- Added a "Class Throughput" section with a **Next student** button that jumps straight to the next student in the same class who still needs grading (not approved, or approved-but-stale), via `navigationDestination`. This completes the class-set grading loop from inside the review screen so a teacher can grade straight through a stack.
- Self-contained: the next-student lookup filters `viewModel.assignments` directly (no dependency on other in-flight branches). Reuses existing review components and the approval/export plumbing; no new dependencies or screen files.
- Validation: local guardrails pass (`check_xcode_project_membership`, `bad_string_scan`, `repo_health`). Xcode compile + the Final Review snapshot/screenshot tests run in CI (currently blocked by the GitHub Actions spending limit; PR left for CI before merge).
## 2026-06-04 — Class-set grading throughput

- Added a "Class Grading" hero to `ClassDetailRosterScreen`: a progress gauge ("X of Y approved" + percent), a **Continue** button that jumps to the next ungraded student's overview via `navigationDestination`, and class-scoped batch export (gradebook archive ZIP + gradebook CSV) with a Share action. Turns single-record grading into whole-class throughput.
- Added view-model support: `classAssignments(for:)` (records for a class, ordered by student), `nextUngradedAssignment(in:)` (first not-approved or stale), and `exportClassGradebookCSV(for:)` / `exportClassArchive(for:)` — class-scoped mirrors of the existing gradebook exports, routed through the same `authenticateForExportIfNeeded` gate so sensitive teacher-only exports keep their auth requirement.
- No new dependencies; reuses existing export plumbing (`CSVExportService`, `BundleExportService`, `ExportFileHardening`, export records). No new screen file (built into the existing class detail screen), so project membership and the screenshot manifest are unchanged.
- Validation: local guardrails pass (`check_xcode_project_membership`, `bad_string_scan`, `repo_health`). Xcode compile/tests run in CI (currently blocked by the GitHub Actions spending limit; PR left for CI before merge).
## 2026-06-04 — Rubric setup screen redesigned for the iPhone

- `RubricInstructionsScreen` was one Form section stacking nine always-expanded stationery cards plus several 100–150pt editors — an enormous undifferentiated scroll on a phone. Reworked it into a progressive-disclosure layout: a tappable "Setup Checklist" overview at the top (status + one-line state per area), then **collapsible** section cards. Rubric and Detected Criteria start expanded; templates, AI constraints, curriculum, instructions, and answer-key/exemplar start collapsed. Tapping a checklist row expands and scrolls to that section via `ScrollViewReader`.
- Added source-dropped, dependency-free building blocks to `RubricComponents.swift`: `RubricCollapsibleCard` (tap-to-fold stationery card), `RubricOverviewRow` (checklist row), `RubricFlowLayout` (native `Layout`-protocol wrapping flow for chips; reference tevelee/SwiftUI-Flow, krishkumar/FlowLayout, MIT — no package added), `RubricChip`, and `inlineRubricMarkdown` (renders inline Markdown in descriptors via native `AttributedString(markdown:)`).
- Criterion detail now renders descriptors as inline Markdown and shows scoring bands as compact chips that reflow to the screen width. Curriculum mappings show as chips. Body split into per-section computed views to keep type-check load low.
- No new dependencies (decision: native + source-drop). The native source-fingerprint snapshot for this screen is unchanged (same root `Form`, control tokens, and no titled sections).
- Validation: local guardrails pass (`check_xcode_project_membership`, `bad_string_scan`, `repo_health`). Xcode compile + the screen snapshot/screenshot tests run in CI (currently blocked by the GitHub Actions spending limit; PR left for CI before merge).

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
- Updated `ContentView.swift` with visible UI paths for import/export, side-by-side scanned text review, final-review evidence, rubric preview, curriculum browsing/mapping, roster/gradebook, and backup/restore.
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
- Xcode, package resolution, signing, archive, App Store Connect, and physical-device validation remain blocked in this non-Xcode implementation environment and are tracked in release docs.

# 2026-06-02 — Stationery redesign implementation

- Implemented the native SwiftUI stationery redesign across MarkForMe’s shared design system, dashboard/class/assignment/review/rubric/export/privacy surfaces, and local capability banner while preserving native `List`/`Form` roots and teacher-gated flows.
- Fixed hosted CI follow-up issues for the stationery redesign: a SwiftLint identifier violation and a rubric-instructions compile failure from an unclosed stationery page closure.
- Renamed the user-facing app, privacy prompts, report/export copy, content catalog, and curriculum attribution surfaces to MarkForMe while preserving internal GradeDraft project/module/schema identifiers.
- Ran local static validation and diff hygiene checks in this Windows environment; Xcode, XCTest, simulator, and SwiftLint validation remain unavailable because Apple tooling is not installed here.

# 2026-06-05 — Apple Intelligence source-completion slice

- Added safe App Intent launch routing into concrete in-app screens plus local-only Shortcut actions for AI Readiness, latest draft, manual final review, recommended AI constraints, and pasted student work.
- Added a dedicated AI Readiness Center, rubric-side AI readiness and packet-preview warnings, persisted final-review criterion accept/reject actions, and source-review navigation from final-review evidence details.
- Added source tests for App Intent payload/action behavior and criterion decision persistence, structured local tool policy/audit behavior, custom-instruction linting, batch AI readiness behavior, local AI evaluation fixture models/tests, a fixture corpus static guardrail, App Intent, local tool, prompt-safety, and batch-readiness guardrails, and updated Apple Intelligence, architecture, offline capability, test-plan, and production-readiness docs.
- Followed up on PR CI by fixing SwiftLint naming, Swift 6 App Intents metadata/parameter compile issues, duplicate extension helper symbols, invalid bundle ID placeholders, and the core-page screenshot manifest entry for the curriculum browser page.

## 2026-06-12 — Ridiculously-close audit hardening pass

- Fixed fail-closed routed assignment screens, GRDB rubric/OCR round trips, low-confidence OCR review gates, mixed PDF import coverage, protected Shortcut payload staging, typed prepared export state, missing-source archive failures, audience-specific export status, backup JSON clipboard affordance removal, and release-readiness fail-closed checks.
- Added UI smoke target wiring, route/export truthfulness guardrail, final-review evidence-staleness regression coverage, App Intent payload privacy coverage, OCR no-op persistence coverage, and native UI rendered-hierarchy snapshot evidence.
- Consolidated export risk-summary calculation into shared export policy so ViewModel export state and SwiftUI confirmation sheets use one audience/sensitivity source of truth.
- Extracted deterministic mixed-PDF import planning into `PDFImportPlanner` and added unit coverage for scanned-page selection, digital/OCR page merging, and empty OCR page preservation.
- Reduced repeated curriculum lookup cost with bundled-catalog ID and normalized search/filter indexes as an interim step; this was superseded on 2026-06-13 by the generated split catalog shell, search index, and bounded source-key shards. Device performance evidence remains release-gated.
- Updated shared primary/secondary action buttons to use a reusable Dynamic Type-aware multiline label with unlimited wrapping at accessibility text sizes, plus a source guard for that behavior; simulator XXL screenshots remain required before release.
- Local static validation was run on Windows. Xcode package resolution, SwiftLint, XCTest, simulator, Vision/VisionKit, Foundation Models, LocalAuthentication, share-sheet, and device/manual QA validation remain unavailable without Apple tooling.

## 2026-06-13 — Audit miss closure follow-up

- Added regression coverage proving failed photo/PDF imports remove copied source files and restore the visible assignment state when OCR or durable assignment save fails.
- Added clipboard policy coverage proving backup, archive, and PDF artifacts are not clipboard-copyable; only text export kinds can use the explicit clipboard-warning path.
- Re-ran the available static guardrails in the Windows checkout. Release readiness still fails only on real external/release evidence blockers: missing `Package.resolved`, unconfigured support/contact surfaces, and unrun manual QA.

## 2026-06-13 — Routed export and selection hardening follow-up

- Routed guided-grading student exports through the shared export confirmation sheet so the wizard no longer bypasses audience warnings, preview acknowledgement, local authentication policy, or typed prepared-export state.
- Hardened assignment selection so missing routed assignment IDs clear the active selection and mutation/save helpers refuse to update a fallback assignment when no saved record is selected.
- Added UI-test fixture coverage for the approved final-review-to-confirmed-export path and ViewModel regression coverage for rejecting missing assignment IDs without mutating another record.

## 2026-06-13 — Saved-assignment preflight for file-producing actions

- Added a shared saved-assignment preflight for imports, exports, and clipboard copy so invalid or cleared selection cannot create temporary files, copy text, publish artifacts, or record success for a fallback assignment.
- Updated student, teacher, gradebook, archive, backup, PDF import, photo/scan import, and clipboard paths to fail visibly before side effects when no saved assignment is selected.
- Strengthened the route/export truthfulness guardrail and export hardening coverage so this model-level preflight remains enforced.

## 2026-06-13 — Saved-assignment preflight for previews and local AI

- Extended the saved-assignment preflight to source-file lookup, clear-student-work, Markdown rubric preview/import, roster preview/creation, curriculum import, AI readiness, AI packet preview, local draft generation, and feedback rewrite.
- Cleared stale AI readiness/packet preview state when a missing routed assignment clears selection, so no local-AI ready state survives without a saved assignment.
- Added ViewModel hardening coverage and route/export guardrail requirements for the new fail-closed preview and AI boundaries.

## 2026-06-13 — Saved-assignment preflight closure for review and template actions

- Extended fail-closed saved-assignment checks to OCR review mutations, final-review start/edit/approval/evidence actions, rubric/template application, pasted student work, direct rubric text edits, curriculum map/unmap actions, and export audit-record helpers.
- Added regression coverage proving those actions do not mutate the fallback assignment or report helper success after a routed/missing assignment clears selection.
- Tightened the route/export truthfulness guardrail so template, paste, rubric text, curriculum mapping, review, OCR, and export audit-record boundaries remain enforced by static validation.

## 2026-06-13 — Release evidence and stale test expectation closure

- Added a single release-status page and converted the promoted and packaged release blocker registers into owner/status/evidence tables so release materials cannot look complete while support/contact, manual QA, package resolution, signing, and Xcode validation are missing.
- Replaced remaining release-package "replace before release/submission" text with explicit not-configured blocker language and extended the static release-readiness script to catch those placeholder patterns across release docs.
- Added dated provenance/status framing to the grading content source of truth and linked the production checklist/release package to the active blocker/status evidence docs.
- Updated stale XCTest expectations for batch AI budget blocking and low-confidence OCR bulk confirmation so the Xcode suite reflects the current fail-closed product behavior.

## 2026-06-13 — Accessibility labels and PR UI gate closure

- Updated the prepared-export sharing surface so the visible and VoiceOver audience value is the actual student-facing or teacher-only status, while share and clipboard controls announce the artifact and warning requirements.
- Added scanned-text line review accessibility values that include review status, confidence, and reviewed text context for OCR line highlights and editor cards.
- Made the app-driving `ui-smoke` job an ordinary PR-required CI gate, updated the CI contract to prevent label-only UI smoke coverage, and documented the new branch-protection expectation.
- Added curriculum catalog resource-size guardrails for the compact runtime shell, generated search index, and per-shard JSON files so the 55 MB monolith cannot return without a failing validator.
