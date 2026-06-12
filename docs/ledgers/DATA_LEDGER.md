# Data Ledger

This ledger summarizes durable data entities and persistence behavior for MarkForMe v3.

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

`ClassGroupRecord`, `StudentRecord`, `ClassStudentEnrollment`, `AssignmentRosterEntry`, and `StudentWorkRecord` support classes, students, enrollment, per-assignment status, and gradebook export. Assignment roster persistence is treated as a complete local snapshot so that deleted assignments, deleted students, and restore/replace operations do not leave stale gradebook rows behind.

## Curriculum data

`CurriculumSource`, `CurriculumItem`, `CurriculumCatalog`, and `CurriculumMapping` support offline curriculum browsing, filtering, provenance display, prompt inclusion, report inclusion, and persistence. Curriculum items come from local bundled/source-material references and carry provenance labels.

## Backup/restore data

`BackupArchiveManifest`, `BackupRestorePreview`, and `BackupConflictResolution` support full local backup manifests, record counts, source-file inclusion, restore previews, ID conflict handling, and source-file restoration into local app storage. Restore confirmation must not report success until assignments plus related class, student, and roster records have been persisted or a visible persistence error has been raised.

## Normalized GRDB tables

`GradeDraftDatabase` creates normalized tables for class groups, students, class-student links, assignment roster entries, student work, source inputs, PDF sources, OCR documents, OCR pages, OCR lines, OCR line revisions, rubrics, rubric criteria, rubric levels, teacher instructions, answer keys, expected elements, exemplars, curriculum items, curriculum mappings, grading packets, grade proposals, grade-proposal criteria, teacher reviews, final reviews, final-review criteria, evidence references, export records, audit events, and backup/restore events.

Compatibility JSON payload rows remain for lossless export/fallback, but normalized rows are the primary load path once present.

## 2026-05-30 — Local AI constraint templates and audit metadata

- Added assignment-level `selectedInstructionTemplateIDs` to record teacher-selected AI grading constraint templates. Templates are selectable per-assignment and included in the local AI grading prompt.
- Added `LocalModelDraftAudit` to draft records for teacher-audit and backup contexts, including prompt/schema/validator version, generation mode, packet fingerprint, token-budget summary, template IDs, scanned text status, and validation warnings.
- Added GRDB columns `selected_instruction_template_ids_json` on assignments and `local_model_audit_json` on drafts (migration 007).
- Student-facing exports continue to exclude local model audit metadata, raw prompt material, raw model material, and private teacher notes.
- Sensitive constraint templates (EAL/D-sensitive, adjustment-context) are never auto-selected and are only available via explicit teacher action.

## 2026-06-10 — Roster, fallback JSON, and restore hardening

- The GRDB and JSON fallback roster save path now replaces the persisted roster snapshot with the view-model roster state rather than only upserting submitted rows. This keeps gradebook roster rows aligned after assignment deletion, student deletion, CSV roster creation, and restore conflict resolution.
- JSON fallback sidecar loads for classes, students, and roster entries now surface decode failures instead of silently returning empty arrays. This avoids presenting corrupt local data as an intentional empty state.
- The JSON fallback store implements explicit child graph save methods for source inputs, OCR documents, final reviews, evidence references, and full assignment graph loading rather than relying on protocol-level empty defaults.
- Backup restore success depends on related class, student, and roster record persistence. Pending restore previews remain available when that persistence fails so the teacher can retry after resolving the local error.

## 2026-06-10 — Atomic restore and explicit roster snapshot contract

- `AssignmentStoring` now exposes an explicit `AssignmentStoreSnapshot` commit path for assignments, class groups, students, and roster entries. Restore confirmation and roster CSV creation use this graph-level path so the UI is not advanced to a restored or imported state before the related records are durably written.
- `replaceAssignmentRosterSnapshot(_:)` is intentionally a full roster replacement API. Call sites must pass the complete desired roster snapshot; partial assignment-row updates use assignment-specific graph saves and must not call this replacement method.
- The GRDB implementation commits graph replacement inside one database write transaction. The JSON fallback implementation stages the existing sidecar files and restores them if any sidecar write fails.
- Ordinary assignment saves preserve roster rows for kept assignments. Deleting an assignment or student removes only the affected roster rows. Full graph replacement removes stale assignment, class, student, and roster rows that are not present in the incoming snapshot.
- Backup ZIP restore is split into preview, source-file extraction/remapping, and graph snapshot commit. If the graph commit fails after source extraction, restored source files are removed, the pending restore preview remains available, and the view model reloads from the store.
- Sensitive teacher archives and full backups now fail visibly if a source reference marked for teacher inclusion is unsafe or missing. The archive path must not silently omit an original source file that the teacher expects to be included.
