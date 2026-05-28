import CoreGraphics
import Foundation

struct AssignmentRecord: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var subject: String
    var gradeLevel: String
    var assignmentType: AssignmentType
    var rubricText: String
    var customInstructions: String
    var reviewedStudentText: String
    var ocrDocument: OCRDocument?
    var latestDraft: GradeDraftResult?
    var finalReview: FinalGradeReview?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "New Assignment",
        subject: String = "",
        gradeLevel: String = "",
        assignmentType: AssignmentType = .shortAnswer,
        rubricText: String = "",
        customInstructions: String = "",
        reviewedStudentText: String = "",
        ocrDocument: OCRDocument? = nil,
        latestDraft: GradeDraftResult? = nil,
        finalReview: FinalGradeReview? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.subject = subject
        self.gradeLevel = gradeLevel
        self.assignmentType = assignmentType
        self.rubricText = rubricText
        self.customInstructions = customInstructions
        self.reviewedStudentText = reviewedStudentText
        self.ocrDocument = ocrDocument
        self.latestDraft = latestDraft
        self.finalReview = finalReview
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var assignmentInputReady: Bool {
        gradingInput.isReadyForGrading
    }

    var gradingInput: GradingInput {
        GradingInput(
            assignmentTitle: title,
            subject: subject,
            gradeLevel: gradeLevel,
            assignmentType: assignmentType,
            rubricText: rubricText,
            customInstructions: customInstructions,
            reviewedStudentText: reviewedStudentText,
            ocrQualitySummary: ocrDocument?.qualitySummary ?? OCRQualitySummary()
        )
    }
}

enum AssignmentType: String, CaseIterable, Codable, Identifiable {
    case shortAnswer
    case essay
    case paragraphResponse
    case labWriteup
    case readingComprehension

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .shortAnswer:
            return "Short answer"
        case .essay:
            return "Essay"
        case .paragraphResponse:
            return "Paragraph response"
        case .labWriteup:
            return "Lab write-up"
        case .readingComprehension:
            return "Reading comprehension"
        }
    }
}

struct OCRDocument: Codable, Equatable {
    var pages: [OCRPage]
    var createdAt: Date

    init(pages: [OCRPage], createdAt: Date = Date()) {
        self.pages = pages
        self.createdAt = createdAt
    }

    var combinedText: String {
        pages
            .sorted { $0.pageIndex < $1.pageIndex }
            .map { $0.lines.map(\.text).joined(separator: "\n") }
            .joined(separator: "\n\n")
    }

    var allLines: [OCRLine] {
        pages.flatMap(\.lines)
    }

    var hasLowConfidenceText: Bool {
        allLines.contains { $0.confidence < OCRQualitySummary.lowConfidenceThreshold }
    }

    var qualitySummary: OCRQualitySummary {
        OCRQualitySummary(lines: allLines)
    }
}

struct OCRPage: Codable, Equatable {
    var pageIndex: Int
    var imageWidth: Double?
    var imageHeight: Double?
    var lines: [OCRLine]

    init(pageIndex: Int, imageWidth: Double? = nil, imageHeight: Double? = nil, lines: [OCRLine]) {
        self.pageIndex = pageIndex
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.lines = lines
    }
}

struct OCRLine: Identifiable, Codable, Equatable {
    var id: UUID
    var text: String
    var confidence: Float
    var boundingBox: NormalizedRect

    init(id: UUID = UUID(), text: String, confidence: Float, boundingBox: NormalizedRect) {
        self.id = id
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}

struct OCRQualitySummary: Codable, Equatable {
    static let lowConfidenceThreshold: Float = 0.70

    var lineCount: Int
    var lowConfidenceLineCount: Int
    var averageConfidence: Float
    var minimumConfidence: Float?

    init(
        lineCount: Int = 0,
        lowConfidenceLineCount: Int = 0,
        averageConfidence: Float = 0,
        minimumConfidence: Float? = nil
    ) {
        self.lineCount = lineCount
        self.lowConfidenceLineCount = lowConfidenceLineCount
        self.averageConfidence = averageConfidence
        self.minimumConfidence = minimumConfidence
    }

