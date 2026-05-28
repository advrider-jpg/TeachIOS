# 04 — Student diversity, adjustments, and grading safety

## 1. Diversity principle

The student diversity page states that students come from different social, cultural, community and family backgrounds and have a wide range of abilities and experiences. The curriculum supports inclusive teaching and learning programs and equitable access.

### Product implication

The app must not treat student work as enough evidence to infer a student’s ability, disability, language background, cultural background, effort, intent, behaviour, or support needs.

The model prompt and validator should include a hard rule:

```text
Do not infer disability, English proficiency, giftedness, effort, motivation, intent, behaviour, demographic traits, home support, or degree of teacher support from the student work. Only comment on observable features of the submitted evidence and the teacher-provided rubric/instructions.
```

## 2. CASE model

The planning-for-diversity page recommends the CASE model:

- Curriculum;
- Abilities;
- Standards;
- Evaluation.

### App use

The app can include optional teacher-controlled adjustment metadata, but must not infer it.

```json
{
  "adjustmentContext": {
    "teacherProvided": true,
    "notes": "Teacher-entered only",
    "mustNotBeInferredByModel": true,
    "visibleInStudentReport": false
  }
}
```

## 3. Students with disability

The disability page emphasises access on the same basis, consultation with students/parents/carers, and reasonable adjustments. It notes that adjustments can relate to content, process, products, and learning environment.

### Product requirements

- Add an optional “teacher-provided adjustment notes” field.
- Keep adjustment notes out of student-facing exports unless explicitly included.
- Do not ask the model to diagnose or infer disability.
- Do not penalise accessibility-related differences unless the rubric/teacher explicitly requires a criterion and the evidence supports it.
- Keep assessment accommodations teacher-controlled.

## 4. Gifted and talented students

The gifted/talented page emphasises rigorous, relevant, engaging opportunities, individual strengths/interests/goals, and adjustments above year-level expectations where appropriate. It also says pre-assessment and ongoing formative assessment are critical.

### Product implications

- Support extension rubrics and above-year-level criteria as teacher-selected options.
- Do not infer giftedness from performance.
- Support independent project assessment only with teacher-confirmed criteria and evidence.

## 5. EAL/D students

The EAL/D page is extremely important for grading design. It notes that EAL/D students are learning Standard Australian English and curriculum content simultaneously, and that language proficiency directly impacts achievement across learning areas. It recommends distinguishing content knowledge from language demands and using differentiated assessment where appropriate.

### Product implications

The app should support teacher-controlled settings such as:

```json
{
  "languageAssessmentMode": {
    "mode": "content_only | language_and_content | teacher_custom",
    "spellingPenalty": "none | meaning_only | rubric_specific",
    "grammarPenalty": "none | meaning_only | rubric_specific",
    "ealdConsiderations": "teacher_entered_only"
  }
}
```

## 6. EAL/D grading cautions

The app must:

- not infer EAL/D status;
- not equate language errors with content misunderstanding unless the rubric says so;
- allow teachers to assess content knowledge separately from SAE proficiency;
- allow visual/drawn evidence in future modes where teacher-confirmed;
- flag when feedback may be language-demand heavy;
- support simple-language feedback drafts when teacher requests.

## 7. Inclusive feedback requirements

Student-facing feedback should be:

- specific;
- evidence-linked;
- actionable;
- respectful;
- focused on the work, not the student’s traits;
- capable of being simplified by the teacher;
- capable of being adjusted for EAL/D or accessibility needs by the teacher.

## 8. Safety validator rules

The grading validator should reject or flag any model output that includes phrases such as:

- “the student is lazy”;
- “the student has a disability”;
- “the student is gifted”;
- “the student did not try”;
- “the student probably had help”;
- “English is not their first language”;
- “low ability”;
- “behaviour issue”;
- demographic, cultural, disability, language-background assumptions.

The app should permit only observable evidence and teacher-provided context.
