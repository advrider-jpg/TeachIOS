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
- Core persistence currently uses local JSON under Application Support (`assignments-v3.json` in the scaffold path).
- `LocalJSONStore` is the active state layer for core app runtime data.
- GRDB is present as a next-pass persistence entry point, not the completed replacement.
- Markdown reporting exists; PDF/CSV/ZIP bundle export remains deferred where noted.
- Foundation Models draft grading remains availability-gated.

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
- Full production SQLite/SwiftData migration and migration/restore UX
- PDF/CSV/ZIP archive productionization beyond existing scaffold state

## Open questions / known limits

- Which Foundation Models API names and signatures are current against installed Xcode 26 SDK/device.
- Which iPhone simulator/device is the active CI-equivalent test baseline.
- Whether GRDB path is planned as immediate migration or retained as deferred scaffold.
- Which UI tests are in CI and which remain open.
- Whether bundle export should be in scope for the next implementation pass.

## Ledger links

- [docs/ledgers/CORE_RULES.md](docs/ledgers/CORE_RULES.md)
- [docs/ledgers/DECISIONS_LEDGER.md](docs/ledgers/DECISIONS_LEDGER.md)
- [docs/ledgers/WORKLOG.md](docs/ledgers/WORKLOG.md)
- [docs/ledgers/VALIDATION_LEDGER.md](docs/ledgers/VALIDATION_LEDGER.md)
- [docs/ledgers/DATA_LEDGER.md](docs/ledgers/DATA_LEDGER.md)
