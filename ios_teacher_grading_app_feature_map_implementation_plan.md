# iOS Teacher Grading App: Repository Findings, Feature Map, and Implementation Plan

Yes. I did a much deeper search/fetch pass across both private repositories and found a lot that is directly reusable as **product architecture**, even though I did **not** find an existing OCR or Apple-on-device-AI implementation in either repo.

The short version is this: **Commenterv3 gives you the report/comment generation, readiness, import validation, and teacher-review model. SchoolMAPv3 gives you the assessment database, offline persistence, backup/restore, grading scale, result-entry, and hardening model.** The Apple app should be built fresh in SwiftUI, but its product logic should borrow heavily from both.

---

## 1. Repository findings

### Commenterv3

Commenterv3 is an offline teacher report-writing app. Its README says it supports roster entry, report subjects, achievement results, draft report comments, local browser saves, finished DOCX export, and XLSX/XLS workflow exports. It also states that the teacher-facing package can be opened offline and that project backups may include student names, achievement results, generated comments, and private teacher notes.

The most relevant pieces for the new grading app are:

| Source area | What it gives us | How to use it in the new app |
|---|---|---|
| `Project`, `Student`, `AchievementResult`, `GeneratedReport` types | A compact teacher workflow model. | Convert into `Assignment`, `Student`, `StudentSubmission`, `GradingResult`, and `FeedbackDraft`. |
| Report readiness logic | A concrete “not ready / stale / locked / ready” model. | Use for OCR review, rubric scoring, teacher approval, and export readiness. |
| Import validation | Strict roster/result import rules. | Reuse the same “reject visibly before mutation” principle for rubrics, rosters, scanned text, and grading imports. |
| Placeholder policy | No unresolved placeholders in final teacher/parent-facing text. | Apply to AI feedback: no `[student]`, `[criterion]`, or generic filler in final output. |
| Static/offline discipline | No backend, no cloud storage, no silent sample-data fallback. | Make “no network grading” a release blocker. |
| Spreadsheet/doc export hardening | Local import/export validation and formula-injection protection. | Reuse for CSV/Excel grade exports. |

Commenterv3’s core rules are especially valuable. They require the teacher-facing app to remain a self-contained offline package, require browser-local persistence, require production comment data not to be silently substituted with fixtures, require honest generation/export readiness, and prohibit upload of student/teacher data as part of core functionality.

### SchoolMAPv3

SchoolMAP is the stronger source for assessment structure. Its README describes it as a local, offline browser app for students, classes, terms, assessments, grading scales, results, and analysis, with no backend and no runtime internet requirement. It also states that the production artifact is a single self-contained `dist/index.html` that can run from `file://` without server, external assets, CDN, telemetry, sidecar JS/CSS/WASM/JSON, or APIs.

The most relevant SchoolMAP pieces are:

| Source area | What it gives us | How to use it in the new app |
|---|---|---|
| Assessment database schema | Mature classroom assessment model. | Use as conceptual model for SwiftData/SQLite schema. |
| Grading scale model | Qualitative grades, grade values, numeric-equivalent legacy handling. | Build flexible rubric scoring and qualitative levels. |
| Result-entry model | Students × assessments × attempts × comments. | Store each AI grading pass as a reviewable result attempt. |
| Backup/restore manifest | Data categories, import/export order, sensitivity boundaries. | Build local backup/export manifest for the iOS app. |
| Persistence hardening | Atomic transactions, persistence failure surfacing, restore preflight. | Require durable local save before telling teacher grading completed. |
| Offline verifier | Runtime network audit pattern. | Build equivalent “no network grading” test suite for iOS. |
| Security notes | Password lock disclaimers and formula-injection protection. | Use same disclosures and export hardening. |

SchoolMAP’s README is very explicit that data is stored in localStorage as serialized SQLite, that backups include students, classes, terms, assessments, results, grading scales, reference tables, teacher profile data, and auth hash data, and that the local password lock is not encryption. It also requires visible failure when persistence fails and forbids reporting success for failed saves.

The SchoolMAP schema is directly useful as a model. It defines tables for learning areas, subjects, strands, grading scales, grade values, students, classes, terms, assessments, results, assessment templates, content descriptions, capabilities, teacher profile, and teacher auth.

---

## 2. Negative finding: no existing OCR or Apple AI layer

