# Decisions Ledger

## D012 — App display name

Decision: The user-facing app name is now **MarkForMe**.

Rationale: User explicitly requested a global app-name change, including user-facing copy. Internal Swift module, target, schema, and path identifiers remain `GradeDraft` where changing them would create a separate project-rename migration or compatibility risk.

## D001 — Local-only source completion

Decision: The all-features completion patch implements requested behavior with local SwiftUI, local file storage, local ZIP/PDF writing, GRDB, PDFKit/UIKit, Vision/VisionKit, and Foundation Models availability gates.

Rationale: MarkForMe is a local-first teacher tool. The patch must not introduce hosted services or network dependencies.

## D002 — Student report and teacher record remain separate

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

## D008 — Typed guided generation replaces raw JSON production drafting

Decision: The production local AI draft path uses Foundation Models typed guided generation and converts generated proposal objects into `GradeDraftResult` before validator normalization. The older string prompt and raw JSON parsing remain only as compatibility/debug material.

Rationale: Rubric marking has a fixed schema. Typed generation reduces malformed output risk while preserving local validation as the correctness gate.

## D009 — No silent truncation for grading packets

Decision: Prompt budgeting chooses full packet, compact full packet, per-criterion generation, or explicit local-too-large failure. Reviewed student text is not silently truncated.

Rationale: The app must grade from teacher-reviewed student text and teacher-supplied grading materials, not hidden excerpts or model summaries.

## D010 — Sensitive constraint templates are manual-only

Decision: EAL/D-sensitive and adjustment-context AI grading constraint templates are never auto-selected. Teachers may select them only when they have supplied the relevant context.

Rationale: MarkForMe must not infer language background, disability, support needs, adjustment status, effort, or intent.

## D013 — Restore commits use graph snapshots

Decision: Confirmed restore, roster CSV assignment creation, class/student mutation, and destructive assignment/student deletion use graph-level snapshot persistence before committing UI state. GRDB implements this as one database write transaction; JSON fallback uses sidecar-file rollback.

Rationale: A teacher must not see a restored, imported, or deleted state unless assignments, related class/student records, roster rows, and source-file references remain coherent in local persistence.

## D014 — Roster replacement is explicit and complete

Decision: Roster persistence is named as a full snapshot replacement. Ordinary assignment saves preserve roster rows for kept assignments; explicit delete and restore paths prune or replace roster rows intentionally.

Rationale: The previous generic roster-save name made partial-save misuse easy. Gradebook rows must not be silently wiped because a future call site passes only one assignment’s roster entries.

## D015 — App-driving UI smoke is PR-required

Decision: `GradeDraftUITests/GradeDraftCoreLaneUITests` runs through the `ui-smoke` job as an ordinary PR-required CI gate, separate from deterministic unit tests and screenshot smoke coverage.

Rationale: The core workflow must be app-driven in CI before merge. A UI test that only runs by label or manual dispatch is useful evidence, but it does not close the product-trust gap for ordinary implementation PRs.
