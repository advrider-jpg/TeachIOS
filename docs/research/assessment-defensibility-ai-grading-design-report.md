# Defensibility & Assessment-Design Report

*Rubric-Assisted, Teacher-Controlled AI Grading App*

---

## Executive Summary

AI can meaningfully support grading when it is designed as a **partner to teachers**, not a replacement. Research shows that automated scoring and AI-generated feedback can:

- Produce **reliable suggestions** for well-defined, analytic criteria.
- Improve efficiency when anchored to **explicit rubrics** and **verbatim evidence**.
- Increase consistency on discrete traits like organization and conventions.

However, models also carry **risks**: they may miss deeper reasoning, reward surface features, or exhibit bias without careful design. Therefore, a defensible system must:

- Treat all AI output as *preliminary suggestions* requiring teacher review.
- Anchor every criterion suggestion to **verbatim student evidence**.
- Signal **uncertainty and weak evidence** clearly.
- Avoid claims of autonomy, inference of non-textual traits, or predictive ability beyond the submission.

This report synthesizes research and responsible AI practices into specific product requirements.

---

## 1. Research on Automated Scoring & AI Feedback

### Automated Essay & Short-Answer Scoring (AES)

AES has decades of research showing that:

- When scoring analytic criteria (e.g., clarity of thesis, evidence use), automated systems can align with human raters under controlled conditions.
- Performance declines when rubrics are vague or when constructs are holistic and require contextual understanding.
- Correlation with human scores does *not* guarantee validity — AES can rely on superficial cues like text length or lexical features.

**Implication:** The system must be constrained to *observable text evidence* tied directly to rubric performance descriptors.

---

### AI-Generated Feedback

AI feedback can be helpful but varies in quality:

- Generic feedback is common without rubric grounding.
- Feedback aligned to specific rubric criteria and paired with text examples is more pedagogically useful.
- Teacher involvement improves clarity and relevance of feedback.

**Best practice:** AI should *generate draft feedback anchored in rubric terms and teacher guidelines*, with teacher editing integral to final feedback.

---

### Teacher-In-The-Loop Systems

Studies emphasize that teachers:

- Prefer AI as an **assistant**, not an authority.
- Value interfaces that surface AI suggestions alongside evidence and uncertainty.
- Express concern about “automation bias” unless output is transparent and editable.

Teacher review must be built *into the workflow by design*.

---

## 2. Assessment Validity & Reliability

### Validity

Validity means scores align with intended learning constructs. Risks to validity include:

- Misinterpreting text due to ambiguous rubrics.
- AI rewarding surface features unrelated to construct mastery.
- Overgeneralizing rubric criteria.

**Defensible practice:** Only score what can be *observed and justified* in the text; do not infer ability beyond the work.

---

### Reliability

AI systems can enhance consistency for routine criteria, but:

- LLM outputs can vary with prompt phrasing or model updates.
- Reliability must be tested across content types and rubric structures.

**Requirement:** Versioned prompts and evaluation against human consensus benchmarks.

---

## 3. Bias, Fairness & Transparency

### Bias & Fairness

Automated systems may behave differently across language backgrounds, genres, or subgroups when not carefully monitored. Responsible design includes:

- Monitoring outputs for subgroup disparities.
- Avoiding use of sensitive or inferred traits.
- Reporting uncertainty, especially where evidence is weak.

Bias mitigation is ongoing and requires *audits with real classroom data*.

---

### Transparency

Teachers and students need to understand *why* a suggestion was made:

- Link evidence excerpts to rubric descriptors.
- Show how suggestions align with criteria.
- Include confidence indicators.

Transparency supports trust and teacher discernment.

---

## 4. Product Design to Reduce Over-Trust

Automation bias (over-reliance on AI output) is a documented risk. Mitigation includes:

- **Active confirmation:** Teachers must explicitly approve each criterion score.
- **Confidence bands:** Highlight low-confidence suggestions for closer review.
- **Evidence flags:** Mark where evidence is missing or ambiguous.
- **Editable rubrics:** Teachers refine criteria before scoring.

The interface should communicate that AI output is a **draft requiring judgment**.

---

## 5. Handling Uncertainty & OCR Errors

The system must differentiate between:

### Rubric Ambiguity

When descriptors are vague, prompt teachers to clarify or expand rubric definitions before scoring.

### Weak or Missing Evidence

Do not assign scores when evidence is insufficient — flag and require teacher decision.

### Conflicting Instructions

Pause automated scoring and require clarification when curriculum guidance contradicts rubric intent.

### OCR Uncertainty

For scanned/photographed text, integrate OCR confidence scores; low confidence must lead to human verification before evidence extraction.

These checks prevent hallucination and unsupported scoring.

---

## 6. Prohibited Inferences

The app must *never* infer or claim to infer:

- Student effort, intention, or engagement.
- Motivation or personality traits.
- Disability or special education status.
- Demographic characteristics.
- Ability beyond the content of submitted work.

Non-textual constructs cannot be validated through text alone and have no defensible evidence basis.