I searched for OCR, camera, Vision, image scan, upload/photo recognition, and Apple-specific AI terms across both repos. I did not find an existing implementation that can be ported. That means the new app needs a fresh native layer for:

- camera/document capture,
- image import,
- OCR,
- OCR confidence review,
- Apple on-device model availability,
- structured local AI grading.

The Apple-native stack remains the right one: Foundation Models for on-device text reasoning, Vision for OCR, VisionKit for document camera scanning, and Core ML later if you add custom local models. Apple’s developer documentation has official pages for Foundation Models, Vision text recognition, VisionKit document camera, and Core ML.

---

## 3. Concrete feature map

### A. Project/classroom layer

| New app feature | Borrow from | Concrete implementation |
|---|---|---|
| Teacher profile | SchoolMAP | Store teacher name, school, class labels, optional lock settings. Use SchoolMAP’s warning that local password locks are not encryption. |
| Class roster | Both | Use Commenterv3’s roster import shape and SchoolMAP’s student/class model. |
| Assignment setup | SchoolMAP | Model assignments like assessments: subject, grade/year, term, due date, topic, description, grading scale, rubric. |
| Assessment templates | SchoolMAP | Let teachers save reusable rubric templates. SchoolMAP already has assessment templates with instructions. |
| Local project storage | Both | SwiftData or SQLite, not cloud. Local persistence failure must block success state. |

### B. Student work intake layer

| New app feature | Borrow from | Concrete implementation |
|---|---|---|
| Scan paper work | New Apple-native code | Use VisionKit document camera. Store scanned page image locally. |
| Upload image/PDF | New Apple-native code | Use iOS document picker and Photos picker. |
| Paste typed text | New app-specific | Fast path for typed student work. |
| OCR extraction | New Apple-native code | Use Vision text recognition. Persist OCR text separately from final corrected text. |
| OCR review | Commenterv3 readiness model | Do not allow grading until OCR is reviewed or low-confidence regions are resolved. |
| Multi-page submissions | SchoolMAP result model | One `Submission` with child `SubmissionPage` records and one merged reviewed text field. |

### C. Rubric/instruction layer

| New app feature | Borrow from | Concrete implementation |
|---|---|---|
| Rubric builder | SchoolMAP grading scales | Criteria, levels, max points, descriptors, required evidence. |
| Standard rubric templates | SchoolMAP assessment templates | Save per subject/grade/task type. |
| Custom instruction sheet | Commenterv3 import validation posture | Import/paste instructions, parse into teacher-reviewable rules, never silently apply malformed instructions. |
| Answer key / exemplar | New app-specific | Optional source text used as grading reference. |
| Grading constraints | Commenterv3 context fields | Examples: “do not penalize spelling,” “require two pieces of evidence,” “grade content only.” |

### D. AI grading layer

| New app feature | Borrow from | Concrete implementation |
|---|---|---|
| Evidence packet | Commenterv3 result/report model | Build a structured packet: reviewed OCR text, rubric, instructions, answer key, student metadata, uncertainty flags. |
| Structured AI output | New Apple-native code | Require JSON-like typed output: criterion scores, evidence quotes, explanation, feedback, confidence. |
| Deterministic totals | SchoolMAP result model | App calculates totals; AI never owns final arithmetic. |
| Readiness gating | Commenterv3 report-readiness | Statuses should include `needsOCRReview`, `needsRubric`, `aiUnavailable`, `draftReady`, `teacherApproved`, `exportReady`. |
| Stale result detection | Commenterv3 fingerprints | If OCR text, rubric, or instructions change, mark AI grade stale. Commenterv3 already fingerprints generated reports against result context. |
| Locked teacher edits | Commenterv3 | Teacher-approved grades/feedback become locked. Regeneration must not overwrite them without explicit unlock. |

### E. Teacher review and export layer

| New app feature | Borrow from | Concrete implementation |
|---|---|---|
| Grade review screen | Commenterv3 `ReportGenerationStep` | Student sidebar, search, filters, to-do list, readiness badges, per-student review. |
| Manual edit | Commenterv3 | Teacher edits score and feedback. Save edit locks result. |
| Export PDF | SchoolMAP / new native | Student-facing report and teacher audit report. |
| Export CSV/Excel | Both | Spreadsheet exports must harden formula-like strings. SchoolMAP expressly requires formula-injection protection. |
| Backup | Both | Versioned local backup with checksum/fingerprint metadata. Commenterv3 backups use versioned JSON envelopes with SHA-256 checksum metadata. |

