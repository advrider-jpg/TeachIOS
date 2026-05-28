# GradeDraft OSS Search and Implementation Plan

Yes. I went back through this as a real architecture/package-selection exercise. The better conclusion is:

**Build this as a native Swift/iPadOS app with Apple frameworks at the core, and use OSS packages only around persistence, rubric parsing, export, dependency injection, and tests. Do not try to find an OSS “AI grading engine.” That is the wrong dependency boundary.**

Apple’s current developer materials support the key technical premise: the Foundation Models framework gives access to the on-device model behind Apple Intelligence, with private, no-internet operation, guided generation, and tool calling; Vision has full-document text-recognition direction; Core ML remains the fallback lane for custom on-device models later.

---

## 1. Recommended Dependency Stack

For the first serious MVP, I would use:

```text
Apple frameworks:
- SwiftUI
- Vision
- VisionKit
- FoundationModels
- PDFKit
- UniformTypeIdentifiers
- PhotosUI
- Security / Keychain
- LocalAuthentication

OSS packages:
- GRDB.swift
- swift-markdown
- TPPDF
- ZIPFoundation
- SwiftCSV
- swift-dependencies
- swift-snapshot-testing
- SwiftLint

Optional/deferred:
- CoreXLSX
- MLX Swift / MLX Swift LM
- KeychainAccess
- The Composable Architecture
```

The strongest MVP is still **text-only grading**, but the infrastructure should preserve scanned image evidence so you can later add handwriting, worksheet layout, posters, and physical-project modes without redesigning the data model.

---

## 2. Package-by-Package Findings

| Area | Package / repo | Verdict | Why |
|---|---|---|---|
| On-device grading | Apple Foundation Models | **Use directly** | This is the actual Apple on-device LLM route. Apple says Foundation Models gives direct access to the on-device model, supports no-internet use, guided generation, and tool calling. |
| Capture | VisionKit | **Use directly** | Native scanner is the right capture layer. OpenScanner’s SwiftUI scanner wrapper shows the basic pattern: create `VNDocumentCameraViewController`, set its delegate, and receive scanned pages. |
| OCR | Vision | **Use directly** | OpenScanner uses `VNRecognizeTextRequest`, `.accurate`, automatic language detection, and language correction; that is the right first implementation pattern for this app. |
| OCR sample app | `pencilresearch/OpenScanner` | **Inspect/copy patterns, do not import whole app** | It is a Swift/SwiftUI open-source scanner app, privacy-oriented, using Core Data and CloudKit. The scanner/OCR code is useful, but CloudKit sync should not be copied into the zero-online MVP. |
| Rubric parsing | `swiftlang/swift-markdown` | **Use** | It parses, builds, edits, and analyzes Markdown documents, and is powered by GitHub-flavored Markdown’s `cmark-gfm`; perfect for teacher-authored rubric templates. |
| Local database | `groue/GRDB.swift` | **Use** | GRDB is a Swift SQLite toolkit focused on application development, with strong repo maturity signals. It gives cleaner audit tables than SwiftData for grading records. |
| PDF export | `techprimate/TPPDF` | **Use** | TPPDF is a fast PDF builder for iOS/macOS and supports tables, headers/footers, pagination, images, metadata, hyperlinks, and Swift Package Manager. |
| CSV export/import | `swiftcsv/SwiftCSV` | **Use lightly** | SwiftCSV supports simple CSV parsing across Apple platforms and can load CSV from strings or files. Good for gradebook import/export, but final CSV writing should include formula-injection hardening. |
| XLSX import | `CoreOffice/CoreXLSX` | **Defer** | CoreXLSX is a pure Swift XLSX parser, but it is read-only. Useful later for importing rubrics/gradebooks from Excel, not necessary for MVP. |
| Assignment bundle export | `weichsel/ZIPFoundation` | **Use** | ZIPFoundation is MIT-licensed, Swift-native ZIP handling with meaningful adoption. Use it for `.gradedraft` local export bundles. |
| Dependency injection | `pointfreeco/swift-dependencies` | **Use** | It is built to control dependencies such as file access, date/UUID generation, clocks, and external systems, which is exactly what you need for deterministic OCR/grading/export tests. |
| State architecture | `pointfreeco/swift-composable-architecture` | **Maybe use** | TCA is excellent for the capture → OCR → review → grade → finalize state machine, but it adds weight. Use it only if you are building a serious production-grade app from the start. It is designed around state management, composition, side effects, and testing. |
| UI regression tests | `pointfreeco/swift-snapshot-testing` | **Use** | SnapshotTesting compares recorded references against runtime output and works for images and textual representations, useful for grading review screens and export previews. |
| Code quality | `realm/SwiftLint` | **Use** | SwiftLint enforces Swift style and conventions and is based mainly on SwiftSyntax. Keep configuration conservative. |
| Secrets | `kishikawakatsumi/KeychainAccess` | **Optional** | It is a simple Swift wrapper for Keychain on iOS/macOS. You may not need it unless you add local passcodes, encryption keys, or optional integrations. |
| Tesseract OCR | `SwiftyTesseract` | **Avoid for MVP** | It is archived/read-only and the maintainer explicitly recommends Apple Vision first-party OCR for Apple apps. |
| Cloud essay grading demos | `GoogleCloudPlatform/essai` | **Do not use as dependency** | It is an experiment/demo built around Google Gemini and Google Cloud, not a zero-online iOS architecture. Useful only for conceptual rubric workflow ideas. |
| Agent grading frameworks | `Mentat-Lab/preclinical` | **Do not use as dependency** | It is impressive for automated grading/testing of healthcare agents, but it requires cloud model/API keys and Docker/server infrastructure, so it conflicts with your product constraints. |
| Alternate local LLM | `ml-explore/mlx-swift-lm` | **Research/defer** | MLX Swift LM supports LLM/VLM app development in Swift, but it introduces model packaging/downloading/tokenizer complexity. Good fallback if Foundation Models availability is too restrictive, not MVP-default. |

