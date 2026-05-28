# GradeDraft Grading Content Source of Truth

**Status:** Canonical product/content specification for implementation agents  
**Audience:** Codex, product, design, Swift implementation, QA, legal/compliance review  
**Scope:** Local-first iOS/iPadOS teacher-controlled rubric-assisted grading assistant  
**Rule:** Coding agents must implement from this file rather than inventing educational, rubric, grading, report, warning, or privacy copy.

---

## 0. Why this file exists

The repository contains enough source material to make the product/content decisions now. This file turns that source material into implementation-ready content so that Codex does not have to perform the educational-design analysis later.

Codex may use this file to create Swift models, seed data, UI string resources, fixture JSON, report templates, validation tests, and export copy. Codex must not treat this file as an invitation to expand product scope. If the app cannot truthfully implement a feature described here, the UI must hide it, disable it, or label it as unavailable rather than pretending it works.

This file is the human-authored answer to the questions Codex should not answer on its own:

- What should the app be called and how should it describe itself?
- What grading posture is pedagogically defensible?
- What rubrics and rubric fields should exist?
- What custom instruction, answer-key, and exemplar structures should the app support?
- What should the grading packet contain?
- What may the local model produce?
- What must the local model never infer?
- How should uncertainty, OCR problems, ambiguous rubrics, weak evidence, and unsupported inputs be handled?
- What should the student report and teacher audit report say?
- What warnings should appear before export, sharing, backup, deletion, clipboard copy, and teacher-note inclusion?
- What copy should be shown in empty states, blocked states, stale states, and local-AI unavailable states?
- How should Australian Curriculum references be represented without falsely claiming official grading or official ingestion?

---

## 1. Canonical product identity

### 1.1 Working name

Use **GradeDraft** as the current app name.

Rationale: the name communicates that the app produces draft grading support, not final autonomous grading.

### 1.2 One-sentence product promise

**GradeDraft helps teachers draft rubric-linked feedback from teacher-confirmed student work while keeping the final grading judgement in the teacher's hands.**

### 1.3 Short app description

Use this where a compact product description is needed:

> Draft rubric-based feedback from teacher-confirmed student work. Scan or paste a response, review the text, apply your rubric, and receive evidence-linked score suggestions for your final judgement.

### 1.4 Longer product description

Use this for onboarding, website copy, and App Store long description drafts:

> GradeDraft is a local-first iPhone and iPad grading workspace for teachers. It helps you review student text, apply a rubric or answer key, draft criterion-by-criterion score suggestions, cite student evidence, flag uncertainty, and prepare feedback. The app is designed for teacher review and final approval. It is not an autonomous grader.

### 1.5 Local-first privacy position

Use this exact meaning whenever local-first privacy is described:

> In the core workflow, student work, OCR text, rubrics, grading drafts, teacher notes, final grades, and feedback reports are processed and stored locally on the teacher's device. GradeDraft does not upload student work for cloud OCR, cloud AI grading, analytics, advertising, or model training.

Do not say: "we do not handle student data." The app does handle student data locally.

### 1.6 Core lane

The canonical product lane is:

```text
scan/import/paste student work
-> local text extraction where applicable
-> explicit teacher review of extracted text
-> grading packet from reviewed text, rubric, instructions, answer key, and exemplar
-> local draft criterion suggestions when available
-> teacher final review and edits
-> local export under teacher control
```

### 1.7 Product posture

GradeDraft is:

- a teacher-controlled grading assistant;
- a rubric-assisted feedback drafting tool;
- an evidence-linking and review workspace;
- a local-first Apple-native app;
- a draft-generation tool that requires teacher final judgement.

GradeDraft is not:

- an autonomous grader;
- a replacement for teacher judgement;
- a final grade authority;
- a cloud grading service;
- a behavioral, disability, demographic, or effort inference tool;
- a reliable handwriting, diagram, poster, model, or math-working grader in the MVP.

---

## 2. Non-negotiable product rules

These rules govern all implementation. If a planned UI, service, export, or prompt conflicts with one of these rules, the stricter rule wins.

1. The default grading workflow must not require a server.
2. The default workflow must not upload student work.
3. The default workflow must not use cloud OCR.
4. The default workflow must not use cloud AI grading.
5. The app must not generate a proposed grade without at least one teacher-provided grading standard: rubric, answer key, exemplar, achievement-standard aspect, or custom grading criteria.
6. The app must not grade OCR-derived text until required OCR review has been completed.
7. Every proposed criterion score must cite student evidence or be marked for teacher review.
8. The AI proposes; the teacher finalizes.
9. Proposed points and teacher-final points must remain separate.
10. Totals must be calculated deterministically in app code, not trusted from model output.
11. Raw source input, OCR output, reviewed text, model proposal, teacher edits, final grade, exports, and audit events must remain separate records.
12. A draft or final review must become stale when its source grading packet changes.
13. Student-facing exports must exclude private teacher notes by default.
14. Teacher-audit exports are sensitive student records.
15. The UI must not imply that unavailable OCR, local AI, export, or grading functionality is working.
16. The app must fail openly on OCR failure, local AI unavailability, malformed model output, persistence failure, or export failure.
17. Handwriting, diagrams, posters, physical models, and visual artifacts require explicit teacher-confirmed evidence before grading.
18. Subjective criteria such as creativity, craftsmanship, effort, or presentation quality require teacher review and must not be presented as fully automated judgements.
19. The app must not infer student effort, intent, motivation, behavior, disability, EAL/D status, giftedness, demographic traits, support level, or ability beyond the submitted work.
20. The app must not claim official curriculum scoring, official standards certification, or jurisdiction reporting compliance unless those features are separately implemented and reviewed.

---

## 3. Safe claims and prohibited claims

### 3.1 Safe claims if implemented

The app may make these claims only to the extent the actual implementation supports them:

- "Drafts rubric-based grading suggestions for teacher review."
- "Keeps teacher-approved final scores separate from AI suggestions."
- "Cites student evidence for each criterion suggestion."
- "Flags weak evidence, OCR uncertainty, and ambiguous criteria for teacher review."
- "Processes the core grading workflow locally on compatible devices."
- "Uses on-device text extraction for supported scans and images."
- "Requires teacher review before finalizing grades."
- "Exports student-facing and teacher-audit reports separately."
- "Excludes private teacher notes from student-facing reports by default."
- "Supports teacher-created rubrics, answer keys, exemplars, and custom instructions."
- "Can store references to curriculum content entered or imported by the teacher."

### 3.2 Claims to avoid

Do not use these claims in UI, README, marketing, onboarding, App Store copy, or generated reports:

- "Auto-grade."
- "Automatically grades student work."
- "Replaces teacher grading."
- "Guaranteed accurate grading."
- "Bias-free grading."
- "Understands all student work."
- "Reliably grades handwriting."
- "Reliably grades diagrams."
- "Reliably grades posters or physical models."
- "Understands math work."
- "Certifies achievement against official standards."
- "Works for every school reporting requirement."
- "Always works offline on first launch."
- "Works on all iPhones and iPads."
- "No student data is handled."
- "Secure enough for any student record."
- "Unhackable."

### 3.3 Preferred wording replacements

| Avoid | Use instead |
|---|---|
| Auto-grade | Draft feedback suggestion |
| Accept AI grade | Save teacher-final feedback |
| AI final grade | Draft score suggestion |
| AI decided | Suggested for teacher review |
| OCR complete | Extracted text needs review / OCR reviewed |
| Evidence found | Evidence cited from reviewed text |
| Private by default | Stored locally in the core workflow |
| Secure export | Export may contain sensitive student information |
| Official standard grade | Teacher judgement against selected rubric/standard |

---

## 4. MVP assignment modes and scope

### 4.1 MVP modes

The MVP should support text-based student work only.

#### Mode A: Short answer

Best for constructed responses, exit tickets, reading checks, quick science/HASS explanations, and discrete answer-key grading.

Required inputs:

- prompt or assignment title;
- reviewed student text;
- rubric, answer key, or expected elements;
- optional teacher instructions.

Outputs:

- proposed criterion scores;
- evidence quotes;
- explanation;
- uncertainty flags;
- student-facing feedback;
- teacher-private notes.

#### Mode B: Paragraph response

Best for one-paragraph claim/evidence/reasoning responses.

Required inputs:

- prompt or assignment title;
- reviewed student text;
- analytic rubric;
- optional exemplar.

Outputs:

- claim/topic sentence feedback;
- evidence feedback;
- reasoning/explanation feedback;
- organization/clarity feedback;
- next step.

#### Mode C: Essay

Best for text essays where the teacher supplies an analytic rubric.

Required inputs:

- prompt or assignment title;
- reviewed student text;
- analytic rubric;
- optional exemplar;
- optional answer key or expected content list.

Outputs:

- criterion-by-criterion suggestions;
- evidence quotes;
- student-facing feedback;
- uncertainty flags for missing evidence, rubric ambiguity, or off-prompt content.

#### Mode D: Lab write-up or science explanation

Best for written lab conclusions, short explanations, claim/evidence/reasoning, and reflection on data already represented in text.

Required inputs:

- prompt or lab question;
- reviewed student text;
- rubric or expected scientific concepts;
- optional answer key.

Outputs:

- concept-understanding feedback;
- evidence/data use feedback;
- reasoning feedback;
- scientific vocabulary feedback;
- flags for missing data, diagram dependence, or unsupported inference.

#### Mode E: Reading comprehension

Best for text responses to a reading prompt.

Required inputs:

- question/prompt;
- reviewed student response;
- answer key, rubric, or expected elements.

Outputs:

- direct-answer score;
- textual evidence score;
- explanation/inference score;
- clarity feedback;
- flags for unsupported claims or missing references.

### 4.2 Explicitly deferred modes

The following must remain deferred unless and until specific teacher-confirmed evidence workflows are implemented:

| Mode | Product posture |
|---|---|
| Handwriting | Assistive OCR only; teacher confirmation required before grading. |
| Math working | Manual transcription or teacher-confirmed text only; no structural math grading. |
| Diagrams and labels | Teacher-tagged regions required; no inferred spatial relationships. |
| Posters and tri-fold boards | Evidence organization and teacher feedback support only; no autonomous visual grading. |
| Physical models | Teacher observations and teacher-tagged evidence required; no autonomous judgement. |
| Concept maps | Teacher-confirmed relationships required. |
| Art/performance/products | Teacher judgement required for craftsmanship, creativity, and performance quality. |
| Languages writing | Requires language-specific support and teacher expertise; do not include as MVP automated scoring. |
| Senior secondary high-stakes assessment | Requires jurisdiction-specific research and heightened caution. |
| LMS sync / grade passback | Later integration; not part of local-first MVP. |
| Cloud backup/sync | Later optional feature only after separate privacy review. |

### 4.3 Subject suitability

| Subject or learning area | MVP suitability | Notes |
|---|---:|---|
| English writing and reading responses | Very high | Text responses and analytic rubrics fit the MVP. |
| HASS short-answer and inquiry responses | High | Source analysis and reasoning can be rubric-scored from text. |
| Science written explanations and lab reflections | Medium-high | Written reasoning works; diagrams and raw data tables require review. |
| Mathematics explanations | Medium | Textual explanation can be assessed; notation and working are deferred. |
| Technologies reflections | Medium | Written design reflections work; code/design artifacts require later modes. |
| Health and Physical Education reflections | Medium | Written responses work; sensitive content needs caution. |
| The Arts artist statements/reflections | Low-medium | Written reflection works; artwork/performance assessment is deferred. |
| Languages | Low-medium | Requires language-specific rubric and teacher expertise. |

---

## 5. Canonical data objects and field definitions

This section defines the content objects Codex should translate into Swift models, fixtures, validation, UI copy, or persistence tables as appropriate. Current Swift models may already contain some of these fields. Missing fields should be treated as planned content/schema requirements, not as proof the UI is implemented.

### 5.1 TeacherProfile

Purpose: store teacher-local preferences without requiring a cloud account.