---

## 4. Proposed app data model

This should be a native SwiftData or SQLite model. I would prefer SQLite if you want auditability, backups, and portable exports; I would prefer SwiftData only if speed of development matters more than long-term control.

### Core entities

```text
TeacherProfile
- id
- displayName
- schoolName
- email optional
- createdAt
- updatedAt
- localLockEnabled
- localLockHash optional
- localLockAlgorithm optional

ClassGroup
- id
- name
- schoolYear
- term
- isArchived
- createdAt
- updatedAt

Student
- id
- firstName
- lastName
- preferredName optional
- yearLevel
- classGroupId
- notes optional
- isActive
- createdAt
- updatedAt

Assignment
- id
- title
- subject
- gradeLevel
- taskType: shortAnswer | essay | worksheet | customText
- instructionsRaw
- instructionsReviewed
- answerKey optional
- exemplar optional
- rubricId
- classGroupId
- createdAt
- updatedAt
- isArchived

Rubric
- id
- title
- subject optional
- gradeLevel optional
- totalPoints
- criteria[]
- createdAt
- updatedAt

RubricCriterion
- id
- rubricId
- name
- description
- maxPoints
- levels[]
- requiredEvidenceCount
- sortOrder

RubricLevel
- id
- criterionId
- label
- points
- descriptor
- sortOrder

Submission
- id
- assignmentId
- studentId
- sourceType: scan | image | pdf | paste
- reviewedText
- ocrReviewStatus: notNeeded | needsReview | reviewed
- createdAt
- updatedAt

SubmissionPage
- id
- submissionId
- pageNumber
- imageLocalUrl
- ocrRawText
- ocrCorrectedText
- ocrConfidenceSummary
- lowConfidenceRegionCount
- createdAt

GradingDraft
- id
- submissionId
- rubricId
- modelAvailabilitySnapshot
- evidencePacketHash
- draftStatus: blocked | generated | stale | teacherApproved | exported
- totalProposedScore
- totalMaxScore
- teacherFinalScore optional
- studentFeedbackDraft
- teacherPrivateNotes
- createdAt
- updatedAt

CriterionGrade
- id
- gradingDraftId
- criterionId
- proposedPoints
- teacherFinalPoints optional
- ratingLabel
- evidenceQuotes[]
- explanation
- confidence: low | medium | high
- teacherReviewRequired
- uncertaintyFlags[]

ExportRecord
- id
- gradingDraftId
- exportType: pdf | csv | backup
- exportedAt
- exportFingerprint
```

The model should preserve four separate texts:

1. `ocrRawText`
2. `ocrCorrectedText`
3. `reviewedText`
4. `studentFeedbackDraft` / final feedback

Do not merge those into one field. The distinction is what makes the app auditable.

---

## 5. Readiness state machine

Borrow this directly from Commenterv3’s `ReportReadinessStatus`, which distinguishes missing result, missing report, unresolved placeholder, stale report, locked-ready, and locked-stale states.

For the new app, use:

```text
Submission readiness:
- noSubmission
- importedButNotOCRed
- ocrFailed
- needsOCRReview
- reviewedTextReady

Rubric readiness:
- noRubric
- rubricMalformed
- rubricReady

AI readiness:
- appleIntelligenceUnavailable
- modelUnavailable
- gradingBlocked
- draftGenerated
- draftStale

Teacher readiness:
- needsTeacherReview
- teacherApproved
- lockedApproved
- exportReady
```

The app should only allow export when all are true:

```text
reviewedTextReady
+ rubricReady
+ draftGenerated or teacherApproved
+ no unresolved placeholders
+ deterministic total matches criterion sum
+ all required criteria have score or explicit teacher override
```

---

## 6. Detailed implementation plan

### Phase 0: Product boundary and release rules

Create a new repo with a written `CORE_RULES.md` before coding. The rules should be adapted from Commenterv3 and SchoolMAP.

Required rules:

