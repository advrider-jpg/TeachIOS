# 01 — Australian Curriculum structure relevant to the app

## 1. Purpose and audience

The Australian Curriculum sets national expectations for what students should learn and the quality of learning expected through the first 11 years of schooling. The official guidance says the primary audience is teachers and that the curriculum is written in language suitable for professional practitioners.

### Product implication

The app should not position itself as a generic homework checker. It should present itself as a tool for professional teachers who are applying curriculum expectations, achievement standards, rubrics, and local policies.

Recommended app terminology:

- assignment;
- learning area;
- subject;
- year level or band;
- content description;
- achievement standard;
- rubric criterion;
- evidence;
- teacher judgement;
- feedback;
- on-balance judgement.

Avoid consumer-style terminology such as:

- instant mark;
- auto-grade;
- AI-decided result;
- guaranteed standard.

## 2. Three dimensions

The Australian Curriculum has three dimensions:

1. learning areas;
2. general capabilities;
3. cross-curriculum priorities.

Learning areas are the foundation; general capabilities and cross-curriculum priorities are developed through learning-area content rather than as separate grading areas by default.

### App implication

The data model should support three curriculum dimensions separately.

```json
{
  "curriculumAlignment": {
    "learningArea": "English",
    "subject": "English",
    "yearLevel": "Year 6",
    "contentDescriptions": [],
    "achievementStandards": [],
    "generalCapabilities": [],
    "crossCurriculumPriorities": []
  }
}
```

General capabilities and priorities should enrich feedback and rubric design only when explicitly relevant. The app should not invent alignment.

## 3. Core curriculum components

The website identifies these recurring components:

- rationale and aims;
- organisation of content;
- key connections;
- key considerations;
- content descriptions;
- achievement standards;
- level descriptions;
- content elaborations.

### App implication

For grading and feedback, the most important components are:

| Curriculum element | App use |
|---|---|
| Content description | Defines the taught/assessed content and supports formative-focus selection. |
| Achievement standard | Defines expected quality of learning and supports score/rubric judgement. |
| Content elaboration | Provides examples and context, but should not be treated as mandatory assessment criteria. |
| Level description | Useful for teacher planning and rubric template context. |
| General capabilities | Optional alignment/feedback tags when meaningfully connected. |
| Cross-curriculum priorities | Optional alignment/feedback tags when meaningfully connected. |

## 4. Learning areas

The F–10 Australian Curriculum identifies eight learning areas:

1. English.
2. Mathematics.
3. Science.
4. Health and Physical Education.
5. Humanities and Social Sciences (HASS).
6. The Arts.
7. Technologies.
8. Languages.

Several learning areas contain multiple subjects.

### Data model

```json
{
  "learningArea": {
    "id": "english",
    "name": "English",
    "type": "single_subject",
    "subjects": ["English"]
  }
}
```

```json
{
  "learningArea": {
    "id": "hass",
    "name": "Humanities and Social Sciences",
    "type": "multi_subject",
    "subjects": [
      "Civics and Citizenship",
      "Economics and Business",
      "Geography",
      "History"
    ]
  }
}
```

## 5. Version 9.0 changes relevant to product design

Version 9.0 was refined to improve clarity, reduce content, strengthen alignment between content descriptions and achievement standards, and make teacher use easier.

### App implication

The app’s internal product model should mirror that alignment:

```text
content description → learning focus → evidence to collect → achievement standard aspect → rubric criterion → teacher judgement
```

The app should support a workflow where a teacher can select or paste a content description and then build a rubric from the intended learning and the achievement standard.

## 6. Senior secondary

The senior secondary page identifies senior subjects in English, Mathematics, Science, and Humanities and Social Sciences, but links to Version 8.4 resources.

### App implication

Do not make senior-secondary alignment the MVP. Senior secondary assessment is more jurisdiction-specific and often high-stakes. Treat it as a later roadmap item requiring state/territory configuration.
