# 02 — Assessment, reporting, and work samples

## 1. Planning, teaching, assessing and reporting

The planning/assessment guidance is one of the most important sources for the app.

The relevant model is:

```text
content descriptions → teaching and learning program → evidence of learning → achievement standards → judgement/reporting
```

Teachers use content descriptions to identify what is to be taught and achievement standards to understand the expected standard of learning. Optional elaborations provide teaching suggestions. Annotated work samples help teachers judge the extent to which achievement standards are met.

## 2. Achievement standards

Achievement standards are used to:

- monitor student learning;
- make judgements about progress and achievement;
- make on-balance judgements at the end of a teaching period;
- report to parents/carers;
- provide a common reference point.

### Product implications

The app should:

1. support achievement-standard-linked rubrics;
2. treat the achievement standard as the reference point, not as a mechanical answer key;
3. include “on-balance teacher judgement” language;
4. allow teachers to override AI suggestions;
5. preserve the teacher’s final judgement separately from AI output;
6. record why a teacher changed a proposed score if the teacher chooses to add a note.

## 3. State and territory reporting differences

The website says state and territory school/curriculum authorities and schools determine reporting style and format, in consultation with local communities and national requirements.

### Product implications

The Australian MVP must not hard-code one reporting format. It should support:

- jurisdiction field;
- sector field: government, Catholic, independent, other;
- custom reporting scale;
- local rubric import;
- optional standards alignment;
- local export templates.

Recommended initial setting:

```json
{
  "schoolContext": {
    "jurisdiction": "NSW | VIC | QLD | WA | SA | TAS | ACT | NT | Not specified",
    "sector": "Government | Catholic | Independent | Other | Not specified",
    "reportingPolicySource": "teacher_configured"
  }
}
```

## 4. Work samples

The work-samples page is highly relevant. Work sample collections demonstrate evidence of student learning in relation to aspects of achievement standards. They are selected, annotated, and reviewed by classroom teachers and curriculum experts. Unless stated otherwise, they are “At” standard.

The page also says the primary purpose is to demonstrate the standard, so the focus is on what is evident in the sample, not how it was created. It says samples may not address every aspect of an achievement standard and may contain spelling mistakes or inaccuracies.

## 5. Work sample implications for AI grading

This strongly supports the app’s evidence-first model.

The app should follow the same discipline:

- focus on what is evident in the submitted work;
- do not infer time taken;
- do not infer degree of teacher support;
- do not infer effort;
- do not infer student intent;
- do not assume a sample covers every aspect of the achievement standard;
- tolerate spelling mistakes when they are not relevant to the rubric;
- separate student opinions from app/teacher endorsement;
- cite evidence for every proposed criterion judgement.

## 6. Work sample data object

```json
{
  "referenceWorkSample": {
    "id": "official-or-teacher-created-id",
    "source": "ACARA | teacher | school | jurisdiction",
    "learningArea": "English",
    "yearLevel": "Year 5",
    "standardLevel": "At standard",
    "achievementStandardAspects": [],
    "annotationNotes": [],
    "copyrightStatus": "external_reference_only"
  }
}
```

## 7. App requirements derived from assessment/reporting guidance

| Requirement | Rationale |
|---|---|
| Teacher final approval required | Achievement judgement is professional and local-policy governed. |
| Criterion-level evidence required | Work samples model standard judgement from evidence. |
| No effort/support inference | ACARA work samples focus on what is evident, not creation conditions. |
| Configurable jurisdiction/reporting context | States/territories determine reporting requirements. |
| Audit trail | Teacher may need to distinguish AI suggestion from final judgement. |
| Separate student and teacher exports | Student feedback differs from professional audit notes. |