1. **No server dependency for core grading.**
2. **No student work upload.**
3. **No cloud OCR.**
4. **No cloud AI grading.**
5. **No success state unless local save completed.**
6. **No grade without reviewed text and rubric.**
7. **No export with unresolved placeholders or stale grading.**
8. **No overwriting teacher-approved grades without explicit unlock.**
9. **All grade totals are app-calculated, not model-calculated.**
10. **Backups and exports are not encryption.**

This mirrors SchoolMAP’s local-only runtime rule and truthful persistence rule.

### Phase 1: Native shell and local storage

Build:

- SwiftUI app shell.
- Local database layer.
- Teacher profile.
- Class roster.
- Assignment list.
- Rubric list.
- Local backup/export skeleton.

Implementation choice:

- Use SQLite if you want SchoolMAP-style manifest/export control.
- Use SwiftData only if you want faster MVP development.

I would use SQLite because SchoolMAP’s data layer shows why: it can manage a complex schema, export/import manifests, preflight restore, and durable persistence. Its data manifest explicitly classifies app-reference, operational, user-configurable-reference, and internal-security data.

### Phase 2: Roster and assignment workflow

Build:

- Add/edit/archive students.
- Add/edit/archive classes.
- Create assignment.
- Add subject, grade/year, due date, instructions, answer key.
- Attach or create rubric.

Borrow from SchoolMAP:

- `Student`
- `Class`
- `Term`
- `Assessment`
- `AssessmentTemplate`
- `Result`

SchoolMAP’s schema already has student, class, term, assessment, result, grading scale, grade value, and assessment template structures.

### Phase 3: Rubric builder

Build rubric editor with:

- criteria,
- points,
- levels,
- descriptors,
- required evidence,
- optional “teacher must review” criteria,
- optional answer-key linkage.

A rubric criterion should be:

```json
{
  "name": "Evidence",
  "maxPoints": 4,
  "levels": [
    { "label": "Exceeds", "points": 4, "descriptor": "Uses multiple precise pieces of evidence." },
    { "label": "Meets", "points": 3, "descriptor": "Uses relevant evidence." },
    { "label": "Developing", "points": 2, "descriptor": "Uses limited or weak evidence." },
    { "label": "Beginning", "points": 1, "descriptor": "Evidence is missing or unclear." }
  ],
  "requiredEvidenceCount": 1
}
```

Borrow SchoolMAP’s idea of grading scales and grade values, but do not inherit its numeric-scale ambiguity. SchoolMAP expressly preserves numeric grading scales for historical/import compatibility while not supporting numeric result entry for new assessments. For this app, numeric scores are allowed because rubric points are central, but the UI must be explicit that points are criterion-level rubric points, not a generic legacy numeric scale.

### Phase 4: Capture and OCR

Build:

- “Paste text” path.
- “Scan pages” path.
- “Import image/PDF” path.
- OCR processing queue.
- Low-confidence region detection.
- Side-by-side image/text review.
- Manual correction.

No grading may run until OCR is reviewed if the submission came from an image or PDF.

Store:

```text
raw image
raw OCR text
corrected OCR text
reviewed text
OCR confidence summary
OCR review timestamp
teacher who reviewed it
```

This is the direct analog to Commenterv3’s separation between generated report text, manual edits, and locked reports. Commenterv3 saves manual edits separately and locks edited reports.

### Phase 5: Evidence packet builder

Before calling the on-device model, build an evidence packet.

```json
{
  "assignment": {
    "title": "...",
    "subject": "...",
    "gradeLevel": "...",
    "instructions": "..."
  },
  "rubric": {
    "criteria": [...]
  },
  "studentSubmission": {
    "reviewedText": "...",
    "source": "ocr-reviewed",
    "ocrWarnings": [...]
  },
  "teacherRules": [
    "Do not penalize spelling unless it affects meaning.",
    "Require at least two supporting details."
  ],
  "answerKey": "...",
  "outputRequirements": {
    "citeStudentEvidenceForEveryCriterion": true,
    "returnStructuredOutputOnly": true,
    "doNotInventFacts": true
  }
}
```

This packet should be hashed. If the reviewed text, rubric, answer key, or teacher rules change, the grading draft becomes stale. This borrows from Commenterv3’s stale-report detection using fingerprints.

### Phase 6: Local AI grading

The model prompt should not ask for “a grade.” It should ask for criterion-level findings.

Required model output:

