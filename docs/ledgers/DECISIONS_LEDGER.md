# Decisions Ledger

## D001 — Local-only source completion

Decision: The all-features completion patch implements requested behavior with local SwiftUI, local file storage, local ZIP/PDF writing, GRDB, PDFKit/UIKit, Vision/VisionKit, and Foundation Models availability gates.

Rationale: GradeDraft is a local-first teacher tool. The patch must not introduce hosted services or network dependencies.

## D002 — Student report and teacher audit report remain separate

Decision: Student-facing reports omit private teacher notes, raw model output, audit metadata, local file paths, other-student data, and raw internal bounding boxes. Teacher-audit reports include sensitive audit information and are warning-gated.

Rationale: Export behavior must match teacher-controlled privacy and evidence-traceability boundaries.

## D003 — Normalized GRDB is the primary repository path

Decision: Normalized tables are created for the full assignment graph, roster, curriculum, evidence, export, audit, and backup/restore entities. Complete JSON payload rows remain as compatibility/export fallback.

Rationale: The app can reconstruct `AssignmentRecord` from normalized rows while retaining a lossless escape hatch during migration.

## D004 — PDF import creates source refs before grading

Decision: Imported PDFs are copied into local source storage, page images are rendered for review/OCR, digital text is extracted when present, OCR fallback is used for image-like pages, and review status is set to `needsReview`.

Rationale: Grading must depend on teacher-reviewed text, not unconfirmed extraction output.

## D005 — Evidence traceability is visible to teachers, not exposed as raw internals to students

Decision: OCR-line evidence stores page/line/bounding-box metadata and offers source navigation/highlighting in teacher workflows. Student reports use the evidence quote, not raw coordinate metadata.

Rationale: Teachers need traceability; students need clear feedback without internal audit metadata.

## D006 — Curriculum references are local and provenance-labeled

Decision: The catalog is seeded from local Australian Curriculum source materials and teacher-provided fallback references. The UI and reports show provenance and avoid endorsement or reporting-approval claims.

Rationale: Offline mapping adds practical value without overclaiming policy status.

## D007 — Restore conflicts are explicit

Decision: Full backup restore detects assignment ID conflicts and supports keep-local, replace-local, and restore-as-copy behavior. Source files are restored through safe relative paths.

Rationale: Backup restore should be recoverable and auditable without silently overwriting newer local work.
