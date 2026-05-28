# 07 — App requirements derived from Australian Curriculum content

## 1. Curriculum-aligned assignment setup

The app must let a teacher configure:

- jurisdiction;
- sector;
- school/class context;
- learning area;
- subject;
- year level or band;
- task type;
- content description or custom focus;
- achievement-standard aspect;
- rubric;
- teacher instructions;
- answer key/exemplar.

## 2. Evidence-first grading

Derived from work samples and formative assessment guidance:

- Every proposed score must cite observable evidence.
- Evidence can be text quote, OCR span, teacher-confirmed visual region in later modes, or teacher-entered observation.
- Evidence must be connected to a criterion.
- If evidence is weak or missing, the app must flag teacher review instead of making a confident judgement.

## 3. Achievement-standard alignment

The app should support:

```json
{
  "achievementStandardAlignment": {
    "standardText": "teacher-provided or official imported",
    "aspectsAssessed": [],
    "onBalanceJudgement": true,
    "teacherFinalJudgementRequired": true
  }
}
```

## 4. Formative mode

The app should include a formative mode:

- formative focus;
- aim;
- timing;
- evidence type;
- next teaching step;
- student feedback.

This mode should focus less on points and more on whether the evidence shows current learning and what comes next.

## 5. Jurisdiction and sector flexibility

Because states, territories, sectors and schools determine implementation and reporting, the app must not assume:

- one grade scale;
- one reporting format;
- one achievement level vocabulary;
- one implementation timeline;
- one curriculum portal;
- one senior-secondary structure.

## 6. Student diversity safeguards

The app must provide:

- teacher-controlled adjustment notes;
- optional content/language assessment mode;
- EAL/D-sensitive feedback settings;
- private teacher notes excluded from student exports;
- validation against trait/inference language.

## 7. Australian spelling and terminology

Defaults should use Australian English:

- achievement standard, not achievement criterion as default official term;
- learning area;
- year level;
- Foundation to Year 10;
- parent/carer;
- Standard Australian English;
- Aboriginal and Torres Strait Islander Histories and Cultures;
- HASS;
- The Arts;
- Technologies.

## 8. Product settings

Suggested settings:

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

## 9. Export requirements

Student report export:

- assignment title;
- learning area/year;
- final score/level if used;
- criterion feedback;
- evidence quotes if teacher wants;
- next steps;
- no private notes.

Teacher audit export:

- source input references;
- OCR status;
- reviewed text;
- rubric;
- AI proposal;
- teacher edits;
- uncertainty flags;
- final judgement;
- private notes;
- export metadata.

## 10. UI requirements

- “Draft suggestion” rather than “Grade automatically”.
- “Teacher final review required”.
- “Evidence missing — review required”.
- “OCR needs review before grading”.
- “Jurisdiction reporting rules may apply”.
- “Content descriptions and achievement standards can be used as references but teachers make final judgements.”
