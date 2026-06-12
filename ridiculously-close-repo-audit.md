# Ridiculously Close Repository Audit

## 1. Executive Summary

Release-readiness verdict: **Not ready**.

The repository is much stronger than a typical prototype: it has explicit local-first rules, a serious Swift test suite, static guardrails for network usage, export hardening, source membership, AI prompt safety, App Intent safety, release-readiness checks, and well-developed documentation. The app is not fake at the broad product level. It is a real local-first iOS/iPadOS teacher grading assistant with real OCR review, local draft/final review, local persistence, and privacy-aware export paths.

That said, the repo is not ready for release or TestFlight based on the current audit. The core lane has several high-risk correctness defects and release blockers:

- Wrong-record fallback: many screens load `viewModel.assignment(for: assignmentID) ?? viewModel.assignment`, so an invalid/stale route can mutate or display the wrong assignment instead of failing closed.
- GRDB persistence drops important assignment state, including rubric import mode and confirmed parsed rubric state, which can silently change grading behavior after reload.
- GRDB OCR persistence reconstructs OCR documents without preserving document metadata and derives review state from line flags only.
- Low-confidence OCR lines can become gradeable after "mark all confirmed" without forcing teacher review of every suspect line.
- Mixed digital/scanned PDFs can skip OCR for scanned pages if any digital text exists.
- App Routing stores Shortcut-imported student text in `UserDefaults`, while the privacy manifest does not declare the required reason API category.
- Release docs and static readiness scripts contain optimistic or placeholder release posture despite missing `Package.resolved`, no local Xcode validation in this environment, no simulator/device runtime evidence, no manual QA result, and placeholder support/contact artifacts.

The biggest architectural risk is `GradeDraftViewModel.swift`: it mixes navigation, import, OCR, grading, final review, persistence, export, backup/restore, restore preview, App Intent handoff, feedback, and status messaging in one 129 KB object. It is the center of most correctness, stale-state, and testability problems.

The biggest trust risk is not that the app is fake overall. The bigger problem is that several success states are close to the real operation but not tightly bound enough to durable, correctly reloaded, correctly scoped state. A local-first grading app has a very small margin for this kind of bug because teachers are handling sensitive student work and grades.

Top 20 highest-priority defects:

1. D001: Wrong assignment fallback can display or mutate the active assignment when a routed assignment ID is invalid.
2. D002: GRDB assignment persistence drops rubric import mode and confirmed parsed rubric state.
3. D003: GRDB OCR persistence loses OCR document metadata and reconstructs review state heuristically.
4. D004: Low-confidence OCR lines can be mass-confirmed without explicit teacher inspection.
5. D005: Mixed digital/scanned PDFs can skip OCR for scanned pages.
6. D006: Privacy manifest omits required reason API usage for `UserDefaults`.
7. D007: App Shortcut student text is persisted through `UserDefaults`.
8. D008: Final review evidence edits can stale-lock an in-progress final review.
9. D009: AI batch readiness can mark rows ready without explicit packet budget plans.
10. D010: Source image/PDF import can leave sensitive copied files behind when later persistence fails.
11. D011: Bundle export service silently drops missing source files when called directly.
12. D012: Markdown rubric preview is global, not assignment-scoped.
13. D013: Share UI uses one global `exportURL`, so share affordances can point at the last export rather than the visible context.
14. D014: Export status conflates teacher ZIP/backup and student-facing export readiness.
15. D015: `Package.resolved` is missing and treated as a documented blocker rather than an actual failing release gate.
16. D016: No local Xcode, SwiftLint, simulator, screenshot, or runtime validation was possible in this environment.
17. D017: No XCUITest/app-driving test target was found.
18. D018: `check_release_readiness_static.py` can print "passed" while release blockers remain.
19. D019: Release/privacy docs still reference removed dependencies and placeholder support surfaces.
20. D020: Very large ViewModel, model, test, and JSON files make regressions likely and review expensive.

Top 20 fastest wins:

1. Fail closed on missing assignment IDs in every routed screen.
2. Add `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1` if `UserDefaults` remains.
3. Stop using `UserDefaults` for Shortcut student text or store only opaque transient IDs.
4. Update GRDB schema/load-save path for rubric import mode and confirmed parsed rubric.
5. Persist OCR document metadata in the active GRDB tables.
6. Require explicit review of every low-confidence OCR line.
7. OCR scanned pages in mixed PDFs instead of accepting digital text as whole-document coverage.
8. Scope markdown rubric preview by assignment ID.
9. Replace global `exportURL` with typed export/share state.
10. Make release readiness fail on missing `Package.resolved`.
11. Remove stale dependency references from privacy/release docs.
12. Replace placeholder support contact URLs with final copy or block release.
13. Add one app-driving XCUITest for the core lane.
14. Add a persistence round-trip test for parsed rubric imports.
15. Add a persistence round-trip test for OCR metadata/review state.
16. Add a mixed-PDF import unit test.
17. Add a wrong-route regression test.
18. Split `GradeDraftViewModel` by import, review, export, backup, and routing domains.
19. Move static source-shape tests toward behavior tests.
20. Update manual QA docs with dated evidence or mark unrun.

Top 20 missing tests:

1. Invalid route assignment ID must not fallback to active assignment.
2. Markdown rubric import mode survives app restart through GRDB.
3. Confirmed parsed rubric survives app restart through GRDB.
4. OCR document engine, source, creation date, review date, and review status survive GRDB reload.
5. Low-confidence OCR line cannot be mass-confirmed without explicit teacher action.
6. Mixed digital/scanned PDF OCRs scanned pages.
7. Shortcut import does not persist raw student text in `UserDefaults`.
8. Privacy manifest includes every required reason API used by code.
9. Evidence edit during final review does not stale-lock or incorrectly approve.
10. Batch readiness requires a real budget plan before AI generation readiness.
11. Failed image import rolls back copied sensitive files.
12. Failed PDF import rolls back copied sensitive original.
13. Bundle export reports missing source files instead of silently dropping them.
14. Student export share never exposes teacher audit/private files.
15. Teacher ZIP export never becomes the student's "exported" state.
16. Clipboard copy is unavailable for teacher-only or sensitive bundle exports unless explicitly safe.
17. App restore preview cannot mutate current assignment until confirmed.
18. Dynamic Type XXL buttons do not truncate critical labels.
19. VoiceOver labels distinguish draft, final, student export, and teacher audit actions.
20. Full core lane UI test: paste/import -> OCR review -> draft -> final -> export.

Top 20 documentation fixes:

1. Update `docs/OFFLINE_CAPABILITY.md` to describe GRDB as the primary persistence path, not JSON-only storage.
2. Update release privacy docs to remove SwiftCSV and swift-dependencies references.
3. Make `Package.resolved` absence a hard release blocker, not a checklist footnote.
4. Replace placeholder support/contact docs and HTML.
5. Add a dated manual QA result or explicit "not run" status.
6. Clarify which CI jobs are required before PR merge versus TestFlight.
7. Document the privacy manifest required reason APIs.
8. Document App Shortcut payload handling and data retention.
9. Document GRDB schema coverage for rubric and OCR state.
10. Add release evidence requirements for screenshots and device tests.
11. Separate product-current docs from aspirational roadmap docs.
12. Add owner/date/status columns to release blockers.
13. Clarify that static release readiness is not runtime release readiness.
14. Add export trust matrix: student-safe, teacher-only, backup, archive.
15. Add OCR review invariants for low-confidence lines.
16. Add mixed-PDF import behavior.
17. Add known limitations for Foundation Models availability.
18. Add manual restore/backup QA steps.
19. Add source data provenance status for the 55 MB curriculum JSON.
20. Add agent instruction to fail closed on assignment-ID routing.

Top 20 refactors:

1. Split `GradeDraftViewModel.swift` into routing/session, import, OCR review, draft/final review, export, backup/restore, and status coordinators.
2. Extract assignment-route resolution into one fail-closed API.
3. Move persistence round-trip rules into repository objects.
4. Move OCR document persistence mapping into a dedicated mapper with tests.
5. Move PDF import into a transactional import service.
6. Move source-file persistence into a rollback-capable service.
7. Split `GradeDraftModels.swift` into assignment, rubric, OCR, grading, export, restore, and feedback models.
8. Split `GradeDraftTests.swift` by feature.
9. Split `GradeDraftHardeningTests.swift` by guardrail domain.
10. Split `FinalReviewScreen.swift` into evidence, feedback, final decision, and export panels.
11. Split `RubricInstructionsScreen.swift` into preview/import/editor subviews.
12. Replace global export state with typed export session state.
13. Replace global rubric preview with assignment-scoped preview state.
14. Add a real import transaction boundary.
15. Add an export result model that captures missing source files.
16. Move static check scripts into required, optional, and release-only groups.
17. Move screenshot templates into a fixture directory with clear purpose.
18. Add design-system tokens for button sizing and Dynamic Type.
19. Replace source-text regex tests where behavior tests are feasible.
20. Convert release documents into a single release evidence checklist.

Top 20 UX improvements:

1. Show a hard "assignment not found" state on stale/deep-linked routes.
2. Explain when grading is blocked because OCR review is incomplete.
3. Show low-confidence OCR lines as individually requiring teacher attention.
4. Show per-page PDF import status for digital, scanned, and failed pages.
5. Tie export buttons to the exact export artifact and audience.
6. Separate student-safe exports from teacher audit/backup exports visually.
7. Make batch AI readiness show "budget not checked" as blocked, not merely informational.
8. Replace ambiguous "ready" statuses with exact operation names.
9. Add success messages that name the durable artifact created.
10. Add error messages that name whether persistence, file copy, OCR, or export failed.
11. Add restore preview differences before overwrite.
12. Add privacy copy next to clipboard operations.
13. Improve Dynamic Type layout for one-line buttons.
14. Add keyboard and VoiceOver focus management for review panels.
15. Add empty states for no classes, no assignments, no student work, no OCR lines, no exports.
16. Add import cleanup/retry states.
17. Add visible current assignment context to share/export panels.
18. Add "not available on this device" state for local AI.
19. Add clear unsupported path state for image/PDF types that cannot be processed.
20. Add final-review stale state recovery guidance.

Top 20 anti-fake/product-trust fixes:

1. No routed screen may silently fallback to another assignment.
2. No readiness script should print release passed while release blockers remain.
3. No success message should appear before persistence and audit logging are complete.
4. No Shortcut handoff should store raw student work in generic defaults.
5. No export share affordance should reuse stale global export state.
6. No missing source file should be silently dropped from a sensitive archive.
7. No OCR review state should be inferred from incomplete persisted metadata.
8. No low-confidence OCR line should become reviewed without teacher intent.
9. No mixed-PDF import should imply full capture if scanned pages were skipped.
10. No docs should describe JSON persistence as current if GRDB is primary.
11. No release docs should include placeholder support contacts.
12. No privacy docs should reference removed dependencies.
13. No CI docs should blur PR merge gates and release gates.
14. No "AI ready" state should exist without budget readiness and local availability.
15. No exported state should conflate student report, teacher audit, ZIP archive, and backup.
16. No static source check should substitute for runtime behavior tests.
17. No internal commentary should appear in user-facing settings copy.
18. No source fixture should look like live student data unless clearly labeled.
19. No grade/final state should survive stale source changes without explicit refresh.
20. No report, docs, or UI should claim validation that was not run.

