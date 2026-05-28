# Worklog

## 2026-05-28 — GradeDraft hardening pass

- Files changed:
  - `GradeDraft.xcodeproj/project.pbxproj` — added GRDBAssignmentStore.swift to app target
  - `GradeDraft/Persistence/Database.swift` — fixed injected-root path bug; resolvedDatabaseFolder stored as property
  - `GradeDraft/Persistence/GRDBAssignmentStore.swift` — now in Xcode target (was on disk but not in project)
  - `GradeDraft/Models/GradeDraftModels.swift` — added prompt field (optional, backward-compatible Codable), updated fingerprint and gradingInput, fixed GradeDraftError messages
  - `GradeDraft/Services/GradingService.swift` — no changes needed
  - `GradeDraft/Services/PromptBuilder.swift` — fixed prompt duplication (was outputting title twice)
  - `GradeDraft/Rubrics/MarkdownRubricParser.swift` — removed fake lineCount>=0 logic; now simply delegates to RubricParser
  - `GradeDraft/Export/PDFExportService.swift` — removed "stub" language from not-implemented errors
  - `GradeDraft/Export/BundleExportService.swift` — removed "stub" language; simplified to not create archive before throwing
  - `GradeDraft/Views/LocalCapabilityBanner.swift` — "Local AI available" → "Local AI ready"
  - `GradeDraft/GradeDraftViewModel.swift` — fixed "draft grade" / "grading" language; added "exemplar" to grading standard readiness copy
  - `GradeDraft/ContentView.swift` — fixed "Draft Grade" → "Draft Feedback Suggestion"; "Start Final Review" → "Start Teacher Final Review"; added prompt TextField; added export confirmation dialogs using canonical Section 18 copy; updated readiness/empty-state copy
  - `GradeDraftTests/GradeDraftSnapshotTests.swift` — replaced snapshot tests (no reference images) with deterministic LocalAIStatus tests
  - `GradeDraftTests/GradeDraftTests.swift` — added sampleInput assessmentPurpose/curriculumReference/prompt; added content-source tests for template IDs, point totals, safety rules; added GRDB injected root and idempotent bootstrap tests; added prompt persistence, fingerprint, and backward-compat decode tests; added prohibited-label test
  - `docs/ledgers/PROJECT_LEDGER.md` — updated persistence posture and deferred areas
- What was implemented:
  - GRDBAssignmentStore added to Xcode project and app target.
  - GradeDraftDatabase now stores resolvedDatabaseFolder and respects injected roots.
  - Snapshot test replaced with deterministic tests.
  - Assignment prompt field implemented (optional, backward-compat). PromptBuilder uses prompt, not title.
  - MarkdownRubricParser fake logic removed.
  - PDF/ZIP not-implemented language cleaned.
  - Export confirmation dialogs added using canonical Section 18 copy.
  - 12+ new tests added for content-source consistency, GRDB path, prompt, prohibited labels.
- What remains deferred:
  - xcodebuild / swiftlint unavailable in this environment (Windows/no Xcode).
  - Full normalized GRDB schema; PDF/ZIP export; Markdown rubric parser; typed LocalAIStatus reasons.
- Validation:
  - `python3 scripts/repo_health.py` — passed.
  - `python3 scripts/no_network_scan.py` — passed.
  - `xcodebuild` and `swiftlint` — unavailable in this environment.

## 2026-05-28 — Initial repo memory layer

- Files changed:
  - `AGENTS.md`
  - `docs/ledgers/PROJECT_LEDGER.md`
  - `docs/ledgers/DATA_LEDGER.md`
  - `docs/ledgers/DECISIONS_LEDGER.md`
  - `docs/ledgers/VALIDATION_LEDGER.md`
  - `docs/ledgers/CORE_RULES.md`
  - `docs/ledgers/WORKLOG.md`
- What was inferred:
  - Project name `GradeDraft` and the core local-first grading lane from repo docs.
  - Build/lint/test references documented in README, TEST_PLAN, and architecture/offline docs.
- What was unknown:
  - Exact current CI pass status, active simulator targets, and current Foundation Models SDK behavior.
- Commands run:
  - Repository inspection only; no validation/build commands were executed.
- Production code untouched:
  - Yes.
- Tests untouched:
  - Yes.
- Validation not run:
  - Yes; no commands executed in this pass.

## 2026-05-28 — Ledger tightening to repo-native memory format

- Files changed:
  - `AGENTS.md`
  - `docs/ledgers/CORE_RULES.md`
  - `docs/ledgers/PROJECT_LEDGER.md`
  - `docs/ledgers/DATA_LEDGER.md`
  - `docs/ledgers/DECISIONS_LEDGER.md`
  - `docs/ledgers/VALIDATION_LEDGER.md`
  - `docs/ledgers/WORKLOG.md`
- What was inferred:
  - Prior repository truths are already authoritative (`README.md`, `docs/ARCHITECTURE.md`, `docs/OFFLINE_CAPABILITY.md`, `docs/TEST_PLAN.md`, `docs/CORE_RULES.md`).
  - `docs/CORE_RULES.md` was not suitable as a canonical project memory ledger and now needs a pointer-oriented role.
  - SwiftLint appears to be part of CI-equivalent validation from repo guidance.
- What was unknown:
  - No session-level validation was executed; no new proof of passing gates was produced.
  - Whether the next pass intends immediate GRDB/SQLite migration remains an explicit project scope decision.
- Commands run:
  - Repository inspection only; no build/lint/tests were executed.
- Production code untouched:
  - Yes.
- Tests untouched:
  - Yes.
- Validation not run:
  - Yes; no commands executed in this pass.
## 2026-05-28 — Final-review approval gate hardening

- Files changed:
  - `GradeDraft/GradeDraftViewModel.swift`
  - `GradeDraft/Views/GradeResultView.swift`
  - `GradeDraftTests/GradeDraftTests.swift`
- What was implemented:
  - Added hard final-review approval gate requiring all criteria approved, valid final points, and non-stale packet state.
  - Updated final-review UI to disable "Approve Final Grade" until all criterion approvals and score bounds are valid.
  - Added tests for blocked approval (unapproved criteria), successful approval, and stale final review blocking.
- Validation status:
  - `python3 scripts/repo_health.py`
  - `python3 scripts/no_network_scan.py`
  - `xcodebuild` / `swiftlint` unavailable in this environment; both commands could not execute.
- Production impact:
  - Teacher finalization behavior changed to reject false-positive final approvals.
- Tests:
  - Added targeted `GradeDraftTests.swift` coverage for approval gating.

## 2026-05-28 — Grading standard gating broadened to answer key/exemplar

- Files changed:
  - `GradeDraft/Models/GradeDraftModels.swift`
  - `GradeDraft/Services/GradingService.swift`
  - `GradeDraft/GradeDraftViewModel.swift`
  - `GradeDraftTests/GradeDraftTests.swift`
- What was implemented:
  - `GradingInput` now carries an explicit `hasGradingStandard` flag derived from rubric text, answer key text, or exemplar text.
  - Draft-readiness and local validator checks now accept answer key or exemplar as a valid grading standard, matching source-of-truth behavior.
  - Added unit tests confirming missing-standard rejection and acceptance when answer key or exemplar is supplied.
- What remains:
  - No runtime changes beyond readiness and validator behavior in this pass.
- Validation status:
  - `python3 scripts/repo_health.py`
  - `python3 scripts/no_network_scan.py`
  - `xcodebuild` and `swiftlint` unavailable in this environment.