| Field | Type | Required | Notes |
|---|---|---:|---|
| `id` | UUID/String | Yes | Local identifier only. |
| `displayName` | String | No | Optional; avoid requiring teacher PII. |
| `preferredLanguage` | String | No | Default `en-US`; optional `en-AU` market mode. |
| `defaultSpelling` | Enum | No | `US English`, `Australian English`, or teacher selected. |
| `exportAuthenticationRequired` | Bool | Yes | Default true where supported. |
| `studentNamesOptional` | Bool | Yes | Default true. |
| `localOnlyReminderDismissedAt` | Date | No | Local UI state only. |

### 5.2 SchoolContext

Purpose: capture optional school/district/jurisdiction context without implying official compliance.

| Field | Type | Required | Notes |
|---|---|---:|---|
| `schoolName` | String | No | Optional. |
| `jurisdiction` | String | No | State, territory, district, or local school setting. |
| `sector` | String | No | Optional; e.g., government, independent, Catholic. |
| `schoolYear` | String | No | Local label. |
| `term` | String | No | Local label. |
| `reportingCaveat` | String | No | Default: "Your school or jurisdiction may have additional reporting requirements." |

### 5.3 ClassGroup

Purpose: group assignments and students locally.

| Field | Type | Required | Notes |
|---|---|---:|---|
| `id` | UUID | Yes | Stable local ID. |
| `name` | String | Yes | Example: `Period 2 English`. |
| `schoolYear` | String | No | Optional. |
| `term` | String | No | Optional. |
| `subject` | String | No | Optional default for assignments. |
| `gradeLevel` | String | No | Optional default for assignments. |
| `isArchived` | Bool | Yes | Default false. |

### 5.4 Student

Purpose: local student reference without requiring full identity.

| Field | Type | Required | Notes |
|---|---|---:|---|
| `id` | UUID | Yes | Stable local ID. |
| `displayName` | String | No | Teacher may use name, initials, or pseudonym. |
| `localIdentifier` | String | No | Teacher or school-local identifier. |
| `classGroupID` | UUID | No | Optional relation. |
| `isActive` | Bool | Yes | Default true. |
| `privateTeacherNotes` | String | No | Must never appear in student-facing exports by default. |

### 5.5 Assignment

Purpose: central unit of grading work.

| Field | Type | Required | Student-facing? | Notes |
|---|---|---:|---:|---|
| `id` | UUID | Yes | No | Stable local ID. |
| `title` | String | Yes | Yes | Assignment title. |
| `prompt` | String | No | Optional | Useful in grading packet and reports. |
| `subject` | String | No | Optional | Subject label. |
| `gradeLevel` | String | No | Optional | Year/grade label. |
| `className` | String | No | Optional | Avoid requiring if teacher wants pseudonyms. |
| `studentDisplayName` | String | No | Optional | May be pseudonym. |
| `assignmentType` | Enum | Yes | Optional | Short answer, essay, paragraph, lab write-up, reading comprehension. |
| `assessmentPurpose` | Enum | Yes | Optional | `formative`, `summative`, `practice`, `diagnostic`, `other`. |
| `rubricText` | String | Conditional | No by default | Required unless answer key/exemplar/standard criteria provide grading standard. |
| `customInstructions` | String | No | No | Teacher-provided grading instructions. |
| `answerKeyText` | String | No | No by default | Used for grading packet. |
| `exemplarText` | String | No | No by default | Used as reference only. |
| `reviewedStudentText` | String | Conditional | Yes | Only text eligible for grading. |
| `ocrReviewStatus` | Enum | Yes | Optional | Blocks grading when review required. |
| `gradingPacketFingerprint` | String | Yes | No | Staleness and audit only. |
| `createdAt` | Date | Yes | No | Local audit. |
| `updatedAt` | Date | Yes | No | Local audit. |

### 5.6 CurriculumReference

Purpose: represent teacher-provided or imported curriculum references without allowing the model to invent official alignment.

| Field | Type | Required | Notes |
|---|---|---:|---|
| `source` | String | No | Example: `Australian Curriculum`, `District standard`, `Teacher-created`. |
| `version` | String | No | Example: `Australian Curriculum Version 9.0`. |
| `learningArea` | String | No | Example: `English`, `Science`, `HASS`. |
| `subject` | String | No | Optional. |
| `yearLevel` | String | No | Example: `Year 6`, `Grade 5`. |
| `contentDescriptions` | Array | No | Teacher-entered or imported. |
| `achievementStandardAspects` | Array | No | Teacher-entered or imported. |
| `generalCapabilities` | Array | No | Optional tags only when explicitly relevant. |
| `crossCurriculumPriorities` | Array | No | Optional tags only when explicitly relevant. |
| `sourceURLOrURI` | String | No | For imported official content. |
| `officialImportVerified` | Bool | Yes | Default false unless actual import implemented. |

Implementation rule: if the app does not implement official import, label these fields as teacher-entered references.

### 5.7 Rubric

Purpose: teacher-editable scoring framework.

| Field | Type | Required | Notes |
|---|---|---:|---|
| `id` | String/UUID | Yes | Stable local ID. |
| `name` | String | Yes | Template or teacher-created. |
| `assignmentType` | Enum | Yes | Used for filtering templates. |
| `description` | String | No | Teacher-facing summary. |
| `source` | Enum | Yes | `builtIn`, `teacherCreated`, `imported`, `curriculumDerived`. |
| `rubricText` | String | Yes | Human-readable rubric. |
| `criteria` | Array<RubricCriterion> | Yes | Structured form after parsing/editing. |
| `totalMaxPoints` | Double | Yes | Deterministic sum. |
| `version` | Int/String | Yes | Used for audit and staleness. |
| `createdAt` | Date | Yes | Local audit. |
| `updatedAt` | Date | Yes | Local audit. |

### 5.8 RubricCriterion

Purpose: criterion-level scoring target.

| Field | Type | Required | Notes |
|---|---|---:|---|
| `criterionID` | String | Yes | Stable, deterministic where possible. |
| `title` | String | Yes | Example: `Evidence / support`. |
| `description` | String | Yes | Criterion descriptor. |
| `maxPoints` | Double | Yes | Non-negative. |
| `levels` | Array<RubricLevel> | Recommended | Point bands. |
| `requiredEvidenceCount` | Int | Recommended | Default 1 for scored criteria. |
| `evidenceRequired` | Bool | Yes | Default true. |
| `studentFacingLabel` | String | No | Optional shorter label. |
| `teacherReviewRequiredByDefault` | Bool | Yes | True for subjective or ambiguous criteria. |
| `sortOrder` | Int | Yes | Display order. |

### 5.9 RubricLevel

Purpose: rubric score band.

| Field | Type | Required | Notes |
|---|---|---:|---|
| `levelID` | String | Yes | Stable within criterion. |
| `label` | String | Yes | Example: `Strong`, `Proficient`, `Developing`, `Missing`. |
| `points` | Double | Yes | Exact point value or top of band. |
| `minPoints` | Double | No | For bands. |
| `maxPoints` | Double | No | For bands. |
| `descriptor` | String | Yes | Observable performance descriptor. |
| `requiresTeacherReview` | Bool | Yes | True for subjective or evidence-light levels. |

### 5.10 TeacherInstruction

Purpose: teacher-authored constraints and preferences for grading.

| Field | Type | Required | Notes |
|---|---|---:|---|
| `id` | UUID | Yes | Stable local ID. |
| `text` | String | Yes | Exact teacher instruction. |
| `scope` | Enum | Yes | `assignment`, `rubric`, `criterion`, `feedback`, `student`, `export`. |
| `priority` | Enum | Yes | `normal`, `high`, `override`. |
| `studentFacing` | Bool | Yes | Default false. |
| `privateTeacherOnly` | Bool | Yes | Default true. |
| `conflictStatus` | Enum | Yes | `none`, `possibleConflict`, `conflictRequiresReview`. |

### 5.11 AnswerKey

Purpose: expected answer elements for short answer, reading comprehension, science, HASS, and explanation modes.

| Field | Type | Required | Notes |
|---|---|---:|---|
| `id` | UUID | Yes | Stable local ID. |
| `prompt` | String | No | Optional original question. |
| `exactAnswer` | String | No | Exact answer where applicable. |
| `acceptableAnswers` | Array<String> | No | Equivalent correct answers. |
| `requiredElements` | Array<ExpectedElement> | No | Concepts/facts that must appear. |
| `partialCreditRules` | Array<PartialCreditRule> | No | Teacher-defined. |
| `commonMisconceptions` | Array<String> | No | Used for feedback and flags. |
| `doNotPenalize` | Array<String> | No | Example: spelling unless meaning unclear. |
| `teacherNotes` | String | No | Private by default. |

### 5.12 ExpectedElement

| Field | Type | Required | Notes |
|---|---|---:|---|
| `elementID` | String | Yes | Stable local ID. |
| `description` | String | Yes | Expected concept, fact, or feature. |
| `required` | Bool | Yes | Default true. |
| `pointValue` | Double | No | Optional. |
| `acceptableWording` | Array<String> | No | Alternative phrasings. |
| `evidenceRequired` | Bool | Yes | Default true. |

### 5.13 Exemplar

Purpose: teacher-selected model response or work sample reference.

| Field | Type | Required | Notes |
|---|---|---:|---|
| `id` | UUID | Yes | Stable local ID. |
| `title` | String | Yes | Local label. |
| `text` | String | Conditional | Required for text exemplar. |
| `source` | String | No | Teacher-created, district-provided, public reference, etc. |
| `qualityLevel` | String | No | Example: high, proficient, developing. |
| `useForScoring` | Bool | Yes | If false, use only for teacher reference. |
| `teacherNotes` | String | No | Private. |

Implementation rule: the model may compare to an exemplar only when the teacher has supplied it. The model must not invent an exemplar.

### 5.14 SourceInput

Purpose: preserve where student work came from.

| Field | Type | Required | Notes |
|---|---|---:|---|
| `id` | UUID | Yes | Stable local ID. |
| `sourceType` | Enum | Yes | `pastedText`, `scan`, `photo`, `pdf`, `handwrittenWork`, `visualArtifact`. |
| `pageIndex` | Int | No | For multi-page inputs. |
| `localRelativePath` | String | No | Local app storage path. |
| `contentDigest` | String | No | App-state fingerprint. |
| `digestAlgorithm` | String | No | Example: `fnv1a64` in scaffold, cryptographic hash in production. |
| `imageWidth` | Double | No | For image sources. |
| `imageHeight` | Double | No | For image sources. |
| `teacherIncludedInExport` | Bool | Yes | Default false. |
| `createdAt` | Date | Yes | Local audit. |

### 5.15 OCRDocument

Purpose: preserve OCR output separately from reviewed text.

| Field | Type | Required | Notes |
|---|---|---:|---|
| `id` | UUID | Yes | Stable local ID. |
| `engine` | String | Yes | Example: `Apple Vision`. |
| `engineVersion` | String | Yes | App/system version if available. |
| `recognitionLevel` | String | No | Accurate/fast or platform equivalent. |
| `languageHints` | Array<String> | No | If supplied. |
| `pages` | Array<OCRPage> | Yes | OCR pages. |
| `createdAt` | Date | Yes | Local audit. |
| `reviewStatus` | Enum | Yes | See OCR states. |
| `reviewedAt` | Date | No | When teacher confirmed. |
| `qualitySummary` | Object | Yes | Counts and confidence. |

### 5.16 OCRLine

| Field | Type | Required | Notes |
|---|---|---:|---|
| `id` | UUID | Yes | Stable local ID. |
| `rawText` | String | Yes | Raw OCR result. |
| `correctedText` | String | No | Teacher correction. |
| `confidence` | Float | Yes | Heuristic, not probability. |
| `boundingBox` | NormalizedRect | Yes | Source location. |
| `topCandidates` | Array<String> | No | If available. |
| `detectedLanguage` | String | No | If available. |
| `teacherConfirmed` | Bool | Yes | Must be true for grading when review required. |
| `reviewState` | Enum | Yes | `autoAccepted`, `needsReview`, `teacherCorrected`, `teacherConfirmed`, `rejected`, `blockedFromGrading`. |

