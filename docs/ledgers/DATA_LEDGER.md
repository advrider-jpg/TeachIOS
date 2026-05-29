# Data Ledger

This ledger summarizes durable data entities and persistence behavior for GradeDraft v3.

## Assignment graph

`AssignmentRecord` remains the UI-facing aggregate. It includes assignment metadata, prompt, rubric, teacher instructions, answer key, expected elements, exemplar, source inputs, OCR state, reviewed student text, local AI draft, final review, evidence references, curriculum mappings, export records, and audit events.

## Source and OCR data

- `SourceInputRef` records pasted text, scans/photos, original PDFs, and rendered PDF pages.
- Original PDFs are copied to local source storage and linked to rendered page refs.
- `OCRDocument`, `OCRPage`, and `OCRLine` store page/line identity, raw text, corrected text, confidence, normalized bounding boxes, confirmation state, rejection state, and review status.
- Rejected OCR lines remain in the audit graph and are excluded from reviewed student text.

## Evidence data

`EvidenceReference` stores source kind, quote, source input ID, OCR line ID, page index, text offsets where known, bounding box where known, teacher-confirmed state, and created timestamp. Final review criteria keep their evidence quote arrays aligned with `EvidenceSourceReference` arrays.

## Roster data

`ClassGroupRecord`, `StudentRecord`, `ClassStudentEnrollment`, `AssignmentRosterEntry`, and `StudentWorkRecord` support classes, students, enrollment, per-assignment status, and gradebook export.

## Curriculum data

`CurriculumSource`, `CurriculumItem`, `CurriculumCatalog`, and `CurriculumMapping` support offline curriculum browsing, filtering, provenance display, prompt inclusion, report inclusion, and persistence. Curriculum items come from local bundled/source-material references and carry provenance labels.

## Backup/restore data

`BackupArchiveManifest`, `BackupRestorePreview`, and `BackupConflictResolution` support full local backup manifests, record counts, source-file inclusion, restore previews, ID conflict handling, and source-file restoration into local app storage.

## Normalized GRDB tables

`GradeDraftDatabase` creates normalized tables for class groups, students, class-student links, assignment roster entries, student work, source inputs, PDF sources, OCR documents, OCR pages, OCR lines, OCR line revisions, rubrics, rubric criteria, rubric levels, teacher instructions, answer keys, expected elements, exemplars, curriculum items, curriculum mappings, grading packets, grade proposals, grade-proposal criteria, teacher reviews, final reviews, final-review criteria, evidence references, export records, audit events, and backup/restore events.

Compatibility JSON payload rows remain for lossless export/fallback, but normalized rows are the primary load path once present.
