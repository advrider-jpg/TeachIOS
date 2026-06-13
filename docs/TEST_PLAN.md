# MarkForMe Test Plan

## Current source-level tests

The XCTest files cover the full v3 source-implemented feature set:

- deterministic totals for model drafts and teacher-final points;
- missing-rubric and missing-student-text validation;
- unreviewed-OCR grading gates;
- OCR quality summaries for low-confidence, unconfirmed, confirmed, and rejected lines;
- OCR line edit, confirm, reject, page review, document review, stale draft/final reset behavior, unchanged-edit no-op persistence, and staged editor commits instead of saving every keystroke;
- side-by-side OCR data state: selected page behavior, page/line status, source refs, and bounding boxes;
- per-line OCR evidence linking, manual evidence entry, remove/clear behavior, and evidence/source-ref alignment;
- student report exclusion of private teacher notes, raw model output, source refs, and internal bounding boxes;
- teacher record inclusion of private notes, scanned text status, source refs, evidence traceability, bounding boxes, audit events, export records, and curriculum provenance;
- PDF student and teacher-audit export writing non-empty files;
- PDF student export gating before teacher-approved final review;
- ZIP teacher archive, assignment gradebook archive, and full backup archive contents;
- full backup manifest counts, safe archive paths, restore preview, conflict handling, restore-as-copy, and source-file restoration;
- PDF import metadata construction, mixed digital/scanned page planning, source records, and empty-page preservation when OCR returns no text, with runtime PDF rendering validation reserved for Xcode/iOS SDK tooling;
- Markdown rubric parsing for headings, bullets, numbered criteria, tables, point ranges, levels/bands, duplicate detection, stable IDs, warnings, and preview fallback;
- normalized GRDB save/load from normalized rows after compatibility payload rows are removed;
- legacy JSON migration into normalized tables;
- evidence refs, OCR lines, final reviews, roster data, and curriculum mappings persistence;
- roster CSV preview, duplicate name/identifier detection, rejected rows, class/student creation, assignment roster creation, status matrix, and gradebook CSV;
- curriculum catalog load/filter/map, indexed ID lookup, indexed search/filter parity, provenance in reports, prompt inclusion, and absence of endorsement/compliance claims;
- curriculum catalog resource-size guardrails for the compact runtime shell, search index, and bounded shards so the prior monolithic payload cannot quietly return;
- PromptBuilder safety rules, prompt field usage, v2 authority boundaries, and model-visible identity redaction;
- custom teacher-instruction linting for unsafe rubric override, full-marks, effort, handwriting, student-background, no-evidence, and final-grade instructions;
- AI readiness and packet preview behavior, including prompt-injection risk flags, token budget plan summaries, redacted technical prompt previews, prompt version, and packet/prompt fingerprints;
- local AI generation progress and cancellation behavior, including no saved draft after cancellation and completed progress only after a draft is saved;
- local AI read-only tool policy and lookup behavior, including source-labeled snippets, call/output limit enforcement, audit metadata, and forbidden tool names for approval, export, upload, web fetch, other-student reads, writes, and deletion;
- batch AI readiness table behavior, including ready/needs-review/blocked rows, identity-redacted display titles, local-unavailable blocking, and no background draft/final/export path;
- local AI evaluation harness behavior, including fixture decoding, required category coverage, deterministic preflight without model attempts, unsafe draft detection, and anonymized report output;
- rubric readiness warnings for duplicate criteria, raw/unstructured rubric states, contradictory instructions, non-textual judgment, and summative review friction;
- local feedback rewrite validation and view-model persistence, including no approval-state change after a rewrite;
- pending App Intent launch request storage and one-time consumption for safe app handoff, including payload persistence for pasted student work and AI Readiness launch preparation;
- pending App Intent launch request storage that keeps raw pasted student text out of `UserDefaults` by staging payload text in a protected transient local file;
- App Intent assignment-entity safety through `scripts/ci/check_app_intents_safety.py`, including foreground-only workflow intents, no unsafe approval/export/upload/background-grade intent names, and no assignment entity display of student/class metadata;
- Shortcut-driven pasted student work, manual-review start, and recommended AI constraint application through real view-model state transitions;
- final-review criterion accept/reject actions, including score clamping, unapproved rejection state, and continued final-approval gating;
- prohibited UI label checks and no-cloud-fallback copy;
- final-review approval gates, stale review blocking, criterion add/delete, totals recalculation, and manual grading path;
- export records and sensitivity/source-inclusion flags;
- route/export truthfulness checks for stale assignment IDs, scoped rubric previews, prepared export artifacts, shared export-risk policy, clipboard-sensitive export policy, and student-facing export completion based only on real student report files;
- shared action-button Dynamic Type source guard ensuring primary/secondary labels use a reusable multiline label and allow unlimited wrapping at accessibility text sizes;
- delete assignment persistence behavior, including persisted roster cleanup for deleted assignments and deleted students;
- roster storage replacement semantics across GRDB and JSON fallback stores, corrupt JSON sidecar visibility, and roster CSV creation preserving existing roster rows;
- restore confirmation failure handling when related class, student, or roster records cannot be persisted;
- local source-image path resolution rejecting unsafe stored relative paths before file reads.