### 5.17 EvidenceReference

Purpose: connect a score or comment to confirmed student evidence.

| Field | Type | Required | Notes |
|---|---|---:|---|
| `evidenceID` | UUID/String | Yes | Stable local ID. |
| `criterionID` | String | Yes | Criterion supported. |
| `quote` | String | Yes | Exact reviewed text where possible. |
| `quoteType` | Enum | Yes | `verbatim`, `teacherConfirmedParaphrase`, `missingEvidenceMarker`. |
| `reviewedTextStart` | Int | No | Character offset. |
| `reviewedTextEnd` | Int | No | Character offset. |
| `sourceInputID` | UUID | No | Source page/file. |
| `ocrLineID` | UUID | No | OCR line. |
| `ocrSpanID` | UUID | No | Future span-level reference. |
| `pageIndex` | Int | No | Source page. |
| `boundingBox` | NormalizedRect | No | Source location. |
| `teacherConfirmed` | Bool | Yes | Required for uncertain OCR. |
| `createdAt` | Date | Yes | Local audit. |

Implementation rule: if bounding boxes or offsets are not implemented, do not claim source-linked evidence. Use reviewed-text quotes only and mark source refs as unavailable.

### 5.18 GradingPacket

Purpose: exact input sent to the model or local grading service.

A grading packet must be explicit and fingerprinted. Any field that can affect grading output must affect packet staleness.

Required packet fields:

```json
{
  "gradingPacket": {
    "packetVersion": "1.0",
    "assignment": {
      "assignmentID": "uuid",
      "title": "string",
      "prompt": "string",
      "subject": "string",
      "gradeLevel": "string",
      "className": "string",
      "studentDisplayName": "string-or-local-identifier",
      "assignmentType": "shortAnswer | essay | paragraphResponse | labWriteup | readingComprehension",
      "assessmentPurpose": "formative | summative | practice | diagnostic | other"
    },
    "curriculumReference": {
      "source": "teacher-entered-or-imported",
      "version": "string",
      "learningArea": "string",
      "subject": "string",
      "yearLevel": "string",
      "contentDescriptions": [],
      "achievementStandardAspects": [],
      "generalCapabilities": [],
      "crossCurriculumPriorities": [],
      "officialImportVerified": false
    },
    "rubric": {
      "rubricText": "string",
      "criteria": []
    },
    "teacherInstructions": [],
    "answerKey": {
      "text": "string",
      "requiredElements": [],
      "commonMisconceptions": []
    },
    "exemplar": {
      "text": "string",
      "qualityLevel": "string"
    },
    "studentEvidence": {
      "reviewedText": "teacher-confirmed text only",
      "ocrReviewStatus": "notNeeded | needsReview | reviewed | blocked",
      "ocrWarnings": [],
      "sourceRefs": []
    },
    "outputRules": {
      "citeEvidenceForEveryCriterion": true,
      "teacherFinalReviewRequired": true,
      "doNotInferStudentTraits": true,
      "calculateTotalsInApp": true,
      "markWeakEvidenceForTeacherReview": true,
      "doNotInventCurriculumReferences": true,
      "doNotInventAnswerKeyContent": true
    }
  }
}
```

### 5.19 GradeProposal

Purpose: model output before teacher edits.

Required schema:

```json
{
  "studentResponseSummary": "one or two factual sentences about what the student wrote",
  "criteria": [
    {
      "criterionId": "criterion id from structured rubric when available",
      "criterion": "criterion name from rubric",
      "rating": "rubric level or concise label",
      "proposedPoints": 0,
      "maxPoints": 0,
      "evidence": ["verbatim quote from reviewed student text, or No supporting evidence found."],
      "evidenceSourceRefs": [],
      "explanation": "specific rubric-based explanation",
      "nextStep": "specific improvement suggestion when appropriate",
      "confidence": "high | medium | low",
      "teacherReviewRequired": true,
      "uncertaintyFlags": []
    }
  ],
  "studentFeedback": "student-facing feedback that is specific, constructive, and concise",
  "teacherNotes": "private notes about ambiguity, grading calls, OCR concerns, or missing evidence",
  "uncertaintyFlags": [],
  "complianceFlags": []
}
```

Model output must not include trusted `totalScore` or `maxScore`. App code calculates totals.

### 5.20 TeacherReview and FinalGradeReview

Purpose: teacher-final record separate from model proposal.

| Field | Type | Required | Notes |
|---|---|---:|---|
| `id` | UUID | Yes | Stable local ID. |
| `createdAt` | Date | Yes | Local audit. |
| `finalizedAt` | Date | No | Set only when approved. |
| `packetFingerprint` | String | Yes | Used for staleness. |
| `status` | Enum | Yes | `inProgress`, `approved`, `stale`. |
| `criteria` | Array<FinalCriterionScore> | Yes | Teacher-final points. |
| `totalScore` | Double | Yes | Deterministic sum of final points. |
| `maxScore` | Double | Yes | Deterministic sum. |
| `studentFeedback` | String | Yes | Teacher-final student-facing feedback. |
| `privateTeacherNotes` | String | No | Excluded from student report by default. |
| `teacherEdited` | Bool | Yes | Whether teacher modified draft. |

### 5.21 FinalCriterionScore

| Field | Type | Required | Notes |
|---|---|---:|---|
| `criterionID` | String | No | Link to rubric criterion when available. |
| `criterion` | String | Yes | Criterion label. |
| `rating` | String | No | Teacher-final or draft rating label. |
| `proposedPoints` | Double | Yes | Preserved model suggestion. |
| `finalPoints` | Double | Yes | Teacher-final score. |
| `maxPoints` | Double | Yes | Non-negative. |
| `evidence` | Array<String> | Yes | Evidence used for final judgement. |
| `explanation` | String | Yes | Rubric-based explanation. |
| `teacherApproved` | Bool | Yes | Must be true before final approval. |
| `teacherRationale` | String | No | Private unless teacher chooses otherwise. |

### 5.22 ExportRecord

| Field | Type | Required | Notes |
|---|---|---:|---|
| `id` | UUID | Yes | Stable local ID. |
| `exportKind` | Enum | Yes | Student report, teacher audit, CSV, JSON backup, ZIP archive. |
| `createdAt` | Date | Yes | Local audit. |
| `contentFingerprint` | String | Yes | Fingerprint of exported content. |
| `includesPrivateTeacherNotes` | Bool | Yes | Must be false for student report by default. |
| `includesOriginalSources` | Bool | Yes | Whether scans/photos included. |
| `warningShown` | Bool | Yes | Export warning gate. |
| `previewConfirmed` | Bool | Recommended | Student-facing reports should require preview confirmation. |
| `destinationKind` | Enum | No | Share sheet, Files, clipboard, local temporary, etc. |

### 5.23 AuditEvent

Purpose: local record of grading-state transitions.

Canonical event types:

- `assignmentCreated`
- `sourceCaptured`
- `sourceImported`
- `sourceCleared`
- `ocrStarted`
- `ocrCompleted`
- `ocrFailed`
- `ocrReviewed`
- `ocrCorrected`
- `inputChanged`
- `rubricChanged`
- `answerKeyChanged`
- `exemplarChanged`
- `draftRequested`
- `draftGenerated`
- `draftRejected`
- `draftMarkedStale`
- `finalReviewStarted`
- `finalEdited`
- `finalApproved`
- `finalMarkedStale`
- `exportPreviewed`
- `exportPrepared`
- `exportShared`
- `persistenceSaved`
- `persistenceFailed`

Audit events should not be represented as legal certification. They are local accountability records.

---

## 6. Built-in rubric templates

All built-in templates must be editable. They are starting points, not official standards. The app must allow teachers to revise criteria, point values, and instructions before grading.

### 6.1 Template: 4-point short answer

**ID:** `short-answer-4pt`  
**Assignment type:** `shortAnswer`  
**Description:** Fast rubric for constructed responses and exit tickets.

Rubric text:

```text
Claim / direct answer: 0-1 point
- 1: directly answers the question or makes a clear claim.
- 0: does not answer the question or is off topic.

Evidence / support: 0-2 points
- 2: includes accurate, relevant evidence or details.
- 1: includes partial, vague, or minimally relevant evidence.
- 0: includes no relevant evidence.

Explanation: 0-1 point
- 1: explains how the evidence supports the answer.
- 0: gives evidence without explanation or has no explanation.
```

Default custom instructions:

```text
Do not penalize spelling, grammar, or handwriting unless they materially interfere with meaning. Award equivalent wording when the meaning is correct. Cite the reviewed student text for each criterion or mark teacher review required.
```

### 6.2 Template: 8-point paragraph response

**ID:** `paragraph-response-8pt`  
**Assignment type:** `paragraphResponse`  
**Description:** Claim, evidence, reasoning, and clarity for one-paragraph responses.

Rubric text:

```text
Clear claim/topic sentence: 0-2 points
- 2: clear, focused claim that answers the prompt.
- 1: claim is present but vague, incomplete, or only partly responsive.
- 0: no clear claim.

Relevant evidence: 0-2 points
- 2: at least two accurate and relevant details, examples, or quotations.
- 1: one relevant detail or partially relevant evidence.
- 0: no relevant evidence.

Reasoning/explanation: 0-2 points
- 2: clearly explains how the evidence supports the claim.
- 1: explanation is present but underdeveloped.
- 0: no reasoning or explanation.

Organization and clarity: 0-2 points
- 2: coherent, complete paragraph with logical flow.
- 1: understandable but choppy, repetitive, or incomplete.
- 0: difficult to follow or not written as a response.
```

Default custom instructions:

```text
Keep feedback specific and actionable. Do not invent missing evidence. If OCR quality is uncertain, flag teacher review. Do not make claims about student effort, ability, or intent.
```

### 6.3 Template: 20-point essay

**ID:** `essay-20pt`  
**Assignment type:** `essay`  
**Description:** General essay rubric for claim, structure, evidence, analysis, and conventions.

Rubric text:

```text
Thesis/claim: 0-4 points
- 4: clear, precise, and responsive thesis or controlling claim.
- 3: clear claim with minor limitation or lack of precision.
- 2: partially responsive, vague, or inconsistent claim.
- 1: minimal or unclear claim.
- 0: no discernible claim or off-topic response.

Evidence: 0-4 points
- 4: accurate, relevant, and sufficient evidence throughout.
- 3: mostly relevant evidence with minor gaps.
- 2: some relevant evidence but insufficient, vague, or uneven.
- 1: minimal evidence.
- 0: no relevant evidence.

Analysis/reasoning: 0-4 points
- 4: consistently explains how evidence supports the claim.
- 3: generally explains evidence with minor gaps.
- 2: some explanation, but reasoning is underdeveloped.
- 1: minimal explanation or mostly summary.
- 0: no analysis or reasoning.

Organization: 0-4 points
- 4: logical structure with effective transitions and paragraphing.
- 3: organized overall with minor lapses.
- 2: uneven organization that sometimes disrupts meaning.
- 1: limited organization.
- 0: disorganized or not developed as an essay.

Language/conventions: 0-4 points
- 4: clear language and conventions support meaning.
- 3: minor errors that do not interfere with meaning.
- 2: errors or awkward language sometimes interfere with meaning.
- 1: frequent errors make meaning difficult.
- 0: conventions or language prevent reliable understanding.
```

Default custom instructions:

```text
Use the rubric criteria exactly. The draft grade must cite text evidence for each criterion. Do not reward length alone. Do not infer effort, ability, or intent. Mark teacher review required when evidence is missing or when the rubric descriptor is ambiguous.
```

### 6.4 Template: 16-point lab write-up

