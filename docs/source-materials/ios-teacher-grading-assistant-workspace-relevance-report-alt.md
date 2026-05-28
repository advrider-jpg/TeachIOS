I treated the available workspace as the uploaded/currently searchable materials, not as a live local repo checkout. I found no directly reusable Swift/iOS code, but I did find substantial reusable architecture, data-model, test, offline/privacy, OCR/HTR, grading/assessment, import/export, and anti-fake-state material.

## 1. Executive summary

The available materials are relevant, but mostly as design source material, not copy-paste implementation.

The strongest reusable assets are:

1. **SchoolMAP materials:** assessment records, grading scales, students/classes/terms, result entry, local SQLite-style persistence, import/export, Playwright tests, and local-only hardening. SchoolMAP is the closest conceptual source for assignment setup, roster/assessment/result data, deterministic totals, offline persistence, and teacher-facing data management. It is an offline browser-based student assessment tracker using React/TypeScript/Vite/sql.js, with local persistence and verified single-file distribution.
2. **CommenterV3 materials:** offline teacher report-writing, roster/result imports, generated report comments, teacher review, DOCX/XLSX/XLS export, IndexedDB-first persistence, anti-fake-state rules, local backup warnings, and spreadsheet hardening. This is highly relevant to student-facing feedback, export workflows, teacher approval, privacy copy, and “AI proposes / teacher finalizes” UX even though it is a web app, not iOS.
3. **Handwriting/OCR research synthesis:** the current OCR/HTR reports are directly relevant to future phases involving scanned handwritten responses, worksheet scanning, page parsing, OCR confidence, teacher review, coordinate grounding, abstention, and visual evidence. The key surviving thesis is reliability-first hybrid OCR: page parsing, confidence, bounded rescue, coordinate grounding, validation, abstention, and review.
4. **Local/offline AI materials:** local model hardware guidance and local-first thinking are directionally relevant, but less directly portable to an Apple-native iOS app because iOS should prefer Apple Vision, VisionKit, Foundation Models where available, Core ML, SwiftData/SQLite, and device availability checks.

The major gap is that none of the inspected materials appears to already implement an Apple-native SwiftUI grading app, Apple Foundation Models integration, VisionKit capture flow, or iOS Core ML handwriting recognizer. The current value is therefore requirements mining and architecture transfer, not code reuse.

## 2. Relevant materials found

### SchoolMAP assessment tracker

SchoolMAP is directly relevant to the iOS app’s education data layer. It includes offline-first runtime, single-file distribution, local persistence using a base64-encoded SQLite database, assessment management, student tracking, results entry, analytics, and import/export using a shared manifest.

Relevant extracted substance:

* It tracks students, classes, terms, cohorts, composite groups, assessments, results, grading scales, grade values, curriculum/reference tables, teacher profile, and authentication hash data through JSON/Excel backup/import paths.
* It has assessment management, student tracking, quick entry for class results, individual student results, and analytics including grade distribution, student progress, at-risk analysis, and result views.
* Its import/export system is manifest-governed so JSON and Excel schemas stay aligned, and imports validate before committing.
* It has hardening rules for failed saves, import rollback, blank-template safety, unknown-sheet reporting, grading-scale integrity, latest-attempt normalization, and local-only backup warnings.

This maps cleanly to the proposed iOS app’s assignment/rubric/submission/grading-record persistence model.

### SchoolMAP test data and workflow materials

The test data README is useful because it defines realistic education-domain scale: multiple years, classes, students, assessments, grading scales, result statuses, multiple attempts, raw scores, comments, and reporting scenarios.

Relevant extracted substance:

* 3 years of assessment data.
* 18 classes, 540 students, 180 assessments, roughly 5,600 results.
* Assessment types across English, Mathematics, Science, and HASS.
* Result statuses such as assessed, absent, exempt, and withdrawn.
* Multiple attempts and teacher comments.
* Testing scenarios for student management, assessment management, result entry, analysis/reporting, and import/export.

This is reusable as a model for iOS test fixtures and sample data.

### CommenterV3 teacher report-writing app

