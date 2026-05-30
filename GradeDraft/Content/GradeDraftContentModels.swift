import Foundation

// MARK: - Planned grading-content model layer

/// Scope for reusable teacher instruction templates. These are deliberately teacher-facing by default.
enum InstructionScope: String, CaseIterable, Codable, Identifiable {
    case grading
    case feedback
    case ocrReview
    case accessibility
    case formative
    case summative
    case answerKey
    case exemplar
    case adjustment
    case misconception

    var id: String { rawValue }
}

/// Priority controls how prominently an instruction should be surfaced in the UI.
enum InstructionPriority: String, CaseIterable, Codable, Identifiable {
    case optional
    case standard
    case required

    var id: String { rawValue }
}

struct TeacherInstructionTemplate: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var description: String
    var text: String
    var scope: InstructionScope
    var priority: InstructionPriority
    var studentFacing: Bool
    var privateTeacherOnly: Bool
}

struct AnswerKeyTemplate: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var assignmentTypes: [AssignmentType]
    var description: String
    var markdownTemplate: String
}

struct ExemplarTemplate: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var assignmentTypes: [AssignmentType]
    var description: String
    var markdownTemplate: String
}

struct FormativeFocusTemplate: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var assignmentTypes: [AssignmentType]
    var description: String
    var markdownTemplate: String
}

enum GradeDraftTemplateKind: String, CaseIterable, Codable, Equatable, Identifiable {
    case rubric
    case teacherInstruction
    case answerKey
    case exemplar
    case formativeFocus

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rubric: return "Rubric"
        case .teacherInstruction: return "Teacher instruction"
        case .answerKey: return "Answer key"
        case .exemplar: return "Exemplar"
        case .formativeFocus: return "Formative focus"
        }
    }
}

struct AppliedTemplateRecord: Identifiable, Codable, Equatable {
    var id: UUID
    var templateID: String
    var templateName: String
    var templateKind: GradeDraftTemplateKind
    var appliedAt: Date
    var insertionMode: TemplateInsertionMode

    init(
        id: UUID = UUID(),
        templateID: String,
        templateName: String,
        templateKind: GradeDraftTemplateKind,
        appliedAt: Date = Date(),
        insertionMode: TemplateInsertionMode
    ) {
        self.id = id
        self.templateID = templateID
        self.templateName = templateName
        self.templateKind = templateKind
        self.appliedAt = appliedAt
        self.insertionMode = insertionMode
    }
}

struct ExportWarningDefinition: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var title: String
    var body: String
    var warningLine: String?
    var securityNote: String?
    var checklist: [String]
    var primaryButton: String
    var secondaryButton: String
    var finalButton: String?
    var optionalCheckbox: String?
    var postPreviewConfirmation: String?
    var escalatedConfirmation: String?
    var defaultChoice: String?
    var acknowledgementText: String
    var requiresAcknowledgement: Bool
    var blocksStudentFacingExportByDefault: Bool

    init(
        id: String,
        name: String,
        title: String,
        body: String,
        warningLine: String? = nil,
        securityNote: String? = nil,
        checklist: [String] = [],
        primaryButton: String,
        secondaryButton: String,
        finalButton: String? = nil,
        optionalCheckbox: String? = nil,
        postPreviewConfirmation: String? = nil,
        escalatedConfirmation: String? = nil,
        defaultChoice: String? = nil,
        acknowledgementText: String,
        requiresAcknowledgement: Bool,
        blocksStudentFacingExportByDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.title = title
        self.body = body
        self.warningLine = warningLine
        self.securityNote = securityNote
        self.checklist = checklist
        self.primaryButton = primaryButton
        self.secondaryButton = secondaryButton
        self.finalButton = finalButton
        self.optionalCheckbox = optionalCheckbox
        self.postPreviewConfirmation = postPreviewConfirmation
        self.escalatedConfirmation = escalatedConfirmation
        self.defaultChoice = defaultChoice
        self.acknowledgementText = acknowledgementText
        self.requiresAcknowledgement = requiresAcknowledgement
        self.blocksStudentFacingExportByDefault = blocksStudentFacingExportByDefault
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, title, body, warningLine, securityNote, checklist, primaryButton, secondaryButton
        case finalButton, optionalCheckbox, postPreviewConfirmation, escalatedConfirmation, defaultChoice
        case acknowledgementText, requiresAcknowledgement, blocksStudentFacingExportByDefault
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        warningLine = try container.decodeIfPresent(String.self, forKey: .warningLine)
        securityNote = try container.decodeIfPresent(String.self, forKey: .securityNote)
        checklist = (try? container.decode([String].self, forKey: .checklist)) ?? []
        primaryButton = try container.decode(String.self, forKey: .primaryButton)
        secondaryButton = try container.decode(String.self, forKey: .secondaryButton)
        finalButton = try container.decodeIfPresent(String.self, forKey: .finalButton)
        optionalCheckbox = try container.decodeIfPresent(String.self, forKey: .optionalCheckbox)
        postPreviewConfirmation = try container.decodeIfPresent(String.self, forKey: .postPreviewConfirmation)
        escalatedConfirmation = try container.decodeIfPresent(String.self, forKey: .escalatedConfirmation)
        defaultChoice = try container.decodeIfPresent(String.self, forKey: .defaultChoice)
        acknowledgementText = (try? container.decode(String.self, forKey: .acknowledgementText)) ?? ""
        requiresAcknowledgement = (try? container.decode(Bool.self, forKey: .requiresAcknowledgement)) ?? false
        blocksStudentFacingExportByDefault = (try? container.decode(Bool.self, forKey: .blocksStudentFacingExportByDefault)) ?? false
    }
}

struct GradeDraftContentSection: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var markdown: String
}

struct ExportRiskSummary: Equatable {
    var includesDraftContent: Bool
    var includesPrivateNotes: Bool
    var includesOriginalSources: Bool
    var affectedAssignmentCount: Int

    static let empty = ExportRiskSummary(
        includesDraftContent: false,
        includesPrivateNotes: false,
        includesOriginalSources: false,
        affectedAssignmentCount: 0
    )
}

struct PlannedCopyItem: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var body: String
}

struct PlannedRuleItem: Identifiable, Codable, Equatable {
    var id: String
    var text: String
}