**ID:** `lab-writeup-16pt`  
**Assignment type:** `labWriteup`  
**Description:** For written science reports, lab reflections, and conclusions.

Rubric text:

```text
Question / purpose: 0-2 points
- 2: clearly states the investigation question or purpose.
- 1: states a partial or vague question/purpose.
- 0: missing or unrelated.

Hypothesis or prediction: 0-2 points
- 2: gives a testable hypothesis or prediction linked to the investigation.
- 1: gives a prediction that is vague, incomplete, or weakly linked.
- 0: missing or unrelated.

Method / procedure summary: 0-3 points
- 3: accurately summarizes the relevant procedure or variables.
- 2: mostly accurate but missing a meaningful detail.
- 1: minimal or unclear method description.
- 0: missing or inaccurate.

Data / observations: 0-3 points
- 3: includes relevant data or observations and identifies patterns.
- 2: includes some relevant data or observations.
- 1: includes minimal or unclear data/observations.
- 0: missing.

Conclusion: 0-3 points
- 3: answers the question and connects to the data.
- 2: answers the question with limited data connection.
- 1: gives a weak or unsupported conclusion.
- 0: missing or unrelated.

Scientific reasoning: 0-3 points
- 3: explains why the data support the conclusion using appropriate scientific ideas.
- 2: gives some scientific reasoning with gaps.
- 1: minimal or unclear reasoning.
- 0: no scientific reasoning.
```

Default custom instructions:

```text
Grade only the written content provided. Do not infer experimental performance beyond the text. Flag missing data, unclear vocabulary, diagram dependence, or unsupported scientific claims for teacher review.
```

### 6.5 Template: 10-point reading comprehension response

**ID:** `reading-comprehension-10pt`  
**Assignment type:** `readingComprehension`  
**Description:** For text-based responses to a reading prompt.

Rubric text:

```text
Direct answer: 0-2 points
- 2: answers the question accurately and completely.
- 1: partially answers the question or is somewhat accurate.
- 0: does not answer the question or is inaccurate.

Text evidence: 0-3 points
- 3: cites or describes accurate, relevant evidence from the text.
- 2: includes relevant but limited or partially explained evidence.
- 1: includes vague, weak, or minimally relevant evidence.
- 0: includes no relevant evidence.

Inference/explanation: 0-3 points
- 3: clearly explains how the evidence supports the answer or inference.
- 2: provides some explanation with minor gaps.
- 1: explanation is minimal, unclear, or mostly restates evidence.
- 0: no explanation.

Clarity: 0-2 points
- 2: response is clear and understandable.
- 1: response is understandable but incomplete, repetitive, or unclear in places.
- 0: response is too unclear to assess reliably.
```

Default custom instructions:

```text
Use only the reviewed student response and the supplied answer key or prompt. If the student refers to text evidence that is not included in the reviewed text, mark teacher review required rather than assuming the reference is correct.
```

### 6.6 Template: 12-point science explanation

**ID:** `science-explanation-12pt`  
**Assignment type:** `shortAnswer` or `labWriteup`  
**Description:** For written scientific explanations using concepts, evidence, and reasoning.

Rubric text:

```text
Concept understanding: 0-4 points
- 4: accurately explains the key scientific concept or relationship.
- 3: mostly accurate with minor gaps or imprecision.
- 2: partially accurate but includes meaningful gaps or confusion.
- 1: minimal accurate understanding.
- 0: inaccurate, missing, or unrelated.

Use of evidence/data: 0-3 points
- 3: uses relevant data, observations, or examples to support the explanation.
- 2: uses some relevant evidence but connection is limited.
- 1: includes minimal or weak evidence.
- 0: no relevant evidence.

Scientific reasoning: 0-3 points
- 3: clearly connects evidence to the concept using scientific reasoning.
- 2: gives some reasoning with gaps.
- 1: reasoning is minimal or unclear.
- 0: no reasoning.

Scientific vocabulary and clarity: 0-2 points
- 2: uses appropriate vocabulary clearly.
- 1: uses some vocabulary but imprecisely or with clarity issues.
- 0: vocabulary is missing, misleading, or prevents reliable assessment.
```

Default custom instructions:

```text
Do not grade diagrams, tables, equations, or experimental setup unless the relevant information appears in the reviewed text or was entered by the teacher. Flag any missing data, diagram dependence, or uncertain vocabulary for teacher review.
```

### 6.7 Template: 12-point HASS source response

**ID:** `hass-source-response-12pt`  
**Assignment type:** `paragraphResponse`  
**Description:** For history, geography, civics, economics, and source-based written responses.

Rubric text:

```text
Understanding of source or context: 0-3 points
- 3: accurately identifies relevant source/context information.
- 2: mostly accurate with minor gaps.
- 1: limited or partially accurate understanding.
- 0: inaccurate, missing, or unrelated.

Use of evidence: 0-3 points
- 3: uses specific, relevant evidence from the source or provided material.
- 2: uses some relevant evidence but lacks specificity or completeness.
- 1: evidence is vague, weak, or minimally relevant.
- 0: no relevant evidence.

Reasoning / interpretation: 0-4 points
- 4: explains the significance, cause/effect, perspective, pattern, or relationship clearly.
- 3: generally sound reasoning with minor gaps.
- 2: partial reasoning with meaningful gaps.
- 1: minimal reasoning or mostly description.
- 0: no relevant reasoning.

Communication: 0-2 points
- 2: clear, organized response using relevant terms.
- 1: understandable but unclear, incomplete, or loosely organized.
- 0: too unclear to assess reliably.
```

Default custom instructions:

```text
Do not assume source facts that are not in the reviewed student response, prompt, answer key, or teacher-provided context. Mark teacher review required when the response depends on a source excerpt not included in the grading packet.
```

### 6.8 Template: 8-point formative exit ticket

**ID:** `formative-exit-ticket-8pt`  
**Assignment type:** `shortAnswer`  
**Assessment purpose:** `formative`  
**Description:** Evidence and next-step feedback for quick formative checks.

Rubric text:

```text
Shows current understanding: 0-3 points
- 3: shows clear understanding of the focus concept or skill.
- 2: shows partial understanding with a small gap or imprecision.
- 1: shows limited understanding or a significant misconception.
- 0: does not yet show the focus concept or skill.

Uses relevant evidence or reasoning: 0-2 points
- 2: includes relevant evidence, reasoning, or explanation.
- 1: includes limited or unclear evidence/reasoning.
- 0: no supporting evidence or reasoning.

Identifies or applies key vocabulary/strategy: 0-1 point
- 1: uses an appropriate key term, strategy, or representation in text.
- 0: does not use the expected term/strategy or it is unclear.

Actionable next step: 0-2 points
- 2: response makes the next teaching or learning step clear.
- 1: some next-step need is visible but requires teacher interpretation.
- 0: evidence is insufficient to determine a next step.
```

Default custom instructions:

```text
This is formative. Emphasize what the student appears to understand from the evidence and one concrete next step. Do not present the output as a final summative grade by default.
```

### 6.9 Template: 12-point reflection response

**ID:** `reflection-response-12pt`  
**Assignment type:** `paragraphResponse`  
**Description:** For written learning reflections and task reflections.

Rubric text:

```text
Connection to task or learning goal: 0-3 points
- 3: clearly connects reflection to the task, goal, or learning focus.
- 2: mostly connected with minor gaps.
- 1: weak or vague connection.
- 0: no clear connection.

Specific evidence or example: 0-3 points
- 3: includes a specific example from the work, process, or learning.
- 2: includes a relevant but limited example.
- 1: includes a vague or minimal example.
- 0: no specific example.

Explanation of learning: 0-3 points
- 3: explains what was learned or improved with clear reasoning.
- 2: gives some explanation with gaps.
- 1: minimal explanation.
- 0: no explanation.

Next step: 0-3 points
- 3: identifies a specific and realistic next step.
- 2: identifies a general next step.
- 1: next step is vague or only implied.
- 0: no next step.
```

Default custom instructions:

```text
Assess only the written reflection. Do not infer effort, attitude, motivation, or personality. Feedback should be supportive, specific, and focused on the evidence in the response.
```

---

## 7. Teacher instruction templates

Teacher instructions should be inserted into the grading packet as constraints. They are not student-facing unless the teacher explicitly includes them in feedback.

### 7.1 General evidence-first instruction

```text
Grade only from the reviewed student text and the grading materials I provided. For every criterion, cite evidence from the reviewed text or mark teacher review required if evidence is missing or unclear.
```

### 7.2 Do-not-penalize conventions instruction

```text
Do not penalize spelling, grammar, punctuation, capitalization, or handwriting unless the rubric explicitly assesses conventions or the errors materially interfere with meaning.
```

### 7.3 Strict answer-key instruction

```text
Use the answer key as the main scoring reference. Award equivalent wording when the meaning is correct. If the response is partially correct, identify which expected elements are present and which are missing.
```

### 7.4 Exemplar comparison instruction

```text
Use the exemplar only as a reference for quality and completeness. Do not require the student's response to match the exemplar wording. Score against the rubric criteria, not against stylistic similarity to the exemplar.
```

### 7.5 Formative feedback instruction

```text
This is formative feedback. Emphasize current evidence of understanding, one misconception or gap if present, and one practical next step. Do not frame the output as a final grade unless I approve it as summative.
```

### 7.6 Summative caution instruction

```text
This may be used for a summative record after teacher review. Keep score suggestions conservative when evidence is incomplete. Mark teacher review required for ambiguous rubric interpretation, missing evidence, or OCR uncertainty.
```

### 7.7 OCR uncertainty instruction

```text
Some text may have come from OCR. If a quote appears garbled, incomplete, or inconsistent, mark teacher review required and do not rely on that text for a confident score.
```

### 7.8 EAL/D-sensitive instruction

```text
Assess the content and reasoning shown in the reviewed student text. Do not infer the student's language background. Do not penalize language features unless the rubric assesses language control or the wording prevents reliable understanding.
```

### 7.9 Adjustment-context instruction

```text
Use only the teacher-provided adjustment context. Do not infer disability, support needs, giftedness, EAL/D status, effort, or intent. Keep adjustment notes private unless I explicitly include them in student-facing feedback.
```

### 7.10 Off-prompt instruction

```text
If the response does not address the prompt, identify the mismatch and score only the evidence that can be connected to the rubric. Do not invent relevance.
```

### 7.11 Misconception instruction

```text
If the response shows a misconception listed in the answer key or visible in the reviewed text, identify it specifically and suggest a next step. Do not diagnose broader ability or future performance.
```

---

## 8. Answer-key and exemplar structures

### 8.1 Short-answer answer key template

```markdown
# Answer Key

## Prompt
[Paste the question or task.]

## Full-credit answer
[State the expected answer in teacher wording.]

## Required elements
1. [Required element 1]
2. [Required element 2]
3. [Required element 3]

## Acceptable equivalent wording
- [Alternative wording or synonym]
- [Alternative phrasing]

## Partial credit guidance
- Full credit: [conditions]
- Partial credit: [conditions]
- No credit: [conditions]

## Common misconceptions
- [Misconception 1]
- [Misconception 2]

## Do not penalize
- [Spelling unless meaning is unclear]
- [Equivalent wording]
```

### 8.2 Paragraph/essay exemplar template

```markdown
# Exemplar Response

## Prompt
[Paste prompt.]

## Exemplar quality level
[High / proficient / developing / teacher-created reference]

## Exemplar text
[Paste exemplar.]

## Why this exemplar is useful
- [Feature 1, e.g., clear claim]
- [Feature 2, e.g., uses evidence]
- [Feature 3, e.g., explains reasoning]

## Important caution
Use this exemplar as a reference. Do not require the student's response to copy its wording or structure unless the rubric requires that structure.
```

### 8.3 Science explanation answer key template