## 2. Product Reality

### What the app appears to do

The app appears to be **GradeDraft**, now externally named **MarkForMe** in several UI surfaces. It is a local-first iOS/iPadOS grading assistant for teachers. The core lane is:

`scan/import/paste -> local OCR -> explicit teacher OCR review -> local rubric/draft support -> teacher final review -> local export`.

This is consistent with:

- `README.md:13-27`, which says the v3 source implementation is complete and describes local AI drafting, curriculum lookup, OCR, rubric review, final review, and export.
- `docs/ARCHITECTURE.md`, which describes a local-first architecture with no backend/cloud in the core lane.
- `docs/OFFLINE_CAPABILITY.md`, which says offline operation is a product invariant, although some persistence details in that doc are stale.
- `docs/ledgers/CORE_RULES.md`, which enforces local-only behavior and teacher finalization.
- `GradeDraft/GradeDraftViewModel.swift`, which implements assignment selection, paste/image/PDF imports, OCR review, draft generation, final review, exports, backups, restore, and App Intent handoff.

### Who the user appears to be

The direct user is a teacher. Secondary beneficiaries are students and school administrators receiving generated student reports, CSV gradebooks, or teacher audit records.

The app's trust model assumes:

- Student work is sensitive.
- Teacher notes and audit bundles are more sensitive than student-facing reports.
- OCR and local AI output are suggestions only.
- The teacher is responsible for final review and final grade approval.

### Main user journeys

1. Create/select class and assignment.
2. Add or import rubric/instructions.
3. Add student work by paste, image scan/import, App Shortcut, or PDF.
4. Review OCR text line by line.
5. Generate or manually prepare a draft.
6. Review suggested grading feedback and evidence.
7. Approve a final grade.
8. Export student report, teacher audit, CSV gradebook, ZIP archive, or backup.
9. Restore from a backup.
10. Use local AI packet preview/batch readiness where available.

### Core entities/data models

Primary entities observed in `GradeDraft/Models/GradeDraftModels.swift`:

- Class/course records.
- Assignment records.
- Student work text and source attachments.
- Rubric text, parsed rubric, rubric import mode.
- OCR documents, pages, lines, bounding boxes, confidence, review status.
- Grading packets and packet fingerprints.
- Draft grading output.
- Final review records and teacher approvals.
- Evidence references and feedback suggestions.
- Export audit records and export statuses.
- Backup/restore preview records.
- Curriculum catalog records.

### Main screens/routes

Observed route/screen files include:

- `GradeDraft/UI/Screens/DashboardScreen.swift`
- `GradeDraft/UI/Screens/ClassDetailRosterScreen.swift`
- `GradeDraft/UI/Screens/StudentWorkScreen.swift`
- `GradeDraft/UI/Screens/ReviewScannedTextScreen.swift`
- `GradeDraft/UI/Screens/RubricInstructionsScreen.swift`
- `GradeDraft/UI/Screens/GradeWizardView.swift`
- `GradeDraft/UI/Screens/FinalReviewScreen.swift`
- `GradeDraft/UI/Screens/ExportsRestoreScreen.swift`
- `GradeDraft/UI/Screens/SettingsAboutLocalPrivacyScreen.swift`
- `GradeDraft/UI/Screens/OnboardingScreen.swift`
- `GradeDraft/UI/Screens/GradingTemplateManagementScreen.swift`
- `GradeDraft/UI/Screens/FrameworkBrowserScreen.swift`
- `GradeDraft/UI/Screens/ReportPreviewScreen.swift`
- `GradeDraft/UI/Screens/BackupRestoreScreen.swift`

### What the repo claims is implemented

The repo claims:

- v3 source implementation complete.
- Local-first operation.
- No backend/cloud/network in the core lane.
- Teacher-gated grading and export.
- Source-first grading packets.
- OCR review before grading.
- Local AI readiness where Apple Foundation Models are available.
- Export hardening and audience separation.
- Static CI guardrails.
- Release-readiness process.

### What appears actually implemented

Much is genuinely implemented:

- Network guardrail passes: `python scripts/no_network_scan.py`.
- Export-hardening guardrail passes: `python scripts/export_hardening_scan.py`.
- Xcode project membership check passes.
- CI contract and AI safety checks pass.
- App Intent safety check passes.
- No obvious network/off-device code was found by the repo script.
- The ViewModel has real import, OCR, draft, final review, export, backup, and restore logic.
- Export services separate student, teacher, CSV, archive, backup, and PDF paths.
- Local JSON snapshot/backup services perform atomic writes.
- Tests are numerous and not merely one or two smoke checks.

### What appears fake, placeholder, incomplete, or aspirational

- Release readiness is aspirational. `docs/release/PACKAGE_RESOLUTION_PENDING.md:3-9` says `Package.resolved` is missing and blocks release, while `scripts/ci/check_release_readiness_static.py:55-58` allows that blocker doc to satisfy the static check.
- Manual QA is not complete. `docs/release/MANUAL_QA_RESULTS.md:3-12` records no manual QA run.
- Support/contact docs contain placeholder deployment values, including `docs/release/SUPPORT_PAGE_COPY.md:37` and `docs/release/support_site/pages/contact.html:14`.
- Runtime validation could not be performed in this environment because `xcodebuild`, `xcrun`, `swift`, `swiftlint`, and `actionlint` are unavailable.
- The privacy manifest does not declare `UserDefaults` required reason API usage even though `GradeDraft/AppRouting.swift:83-90` uses `UserDefaults`.
- The local-first story is strong, but `UserDefaults` carrying raw student work from App Shortcuts is a trust-sensitive implementation choice.

## 3. Verification Log

| Command | Result | What it showed | Failure cause / blocker |
|---|---:|---|---|
| `git status --short --branch` | Pass | On `codex/markforme-release-integration...origin/codex/markforme-release-integration`; initially no source changes visible. | None. |
| `rg --files` | Pass | Enumerated source, tests, docs, scripts, workflows, and release materials. | None. |
| `Get-ChildItem -Recurse -File ... Sort-Object Length -Descending` | Pass | Identified largest files, including 55 MB curriculum JSON and 129 KB ViewModel. | None. |
| `python scripts/no_network_scan.py` | Pass | Reported: `No obvious network/off-device code found.` | Static check only; does not prove runtime privacy. |
| `python scripts/export_hardening_scan.py` | Pass | Reported: `Export-hardening guardrail passed.` | Static check only. |
| `python scripts/repo_health.py` | Pass | Source/tests/scripts/docs checks passed; output says use Xcode for compile/unit tests. | Does not compile app. |
| `python scripts/ci/bad_string_scan.py` | Pass | No unresolved implementation strings in GradeDraft source/tests. | Static text scan only. |
| `python scripts/ci/check_xcode_project_membership.py` | Pass | All 102 Swift source/test files appear in Xcode project. | Does not prove build. |
| `python scripts/ci/check_ci_contract.py` | Pass | CI contract script accepted workflow configuration. | Static script. |
| `python scripts/ci/check_ai_evaluation_fixtures.py` | Pass | 18 fixture cases across 18 categories passed. | Fixture-level only; no live model. |
| `python scripts/ci/check_app_intents_safety.py` | Pass | App Intent static guardrail passed. | Does not catch `UserDefaults` retention issue. |
| `python scripts/ci/check_local_ai_tools.py` | Pass | Local AI tooling static guardrail passed. | No runtime Foundation Models validation. |
| `python scripts/ci/check_ai_prompt_safety.py` | Pass | AI prompt safety static guardrail passed. | Static only. |
| `python scripts/ci/check_ai_batch_readiness.py` | Pass | Batch readiness static guardrail passed. | Does not prove readiness semantics are strict enough. |
| `python scripts/ci/check_ai_packet_preview_screen.py` | Pass | Packet preview screen static guardrail passed. | Static only. |
| `python scripts/ci/check_native_ui_refactor.py` | Pass | Native UI static guardrail passed. | Static only. |
| `python scripts/ci/check_release_readiness_static.py` | Pass | Printed production static readiness passed. | Over-permissive because release blockers remain. |
| `python scripts/curriculum/build_acara_curriculum_catalog.py --check` | Pass | Curriculum catalog check passed. | Generated Python cache artifact in workspace. |
| `python scripts/ci/check_curriculum_catalog.py` | Pass | Curriculum catalog static check passed. | Static/data integrity only. |
| XcodeBuildMCP `session_show_defaults` | Partial | Defaults were empty. | No configured Xcode defaults. |
| XcodeBuildMCP `list_schemes(projectPath:"C:\\TeachIOS\\GradeDraft.xcodeproj")` | Fail | Tried to inspect project. | `spawn xcodebuild ENOENT`; Xcode tools unavailable. |
| XcodeBuildMCP `list_sims` | Fail | Tried to list simulators. | `spawn xcrun ENOENT`; simulator tools unavailable. |
| `where.exe swift xcodebuild xcrun swiftlint actionlint python python3 gh` | Partial | Found Python/Python3/GitHub CLI; did not find Swift/Xcode/actionlint. | Windows environment lacks Apple toolchain and actionlint. |
| `git diff --check` | Pass | No whitespace errors in current diff. | Does not validate source correctness. |
| `git ls-files --eol | Select-String 'w/crlf|i/crlf'` | Informational | Many files have CRLF in working tree on Windows checkout. | Risk of line-ending churn if staged carelessly. |

Commands required by the prompt that could not be completed:

- Dependency installation: no dependency manager install was run because this Xcode project has no reachable Apple build toolchain in this environment and `Package.resolved` is missing by documented release blocker.
- Typecheck/build/unit/integration/e2e: Xcode and Swift toolchain are unavailable here.
- SwiftLint: `swiftlint` unavailable.
- Simulator preview/start: `xcrun` and simulator unavailable.
- Formatting/actionlint: no formatter script found; `actionlint` unavailable.

This blocks release validation, but it did not block static audit, source review, docs review, and script-level verification.

## 4. Feature Claim Matrix

