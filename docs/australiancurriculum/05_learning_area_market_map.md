# 05 — Learning-area market map for the Australian teacher app

## 1. Learning areas and app suitability

| Learning area | MVP suitability | Reason |
|---|---:|---|
| English | Very high | Text responses, writing, reading, evidence, rubric feedback. |
| Humanities and Social Sciences | High | Short answers, source analysis, explanations, inquiry responses. |
| Science | Medium-high | Lab write-ups and explanations work; diagrams/math deferred. |
| Mathematics | Medium | Text explanations work; equations/working/math notation require later support. |
| Technologies | Medium | Written design reflections work; code/design artifacts require later modes. |
| Health and Physical Education | Medium | Reflections and written explanations work; sensitive topics need caution. |
| The Arts | Low-medium | Artist statements/reflections work; performance/artwork assessment needs visual/teacher evidence. |
| Languages | Low-medium | Requires language-specific support and teacher expertise; avoid early automated scoring. |

## 2. MVP target subjects

The strongest Australian MVP should focus on:

1. English writing and reading responses.
2. HASS short-answer/inquiry responses.
3. Science written explanations and lab reflections.
4. General formative exit tickets/open questions across subjects.

## 3. Explicitly deferred modes

| Mode | Reason for deferral |
|---|---|
| Full mathematics working | OCR/math notation and reasoning risk. |
| Diagrams and labels | Requires visual region evidence and teacher confirmation. |
| Concept maps | Requires spatial/relationship interpretation. |
| Posters/physical models | Requires multimodal evidence and subjective judgement safeguards. |
| Languages writing | Requires language-specific grammar/orthography expertise. |
| Performing arts | Requires video/audio/performance evidence and teacher judgement. |
| Senior secondary high-stakes assessment | Jurisdiction-specific rules and high-stakes consequences. |

## 4. Learning-area schema

```json
{
  "assignment": {
    "learningArea": "English",
    "subject": "English",
    "yearLevel": "Year 7",
    "taskType": "open_question | essay | short_answer | lab_writeup | reflection",
    "curriculumReferences": {
      "contentDescriptions": [],
      "achievementStandardAspects": [],
      "generalCapabilities": [],
      "crossCurriculumPriorities": []
    }
  }
}
```

## 5. Product mode recommendations

### Mode 1 — Open response

Best for English, HASS, Science, HPE, Technologies.

Inputs:

- prompt;
- student response;
- rubric or achievement-standard aspect;
- optional answer key/exemplar.

Outputs:

- criterion suggestions;
- evidence quotes;
- next steps.

### Mode 2 — Writing rubric

Best for English.

Inputs:

- writing type;
- rubric criteria;
- student response;
- teacher instructions.

Outputs:

- claim/structure/evidence/language feedback;
- teacher-editable score.

### Mode 3 — Explanation checker

Best for Science/HASS.

Inputs:

- key concepts;
- answer key;
- student explanation.

Outputs:

- concept coverage;
- misconceptions;
- evidence-backed feedback.

### Mode 4 — Formative exit ticket

Best across subjects.

Inputs:

- content description;
- formative focus;
- expected evidence.

Outputs:

- demonstrated / not yet demonstrated;
- misconception flags;
- next teaching step suggestions.

## 6. Default rubrics to include

- Short answer: accuracy, evidence, explanation, clarity.
- Constructed response: claim, evidence, reasoning, curriculum vocabulary.
- Writing: ideas, structure, language choices, conventions, audience/purpose.
- Science explanation: concept understanding, use of evidence/data, scientific vocabulary, reasoning.
- HASS source response: source understanding, evidence, historical/geographical/civic reasoning, communication.
- Reflection: connection to task, explanation of learning, specificity, next steps.

All templates must be editable and locally stored.
