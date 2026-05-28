# GradeDraft Test Plan

## Current source-level tests

The XCTest files cover:

- deterministic totals for model drafts;
- deterministic totals for teacher-final points;
- missing-rubric validation;
- missing-student-text validation;
- unreviewed-OCR gating;
- JSON extraction around braces in strings;
- OCR quality summaries for low-confidence and unconfirmed lines;
- simple rubric parsing;
- model-score clamping;
- missing-evidence teacher-review flags;
- structured-criterion completeness;
- student export exclusion of private teacher notes;
- teacher-audit inclusion of private teacher notes;
- GRDB round-trip including delete and injected root;
- assignment prompt persistence and backward-compatible decode;
- built-in rubric template IDs, totals, and evidence safeguards;
- PromptBuilder safety rules and prompt field usage;
- prohibited UI label check;
- local AI unavailable no-cloud-fallback copy;
- final-review approval gate (unapproved criteria, stale review, out-of-range scores);
- answer key / exemplar as valid grading standard;
- **manual final review**: start without AI draft; blocked without reviewed text; blocked with OCR needsReview/blocked; blocked without grading standard;
- **manual final review**: parsed rubric → matching criteria; answer-key-only → teacher-review-required criterion;
- **manual final review**: approval gates; approved review enables student export; GRDB round trip;
- **criterion management**: add criterion; delete criterion; approval blocked after adding unapproved; totals recalculate after deletion;
- **export flow**: student report blocked without approved final review; blocked when stale; excludes raw model response; teacher audit includes private notes/OCR/fingerprint;
- **CSV status matrix**: pending, approved, stale;
- **local AI unavailability**: disables draft button; does not disable manual final review;
- **OCR**: scanned input sets needsReview; markOCRReviewed sets reviewed; draft blocked before review; manual review available after review;
- delete assignment removes persisted record.

## Required Xcode validation

Run in Xcode 26+ on macOS with iOS SDK:

```text
- Build app target.
- Build test target.
- Run unit tests.
- Confirm Foundation Models API calls compile against the installed SDK.
- Confirm Vision/VisionKit capture and OCR compile and run on device/simulator where supported.
```

## Release-gating tests still needed

- UI test: paste text -> draft -> start final review -> edit final points -> approve -> student export.
- UI test: scan/import -> OCR status needs review -> draft blocked -> mark reviewed -> draft allowed.
- UI test: edit rubric after draft -> draft stale; edit reviewed text after final -> final stale.
- Export test: student report contains no private teacher notes.
- Export test: teacher audit contains audit events and OCR state.
- Persistence test: source image file exists after scan/photo import.
- Offline test: core flow succeeds in airplane mode on compatible device.
- Availability test: local AI unavailable copy appears and no cloud fallback is attempted.

## Future test areas

- SQLite/SwiftData migration tests.
- Backup/restore preflight tests.
- OCR fixture tests with page thumbnails and bounding boxes.
- Evidence quote-to-source-span tests.
- PDF/CSV export tests.
- Spreadsheet formula-injection hardening tests once CSV export is added.