CommenterV3 is highly relevant to feedback generation, teacher approval, report export, local persistence, and privacy warnings. Its documentation describes an offline report-writing app for teachers that lets a teacher enter a roster, choose report subjects, add achievement results, create draft report comments, save locally, and export finished comments to Word, with spreadsheet exports also available.

Relevant extracted substance:

* It is explicitly offline/browser-persistent.
* It handles rosters, subjects, achievement results, generated draft comments, local saves, backups, and finished-comment export.
* It treats project backups as sensitive because they may include student names, achievement results, generated comments, and private teacher notes.
* It has template/import workflows for roster and achievement-result data.
* It insists that runtime code must not silently fall back to archived prototypes, sample fixtures, or root data files.

This maps strongly to the teacher-controlled grading assistant’s feedback/reporting layer.

### CommenterV3 spreadsheet import/export plan

The spreadsheet implementation plan is relevant to import/export reliability, teacher-facing templates, formula-injection hardening, validation-before-mutation, and export formats. It requires CSV/XLSX/XLS import/export without fake spreadsheet support and says .xls must be a real legacy Excel workbook, not HTML renamed with an .xls extension.

Relevant extracted substance:

* Same business validation should apply to CSV, XLSX, and XLS inputs.
* Invalid imports must produce visible errors and avoid partial mutation.
* Report exports must avoid leaking private teacher notes or internal identifiers.
* Spreadsheet formula injection must be neutralized.
* Existing DOCX export must remain working.
* Unsupported workbook/document formats must fail visibly.

This is directly reusable as an iOS import/export philosophy.

### CommenterV3 UI/anti-fake-state prompt

The OSS polish prompt is relevant because it sets concrete anti-fake-state product rules. It requires no hosted fonts, no remote images, no cloud services, no analytics, no account/sync assumptions, no fake progress, no fake readiness, no support/debug terms in ordinary UI, and no behavior changes hidden behind UI polish.

Relevant extracted substance:

* Progress/readiness must come from real data.
* Diagnostics/support-only routes must remain hidden.
* Generated report text must be preserved exactly where tests depend on it.
* Mobile layout must avoid unsafe overflow.
* Existing import/export, report generation, backups, and persistence must remain intact.

This is one of the most portable concepts for the iOS grading app: every “AI” affordance must be backed by real capability and explicit state.

### OCR/HTR synthesis and buildable architecture reports

The OCR synthesis is directly relevant to future scanned handwriting and visual-evidence phases. It concludes that the opportunity is not a magic single recognizer but a provenance-first, confidence-aware, hybrid pipeline with document typing, page parsing, reading order, recognition, selective escalation, grounding, validation, abstention, and adaptation.

The buildable OCR report adds that real handwriting OCR fails because of pipeline brittleness: distortion, layout ambiguity, segmentation drift, reading-order confusion, and inability to represent uncertainty downstream. It emphasizes staged perception pipelines with explicit contracts, observability, retries, and fallbacks.

Relevant extracted substance:

* Handwriting OCR should be treated as a systems problem, not a recognizer-only problem.
* Page parsing, line detection, reading order, confidence, and downstream uncertainty matter.
* OCR-VLMs are strongest as bounded rescue/specialized parsing components, not necessarily default engines.
* Outputs should be coordinate-grounded and schema-constrained.
* Low-confidence outputs should trigger abstention or human review.

This maps directly to the proposed “no grading from low-confidence OCR unless teacher confirms text” rule.

## 3. Relevance map

