# Project Ledger

This file is descriptive repo memory, not a roadmap or task queue.

## Project name

GradeDraft v3

## Current known purpose

Local-first, teacher-controlled iOS/iPadOS grading assistant for text-based student work.

Core lane:
`scan/import/paste student work -> local OCR -> explicit teacher OCR review -> local rubric draft -> criterion-level teacher final review -> local export`.

## Current durable status

- v3 scaffold is active.
- Active runtime persistence is GRDB-backed. Complete assignment JSON payloads are retained for compatibility, and normalized GRDB tables mirror assignments, source inputs, OCR lines, drafts, final reviews, exports, and audit events.
- `GRDBAssignmentStore.swift` is included in the Xcode project and app target.
- `GradeDraftDatabase` correctly respects injected application support roots.
- Markdown, PDF, CSV, and ZIP/archive exports are implemented locally and warning-gated in UI.
- Foundation Models draft grading remains availability-gated.
- Assignment prompt field (`AssignmentRecord.prompt`) is implemented with backward-compatible Codable decoding.
- **Manual grading path** is implemented: teacher can start, edit, and approve a final review without any AI draft, from parsed rubric criteria or an answer-key/exemplar-only baseline.
- **Full final-review editor** is implemented: all criterion fields editable (name, rating, final/max points, explanation, evidence, teacher rationale, approval toggle). Add Criterion and Delete Criterion are supported.
- **OCR confirmation dialog** ("Mark OCR reviewed?") uses canonical copy before marking text reviewed.
- **Approve Final Grade confirmation** dialog uses canonical copy before approving.
- **Share-sheet warning** dialog uses canonical copy before opening UIActivityViewController.
- **About/Local Privacy section** is in the app UI, listing local data inventory and deferred features.
- Source image files are deleted when an assignment is deleted (best-effort; no error surfaced if deletion fails).
- `no_network_scan.py` and `repo_health.py` both pass in current environment. xcodebuild/SwiftLint/simulator not run (Windows environment).

## Major components / directories

- `GradeDraft/`
- `GradeDraft/Models/`
- `GradeDraft/Services/`
- `GradeDraft/Views/`
- `GradeDraft/Export/`
- `GradeDraft/Persistence/`
- `GradeDraftTests/`
- `docs/`
- `scripts/`
- `.agents/skills/`
- `.github/workflows/`

## Current known non-goals / deferred areas

- Handwriting as fully autonomous grading
- Posters / physical models / visual artifacts as automated grading
- Symbolic math structure grading without explicit evidence pipelines
- LMS sync, grade passback, and cloud backup/sync
- Typed LocalAIStatus reason enum (currently string-only unavailable; typed reasons deferred)
- Fully certified official jurisdiction reporting workflows
- Autonomous handwriting, visual artifact, and symbolic math grading remain out of scope

## Open questions / known limits

- Which Foundation Models API names and signatures are current against installed Xcode 26 SDK/device.
- Which iPhone simulator/device is the active CI-equivalent test baseline.
- Which UI tests are in CI and which remain open.

## Ledger links

- [docs/ledgers/CORE_RULES.md](docs/ledgers/CORE_RULES.md)
- [docs/ledgers/DECISIONS_LEDGER.md](docs/ledgers/DECISIONS_LEDGER.md)
- [docs/ledgers/WORKLOG.md](docs/ledgers/WORKLOG.md)
- [docs/ledgers/VALIDATION_LEDGER.md](docs/ledgers/VALIDATION_LEDGER.md)
- [docs/ledgers/DATA_LEDGER.md](docs/ledgers/DATA_LEDGER.md)
