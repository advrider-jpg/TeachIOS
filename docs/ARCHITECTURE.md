# GradeDraft Architecture

GradeDraft is an Apple-native, local-first iOS scaffold. The architectural rule is that each state boundary remains explicit:

```text
source input -> OCR output -> teacher-reviewed text -> grading packet -> model draft -> teacher final review -> export
```

The app must not collapse those layers into one mutable blob.

## App layers

```text
GradeDraftApp.swift
ContentView.swift           — NavigationSplitView with assignment list and detail
GradeDraftViewModel.swift   — all state transitions; manual and AI-draft grading paths
Models/GradeDraftModels.swift
Services/
  OCRService.swift
  GradingService.swift      — protocols, validators, UnavailableLocalGradingService
  FoundationModelGradingService.swift
  PromptBuilder.swift
  GradeTotals.swift
  LocalJSONStore.swift      — JSON store and MarkdownReportBuilder
Export/
  CSVExportService.swift
  PDFExportService.swift    — not implemented; throws not-implemented
  BundleExportService.swift — not implemented; throws not-implemented
Persistence/
  Database.swift
  GRDBAssignmentStore.swift
Rubrics/
  MarkdownRubricParser.swift
Core/
  AppDependencies.swift
Views/
  DocumentScannerView.swift
  LocalCapabilityBanner.swift
  GradeResultView.swift     — GradeResultView (draft view), FinalGradeReviewView (full editor), FinalCriterionEditor
Resources/
  Info.plist
  PrivacyInfo.xcprivacy
```

## Service boundaries

- `OCRServicing` owns local OCR. The default implementation uses Apple Vision.
- `GradingServicing` owns local AI draft generation. The default implementation is guarded behind Foundation Models availability.
- `CapabilityChecking` exposes local AI availability so the UI can avoid fake readiness.
- `AssignmentStoring` owns local assignment persistence.
- `MarkdownReportBuilder` owns local report generation.
- `CSVExportService` owns CSV export with formula-injection hardening.
- PDF and ZIP services throw a not-implemented error; they are not exposed in UI.

## Grading paths

Two distinct teacher-controlled paths both produce `FinalGradeReview`:

1. **AI draft path**: `draftGrade()` → `GradingServicing` → `FinalGradeReview` via `startFinalReviewFromLatestDraft()`. Requires local AI availability.
2. **Manual path**: `startManualFinalReview()` → creates `FinalGradeReview` from parsed rubric criteria or a single teacher-review-required criterion. Does not require local AI.

Both paths produce the same `FinalGradeReview` model and use the same approval gate, export flow, and audit trail.

## Data-state rules

- `SourceInputRef` records source images or pasted text references.
- `OCRDocument` stores OCR pages and OCR line metadata.
- `reviewedStudentText` is the only student text eligible for grading.
- `GradeDraftResult` stores model-proposed scoring.
- `FinalGradeReview` stores teacher-final scoring.
- `FinalCriterionScore` keeps proposed points and final points separate.
- `AuditEvent` records local state transitions.

## Staleness

`AssignmentRecord.gradingPacketFingerprint` is derived from reviewed text, rubric, instructions, answer key, exemplar, OCR review status, and source references. Draft and final review records store the fingerprint used to produce them. If inputs change, the app marks existing draft/final review state stale.

## Deferred production hardening

The scaffold uses JSON for local persistence to stay easy to inspect. Production should move to SQLite or SwiftData with migrations, import/restore preflight, and stronger audit-query support.