```markdown
# Science Explanation Key

## Focus question
[Paste focus question.]

## Key concept(s)
- [Concept 1]
- [Concept 2]

## Expected evidence or data
- [Data/observation 1]
- [Data/observation 2]

## Expected reasoning
[Describe how the evidence should connect to the concept.]

## Scientific vocabulary
- [Term 1]
- [Term 2]

## Common misconceptions
- [Misconception]

## Unsupported evidence warning
If the response depends on a diagram, table, equation, or data not included in reviewed text, mark teacher review required.
```

### 8.4 HASS source response answer key template

```markdown
# HASS Source Response Key

## Question
[Paste question.]

## Source/context provided to students
[Summarize or paste the relevant source context if appropriate.]

## Expected source understanding
- [Expected understanding]

## Expected evidence
- [Evidence students may cite]

## Expected reasoning
- [Cause/effect, perspective, pattern, significance, continuity/change, civic reasoning, geographic reasoning, etc.]

## Common weak responses
- [Weak response pattern]

## Teacher review trigger
Mark teacher review required if the student refers to source content that is not available in the reviewed text or teacher-provided context.
```

### 8.5 Formative focus template

```markdown
# Formative Focus

## Learning focus
[What understanding or skill is being checked?]

## Aim
[Why is this evidence being collected now?]

## Timing
[Before teaching / during teaching / after practice / exit ticket / revision check]

## Expected evidence
[What should the student response show?]

## Possible next teaching decisions
- [Reteach]
- [Small group]
- [Move on]
- [Give extension]
- [Clarify misconception]

## Student feedback style
Short, specific, and next-step focused.
```

---

## 9. Canonical grading prompt template

This is the content template for a local model prompt. Codex may implement it as string resources, a typed prompt builder, or a structured input adapter. Do not weaken the mandatory rules.

```text
You are a local-only rubric grading assistant for a teacher. You are not the final grader. The teacher will review, edit, and approve every score and comment.

Mandatory rules:
- Grade only from the reviewed student text, rubric, answer key, exemplar, curriculum reference, and custom teacher instructions supplied in this packet.
- Do not infer effort, intent, motivation, behavior, ability beyond the submitted work, demographics, disability, EAL/D status, giftedness, support level, or personality traits.
- Do not invent evidence. Every criterion must cite direct evidence from the reviewed student text or state that evidence is missing.
- Do not invent curriculum references, official standards, answer-key elements, source facts, or exemplar content.
- If the rubric is ambiguous, apply the most conservative reasonable score and add an uncertainty flag.
- If OCR quality or wording is uncertain, mark teacherReviewRequired true for affected criteria.
- If evidence is weak, missing, garbled, or only implied, mark teacherReviewRequired true.
- If the response depends on an unsupported source, diagram, image, math notation, handwriting, or visual artifact, mark teacherReviewRequired true and explain the limitation.
- Return one JSON object only. Do not wrap it in markdown.
- Use numeric proposedPoints and maxPoints.
- Do not include totalScore or maxScore; the app calculates totals.
- If structured criteria are listed, return one and only one score for each criterionId.
- Keep student feedback constructive, specific, and concise.
- Keep teacherNotes private and use them for ambiguity, OCR concerns, evidence concerns, or grading calls.

Assignment metadata:
- Title: {{assignmentTitle}}
- Prompt: {{promptOrNone}}
- Student: {{studentDisplayNameOrNotSpecified}}
- Class: {{classNameOrNotSpecified}}
- Subject: {{subjectOrNotSpecified}}
- Grade/year level: {{gradeLevelOrNotSpecified}}
- Assignment type: {{assignmentTypeDisplayName}}
- Assessment purpose: {{assessmentPurpose}}
- Source input count: {{sourceInputCount}}
- OCR review status: {{ocrReviewStatus}}
- OCR quality summary: {{ocrQualitySummary}}

Curriculum/reference material:
{{curriculumReferenceOrNone}}

Structured rubric criteria:
{{structuredRubricCriteria}}

Raw rubric / answer key / grading criteria:
"""
{{rubricText}}
"""

Custom teacher instructions:
"""
{{customInstructionsOrNone}}
"""

Answer key:
"""
{{answerKeyTextOrNone}}
"""

Exemplar response:
"""
{{exemplarTextOrNone}}
"""

Reviewed student text:
"""
{{reviewedStudentText}}
"""

Required JSON schema:
{
  "studentResponseSummary": "one or two factual sentences about what the student wrote",
  "criteria": [
    {
      "criterionId": "criterion id from the structured rubric list when available",
      "criterion": "criterion name exactly or nearly exactly from the rubric",
      "rating": "rubric level or short label",
      "proposedPoints": 0,
      "maxPoints": 0,
      "evidence": ["quote from reviewed student text, or No supporting evidence found."],
      "evidenceSourceRefs": [],
      "explanation": "specific rubric-based explanation",
      "nextStep": "specific improvement suggestion when appropriate",
      "confidence": "high | medium | low",
      "teacherReviewRequired": true,
      "uncertaintyFlags": []
    }
  ],
  "studentFeedback": "student-facing feedback that is specific, constructive, and concise",
  "teacherNotes": "private notes about ambiguity, grading calls, OCR concerns, or unsupported evidence",
  "uncertaintyFlags": ["issues the teacher should review"],
  "complianceFlags": ["ways the draft was constrained to rubric and evidence"]
}
```

---

## 10. Output validation rules

Codex should implement these as tests and validators.

### 10.1 Required draft validation

A draft is invalid if:

- it contains no criteria;
- a criterion has no name;
- a criterion has negative `maxPoints`;
- `proposedPoints` is below 0 or above `maxPoints` and is not clamped by app code;
- structured criteria exist but the model omits one;
- structured criteria exist but the model scores one twice;
- the model includes total score fields and app code trusts them;
- evidence quotes are empty and `teacherReviewRequired` is false;
- evidence quotes refer to text not present in reviewed student text, unless the quote is the exact missing-evidence marker;
- uncertainty flags are empty despite OCR review warnings, parsed-rubric issues, missing evidence, or unsupported input type;
- output contains prohibited inferences;
- output says the grade is final before teacher approval.

### 10.2 Required normalization

App code may normalize:

- whitespace;
- criterion names matched to structured rubric titles;
- point values clamped between 0 and max;
- blank evidence removed;
- duplicate compliance flags deduplicated;
- parsed-rubric issues added to uncertainty flags;
- draft status set to `teacherReviewRequired` when any criterion requires review.

App code must not silently normalize away:

- missing structured criteria;
- unsupported visual/multimodal claims;
- prohibited inferences;
- nonexistent evidence;
- malformed JSON;
- local AI unavailability.

### 10.3 Prohibited inference validator

Flag or reject model output containing unsupported claims about:

- effort;
- intent;
- motivation;
- engagement;
- attitude;
- personality;
- behavior outside the submitted work;
- disability;
- EAL/D status;
- giftedness;
- demographic traits;
- socioeconomic status;
- home support;
- parental support;
- future performance;
- intelligence;
- diligence;
- laziness;
- carelessness, unless describing a visible feature of the work product and framed neutrally.

Preferred neutral replacements:

| Prohibited phrasing | Safer phrasing |
|---|---|
| The student did not try | The submitted response does not provide evidence for this criterion. |
| The student is careless | Several errors in the submitted text make the meaning hard to follow. |
| The student does not understand | The response does not yet show the expected concept. |
| The student is an EAL/D learner | The response includes language features that may require teacher review if language control is being assessed. |
| The student has a disability | Use only teacher-provided adjustment context; do not infer from the work. |

---

## 11. Evidence rules

### 11.1 Evidence hierarchy

Use evidence in this order:

1. Teacher-confirmed reviewed student text.
2. Digitally extracted PDF text accepted by the teacher or auto-accepted by policy.
3. OCR text that has been corrected or confirmed by the teacher.
4. Teacher-entered observation or visual tag in future visual modes.

Do not use:

- raw OCR that requires review;
- uncertain handwriting without teacher confirmation;
- inferred diagram or image meaning;
- facts from outside the grading packet;
- curriculum facts not supplied or imported;
- source excerpts not included in the packet;
- private teacher notes as student evidence unless explicitly selected.

### 11.2 Evidence quote rules

A criterion evidence quote should be:

- exact where possible;
- short enough to be readable;
- tied to the criterion;
- present in the reviewed student text;
- not fabricated;
- not a paraphrase unless labelled teacher-confirmed paraphrase;
- marked missing when no evidence exists.

Canonical missing evidence marker:

```text
No supporting evidence found.
```

If this marker is used, `teacherReviewRequired` must be true.

### 11.3 Evidence-source references

When implemented, source references should use stable IDs such as:

```text
source:<sourceInputID>:page:<pageIndex>:ocrLine:<ocrLineID>
reviewedText:<startOffset>-<endOffset>
teacherObservation:<observationID>
visualRegion:<regionID>
```

If source references are not implemented, the UI must not imply bounding-box traceability. It may say:

> Evidence is quoted from the teacher-reviewed text. Source-image linking is not available in this version.

### 11.4 Weak evidence handling

Weak evidence means:

- the quote is vague;
- the quote is only tangentially related;
- the quote may be OCR-garbled;
- the response gestures at an idea without explaining it;
- the student refers to a source not present in the packet;
- the criterion requires more evidence than the response provides.

Required handling:

- assign conservative points;
- add criterion-level explanation;
- add uncertainty flag;
- set `teacherReviewRequired` true;
- do not present the score as final.

---

## 12. OCR and text-review content

### 12.1 OCR review states

Use these document-level states:

| State | Meaning | Blocks grading? | UI copy |
|---|---|---:|---|
| `notNeeded` | Pasted text or trusted digital text does not require OCR review. | No | No OCR review needed. |
| `processing` | OCR is running. | Yes | Extracting text on device... |
| `needsReview` | OCR text requires teacher review. | Yes | Review extracted text before grading. |
| `reviewed` | Teacher confirmed the extracted text. | No | OCR reviewed. |
| `blocked` | OCR result is too unreliable or unsupported. | Yes | OCR blocked. Enter or correct the text manually before grading. |
| `failed` | OCR failed. | Yes | Text extraction failed. Enter the student text manually or try another scan. |

Current Swift has `notNeeded`, `needsReview`, `reviewed`, and `blocked`. Additional states may be added when implementing richer OCR.

### 12.2 Line/span review states

Use these line/span states when per-line UI exists:

| State | Meaning |
|---|---|
| `autoAccepted` | High-confidence text accepted under policy. |
| `needsReview` | Teacher must check the text. |
| `teacherCorrected` | Teacher edited the text. |
| `teacherConfirmed` | Teacher confirmed the line/span. |
| `rejected` | Teacher rejected the OCR line/span. |
| `blockedFromGrading` | This text must not be used as grading evidence. |

### 12.3 Confidence bands

Use conservative default bands:

| Confidence | Action | UI label |
|---:|---|---|
| `>= 0.97` | Auto-accept unless layout risk exists. | High confidence |
| `0.90 - 0.97` | Highlight for review. | Review suggested |
| `< 0.90` | Mandatory review. | Review required |
| `< 0.75` | Strong warning and default block. | Low confidence |

The current scaffold uses a lower confidence threshold. If production OCR review is implemented, prefer the conservative bands above or expose thresholds as internal configuration.

### 12.4 Force-review triggers

Force teacher OCR review when:

- handwriting is detected or suspected;
- mixed handwriting and print appear;
- the page is low-light, blurred, skewed, shadowed, or faint;
- multi-column or table layout may affect reading order;
- math notation, formulas, or diagrams are present;
- OCR returns zero text;
- OCR confidence is low;
- candidate strings are ambiguous;
- OCR appears to omit visible text;
- teacher imports a photo rather than a clean digital PDF.

### 12.5 OCR UI copy

#### OCR review banner

```text
Review extracted text before grading. GradeDraft can draft feedback only from text you have confirmed.
```

#### Low-confidence line warning

```text
This line may have been read incorrectly. Check it against the source image before using it for grading.
```

#### OCR blocked warning

```text
Text extraction is not reliable enough to grade from this source. Correct the text manually or enter the student response before drafting feedback.
```

