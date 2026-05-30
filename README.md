# GradeDraft v3

GradeDraft is a local-first iOS/iPadOS repository for a teacher-controlled grading assistant for text-based student work.

The core lane is:

```text
scan/import/paste/PDF student work -> local OCR where needed -> explicit teacher OCR review -> local rubric draft or manual review -> criterion-level teacher final review -> local export/archive/backup
```

The repo is deliberately scoped to text evidence workflows. Handwriting, posters, physical models, diagrams, symbolic math, LMS sync, cloud backup, accounts, subscriptions, and autonomous visual-artifact grading remain out of scope unless they are backed by teacher-confirmed evidence workflows and local-only implementation.

## Source-implemented feature set

This patch level implements the complete v3 feature set in source code, tests, documentation, and project-file references:

1. Student-facing and teacher-audit PDF export.
2. Teacher audit ZIP archive, assignment gradebook archive, and full local backup archive.
3. PDF import as student work, including original PDF source ref, rendered page refs, digital-text extraction, and OCR fallback path.
4. Side-by-side OCR review with page preview, thumbnails, line list, status, confidence, bounding-box overlay, and navigation.
5. Per-line OCR correction, confirmation, rejection, and evidence linking.
6. Bounding-box evidence traceability in teacher UI/report/archive while excluding internal coordinates from student reports.
7. Markdown rubric import/parser with headings, lists, tables, point ranges, levels, warnings, and teacher-confirmed preview.
8. Normalized GRDB schema and repository path for assignments, rosters, sources, OCR, rubrics, curriculum mappings, grading packets, reviews, evidence, exports, audit events, and backup/restore events, with JSON payloads retained only as compatibility backup.
9. Offline curriculum catalog and mapping from local Australian Curriculum source materials, including provenance and non-endorsement warning.
10. Class roster and multi-student workflow with class/student records, CSV roster preview, duplicate/rejected-row handling, assignment roster statuses, and gradebook CSV.
11. Backup/restore UI path with warning, restore preview, conflict handling, source-file restoration, and restore audit trail.

## Product promise

GradeDraft is not an autonomous grader. It is a teacher-controlled assistant:

1. The teacher supplies or confirms the rubric, answer key, exemplar, and custom grading instructions.
2. The app extracts text locally with Apple Vision and PDFKit where needed.
3. The teacher reviews and confirms OCR text before grading.
4. The app proposes rubric scores and feedback using Apple’s on-device language model when available.
5. The teacher edits or approves each criterion before treating the grade as final.
6. The app preserves source input, OCR output, reviewed text, model proposal, final review, exports, archive records, curriculum mappings, and audit events as separate local records.

GradeDraft does **not** upload student work, rubrics, prompts, draft grades, or final grades to a server.


## Export hardening posture

GradeDraft's export layer is intentionally separated by audience and sensitivity:

- Student-facing Markdown/PDF reports are final-only. They are blocked until a teacher-approved final review exists and the final review is not stale, and the student report builder does not render draft-only grade content.
- Student-facing reports exclude private teacher notes, teacher rationale, raw model responses, audit events, source file paths, OCR internals, evidence source references, and bounding-box coordinates.
- CSV gradebook exports quote every cell, escape embedded quotes, preserve commas/newlines as valid CSV content, and neutralize formula-like text values before writing.
- Teacher audit reports, teacher archive ZIPs, and full local backups are teacher-only sensitive records. Archives include `archive_inventory.json` so teachers and restore tooling can see what categories of data were included.
- Generated export filenames avoid assignment titles, student names, class names, and prompts by default. Filenames use the GradeDraft prefix, export kind, timestamp, short identifier, and extension.
- Export files receive best-effort platform file-protection and exclude-from-backup attributes where supported. This does not make files encrypted after they leave the app.

## Apple framework posture

- OCR: Vision / VisionKit.
- PDF import/export: PDFKit and UIKit local rendering.
- Local grading draft: Foundation Models typed guided generation, when available on supported devices.
- Long grading packets may be drafted criterion-by-criterion or blocked with an explicit local-too-large message; GradeDraft does not silently truncate reviewed student text.
- Storage: local-first GRDB database with normalized tables.
- Export: teacher-controlled local Markdown, PDF, CSV, ZIP/archive, and backup files.
- Minimum deployment target in this scaffold: iOS 17.0.
- Foundation Models code is guarded with `canImport(FoundationModels)` and iOS availability checks.

If Foundation Models is unavailable, GradeDraft shows a local-unavailable state and refuses to generate an AI grade. It does not fall back to a cloud model. Manual final review remains available.

## Local-only constraints

This repo intentionally contains:

- No backend.
- No `URLSession` use.
- No cloud OCR.
- No cloud grading.
- No analytics SDK.
- No remote rubric processing.
- No account login.
- No network entitlement request.

Run the guardrails before committing:

```bash
python3 scripts/no_network_scan.py
python3 scripts/export_hardening_scan.py
python3 scripts/repo_health.py
```

## Open in Xcode

1. Open `GradeDraft.xcodeproj` in Xcode 26 or later for Foundation Models development.
2. Select an iOS simulator or physical device.
3. For actual local AI grading, use a compatible physical device with Apple Intelligence enabled and the on-device model ready.
4. Build and run.

This package was source-checked in a non-Xcode environment. Runtime validation still requires Xcode, GitHub Actions, or a Codex iOS build plugin with Apple SDK access.

## First user flow

1. Create or select a class and assignment.
2. Add students manually or import a roster CSV with preview.
3. Apply/import a rubric, answer key, exemplar, custom instructions, and curriculum references.
4. Scan, import PDF/photo, or paste student work.
5. Review OCR side by side, edit/confirm/reject lines, and link evidence.
6. Draft with local AI when available or start manual final review.
7. Edit final criterion scores, feedback, evidence, rationale, and approval flags.
8. Approve the teacher-final grade.
9. Export student PDF/Markdown, teacher PDF/Markdown, CSV, ZIP archive, or full local backup.
10. Restore a backup with preview and conflict handling when needed.

## Repository layout

```text
GradeDraft/
  GradeDraft.xcodeproj/
  GradeDraft/
    GradeDraftApp.swift
    ContentView.swift
    GradeDraftViewModel.swift
    Models/
    Services/
    Export/
    Persistence/
    Rubrics/
    Views/
    Resources/
  GradeDraftTests/
  docs/
  scripts/
```

## Validation notes

Static checks are available through `scripts/repo_health.py` and `scripts/no_network_scan.py`. Xcode build, iOS simulator smoke tests, Vision/PDFKit runtime behavior, and Foundation Models runtime behavior must be validated on macOS with the relevant Apple SDK and device/simulator support.