| Claimed or implied feature | Source of claim | Evidence in implementation | Status | Missing / risk |
|---|---|---|---|---|
| Local-first app with no backend/cloud | `README.md`, `docs/ARCHITECTURE.md`, `docs/ledgers/CORE_RULES.md` | `python scripts/no_network_scan.py` passed; no obvious network/off-device code found. | Mostly implemented | Static check only; privacy manifest/UserDefaults issue remains. |
| No analytics/account/login | Docs/core rules | No auth or analytics code surfaced in audit. | Mostly implemented | Needs runtime/privacy review before release. |
| Paste/import student work | UI and `GradeDraftViewModel.swift:551` | `applyPastedStudentText` exists. | Implemented | Route fallback can target wrong assignment. |
| Image import with local source storage | `GradeDraftViewModel.swift:580-607` | Images persisted, assignment saved, success status set after save. | Mostly implemented | Sensitive files can remain if later save fails after file write. |
| PDF import | `GradeDraftViewModel.swift:1234-1315` | Copies original PDF and extracts digital text or images. | Partially implemented | Mixed digital/scanned PDFs can skip scanned-page OCR. |
| OCR review before grading | Core docs; models | `AssignmentRecord.requiresOCRReviewBeforeGrading`, `OCRDocument`, `reviewStatus`. | Mostly implemented | Mass-confirm path can mark low-confidence lines reviewed without individual inspection. |
| Markdown rubric import | `RubricInstructionsScreen.swift`, `GradeDraftViewModel.swift:1319-1340` | Preview and confirm paths exist. | Partially implemented | Preview is global; GRDB persistence drops import mode/confirmed parsed rubric. |
| Local draft generation | README, ViewModel | `draftGrade` and grading packet builder exist. | Implemented but not runtime verified | No local model runtime validation here. |
| Teacher final review | `FinalReviewScreen.swift`, ViewModel | Final review start/approve paths exist. | Mostly implemented | Evidence edits can stale-lock final review. |
| Student report export | Export services, ViewModel | Student markdown/PDF export paths and audit records exist. | Mostly implemented | Global `exportURL` share risk; needs UI validation. |
| Teacher audit export | Export services | Teacher audit markdown and ZIP archive paths exist. | Mostly implemented | Share/clipboard affordance must not expose wrong audience. |
| CSV gradebook export | ViewModel `exportCSVGradebook` | CSV export path and audit record exist. | Implemented | Needs app-driving test. |
| Backup/restore | `LocalJSONStore.swift`, `BackupRestoreScreen.swift` | Backup JSON and restore preview paths exist. | Mostly implemented | Restore UX/runtime not validated. |
| App Shortcuts import | `GradeDraftAppIntents.swift`, `AppRouting.swift` | Pasted student work request handoff exists. | Partially implemented | Raw student text through `UserDefaults`; privacy manifest gap. |
| Local AI packet preview | UI/tests/scripts | Static guardrails pass. | Mostly implemented | Runtime model availability not verified. |
| AI batch readiness | `AIBatchReadiness.swift` | Batch row/status logic exists. | Partially implemented | Can be ready without explicit budget plan. |
| Curriculum catalog | 55 MB JSON and scripts | Curriculum catalog checks pass. | Implemented | Bundle size/startup risk; provenance docs need sharper status. |
| Screenshot evidence | screenshot tests/docs | Screenshot fixtures/tests exist. | Partially implemented | No simulator screenshot run here. |
| Release readiness | release docs/scripts | Static readiness check passes. | Not release-ready | Missing Package.resolved, manual QA, Xcode validation. |
| Support/privacy website copy | release docs/support site | Placeholder support/contact files exist. | UI/docs-only | Not production-ready. |

## 5. Major User Journey Audit

### Journey 1: Create/select assignment and enter work

Entry point: dashboard/class roster/assignment route.

Expected path: select assignment -> add student work -> save durable assignment -> proceed to OCR or grading.

Actual path:

- Screens often resolve an assignment with `viewModel.assignment(for: assignmentID) ?? viewModel.assignment`, including `RubricInstructionsScreen.swift:40`, `StudentWorkScreen.swift:73`, `ReviewScannedTextScreen.swift:13`, and `ExportsRestoreScreen.swift:235`.
- `GradeDraftViewModel.swift:334` selects assignment by arbitrary ID if found but route-level fallbacks bypass fail-closed behavior.

Status: mostly complete but unsafe.

Defect: stale/deep-linked assignment IDs can show or mutate the wrong assignment. A teacher can think they are editing one assignment while the app uses the current active one.

Recommended fix: centralize route assignment resolution and render an explicit "Assignment not found" state with no mutation actions.

Suggested tests: invalid assignment route for every routed screen; assert no mutation occurs and no fallback assignment is displayed.

### Journey 2: Import rubric/instructions

Entry point: Rubric/Instructions screen.

Expected path: paste/import markdown rubric -> preview parsed rubric -> confirm for current assignment -> durable rubric state survives restart.

Actual path:

- `GradeDraftViewModel.swift:1319-1321` stores markdown preview in global `latestRubricPreview`.
- `GradeDraftViewModel.swift:1325-1340` confirms that global preview into the current assignment.
- `GradeDraft/Models/GradeDraftModels.swift:187-188`, `223-224`, `309-310`, `347-348`, and `380-385` model and encode rubric import mode and parsed rubric.
- `GradeDraft/Persistence/Database.swift:349-358` inserts assignment fields without these rubric state fields.
- `GradeDraft/Persistence/Database.swift:480` reconstructs assignment records with rubric text but without preserved import mode/confirmed parsed rubric.

Status: partially implemented.

Defect: parsed rubric state can be lost across GRDB reload and the preview is not assignment-scoped.

Recommended fix: add schema columns or child table for rubric import state; scope preview by assignment ID.

Suggested tests: preview assignment A, switch to B, confirm; restart app; assert A/B rubric state remains correct.

### Journey 3: Paste/import/scan student work and OCR

Entry point: Student Work screen, App Shortcut, image/PDF importer.

Expected path: import content -> persist source securely -> OCR locally -> teacher reviews OCR before grading.

Actual path:

- Paste path exists at `GradeDraftViewModel.swift:551`.
- Image path persists source images before saving assignment at `GradeDraftViewModel.swift:580-607`.
- PDF path copies original and either extracts digital text or OCRs rendered images at `GradeDraftViewModel.swift:1234-1315`.
- Mixed PDF branch at `GradeDraftViewModel.swift:1276-1290` uses digital text if any exists and only OCRs all rendered images when no digital text exists.
- OCR review state can be mass confirmed through `GradeDraftViewModel.swift:649-653` and `OCRDocument.markingAllLinesConfirmed`.

Status: mostly complete but with critical edge-case gaps.

Defects:

- Mixed PDFs can skip scanned pages.
- Low-confidence lines can be mass-confirmed.
- Source files can be orphaned if a file copy succeeds and assignment persistence later fails.

Recommended fix: per-page PDF classification and OCR; review low-confidence lines explicitly; transactional source import with rollback.

Suggested tests: mixed PDF fixture; low-confidence OCR fixture; failing store fixture during image/PDF import.

### Journey 4: Draft grade

Entry point: Grade wizard.

Expected path: validated OCR/rubric/student work -> local draft generation -> teacher sees draft as provisional.

Actual path:

- `GradeDraftViewModel.swift:716` handles drafting.
- `GradeDraftViewModel.swift:757` saves draft output.
- `GradingPacketBuilder.swift:333-344` can return `.unavailable` if budget check is missing.
- `AIBatchReadiness.swift:36-50` uses optional budget plans and can report readiness based on generation mode derived without explicit plan.

Status: mostly complete but rough.

Defect: batch readiness semantics are too permissive for a trust-sensitive "AI ready" state.

Recommended fix: readiness should require explicit successful packet budget plan and local model availability.

Suggested tests: batch row with no budget plan must be blocked; row with failed budget plan must be blocked.

### Journey 5: Final review and approve grade

Entry point: Final Review screen.

Expected path: teacher reviews evidence, feedback, grade -> approves final -> final record remains valid unless source/rubric/student work changes.

Actual path:

- `GradeDraftViewModel.swift:871-882` starts final review from latest draft and records packet fingerprint.
- Evidence editing methods at `GradeDraftViewModel.swift:1728`, `1761`, `1768`, `1797`, `1804`, `1819-1823`, and `1838-1840` mutate evidence references and final review.
- `GradingPacketBuilder.swift:824`, `838`, and `866-868` include evidence references in the packet/fingerprint.

Status: mostly complete but brittle.

Defect: editing evidence during final review can change the packet fingerprint and make the active final review stale or unapprovable, even though the teacher is performing the intended review work.

Recommended fix: separate source packet fingerprint from review annotation fingerprint, or refresh final-review packet metadata on evidence edits.

Suggested tests: start final review, edit evidence, approve final review; assert expected behavior.

### Journey 6: Export/share

Entry point: Final Review, Class Detail, Exports/Restore.

Expected path: export exact artifact for exact audience -> audit log persisted -> share only that artifact.

Actual path:

- Export methods set global `exportURL` and call `recordExport`: `GradeDraftViewModel.swift:1127-1175`.
- ShareLink usage in `ClassDetailRosterScreen.swift:88` and `GradeWizardView.swift:343` uses `viewModel.exportURL`.
- Export status helpers can treat ZIP archive/backup-like artifacts as exported student state, as indicated by `ScreenModels.swift` export readiness and v6 status logic.
- `BundleExportService.swift:88-100`, `133-145`, and `169-188` filter source files to existing files rather than failing by default when called directly.

Status: mostly implemented but trust-sensitive.

Defects: global share state, audience confusion, silent source-file omission risk.

Recommended fix: typed export state keyed by artifact kind and assignment ID; service-level error on missing source file unless caller explicitly requests partial export.

Suggested tests: export student then teacher ZIP, verify share points to selected artifact; missing source file causes user-visible error.

### Journey 7: Backup/restore

Entry point: Exports/Restore and Backup Restore screens.

Expected path: preview backup -> confirm replacement -> local data replaced atomically -> clear status.

Actual path:

- `LocalJSONStore.swift:161-169` has snapshot replacement logic.
- `GradeDraftViewModel.swift:1999-2055` includes backup/export flows.
- Restore preview screens exist.

Status: mostly implemented but not runtime verified.

Missing verification: no simulator or app-driving test run here; no manual QA result.

## 6. Screen-by-Screen UX Audit

| Screen / surface | Purpose clarity | Evidence | UX defects | Status |
|---|---|---|---|---|
| Dashboard | Entry point for classes/assignments/status. | `DashboardScreen.swift` exists; static UI tests exist. | Needs runtime validation; likely source-shaped tests over behavior. | Mostly complete, unverified runtime. |
| Class Detail / Roster | Manage roster and assignment context. | `ClassDetailRosterScreen.swift:88` uses `ShareLink(item: exportURL)`. | Share affordance depends on global last export, not necessarily visible roster context. | Rough. |
| Student Work | Paste/import student work. | `StudentWorkScreen.swift:73` fallback to active assignment. | Wrong assignment fallback; import failure cleanup UX unclear. | Unsafe edge cases. |
| Review Scanned Text | OCR review before grading. | `ReviewScannedTextScreen.swift:13` fallback; OCR model line flags. | Missing fail-closed route state; low-confidence mass-confirm risk. | Partially production-ready. |
| Rubric/Instructions | Rubric text/markdown preview/import. | `RubricInstructionsScreen.swift:40`, `:267`, `:465`, `:473`. | Global preview state; wrong assignment fallback; persistence drop after restart. | Partially implemented. |
| Grade Wizard | Draft and grade flow. | `GradeWizardView.swift:343` share global exportURL. | Share state ambiguity; needs clear blocked states for AI budget/model unavailable. | Mostly complete but rough. |
| Final Review | Teacher finalization. | `FinalReviewScreen.swift`; ViewModel final review methods. | Evidence editing can stale-lock review; dynamic type/accessibility unverified. | Mostly complete but brittle. |
| Exports/Restore | Export, backup, restore. | `ExportsRestoreScreen.swift:235` fallback. | Wrong assignment fallback; student vs teacher artifact status can blur. | Needs trust cleanup. |
| Settings/About/Privacy | Explain local/privacy behavior. | `SettingsAboutLocalPrivacyScreen.swift` exists. | Needs release-copy review; internal implementation notes were reported in copy by subagent and should be checked before release. | Needs polish. |
| Onboarding | First-run product framing. | `OnboardingScreen.swift` exists. | Runtime not inspected visually; must avoid overclaiming AI readiness. | Unverified. |
| Template Management | Manage grading templates. | `GradingTemplateManagementScreen.swift` exists. | Needs test coverage and accessibility validation. | Unverified. |
| Framework Browser | Browse curriculum/framework data. | `FrameworkBrowserScreen.swift`; 55 MB curriculum JSON. | Potential performance and bundle-size issue. | Implemented but heavy. |
| Report Preview | Preview student/teacher output. | `ReportPreviewScreen.swift` exists. | Must clearly label student-safe vs teacher-only outputs. | Needs runtime UX validation. |
| Backup Restore | Restore workflow. | `BackupRestoreScreen.swift`, `LocalJSONStore` restore. | Needs app-driving destructive-action confirmation test. | Mostly complete, unverified. |