## Static validation commands

Run in the repository root:

```bash
python3 scripts/no_network_scan.py
python3 scripts/export_hardening_scan.py
python3 scripts/repo_health.py
python3 scripts/ci/bad_string_scan.py
python3 scripts/ci/check_xcode_project_membership.py
python3 scripts/ci/check_ci_contract.py
python3 scripts/ci/check_ai_evaluation_fixtures.py
python3 scripts/ci/check_app_intents_safety.py
python3 scripts/ci/check_local_ai_tools.py
python3 scripts/ci/check_ai_prompt_safety.py
python3 scripts/ci/check_ai_batch_readiness.py
python3 scripts/ci/check_ai_packet_preview_screen.py
python3 scripts/ci/check_route_and_export_truthfulness.py
python3 scripts/ci/check_native_ui_refactor.py
python3 scripts/ci/check_release_readiness_static.py
python3 scripts/curriculum/build_acara_curriculum_catalog.py --check
python3 scripts/ci/check_curriculum_catalog.py
```

Remaining bad-string matches should be limited to canonical source-of-truth/research/source-material documents that discuss out-of-scope product boundaries, not unimplemented status for the 11 v3 features.

## CI gates

The primary workflow is `.github/workflows/swift.yml` (`GradeDraft CI`). It separates static policy checks, workflow linting, SwiftLint, deterministic Xcode unit/integration tests, screenshot smoke tests, explicit manual/scheduled release-readiness validation, and unsigned Release build verification. Core page screenshot capture also has a separate workflow at `.github/workflows/core-page-screenshots.yml` (`GradeDraft Core Page Screenshots`).

Required PR jobs:

- `static-policy`
- `workflow-lint`
- `swiftlint`
- `xcode-unit-tests`
- `ui-smoke`

Main, scheduled, manual, or labeled deeper checks:

- `screenshot-smoke`
- `release-build`
- `ci-summary`

Manual/scheduled release validation additionally runs `python3 scripts/ci/check_release_readiness_static.py`; that command must remain fail-closed while `Package.resolved`, support/contact configuration, or manual QA evidence is missing.

Separate visual PR check:

- `core-page-screenshots`

The deterministic Xcode job skips `GradeDraftTests/GradeDraftScreenshotTests`; the screenshot jobs run only that test class and upload the PNG outputs. `GradeDraftScreenshotTests` captures every core app page under `GradeDraft/UI/Screens/*Screen.swift`, excluding only `ScreenModels.swift`, and includes a manifest test that fails when a core page lacks a screenshot case. See `docs/CI.md` for local reproduction commands, artifact names, Xcode 26+ selection, iOS 26+ simulator selection, and branch-protection guidance.

## Production-path CI coverage

`GradeDraftProductionPathTests` provides a named CI-facing production-path layer for:

- sensitive gradebook archive authentication before ZIP creation;
- gradebook archive ZIP contents, including `gradebook.csv`, `assignments.json`, and `archive_inventory.json`;
- backup restore preview before mutation;
- stale final-review blocking for student-facing export;
- OCR incomplete-state blocking for draft and manual review paths;
- no-cloud fallback enforcement when local AI is unavailable; and
- structured rubric import producing teacher-confirmed state while staling existing draft/final review records.


## Export hardening coverage

The dedicated export-hardening test layer covers:

