# GradeDraft Test Plan

## Current source-level tests

The XCTest file covers:

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
- teacher-audit inclusion of private teacher notes.

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
