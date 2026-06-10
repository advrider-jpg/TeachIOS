import Foundation

#if canImport(AppIntents)
import AppIntents

enum GradeDraftIntentDestination: String, AppEnum {
    case assignments
    case review
    case aiReadiness
    case finalReview
    case latestDraft
    case packetPreview
    case ocrReview
    case curriculum
    case studentWork

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Mark My Work Destination")
    static let caseDisplayRepresentations: [GradeDraftIntentDestination: DisplayRepresentation] = [
        .assignments: "Assignments",
        .review: "Review",
        .aiReadiness: "AI Readiness",
        .finalReview: "Final Review",
        .latestDraft: "Latest Draft",
        .packetPreview: "AI Packet Preview",
        .ocrReview: "OCR Review",
        .curriculum: "Curriculum",
        .studentWork: "Student Work"
    ]

    var launchDestination: AppLaunchDestination {
        switch self {
        case .assignments:
            return .assignments
        case .review:
            return .review
        case .aiReadiness:
            return .aiReadiness
        case .finalReview:
            return .finalReview
        case .latestDraft:
            return .latestDraft
        case .packetPreview:
            return .packetPreview
        case .ocrReview:
            return .ocrReview
        case .curriculum:
            return .curriculum
        case .studentWork:
            return .studentWork
        }
    }
}

struct AssignmentEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Assignment")
    static let defaultQuery = AssignmentEntityQuery()

    let id: UUID
    let title: String

    init(id: UUID, title: String) {
        self.id = id
        self.title = title
    }

    init(record: AssignmentRecord) {
        self.id = record.id
        self.title = AssignmentEntity.safeDisplayTitle(for: record)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }

    static func safeDisplayTitle(for record: AssignmentRecord) -> String {
        var displayTitle = record.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if displayTitle.isEmpty {
            displayTitle = "Untitled assignment"
        }
        for sensitiveValue in [record.studentDisplayName, record.studentID?.uuidString, record.className] {
            guard let sensitiveValue else { continue }
            let trimmed = sensitiveValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            displayTitle = displayTitle.replacingOccurrences(
                of: trimmed,
                with: "[redacted identity]",
                options: [.caseInsensitive]
            )
        }
        return displayTitle
    }
}

struct AssignmentEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [AssignmentEntity.ID]) async throws -> [AssignmentEntity] {
        let requested = Set(identifiers)
        return AssignmentIntentResolver.loadAssignments()
            .filter { requested.contains($0.id) }
            .map(AssignmentEntity.init(record:))
    }

    func suggestedEntities() async throws -> [AssignmentEntity] {
        AssignmentIntentResolver.loadAssignments()
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(10)
            .map(AssignmentEntity.init(record:))
    }

    func entities(matching string: String) async throws -> [AssignmentEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return AssignmentIntentResolver.loadAssignments()
            .filter { $0.title.localizedCaseInsensitiveContains(query) }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(10)
            .map(AssignmentEntity.init(record:))
    }
}

enum AssignmentIntentResolver {
    static func assignmentID(entity: AssignmentEntity?, idText: String?) -> UUID? {
        entity?.id ?? idText.flatMap(UUID.init(uuidString:))
    }

    static func loadAssignments() -> [AssignmentRecord] {
        let store: AssignmentStoring
        if let dbStore = try? GRDBAssignmentStore() {
            store = dbStore
        } else {
            store = LocalJSONStore()
        }
        return (try? store.loadAssignments()) ?? []
    }
}

struct OpenGradeDraftDestinationIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Mark My Work"
    static let description = IntentDescription("Opens a safe Mark My Work workflow. AI drafts, final approval, and exports still require in-app teacher action.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Destination")
    var destination: GradeDraftIntentDestination?

    @Parameter(title: "Assignment")
    var assignment: AssignmentEntity?

    @Parameter(title: "Assignment ID")
    var assignmentIDText: String?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let resolvedDestination = destination ?? .review
        let assignmentID = AssignmentIntentResolver.assignmentID(entity: assignment, idText: assignmentIDText)
        let action: AppLaunchAction = (resolvedDestination == .packetPreview || resolvedDestination == .aiReadiness) ? .preparePacketPreview : .none
        AppLaunchRequestStore.save(
            AppLaunchRequest(
                destination: resolvedDestination.launchDestination,
                assignmentID: assignmentID,
                action: action
            )
        )
        return .result(dialog: "Opening Mark My Work. Teacher review stays in the app.")
    }
}