Cross-screen UI/UX findings:

- The product terminology is split between GradeDraft and MarkForMe. This may be intentional rebrand-in-progress, but it needs one definitive public name before release.
- Several screens use a stale-route fallback pattern instead of an explicit missing-state. This is both a UX bug and a data safety bug.
- Export/share UX is too global for an app with multiple artifact audiences.
- Static screenshot/source tests are useful, but they do not prove first-glance comprehension, VoiceOver, dynamic type, or actual interaction.

## 7. Anti-Fake and Product Trust Audit

This app is not broadly fake, but several places weaken user trust because they present or imply certainty that the underlying state does not fully support.

| Issue | Evidence | Why it damages trust | Fix |
|---|---|---|---|
| Static readiness can pass while release blockers remain. | `scripts/ci/check_release_readiness_static.py:55-58`, `docs/release/PACKAGE_RESOLUTION_PENDING.md:3-9`. | "Passed" sounds release-ready, but package resolution remains blocked. | Make release blocker fail release readiness. Rename static script if it is not a release gate. |
| Manual QA docs are empty/unrun. | `docs/release/MANUAL_QA_RESULTS.md:3-12`. | Release docs imply a process but provide no evidence. | Add dated device/simulator QA or label as not run. |
| Placeholder support/contact docs. | `docs/release/SUPPORT_PAGE_COPY.md:37`, `docs/release/support_site/pages/contact.html:14`. | Shipping placeholder support breaks credibility and compliance. | Replace with final support URL/contact or block release. |
| UserDefaults stores Shortcut student text. | `AppRouting.swift:83-90`; App Intent text from `GradeDraftAppIntents.swift:319`. | "Local/private" still requires careful retention and privacy disclosure. | Avoid raw text in defaults; use ephemeral in-memory handoff or encrypted app group file with clear lifecycle. |
| Privacy manifest misses UserDefaults required reason category. | `PrivacyInfo.xcprivacy:10` empty `NSPrivacyAccessedAPITypes`; Apple docs list `CA92.1` for UserDefaults. | App privacy declarations are incomplete. | Add required reason API declaration or remove defaults usage. |
| Missing source files silently dropped by bundle export service. | `BundleExportService.swift:88-100`, `133-145`, `169-188`. | Archive can look successful while omitting source evidence. | Fail by default on missing source file and record exact omission if partial export is explicit. |
| Wrong assignment fallback. | `RubricInstructionsScreen.swift:40`, `StudentWorkScreen.swift:73`, `ReviewScannedTextScreen.swift:13`, `ExportsRestoreScreen.swift:235`. | A teacher can unknowingly act on a different assignment. | Fail closed with assignment-not-found state. |
| AI readiness overclaim risk. | `AIBatchReadiness.swift:36-50`; `GradingPacketBuilder.swift:333-344`. | "Ready" without explicit budget/model readiness looks like fake AI availability. | Require budget plan and local model availability for ready state. |
| Export status conflation. | `ScreenModels.swift` export status helpers; global `exportURL`. | Student-safe and teacher-only artifacts can be mentally conflated. | Use audience-scoped export states. |

## 8. Code Correctness Defects

### D001 - Critical - Wrong assignment fallback can mutate the wrong record

Affected files:

- `GradeDraft/UI/Screens/RubricInstructionsScreen.swift:40`
- `GradeDraft/UI/Screens/StudentWorkScreen.swift:73`
- `GradeDraft/UI/Screens/ReviewScannedTextScreen.swift:13`
- `GradeDraft/UI/Screens/ExportsRestoreScreen.swift:235`
- `GradeDraft/GradeDraftViewModel.swift:334`

What code says: screens try to load a requested assignment ID and fallback to `viewModel.assignment`.

What actually happens: if a route/deep link/stale navigation path points to a missing assignment, the visible screen can display or mutate the currently selected assignment.

Why it matters: this is a teacher data safety bug. Work, rubric, OCR review, export, or final grading can be applied to the wrong assignment.

Reproduce/verify: create two assignments, navigate to a routed screen for assignment A, delete or invalidate A, select B, then revisit the stale route. The screen should not show B, but current code pattern can.

Recommended fix: introduce `ResolvedAssignmentRoute` with `.found(record)`, `.missing(id)`, and `.loading` states; remove fallbacks from routed screens.

Suggested tests: one regression per routed screen asserting invalid route IDs do not render mutation controls and do not call ViewModel mutation methods.

Deeper design problem: navigation state is not strongly tied to domain identity.

### D002 - High - GRDB persistence drops rubric import state

Affected files:

- `GradeDraft/Models/GradeDraftModels.swift:187-188`
- `GradeDraft/Models/GradeDraftModels.swift:223-224`
- `GradeDraft/Models/GradeDraftModels.swift:309-310`
- `GradeDraft/Models/GradeDraftModels.swift:347-348`
- `GradeDraft/Models/GradeDraftModels.swift:380-385`
- `GradeDraft/Persistence/Database.swift:349-358`
- `GradeDraft/Persistence/Database.swift:480`

What code says: assignment records include rubric import mode and confirmed parsed rubric.

What actually happens: the GRDB insert/load path does not persist or reconstruct those fields.

Why it matters: a teacher-confirmed parsed rubric can silently become raw/fallback rubric after app restart, changing grading packet content.

Reproduce/verify: import markdown rubric, confirm parsed rubric, persist to GRDB, reload assignment, compare `rubricImportMode` and `confirmedParsedRubric`.

Recommended fix: add GRDB schema coverage and migration for rubric import mode and confirmed parsed rubric, with backward-compatible defaults.

Suggested tests: GRDB round-trip test for parsed rubric import.

Deeper design problem: model Codable support and database schema are out of sync.

### D003 - High - GRDB OCR persistence loses document metadata and infers review state

Affected files:

- `GradeDraft/Persistence/Database.swift:228`
- `GradeDraft/Persistence/Database.swift:390-396`
- `GradeDraft/Persistence/Database.swift:532-556`
- `GradeDraft/Models/GradeDraftModels.swift:1253-1259`

What code says: OCR documents have metadata such as engine, source, created date, review status, reviewed date.

What actually happens: active normalized load reconstructs `OCRDocument` from lines/pages and derives review status from `needsReview`, losing document-level metadata.

Why it matters: auditability and user-facing review state can change after reload. OCR provenance is core to teacher trust.

Reproduce/verify: create OCR document with non-default metadata/reviewed date, save through GRDB, reload, compare fields.

Recommended fix: persist document-level OCR metadata in active tables and reconstruct exactly.

Suggested tests: OCR document metadata round-trip and reviewed state round-trip.

Deeper design problem: normalized persistence tables do not cover the full domain model.

### D004 - High - Low-confidence OCR lines can be mass-confirmed

Affected files:

- `GradeDraft/GradeDraftViewModel.swift:649-653`
- `GradeDraft/GradeDraftViewModel.swift:1636-1645`
- `GradeDraft/GradeDraftViewModel.swift:1721`
- `GradeDraft/Models/GradeDraftModels.swift:1313-1318`
- `GradeDraft/Models/GradeDraftModels.swift:1325-1328`
- `GradeDraft/Models/GradeDraftModels.swift:1430-1432`

What code says: OCR lines need review if low confidence or not teacher-confirmed, and grading should wait for OCR review.

What actually happens: `markingAllLinesConfirmed` can mark all lines confirmed, then `applyOCRReviewState` checks only whether unconfirmed lines remain.

Why it matters: the app can claim OCR review is complete even when low-confidence text was not specifically inspected.

Reproduce/verify: create document with low-confidence line, call mark-all-confirmed path, verify grading becomes unblocked.

Recommended fix: keep `needsReview` true for low-confidence lines until each line is explicitly reviewed or edited.

Suggested tests: low-confidence line must block grading after bulk confirm.

Deeper design problem: "confirmed" and "needs review" are conflated.

### D005 - High - Mixed digital/scanned PDFs can skip scanned pages

Affected files:

- `GradeDraft/GradeDraftViewModel.swift:1234-1315`
- `GradeDraft/GradeDraftViewModel.swift:1276-1290`
- `GradeDraft/GradeDraftViewModel.swift:2457-2479`

What code says: PDF import extracts digital PDF text, otherwise OCRs rendered page images.

What actually happens: if any digital text exists, the code uses digital text path for the document. Scanned pages in a mixed PDF can be skipped.

Why it matters: student work can be partially omitted without an obvious error, causing incorrect grading.

Reproduce/verify: import a PDF with one text page and one scanned-image page. Verify whether OCR is run for the scanned page.

Recommended fix: classify each PDF page; use digital text where present and OCR only pages without text.

Suggested tests: mixed PDF fixture with expected page count and text coverage.

Deeper design problem: import pipeline treats PDF as one mode instead of per-page source.

### D006 - High - Privacy manifest omits required reason API for UserDefaults

Affected files:

- `GradeDraft/AppRouting.swift:83-90`
- `GradeDraft/Resources/PrivacyInfo.xcprivacy:10`

What code says: App Routing stores and removes Shortcut handoff data through `UserDefaults`.

What manifest says: `NSPrivacyAccessedAPITypes` is empty.

Why it matters: Apple's required reason API documentation includes UserDefaults under `NSPrivacyAccessedAPITypeUserDefaults`, with reason code `CA92.1` for app use. Sources checked: `https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype` and `https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api`. This is a release/compliance risk.

Reproduce/verify: inspect `AppRouting.swift` for `UserDefaults` and `PrivacyInfo.xcprivacy` for accessed API declarations.

Recommended fix: either remove UserDefaults usage for this path or declare the required reason API accurately.

Suggested tests: static manifest check that scans for UserDefaults usage and required reason declaration.

Deeper design problem: privacy manifest is not mechanically checked against source APIs.

### D007 - High - App Shortcut handoff stores raw student work in UserDefaults

Affected files:

- `GradeDraft/AppIntents/GradeDraftAppIntents.swift:292`
- `GradeDraft/AppIntents/GradeDraftAppIntents.swift:319`
- `GradeDraft/AppRouting.swift:30`
- `GradeDraft/AppRouting.swift:83-90`
- `GradeDraft/GradeDraftViewModel.swift:365`