| iOS app area | Relevant source material | How it maps |
|---|---|---|
| Assignment setup | SchoolMAP assessments/classes/terms/subjects | Use assignment, class, term, subject, assessment type, and due-date structures as product patterns. |
| Rubric / grading scales | SchoolMAP grading scales and grade values | Reuse conceptually for rubric criteria, score bands, qualitative levels, deterministic totals. |
| Student work capture | OCR reports; Commenter/SchoolMAP import concepts | Capture must preserve raw input separately from extracted/confirmed text. |
| OCR review | OCR reliability synthesis | OCR output needs confidence, provenance, abstention, and teacher confirmation before grading. |
| Handwriting recognition | OCR buildable architecture report | Future HTR should use staged page/line/region processing, not a one-shot claim. |
| Evidence-linked grading | User’s app concept + OCR provenance principles | Score proposals should cite exact text spans or confirmed evidence regions. |
| Teacher review/override | Commenter generated comments and edit/export workflow | AI-generated text is draft material; teacher edits and final output must be separate. |
| Student feedback reports | CommenterV3 report generation/export | Strong conceptual source for teacher-reviewed, exportable student-facing text. |
| Local storage/audit trail | SchoolMAP local SQLite/localStorage; Commenter IndexedDB | iOS equivalent should use SwiftData/SQLite with explicit record separation and export. |
| Privacy/offline | SchoolMAP and Commenter | Core workflow should have no cloud/server dependency; backups must be described honestly. |
| Export/report generation | SchoolMAP JSON/Excel; Commenter DOCX/XLSX/XLS | iOS should export PDF, DOCX/RTF/CSV/JSON where appropriate, with formula-injection precautions for spreadsheet exports. |
| Test strategy | SchoolMAP Playwright and test data; Commenter KPIs | Translate to XCTest/UI tests, fixture datasets, import/export roundtrip tests, OCR-gating tests. |
| Anti-fake-state | Commenter and SchoolMAP hardening | No green success if zero records saved; no fake spreadsheet; no fake readiness; no unsupported OCR/grading availability. |
| Batch grading | SchoolMAP quick entry and result workflows | Conceptual model for class-level workflows, not directly portable code. |
| Poster/project grading | OCR/visual artifact future path | Needs teacher-tagged evidence and explicit distinction between detected vs confirmed visual claims. |

## 4. Reusable code inventory

### Directly reusable code

None for the iOS app. The inspected files are React/TypeScript/browser/Python-ish research materials, not SwiftUI/SwiftData/VisionKit code. The code should not be copied directly into the Apple-native app.

### Conceptually reusable implementation patterns

**SchoolMAP persistence and data manifest pattern.**
Path/material: SchoolMAP README and hardening notes.
Current behavior: local SQLite via sql.js persisted to browser localStorage; JSON/Excel import/export governed by `src/utils/dataManifest.ts`; import validates before commit.

**iOS adaptation:** use SwiftData or SQLite. Create a canonical manifest/schema for export/import. Validate import into a temporary context before committing.

**CommenterV3 tabular import/export validation pattern.**
Path/material: `client/src/lib/spreadsheet.ts` proposed in implementation plan.
Current behavior in plan: parse CSV/XLSX/XLS into a shared tabular shape, then feed identical validation functions; reject unsupported types visibly; sanitize formula-like exported strings.

**iOS adaptation:** build `ImportValidationService` and `ExportSafetyService`; use a single validation path for CSV/Excel if spreadsheet import/export exists.

**CommenterV3 readiness/anti-fake-state UI pattern.**
Path/material: OSS polish prompt.
Current behavior/rule: readiness and progress must derive from real project data; no fake state; no support-only commands in ordinary UI.

**iOS adaptation:** every grading button should check rubric availability, OCR review status, local AI availability, and deterministic scoring readiness before enabling.

**OCR/HTR staged pipeline pattern.**
Path/material: handwriting OCR architecture reports.
Current behavior/concept: page parsing, line/region detection, confidence, recognition, bounded rescue, coordinate grounding, abstention.

**iOS adaptation:** Apple Vision OCR for MVP scans, teacher review as required gate, future Core ML handwriting recognizer or OCR-VLM-style local model only if real availability exists.

## 5. Reusable product/design concepts

The most valuable design concept is separation of record layers:

1. raw source input,
2. OCR/extracted text,
3. teacher-confirmed text,
4. model-proposed grading,
5. teacher edits,
6. teacher-approved final grade and feedback.

This is consistent with the SchoolMAP/Commenter anti-fake-state posture and the OCR reliability synthesis.

A second strong concept is readiness gating. The app should not expose “Grade” as active until it has a rubric/standard, confirmed text or pasted text, local model availability, and deterministic score constraints. This follows Commenter’s readiness/real-state UI philosophy.

A third concept is teacher-facing import/export honesty. Unsupported formats should fail visibly; backups and exports should clearly explain what they contain; spreadsheet outputs should be hardened against formula injection.