    init(lines: [OCRLine]) {
        lineCount = lines.count
        lowConfidenceLineCount = lines.filter { $0.confidence < Self.lowConfidenceThreshold }.count
        if lines.isEmpty {
            averageConfidence = 0
            minimumConfidence = nil
        } else {
            averageConfidence = lines.map(\.confidence).reduce(0, +) / Float(lines.count)
            minimumConfidence = lines.map(\.confidence).min()
        }
    }

    var requiresTeacherOCRReview: Bool {
        lowConfidenceLineCount > 0
    }

    var displaySummary: String {
        guard lineCount > 0 else {
            return "No OCR text has been captured."
        }
        let average = Int((averageConfidence * 100).rounded())
        if lowConfidenceLineCount == 0 {
            return "OCR captured \(lineCount) text line(s) with average confidence \(average)%."
        }
        return "OCR captured \(lineCount) text line(s); \(lowConfidenceLineCount) need review. Average confidence \(average)%."
    }
}

struct NormalizedRect: Codable, Equatable {
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat

    static let zero = NormalizedRect(x: 0, y: 0, width: 0, height: 0)
}

struct GradingInput: Codable, Equatable {
    var assignmentTitle: String
    var subject: String
    var gradeLevel: String
    var assignmentType: AssignmentType
    var rubricText: String
    var customInstructions: String
    var reviewedStudentText: String
    var ocrQualitySummary: OCRQualitySummary

