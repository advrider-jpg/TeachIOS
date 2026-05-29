# GradeDraft v3 Implementation Notes

GradeDraft v3 is a source-level completion pass for the local-first, teacher-controlled grading workflow. The implementation keeps the product bounded to local iOS/iPadOS app behavior and does not add cloud services, remote AI, hosted OCR, accounts, telemetry, analytics, subscriptions, hosted assets, Firebase, RevenueCat, or server APIs.

## Source-implemented feature set

The app source now wires all eleven requested feature areas through models, persistence, SwiftUI flows, exports, tests, and documentation.

1. **Student and teacher PDF export.** `PDFExportService` renders local PDFs with headings, page breaks, page numbers, criterion results, evidence excerpts, and student/audit separation. Student export is gated on a fresh teacher-approved final review. Teacher export is sensitive-record-gated and records private-note sensitivity.
2. **ZIP/archive export.** `BundleExportService` writes real ZIP archives for teacher audit packets, assignment gradebooks, and full local backups. Manifests include archive identity, kind, schema, counts, source inclusion, private-note inclusion, fingerprints, and restore compatibility.
3. **PDF import.** The view model imports a PDF into local source storage, records the original PDF and rendered pages as `SourceInputRef` records, extracts digital text with PDFKit when present, falls back to OCR for rendered pages when needed, creates an `OCRDocument`, sets review state to `needsReview`, and blocks grading until teacher review.
4. **Side-by-side OCR review.** `ContentView` presents page thumbnails, a selected page preview, page navigation, overlays for normalized OCR line boxes, selected-line highlighting, confidence/status labels, raw and corrected text editing, confirm/reject actions, page review, document review, and next-unreviewed navigation.
5. **Per-line OCR editing and evidence linking.** OCR edits update reviewed text, reset stale grading state, and record audit events. Final-review criteria can add OCR-line evidence, manual evidence, remove individual evidence, or clear evidence while keeping quote arrays and source-reference arrays aligned.
6. **Bounding-box evidence traceability.** OCR-line evidence stores source input ID, OCR line ID, page index, quote, normalized bounding box, source kind, confirmation state, and created timestamp. Teacher audit reports and archives include source/page/line/bounding-box metadata; student reports omit raw internal coordinate metadata.
7. **Markdown rubric import/parser.** `MarkdownRubricParser` supports heading groups, bullet and numbered criteria, simple tables, point ranges, maximum-point notation, level/band labels, descriptors, explicit criterion IDs, duplicate detection, parse warnings, and an import preview/confirmation path.
8. **Normalized SQLite/GRDB path.** `GradeDraftDatabase` creates normalized tables for classes, students, rosters, student work, source inputs, PDFs, OCR documents/pages/lines/revisions, rubrics/criteria/levels, teacher instructions, answer keys, expected elements, exemplars, curriculum items/mappings, grading packets, proposals, teacher/final reviews, evidence refs, export records, audit events, and backup/restore events. Normalized rows are the primary load path, with compatibility JSON retained for fallback/export.
9. **Offline curriculum import/mapping.** `CurriculumCatalogService` seeds a conservative local curriculum catalog from bundled Australian Curriculum source materials and exposes browsing, filtering, assignment/criterion/evidence mapping, provenance warnings, prompt inclusion, persistence, reports, and archives without any endorsement or compliance claim.
10. **Class roster and multi-student workflow.** The app models classes, students, enrollments, assignment roster entries, and per-student status. The UI supports class/student creation, roster CSV preview, duplicate/rejected-row handling, enrollment, assignment creation from roster rows, assignment roster status, per-student grading/export, and gradebook CSV.
11. **Backup/restore UI.** The UI and archive service support backup export warnings, backup creation, ZIP restore import, preview counts, conflict detection, keep-local/replace-local/restore-as-copy choices, source-file restoration, restore summaries, and audit events.

## Validation status

Static repository checks are run after generating the final patch and applying it to a clean copy of the uploaded ZIP. Xcode build, XCTest execution, simulator smoke tests, PDFKit/UIKit runtime rendering, Vision/VisionKit capture/OCR, and Foundation Models behavior require macOS/Xcode or equivalent CI/plugin tooling.

## Product boundaries retained

The source remains local-first and teacher-controlled. Handwriting-first grading, visual artifact grading, mathematics notation grading beyond reviewed textual explanation, LMS/cloud sync, accounts, subscriptions, district dashboards, and official jurisdiction reporting approval remain outside the current product scope unless separately implemented and validated.
