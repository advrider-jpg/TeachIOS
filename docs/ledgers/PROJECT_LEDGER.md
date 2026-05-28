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
- Active runtime persistence is a thin GRDB-backed local store (`GRDBAssignmentStore`) that persists complete assignment records as JSON payloads inside SQLite. `LocalJSONStore` is retained as a fallback if GRDB init fails. This is a bridge, not the final normalized production schema.
- `GRDBAssignmentStore.swift` is now included in the Xcode project and app target.
- `GradeDraftDatabase` correctly respects injected application support roots (fixed injected-root bug).
- Markdown reporting and CSV export are implemented. PDF and ZIP/archive export remain deferred and not exposed in UI.
- Foundation Models draft grading remains availability-gated.
- Snapshot testing replaced with deterministic tests (no reference images required).
- Assignment prompt field (`AssignmentRecord.prompt`) is implemented with backward-compatible Codable decoding.

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
- Full normalized production SQLite schema (current GRDB layer stores JSON payloads, not a normalized schema)
- PDF export (deferred; service throws not-implemented; not exposed in UI)
- ZIP/archive bundle export (deferred; service throws not-implemented; not exposed in UI)
- Full Markdown rubric parsing (MarkdownRubricParser delegates to RubricParser; Markdown structure parsing deferred)
- Typed LocalAIStatus reason enum (currently string-only unavailable; typed reasons deferred)
- Import/restore UX, side-by-side OCR review, per-line OCR editing, evidence bounding-box linking

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
