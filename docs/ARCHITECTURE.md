# MarkForMe Architecture

MarkForMe is an Apple-native, local-first iOS app scaffold. The architectural rule is that each state boundary remains explicit:

```text
source input -> OCR/PDF text extraction -> teacher-reviewed text -> grading packet -> prompt redaction -> AI readiness / packet preview -> read-only local lookup tools -> model draft / feedback rewrite / manual review -> teacher final review -> export/archive/backup
```

The app must not collapse those layers into one mutable blob.

## App layers

```text
GradeDraftApp.swift
ContentView.swift           — NavigationSplitView with assignment list and feature sections
GradeDraftViewModel.swift   — all state transitions; PDF import; scanned text review; evidence; roster; curriculum; AI readiness/packet preview; feedback rewrite; safe App Intent handoff; backup/restore
Models/GradeDraftModels.swift
Services/
  OCRService.swift
  GradingService.swift      — protocols, validators, unavailable-local-grading service
  FoundationModelGradingService.swift
  PromptBuilder.swift       — model-visible prompt construction with identity redaction
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
AI/Evaluation/
  AIEvaluation.swift        — deterministic evaluation fixtures, preflight checks, draft checks, anonymized reports
AI/Tools/
  LocalGradingToolSupport.swift — read-only local tool policy, source-labeled snippets, lexical evidence index, call audit
AI/Batch/
  AIBatchReadiness.swift    — deterministic batch readiness rows and one-at-a-time local queue policy
Views/
  DocumentScannerView.swift
  LocalCapabilityBanner.swift
  GradeResultView.swift     — draft view, full final-review editor, evidence editor
Resources/
  Info.plist
  PrivacyInfo.xcprivacy
```

## Service boundaries

- `OCRServicing` owns local OCR. The default implementation uses Apple Vision. `PDFImportPlanner` owns deterministic mixed-PDF page classification and merges digital text pages with OCR-recognized scanned pages so page-level coverage can be tested without PDFKit runtime access.
- `GradeDraftViewModel.applyPDFFile(_:)` owns local PDF import orchestration using PDFKit, rendered page images, source refs, digital text extraction, and OCR fallback.
- `GradingServicing` owns local AI draft generation and feedback rewrite. The default implementation is guarded behind Foundation Models availability.
- `LocalGradingToolSession` owns assignment-scoped, read-only, source-labeled lookup helpers for rubric, evidence, OCR/source references, answer keys, exemplars, curriculum references, selected constraints, and packet limits. It enforces per-request call limits, output character limits, no writes, no network, and produces `LocalToolCallAudit` records. `LocalAIGradingToolbox` remains as compatibility wrappers for simple call sites.
- `CapabilityChecking` exposes local AI availability so the UI only presents capabilities that are actually available.
- `AssignmentStoring` owns local assignment, class, student, roster, source, OCR, final review, and evidence persistence.
- `MarkdownReportBuilder` owns local Markdown reports with student/audit separation.
- `ExportPolicy` owns export audience/sensitivity policy and shared risk-summary calculation used by both ViewModel export state and SwiftUI confirmation sheets.
- `PDFExportService` owns deterministic local PDF rendering with headings, page breaks, and page numbers.
- `BundleExportService` owns ZIP archives, full backup manifests, restore preview, source restoration, conflict handling, and safe archive paths.
- `RosterImportService` owns CSV roster preview, duplicate detection, and rejected-row reasons.
- `CurriculumCatalogService` owns local offline curriculum catalog references and provenance copy. The bundled Australian Curriculum catalog is a compact shell plus `curriculum_catalog_acara_v9_index.json` and bounded source-key shards under `Resources/JSON/CurriculumShards`; the loader fails closed if an indexed shard is missing or has the wrong item count, then reconstructs the full offline catalog for existing UI flows. Repeated lookup uses the prebuilt item/search index for the bundled catalog and falls back to an in-memory index for teacher-imported catalogs.

## Grading paths

Two teacher-controlled paths both produce `FinalGradeReview`:

1. **AI draft path**: `draftGrade()` → `GradingServicing` → `FinalGradeReview` via `startFinalReviewFromLatestDraft()`. Requires local AI availability.
2. **Manual path**: `startManualFinalReview()` → creates `FinalGradeReview` from parsed rubric criteria or a teacher-review-required criterion. Does not require local AI.

Both paths use the same final-review editor, approval gate, export flow, evidence source references, and audit trail.

## Data-state rules

- `SourceInputRef` records pasted text, scans/photos, original PDFs, and rendered PDF pages.
- `OCRDocument`, `OCRPage`, and `OCRLine` store OCR pages, raw/corrected text, line confidence, line review status, rejection state, and normalized bounding boxes.
- `reviewedStudentText` is the only student text eligible for grading.
- OCR correction typing is staged in the line editor and becomes durable only on an explicit save/commit, focus loss, confirm, reject, or evidence action. Unchanged correction commits do not create duplicate saves or misleading audit events.
- Rejected OCR lines are preserved for audit but excluded from reviewed text.
- `EvidenceReference` stores source kind, OCR line ID, page index, span offsets where known, bounding box where known, confirmation state, and quote.
- `GradeDraftResult` stores model-proposed scoring and raw model/audit metadata.
- `FinalGradeReview` stores teacher-final scoring and private teacher notes.
- `CurriculumMapping` connects assignment, criterion, or evidence to local curriculum catalog items.
- `ExportRecord` records export kind, content fingerprint, private-note sensitivity, and original-source inclusion.
- `AuditEvent` records local state transitions.

## Staleness

