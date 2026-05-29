# GradeDraft Architecture

GradeDraft is an Apple-native, local-first iOS app scaffold. The architectural rule is that each state boundary remains explicit:

```text
source input -> OCR/PDF text extraction -> teacher-reviewed text -> grading packet -> model draft or manual review -> teacher final review -> export/archive/backup
```

The app must not collapse those layers into one mutable blob.

## App layers

```text
GradeDraftApp.swift
ContentView.swift           — NavigationSplitView with assignment list and feature sections
GradeDraftViewModel.swift   — all state transitions; PDF import; OCR review; evidence; roster; curriculum; backup/restore
Models/GradeDraftModels.swift
Services/
  OCRService.swift
  GradingService.swift      — protocols, validators, unavailable-local-grading service
  FoundationModelGradingService.swift
  PromptBuilder.swift
  GradeTotals.swift
  LocalJSONStore.swift      — compatibility store and MarkdownReportBuilder
  RosterImportService.swift
  CurriculumCatalogService.swift
Export/
  CSVExportService.swift
  PDFExportService.swift    — local student and teacher-audit PDF rendering
  BundleExportService.swift — local teacher ZIP archives, gradebook archive, full backup, restore
Persistence/
  Database.swift            — normalized GRDB schema, migrations, load/save graph
  GRDBAssignmentStore.swift
Rubrics/
  MarkdownRubricParser.swift
Views/
  DocumentScannerView.swift
  LocalCapabilityBanner.swift
  GradeResultView.swift     — draft view, full final-review editor, evidence editor
Resources/
  Info.plist
  PrivacyInfo.xcprivacy
```

## Service boundaries

- `OCRServicing` owns local OCR. The default implementation uses Apple Vision.
- `GradeDraftViewModel.applyPDFFile(_:)` owns local PDF import orchestration using PDFKit, rendered page images, source refs, digital text extraction, and OCR fallback.
- `GradingServicing` owns local AI draft generation. The default implementation is guarded behind Foundation Models availability.
- `CapabilityChecking` exposes local AI availability so the UI only presents capabilities that are actually available.
- `AssignmentStoring` owns local assignment, class, student, roster, source, OCR, final review, and evidence persistence.
- `MarkdownReportBuilder` owns local Markdown reports with student/audit separation.
- `PDFExportService` owns deterministic local PDF rendering with headings, page breaks, and page numbers.
- `BundleExportService` owns ZIP archives, full backup manifests, restore preview, source restoration, conflict handling, and safe archive paths.
- `RosterImportService` owns CSV roster preview, duplicate detection, and rejected-row reasons.
- `CurriculumCatalogService` owns local offline curriculum catalog references and provenance copy.

## Grading paths

Two teacher-controlled paths both produce `FinalGradeReview`:

1. **AI draft path**: `draftGrade()` → `GradingServicing` → `FinalGradeReview` via `startFinalReviewFromLatestDraft()`. Requires local AI availability.
2. **Manual path**: `startManualFinalReview()` → creates `FinalGradeReview` from parsed rubric criteria or a teacher-review-required criterion. Does not require local AI.

Both paths use the same final-review editor, approval gate, export flow, evidence source references, and audit trail.

## Data-state rules

- `SourceInputRef` records pasted text, scans/photos, original PDFs, and rendered PDF pages.
- `OCRDocument`, `OCRPage`, and `OCRLine` store OCR pages, raw/corrected text, line confidence, line review status, rejection state, and normalized bounding boxes.
- `reviewedStudentText` is the only student text eligible for grading.
- Rejected OCR lines are preserved for audit but excluded from reviewed text.
- `EvidenceReference` stores source kind, OCR line ID, page index, span offsets where known, bounding box where known, confirmation state, and quote.
- `GradeDraftResult` stores model-proposed scoring and raw model/audit metadata.
- `FinalGradeReview` stores teacher-final scoring and private teacher notes.
- `CurriculumMapping` connects assignment, criterion, or evidence to local curriculum catalog items.
- `ExportRecord` records export kind, content fingerprint, private-note sensitivity, and original-source inclusion.
- `AuditEvent` records local state transitions.

## Staleness

`AssignmentRecord.gradingPacketFingerprint` is derived from assignment metadata, reviewed text, rubric, instructions, answer key, exemplar, OCR review status, source references, evidence references, and curriculum mappings. Draft and final review records store the fingerprint used to produce them. If inputs change, the app marks existing draft/final review state stale and blocks student-facing export until a fresh teacher-approved final review exists.

## Persistence posture

The primary persistence path is normalized GRDB. `GradeDraftDatabase` creates and uses tables for classes, students, rosters, student work, source inputs, PDF sources, OCR documents/pages/lines/revisions, rubrics/criteria/levels, instructions, answer keys, expected elements, exemplars, curriculum items/mappings, grading packets, proposals, reviews, evidence references, exports, audit events, and backup/restore events. Complete JSON payload rows are retained as compatibility/export fallback, and tests cover loading from normalized rows after compatibility payloads are removed.

## Local-only posture

No cloud services, remote AI, remote OCR, accounts, telemetry, analytics, subscriptions, hosted assets, Firebase, RevenueCat, or server APIs are introduced. Runtime validation still requires Xcode or equivalent Apple SDK tooling.