---

## 7. MVP Assignment Use Cases

The MVP should focus on text formats where rubric alignment and evidence extraction are feasible:

- **Short answers** with clear, discrete criteria.
- **Constructed responses** tied to explicit expectations.
- **Paragraphs and essays** with analytic rubrics (e.g., claim, evidence, reasoning).
- **Discipline-specific analytic writing** where performance descriptors are well defined.

These formats balance instructional relevance with feasibility for evidence-anchored AI suggestions.

---

## 8. Deferred or High-Risk Use Cases

The system should *not* attempt AI suggestions for:

- **Math problem solving** requiring symbolic reasoning or notation.
- **Handwritten work** without reliable OCR.
- **Visual, multimodal artifacts** (diagrams, posters).
- **Creativity, craftsmanship, aesthetics**, or products without clear rubric criteria.
- **Effort or participation scoring**, which rely on contextual judgment outside the text.

These domains demand human insight beyond the reach of current text-based AI.

---

## 9. Defensible Grading Output Schema

A defensible schema should include:

1. **Criterion Name & Description**
2. **AI Suggested Score Range**
3. **Verbatim Evidence Excerpts**
4. **AI Confidence Indicator**
5. **Rubric Match Strength**
6. **Teacher Final Score & Edits**
7. **Timestamp & Rubric Version**

This preserves auditability and supports clear traceability from evidence to conclusion.

---

## 10. Criterion-Level Explanations

Effective explanations must:

- Quote specific text segments.
- Map evidence clearly to rubric descriptors.
- Distinguish *observation* from *judgment*.
- Use educational language that supports learning.

Example:  
> “The quote on line 3 does not explicitly support the claim because it describes an unrelated event, so criterion X is not met.”

This makes suggestions instructive and interpretable.

---

## 11. Rubric Templates for Classroom Use

Include customizable templates for:

- **Argumentation:** claim clarity, evidence quality, reasoning.
- **Expository writing:** coherence, conceptual accuracy.
- **Mechanics & conventions** (where instructional priority).
- **Discipline-specific needs:** history, science explanations.

Templates should be editable and aligned with common standards.

---

## 12. Distinguishing Formative vs. Summative Outputs

- **Formative feedback**: draft suggestions and learning guidance not used for reporting.
- **Summative grading**: teacher-verified final scores suitable for gradebooks or records.

User flows should clearly label outputs to avoid confusion between formative and summative contexts.

---

## 13. Audit Trail Requirements

A robust audit trail must:

- Log AI suggestions with evidence excerpts.
- Capture teacher edits, overrides, and rationales.
- Record rubric versions and scoring contexts.
- Track confidence levels and uncertainty flags.

This supports accountability, compliance, and retrospective analysis.

---

## 14. Preventing Hallucination & Placeholder Outputs

To guard against AI hallucination:

- Extract evidence only from verbatim student text.
- Reject or flag outputs that reference nonexistent material.
- Detect and eliminate placeholder text or generic filler.
- Power checks that ensure every suggestion is justified by evidence.

When evidence is lacking, defer entirely to the teacher.

---

## 15. Teacher Overrides & Control Features

Teachers must be empowered to:

- **Edit or reject AI suggestions** at any point.
- **Adjust rubric criteria and weights** mid-grading.
- **Lock final decisions** so they cannot be altered by regenerated drafts.
- **Regenerate suggestions only after rubric changes.**

Default settings must prioritize teacher authority.

---

## 16. Evaluation & Test Plan

A defensible evaluation framework includes:

- **Inter-rater reliability metrics** (e.g., Quadratic Weighted Kappa) comparing AI suggestions to human consensus.
- **Rubric alignment assessments** checking evidence-criterion matches.
- **Bias audits** across learner subgroups (e.g., language variation).
- **Teacher usability and workload studies**.
- **Student feedback on feedback usefulness.**

These measures provide empirical backing for claims and improvements.

---

## 17. Product Copy & Positioning

Language should emphasize:

- “AI-assisted grading suggestions” requiring teacher confirmation.
- “Rubric-anchored evidence extraction” for every suggestion.
- Transparency about uncertainty indicators.
- Avoidance of terms like “auto-grade” or “replace teachers.”

Messaging must align with responsible AI and educational integrity.

---

## 18. “Do Not Claim” List

The product must not claim:

- Autonomous grading capability.
- Ability to infer student traits beyond text.
- Bias-free outcomes across all contexts.
- Replacement of professional human judgment.
- Predictive validity about student future performance.

These claims are not supported by current research.

---

## Conclusion

A defensible rubric-assisted AI grading system is possible *only* if it:

- Anchors every score and comment to **verifiable text evidence**.
- Keeps **teachers fully in control** of final decisions.
- Surfaces **uncertainty and rubric alignment** explicitly.
- Provides **robust audit trails and evaluation data**.
- Avoids making claims outside the scope of defensible assessment.

When designed this way, the app can enhance teacher efficiency and formative feedback quality without compromising educational integrity or fairness.
