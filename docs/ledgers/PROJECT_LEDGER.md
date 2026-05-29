# Project Ledger

This file is descriptive repository memory. It records the current product and source posture after the all-features completion patch.

## Project name

GradeDraft v3.

## Current purpose

GradeDraft is a local-first, teacher-controlled iOS/iPadOS grading assistant for text-based student work. The core lane is:

```text
source import -> OCR/PDF extraction -> teacher OCR review -> grading packet -> local AI draft or manual review -> teacher final review -> export/archive/backup
```

## Current durable status

- The app uses the existing SwiftUI scaffold and project file.
- The source tree implements PDF import, student PDF export, teacher audit PDF export, teacher ZIP archive export, assignment gradebook archive export, full local backup ZIP export, and backup restore.
- OCR review is teacher-confirmed and line-level, with page selection, source preview, bounding boxes, corrected text, confirmation, rejection, and quality summaries.
- Evidence references can originate from OCR lines, reviewed-text spans, or manual teacher entries, and source-reference arrays stay aligned with visible evidence text.
- Normalized GRDB persistence is the primary repository path, with compatibility JSON payloads retained for fallback/export and tested by clearing compatibility rows after save.
- Class, student, roster, assignment roster, gradebook, curriculum mapping, audit, export, and backup/restore records are modeled in source.
- Curriculum references are local/offline, provenance-labeled, and do not claim endorsement, certification, reporting approval, or compliance approval.
- Foundation Models draft grading remains local-only and capability-gated. Manual final review remains available when local AI is unavailable.
- Runtime validation still requires Xcode, XCTest, simulator/device execution, and Apple SDK checks.

## Major components

- `GradeDraft/ContentView.swift` — SwiftUI shell, roster, PDF import/export, OCR review, rubric import, curriculum, backup/restore.
- `GradeDraft/GradeDraftViewModel.swift` — state transitions, PDF import orchestration, OCR edits, evidence linking, exports, restore merging.
- `GradeDraft/Models/GradeDraftModels.swift` — assignment graph, OCR, evidence, roster, curriculum, backup/restore models.
- `GradeDraft/Persistence/Database.swift` — normalized GRDB schema, migration, save/load/delete repository path.
- `GradeDraft/Export/PDFExportService.swift` — local student and teacher-audit PDF rendering.
- `GradeDraft/Export/BundleExportService.swift` — local ZIP archives, manifests, backup restore, source-file restoration.
- `GradeDraft/Rubrics/MarkdownRubricParser.swift` — structured Markdown rubric parser and import preview.
- `GradeDraft/Services/RosterImportService.swift` — roster CSV preview and validation.
- `GradeDraft/Services/CurriculumCatalogService.swift` — offline curriculum catalog and provenance labels.
- `GradeDraftTests/` — unit tests for grading, OCR, evidence, archive, backup, roster, rubric, curriculum, persistence, and export gates.

## Product boundaries

Handwriting-first grading, visual-artifact scoring, mathematics notation grading beyond reviewed textual explanation, LMS sync, cloud sync, district dashboards, account systems, subscriptions, telemetry, analytics, and official jurisdiction reporting workflows are outside this product slice.
