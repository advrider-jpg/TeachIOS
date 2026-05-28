# Data Ledger

## Current source-of-truth records

- `AssignmentRecord`
- `SourceInputRef`
- `OCRDocument`
- `OCRPage`
- `OCRLine`
- `GradingInput`
- `GradeDraftResult`
- `CriterionScore`
- `FinalGradeReview`
- `FinalCriterionScore`
- `ExportRecord`
- `AuditEvent`

## Active persistence

- Runtime store: local JSON in Application Support (`assignments-v3.json`).
- Source images are stored as local file references under Application Support (`Sources/<assignmentID>/...`) with deterministic content fingerprints.
- This repo contains runtime-facing store code and export builders, not committed runtime databases.

## Provenance and immutability rules

- Source input and OCR text are separate.
- Raw OCR text is separate from corrected and teacher-reviewed text.
- `reviewedStudentText` is the grading input for workflow integrity.
- Draft and final review records carry grading-packet fingerprints.
- Current fingerprinting is a recordkeeping mechanism, not a cryptographic guarantee.

## Generated artifacts

- Student Markdown report.
- Teacher-audit Markdown report.
- Temporary local export files.
- Export records capturing content fingerprints and export metadata.

## Sensitive data warning

- Local state, source images, and export records may contain student data.
- The scaffold does not include encryption.
- Teacher-audit exports should be handled as sensitive student records.

## Known counts / computed checks

- Repo checks completed previously for this implementation:  
  - `docs/` files: `40`
  - `docs/source-materials/`: `6`
  - `docs/australiancurriculum/`: `15`

## Unknowns

- No current migration status, checksums, or production backup inventory has been recorded in source control.
- No completion claim for SQLite migration, bundle export productionization, or migration testing exists in the current tree.