A fourth concept is field-specific review thresholds. For grading, the app should treat OCR uncertainty differently depending on whether it affects quoted evidence, a numeric answer, a student name, or a general paragraph. This follows the OCR reliability synthesis.

## 6. Proposed iOS app feature map

### MVP features

* Assignment creation.
* Rubric creation/import.
* Teacher instructions, answer key, exemplar response.
* Pasted text submission.
* PDF/photo scan submission using VisionKit where available.
* Apple Vision text recognition for printed/typed text.
* OCR review/correction screen.
* Local AI grading proposal only after OCR confirmation.
* Criterion-level proposed score.
* Evidence quotes for every proposed score.
* Uncertainty flags.
* Teacher edit/override.
* Deterministic total calculation.
* Final approval record.
* Student-facing feedback export.
* Local storage and local backup/export.

### Near-term features

* Multi-page submissions.
* Batch grading queue.
* Roster and class association.
* Assignment templates.
* Rubric templates.
* CSV/JSON import/export.
* PDF feedback reports.
* Local audit trail viewer.
* Low-confidence OCR review queue.
* Side-by-side source image and extracted text review.

### Later features

* Handwriting recognition support.
* Teacher-corrected handwriting memory.
* Region-level OCR evidence.
* Multi-image artifact review.
* Teacher-tagged image evidence.
* Visual rubric support for posters/projects.
* Offline model benchmarking/evaluation harness.

### Experimental features

* Core ML custom HTR model.
* On-device layout classifier.
* Diagram or math-region detector.
* Visual artifact evidence extraction.
* Local adaptation per teacher/class/student handwriting style.
* Optional cloud/sync export, never core grading dependency.

### Explicitly defer

* Fully autonomous grading.
* Unreviewed handwriting grading.
* Independent creativity/craftsmanship judgment without teacher-confirmed evidence.
* Visual project grading without region tagging and teacher confirmation.
* Any cloud-required grading path.
* Any fake “AI available” mode when Foundation Models/Core ML/Apple Intelligence is unavailable.

## 7. MVP scope

The MVP should be narrower than the long-term vision:

### MVP input types

* pasted text,
* imported text/PDF where text is extractable,
* scanned typed work through Vision OCR,
* manually corrected OCR text.

### MVP grading

* rubric-required,
* teacher-standard-required,
* text-only,
* criterion-by-criterion,
* evidence-linked,
* teacher-finalized.

### MVP non-goals

* handwriting-first grading,
* poster/model grading,
* math notation scoring,
* diagram interpretation,
* classwide automation without review,
* cloud model fallback.

## 8. Deferred and future-feature roadmap

### Phase 2: OCR maturity

* multi-page scan review,
* page thumbnails,
* OCR confidence display,
* per-page review status,
* evidence quote-to-source-page linking.

### Phase 3: handwriting

* Apple Vision handwriting if sufficient for target devices/languages; otherwise Core ML model research.
* line/region segmentation,
* teacher-confirmed transcription workflow,
* no grading from unconfirmed handwriting.

### Phase 4: batch grading

* class roster,
* batch queue,
* status filters,
* bulk export,
* exception-only review.

### Phase 5: visual artifacts

* multi-image submissions,
* teacher region tagging,
* visual observation cards,
* “machine-detected” versus “teacher-confirmed” evidence distinction,
* rubric support for visual criteria.

## 9. Proposed iOS architecture

Use a modular Apple-native architecture:

```text
App/
  GradeAssistApp.swift
  AppEnvironment.swift
Features/
  Assignments/
  Rubrics/
  Submissions/
  Capture/
  OCRReview/
  Grading/
  TeacherReview/
  Reports/
  Settings/
Core/
  Models/
  Persistence/
  OCR/
  LocalAI/
  GradingEngine/
  Evidence/
  Export/
  Audit/
  Availability/
  Privacy/
  Validation/
```

### Major services

* AssignmentService
* RubricService
* SubmissionService
* DocumentCaptureService
* VisionOCRService
* OCRReviewService
* LocalAIAvailabilityService
* RubricGradingService
* EvidenceExtractor
* DeterministicScoreCalculator
* TeacherApprovalService
* ExportService
* AuditTrailService