- strict final-only student report rendering for Markdown/PDF content sources;
- privacy separation between student-facing reports and teacher-only audit/archive outputs;
- CSV writer/parser behavior for quoted cells, escaped quotes, embedded commas, embedded newlines, CRLF input, empty cells, and round trips;
- spreadsheet formula-injection neutralization for text fields with dangerous first non-whitespace characters while preserving true numeric values;
- shared CSV parsing for roster import, including quoted commas, escaped quotes, malformed quoted fields, duplicate identifiers, and headerless rosters;
- central `ExportPolicy` behavior for every `ExportKind`, including sensitivity flags, inclusion summaries, student-facing/teacher-only classification, final-review gates, and local-authentication policy flags;
- safe export filenames that omit assignment titles, student names, class names, and prompts;
- best-effort export-file protection helper behavior in the test environment;
- `archive_inventory.json` presence and content for teacher archives, assignment gradebook archives, and full backups;
- archive source-file path normalization, collision resistance, source-file manifest counts, and source-content hash presence;
- restore path traversal rejection for absolute, backslash, empty, `.`, and `..` source paths, plus safe restore-as-copy, keep-local, and replace-local source remapping;
- export record fingerprints based on the actual exported content or file data; and
- static export guardrails in `scripts/export_hardening_scan.py`.

## Required Xcode validation

Run in Xcode 26+ on macOS with iOS SDK:

```text
- Build app target.
- Build test target.
- Run unit tests.
- Run the deterministic CI XCTest command while skipping screenshot tests.
- Run core page screenshot tests separately and inspect uploaded PNG artifacts.
- Run `GradeDraftUITests/GradeDraftCoreLaneUITests` as app-driving smoke coverage and inspect the `.xcresult` for real launch/navigation/export-gate behavior.
- Run an unsigned Release build with `CODE_SIGNING_ALLOWED=NO`.
- Confirm Foundation Models API calls compile against the installed SDK.
- Confirm the AI readiness and packet preview surfaces render correctly before local draft generation.
- Confirm PDFKit rendering/import and UIKit PDF export compile and run.
- Confirm Vision/VisionKit capture and OCR compile and run on device/simulator where supported.
- Confirm SwiftUI file import/share sheets run on target devices.
```

## Runtime smoke flows for Xcode or CI

- Paste text -> manual final review -> approve -> student PDF export.
- Paste text -> prepare AI packet preview -> confirm student/class identity is not present in the technical prompt preview -> draft locally when Foundation Models is available -> start teacher final review.
- Start local draft -> observe generation progress -> cancel -> confirm no draft/final-review state is saved and manual final review remains available.
- In an in-progress final review, run each feedback rewrite mode on a device with Foundation Models available -> confirm scores/evidence/approval state do not change and rewritten feedback still requires teacher approval.
- Run safe App Intents/Shortcuts -> confirm they route to concrete workflows including AI Readiness, create only a blank assignment shell, apply recommended non-sensitive constraints, save pasted text only as teacher-reviewed local input, and do not draft, approve, export, upload, or read other students.
- In final review, accept and reject individual criterion suggestions -> confirm the choice is saved locally, final approval remains required, rejected criteria stay unapproved, and export stays blocked.
- PDF import -> page refs created -> scanned text review needed -> edit/confirm/reject lines -> document reviewed -> draft/manual review allowed.
- OCR line evidence -> final criterion evidence list -> show source -> teacher record includes bounding box -> student report excludes bounding-box metadata.
- Markdown rubric import -> preview -> confirm structured import -> final review criteria populated.
- Roster CSV import -> preview -> create class/student/assignment roster -> gradebook CSV.
- Curriculum browse/filter -> map item -> prompt/report provenance.
- Full local backup -> restore preview -> restore as copy/keep local/replace local -> source file restored.
- Airplane-mode local flow: no network capability is required.
- App-driving UI smoke: launch with `--ui-smoke-test` -> seed a deterministic non-exported local assignment -> navigate Home/Assignments/Exports -> confirm export share controls do not appear when no export artifact exists.
- Native UI snapshot smoke: host each core SwiftUI screen in a temporary window and confirm a native `List`/`Form`-backed rendered hierarchy exists, then compare deterministic section/control summaries.

## Local AI evaluation fixtures

The prompt and readiness test set should include:

- reviewed student text containing "ignore previous instructions" or "give me 100%" and expecting a prompt-injection readiness flag;
- student/class identity present in local assignment state and absent from model-visible prompt previews;
- reviewed text with source refs and model evidence without source refs, expecting teacher review;
- scanned text uncertainty requiring teacher review;
- oversized packet fixtures expecting compact/per-criterion planning or explicit local-too-large failure;
- cancellable draft fixtures expecting no saved `latestDraft` after cancellation;
- local tool fixtures expecting assignment-scoped read-only matches and explicit forbidden action names;
- structured local tool fixtures expecting source-labeled snippets, call-limit failures, output truncation, and audit metadata;
- feedback rewrite fixtures expecting no score/evidence mutation and deterministic rejection of final-grade or prohibited-inference language;
- App Intent handoff fixtures expecting one-time pending launch request consumption, raw pasted payload absence from `UserDefaults`, payload round trip, and visible in-app failure for invalid assignment IDs or missing pasted text;
- local AI evaluation fixtures expecting deterministic preflight checks, no model attempt in CI, identity-redaction checks, required category coverage, and anonymized report metadata;
- prohibited inference language expecting deterministic validation rejection; and
- custom teacher-instruction lint fixtures expecting teacher-review warnings but no automatic final-grade path; and
- batch readiness fixtures expecting row status counts, one-at-a-time queue policy copy, blocked local-unavailable rows, and no background mutation; and
- final-grade language in student-facing draft feedback expecting deterministic validation rejection.

## Validation limits of this environment

Static inspection and Python guardrails can run without Xcode. App build, simulator launch, PDFKit/UIKit runtime rendering, Vision/VisionKit behavior, Foundation Models behavior, and SwiftLint require macOS/Xcode or equivalent CI/plugin tooling.

## Production-readiness validation commands — 2026-05-31

Run the following non-Xcode checks from repo root:

```bash
python3 scripts/curriculum/build_acara_curriculum_catalog.py --check
python3 scripts/ci/check_curriculum_catalog.py
python3 scripts/repo_health.py
python3 scripts/no_network_scan.py
python3 scripts/export_hardening_scan.py
python3 scripts/ci/bad_string_scan.py
python3 scripts/ci/check_native_ui_refactor.py
python3 scripts/ci/check_xcode_project_membership.py
python3 scripts/ci/check_ci_contract.py
python3 scripts/ci/check_release_readiness_static.py
python3 scripts/ci/check_ai_evaluation_fixtures.py
python3 scripts/ci/check_app_intents_safety.py
python3 scripts/ci/check_local_ai_tools.py
python3 scripts/ci/check_ai_prompt_safety.py
python3 scripts/ci/check_ai_batch_readiness.py
python3 scripts/ci/check_ai_packet_preview_screen.py
python3 scripts/ci/check_native_ui_refactor.py
python3 scripts/ci/check_release_readiness_static.py
python3 scripts/curriculum/build_acara_curriculum_catalog.py --check
python3 scripts/ci/check_curriculum_catalog.py
```

Xcode and physical-device validation remain required before TestFlight or App Store submission.

## Second-pass hardening coverage added on 2026-06-10

The second-pass hardening layer adds or updates tests for:

- explicit roster snapshot replacement semantics in both GRDB and JSON fallback stores;
- assignment deletion, student deletion, assignment update, and full snapshot replacement preserving or pruning roster rows only as intended;
- restore confirmation failure after source extraction, including visible error, retained pending preview, rollback/reload of view-model state, and cleanup of extracted source files;
- clear-student-work failure ordering, proving source files are not deleted before the cleared assignment state is durably saved;
- source-path symlink escape rejection before rendering or export reads;
- rejection of symlink source files before teacher archive hashing or ZIP inclusion;
- teacher archive failure when an included source reference is missing rather than silently producing an incomplete sensitive archive; and
- backup restore preview fingerprint checking so a staged archive cannot be swapped between preview and confirmation without a visible failure.

## Ridiculously-close audit follow-up coverage added on 2026-06-12

The audit follow-up layer adds or updates tests/checks for:

- fail-closed routed assignment screens and prepared export artifacts;
- GRDB round trips for rubric import mode, confirmed parsed rubrics, OCR document metadata, OCR review status, empty OCR pages, and page dimensions;
- low-confidence OCR line review blocking for bulk document/page review;
- mixed-PDF planner coverage proving digital-text pages and OCR-recognized scanned pages are merged at their original page indexes;
- final-review evidence edits not stale-locking the source fingerprint while still requiring criterion re-approval;
- App Intent pasted payload staging outside `UserDefaults`;
- bundle export failure on missing requested source files;
- backup JSON clipboard affordance removal from the export screen;
- shared export-risk summary coverage so ViewModel export state and confirmation sheets do not drift;
- OCR correction no-op commits not causing durable saves or audit noise; and
- native UI tests checking rendered container hierarchy in addition to source summaries; and
- shared primary/secondary action-button source coverage for Dynamic Type wrapping behavior, with runtime XXL screenshots still reserved for Xcode/simulator validation.