```json
{
  "criterionGrades": [
    {
      "criterionId": "claim",
      "proposedPoints": 3,
      "maxPoints": 4,
      "ratingLabel": "Proficient",
      "evidenceQuotes": [
        "The student states that renewable energy reduces pollution."
      ],
      "explanation": "The claim is clear but not fully qualified.",
      "confidence": "medium",
      "teacherReviewRequired": false,
      "uncertaintyFlags": []
    }
  ],
  "studentFeedbackDraft": "You made a clear claim and included relevant evidence. To improve, explain how your evidence supports the claim.",
  "privateTeacherNotes": "OCR confidence was low in the final sentence."
}
```

Rules:

- The app validates that every `criterionId` exists.
- The app clamps scores to the criterion max.
- The app rejects missing evidence unless the criterion allows no evidence.
- The app calculates total score.
- The app marks draft as `needsTeacherReview`.
- The app never silently exports an AI draft as final.

### Phase 7: Review UI

Use Commenterv3’s `ReportGenerationStep` as the conceptual template. It already has:

- student sidebar,
- search,
- complete/incomplete filter,
- sort,
- to-do list,
- generation errors,
- readiness counts,
- lock/edit flow,
- safe error messages.

The new app’s review screen should have:

```text
Left pane:
- Student list
- Status badges: Needs OCR review, Needs grading, Needs teacher review, Approved
- Search/filter/sort
- Batch generate missing drafts

Center pane:
- Student reviewed text
- Evidence highlights
- Original image thumbnails if available

Right pane:
- Rubric criteria
- Proposed score
- Evidence quotes
- Teacher final score
- Feedback editor
- Approve / Lock / Regenerate
```

### Phase 8: Export

Build three exports:

1. **Student feedback PDF**
   - final score,
   - rubric breakdown,
   - feedback,
   - no private notes.

2. **Teacher audit PDF**
   - OCR source,
   - reviewed text,
   - AI proposed score,
   - teacher final score,
   - changes from proposal,
   - uncertainty flags.

3. **CSV/Excel gradebook export**
   - student,
   - assignment,
   - criterion scores,
   - total,
   - final feedback.

Follow SchoolMAP’s export safety rule: spreadsheet formula-like strings must be exported as text. SchoolMAP’s security notes say strings beginning with `=`, `+`, `-`, or `@`, including after leading spaces, are hardened in CSV and Excel exports.

### Phase 9: Backup and restore

Build:

- full local backup,
- assignment-only export,
- rubric-only export,
- class roster export,
- restore preflight,
- checksum/fingerprint,
- visible warnings that backups are not encrypted.

This should copy the SchoolMAP restore posture: preflight the backup, show counts, reject malformed/incomplete data, and preserve current data if restore fails. SchoolMAP’s tests specifically check restore preflight, invalid backup rejection, incomplete schema rejection, atomic restore behavior, and preservation of existing data after failed restore.

### Phase 10: Offline/no-network verification

Build a release gate equivalent to SchoolMAP’s offline verifier. SchoolMAP scans source and built output for runtime network APIs, external assets, dynamic imports, workers, beacons, WebSockets, EventSource, hosted URLs, and missing inlined assets.

For the iOS app, implement:

- unit test that grading engine has no URLSession dependency,
- runtime test with network link conditioner / airplane mode,
- test that scan → OCR → review → grade → save → export works without network,
- dependency audit for analytics/cloud SDKs,
- build script that fails if known networking frameworks are used outside explicitly allowed import/export UI.

---

## 7. MVP scope I recommend

The MVP should be:

**Text-only, OCR-reviewed, rubric-assisted grading for short-answer and paragraph/essay responses, fully local on compatible Apple devices.**

### MVP included

- Teacher profile.
- Class roster.
- Assignment setup.
- Rubric builder.
- Paste text.
- Scan page.
- OCR extraction.
- OCR correction.
- Structured grading draft.
- Teacher approval.
- PDF export.
- CSV export.
- Local backup.

### MVP excluded

- Posters.
- Physical models.
- Math notation grading.
- Multi-student batch photo splitting.
- LMS sync.
- Cloud drive sync.
- Parent portal.
- Cross-device account sync.
- Remote AI fallback.

---

## 8. Suggested repo structure

