import Foundation

// MARK: - Built-in rubric templates

/// Source: docs/GRADING_CONTENT_SOURCE_OF_TRUTH.md, Section 6.
/// These templates are editable starting points, not official standards.
enum RubricTemplateCatalog {
    static let builtIn: [RubricTemplate] = [
        RubricTemplate(
            id: "short-answer-4pt",
            name: "4-point short answer",
            assignmentType: .shortAnswer,
            assessmentPurpose: .summative,
            description: "Fast rubric for constructed responses and exit tickets.",
            rubricText: #"""
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
"""#,
            customInstructions: #"""
Do not penalize spelling, grammar, or handwriting unless they materially interfere with meaning. Award equivalent wording when the meaning is correct. Cite the reviewed student text for each criterion or mark teacher review required.
"""#
        ),
        RubricTemplate(
            id: "paragraph-response-8pt",
            name: "8-point paragraph response",
            assignmentType: .paragraphResponse,
            assessmentPurpose: .summative,
            description: "Claim, evidence, reasoning, and clarity for one-paragraph responses.",
            rubricText: #"""
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
"""#,
            customInstructions: #"""
Keep feedback specific and actionable. Do not invent missing evidence. If OCR quality is uncertain, flag teacher review. Do not make claims about student effort, ability, or intent.
"""#
        ),
        RubricTemplate(
            id: "essay-20pt",
            name: "20-point essay",
            assignmentType: .essay,
            assessmentPurpose: .summative,
            description: "General essay rubric for claim, structure, evidence, analysis, and conventions.",
            rubricText: #"""
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
"""#,
            customInstructions: #"""
Use the rubric criteria exactly. The draft grade must cite text evidence for each criterion. Do not reward length alone. Do not infer effort, ability, or intent. Mark teacher review required when evidence is missing or when the rubric descriptor is ambiguous.
"""#
        ),
        RubricTemplate(
            id: "lab-writeup-16pt",
            name: "16-point lab write-up",
            assignmentType: .labWriteup,
            assessmentPurpose: .summative,
            description: "For written science reports, lab reflections, and conclusions.",
            rubricText: #"""
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
"""#,
            customInstructions: #"""
Grade only the written content provided. Do not infer experimental performance beyond the text. Flag missing data, unclear vocabulary, diagram dependence, or unsupported scientific claims for teacher review.
"""#
        ),
        RubricTemplate(
            id: "reading-comprehension-10pt",
            name: "10-point reading comprehension response",
            assignmentType: .readingComprehension,
            assessmentPurpose: .summative,
            description: "For text-based responses to a reading prompt.",
            rubricText: #"""
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
"""#,
            customInstructions: #"""
Use only the reviewed student response and the supplied answer key or prompt. If the student refers to text evidence that is not included in the reviewed text, mark teacher review required rather than assuming the reference is correct.
"""#
        ),
        RubricTemplate(
            id: "science-explanation-12pt",
            name: "12-point science explanation",
            assignmentType: .shortAnswer,
            assessmentPurpose: .summative,
            description: "For written scientific explanations using concepts, evidence, and reasoning.",
            rubricText: #"""
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
"""#,
            customInstructions: #"""
Do not grade diagrams, tables, equations, or experimental setup unless the relevant information appears in the reviewed text or was entered by the teacher. Flag any missing data, diagram dependence, or uncertain vocabulary for teacher review.
"""#
        ),
        RubricTemplate(
            id: "hass-source-response-12pt",
            name: "12-point HASS source response",
            assignmentType: .paragraphResponse,
            assessmentPurpose: .summative,
            description: "For history, geography, civics, economics, and source-based written responses.",
            rubricText: #"""
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
"""#,
            customInstructions: #"""
Do not assume source facts that are not in the reviewed student response, prompt, answer key, or teacher-provided context. Mark teacher review required when the response depends on a source excerpt not included in the grading packet.
"""#
        ),
        RubricTemplate(
            id: "formative-exit-ticket-8pt",
            name: "8-point formative exit ticket",
            assignmentType: .shortAnswer,
            assessmentPurpose: .formative,
            description: "Evidence and next-step feedback for quick formative checks.",
            rubricText: #"""
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
"""#,
            customInstructions: #"""
This is formative. Emphasize what the student appears to understand from the evidence and one concrete next step. Do not present the output as a final summative grade by default.
"""#
        ),
        RubricTemplate(
            id: "reflection-response-12pt",
            name: "12-point reflection response",
            assignmentType: .paragraphResponse,
            assessmentPurpose: .summative,
            description: "For written learning reflections and task reflections.",
            rubricText: #"""
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
"""#,
            customInstructions: #"""
Assess only the written reflection. Do not infer effort, attitude, motivation, or personality. Feedback should be supportive, specific, and focused on the evidence in the response.
"""#
        )
    ]

    static func template(id: String) -> RubricTemplate? {
        builtIn.first { $0.id == id }
    }
}

extension RubricTemplates {
    /// Compatibility shim for the planned content module. During integration, replace the current
    /// hardcoded RubricTemplates.builtIn implementation with RubricTemplateCatalog.builtIn.
    static var contentCatalogBuiltIn: [RubricTemplate] { RubricTemplateCatalog.builtIn }
}
