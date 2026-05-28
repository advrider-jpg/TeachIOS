# 03 — Formative assessment extraction and app implications

## 1. Formative assessment role

The formative assessment pages describe formative assessment as purposeful design plus responsive teaching to support student progress. It is embedded in teaching, gathers manageable evidence, and helps teachers decide what students need next.

### Product implication

The app should initially position itself closer to formative feedback and rubric-assisted review than high-stakes summative grading.

Recommended product mode names:

- Feedback draft;
- Formative evidence review;
- Rubric suggestion;
- Teacher final review.

Avoid:

- Final automatic grade;
- Summative assessor;
- National standard certifier.

## 2. Effective formative assessment

The site emphasises:

- clear purpose;
- alignment with curriculum;
- focus on the specific learning;
- timing in the teaching sequence;
- evidence useful for teaching and learning decisions;
- actionable feedback;
- student reflection and self-regulation.

### App workflow mapping

```text
Teacher selects curriculum/rubric focus
→ Teacher captures student evidence
→ App extracts/reviews evidence
→ App drafts feedback against focus
→ Teacher edits/finalises feedback
→ Teacher uses result to plan next step
```

## 3. Design framework

The formative assessment design framework is built around four components:

1. formative focus;
2. aim;
3. timing;
4. evidence.

### App object

```json
{
  "formativeAssessmentDesign": {
    "formativeFocus": "specific aspect of content description",
    "aim": "what the teacher needs to know",
    "timing": "before teaching | during lesson | after learning | across sequence",
    "evidence": "student written response | exit ticket | diagram | checklist | other"
  }
}
```

## 4. Formative focus

The design page says teachers begin by identifying the aspect of a content description that will be the focus. A formative focus should isolate the thinking students are expected to demonstrate, the learning focus, the key curriculum language, and where students are starting.

### App implications

The app should include a “Define focus” step:

```text
1. Select or paste content description.
2. Highlight action verbs.
3. Identify learning focus nouns/concepts.
4. Confirm prior learning / starting point.
5. Save as the assessment focus.
```

For example, a content description with verbs such as “identify”, “explain”, “compare”, “justify”, or “create” can be parsed into candidate rubric criteria, but the teacher must approve the criteria.

## 5. Assessment types relevant to future features

The formative assessment design page lists practical assessment type categories, including:

- case studies and scenarios;
- checklists;
- comprehension questions;
- concept maps;
- diagnostic questions;
- diagrams and labels;
- graphic organisers;
- multiple-choice questions;
- open questions;
- show thinking.

### App roadmap mapping

| Assessment type | MVP suitability | Notes |
|---|---:|---|
| Open questions | High | Best text-only grading fit. |
| Comprehension questions | High | Good for answer-key + rubric mode. |
| Diagnostic questions | Medium | Useful for formative flags, not final grades. |
| Checklists | Medium | Good teacher-controlled rubric mode. |
| Case studies/scenarios | Medium | Higher context needs. |
| Show thinking | Medium | Works for written reasoning; math/diagram variants deferred. |
| Graphic organisers | Later | Requires layout/OCR support. |
| Concept maps | Later | Requires visual structure interpretation. |
| Diagrams and labels | Later | Requires image-region evidence and teacher confirmation. |
| Multiple-choice | Not core | Could be implemented deterministically, but less differentiated. |

## 6. Embedding formative assessment

The embedding page identifies a five-step process:

1. plan formative assessment;
2. design formative assessment;
3. collect evidence;
4. analyse and interpret evidence;
5. make responsive teaching decisions.

### App screens

| Step | App screen |
|---|---|
| Plan | Assignment/rubric/curriculum focus setup. |
| Design | Assessment type and evidence requirement setup. |
| Collect evidence | Scan/import/paste student work. |
| Analyse evidence | OCR review + proposed grading. |
| Respond | Feedback, next steps, teacher notes, group insights. |

## 7. Product safety implications

The app should state that feedback suggestions are intended to help teachers make decisions, not replace teacher judgement. It should support next-step feedback and instructional notes rather than only points.

A useful criterion output should include:

```json
{
  "criterionId": "evidence",
  "whatWasShown": "Student used two relevant examples.",
  "nextStep": "Explain how each example supports the claim.",
  "teacherReviewRequired": false
}
```