    var isReadyForGrading: Bool {
        !rubricText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !reviewedStudentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct GradeDraftResult: Identifiable, Codable, Equatable {
    var id: UUID
    var generatedAt: Date
    var studentResponseSummary: String
    var criteria: [CriterionScore]
    var totalScore: Double
    var maxScore: Double
    var studentFeedback: String
    var teacherNotes: String
    var uncertaintyFlags: [String]
    var complianceFlags: [String]
    var rawModelResponse: String?

    init(
        id: UUID = UUID(),
        generatedAt: Date = Date(),
        studentResponseSummary: String,
        criteria: [CriterionScore],
        totalScore: Double,
        maxScore: Double,
        studentFeedback: String,
        teacherNotes: String,
        uncertaintyFlags: [String],
        complianceFlags: [String] = [],
        rawModelResponse: String? = nil
    ) {
        self.id = id
        self.generatedAt = generatedAt
        self.studentResponseSummary = studentResponseSummary
        self.criteria = criteria
        self.totalScore = totalScore
        self.maxScore = maxScore
        self.studentFeedback = studentFeedback
        self.teacherNotes = teacherNotes
        self.uncertaintyFlags = uncertaintyFlags
        self.complianceFlags = complianceFlags
        self.rawModelResponse = rawModelResponse
    }
}

struct CriterionScore: Identifiable, Codable, Equatable {
    var id: UUID
    var criterion: String
    var rating: String
    var proposedPoints: Double
    var maxPoints: Double
    var evidence: [String]
    var explanation: String
    var teacherReviewRequired: Bool

    init(
        id: UUID = UUID(),
        criterion: String,
        rating: String,
        proposedPoints: Double,
        maxPoints: Double,
        evidence: [String],
        explanation: String,
        teacherReviewRequired: Bool
    ) {
        self.id = id
        self.criterion = criterion
        self.rating = rating
        self.proposedPoints = proposedPoints
        self.maxPoints = maxPoints
        self.evidence = evidence
        self.explanation = explanation
        self.teacherReviewRequired = teacherReviewRequired
    }
}

struct FinalGradeReview: Identifiable, Codable, Equatable {
    var id: UUID
    var finalizedAt: Date
    var criteria: [CriterionScore]
    var totalScore: Double
    var maxScore: Double
    var studentFeedback: String
    var privateTeacherNotes: String
    var teacherEdited: Bool

    init(
        id: UUID = UUID(),
        finalizedAt: Date = Date(),
        criteria: [CriterionScore],
        totalScore: Double,
        maxScore: Double,
        studentFeedback: String,
        privateTeacherNotes: String,
        teacherEdited: Bool
    ) {
        self.id = id
        self.finalizedAt = finalizedAt
        self.criteria = criteria
        self.totalScore = totalScore
        self.maxScore = maxScore
        self.studentFeedback = studentFeedback
        self.privateTeacherNotes = privateTeacherNotes
        self.teacherEdited = teacherEdited
    }
}

struct RubricTemplate: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var assignmentType: AssignmentType
    var description: String
    var rubricText: String
    var customInstructions: String
}

enum RubricTemplates {
    static let builtIn: [RubricTemplate] = [
        RubricTemplate(
            id: "short-answer-4pt",
            name: "4-point short answer",
            assignmentType: .shortAnswer,
            description: "Fast rubric for constructed responses and exit tickets.",
            rubricText: """
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
            """,
            customInstructions: "Do not penalize spelling, grammar, or handwriting unless they materially interfere with meaning. Award equivalent wording when the meaning is correct."
        ),
        RubricTemplate(
            id: "paragraph-response-8pt",
            name: "8-point paragraph response",
            assignmentType: .paragraphResponse,
            description: "Claim, evidence, reasoning, and clarity for one-paragraph responses.",
            rubricText: """
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
            """,
            customInstructions: "Keep feedback specific and actionable. Do not invent missing evidence. If OCR quality is uncertain, flag teacher review."
        ),
        RubricTemplate(
            id: "essay-20pt",
            name: "20-point essay",
            assignmentType: .essay,
            description: "General essay rubric for claim, structure, evidence, analysis, and conventions.",
            rubricText: """
            Thesis/claim: 0-4 points
            Evidence: 0-4 points
            Analysis/reasoning: 0-4 points
            Organization: 0-4 points
            Language/conventions: 0-4 points

            For each criterion:
            - 4: strong and complete.
            - 3: proficient with minor gaps.
            - 2: developing with meaningful gaps.
            - 1: minimal attempt.
            - 0: missing or off topic.
            """,
            customInstructions: "Use the rubric criteria exactly. The draft grade must cite text evidence for each criterion. Avoid comments about student ability, effort, or intent."
        ),
        RubricTemplate(
            id: "lab-writeup-16pt",
            name: "16-point lab write-up",
            assignmentType: .labWriteup,
            description: "For written science reports and lab conclusions.",
            rubricText: """
            Question / purpose: 0-2 points
            Hypothesis or prediction: 0-2 points
            Method / procedure summary: 0-3 points
            Data / observations: 0-3 points
            Conclusion: 0-3 points
            Scientific reasoning: 0-3 points
            """,
            customInstructions: "Grade only the written content provided. Do not infer experimental performance beyond the text. Flag missing data or unclear scientific vocabulary for teacher review."
        )
    ]
}

enum GradeDraftError: LocalizedError, Equatable {
    case missingRubric
    case missingStudentText
    case localModelUnavailable(String)
    case malformedModelResponse(String)
    case invalidModelGrade(String)
    case ocrFailed(String)
    case persistenceFailed(String)
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingRubric:
            return "Add a rubric, answer key, or grading criteria before drafting a grade."
        case .missingStudentText:
            return "Add or review the student text before drafting a grade."
        case .localModelUnavailable(let message):
            return message
        case .malformedModelResponse(let message):
            return "The local model returned a response the app could not parse: \(message)"
        case .invalidModelGrade(let message):
            return "The local model returned an invalid grade draft: \(message)"
        case .ocrFailed(let message):
            return "OCR failed: \(message)"
        case .persistenceFailed(let message):
            return "Could not save local data: \(message)"
        case .exportFailed(let message):
            return "Could not export the local report: \(message)"
        }
    }
}