What code says: `AddPastedStudentWorkIntent` accepts text and writes an app route request with `payloadText`.

What actually happens: raw student work can be persisted in `UserDefaults` until consumed.

Why it matters: this is sensitive student content. It is local, but not scoped, encrypted, or lifecycle-managed like assignment storage.

Reproduce/verify: trigger App Intent and inspect defaults before app consumes route.

Recommended fix: use an ephemeral in-memory handoff when possible; otherwise store an encrypted transient file with TTL and deletion guarantees.

Suggested tests: App Intent import does not leave raw text in defaults after launch/consume/failure.

Deeper design problem: route handoff layer is doing persistence.

### D008 - Medium/High - Final review evidence edits can stale-lock approval

Affected files:

- `GradeDraft/GradeDraftViewModel.swift:871-882`
- `GradeDraft/GradeDraftViewModel.swift:1728`
- `GradeDraft/GradeDraftViewModel.swift:1761`
- `GradeDraft/GradeDraftViewModel.swift:1768`
- `GradeDraft/GradeDraftViewModel.swift:1797`
- `GradeDraft/GradeDraftViewModel.swift:1804`
- `GradeDraft/GradeDraftViewModel.swift:1819-1823`
- `GradeDraft/GradeDraftViewModel.swift:1838-1840`
- `GradeDraft/Content/GradingPacketBuilder.swift:824`
- `GradeDraft/Content/GradingPacketBuilder.swift:838`
- `GradeDraft/Content/GradingPacketBuilder.swift:866-868`

What code says: final review captures packet fingerprint; evidence references are included in packet/fingerprint.

What actually happens: intended evidence edits during review can change the source fingerprint and invalidate the current final review.

Why it matters: teacher review workflow can dead-end or behave inconsistently.

Recommended fix: distinguish source-content fingerprint from review-annotation fingerprint.

Suggested tests: start final review, add/remove/merge evidence, approve final review.

### D009 - Medium - AI batch readiness can be ready without explicit budget plan

Affected files:

- `GradeDraft/AI/Batch/AIBatchReadiness.swift:36`
- `GradeDraft/AI/Batch/AIBatchReadiness.swift:40`
- `GradeDraft/AI/Batch/AIBatchReadiness.swift:47-50`
- `GradeDraft/AI/Batch/AIBatchReadiness.swift:88`
- `GradeDraft/Content/GradingPacketBuilder.swift:333-344`

What code says: local AI generation should be budget-checked.

What actually happens: optional budget plans default to empty, and readiness can be computed from assignment readiness rather than explicit successful budget check.

Why it matters: a teacher may see "ready" or batch-enabled status when the model cannot actually generate.

Recommended fix: require explicit `budgetPlan.status == .ready` for generation readiness.

Suggested tests: no budget plan -> not ready; failed budget plan -> not ready.

### D010 - Medium/High - Sensitive import files can be orphaned after persistence failure

Affected files:

- `GradeDraft/GradeDraftViewModel.swift:580-607`
- `GradeDraft/GradeDraftViewModel.swift:1234-1315`
- `GradeDraft/GradeDraftViewModel.swift:2401` vicinity

What code says: source files are persisted, then assignment is saved.

What actually happens: if file persistence succeeds and assignment save fails, copied sensitive files may remain without assignment ownership.

Why it matters: local-first privacy requires cleanup of failed imports.

Recommended fix: transactional import service with rollback of copied source files on save failure.

Suggested tests: inject store save failure and assert source file directory is cleaned up.

### D011 - Medium - Bundle export service silently drops missing source files when called directly

Affected files:

- `GradeDraft/Export/BundleExportService.swift:88-100`
- `GradeDraft/Export/BundleExportService.swift:133-145`
- `GradeDraft/Export/BundleExportService.swift:169-188`
- `GradeDraft/Export/BundleExportService.swift:361-365`
- `GradeDraft/Export/BundleExportService.swift:377-381`

What code says: archive export includes source files and has symlink/path hardening.

What actually happens: service filters to existing files, so missing source files can be omitted without service-level failure if caller bypasses ViewModel preflight.

Why it matters: teacher audit archive can look complete while omitting evidence.

Recommended fix: service should fail by default if requested source file is missing.

Suggested tests: direct service call with missing source file throws and surfaces missing paths.

## 9. Performance and Efficiency Defects

| ID | Severity | Evidence | Bottleneck | User impact | Fix |
|---|---|---|---|---|---|
| P001 | High | `GradeDraft/Resources/JSON/curriculum_catalog_acara_v9.json` is 55,302,692 bytes. | Large bundled JSON. | Larger app, slower cold loads if decoded eagerly, more memory pressure on older iPads. | Lazy index, split catalog by jurisdiction/year/subject, compress or store in SQLite. |
| P002 | High | `GradeDraft/GradeDraftViewModel.swift` is 129,960 bytes. | Huge observable object likely invalidates many screens. | Unnecessary SwiftUI rerenders and hard-to-isolate state changes. | Split stores/coordinators; minimize published state. |
| P003 | Medium | `GradeDraft/Models/GradeDraftModels.swift` is 84,769 bytes. | Huge model file with many domains. | Slow reviews and risk of broad recompilation. | Split by domain. |
| P004 | Medium | PDF import renders/extracts in one ViewModel path. | Potential synchronous heavy work near UI state. | Large PDFs can block UI or produce poor progress states. | Async per-page import pipeline with progress and cancellation. |
| P005 | Medium | OCR line edit/review paths persist assignment repeatedly. | Repeated full assignment saves. | Large OCR docs can feel sluggish during line-by-line review. | Batch line edits or debounce saves with explicit durable state. |
| P006 | Medium | `FrameworkBrowserScreen.swift` plus huge catalog. | Search/filter over large static payload risk. | Browser may lag on device. | Precomputed indexes and virtualization. |
| P007 | Low/Medium | `ProgressComponents.swift:85` uses enumerated offset identity. | Reordering can cause unnecessary view churn. | Visual glitches if steps change. | Use stable step IDs. |
| P008 | Low | `GradeDraftViewModel.swift:1845-1848` source image reads use `try? Data(contentsOf:)`. | Synchronous file read. | UI stalls on large images. | Async image loading/cache. |
| P009 | Low/Medium | Source-shaped tests scan large source files. | Test suite overhead and brittleness. | Slower CI, false failures on refactors. | Replace with behavior tests where possible. |
| P010 | Low | Many static checks run serially in CI. | Script overhead. | Longer CI. | Group fast checks and parallelize jobs if CI time grows. |

## 10. Architecture and File Organization Defects

The codebase has a real architecture, but key boundaries are overgrown.

Most problematic files:

| File | Size | Problem | Recommended split |
|---|---:|---|---|
| `GradeDraft/Resources/JSON/curriculum_catalog_acara_v9.json` | 55,302,692 bytes | Huge bundled data file. | Split or convert to indexed store. |
| `GradeDraft/GradeDraftViewModel.swift` | 129,960 bytes | God ViewModel. | `AssignmentSessionStore`, `StudentWorkImportService`, `OCRReviewCoordinator`, `DraftGenerationCoordinator`, `FinalReviewCoordinator`, `ExportCoordinator`, `BackupRestoreCoordinator`, `RouteHandoffCoordinator`. |
| `GradeDraftTests/GradeDraftTests.swift` | 133,918 bytes | God test file. | Split by assignment, OCR, rubric, draft, final review, export, restore. |
| `GradeDraftTests/GradeDraftHardeningTests.swift` | 105,096 bytes | Large mixed hardening suite. | Split into privacy, export, local AI, OCR, App Intent, docs guardrails. |
| `docs/GRADING_CONTENT_SOURCE_OF_TRUTH.md` | 104,429 bytes | Large source-of-truth doc. | Split into source provenance, rubric policy, packet format, fixtures. |
| `GradeDraft/Models/GradeDraftModels.swift` | 84,769 bytes | Many domains in one file. | Assignment, OCR, rubric, grading, export, backup, curriculum model files. |
| `GradeDraft/Persistence/Database.swift` | 63,298 bytes | Schema, migration, load/save mapping in one file. | Schema definitions, migrations, assignment repository, OCR repository, export repository. |
| `GradeDraft/Export/BundleExportService.swift` | 46,335 bytes | Archive building, hashing, safety validation. | Archive manifest, source collector, writer, sanitizer. |
| `GradeDraft/Content/GradingPacketBuilder.swift` | 44,113 bytes | Packet build, budget, fingerprinting. | Packet assembler, budget calculator, fingerprinting, validation. |
| `GradeDraft/UI/Screens/FinalReviewScreen.swift` | 43,561 bytes | Large screen with many responsibilities. | Evidence panel, feedback panel, approval panel, export panel. |
| `GradeDraft/UI/Screens/RubricInstructionsScreen.swift` | 41,958 bytes | Import, preview, editing, confirmation in one screen. | Rubric editor, markdown preview, import confirmation, status panel. |
| `GradeDraft/Services/LocalJSONStore.swift` | 29,857 bytes | Local snapshot persistence, exports, restore. | Snapshot writer, report writer, restore service, audit writer. |

Architectural smells:

- Domain, UI, persistence, and routing logic are mixed in `GradeDraftViewModel`.
- There are two persistence stories: GRDB primary runtime and JSON backup/snapshot services. Docs do not consistently explain this split.
- Several static tests enforce source shape instead of domain behavior, which makes refactors expensive and can miss runtime bugs.
- Export state is global rather than typed by assignment/artifact/audience.
- Assignment routing is decentralized and unsafe.

## 11. Custom CSS and Component Audit

This is a SwiftUI app, so the relevant equivalent to custom CSS is custom SwiftUI design-system code and hand-rolled controls.

Custom component areas:

| Component area | Evidence | Assessment | OSS/native recommendation |
|---|---|---|---|
| Buttons/design system | `GradeDraft/UI/DesignSystem/Buttons.swift` | Useful centralization, but one-line labels and fixed presentation can be brittle with Dynamic Type. | Prefer native `Button` styles with multiline support and measured min heights. |
| Progress/step components | `GradeDraft/UI/DesignSystem/ProgressComponents.swift:85` | Uses enumerated offset identity; acceptable for static lists but fragile if order changes. | Use stable IDs. |
| Custom review flows | `FinalReviewScreen.swift`, `ReviewScannedTextScreen.swift` | Domain-specific custom UI is appropriate. | Keep custom, but add accessibility and UI tests. |
| Export/share panels | Export screens and `ShareLink` usage | Custom state model is weak; global URL is not enough. | Native `ShareLink` is fine, but wrap in typed artifact state. |
| Restore preview | Backup/restore screens | Custom is appropriate because data ownership is domain-specific. | Add destructive confirmation and diff component. |
| Framework browser | `FrameworkBrowserScreen.swift` | Custom list/search may be heavy with huge catalog. | Use lazy lists, indexes, and search tokens; avoid third-party unless native performance fails. |
| Markdown/rubric preview | `RubricInstructionsScreen.swift` | Custom parser/preview is domain-specific. | Keep custom but persist parsed state and scope preview. |

