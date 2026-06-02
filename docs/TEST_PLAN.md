# Mark My Work Test Plan

## Current source-level tests

The XCTest files cover the full v3 source-implemented feature set:

- deterministic totals for model drafts and teacher-final points;
- missing-rubric and missing-student-text validation;
- unreviewed-OCR grading gates;
- OCR quality summaries for low-confidence, unconfirmed, confirmed, and rejected lines;
- OCR line edit, confirm, reject, page review, document review, and stale draft/final reset behavior;
- side-by-side OCR data state: selected page behavior, page/line status, source refs, and bounding boxes;
- per-line OCR evidence linking, manual evidence entry, remove/clear behavior, and evidence/source-ref alignment;
- student report exclusion of private teacher notes, raw model output, source refs, and internal bounding boxes;
- teacher audit inclusion of private notes, OCR status, source refs, evidence traceability, bounding boxes, audit events, export records, and curriculum provenance;
- PDF student and teacher-audit export writing non-empty files;
- PDF student export gating before teacher-approved final review;
- ZIP teacher archive, assignment gradebook archive, and full backup archive contents;
- full backup manifest counts, safe archive paths, restore preview, conflict handling, restore-as-copy, and source-file restoration;
- PDF import metadata construction and source records, with runtime PDF rendering validation reserved for Xcode/iOS SDK tooling;
- Markdown rubric parsing for headings, bullets, numbered criteria, tables, point ranges, levels/bands, duplicate detection, stable IDs, warnings, and preview fallback;
- normalized GRDB save/load from normalized rows after compatibility payload rows are removed;
- legacy JSON migration into normalized tables;
- evidence refs, OCR lines, final reviews, roster data, and curriculum mappings persistence;
- roster CSV preview, duplicate name/identifier detection, rejected rows, class/student creation, assignment roster creation, status matrix, and gradebook CSV;
- curriculum catalog load/filter/map, provenance in reports, prompt inclusion, and absence of endorsement/compliance claims;
- PromptBuilder safety rules and prompt field usage;
- prohibited UI label checks and no-cloud-fallback copy;
- final-review approval gates, stale review blocking, criterion add/delete, totals recalculation, and manual grading path;
- export records and sensitivity/source-inclusion flags;
- delete assignment persistence behavior.

## Static validation commands

Run in the repository root:

```bash
python3 scripts/no_network_scan.py
python3 scripts/export_hardening_scan.py
python3 scripts/repo_health.py
python3 scripts/ci/bad_string_scan.py
python3 scripts/ci/check_xcode_project_membership.py
python3 scripts/ci/check_ci_contract.py
```

Remaining bad-string matches should be limited to canonical source-of-truth/research/source-material documents that discuss out-of-scope product boundaries, not unimplemented status for the 11 v3 features.

## CI gates

The primary workflow is `.github/workflows/swift.yml` (`GradeDraft CI`). It separates static policy checks, workflow linting, SwiftLint, deterministic Xcode unit/integration tests, screenshot smoke tests, and unsigned Release build verification. Core page screenshot capture also has a separate workflow at `.github/workflows/core-page-screenshots.yml` (`GradeDraft Core Page Screenshots`).

Required PR jobs:

- `static-policy`
- `workflow-lint`
- `swiftlint`
- `xcode-unit-tests`

Main, scheduled, manual, or labeled deeper checks:

- `screenshot-smoke`
- `release-build`
- `ci-summary`

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
- Run an unsigned Release build with `CODE_SIGNING_ALLOWED=NO`.
- Confirm Foundation Models API calls compile against the installed SDK.
- Confirm PDFKit rendering/import and UIKit PDF export compile and run.
- Confirm Vision/VisionKit capture and OCR compile and run on device/simulator where supported.
- Confirm SwiftUI file import/share sheets run on target devices.
```

## Runtime smoke flows for Xcode or CI

- Paste text -> manual final review -> approve -> student PDF export.
- PDF import -> page refs created -> OCR review needed -> edit/confirm/reject lines -> document reviewed -> draft/manual review allowed.
- OCR line evidence -> final criterion evidence list -> show source -> teacher audit includes bounding box -> student report excludes bounding-box metadata.
- Markdown rubric import -> preview -> confirm structured import -> final review criteria populated.
- Roster CSV import -> preview -> create class/student/assignment roster -> gradebook CSV.
- Curriculum browse/filter -> map item -> prompt/report provenance.
- Full local backup -> restore preview -> restore as copy/keep local/replace local -> source file restored.
- Airplane-mode local flow: no network capability is required.

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
```

Xcode and physical-device validation remain required before TestFlight or App Store submission.