#### OCR failed warning

```text
Text extraction failed. You can try another scan, import a clearer image, or enter the student text manually.
```

#### Mark reviewed confirmation

```text
Mark OCR reviewed?

Only continue if the text shown here accurately reflects the student work you want GradeDraft to use. The app will draft feedback from this reviewed text, not from the original image.
```

Primary button:

```text
Mark Reviewed
```

Secondary button:

```text
Keep Reviewing
```

#### Manual transcription mode

```text
Enter the student text manually. GradeDraft will treat this as teacher-confirmed text for grading.
```

### 12.6 Side-by-side OCR review layout

When implemented, the preferred layout is:

- left side: original source image or PDF page;
- right side: editable extracted text;
- line highlight on tap;
- confidence badge for each line;
- buttons for `Confirm line`, `Edit line`, `Reject line`, and `Mark page reviewed`;
- document-level `Mark all high-confidence lines reviewed` only when low-risk and reversible.

### 12.7 OCR export warnings

Student-facing final exports should be blocked if OCR is unreviewed. Teacher-only diagnostic exports may proceed with a clear warning.

Warning title:

```text
Export includes unconfirmed OCR text
```

Warning body:

```text
Some extracted text has not been confirmed by the teacher. Review uncertain OCR before exporting or using it for grading records.
```

Primary button:

```text
Review OCR Issues
```

Teacher-only secondary button:

```text
Export Teacher Copy
```

Do not offer `Export Anyway` for student-facing final reports.

---

## 13. Local AI availability content

### 13.1 Capability banner states

| State | UI title | Body |
|---|---|---|
| Available | Local AI ready | Draft grading suggestions can run on this device using the local model. Teacher review is still required. |
| Device not eligible | Local AI not available on this device | You can still scan, review text, edit rubrics, and grade manually. This device cannot generate local AI draft suggestions. |
| Apple Intelligence disabled | Local AI is turned off | Enable the required on-device AI setting in system settings, or continue using manual grading tools. |
| Model not ready | Local AI model is not ready | The local model may still be preparing on this device. Continue with manual grading or try again later. |
| Unsupported language/region | Local AI unavailable for this language or region | Continue with manual grading. Do not use cloud fallback in the core workflow. |
| Context too large | Assignment too large for one local draft | Shorten the input, draft by criterion, or split the submission. |
| Unknown unavailable | Local AI grading unavailable | GradeDraft cannot generate a local AI draft right now. Manual review and export remain available. |

### 13.2 Unavailable-state copy

```text
Local AI grading is unavailable in this build or on this device. GradeDraft will not send student work to a cloud model as a fallback. You can continue reviewing text, editing the rubric, and grading manually.
```

### 13.3 Draft button labels

Use:

```text
Draft Feedback Suggestion
```

or:

```text
Draft Grade for Review
```

Avoid:

```text
Auto-grade
```

```text
Grade Automatically
```

```text
Accept AI Grade
```

### 13.4 Malformed model output error

```text
The local model returned a response the app could not use. No grade was saved. Try again with a shorter rubric or review the assignment manually.
```

### 13.5 Invalid model grade error

```text
The local model returned an invalid draft. GradeDraft rejected it because it did not meet the rubric/evidence rules.
```

---

## 14. Teacher review workflow content

### 14.1 Draft status labels

| Status | Label | Explanation |
|---|---|---|
| `generated` | Draft generated | Review every criterion before finalizing. |
| `teacherReviewRequired` | Teacher review required | At least one criterion has missing evidence, uncertainty, OCR concern, or rubric ambiguity. |
| `stale` | Draft stale | Inputs changed after this draft was generated. Regenerate or review manually. |

### 14.2 Final review status labels

| Status | Label | Explanation |
|---|---|---|
| `inProgress` | Final review in progress | Save edits and approve before treating this as final. |
| `approved` | Approved by teacher | This grade reflects teacher-final review. |
| `stale` | Final review stale | Inputs changed after this final review was created. Review before use. |

### 14.3 Start final review copy

```text
Start teacher final review
```

Description:

```text
Copy the draft into an editable teacher review. Proposed points and final points will remain separate.
```

### 14.4 Save edits copy

```text
Save Teacher Edits
```

### 14.5 Approve final grade copy

```text
Approve Final Grade
```

Confirmation body:

```text
Approve this as the teacher-final grade? You can still keep the AI proposal for audit, but the final score and feedback will reflect your reviewed edits.
```

Primary button:

```text
Approve Final Grade
```

Secondary button:

```text
Keep Reviewing
```

### 14.6 Criterion review checklist

Each criterion card should allow the teacher to confirm:

- criterion name;
- proposed points;
- final points;
- max points;
- evidence quote(s);
- explanation;
- student-facing feedback effect;
- teacher rationale if changed;
- approval toggle.

### 14.7 Stale-state copy

Draft stale:

```text
This draft is stale because grading inputs changed after it was generated. Regenerate the draft or review the changes manually before using it.
```

Final review stale:

```text
This final review is stale because grading inputs changed after it was approved or edited. Review the changed inputs before exporting or sharing.
```

### 14.8 Regeneration warning

```text
Generate a new draft?

A new draft may differ from the current one. Your teacher-final review will remain separate, but it may be marked stale if the grading packet changed.
```

Primary button:

```text
Generate New Draft
```

Secondary button:

```text
Cancel
```

---

## 15. Student-facing feedback rules

### 15.1 Tone rules

Student-facing feedback should be:

- specific;
- concise;
- tied to rubric criteria;
- grounded in evidence;
- actionable;
- respectful;
- focused on the submitted work;
- free of private teacher notes;
- free of unsupported trait inferences.

### 15.2 Feedback structure

Preferred student feedback structure:

```text
What you did well: [one evidence-linked strength]
What to improve: [one evidence-linked gap]
Next step: [one concrete action]
```

For short answers, one paragraph is enough. For longer work, use 2-4 bullets.

### 15.3 Avoid in student feedback

Avoid:

- "You did not try."
- "You are careless."
- "You do not understand this."
- "You are below grade level."
- "Your disability/language background affects..."
- "The AI decided..."
- "The app graded you..."
- private teacher rationales;
- raw OCR uncertainty flags unless teacher intentionally includes them;
- internal compliance flags;
- raw model output.

### 15.4 Preferred phrasing

| Situation | Student-facing phrasing |
|---|---|
| Missing evidence | Add a specific detail or quote that supports your answer. |
| Weak claim | Make your answer more direct by stating your main idea first. |
| Underdeveloped reasoning | Explain how your evidence supports your answer. |
| Partial concept understanding | You show part of the idea; next, connect it to [specific concept]. |
| Organization issue | Group related ideas together so the response is easier to follow. |
| Conventions interfere with meaning | Check the wording in [specific sentence/part] so your meaning is clearer. |

---

## 16. Student report templates

### 16.1 Student report header

```markdown
# GradeDraft Student Feedback

**Assignment:** {{assignmentTitle}}
**Student:** {{studentDisplayNameOrLocalIdentifier}}
**Class:** {{classNameOrNotSpecified}}
**Subject:** {{subjectOrNotSpecified}}
**Grade/year level:** {{gradeLevelOrNotSpecified}}
**Assignment type:** {{assignmentTypeDisplayName}}
**Updated:** {{updatedDate}}

> Generated from local app state. GradeDraft does not upload this report.
> This student-facing report excludes private teacher notes and raw model responses.
```

### 16.2 Final teacher-approved student report

```markdown
## Final teacher-approved grade

**Score:** {{finalTotalScore}} / {{finalMaxScore}}

### Feedback

{{teacherFinalStudentFeedback}}

### Criteria

{{#criteria}}
#### {{criterionName}}
- Final score: {{finalPoints}} / {{maxPoints}}
- Rating: {{ratingOrNotSpecified}}
- Evidence: {{studentFacingEvidence}}
- Explanation: {{studentFacingExplanation}}
{{/criteria}}
```

### 16.3 Draft student report warning

Student-facing draft reports should normally be blocked. If the app supports a draft preview for teacher use, use this warning:

```markdown
## Draft grade for teacher review

This is not a finalized grade. A teacher must review and approve it before use.
```

### 16.4 Formative report template

```markdown
## Formative feedback

**Learning focus:** {{formativeFocus}}

### Evidence noticed

{{evidenceSummary}}

### Current understanding

{{currentUnderstandingFeedback}}

### Next step

{{nextStep}}

> This formative feedback is for learning support and is not a final grade unless the teacher marks it as summative.
```

---

## 17. Teacher audit report template

Teacher audit reports may include sensitive records. They are not student-facing by default.

### 17.1 Header

```markdown
# GradeDraft Teacher Audit Report

**Assignment:** {{assignmentTitle}}
**Student:** {{studentDisplayNameOrLocalIdentifier}}
**Class:** {{classNameOrNotSpecified}}
**Subject:** {{subjectOrNotSpecified}}
**Grade/year level:** {{gradeLevelOrNotSpecified}}
**Assignment type:** {{assignmentTypeDisplayName}}
**Updated:** {{updatedDate}}

> This teacher audit report may include private notes, reviewed text, OCR warnings, source fingerprints, and grading-state metadata. Treat it as sensitive student data.
> Generated from local app state. GradeDraft does not upload this report.
```

### 17.2 Required sections

```markdown
## Readiness and source state
- OCR review status: {{ocrReviewStatus}}
- Source inputs: {{sourceInputCount}}
- Current grading packet fingerprint: {{packetFingerprint}}
- Draft stale: {{yesNo}}
- Final review stale: {{yesNo}}

## Source inputs
{{sourceInputList}}

## OCR summary
- Engine: {{ocrEngine}}
- Review status: {{ocrReviewStatus}}
- Quality: {{ocrQualitySummary}}
- Reviewed at: {{ocrReviewedAtOrNotReviewed}}

## Reviewed student text

{{reviewedStudentText}}

## Rubric and grading materials

### Rubric
{{rubricText}}

### Custom teacher instructions
{{customInstructions}}

### Answer key
{{answerKeyText}}

### Exemplar
{{exemplarText}}

## Model draft
- Draft status: {{draftStatus}}
- Score: {{draftTotalScore}} / {{draftMaxScore}}
- Packet fingerprint: {{draftPacketFingerprint}}

{{draftCriteria}}

### Uncertainty flags
{{uncertaintyFlags}}

### Compliance flags
{{complianceFlags}}

### Private model/teacher notes
{{draftTeacherNotes}}

## Final teacher review
- Status: {{finalStatus}}
- Score: {{finalTotalScore}} / {{finalMaxScore}}
- Packet fingerprint: {{finalPacketFingerprint}}
- Finalized at: {{finalizedAtOrNotFinalized}}

{{finalCriteria}}

### Private teacher notes
{{privateTeacherNotes}}

## Export records
{{exportRecords}}

## Audit events
{{auditEvents}}
```

### 17.3 Teacher audit privacy note

Include this near export:

```text
Teacher audit reports may include private notes, OCR uncertainty, source references, draft scoring, final scoring, and reviewed student text. They are sensitive student records and should not be shared with students or families unless reviewed and redacted.
```

---

## 18. Export, backup, and sharing warnings

The following copy is canonical. Implement warnings before file creation or share-sheet handoff. Do not use weak warnings like "Are you sure?"

### 18.1 Global export confirmation

Title:

```text
Export student information?
```

Body:

```text
This export may include student names, assignment work, grades, rubric scores, feedback, and teacher notes. Once exported, the file may leave the app's protected local storage. Store and share it only through approved school channels.
```

Primary button:

```text
Continue to Export
```

Secondary button:

```text
Cancel
```

Optional checkbox:

```text
I understand this file may contain sensitive student information.
```

### 18.2 Student-facing report export

Title:

```text
Review student-facing report
```

Body:

```text
This report is intended for student or family review. Confirm that it includes only the feedback, scores, and evidence you want the student or family to see.
```

Warning line:

```text
Teacher-only notes and internal review flags should not be included unless you intentionally add them.
```

Primary button:

```text
Preview Report
```

Secondary button:

```text
Cancel
```

Post-preview confirmation:

```text
I reviewed the report and confirmed it is appropriate to share.
```

Final button:

```text
Export Student Report
```

### 18.3 Teacher-only record export

Title:

```text
Export teacher-only grading record?
```

Body:

```text
This file may include internal grading notes, draft scores, rubric reasoning, OCR uncertainty flags, and teacher annotations. It is not intended for students or families unless reviewed and redacted.
```

Primary button:

```text
Export Teacher Record
```

Secondary button:

```text
Cancel
```

Optional checkbox:

```text
I understand this export may include teacher-only content.
```

### 18.4 PDF export warning

Title:

```text
Export PDF with student information?
```

Body:

```text
This PDF may include student names, assignment text, grading feedback, rubric scores, and evidence quotes. Review the preview before sharing. Once exported, the PDF can be copied, printed, emailed, uploaded, or forwarded outside the app.
```

Primary button:

```text
Preview PDF
```

Secondary button:

```text
Cancel
```

Final button:

```text
Export PDF
```

### 18.5 CSV export warning

Title:

```text
Export spreadsheet data?
```

Body:

```text
This CSV may include student names, scores, grades, rubric labels, and comments. CSV files are easy to copy, upload, email, and re-import into other systems. Use only approved school storage and transfer methods.
```

Security note:

```text
GradeDraft neutralizes spreadsheet formula-injection risks before export. Review free-text fields before sharing.
```

Primary button:

```text
Export CSV
```

Secondary button:

```text
Cancel
```

Optional checkbox:

```text
I understand this file may expose student records if shared incorrectly.
```

### 18.6 JSON export warning

Title:

```text
Export structured data?
```

Body:

```text
This JSON file may contain full assignment records, OCR text, rubric data, scores, feedback, teacher notes, and internal metadata. JSON exports may reveal more information than a student-facing report.
```

Primary button:

```text
Export JSON
```

Secondary button:

```text
Cancel
```

Optional checkbox:

```text
I understand this export may include complete local records.
```

### 18.7 ZIP/archive export warning

Title:

```text
Export archive with source files?
```

Body:

```text
This archive may include scanned work images, OCR text, grading records, feedback drafts, rubrics, and teacher notes. Archives can contain multiple files and may expose more student information than expected.
```

Checklist:

```text
Before export, review which classes, assignments, and students are included; whether scanned images are included; whether teacher-only notes are included; and whether the destination is approved by your school or district.
```

Primary button:

```text
Review Archive Contents
```

Secondary button:

```text
Cancel
```

Final button:

```text
Export Archive
```

### 18.8 Clipboard warning

Title:

```text
Copy student information?
```

Body:

```text
The copied text may include student information. Other apps, shared devices, or clipboard history tools may expose copied content. Copy only what you need.
```

Primary button:

```text
Copy
```

Secondary button:

```text
Cancel
```

### 18.9 Share sheet warning

Title:

```text
Share outside the app?
```

Body:

```text
You are about to send a file or text to another app. GradeDraft cannot control how that destination app stores, syncs, forwards, or protects the information.
```

Primary button:

```text
Open Share Sheet
```

Secondary button:

```text
Cancel
```

Optional link:

```text
Learn what is included in this export.
```

### 18.10 Backup toggle warning

Title:

```text
Include student records in device backup?
```

Body:

```text
By default, GradeDraft keeps student records local and excludes sensitive app files from backup where supported. If you enable backup for student records, copies may be stored outside this device according to your device and account settings.
```

Primary button:

```text
Enable Backup
```

Secondary button:

```text
Keep Local Only
```

Optional checkbox:

```text
I have confirmed this is permitted by my school or district.
```

### 18.11 Delete local data warning

Title:

```text
Delete local student records?
```

Body:

```text
This will remove the selected records from this device. This action may delete scans, OCR text, scores, feedback, and teacher notes stored in the app. Export a permitted backup first if your school requires retention.
```

Primary button:

```text
Delete Records
```

Secondary button:

```text
Cancel
```

Escalated confirmation:

```text
Type DELETE to confirm.
```

### 18.12 Teacher notes inclusion warning

Title:

```text
Include teacher-only notes?
```

Body:

```text
Teacher-only notes may contain internal observations, draft reasoning, or information not intended for students or families. Include them only if this export is for internal school use.
```

Primary button:

```text
Include Teacher Notes
```

Secondary button:

```text
Exclude Teacher Notes
```

Default:

```text
Exclude Teacher Notes
```

### 18.13 Draft grade export warning

Title:

```text
Export draft scores?
```

Body:

```text
Some scores or comments are still marked as drafts. Draft grading content should not be shared with students or families unless you have reviewed and finalized it.
```

Primary button:

```text
Review Drafts
```

Secondary button for teacher-only diagnostic export:

```text
Export Teacher Copy
```

Required default: block student-facing export until all draft items are finalized.

---

## 19. Privacy and local-security copy

### 19.1 Privacy policy summary

```text
GradeDraft stores and processes student work, grading records, rubrics, teacher notes, and feedback locally on your device. The developer does not receive, upload, or access this information in the core app workflow. Because this information is processed only on device and is not transmitted to the developer or third-party partners, it is not collected by the developer in the core workflow. You should still treat local app data and exported files as sensitive student information.
```

### 19.2 App Review notes draft

```text
GradeDraft is a teacher-facing local-first grading assistant. The core workflow runs on device. The app does not upload student work, OCR text, rubrics, grading drafts, teacher notes, final grades, or feedback reports to the developer or third-party services. The app does not include third-party analytics, advertising, tracking, or cloud AI grading. Student work may be imported or scanned by the teacher and remains in local app storage unless the teacher explicitly exports it through the iOS share sheet. The app includes in-app warnings for sensitive exports and is intended for teachers, not direct child use.
```

If no accounts exist, add:

```text
The app does not require a user account, and there is no developer-accessible backend account database.
```

If local lock exists, add:

```text
The app includes local device authentication for sensitive areas and exports where supported.
```

### 19.3 Local lock description

```text
Local lock helps prevent casual access to GradeDraft on this device. It does not make exported files encrypted and does not replace school-approved device security, passcodes, or records policies.
```

### 19.4 Data protection description

```text
GradeDraft uses iOS/iPadOS local storage protections where implemented. Device passcode, Face ID or Touch ID, school device management, and careful export handling remain important.
```

Avoid:

```text
Your data is completely secure.
```

Avoid:

```text
Exports are protected after they leave the app.
```

### 19.5 Student/parent notice short form

```text
[School/District] uses GradeDraft, a teacher-facing iPad/iPhone tool, to help teachers review student work and draft rubric-based feedback. The app is designed for teacher use, not student sign-in or direct student use. In the core workflow, student work and grading information are processed locally on the teacher's device and are not uploaded to the app developer, cloud AI services, cloud OCR services, analytics providers, or advertisers. Teachers review and finalize all grades and feedback. Exported files, if created by the teacher, may contain student information and must be handled under [School/District] privacy and records policies.
```

### 19.6 Local data inventory copy

Use in privacy settings or help:

```text
Depending on how you use GradeDraft, local records may include student identifiers, scanned work, pasted text, OCR text, rubrics, answer keys, exemplars, draft scores, final scores, feedback, private teacher notes, export records, and audit events. These records stay on this device in the core workflow unless you export or share them.
```

---

## 20. UI string library

### 20.1 Readiness issues

Use these strings for readiness checks:

- `Add a rubric, answer key, exemplar, or grading criteria before drafting feedback.`
- `Add or review the student text before drafting feedback.`
- `Review and confirm OCR text before drafting feedback.`
- `Local AI grading is unavailable. Manual review is still available.`
- `This draft is stale because the grading inputs changed.`
- `This final review is stale because the grading inputs changed.`
- `At least one criterion has no cited student evidence.`
- `At least one criterion requires teacher review.`
- `Student-facing export is blocked until the teacher approves the final grade.`
- `Teacher-only notes are excluded from student reports by default.`

### 20.2 Empty states

No assignments:

```text
Create an assignment to start reviewing student work.
```

No rubric:

```text
Add a rubric, answer key, exemplar, or grading criteria so GradeDraft knows what to assess.
```

No student text:

```text
Scan, import, or paste student text. GradeDraft drafts feedback only from reviewed text.
```

No OCR text:

```text
No OCR text has been captured. Scan or import a source, or paste the student response directly.
```

No draft:

```text
No draft has been generated yet. Add reviewed text and a grading standard, then draft feedback for teacher review.
```

No final review:

```text
No teacher-final review yet. Start final review from a draft or grade manually.
```

No export:

```text
No report has been exported for this assignment.
```

### 20.3 Buttons

Use these labels:

- `New Assignment`
- `Duplicate Assignment`
- `Save`
- `Delete`
- `Scan`
- `Import Photo`
- `Import PDF`
- `Paste Text`
- `Clear Source`
- `Review OCR`
- `Mark OCR Reviewed`
- `Apply Template`
- `Draft Feedback Suggestion`
- `Start Teacher Final Review`
- `Save Teacher Edits`
- `Approve Final Grade`
- `Preview Student Report`
- `Export Student Report`
- `Export Teacher Audit Report`
- `Export CSV`
- `Review Export Contents`
- `Open Share Sheet`
- `Keep Local Only`

Avoid these labels:

- `Auto-grade`
- `Accept AI Grade`
- `AI Final`
- `One-click Grade`
- `Guaranteed Score`
- `Fix Student Work`

### 20.4 Error messages

Missing rubric:

```text
Add a rubric, answer key, exemplar, or grading criteria before drafting feedback.
```

Missing student text:

```text
Add or review the student text before drafting feedback.
```

OCR review required:

```text
Review and confirm OCR text before drafting feedback.
```

Local model unavailable:

```text
Local AI grading is unavailable. GradeDraft will not send this student work to a cloud model as a fallback.
```

Malformed model response:

```text
The local model returned a response the app could not parse. No grade was saved.
```

Invalid model grade:

```text
The local model returned a draft that failed validation. No grade was saved.
```

Persistence failure:

```text
GradeDraft could not save local data. Do not close the app until you have copied or exported any important work.
```

Export failure:

```text
GradeDraft could not create the export. No file was shared.
```

---

## 21. Australian Curriculum configuration

This section is optional market configuration, not MVP core unless explicitly implemented. It is included because the source material contains Australian Curriculum analysis and app requirements.

### 21.1 Australian product description

```text
A local-first iPad app that helps Australian teachers review student work, connect evidence to rubrics and achievement standards, and draft feedback for teacher final approval.
```

### 21.2 Australian settings object

```json
{
  "regionalSettings": {
    "country": "Australia",
    "curriculumVersion": "Australian Curriculum Version 9.0",
    "jurisdiction": "Not specified",
    "sector": "Not specified",
    "language": "en-AU",
    "spelling": "Australian English"
  }
}
```

### 21.3 Australian terminology defaults

Use when Australian mode is enabled:

- `achievement standard`
- `content description`
- `learning area`
- `year level`
- `Foundation to Year 10`
- `parent/carer`
- `Standard Australian English`
- `Aboriginal and Torres Strait Islander Histories and Cultures`
- `HASS`
- `The Arts`
- `Technologies`
- `teacher judgement`
- `on-balance judgement`
- `finalise`
- `judgement`
- `behaviour` where relevant to spelling, but do not infer behavior as a grading trait.

### 21.4 Australian learning areas

Support these learning areas as labels and filters:

1. English.
2. Mathematics.
3. Science.
4. Health and Physical Education.
5. Humanities and Social Sciences (HASS).
6. The Arts.
7. Technologies.
8. Languages.

### 21.5 Australian curriculum reference object