Design-system problems:

- No full runtime Dynamic Type verification was possible.
- One-line button labels risk truncating action verbs and trust-sensitive labels.
- Export artifact/audience styling needs stronger visual distinction.
- Some screens are likely too dense because very large SwiftUI screen files contain multiple states and panels.
- Source tests can enforce UI text but cannot validate visual hierarchy.

No blanket recommendation to add a component library: native SwiftUI components are the right default for this app. The biggest issue is not lack of OSS UI components; it is state modeling and domain-specific safety.

## 12. Test Coverage Audit

Frameworks and test types observed:

- Swift/XCTest unit tests in `GradeDraftTests`.
- Static source/guardrail Python scripts in `scripts/ci` and root `scripts`.
- Screenshot-oriented tests in `GradeDraftTests/GradeDraftScreenshotTests.swift`.
- Native UI/source snapshot checks in `GradeDraftTests/NativeUIRefactorSnapshotTests.swift`.
- AI fixture tests in `GradeDraftTests/AIEvaluationFixtureTests.swift`.

What runs here:

- Python/static checks listed in Section 3 passed.

What did not run here:

- Xcode unit tests.
- Swift typecheck/build.
- SwiftLint.
- XCUITest.
- Simulator screenshots.
- Device/manual QA.

Coverage strengths:

- Strong static guardrails for no network, export hardening, AI prompt safety, App Intent safety, Xcode project membership, local AI shape, and release docs.
- AI fixture tests assert no live model attempt in fixtures (`AIEvaluationFixtureTests.swift:70`).
- Screenshot/source tests give some protection against accidental UI drift.

Coverage weaknesses:

- No app-driving XCUITest target was found (`rg "XCUIApplication"` returned no app-driving test usage).
- Several tests are source-shape tests rather than behavior tests.
- Critical persistence round trips are missing for rubric import state and OCR metadata.
- Mixed PDF, low-confidence OCR review, route fallback, global export URL, and Shortcut UserDefaults retention are not adequately covered by visible tests.
- Manual QA evidence is absent.

Missing-test matrix is in Appendix B.

## 13. Documentation Audit

| Document | Issue | Evidence | Fix |
|---|---|---|---|
| `README.md` | Strong but optimistic. Claims source implementation complete; release gates require external validation. | `README.md:13-27`, `README.md:95`, `README.md:139`. | Add current "not release validated locally" state and blockers. |
| `docs/OFFLINE_CAPABILITY.md` | Stale persistence description. | `docs/OFFLINE_CAPABILITY.md:25-27` says JSON storage under Application Support. | Update to GRDB primary plus JSON backup/export. |
| `docs/ARCHITECTURE.md` | Generally aligned, but should call out GRDB schema coverage gaps. | Source vs persistence mismatch found. | Add persistence model/schema contract. |
| `docs/TEST_PLAN.md` | Needs to distinguish static checks from runtime validation. | Xcode unavailable here; static scripts pass. | Add required app-driving smoke before release. |
| `docs/release/PRIVACY_REVIEW.md` | Stale dependency references. | `docs/release/PRIVACY_REVIEW.md:34` references removed SwiftCSV/swift-dependencies. | Remove or mark historical. |
| `docs/OSS_REVIEW.md` | Says deps removed; conflicts with privacy review. | `docs/OSS_REVIEW.md:19-20`. | Cross-link from privacy review to current dependency state. |
| `docs/DEPENDENCIES.md` | Current dependency state appears no third-party runtime deps. | `docs/DEPENDENCIES.md:16`. | Use this as source of truth. |
| `docs/release/PACKAGE_RESOLUTION_PENDING.md` | Release blocker exists. | `docs/release/PACKAGE_RESOLUTION_PENDING.md:3-9`. | Make static readiness fail until resolved. |
| `docs/release/PRODUCTION_READINESS_CHECKLIST.md` | Many unchecked runtime/manual items. | `docs/release/PRODUCTION_READINESS_CHECKLIST.md:11`, `:41-79`. | Add dated owner/status/evidence columns. |
| `docs/release/MANUAL_QA_RESULTS.md` | No QA run. | `docs/release/MANUAL_QA_RESULTS.md:3-12`. | Fill after simulator/device run or keep as explicit release blocker. |
| `docs/release/SUPPORT_PAGE_COPY.md` | Placeholder support copy. | `docs/release/SUPPORT_PAGE_COPY.md:37`. | Replace before release. |
| `docs/release/support_site/pages/contact.html` | Placeholder contact page. | `docs/release/support_site/pages/contact.html:14`. | Replace or remove from release package. |
| `.github/workflows/swift.yml` docs/CI relationship | CI has optional release jobs. | `.github/workflows/swift.yml:157`, `:251`, `:352`, `:400`, `:461-462`; `docs/CI.md:12-14`, `:147-156`. | Make required/recommended/release gates unambiguous in one table. |

## 14. Agent Instructions Audit

Agent instructions are unusually strong on truthfulness, local-first constraints, and validation honesty. They are directionally correct for this repo.

Strengths:

- Explicitly forbids fake state, placeholder logic, and fake completion.
- Defines core lane and no-cloud/no-backend/no-analytics posture.
- Requires relevant validation evidence and honest unavailable status.
- Defines ledger update discipline.
- Tells CI/debugging agents to inspect exact logs before guessing.

Defects:

- AGENTS includes drift-prone GitHub popularity/release claims for external tools. Those claims can become stale and should not be hardcoded.
- The "must fix existing fake state while working" rule is too broad for audit-only or scoped tasks. It conflicts with the user's explicit audit-only boundary unless interpreted carefully.
- It does not explicitly say routed assignment IDs must fail closed.
- It does not require privacy manifest checks when adding APIs like `UserDefaults`.
- It does not distinguish static readiness from release readiness.

Recommended stronger structure:

1. Product invariants: local-first, teacher-final, no backend.
2. Data safety invariants: fail closed on assignment identity, no raw student data in generic persistence, source export completeness.
3. AI/OCR invariants: no fake AI availability, low-confidence OCR requires explicit teacher action.
4. Export invariants: audience-scoped artifact state, no silent omission.
5. Validation matrix: static, build, unit, UI, manual/device, release.
6. Audit-only exception: when user requests audit-only, report issues but do not patch source.
7. Ledger policy.

## 15. Work Log, Changelog, and Register Audit

Observed tracking docs:

- `docs/ledgers/CORE_RULES.md`
- `docs/ledgers/WORKLOG.md`
- `docs/ledgers/PROJECT_LEDGER.md`
- `docs/ledgers/DATA_LEDGER.md`
- `docs/ledgers/DECISIONS_LEDGER.md`
- `docs/ledgers/VALIDATION_LEDGER.md`
- release checklist docs under `docs/release`
- CI docs under `docs/CI.md`

Findings:

- Ledger discipline exists and is useful.
- Release docs duplicate state across production checklist, manual QA, package resolution, privacy review, and support-site docs.
- Some release docs are stale relative to dependency docs.
- Manual QA and package resolution blockers are documented but not enforced strongly enough by readiness script.
- Static readiness output is too confident for a repo with documented release blockers.

Recommended future structure:

- `docs/release/RELEASE_STATUS.md`: single current release gate table with owner, status, date, evidence link.
- `docs/release/RELEASE_BLOCKERS.md`: only active blockers, each with reproduction and exit criteria.
- `docs/release/MANUAL_QA_RESULTS.md`: dated run logs only.
- `docs/release/PRIVACY_REVIEW.md`: current dependencies/APIs only, with historical notes moved to appendix.
- Keep ledgers for durable decisions, not day-to-day release checklist churn.

## 16. Build, Deployment, and Environment Audit

Build environment facts:

- Local shell is Windows/PowerShell.
- Apple tools are unavailable: `swift`, `xcodebuild`, `xcrun`, `swiftlint`, and `actionlint` were not found.
- XcodeBuildMCP failed because it could not spawn `xcodebuild` or `xcrun`.
- GitHub CLI and Python are available.

Build/deployment risks:

- `Package.resolved` missing is a documented release blocker.
- Release readiness static script passes despite missing package resolution.
- Optional CI jobs for screenshots/release/archive are not equivalent to required merge checks.
- No local Xcode build/test evidence exists from this audit.
- No manual QA evidence exists in release docs.
- Support/contact placeholder docs are not production-ready.
- Privacy manifest is incomplete for observed `UserDefaults` usage.

Environment classification:

- Xcode failures are environment/tooling limitations in this Windows audit environment.
- Missing `Package.resolved`, stale docs, placeholder support, and privacy manifest gaps are repo problems.
- Lack of manual QA evidence is a repo/release-process problem.

## 17. Security, Privacy, and Data Safety Audit

Confirmed positive findings:

- `python scripts/no_network_scan.py` passed.
- `python scripts/export_hardening_scan.py` passed.
- `BundleExportService.swift:361-365` and `377-381` include symlink/path hardening.
- `LocalJSONStore.swift:233-236` uses atomic write behavior.
- Student report and teacher audit warnings distinguish audiences in `LocalJSONStore.swift:283-285`, `302-304`, `377-379`, and `464-466`.

Confirmed risks:

- Raw student text can pass through `UserDefaults` via App Routing.
- Privacy manifest omits required reason API declaration for `UserDefaults`.
- Missing source files can be silently dropped by direct bundle export service calls.
- Import file copy lacks obvious rollback on later persistence failure.
- Clipboard copy path includes `GradeDraftViewModel.swift:2252-2268` and allowed kinds at `2318-2319`; backup JSON is allowed, so teacher-only/private export clipboard rules need sharp UX and tests.

Theoretical/unverified risks:

- Physical device storage protection class could not be inspected by runtime.
- Share sheet audience isolation could not be verified on simulator/device.
- Foundation Models availability and failure modes could not be runtime-tested.
- Vision/VisionKit OCR behavior could not be runtime-tested.

## 18. Accessibility Audit

Could not run VoiceOver, simulator accessibility inspector, Dynamic Type screenshots, or keyboard navigation tests in this environment.

Source-level risks:

- One-line button labels in custom button styles can truncate under Dynamic Type.
- Large, dense custom screens such as `FinalReviewScreen.swift` and `RubricInstructionsScreen.swift` need explicit focus order and screen-reader labels.
- Export actions need audience labels ("student-safe report" vs "teacher audit") that are clear to VoiceOver.
- OCR line review needs line-by-line accessible labels including confidence/review status.
- Missing assignment route state should be announced as an error and must not expose mutation controls.
- Modals/sheets for import, restore, and final approval need focus trapping and cancellation semantics verified on device.

Recommended accessibility gates:

- XCUITest or manual VoiceOver pass for core lane.
- Dynamic Type XXL screenshot pass.
- Keyboard navigation pass on iPad.
- UI tests for disabled/enabled states and error announcements.

## 19. Dependency and OSS Audit

Dependency state:

- Docs indicate SwiftCSV and swift-dependencies were removed (`docs/OSS_REVIEW.md:19-20`, `docs/DEPENDENCIES.md:16`).
- Privacy review still references removed dependencies (`docs/release/PRIVACY_REVIEW.md:34`).
- `Package.resolved` is missing and documented as pending.

