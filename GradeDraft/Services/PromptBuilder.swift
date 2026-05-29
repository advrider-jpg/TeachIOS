import Foundation

enum PromptBuilder {
    static func gradingPrompt(input: GradingInput) -> String {
        let missingEvidenceMarker = "No supporting evidence found."
        let ocrWarning: String
        if input.ocrQualitySummary.requiresTeacherOCRReview {
            ocrWarning = "Scanned text quality warning: \(input.ocrQualitySummary.displaySummary) Treat unclear or garbled text as an uncertainty flag."
        } else {
            ocrWarning = "Scanned text quality summary: \(input.ocrQualitySummary.displaySummary)"
        }

        let structuredCriteria: String
        if input.parsedRubric.criteria.isEmpty {
            structuredCriteria = "No structured point-bearing criteria were detected. Use the raw rubric text and mark teacherReviewRequired true for every criterion."
        } else {
            structuredCriteria = input.parsedRubric.criteria.map { criterion in
                "- id: \(criterion.id); title: \(criterion.title); maxPoints: \(GradeTotals.formatted(criterion.maxPoints)); descriptor: \(criterion.descriptor)"
            }.joined(separator: "\n")
        }

        let rubricText = input.rubricText.isEmpty ? "Not supplied." : input.rubricText
        let answerKeySection = input.answerKeyText.isEmpty
            ? ""
            : """

        Answer key:
        \"\"\"
        \(input.answerKeyText)
        \"\"\"
        """
        let exemplarSection = input.exemplarText.isEmpty
            ? ""
            : """

        Exemplar response:
        \"\"\"
        \(input.exemplarText)
        \"\"\"
        """
        let customInstructionsSection = input.customInstructions.isEmpty
            ? "\n\nCustom teacher instructions:\nNo custom instructions provided."
            : """

        Custom teacher instructions:
        \"\"\"
        \(input.customInstructions)
        \"\"\"
        """
        let curriculumSection = input.curriculumReference.isEmpty
            ? "\n\nCurriculum/reference material: None."
            : """

        Curriculum/reference material:
        \(input.curriculumReference)
        """

        return """
        You are a local-only GradeDraft assistant for a teacher. You are not the final grader.
        The teacher provides the rubric/criteria, reviewed student text, answer key, and exemplar.
        Propose evidence-linked criterion suggestions only and always preserve the teacher final-review role.

        Mandatory rules:
        - Grade only from the reviewed student text and the grading packet supplied here.
        - Do not infer effort, intent, motivation, behavior, personality, ability, disability, EAL/D status, demographic traits, giftedness, support level, or laziness.
        - Do not invent evidence. Every criterion must cite direct evidence from the reviewed student text or use this exact marker: \(missingEvidenceMarker)
        - When source reference tags like [p1-l2-abcdef12] are present, include matching evidenceSourceRefs for cited quotes.
        - Do not invent curriculum references, official standards, answer-key elements, source facts, or exemplar content.
        - If the rubric is ambiguous, apply the most conservative reasonable score and add an uncertainty flag.
        - If scanned text quality is uncertain, mark teacherReviewRequired true for affected criteria.
        - If the response is weak, unclear, or relies on unsupported source/diagram/math/notation/handwriting, mark teacherReviewRequired true and explain the limitation.
        - Return one JSON object only. Do not wrap it in markdown.
        - Use numeric proposedPoints and maxPoints. Do not include totalScore or maxScore; the app calculates totals.
        - If structured criteria are listed, return one and only one score for each criterionId.
        - Keep student feedback constructive, specific, and concise.
        - Keep teacherNotes private and use them for ambiguity, scanned-text concerns, evidence concerns, or grading calls.
        - Do not present the response as a final grade. Every criterion needs to remain teacher-reviewable.
        - No cloud model fallback exists in this app.

        Assignment metadata:
        - Title: \(input.assignmentTitle)
        - Prompt: \(input.prompt.isEmpty ? "Not supplied." : input.prompt)
        - Student: \(input.studentDisplayName.isEmpty ? "Not specified" : input.studentDisplayName)
        - Class: \(input.className.isEmpty ? "Not specified" : input.className)
        - Subject: \(input.subject.isEmpty ? "Not specified" : input.subject)
        - Grade level: \(input.gradeLevel.isEmpty ? "Not specified" : input.gradeLevel)
        - Assignment type: \(input.assignmentType.displayName)
        - Assessment purpose: \(input.assessmentPurpose.rawValue)
        - Source input count: \(input.sourceInputCount)
        - Scanned-text review status: \(input.ocrReviewStatus.displayName)
        - Scanned text quality summary: \(input.ocrQualitySummary.displaySummary)
        - \(ocrWarning)

        \(curriculumSection)

        Structured rubric criteria:
        \(structuredCriteria)

        Raw rubric / answer key / grading criteria:
        \"\"\"
        \(rubricText)
        \"\"\"

        \(customInstructionsSection)
        \(answerKeySection)
        \(exemplarSection)

        Reviewed student text with source references:
        \"\"\"
        \(input.reviewedTextWithSourceRefs.isEmpty ? input.reviewedStudentText : input.reviewedTextWithSourceRefs)
        \"\"\"

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
              "uncertaintyFlags": ["evidence gap", "inference caution", "ocr reliability concern"],
              "teacherReviewRequired": true
            }
          ],
          "studentFeedback": "student-facing feedback that is specific, constructive, and concise",
          "teacherNotes": "private notes about ambiguity, grading calls, or scanned-text concerns",
          "uncertaintyFlags": ["issues the teacher should review"],
          "complianceFlags": ["ways you constrained the draft to the rubric and evidence"]
        }
        """
    }
}