```text
GradeDraft/
├── GradeDraftApp/
│   ├── App/
│   ├── Models/
│   │   ├── TeacherProfile.swift
│   │   ├── Student.swift
│   │   ├── ClassGroup.swift
│   │   ├── Assignment.swift
│   │   ├── Rubric.swift
│   │   ├── Submission.swift
│   │   ├── GradingDraft.swift
│   │   └── ExportRecord.swift
│   ├── Persistence/
│   │   ├── Database.swift
│   │   ├── Migrations.swift
│   │   ├── BackupManifest.swift
│   │   └── RestorePreflight.swift
│   ├── OCR/
│   │   ├── DocumentScanner.swift
│   │   ├── OCRService.swift
│   │   ├── OCRReviewModel.swift
│   │   └── OCRConfidence.swift
│   ├── Grading/
│   │   ├── EvidencePacketBuilder.swift
│   │   ├── LocalModelAvailability.swift
│   │   ├── RubricGradingService.swift
│   │   ├── StructuredGradingOutput.swift
│   │   ├── GradingValidator.swift
│   │   └── ScoreCalculator.swift
│   ├── Export/
│   │   ├── PDFExportService.swift
│   │   ├── CSVExportService.swift
│   │   └── SpreadsheetSafety.swift
│   ├── UI/
│   │   ├── Dashboard/
│   │   ├── Roster/
│   │   ├── Assignments/
│   │   ├── Rubrics/
│   │   ├── ScanReview/
│   │   ├── GradingReview/
│   │   └── Settings/
│   └── Tests/
├── docs/
│   ├── CORE_RULES.md
│   ├── PRODUCT_SPEC.md
│   ├── DATA_MODEL.md
│   ├── PRIVACY_BOUNDARY.md
│   ├── VALIDATION_PLAN.md
│   └── RELEASE_CHECKLIST.md
└── README.md
```

---

## 9. Build order

### Sprint 1: Local skeleton

Deliver:

- SwiftUI shell.
- Local database.
- Teacher profile.
- Student roster CRUD.
- Assignment CRUD.
- Basic rubric CRUD.

Acceptance criteria:

- App launches offline.
- Roster persists after force quit.
- Assignment persists after force quit.
- Failed persistence shows visible error.
- No networking code in core path.

### Sprint 2: Text input and rubric grading without OCR

Deliver:

- Paste student response.
- Build evidence packet.
- Call local model.
- Validate structured output.
- Show proposed grade.
- Teacher edits and approves.

Acceptance criteria:

- No grading without rubric.
- No grading without student text.
- Criterion scores must match rubric.
- Total is calculated by app.
- Teacher approval locks result.

### Sprint 3: OCR

Deliver:

- Scan paper with camera.
- OCR page.
- Show extracted text.
- Teacher correction screen.
- OCR confidence warnings.
- Grade only after review.

Acceptance criteria:

- Low-confidence OCR blocks grade until reviewed.
- Raw OCR and corrected text remain separately stored.
- Regeneration after text edit marks prior grade stale.

### Sprint 4: Export

Deliver:

- Student PDF.
- Teacher audit PDF.
- CSV gradebook.
- Local backup.

Acceptance criteria:

- No private notes in student export.
- CSV formula-injection hardening.
- Backup restore preflight.
- Invalid backup does not mutate existing data.

### Sprint 5: Release hardening

Deliver:

- No-network test.
- Model-unavailable UI.
- Privacy disclosures.
- Backup warnings.
- Full regression suite.

Acceptance criteria:

- Scan/paste → grade → approve → export works offline.
- App does not claim Apple AI is available when it is not.
- No success toast appears unless local save completed.
- Current release validation status is recorded.

---

## 10. The most important product rule

The new app should inherit the strongest rule from both repos:

**Do not fake readiness.**

Commenterv3 blocks generation when data is unavailable, validates required results before generating, checks placeholders, treats locked reports carefully, and surfaces save failures.

SchoolMAP likewise says failed persistence must be visible and must not be reported as success.

For this grading app, that means:

- No OCR confidence, no silent grading.
- No rubric, no grade.
- No reviewed text, no grade.
- No local model, no AI grade.
- No successful local save, no success message.
- No teacher approval, no final grade.
- No evidence for a score, no confident recommendation.

That is the architecture that makes the app usable in a real classroom rather than just impressive in a demo.

