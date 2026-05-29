# GradeDraft v3 Data Model

GradeDraft v3 uses normalized GRDB persistence as the primary path while retaining complete assignment JSON payloads only for compatibility and backup/export fallback.

## Core assignment graph

`AssignmentRecord` stores assignment metadata and references to local grading state:

- assignment metadata: title, prompt, subject, grade level, assignment type, purpose;
- classroom metadata: class group ID, student ID, class name, student display name;
- rubric and grading context: rubric text, custom instructions, answer key, exemplar;
- curriculum reference text and `CurriculumMapping` records;
- source inputs: local source references and content digests;
- OCR document: pages, lines, confidence, review state, rejection state, bounding boxes;
- reviewed student text: the only text eligible for grading;
- latest model draft: proposed criterion scores and feedback;
- final review: teacher-final criterion scores, feedback, private notes, and approval status;
- evidence references;
- export records;
- audit events.

## Classroom and roster records

- `ClassGroupRecord` stores local class metadata.
- `StudentRecord` stores local student metadata without accounts or cloud IDs.
- `ClassStudentEnrollment` models class membership.
- `AssignmentRosterEntry` stores per-student assignment status: not started, source needed, OCR review needed, ready for grading, draft generated, final review in progress, approved, or exported.
- `StudentWorkRecord` models per-student work when a class assignment is expanded into roster entries.

## Source and PDF records

`SourceInputRef` preserves source metadata separately from OCR:

- source type;
- page index;
- local relative path;
- file name and MIME type;
- content digest and digest algorithm;
- image dimensions;
- PDF page count;
- whether the teacher included the source in exports.

PDF import creates a source ref for the original PDF and page-level source refs for rendered pages, preserving page count and relative source paths.

## OCR records

`OCRDocument`, `OCRPage`, and `OCRLine` distinguish:

- raw OCR text;
- corrected text;
- teacher-confirmed state;
- rejected state;
- confidence;
- normalized bounding boxes;
- document-level review status and reviewed timestamp.

Rejected lines remain in the OCR record for audit traceability but are excluded from `reviewedStudentText` and grading input.

## Rubric records

`MarkdownRubricParser` and `RubricParser` produce:

- `ParsedRubric`;
- `RubricCriterion` with stable IDs, group titles, descriptors, max points, and explicit IDs where supplied;
- `RubricLevel` with label, point/band values, descriptors, and sort order;
- `RubricImportPreview` and `RubricParseIssue` for teacher confirmation before the rubric replaces grading context.

The parser supports heading groups, bullet/list criteria, numbered criteria, simple Markdown tables, point ranges, max points, labels, scoring bands, descriptors, duplicate detection, warnings, and fallback to raw rubric text.

## Curriculum records

- `CurriculumSource` records local source/provenance.
- `CurriculumItem` records source, version, learning area, subject, year level, strand/organizer, item type, code, title, description, URL/path, and provenance.
- `CurriculumCatalog` supports local browse/search/filter.
- `CurriculumMapping` connects items to assignments, rubric criteria, or evidence references.

The local catalog is a reference aid; it does not claim endorsement, compliance, certification, or jurisdiction reporting approval.

## Grading records

- `GradeDraftResult` stores model proposals, packet fingerprint, student feedback, teacher notes, uncertainty flags, compliance flags, and raw model output for teacher audit only.
- `CriterionScore` stores proposed criterion scoring and source refs.
- `FinalGradeReview` stores teacher-final status, final totals, feedback, private notes, and finalized timestamp.
- `FinalCriterionScore` stores proposed points and teacher-final points separately, plus teacher rationale, evidence, and evidence source refs.

## Evidence, audit, export, and backup records

- `EvidenceReference` stores OCR-line evidence, reviewed-text-span evidence, or manual teacher evidence with quote, source kind, source input ID, OCR line ID, page index, offsets, bounding box, confirmation state, and timestamp.
- `AuditEvent` records major local state transitions.
- `ExportRecord` records export type, timestamp, content fingerprint, private-note inclusion, and original-source inclusion.
- `BackupArchiveManifest` records archive ID, kind, schema version, created timestamp, counts, source count, private-note/source inclusion, fingerprints, and restore compatibility.
- `BackupRestorePreview` and `BackupConflictResolution` model restore preview and conflict decisions.

## Normalized GRDB schema

The migration creates normalized tables for:

```text
class_groups, students, class_students, assignments, assignment_roster_entries, student_work,
source_inputs, pdf_sources, ocr_documents, ocr_pages, ocr_lines, ocr_line_revisions,
rubrics, rubric_criteria, rubric_levels, teacher_instructions, answer_keys, expected_elements,
exemplars, curriculum_items, curriculum_mappings, grading_packets, grade_proposals,
grade_proposal_criteria, teacher_reviews, final_reviews, final_review_criteria,
evidence_references, export_records, audit_events, backup_restore_events
```

Compatibility tables prefixed with `grade_draft_` preserve legacy assignment payloads and power full graph reconstruction while normalized rows are the primary load path.
