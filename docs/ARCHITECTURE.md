# GradeDraft Architecture

GradeDraft is an Apple-native, local-first iOS scaffold. The architectural rule is that each state boundary remains explicit:

```text
source input -> OCR output -> teacher-reviewed text -> grading packet -> model draft -> teacher final review -> export
```

The app must not collapse those layers into one mutable blob.

## App layers

```text
GradeDraftApp.swift
ContentView.swift
GradeDraftViewModel.swift
Models/GradeDraftModels.swift
Services/
  OCRService.swift
  GradingService.swift
  FoundationModelGradingService.swift
  PromptBuilder.swift
  GradeTotals.swift
  LocalJSONStore.swift
Views/
  DocumentScannerView.swift
  LocalCapabilityBanner.swift
  GradeResultView.swift
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
