# GradeDraft v3 Data Model

The scaffold still stores records in JSON, but the model now mirrors the intended production entities more closely.

## Main record

`AssignmentRecord` stores assignment metadata and references to local grading state:

- assignment metadata: title, subject, grade level, assignment type;
- classroom metadata: class name and student display name;
- rubric and grading context: rubric text, custom instructions, answer key, exemplar;
- source inputs: local source-image references and content digests;
- OCR document: pages, lines, confidence, review state;
- reviewed student text: the only text eligible for grading;
- latest model draft: proposed criterion scores and feedback;
- final review: teacher-final criterion scores and feedback;
- export records;
- audit events.

## Source records

`SourceInputRef` preserves source metadata separately from OCR:

- source type;
- page index;
- local relative path;
- content digest;
- digest algorithm;
- image dimensions;
- whether the teacher wants it included in exports.

## OCR records

`OCRDocument`, `OCRPage`, and `OCRLine` distinguish:

- raw OCR text;
- corrected text;
- teacher-confirmed state;
- confidence;
- bounding boxes;
- document-level review status.

## Rubric records

`RubricParser` extracts point-bearing lines into `RubricCriterion` records. The parser is intentionally simple and should be replaced or expanded once Markdown/table rubrics become a priority.

## Grading records

`GradeDraftResult` stores the model proposal and packet fingerprint. `FinalGradeReview` stores the teacher-final version. `FinalCriterionScore` stores proposed points and final points separately.

## Audit and export records

`AuditEvent` records major state transitions. `ExportRecord` records export type, timestamp, content fingerprint, and whether private notes/original sources were included.