```json
{
  "curriculumReference": {
    "source": "Australian Curriculum",
    "version": "9.0",
    "learningArea": "English",
    "subject": "English",
    "yearLevel": "Year 6",
    "contentDescriptions": [
      {
        "code": "teacher-entered-or-MRAC-imported",
        "text": "teacher-entered or official imported",
        "sourceUrl": "official URL or MRAC URI"
      }
    ],
    "achievementStandardAspects": [
      {
        "id": "local-id",
        "text": "teacher-selected aspect",
        "sourceUrl": "official URL or MRAC URI"
      }
    ],
    "generalCapabilities": [],
    "crossCurriculumPriorities": [],
    "officialImportVerified": false
  }
}
```

### 21.6 Australian warnings

Achievement standard warning:

```text
Achievement standards support teacher judgement. Your school, sector, or jurisdiction may have additional reporting requirements.
```

Official import warning when not implemented:

```text
These curriculum references were entered by the teacher. GradeDraft has not verified them against an official curriculum import in this version.
```

Jurisdiction warning:

```text
States, territories, sectors, and schools may have different reporting requirements. Confirm that this export matches your local policy before sharing or recording it.
```

### 21.7 Claims to avoid in Australian mode

- `Automatically grades Australian Curriculum work.`
- `Certifies achievement against Australian Curriculum standards.`
- `Works for every jurisdiction reporting requirement.`
- `Uses official ACARA data` unless official import is actually implemented.
- `Produces final grades without teacher review.`

---

## 22. Student diversity and inclusive feedback safeguards

### 22.1 Core rule

The app may use teacher-provided adjustment context, but it must not infer protected, sensitive, or personal traits from the student work.

### 22.2 Teacher-provided adjustment object

```json
{
  "teacherProvidedAdjustmentContext": {
    "hasTeacherNotes": true,
    "notesArePrivate": true,
    "studentFacing": false,
    "languageAssessmentMode": "content_only | language_control_assessed | teacher_specified",
    "doNotInfer": [
      "disability",
      "EAL/D status",
      "giftedness",
      "effort",
      "intent",
      "support level",
      "demographic traits"
    ]
  }
}
```

### 22.3 EAL/D-sensitive content mode

UI label:

```text
Assess content separately from language control where appropriate.
```

Help text:

```text
Use this when you want feedback to focus on content understanding unless the rubric specifically assesses language control. GradeDraft will not infer a student's language background.
```

### 22.4 Adjustment notes warning

```text
Adjustment notes are private teacher context. They are excluded from student-facing reports unless you intentionally include them.
```

### 22.5 Inclusive feedback rules

Feedback should:

- describe observable work evidence;
- provide concrete next steps;
- avoid diagnostic language;
- avoid personal traits;
- avoid deficit labels;
- distinguish language control from content understanding when the teacher asks;
- preserve teacher authority over adjustment context.

---

## 23. Formative assessment mode

Formative mode should be point-light and next-step heavy.

### 23.1 Formative object

```json
{
  "formativeAssessment": {
    "formativeFocus": "string",
    "aim": "string",
    "timing": "before teaching | during teaching | after practice | exit ticket | revision check",
    "evidenceType": "student response | teacher observation | reviewed text | other",
    "nextTeachingDecision": "teacher-entered or AI-drafted for teacher review"
  }
}
```

### 23.2 Formative output schema

```json
{
  "formativeFeedback": {
    "focus": "string",
    "evidenceNoticed": ["quote or observation"],
    "currentUnderstanding": "string",
    "possibleMisconception": "string or empty",
    "studentNextStep": "string",
    "teacherNextTeachingStep": "string",
    "teacherReviewRequired": true
  }
}
```

### 23.3 Formative UI copy

```text
Formative mode drafts feedback for learning and next teaching decisions. It is not a final grade unless you approve it as one.
```

### 23.4 Formative acceptance criteria

- Output includes evidence.
- Output includes a next step.
- Output does not default to a summative grade.
- Teacher can save or edit next teaching decision.
- Private teacher next steps do not appear in student report unless selected.

---

## 24. Future visual and handwriting evidence model

This is roadmap content only. Do not expose as working functionality until implemented.

### 24.1 Visual artifact object

```json
{
  "visualArtifactEvidence": {
    "artifactType": "poster | model | diagram | worksheet | concept_map | other",
    "sourceImages": [],
    "teacherTaggedRegions": [
      {
        "regionID": "uuid",
        "sourceInputID": "uuid",
        "pageIndex": 0,
        "boundingBox": { "x": 0, "y": 0, "width": 0, "height": 0 },
        "teacherLabel": "string",
        "teacherDescription": "string",
        "studentVisibleText": "teacher-confirmed text",
        "usableForGrading": true
      }
    ],
    "unsupportedClaims": [
      "craftsmanship quality not teacher-confirmed",
      "spatial relationship not teacher-confirmed"
    ]
  }
}
```

### 24.2 Visual mode rules

- The model may not infer visual quality from an image unless a validated local visual model and teacher confirmation workflow exist.
- Teacher-tagged regions may be used as evidence.
- OCR labels on images require teacher review.
- Creativity, craftsmanship, aesthetics, and presentation quality require teacher final judgement.
- If teacher-confirmed visual evidence is missing, the app must abstain or mark review required.

### 24.3 Handwriting mode rules

- Treat handwriting OCR as assistive transcription.
- Require teacher confirmation before grading.
- Store raw recognition, corrected text, and teacher-confirmed text separately.
- Do not claim reliable handwriting grading.
- Do not use handwriting neatness as effort or ability evidence unless the rubric explicitly assesses legibility and the teacher confirms it.

### 24.4 Math mode rules

- Do not infer mathematical correctness from general OCR.
- Teacher may enter or confirm transcription of the student's reasoning.
- Text explanations can be assessed with a rubric.
- Equations, diagrams, fractions, superscripts, matrices, and symbolic work require specialized future support or teacher confirmation.

---

## 25. Export format content requirements

### 25.1 Student report must include

- assignment title;
- student display name or local identifier, if used;
- class/subject/grade-level metadata where teacher chooses;
- final score and max score if approved;
- criterion-level final scores;
- student-facing evidence where appropriate;
- student-facing explanation;
- teacher-final feedback;
- local-generation note.

### 25.2 Student report must exclude by default

- private teacher notes;
- raw model response;
- internal compliance flags;
- OCR uncertainty flags;
- audit events;
- source-image fingerprints;
- local file paths;
- adjustment notes;
- draft-only scores unless clearly marked and teacher-selected.

### 25.3 Teacher audit report must include

- assignment metadata;
- source input references;
- OCR status and quality summary;
- reviewed student text;
- rubric text;
- answer key;
- exemplar;
- custom instructions;
- draft proposal;
- final review;
- uncertainty flags;
- compliance flags;
- private teacher notes;
- packet fingerprints;
- export records;
- audit events.

### 25.4 CSV export fields

Canonical CSV headers:

```text
assignment_id,title,subject,grade_level,class_name,student,assignment_type,assessment_purpose,total_score,max_score,final_status,ocr_status,draft_status,final_review_stale,draft_stale,updated_at
```

CSV rules:

- Prefer final approved totals over draft totals.
- If no final review exists, label status `pending_final_review`.
- If final review exists but is stale, label status `stale_review`.
- Escape formula-like strings beginning with `=`, `+`, `-`, `@`, or leading whitespace followed by those characters.
- Do not include private teacher notes in default CSV.
- Include a separate teacher-audit CSV only if deliberately implemented and warned.

### 25.5 ZIP/archive inventory

Before archive export, show:

- number of assignments;
- number of students;
- whether scans/photos are included;
- whether OCR text is included;
- whether final grades are included;
- whether draft grades are included;
- whether private teacher notes are included;
- whether source file paths/fingerprints are included;
- destination warning.

---

## 26. Content tests and acceptance criteria

Codex should add tests that enforce this file's content rules when implementing.

### 26.1 Prompt tests

- Prompt includes teacher-final-review language.
- Prompt prohibits effort/intent/demographic/disability inference.
- Prompt requires evidence for every criterion.
- Prompt tells model not to calculate totals.
- Prompt includes OCR warning when OCR summary requires review.
- Prompt includes structured criteria IDs when parsed rubric exists.
- Prompt includes answer key and exemplar only when supplied.

### 26.2 Rubric template tests

- Built-in templates parse into expected criterion counts.
- Built-in template max points sum correctly.
- Built-in template criteria have stable IDs.
- Templates are editable and not treated as official standards.
- Template instructions include evidence and teacher-review safeguards.

### 26.3 Validator tests

- Missing rubric blocks draft.
- Missing reviewed text blocks draft.
- OCR `needsReview` blocks draft.
- OCR `blocked` blocks draft.
- Missing evidence marks teacher review required.
- Missing structured criterion rejects draft.
- Duplicate structured criterion rejects draft.
- Proposed points above max are clamped and flagged.
- Prohibited inferences are flagged or rejected.
- Final totals use teacher-final points, not proposed points.

### 26.4 Export tests

- Student report excludes private teacher notes.
- Student report excludes raw model response.
- Teacher audit includes private teacher notes.
- Teacher audit includes OCR status.
- Teacher audit includes packet fingerprint.
- CSV prefers final approved totals over draft totals.
- CSV neutralizes formula-like strings.
- Student-facing export is blocked when final review is missing or stale unless explicitly preview-only.
- Archive export cannot proceed without inventory warning.

### 26.5 UI string tests

- No visible button says `Auto-grade`.
- No visible button says `Accept AI Grade`.
- Draft generation button uses `Draft` or `Suggestion` language.
- Final approval button refers to teacher approval.
- Local AI unavailable state says there is no cloud fallback.
- OCR review required state explains that grading is blocked.
- Export warnings state what data is included and what changes after export.

### 26.6 Anti-fake-state tests

- PDF export UI is hidden or disabled until PDF export actually works.
- ZIP/archive export UI is hidden or disabled until archive writing actually works.
- Source-image evidence links are not claimed until bounding-box references are implemented.
- Official curriculum import is not claimed until actual import exists.
- Foundation Models availability is checked before enabling local AI draft generation.
- Manual grading path remains available when local AI is unavailable.

---

## 27. Codex implementation instructions

When applying this spec, Codex should:

1. Add this file first as the content source of truth.
2. Do not rewrite this file casually during code implementation.
3. Convert built-in rubrics into Swift seed data only after preserving the wording here.
4. Convert UI strings into a typed string catalog or constants if useful.
5. Convert warning copy into reusable modal definitions.
6. Convert schemas into Swift structs only where needed by actual implementation.
7. Add tests that enforce the product rules and forbidden copy.
8. Prefer hiding unavailable features over adding placeholder UI.
9. Keep student-facing and teacher-only content separate at the model, UI, and export layers.
10. Keep draft and final scoring separate.
11. Keep model output validation strict.
12. Keep local-only privacy promises aligned with actual data flows.
13. If a source-material recommendation conflicts with a current implemented limitation, document the limitation and avoid fake readiness.
14. If Apple SDK reality differs from this spec, update implementation to fail openly and update docs before exposing the feature.

### 27.1 Immediate implementation priority from this content file

The next implementation pass should use this file to do the following, in order:

1. Add or update built-in rubric templates.
2. Replace unsafe/ambiguous UI copy with the canonical strings above.
3. Add missing readiness and export warnings.
4. Add prompt-builder tests against the canonical prompt rules.
5. Add model-output validation tests for evidence, prohibited inferences, missing criteria, and totals.
6. Add report-template tests proving student/audit separation.
7. Add CSV tests proving final-total preference and formula-injection hardening.
8. Hide or disable PDF and archive export until real implementations exist.
9. Add a typed `GradingPacket` so fingerprinting covers every prompt-affecting field.
10. Add OCR review UI copy and states needed for side-by-side review.

---

## 28. Final product boundary

The defensible MVP is not "an AI grader." It is:

> a local-first teacher workspace that drafts rubric-linked, evidence-cited grading suggestions from teacher-confirmed text, flags uncertainty, and requires teacher final approval.

Everything in the app should reinforce that boundary.