struct OpenAIReadinessIntent: AppIntent {
    static let title: LocalizedStringResource = "Open AI Readiness"
    static let description = IntentDescription("Opens Mark My Work to the deterministic local AI readiness center for teacher review. It does not generate a draft.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Assignment")
    var assignment: AssignmentEntity?

    @Parameter(title: "Assignment ID")
    var assignmentIDText: String?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        AppLaunchRequestStore.save(
            AppLaunchRequest(
                destination: .aiReadiness,
                assignmentID: AssignmentIntentResolver.assignmentID(entity: assignment, idText: assignmentIDText),
                action: .preparePacketPreview
            )
        )
        return .result(dialog: "Opening AI readiness in Mark My Work. No grade is generated.")
    }
}

struct OpenLatestDraftIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Latest Draft"
    static let description = IntentDescription("Opens Mark My Work to the latest local draft or final-review workflow. It does not generate or approve a grade.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Assignment")
    var assignment: AssignmentEntity?

    @Parameter(title: "Assignment ID")
    var assignmentIDText: String?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        AppLaunchRequestStore.save(
            AppLaunchRequest(
                destination: .latestDraft,
                assignmentID: AssignmentIntentResolver.assignmentID(entity: assignment, idText: assignmentIDText)
            )
        )
        return .result(dialog: "Opening the latest local draft in Mark My Work. Teacher approval stays in the app.")
    }
}

struct PrepareLocalAIPacketPreviewIntent: AppIntent {
    static let title: LocalizedStringResource = "Prepare AI Packet Preview"
    static let description = IntentDescription("Opens Mark My Work and prepares the local AI packet preview for teacher review. It does not generate a draft or approve a grade.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Assignment")
    var assignment: AssignmentEntity?

    @Parameter(title: "Assignment ID")
    var assignmentIDText: String?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        AppLaunchRequestStore.save(
            AppLaunchRequest(
                destination: .packetPreview,
                assignmentID: AssignmentIntentResolver.assignmentID(entity: assignment, idText: assignmentIDText),
                action: .preparePacketPreview
            )
        )
        return .result(dialog: "Preparing the packet preview in Mark My Work. No draft or final grade is created by this shortcut.")
    }
}

struct CreateGradeDraftAssignmentShellIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Assignment Shell"
    static let description = IntentDescription("Opens Mark My Work and creates a local blank assignment record. Student work, grading, and export still require teacher action in the app.")
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        AppLaunchRequestStore.save(
            AppLaunchRequest(destination: .assignments, action: .createAssignmentShell)
        )
        return .result(dialog: "Creating a local assignment shell in Mark My Work.")
    }
}

struct StartManualFinalReviewIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Manual Final Review"
    static let description = IntentDescription("Opens Mark My Work and starts a teacher-only manual final review when the assignment already has reviewed student work and a grading standard.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Assignment")
    var assignment: AssignmentEntity?

    @Parameter(title: "Assignment ID")
    var assignmentIDText: String?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        AppLaunchRequestStore.save(
            AppLaunchRequest(
                destination: .finalReview,
                assignmentID: AssignmentIntentResolver.assignmentID(entity: assignment, idText: assignmentIDText),
                action: .startManualFinalReview
            )
        )
        return .result(dialog: "Opening Mark My Work to start manual final review if the assignment is ready.")
    }
}

struct ApplyRecommendedAIConstraintsIntent: AppIntent {
    static let title: LocalizedStringResource = "Apply Recommended AI Constraints"
    static let description = IntentDescription("Opens Mark My Work and applies the app's recommended local-AI constraint templates to the selected assignment. Sensitive templates remain manual-only.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Assignment")
    var assignment: AssignmentEntity?

    @Parameter(title: "Assignment ID")
    var assignmentIDText: String?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        AppLaunchRequestStore.save(
            AppLaunchRequest(
                destination: .packetPreview,
                assignmentID: AssignmentIntentResolver.assignmentID(entity: assignment, idText: assignmentIDText),
                action: .applyRecommendedAIConstraints
            )
        )
        return .result(dialog: "Opening Mark My Work to apply recommended local AI constraints.")
    }
}