### Persistence

Use SwiftData if the model remains simple and Apple-platform-only. Use SQLite if export/import compatibility, migrations, and audit durability matter more. Given the SchoolMAP pattern, I would prefer SQLite or a thin SQLite-backed repository layer for v1 if you expect serious export/import and audit requirements. SchoolMAP’s local SQLite-style persistence is a strong conceptual precedent, even though its implementation is browser-specific.

## 10. Data model and grading schema

A concrete internal schema should look like this:

```json
{
  "gradingRecordId": "uuid",
  "schemaVersion": "1.0",
  "assignment": {
    "assignmentId": "uuid",
    "title": "Essay 1",
    "subject": "English",
    "gradeLevel": "Year 6",
    "createdAt": "2026-05-28T09:00:00-04:00",
    "rubricId": "uuid",
    "teacherInstructionsId": "uuid",
    "answerKeyId": "uuid",
    "exemplarIds": ["uuid"]
  },
  "studentSubmission": {
    "submissionId": "uuid",
    "studentId": "uuid",
    "studentDisplayName": "Student A",
    "sourceType": "pasted_text | scan | photo | pdf | handwritten_work | visual_artifact",
    "sourceInputRefs": [
      {
        "sourceId": "uuid",
        "kind": "image | pdf | text",
        "localUri": "app-local-reference",
        "pageNumber": 1,
        "sha256": "hash"
      }
    ],
    "submittedAt": "2026-05-28T09:10:00-04:00"
  },
  "extraction": {
    "ocrEngine": "AppleVision",
    "ocrAvailability": {
      "available": true,
      "reasonUnavailable": null
    },
    "extractedText": "Raw OCR text here",
    "correctedText": "Teacher-confirmed text here",
    "confidenceSummary": {
      "mean": 0.91,
      "minimum": 0.64,
      "lowConfidenceSpanCount": 4
    },
    "reviewStatus": "not_required | required | reviewed | blocked",
    "handwritingRecognition": {
      "attempted": false,
      "status": "not_applicable | unavailable | attempted | teacher_confirmed | blocked",
      "requiresTeacherConfirmation": true
    },
    "textSpans": [
      {
        "spanId": "uuid",
        "text": "quoted span",
        "pageNumber": 1,
        "boundingBox": {
          "x": 0.1,
          "y": 0.2,
          "width": 0.5,
          "height": 0.03
        },
        "confidence": 0.88,
        "teacherConfirmed": true
      }
    ]
  },
  "rubric": {
    "rubricId": "uuid",
    "criteria": [
      {
        "criterionId": "uuid",
        "name": "Claim and thesis",
        "maxPoints": 4,
        "levels": [
          {
            "levelId": "uuid",
            "label": "Proficient",
            "points": 3,
            "description": "Clear claim with adequate support."
          }
        ]
      }
    ]
  },
  "teacherInstructions": {
    "customInstructions": "Apply the attached rubric. Do not penalize spelling unless it obscures meaning.",
    "answerKeyRef": "uuid",
    "exemplarRefs": ["uuid"]
  },
  "localAI": {
    "provider": "AppleFoundationModels",
    "available": true,
    "availabilityCheckedAt": "2026-05-28T09:12:00-04:00",
    "modelIdentifier": "device-local",
    "reasonUnavailable": null
  },
  "proposal": {
    "proposalId": "uuid",
    "status": "not_started | blocked | generated | review_required | rejected | approved",
    "blockedReasons": [],
    "criterionScores": [
      {
        "criterionId": "uuid",
        "proposedPoints": 3,
        "maxPoints": 4,
        "evidenceRefs": ["span-1", "span-2"],
        "evidenceQuotes": ["The student writes...", "The conclusion states..."],
        "explanation": "The response states a clear claim but support is uneven.",
        "uncertaintyFlags": [
          {
            "type": "weak_evidence | OCR_uncertain | rubric_ambiguous | subjective_judgment",
            "message": "One quoted sentence came from a low-confidence OCR span."
          }
        ],
        "requiresTeacherReview": true
      }
    ],
    "deterministicTotal": {
      "proposedTotal": 15,
      "maxTotal": 20,
      "calculationMethod": "sum_of_criteria"
    },
    "draftStudentFeedback": "You made a clear claim and used some evidence..."
  },
  "teacherReview": {
    "reviewedBy": "teacher-local-id",
    "teacherEdits": [
      {
        "field": "criterionScores[0].proposedPoints",
        "oldValue": 3,
        "newValue": 4,
        "reason": "Teacher judged support stronger after review."
      }
    ],
    "finalScores": [
      {
        "criterionId": "uuid",
        "points": 4,
        "teacherApproved": true
      }
    ],
    "finalFeedback": "Teacher-approved feedback.",
    "approvedAt": "2026-05-28T09:20:00-04:00"
  },
  "visualArtifact": {
    "enabled": false,
    "artifactType": "poster | model | diagram | worksheet | other",
    "imageRegions": [
      {
        "regionId": "uuid",
        "sourceId": "uuid",
        "label": "caption",
        "boundingBox": {
          "x": 0.1,
          "y": 0.1,
          "width": 0.3,
          "height": 0.2
        },
        "machineDetected": true,
        "teacherConfirmed": false,
        "visualObservation": "possible title area",
        "unsupportedOrUncertainClaims": ["Model cannot assess craftsmanship reliably."]
      }
    ],
    "teacherTaggedEvidence": []
  },
  "export": {
    "exportStatus": "not_exported | exported",
    "formats": ["pdf", "json"],
    "exportedAt": null
  },
  "auditTrail": [
    {
      "eventId": "uuid",
      "timestamp": "2026-05-28T09:11:00-04:00",
      "actor": "teacher | system",
      "eventType": "ocr_completed | ocr_reviewed | proposal_generated | final_approved",
      "details": {}
    }
  ],
  "reviewRequiredFlags": [
    "ocr_low_confidence",
    "teacher_final_approval_required"
  ]
}
```