Custom vs OSS:

- Native SwiftUI is appropriate for most UI. Do not add a UI library casually.
- Custom OCR review, grading packet, final review, and export logic are domain-specific and should remain custom.
- Custom archive/export code is appropriate because the app needs privacy-specific safeguards, but direct-service missing-file behavior should be stricter.
- Custom CSV code may be acceptable if dependency removal was intentional; verify edge cases such as quotes, commas, line breaks, Unicode, and formula injection.
- The huge curriculum catalog may benefit from a structured local store or generated index rather than hand-loading raw JSON.

Dependency audit gaps:

- No package resolution/build was possible.
- No license scan was run.
- No `swift package` or Xcode dependency graph could be inspected.

## 20. Prioritized Defect Register

| ID | Severity | Category | Title | Evidence | Impact | Recommended Fix | Suggested Test | Priority Order |
|---|---|---|---|---|---|---|---|---:|
| D001 | Critical | Data safety | Routed screens fallback to active assignment | `RubricInstructionsScreen.swift:40`; `StudentWorkScreen.swift:73`; `ReviewScannedTextScreen.swift:13`; `ExportsRestoreScreen.swift:235` | Wrong assignment can be edited/exported/graded. | Fail closed on missing assignment ID. | Invalid route ID renders missing state and blocks mutation. | 1 |
| D002 | High | Persistence | GRDB drops rubric import mode/parsed rubric | `Models:187-188`; `Database.swift:349-358`, `480` | Confirmed rubric can change after reload. | Add schema/migration/mapper fields. | Parsed rubric GRDB round-trip. | 2 |
| D003 | High | Persistence | GRDB drops OCR metadata and infers review state | `Database.swift:390-396`, `532-556`; `Models:1253-1259` | OCR provenance/review state can be wrong. | Persist document metadata. | OCR metadata round-trip. | 3 |
| D004 | High | OCR safety | Low-confidence OCR mass confirm | `ViewModel:649-653`; `Models:1325-1328`, `1430-1432` | Unreviewed suspect text can be graded. | Require explicit low-confidence line review. | Low-confidence bulk confirm remains blocked. | 4 |
| D005 | High | Import | Mixed PDFs skip scanned pages | `ViewModel:1276-1290`, `2457-2479` | Student work can be omitted. | Per-page digital/OCR import. | Mixed PDF fixture. | 5 |
| D006 | High | Privacy/release | UserDefaults required reason missing | `AppRouting.swift:83-90`; `PrivacyInfo.xcprivacy:10` | App Store privacy compliance risk. | Add required reason API or remove usage. | Manifest-source static check. | 6 |
| D007 | High | Privacy | Shortcut raw student text in UserDefaults | `GradeDraftAppIntents.swift:319`; `AppRouting.swift:83-90` | Sensitive student work retained in generic local store. | Ephemeral/encrypted handoff with TTL. | Intent import leaves no raw defaults. | 7 |
| D008 | High | Final review | Evidence edits can stale-lock final review | `ViewModel:871-882`; `GradingPacketBuilder:824`, `866-868` | Teacher cannot approve after intended edits. | Separate source and review fingerprints. | Edit evidence then approve. | 8 |
| D009 | Medium | AI readiness | Batch readiness can be ready without budget plan | `AIBatchReadiness.swift:36-50`, `88` | Fake-looking AI readiness. | Require explicit ready budget plan. | No-budget row blocked. | 9 |
| D010 | High | Data safety | Import source files can be orphaned | `ViewModel:580-607`, `1234-1315` | Sensitive local files can remain after failed save. | Transactional import rollback. | Inject save failure; assert cleanup. | 10 |
| D011 | Medium | Export | Bundle export drops missing sources | `BundleExportService.swift:88-100`, `133-145`, `169-188` | Teacher audit archive can be incomplete. | Throw on missing requested source by default. | Missing source file export fails. | 11 |
| D012 | Medium | State | Rubric preview is global | `ViewModel:1319-1340`; `RubricInstructionsScreen.swift:267` | Preview can apply to wrong assignment. | Scope preview by assignment ID. | Preview A, switch B, confirm blocked. | 12 |
| D013 | Medium | Export UX | Global exportURL share state | `ViewModel:1127-1175`; `ClassDetailRosterScreen.swift:88`; `GradeWizardView.swift:343` | Share can point at wrong/last artifact. | Typed artifact share state. | Export two artifacts; share exact one. | 13 |
| D014 | Medium | Product logic | Export status conflates artifact audiences | `ScreenModels.swift` export readiness/status helpers | Teacher archive can appear as student export status. | Audience-specific export status. | ZIP does not satisfy student export. | 14 |
| D015 | High | Release | Missing Package.resolved | `docs/release/PACKAGE_RESOLUTION_PENDING.md:3-9` | Builds may resolve unexpected deps. | Generate/commit or document no-SPM truth. | Static release check fails if missing. | 15 |
| D016 | High | Release validation | No Xcode validation in audit environment | `xcodebuild`/`xcrun` ENOENT | Compile/test/runtime unknown. | Run on macOS/Xcode CI or device. | Full Xcode unit/UI test suite. | 16 |
| D017 | Medium | Testing | No XCUITest app-driving coverage found | `rg "XCUIApplication"` no app tests | Core user flow can regress. | Add UI test target. | Core lane UI smoke. | 17 |
| D018 | Medium | Release process | Static readiness overclaims | `check_release_readiness_static.py:55-58`, output passed | False release confidence. | Rename or fail on blockers. | Missing Package.resolved fails release check. | 18 |
| D019 | Medium | Docs | Privacy/release docs stale deps | `PRIVACY_REVIEW.md:34`; `OSS_REVIEW.md:19-20` | Confuses release review. | Update docs. | Doc consistency static scan. | 19 |
| D020 | Medium | Docs/product trust | Placeholder support/contact docs | `SUPPORT_PAGE_COPY.md:37`; `contact.html:14` | Not credible/releasable. | Replace final support details. | Release check blocks placeholders. | 20 |
| D021 | Medium | Architecture | God ViewModel | `GradeDraftViewModel.swift` 129,960 bytes | Bugs concentrate, tests hard. | Split by domain. | Behavior tests stay green after split. | 21 |
| D022 | Medium | Architecture | Massive model file | `GradeDraftModels.swift` 84,769 bytes | Hard reviews/schema drift. | Split models. | Compile and persistence tests. | 22 |
| D023 | Medium | Architecture/testing | Massive test files | `GradeDraftTests.swift` 133,918 bytes; `GradeDraftHardeningTests.swift` 105,096 bytes | Hard to maintain. | Split by feature. | CI still discovers all tests. | 23 |
| D024 | Medium | Performance | 55 MB curriculum JSON bundled | `Resources/JSON/curriculum_catalog_acara_v9.json` | Bundle/startup/memory risk. | Indexed/split store. | Cold load benchmark. | 24 |
| D025 | Medium | Accessibility | Button labels likely truncate | `UI/DesignSystem/Buttons.swift` | Dynamic Type risk. | Multiline/responsive buttons. | XXL Dynamic Type screenshots. | 25 |
| D026 | Medium | Performance | OCR review can persist too often | ViewModel OCR edit/save paths | Large docs may lag. | Batch/debounce durable saves. | Large OCR edit performance test. | 26 |
| D027 | Low/Medium | SwiftUI | Offset identity in progress steps | `ProgressComponents.swift:85` | View churn if reordered. | Stable IDs. | Reordered steps preserve identity. | 27 |
| D028 | Medium | Testing | Source-shape tests brittle | `NativeUIRefactorSnapshotTests.swift:172`, `215` | Refactors can fail without behavior change. | Replace with behavior tests. | UI behavior test. | 28 |
| D029 | Medium | Privacy | Clipboard copy allows sensitive kinds | `ViewModel:2252-2268`, `2318-2319` | Teacher-only content can be copied casually. | Restrict or add explicit confirmation. | Backup copy disabled/confirmed. | 29 |
| D030 | Low/Medium | Docs | Offline doc says JSON storage primary | `OFFLINE_CAPABILITY.md:25-27` | Misleads maintainers. | Update persistence docs. | Doc/source consistency check. | 30 |
| D031 | Low | Agent docs | Hardcoded external tool popularity/latest claims | `AGENTS.md:47-65` | Drift-prone instructions. | Link instead of hardcoding. | None. | 31 |
| D032 | Medium | Release | Manual QA not run | `MANUAL_QA_RESULTS.md:3-12` | Release confidence unsupported. | Run and record QA. | Release check requires dated QA. | 32 |
| D033 | Medium | Build | SwiftLint/actionlint unavailable locally | `where.exe` results | Quality gates unverified here. | Run in CI/macOS env. | CI lint jobs. | 33 |
| D034 | Medium | UX | Missing assignment route has no explicit state | Same as D001 | Confusing dead-end/wrong state. | Missing-state screen. | UI snapshot for missing route. | 34 |
| D035 | Medium | UX | Export audiences not visibly distinct enough | Export/global status evidence | User can share wrong artifact. | Strong labels/colors/icons per audience. | VoiceOver/action label tests. | 35 |
| D036 | Low/Medium | Data | Restore preview runtime unverified | Backup/restore code exists; no runtime run | Destructive restore may surprise. | Add device/sim tests. | Restore preview/confirm UI test. | 36 |
| D037 | Medium | Privacy | Support/privacy release artifacts incomplete | release support docs | App Store/release risk. | Finalize support artifacts. | Release placeholder scan. | 37 |
| D038 | Medium | Domain | CSV/formula edge cases not proven | Custom CSV/export paths | Spreadsheet injection or malformed CSV risk. | Escape formula-leading cells and CSV edge cases. | CSV edge-case tests. | 38 |
| D039 | Low | Repo hygiene | Python cache generated by checks | `scripts/curriculum/__pycache__` observed after command | Dirty tree noise. | Ensure ignored/clean. | `git status --short` clean after checks. | 39 |
| D040 | Medium | Runtime | Foundation Models/Vision not runtime verified | Toolchain unavailable | AI/OCR device behavior unknown. | Run on supported Apple OS/device. | Device runtime smoke. | 40 |

## 21. Recommended Fix Plan

### Phase 0: stop-the-line issues

- Fail closed on missing assignment routes.
- Fix privacy manifest/UserDefaults required reason gap.
- Stop storing raw Shortcut student text in `UserDefaults`.
- Make release readiness fail on missing `Package.resolved` and placeholder support docs.
- Mark release status "not ready" until Xcode build/test/manual QA evidence exists.

### Phase 1: correctness and data safety

- Persist rubric import mode and confirmed parsed rubric in GRDB.
- Persist OCR document metadata in GRDB.
- Fix low-confidence OCR review semantics.
- Fix mixed PDF per-page OCR.
- Add transactional rollback for imported source files.
- Make bundle export fail on missing requested source files.

### Phase 2: user flow and UX clarity

- Add missing-assignment route screens.
- Add audience-specific export state and labels.
- Add exact blocked/ready states for local AI budget and model availability.
- Add restore preview confirmation and recovery copy.
- Improve import failure and retry UX.

### Phase 3: test coverage

