# 08 — Data model and schema implications

## 1. Core entities

```text
TeacherProfile
SchoolContext
ClassGroup
Student
Assignment
CurriculumReference
Rubric
RubricCriterion
RubricLevel
TeacherInstruction
AnswerKey
Exemplar
Submission
SourceInput
OCRRun
OCRSpan
ReviewedText
GradingPacket
GradeProposal
CriterionProposal
TeacherReview
FinalCriterionScore
FinalFeedback
ExportRecord
AuditEvent
```

## 2. Curriculum reference object

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
    "crossCurriculumPriorities": []
  }
}
```

## 3. Grading packet

```json
{
  "gradingPacket": {
    "assignment": {
      "title": "Open response: persuasive paragraph",
      "jurisdiction": "NSW",
      "sector": "Government",
      "learningArea": "English",
      "yearLevel": "Year 6",
      "taskType": "open_question"
    },
    "curriculumReference": {
      "version": "Australian Curriculum Version 9.0",
      "contentDescriptions": [],
      "achievementStandardAspects": []
    },
    "rubric": {
      "criteria": [
        {
          "criterionId": "claim",
          "name": "Claim",
          "maxPoints": 4,
          "description": "Clear position relevant to the task.",
          "requiredEvidenceCount": 1
        }
      ]
    },
    "teacherInstructions": [
      "Assess content and reasoning. Do not penalise spelling unless meaning is unclear."
    ],
    "studentEvidence": {
      "reviewedText": "Teacher-confirmed student text.",
      "ocrWarnings": [],
      "sourceRefs": []
    },
    "outputRules": {
      "citeEvidenceForEveryCriterion": true,
      "teacherFinalReviewRequired": true,
      "doNotInferStudentTraits": true,
      "calculateTotalsInApp": true
    }
  }
}
```

## 4. Proposed criterion output

```json
{
  "criterionProposal": {
    "criterionId": "claim",
    "proposedPoints": 3,
    "maxPoints": 4,
    "ratingLabel": "Proficient",
    "evidenceQuotes": [
      {
        "quote": "The student states...",
        "sourceRef": "ocr-span-id-or-reviewed-text-offset"
      }
    ],
    "explanation": "The response presents a clear claim, though qualification is limited.",
    "nextStep": "Make the claim more precise by naming the specific reason.",
    "confidence": "medium",
    "teacherReviewRequired": false,
    "uncertaintyFlags": []
  }
}
```

## 5. Diversity and adjustment object

```json
{
  "teacherProvidedAdjustmentContext": {
    "hasTeacherNotes": true,
    "notesArePrivate": true,
    "studentFacing": false,
    "languageAssessmentMode": "content_only",
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

## 6. Formative assessment object

```json
{
  "formativeAssessment": {
    "formativeFocus": "recognise and continue repeating patterns",
    "aim": "identify whether students can recognise and continue patterns before introducing the repeating unit",
    "timing": "before teaching",
    "evidenceType": "student response",
    "nextTeachingDecision": "teacher-entered or AI-drafted for teacher review"
  }
}
```

## 7. Export metadata

```json
{
  "exportRecord": {
    "type": "student_report | teacher_audit | csv_gradebook | archive",
    "includesPrivateNotes": false,
    "includesSourceImages": false,
    "createdAt": "ISO-8601",
    "createdBy": "local-teacher-id",
    "jurisdictionWarningShown": true
  }
}
```
