# GradeDraft Test Plan

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
python3 scripts/repo_health.py
python3 scripts/no_network_scan.py
# Run the required unresolved-completion-language search from the project prompt.
# Any matches should be limited to canonical source/research materials that discuss scope boundaries.
```

Remaining bad-string matches should be limited to canonical source-of-truth/research/source-material documents that discuss out-of-scope product boundaries, not unimplemented status for the 11 v3 features.

## Required Xcode validation

Run in Xcode 26+ on macOS with iOS SDK:

```text
- Build app target.
- Build test target.
- Run unit tests.
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
