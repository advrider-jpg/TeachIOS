import Foundation
import GRDB

// MARK: - Assignment (class-level, one shared rubric)

enum AssignmentType: String, CaseIterable, Codable, Identifiable, Sendable {
    case shortAnswer
    case essay
    case paragraphResponse
    case labWriteup
    case readingComprehension

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .shortAnswer: return "Short answer"
        case .essay: return "Essay"
        case .paragraphResponse: return "Paragraph response"
        case .labWriteup: return "Lab write-up"
        case .readingComprehension: return "Reading comprehension"
        }
    }
}

enum AssessmentPurpose: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case formative
    case summative
    case practice
    case diagnostic
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .formative: return "Formative"
        case .summative: return "Summative"
        case .practice: return "Practice"
        case .diagnostic: return "Diagnostic"
        case .other: return "Other"
        }
    }
}

enum RubricImportMode: String, Codable, Equatable, Sendable {
    case automatic
    case structuredConfirmed
    case rawTextOnly
}

struct Assignment: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable, Sendable {
    static let databaseTableName = "assignment"

    var id: UUID
    var classGroupID: UUID
    var title: String
    var prompt: String
    var subject: String
    var gradeLevel: String
    var assessmentPurpose: AssessmentPurpose
    var curriculumReference: String
    var assignmentType: AssignmentType
    var rubricText: String
    var rubricImportMode: RubricImportMode
    var confirmedRubric: ParsedRubric?
    var customInstructions: String
    var constraintTemplateIDs: [String]
    var answerKeyText: String
    var exemplarText: String
    var formativeFocusText: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        classGroupID: UUID,
        title: String,
        prompt: String = "",
        subject: String = "",
        gradeLevel: String = "",
        assessmentPurpose: AssessmentPurpose = .summative,
        curriculumReference: String = "",
        assignmentType: AssignmentType = .shortAnswer,
        rubricText: String = "",
        rubricImportMode: RubricImportMode = .automatic,
        confirmedRubric: ParsedRubric? = nil,
        customInstructions: String = "",
        constraintTemplateIDs: [String] = GradingConstraintTemplates.defaultSelectedIDs,
        answerKeyText: String = "",
        exemplarText: String = "",
        formativeFocusText: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.classGroupID = classGroupID
        self.title = title
        self.prompt = prompt
        self.subject = subject
        self.gradeLevel = gradeLevel
        self.assessmentPurpose = assessmentPurpose
        self.curriculumReference = curriculumReference
        self.assignmentType = assignmentType
        self.rubricText = rubricText
        self.rubricImportMode = rubricImportMode
        self.confirmedRubric = confirmedRubric
        self.customInstructions = customInstructions
        self.constraintTemplateIDs = constraintTemplateIDs
        self.answerKeyText = answerKeyText
        self.exemplarText = exemplarText
        self.formativeFocusText = formativeFocusText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var hasGradingStandard: Bool {
        ![rubricText, answerKeyText, exemplarText].allSatisfy {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

struct CurriculumMapping: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable, Sendable {
    static let databaseTableName = "curriculumMapping"

    var id: UUID
    var assignmentID: UUID
    var curriculumItemID: String
    var mappingKind: String
    var rubricCriterionID: String?
    var suggestedByAI: Bool
    var teacherConfirmed: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        assignmentID: UUID,
        curriculumItemID: String,
        mappingKind: String,
        rubricCriterionID: String? = nil,
        suggestedByAI: Bool = false,
        teacherConfirmed: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.assignmentID = assignmentID
        self.curriculumItemID = curriculumItemID
        self.mappingKind = mappingKind
        self.rubricCriterionID = rubricCriterionID
        self.suggestedByAI = suggestedByAI
        self.teacherConfirmed = teacherConfirmed
        self.createdAt = createdAt
    }
}

// MARK: - Assignment setup (the grading inputs shared by every submission)

struct AssignmentSetup: Codable, Equatable, Sendable, Identifiable {
    var assignment: Assignment
    var appliedTemplates: [AppliedTemplateRecord]
    var curriculumMappings: [CurriculumMapping]

    init(assignment: Assignment, appliedTemplates: [AppliedTemplateRecord] = [], curriculumMappings: [CurriculumMapping] = []) {
        self.assignment = assignment
        self.appliedTemplates = appliedTemplates
        self.curriculumMappings = curriculumMappings
    }

    var id: UUID { assignment.id }

    var parsedRubric: ParsedRubric {
        switch assignment.rubricImportMode {
        case .structuredConfirmed:
            return assignment.confirmedRubric ?? RubricParser.parse(assignment.rubricText)
        case .rawTextOnly:
            let hasText = !assignment.rubricText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return ParsedRubric(
                criteria: [],
                issues: hasText ? ["Rubric was saved as raw text; structured criteria were not teacher-confirmed."] : [],
                groups: []
            )
        case .automatic:
            return RubricParser.parse(assignment.rubricText)
        }
    }

    /// SHA-256 of `canonicalEncoding()`.
    var setupFingerprint: String {
        get throws { ContentDigest.sha256Hex(try canonicalEncoding()) }
    }

    /// The grading inputs of this setup as sorted-key JSON. Record IDs, the class link and
    /// timestamps are left out: they are not grading inputs, and including them would mark
    /// drafts stale on a save that changed nothing a teacher or the model reads.
    func canonicalEncoding() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(CanonicalSetup(self))
    }
}

private struct CanonicalSetup: Encodable {
    struct Template: Encodable {
        var templateID: String
        var templateName: String
        var templateKind: GradeDraftTemplateKind
        var insertionMode: TemplateInsertionMode
    }

    struct Mapping: Encodable {
        var curriculumItemID: String
        var mappingKind: String
        var rubricCriterionID: String?
        var suggestedByAI: Bool
        var teacherConfirmed: Bool
    }

    var title: String
    var prompt: String
    var subject: String
    var gradeLevel: String
    var assessmentPurpose: AssessmentPurpose
    var curriculumReference: String
    var assignmentType: AssignmentType
    var rubricText: String
    var rubricImportMode: RubricImportMode
    var confirmedRubric: ParsedRubric?
    var customInstructions: String
    var constraintTemplateIDs: [String]
    var answerKeyText: String
    var exemplarText: String
    var formativeFocusText: String
    var appliedTemplates: [Template]
    var curriculumMappings: [Mapping]

    init(_ setup: AssignmentSetup) {
        let assignment = setup.assignment
        title = assignment.title
        prompt = assignment.prompt
        subject = assignment.subject
        gradeLevel = assignment.gradeLevel
        assessmentPurpose = assignment.assessmentPurpose
        curriculumReference = assignment.curriculumReference
        assignmentType = assignment.assignmentType
        rubricText = assignment.rubricText
        rubricImportMode = assignment.rubricImportMode
        confirmedRubric = assignment.confirmedRubric
        customInstructions = assignment.customInstructions
        constraintTemplateIDs = assignment.constraintTemplateIDs
        answerKeyText = assignment.answerKeyText
        exemplarText = assignment.exemplarText
        formativeFocusText = assignment.formativeFocusText
        appliedTemplates = setup.appliedTemplates.map {
            Template(templateID: $0.templateID, templateName: $0.templateName, templateKind: $0.templateKind, insertionMode: $0.insertionMode)
        }
        curriculumMappings = setup.curriculumMappings.map {
            Mapping(
                curriculumItemID: $0.curriculumItemID,
                mappingKind: $0.mappingKind,
                rubricCriterionID: $0.rubricCriterionID,
                suggestedByAI: $0.suggestedByAI,
                teacherConfirmed: $0.teacherConfirmed
            )
        }
    }
}