---

## 3. Architecture I Would Build

The app should be divided into hard layers. The key is to make every AI output traceable back to teacher-approved text and rubric criteria.

```text
GradeDraft
  App/
    GradeDraftApp.swift
    AppEnvironment.swift

  Features/
    Assignments/
    Rubrics/
    Capture/
    OCRReview/
    Grading/
    FinalReview/
    Export/

  Services/
    CaptureService
    OCRService
    RubricParser
    GradingPacketBuilder
    FoundationModelsGradingService
    PersistenceStore
    PDFExportService
    CSVExportService
    BundleExportService
    NetworkGuard

  Models/
    Assignment
    StudentSubmission
    CapturedPage
    OCRRun
    OCRLine
    Rubric
    RubricCriterion
    TeacherInstruction
    GradingPacket
    GradeProposal
    CriterionScoreProposal
    FinalGrade
    AuditEvent

  Tests/
    OCRFixtureTests
    RubricParserTests
    GradingPacketBuilderTests
    FoundationModelsSchemaTests
    PersistenceMigrationTests
    ExportTests
    SnapshotTests
    NetworkDenialTests
```

---

## 4. Data Model

Use GRDB with explicit tables. Do not use a loose blob-only persistence model.

```text
assignments
- id
- title
- subject
- grade_level
- created_at
- updated_at
- grading_mode

rubrics
- id
- assignment_id
- title
- raw_markdown
- parsed_version
- created_at

rubric_criteria
- id
- rubric_id
- order_index
- title
- description
- max_points
- performance_levels_json

teacher_instructions
- id
- assignment_id
- raw_text
- normalized_text
- created_at

student_submissions
- id
- assignment_id
- student_display_name
- local_identifier
- status
- created_at

captured_pages
- id
- submission_id
- page_index
- image_path
- image_sha256
- source_type

ocr_runs
- id
- submission_id
- engine
- engine_version
- started_at
- completed_at
- average_confidence
- requires_review

ocr_lines
- id
- ocr_run_id
- page_id
- order_index
- raw_text
- corrected_text
- confidence
- bounding_box_json
- teacher_confirmed

grading_packets
- id
- submission_id
- rubric_id
- teacher_instruction_id
- packet_json
- packet_sha256
- created_at

grade_proposals
- id
- submission_id
- grading_packet_id
- model_provider
- model_availability_state
- proposal_json
- created_at

final_grades
- id
- submission_id
- proposal_id
- final_score
- max_score
- teacher_feedback
- finalized_at

audit_events
- id
- entity_type
- entity_id
- event_type
- before_json
- after_json
- created_at
```