`AssignmentRecord.gradingPacketFingerprint` is derived from assignment metadata, reviewed text, rubric, instructions, answer key, exemplar, scanned text review status, source references, evidence references, and curriculum mappings. Draft and final review records store the fingerprint used to produce them. If inputs change, the app marks existing draft/final review state stale and blocks student-facing export until a fresh teacher-approved final review exists.

## Persistence posture

The primary persistence path is normalized GRDB. `GradeDraftDatabase` creates and uses tables for classes, students, rosters, student work, source inputs, PDF sources, OCR documents/pages/lines/revisions, rubrics/criteria/levels, instructions, answer keys, expected elements, exemplars, curriculum items/mappings, grading packets, proposals, reviews, evidence references, exports, audit events, and backup/restore events. Complete JSON payload rows are retained as compatibility/export fallback, and tests cover loading from normalized rows after compatibility payloads are removed.

Normalized GRDB rows must cover user-visible grading state, not just a lossy subset. Rubric import mode and teacher-confirmed parsed rubric JSON are persisted with the assignment row. OCR document metadata is persisted through `ocr_documents`, pages through `ocr_pages`, and lines through `grade_draft_ocr_lines`; load must preserve engine, engine version, created date, review status, reviewed date, page dimensions, and empty pages rather than inferring a default document from line flags.

Routed screen assignment IDs fail closed. A stale or invalid route shows an assignment-not-found state and exposes no mutation, grading, import, review, or export controls for the currently selected assignment.

## Local-only posture

No cloud services, remote AI, remote OCR, accounts, telemetry, analytics, subscriptions, hosted assets, Firebase, RevenueCat, or server APIs are introduced. Runtime validation still requires Xcode or equivalent Apple SDK tooling.

## Foundation Models typed draft path

MarkForMe uses Apple Foundation Models only as a local draft-assistance path. The production service requests typed guided-generation proposal objects, adapts those objects into `GradeDraftResult`, and then runs `GradeDraftValidator.normalizeAndValidate` before any draft is stored or shown for teacher final review.

The draft path is:

```text
teacher-reviewed packet -> prompt redaction -> AI readiness report -> packet preview -> local validation -> read-only local lookup policy -> prompt budget plan -> full/compact/per-criterion typed generation with progress/cancellation -> app validator -> teacher final review
```

The deterministic local tool session is source-implemented under `AI/Tools`. It does not claim Foundation Models runtime tool invocation in this environment; direct SDK `Tool` wrappers still require Xcode 26+ API compilation and physical-device validation. Required grading logic remains in app code and validators, never behind model-selected tool calls.

`AIBatchReadinessAnalyzer` provides deterministic batch queue readiness rows. It only reports which assignments are ready, need review, or are blocked; it does not call the model, create drafts, approve grades, or export student-facing reports. Batch queue policy is one assignment at a time with teacher pause/cancel controls.

The prompt budgeter must not silently truncate reviewed student text. When the packet cannot fit safely in the on-device model context, the app either drafts criterion-by-criterion from the full reviewed text and grading materials or fails with an explicit local-too-large message. Manual final review remains available when local AI is unavailable or blocked.

Safe App Intents can hand off into review workflows, AI Readiness, packet preview, scanned text review, curriculum, blank assignment-shell creation, pasted student-work save, recommended AI constraints, and local assignment-title search. Shortcuts resolve assignments through a local `AssignmentEntity` that redacts known student/class identity from display titles and does not expose class, roster, student-name, or student-ID properties. They do not perform background grading, final approval, student-facing export, upload, or network work.

The App Intent handoff path stores a pending launch request locally, the app consumes it once, performs only the requested safe local action, and navigates to the concrete screen when an assignment can be resolved. Pasted student-work shortcuts save text through the same reviewed-input mutation path as the paste UI. Manual-review and recommended-constraint shortcuts reuse the existing view-model methods and surface normal in-app errors when gates are not met.

The model-visible packet excludes student display name, student ID, class group ID, class name, roster membership, source filenames, and local source file paths by default. These fields remain in local assignment state where needed for teacher workflow, exports, and audit records, but prompt construction uses the redacted packet view.

`AIReadinessAnalyzer` and `AIPacketPreviewBuilder` are deterministic app-side surfaces. They do not call the model, do not create a draft, and do not make final-review state durable. They expose the real capability status, OCR/rubric/student-text gates, prompt-injection warnings, custom-instruction lint warnings, prompt version, prompt fingerprint, packet fingerprint, and conservative budget plan before generation.

`AIGenerationProgress` is also deterministic app-side state. `GradeDraftViewModel` owns the active draft task, publishes progress stages, and cancels that task before any validated draft is stored. A cancelled generation does not create `latestDraft` or final-review state.

Final-review criterion accept/reject controls are persisted view-model actions. Accepting a criterion clamps the draft suggestion into the teacher-final point range and marks that criterion approved, while still requiring final-grade approval. Rejecting a criterion leaves it unapproved with teacher rationale so export remains blocked until the teacher edits and approves.

The local AI evaluation harness is split between deterministic CI-safe checks and device-only model runs. Deterministic preflight builds real `GradingInput`, runs local validation, prompt budgeting, readiness analysis, identity-redaction checks, and expected constraint checks without attempting a model call. Device-only runs can inject the real Foundation Models service and use the same fixtures to capture validation results and anonymized report metadata.

## Production-readiness additions — 2026-05-31

Release configuration lives under `Config/`, with replace-before-release bundle and team values instead of hard-coded signing credentials. `LocalDataProtection` centralizes backup exclusion and best-effort file protection for local databases, fallback JSON persistence, staged backup imports, source images, and export artifacts. `CurriculumCatalogService` loads bundled Australian Curriculum JSON resources and exposes read-only search/mapping data to SwiftUI; teachers must explicitly map references before the references enter grading packets.