## 11. OCR and handwriting strategy

### MVP OCR strategy

Use Apple Vision for printed/typed text recognition where available. The app should store:

* source image/PDF reference,
* raw OCR text,
* text regions,
* confidence where available,
* corrected teacher-confirmed text,
* review status.

Do not grade from OCR text until review is complete if the OCR confidence is low or if the source appears handwritten.

### Handwriting strategy

The OCR reports strongly argue against treating handwriting as solved. A serious handwriting flow must use page/line/region segmentation, confidence, teacher review, and abstention.

The iOS plan should therefore be:

1. Defer handwriting grading from raw OCR in MVP.
2. Allow handwritten scans to be captured and manually transcribed or teacher-corrected.
3. Later, add handwriting extraction as assistive only.
4. Require teacher confirmation before grading.
5. Preserve machine-detected text separately from teacher-confirmed text.
6. Use Core ML only if a real local model is selected and benchmarked.

## 12. Implementation plan

### Phase 0: architecture foundation

* Define Swift packages/modules.
* Create persistence schema.
* Implement audit trail.
* Implement assignment, rubric, submission, OCR extraction, grading proposal, teacher final records.
* Add local availability checks.

### Phase 1: text-only MVP

* Assignment creation.
* Rubric builder.
* Teacher instructions/answer key/exemplar entry.
* Pasted text submission.
* Local AI grading proposal.
* Evidence quote requirement.
* Deterministic score calculation.
* Teacher review and finalization.
* PDF/JSON export.

### Phase 2: scan/OCR MVP

* VisionKit document scanning.
* Vision OCR.
* OCR review screen.
* Low-confidence gating.
* Link evidence quotes to confirmed OCR spans.

### Phase 3: classroom workflow

* Roster/class support.
* Batch submission queue.
* Filtering by status.
* Bulk export.
* Assignment-level dashboard.

### Phase 4: handwriting assist

* Capture handwritten scans.
* Local handwriting extraction if available.
* Manual correction.
* Review-required flags.
* Benchmark before enabling any grade-from-handwriting flow.

### Phase 5: visual artifact assessment