The important point is that **OCR text, AI proposal, and teacher-final grade are separate records**. Never overwrite one with another.

---

## 5. Grading Packet Contract

The model should never receive unstructured app state. It should receive a locked packet.

```json
{
  "assignment": {
    "title": "Civil War Short Response",
    "subject": "History",
    "grade_level": "8"
  },
  "rubric": {
    "criteria": [
      {
        "id": "claim",
        "title": "Claim",
        "max_points": 2,
        "levels": [
          { "points": 0, "description": "No claim" },
          { "points": 1, "description": "Vague or incomplete claim" },
          { "points": 2, "description": "Clear historically accurate claim" }
        ]
      }
    ]
  },
  "teacher_instructions": [
    "Do not penalize spelling unless meaning is unclear.",
    "Require at least two pieces of evidence."
  ],
  "student_text": {
    "confirmed_text": "The student response goes here.",
    "ocr_warnings": [
      "Line 4 had low OCR confidence and was corrected by teacher."
    ]
  },
  "required_output": {
    "must_score_each_criterion": true,
    "must_quote_student_evidence": true,
    "must_flag_uncertainty": true,
    "must_not_infer_effort_or_intent": true
  }
}
```

The model output should be schema-validated before the app accepts it:

```json
{
  "rubric_scores": [
    {
      "criterion_id": "claim",
      "proposed_points": 2,
      "max_points": 2,
      "evidence_quotes": ["..."],
      "explanation": "...",
      "confidence": "high",
      "teacher_review_required": false
    }
  ],
  "total_score": 7,
  "max_score": 10,
  "student_feedback": "...",
  "teacher_notes": "...",
  "uncertainty_flags": []
}
```

The app, not the model, should recalculate totals and reject malformed output.

---

## 6. Implementation Plan

### Phase 1: Local-Only Skeleton

Build the SwiftUI app shell, GRDB persistence, dependency container, and zero-network posture.

Acceptance criteria:

```text
- App launches without network access.
- No backend URL exists in config.
- No analytics SDK.
- No remote crash reporting SDK.
- NetworkGuard test fails the build if grading/capture/export attempts URLSession traffic.
- GRDB migrations run from a clean install.
- Basic assignment and rubric records persist locally.
```

### Phase 2: Capture and OCR

Implement VisionKit capture and Vision OCR. Use OpenScanner as a reference pattern, not as a dependency. Its code demonstrates the needed `VNDocumentCameraViewController` flow and Vision OCR request construction.

Acceptance criteria:

```text
- Teacher can scan one or more pages.
- App stores page images locally.
- App runs OCR locally.
- OCR lines are stored with order, confidence, page, and bounding box when available.
- Teacher can edit OCR text before grading.
- Low-confidence lines block grading until reviewed or explicitly accepted.
```

### Phase 3: Rubric Editor and Parser

Use `swift-markdown` for teacher-friendly rubric authoring. Teachers should be able to paste a plain rubric, but the app should normalize it into structured criteria. Swift Markdown supports parsing documents from strings or URLs and exposes a markup tree suitable for this conversion.

Acceptance criteria:

```text
- Teacher can create rubric from template.
- Teacher can paste Markdown rubric.
- Parser identifies criteria, levels, point values, and descriptions.
- Invalid rubric blocks grading.
- App shows a rubric preview before use.
```

### Phase 4: Foundation Models Grading Service

Wrap Foundation Models behind your own service boundary. Do not let UI code call `LanguageModelSession` directly.

```swift
protocol GradingService {
    func availability() async -> ModelAvailability
    func generateProposal(packet: GradingPacket) async throws -> GradeProposal
}
```

Acceptance criteria:

```text
- App checks model availability before showing “Grade.”
- If Apple Intelligence/Foundation Models is unavailable, app clearly says local AI grading is unavailable.
- App never silently falls back to cloud.
- Prompt requires criterion-by-criterion JSON-like structured output.
- App validates output before saving it.
- App recalculates total score independently.
- Every proposed score must contain evidence or a teacher-review flag.
```

### Phase 5: Teacher Review Layer

This is the core product. The app must make clear which material came from OCR, which came from the AI, and which was finalized by the teacher.

Acceptance criteria:

```text
- Grade proposal screen shows each rubric criterion separately.
- Each criterion shows proposed score, evidence quote, explanation, confidence, and flags.
- Teacher can accept, edit, or reject each criterion score.
- Final grade cannot be created until all criteria are resolved.
- App stores final grade separately from AI proposal.
```

### Phase 6: Export

Use TPPDF for polished reports, SwiftCSV for gradebook-style export/import, and ZIPFoundation for complete local bundles. TPPDF has the right PDF feature set for tables, headers/footers, metadata, pagination, images, and hyperlinks. ZIPFoundation is the right package for a portable `.gradedraft` archive.

Acceptance criteria:

```text
- Export PDF includes assignment, rubric, final score, criterion scores, feedback, and evidence.
- CSV export escapes spreadsheet-formula injection strings beginning with =, +, -, @, or leading whitespace followed by those characters.
- Bundle export includes rubric, OCR text, final grade, and optionally images.
- Export explicitly warns whether original scans are included.
```

### Phase 7: Test Hardening

Use dependency injection and snapshot tests from the beginning. `swift-dependencies` is particularly useful because it lets you control file access, dates, UUIDs, clocks, and other outside-world dependencies in tests. SnapshotTesting should cover screens where confusion would be dangerous: OCR review, AI proposal, final grade, and export preview.

Acceptance criteria:

```text
- Unit tests for rubric parser.
- Unit tests for grading packet construction.
- Unit tests for model-output validation.
- Unit tests for deterministic score total calculation.
- Snapshot tests for OCR review and final grade screens.
- Export tests for PDF/CSV presence and structure.
- Network-denial tests for scan → OCR → grade → export.
```

---

## 7. What I Would Not Build First

Do **not** start with these:

```text
- Batch grading for entire classes.
- LMS sync.
- Google Classroom integration.
- Cloud backup.
- Handwriting-heavy grading.
- Math equation grading.
- Poster/model grading.
- Fully autonomous grading.
- A custom on-device LLM shipped in the app.
- Tesseract OCR fallback.
- DOCX import.
```

Those are later phases. The first version should be boring and defensible.

---

## 8. The Actual MVP Spec

The MVP should be:

**GradeDraft: a local-first iPad app for rubric-assisted grading of text-based student work.**

Core promise:

```text
Scan or import student text work.
Review the extracted text.
Apply a teacher-provided rubric and custom instructions.
Generate a proposed criterion-by-criterion score with evidence.
Teacher reviews and finalizes.
Export a local PDF or CSV.
No student work is uploaded.
```

Minimum feature list:

```text
1. Assignment creation
2. Rubric creation from Markdown/template
3. Custom instruction input
4. Single-student scan/import
5. Vision OCR
6. OCR review/correction
7. Local Foundation Models grading proposal
8. Criterion-by-criterion teacher review
9. Final grade record
10. PDF export
11. CSV export
12. Local archive export
```

---

## 9. Final Recommended Build Order

I would implement in this exact order:

```text
1. GRDB schema + migrations
2. Assignment/rubric CRUD
3. Markdown rubric parser
4. Scanner wrapper
5. Vision OCR service
6. OCR review UI
7. Grading packet builder
8. Foundation Models availability gate
9. Foundation Models grading service
10. Output validator and deterministic score calculator
11. Teacher review/finalization UI
12. PDF export
13. CSV export
14. ZIP bundle export
15. Network-denial and snapshot tests
```

The biggest architectural rule is this:

**The app should grade only teacher-confirmed text against a structured rubric packet, and every score must trace to student evidence.**

That is what makes it technically realistic, locally private, and defensible in a school setting.

