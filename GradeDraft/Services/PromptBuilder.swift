import Foundation

enum PromptBuilder {
    static func gradingPrompt(input: GradingInput) -> String {
        let ocrWarning: String
        if input.ocrQualitySummary.requiresTeacherOCRReview {
            ocrWarning = "OCR quality warning: \(input.ocrQualitySummary.displaySummary) Treat unclear or garbled text as an uncertainty flag."
        } else {
            ocrWarning = "OCR quality summary: \(input.ocrQualitySummary.displaySummary)"
        }

        let structuredCriteria: String
        if input.parsedRubric.criteria.isEmpty {
            structuredCriteria = "No structured point-bearing criteria were detected. Use the raw rubric text and mark teacherReviewRequired true for every criterion."
        } else {
            structuredCriteria = input.parsedRubric.criteria.map { criterion in
                "- id: \(criterion.id); title: \(criterion.title); maxPoints: \(GradeTotals.formatted(criterion.maxPoints)); descriptor: \(criterion.descriptor)"
            }.joined(separator: "\n")
        }

        return """
        You are a local-only rubric grading assistant for a teacher. You are not the final grader. The teacher will review and may edit every score.

        Mandatory rules:
        - Grade only from the reviewed student text below, the rubric, the answer key/exemplar if supplied, and the custom instructions.
        - Do not infer effort, intent, ability, demographics, disability, or behavior from the text.
        - Do not invent evidence. Every criterion must cite direct evidence from the reviewed student text or state that evidence is missing.
        - If the rubric is ambiguous, apply the most conservative reasonable score and add an uncertainty flag.
        - If OCR quality or wording is uncertain, mark teacherReviewRequired true for affected criteria.
        - Return one JSON object only. Do not wrap it in markdown.
        - Use numeric proposedPoints and maxPoints. Do not include totalScore or maxScore; the app calculates totals.
        - If structured criteria are listed, return one and only one score for each criterionId.

        Assignment metadata:
        - Title: \(input.assignmentTitle)
        - Student: \(input.studentDisplayName.isEmpty ? "Not specified" : input.studentDisplayName)
        - Class: \(input.className.isEmpty ? "Not specified" : input.className)
        - Subject: \(input.subject.isEmpty ? "Not specified" : input.subject)
        - Grade level: \(input.gradeLevel.isEmpty ? "Not specified" : input.gradeLevel)
        - Assignment type: \(input.assignmentType.displayName)
        - Source input count: \(input.sourceInputCount)
        - OCR review status: \(input.ocrReviewStatus.displayName)
        - \(ocrWarning)

        Structured rubric criteria:
        \(structuredCriteria)

        Raw rubric / answer key / grading criteria:
        \"\"\"
        \(input.rubricText)
        \"\"\"

        Custom teacher instructions:
        \"\"\"
        \(input.customInstructions.isEmpty ? "None." : input.customInstructions)
        \"\"\"

        Answer key:
        \"\"\"
        \(input.answerKeyText.isEmpty ? "None." : input.answerKeyText)
        \"\"\"

        Exemplar response:
        \"\"\"
        \(input.exemplarText.isEmpty ? "None." : input.exemplarText)
        \"\"\"

        Reviewed student text:
        \"\"\"
        \(input.reviewedStudentText)
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
              "evidence": ["quote or close paraphrase from reviewed student text, or 'No supporting evidence found.'"],
              "evidenceSourceRefs": [],
              "explanation": "specific rubric-based explanation",
              "teacherReviewRequired": true
            }
          ],
          "studentFeedback": "student-facing feedback that is specific, constructive, and concise",
          "teacherNotes": "private notes about ambiguity, grading calls, or OCR concerns",
          "uncertaintyFlags": ["issues the teacher should review"],
          "complianceFlags": ["ways you constrained the draft to the rubric and evidence"]
        }
        """
    }
}