* Multi-image artifact capture.
* Teacher-tagged image regions.
* Visual evidence packet.
* Feedback assistance only.
* No independent subjective visual scoring without teacher confirmation.

## 13. Testing and validation plan

Use SchoolMAP’s test-data discipline and Commenter’s import/export hardening as models.

### Unit tests

* Rubric total calculation.
* Score band validation.
* “No rubric / no grading” rule.
* Evidence required per proposed score.
* OCR review gating.
* Local AI unavailable gating.
* Audit trail event creation.
* Export schema generation.

### UI tests

* Create assignment.
* Add rubric.
* Paste student text.
* Generate proposal.
* Edit proposed score.
* Approve final grade.
* Export feedback.
* Try to grade without rubric: blocked.
* Try to grade low-confidence OCR without review: blocked.
* Disable local AI availability: grading unavailable with explicit copy.

### OCR tests

* Printed scan fixture.
* Low-confidence scan fixture.
* Multi-page fixture.
* Handwritten fixture marked review-required.
* OCR correction persistence.

### Release-readiness criteria

* No active grading button unless prerequisites are real.
* No proposed score without evidence.
* No final score without teacher approval.
* No failed import/export appearing successful.
* No raw OCR treated as teacher-confirmed text.
* No unsupported local AI feature shown as available.
* All local-only privacy copy accurate.

## 14. Privacy/offline requirements

The iOS app should adopt the strictest available patterns from SchoolMAP and Commenter:

* Core grading must run without server dependency.
* No analytics/tracking by default.
* No remote AI calls in default mode.
* Local backups/exports must be labeled sensitive.
* Any device lock/password feature must not be described as encryption unless it actually encrypts stored records.
* Export files must not leak internal IDs or private notes unless intentionally included.
* Spreadsheet exports must sanitize formula-like values.

Commenter’s warning pattern is especially relevant: backup files may include student data, generated comments, and teacher notes, and should not be treated as safe to send casually.

## 15. Risks, gaps, and open questions

### Major gaps

* No SwiftUI implementation exists in the inspected materials.
* No Apple Foundation Models integration exists in the inspected materials.
* No VisionKit capture code exists in the inspected materials.
* No Core ML handwriting model exists in the inspected materials.
* No real rubric-grading engine exists in the inspected materials.
* No iOS export implementation exists in the inspected materials.

### Technical risks

* Apple Foundation Models availability may vary by device, OS, locale, and model capability.
* Vision OCR may be insufficient for handwriting.
* OCR confidence may be hard to expose at the exact granularity needed.
* Teacher review UX can become burdensome if too many spans are flagged.
* Rubric ambiguity may cause unstable grading proposals.
* Evidence quotes may be over-selected or weakly tied to criteria.
* Visual artifact grading risks false authority.

### Product risks

* Teachers may over-trust proposed grades.
* Student-facing feedback may sound final before teacher approval.
* Batch grading can create automation pressure.
* Subjective criteria may invite fake precision.
* Privacy expectations are high because student work is sensitive.

## 16. Recommended next build steps

1. Do not start with handwriting. Start with pasted/confirmed text and rubric-based grading.
2. Build the record model first. The first implementation should create the separate records: raw input, extracted text, teacher-confirmed text, AI proposal, teacher edits, final grade.
3. Implement hard readiness gates. The grade button should be blocked unless rubric/standard exists, confirmed text exists, local AI is available, and evidence citation can be produced.
4. Build the OCR review UI before advanced OCR. VisionKit/Vision OCR is useful only if the teacher can inspect and correct the extracted text.
5. Use the SchoolMAP/Commenter privacy posture. Backups and exports should be sensitive local files; local lock is not encryption unless actual encryption exists.
6. Use the OCR research as future-phase architecture, not MVP scope. Handwriting and visual projects should be assistive, teacher-confirmed, and confidence-gated.

The clean v1 build target is:

SwiftUI + local persistence + assignment/rubric/submission model + pasted/confirmed text grading + evidence-linked proposal + teacher finalization + export.

Then add:

VisionKit capture + Apple Vision OCR + teacher OCR review.

Only after that should the app attempt:

handwriting assistance, visual artifacts, or Core ML custom models.