struct AddPastedStudentWorkIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Pasted Student Work"
    static let description = IntentDescription("Opens Mark My Work and saves pasted student work as teacher-reviewed local input. Existing reviewed text for the selected assignment is replaced.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Student Work Text")
    var studentWorkText: String

    @Parameter(title: "Assignment")
    var assignment: AssignmentEntity?

    @Parameter(title: "Assignment ID")
    var assignmentIDText: String?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = studentWorkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(dialog: "Paste non-empty student work text before running this shortcut.")
        }
        guard let assignmentID = AssignmentIntentResolver.assignmentID(entity: assignment, idText: assignmentIDText) else {
            return .result(dialog: "Choose an assignment before saving pasted student work. Mark My Work did not change any student work.")
        }
        AppLaunchRequestStore.save(
            AppLaunchRequest(
                destination: .studentWork,
                assignmentID: assignmentID,
                action: .applyPastedStudentText,
                payloadText: trimmed
            )
        )
        return .result(dialog: "Opening Mark My Work to save pasted student work locally. No grade is generated.")
    }
}

struct SearchLocalGradeDraftAssignmentsIntent: AppIntent {
    static let title: LocalizedStringResource = "Search Local Assignments"
    static let description = IntentDescription("Searches local assignment titles on this device. It does not inspect roster records, generate grades, or export reports.")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Search Text")
    var searchText: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return .result(dialog: "Enter search text to search local assignment titles.")
        }
        let matches = AssignmentIntentResolver.loadAssignments()
            .filter { $0.title.localizedCaseInsensitiveContains(query) }
            .prefix(5)
            .map(AssignmentEntity.safeDisplayTitle(for:))
        let message = matches.isEmpty
            ? "No local assignment titles matched \(query)."
            : "Matched local assignment titles: \(matches.joined(separator: "; ")). Use the Assignment parameter in shortcuts to select one."
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

struct GradeDraftShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenGradeDraftDestinationIntent(),
            phrases: [
                "Open \(.applicationName)",
                "Open review in \(.applicationName)"
            ],
            shortTitle: "Open Review",
            systemImageName: "checklist"
        )
        AppShortcut(
            intent: OpenAIReadinessIntent(),
            phrases: [
                "Open AI readiness in \(.applicationName)"
            ],
            shortTitle: "AI Readiness",
            systemImageName: "checkmark.shield"
        )
        AppShortcut(
            intent: PrepareLocalAIPacketPreviewIntent(),
            phrases: [
                "Prepare packet preview in \(.applicationName)",
                "Preview local AI packet in \(.applicationName)"
            ],
            shortTitle: "Packet Preview",
            systemImageName: "doc.text.magnifyingglass"
        )
        AppShortcut(
            intent: OpenLatestDraftIntent(),
            phrases: [
                "Open latest draft in \(.applicationName)"
            ],
            shortTitle: "Latest Draft",
            systemImageName: "doc.text.magnifyingglass"
        )
        AppShortcut(
            intent: StartManualFinalReviewIntent(),
            phrases: [
                "Start manual final review in \(.applicationName)"
            ],
            shortTitle: "Manual Review",
            systemImageName: "pencil.and.list.clipboard"
        )
        AppShortcut(
            intent: ApplyRecommendedAIConstraintsIntent(),
            phrases: [
                "Apply AI constraints in \(.applicationName)"
            ],
            shortTitle: "AI Constraints",
            systemImageName: "checklist.checked"
        )
        AppShortcut(
            intent: AddPastedStudentWorkIntent(),
            phrases: [
                "Add pasted student work in \(.applicationName)"
            ],
            shortTitle: "Paste Work",
            systemImageName: "text.badge.plus"
        )
        AppShortcut(
            intent: CreateGradeDraftAssignmentShellIntent(),
            phrases: [
                "Create assignment in \(.applicationName)"
            ],
            shortTitle: "New Assignment",
            systemImageName: "doc.badge.plus"
        )
        AppShortcut(
            intent: SearchLocalGradeDraftAssignmentsIntent(),
            phrases: [
                "Search assignments in \(.applicationName)"
            ],
            shortTitle: "Search",
            systemImageName: "magnifyingglass"
        )
    }
}
#endif