- Add missing tests from Appendix B, starting with route fallback, persistence round trips, mixed PDF, low-confidence OCR, App Intent retention, and export audience tests.
- Add one full XCUITest for the core lane.
- Add Dynamic Type and VoiceOver manual/test checklist.

### Phase 4: documentation and repo hygiene

- Update stale persistence docs.
- Update privacy/release docs.
- Consolidate release blockers.
- Remove placeholder support artifacts.
- Document privacy manifest API mapping.
- Update agent instructions for fail-closed routing and audit-only exception.

### Phase 5: refactors and performance

- Split `GradeDraftViewModel`.
- Split model and test god files.
- Extract import/export/persistence coordinators.
- Rework huge curriculum catalog delivery.
- Replace source-shape tests with behavior tests where practical.

### Phase 6: polish and release readiness

- Run full macOS/Xcode validation.
- Run simulator/device manual QA.
- Generate and validate screenshots.
- Run release archive job.
- Verify support/privacy pages.
- Produce a dated release evidence packet.

## 22. Appendix A: Largest Files and Split Recommendations

| Rank | File | Size | Risk | Split recommendation |
|---:|---|---:|---|---|
| 1 | `GradeDraft/Resources/JSON/curriculum_catalog_acara_v9.json` | 55,302,692 | Bundle/memory/startup risk. | Convert to indexed SQLite or split JSON shards. |
| 2 | `GradeDraftTests/GradeDraftTests.swift` | 133,918 | Too broad to maintain. | Split by feature domain. |
| 3 | `GradeDraft/GradeDraftViewModel.swift` | 129,960 | God object; state bugs. | Split by workflow coordinator. |
| 4 | `GradeDraftTests/GradeDraftHardeningTests.swift` | 105,096 | Hardening domains mixed. | Split guardrails by privacy/export/AI/OCR/release. |
| 5 | `docs/GRADING_CONTENT_SOURCE_OF_TRUTH.md` | 104,429 | Long doc hard to keep current. | Split provenance/policy/packet/fixtures. |
| 6 | `GradeDraft/Models/GradeDraftModels.swift` | 84,769 | Model/schema drift. | Split domain models. |
| 7 | `GradeDraft/Persistence/Database.swift` | 63,298 | Schema/mapping/migrations mixed. | Split schema, migrations, repositories. |
| 8 | `GradeDraft/Export/BundleExportService.swift` | 46,335 | Archive responsibilities mixed. | Split manifest/source collection/writer/sanitizer. |
| 9 | `GradeDraft/Content/GradingPacketBuilder.swift` | 44,113 | Packet/budget/fingerprint mixed. | Split builder, budget, fingerprint, validator. |
| 10 | `GradeDraft/UI/Screens/FinalReviewScreen.swift` | 43,561 | Large UI surface. | Split evidence/feedback/approval/export panels. |
| 11 | `GradeDraft/UI/Screens/RubricInstructionsScreen.swift` | 41,958 | Import/editor/preview mixed. | Split editor, parser preview, confirmation. |
| 12 | `GradeDraft/Services/LocalJSONStore.swift` | 29,857 | Snapshot/report/restore mixed. | Split local snapshot store and report writers. |

## 23. Appendix B: Missing Test Matrix

| Test name | Type | Target | Scenario | Why it matters |
|---|---|---|---|---|
| `testInvalidAssignmentRouteFailsClosed` | Unit/UI | Routed screens | Invalid assignment ID renders missing state. | Prevents wrong-record mutation. |
| `testStudentWorkScreenDoesNotFallbackToActiveAssignment` | UI/unit | `StudentWorkScreen` | Stale ID with different active assignment. | Protects student work import. |
| `testRubricScreenDoesNotConfirmPreviewForWrongAssignment` | Unit | Rubric screen/ViewModel | Preview A, switch B, confirm. | Prevents rubric cross-assignment leak. |
| `testParsedRubricRoundTripsThroughGRDB` | Persistence | `Database` | Confirm markdown rubric, save, reload. | Prevents rubric state loss. |
| `testRubricImportModeRoundTripsThroughGRDB` | Persistence | `Database` | Save raw/structured modes. | Prevents mode drift. |
| `testOCRDocumentMetadataRoundTripsThroughGRDB` | Persistence | `Database` | Save engine/source/reviewedAt. | Preserves OCR provenance. |
| `testOCRReviewStatusRoundTripsThroughGRDB` | Persistence | `Database` | Save reviewed vs needs review. | Prevents false grading unlock. |
| `testLowConfidenceLineCannotBeBulkConfirmed` | Unit | OCR review model | Low-confidence line and mark all. | Protects teacher review gate. |
| `testMixedPDFOCRsScannedPages` | Import | PDF import service | One digital, one scanned page. | Prevents omitted student work. |
| `testImageImportRollsBackFilesOnSaveFailure` | Unit/integration | Import service | Persist file then fail store save. | Prevents orphan sensitive files. |
| `testPDFImportRollsBackOriginalOnSaveFailure` | Unit/integration | PDF import | Copy original then fail save. | Prevents orphan source PDF. |
| `testShortcutImportDoesNotPersistRawTextInDefaults` | Unit/integration | App Routing/App Intent | Shortcut payload consumed/failure. | Protects student privacy. |
| `testPrivacyManifestMatchesUserDefaultsUsage` | Static | Privacy manifest | Source uses defaults. | Prevents App Store compliance miss. |
| `testBatchReadinessRequiresBudgetPlan` | Unit | `AIBatchReadiness` | No budget plan. | Prevents fake AI readiness. |
| `testBatchReadinessBlocksFailedBudgetPlan` | Unit | `AIBatchReadiness` | Failed budget plan. | Prevents invalid batch start. |
| `testFinalReviewEvidenceEditRemainsApprovable` | Unit | Final review | Add evidence after start. | Prevents stale-lock. |
| `testBundleExportThrowsOnMissingSource` | Unit | `BundleExportService` | Missing source path. | Prevents incomplete archive. |
| `testShareLinkUsesSelectedArtifact` | UI/unit | Export/share UI | Export student then teacher ZIP. | Prevents wrong share. |
| `testTeacherArchiveDoesNotSatisfyStudentExportStatus` | Unit | Screen/export model | ZIP created, no student report. | Prevents status conflation. |
| `testClipboardCopyBlocksSensitiveBackupByDefault` | Unit/UI | Clipboard export | Backup JSON copy. | Prevents casual sensitive copy. |
| `testCSVFormulaInjectionEscaped` | Unit | CSV export | Cell starts `=`, `+`, `-`, `@`. | Spreadsheet safety. |
| `testCSVQuotesCommasAndNewlines` | Unit | CSV export | Complex student names/comments. | Data integrity. |
| `testRestorePreviewRequiresExplicitConfirmation` | UI | Restore screen | Preview backup then cancel. | Prevents accidental overwrite. |
| `testCoreLanePasteOCRDraftFinalExport` | XCUITest | Full app | Paste -> OCR review -> draft -> final -> export. | Release smoke. |
| `testDynamicTypeXXLCoreScreens` | Snapshot/manual | UI | XXL Dynamic Type. | Accessibility. |
| `testVoiceOverExportLabels` | Manual/UI | Export UI | Screen reader labels. | Audience safety. |
| `testNoPlaceholdersInReleaseSupportDocs` | Static | release docs | Placeholder URL/contact scan. | Release trust. |
| `testReleaseReadinessFailsWithPackageResolvedMissing` | Static | release script | Missing Package.resolved. | Prevents false green. |
| `testManualQARequiredForReleaseMode` | Static/process | release docs | No dated QA run. | Prevents unsupported release claim. |
| `testCurriculumCatalogLazyLoadPerformance` | Performance | Framework browser | Cold load/search. | iPad performance. |

## 24. Appendix C: Documentation Rewrite Checklist

| File | Required update |
|---|---|
| `README.md` | Add current release status: source implemented but release not validated until Xcode build/test, Package.resolved, manual QA, privacy manifest, and support docs are complete. |
| `docs/ARCHITECTURE.md` | Add persistence contract: which fields are GRDB primary, JSON backup-only, and migration-covered. |
| `docs/OFFLINE_CAPABILITY.md` | Replace JSON-primary storage claim with GRDB primary plus JSON export/backup. |
| `docs/TEST_PLAN.md` | Separate static scripts, Xcode unit tests, XCUITest, simulator screenshots, device QA, and release archive. |
| `docs/CI.md` | Make required PR gates, optional heavy jobs, and release gates unambiguous. |
| `docs/ledgers/CORE_RULES.md` | Add fail-closed assignment routing invariant and low-confidence OCR explicit-review invariant. |
| `docs/ledgers/VALIDATION_LEDGER.md` | Record that this audit could not run Apple toolchain validation in Windows environment. |
| `docs/release/PRIVACY_REVIEW.md` | Remove stale dependency references; add UserDefaults required reason API review. |
| `docs/release/PRODUCTION_READINESS_CHECKLIST.md` | Add owner/date/evidence/status fields and mark unchecked items as blockers. |
| `docs/release/PACKAGE_RESOLUTION_PENDING.md` | Convert from passive note to active blocker with exit criteria. |
| `docs/release/MANUAL_QA_RESULTS.md` | Add dated QA evidence or keep explicit "not run - blocks release". |
| `docs/release/SUPPORT_PAGE_COPY.md` | Replace placeholder support URL/contact with final values. |
| `docs/release/support_site/pages/contact.html` | Replace placeholder content or exclude from release. |
| `docs/OSS_REVIEW.md` | Cross-link to current dependencies/privacy review. |
| `docs/DEPENDENCIES.md` | State whether no runtime package deps is intentional and how Package.resolved should be handled. |
| `AGENTS.md` | Remove drift-prone external star/latest release claims; add audit-only exception and privacy-manifest rule. |
| `.github/workflows/swift.yml` comments/docs | Document which jobs must pass for merge vs TestFlight/release. |
| `docs/GRADING_CONTENT_SOURCE_OF_TRUTH.md` | Split or add dated status header and provenance summary. |
| `docs/release/RELEASE_STATUS.md` | Create single current release-status page. |
| `docs/release/RELEASE_BLOCKERS.md` | Create active blocker register with reproduction and exit criteria. |

## 25. Appendix D: Open Questions

These could not be answered from the repo/environment alone:

1. Is the public product name definitively MarkForMe, GradeDraft, or a transitional combination?
2. Is `UserDefaults` acceptable for App Shortcut handoff if declared in the privacy manifest, or should raw student text never touch defaults by policy?
3. Should low-confidence OCR lines require individual confirmation even when the teacher uses a "confirm all" action?
4. What is the intended behavior for mixed digital/scanned PDFs?
5. Should teacher ZIP/archive creation ever count toward student-facing "exported" status?
6. Is `Package.resolved` intentionally absent because no packages should exist, or is package resolution pending?
7. What are the final support URL, contact email, and privacy/support site deployment targets?
8. Which CI jobs are required for merge and which are required only for TestFlight/release?
9. What minimum iOS/iPadOS versions and devices must pass manual QA?
10. Should the 55 MB curriculum catalog ship as bundled JSON, or should it move to an indexed local store?
