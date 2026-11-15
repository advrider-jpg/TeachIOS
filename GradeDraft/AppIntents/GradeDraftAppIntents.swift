import AppIntents
import Foundation

// Three Shortcuts, delivered in-process: Open Assignment routes the open window to a submission;
// Add Pasted Student Work writes through the app's `AppDatabase` and Create Assignment through the `AppModel`
// (both registered with `AppDependencyManager` at launch); each then opens what it changed.
// No Shortcut drafts, grades, approves or exports.

enum SubmissionDestination: String, AppEnum {
    case overview
    case aiDraft
    case finalReview
    case aiReadiness

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "MarkForMe Screen")
    static let caseDisplayRepresentations: [SubmissionDestination: DisplayRepresentation] = [
        .overview: "Student Work",
        .aiDraft: "AI Draft",
        .finalReview: "Final Review",
        .aiReadiness: "AI Readiness"
    ]
}

// MARK: - Entities

/// One student's submission under an assignment. Its title is the assignment title only: student and class
/// names are kept out of Shortcuts and Siri suggestions, as before.
struct SubmissionEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Assignment")
    static let defaultQuery = SubmissionEntityQuery()

    let id: UUID
    let title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }

    /// The assignment title with the student's and class's names removed.
    static func safeTitle(assignmentTitle: String, studentName: String, className: String) -> String {
        var title = assignmentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty { title = "Untitled assignment" }
        for sensitive in [studentName, className] {
            let trimmed = sensitive.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            title = title.replacingOccurrences(of: trimmed, with: "[redacted identity]", options: [.caseInsensitive])
        }
        return title
    }
}

/// Reads submission titles with one query (no graphs are loaded).
struct SubmissionEntityQuery: EntityQuery, EntityStringQuery {
    @Dependency private var database: AppDatabase

    private static let limit = 10

    func entities(for identifiers: [SubmissionEntity.ID]) async throws -> [SubmissionEntity] {
        let requested = Set(identifiers)
        return try await titles().filter { requested.contains($0.id) }
    }

    func suggestedEntities() async throws -> [SubmissionEntity] {
        Array(try await titles().prefix(Self.limit))
    }

    func entities(matching string: String) async throws -> [SubmissionEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return Array(try await titles().filter { $0.title.localizedCaseInsensitiveContains(query) }.prefix(Self.limit))
    }

    /// Most recently changed first.
    private func titles() async throws -> [SubmissionEntity] {
        try await database.submissionTitles().map { row in
            SubmissionEntity(
                id: row.id,
                title: SubmissionEntity.safeTitle(assignmentTitle: row.assignmentTitle, studentName: row.studentName, className: row.className)
            )
        }
    }
}

struct ClassEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Class")
    static let defaultQuery = ClassEntityQuery()

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct ClassEntityQuery: EntityQuery {
    @Dependency private var database: AppDatabase

    func entities(for identifiers: [ClassEntity.ID]) async throws -> [ClassEntity] {
        let requested = Set(identifiers)
        return try await database.classGroups()
            .filter { requested.contains($0.id) }
            .map { ClassEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [ClassEntity] {
        try await database.classGroups()
            .filter { !$0.isArchived }
            .map { ClassEntity(id: $0.id, name: $0.name) }
    }
}

// MARK: - Intents

/// Opens MarkForMe at one student's submission. The open window handles it with `.onAppIntentExecution`.
struct OpenSubmissionIntent: OpenIntent, TargetContentProvidingIntent {
    static let title: LocalizedStringResource = "Open Assignment"
    static let description = IntentDescription("Opens a student's work in MarkForMe. Drafting, final approval and exports stay with the teacher in the app.")

    @Parameter(title: "Assignment")
    var target: SubmissionEntity

    /// Optional: an open intent may require only its target. Nil opens the student's overview.
    @Parameter(title: "Screen")
    var destination: SubmissionDestination?

    init() {}

    init(target: SubmissionEntity, destination: SubmissionDestination?) {
        self.target = target
        self.destination = destination
    }

    var contentIdentifier: String { target.id.uuidString }

    func perform() async throws -> some IntentResult {
        .result()
    }
}

/// Saves pasted text as a submission's teacher-reviewed work (replacing earlier work), then opens it.
struct AddPastedStudentWorkIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Pasted Student Work"
    static let description = IntentDescription("Saves pasted student work for one student in MarkForMe, replacing their earlier work. No grade is generated.")

    @Parameter(title: "Student Work Text")
    var studentWorkText: String

    @Parameter(title: "Assignment")
    var target: SubmissionEntity

    @Dependency private var database: AppDatabase

    func perform() async throws -> some IntentResult & ProvidesDialog & OpensIntent {
        let text = studentWorkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw IntentFailure(message: "Paste non-empty student work text before running this shortcut. No student work was changed.")
        }
        guard let graph = try await database.submission(id: target.id) else {
            throw AppDatabaseError.notFound(target.id)
        }
        let replaced = try await database.replaceInput(submissionID: target.id, kind: .pasted, pastedText: text, sources: [], ocr: nil)
        try await database.appendAudit(AuditEvent(
            assignmentID: graph.submission.assignmentID, submissionID: target.id, eventType: .inputChanged,
            detail: "Pasted student text saved from Shortcuts as teacher-reviewed work."
        ))
        let failed = SourceFileCleanup.delete(replaced, storageRoot: try AppDatabase.storageDirectory())
        if !failed.isEmpty {
            try await database.appendAudit(AuditEvent(
                assignmentID: graph.submission.assignmentID, submissionID: target.id, eventType: .localFileCleanupFailed,
                detail: SourceFileCleanup.failureMessage(failed)
            ))
        }
        return .result(
            opensIntent: OpenSubmissionIntent(target: target, destination: .overview),
            dialog: "Student work saved in MarkForMe. No grade was generated."
        )
    }
}

/// Creates a class-level assignment (one submission per enrolled student) and opens it.
struct CreateAssignmentIntent: AppIntent {
    static let openAppWhenRun = true

    static let title: LocalizedStringResource = "Create Assignment"
    static let description = IntentDescription("Creates an assignment for a class in MarkForMe. Rubrics, student work and grading stay with the teacher in the app.")

    @Parameter(title: "Title")
    var assignmentTitle: String

    @Parameter(title: "Class")
    var classGroup: ClassEntity

    @Dependency private var appModel: AppModel

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let title = assignmentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            throw IntentFailure(message: "Enter an assignment title. No assignment was created.")
        }
        let assignmentID = try await appModel.createAssignment(
            title: title, classGroupID: classGroup.id, auditDetail: "Assignment created from Shortcuts."
        )
        appModel.openAssignment(assignmentID)
        return .result(dialog: "Created \(title) for \(classGroup.name) in MarkForMe.")
    }
}

/// A Shortcut failure with the message the teacher sees.
struct IntentFailure: LocalizedError {
    var message: String
    var errorDescription: String? { message }
}

struct GradeDraftShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenSubmissionIntent(),
            phrases: ["Open an assignment in \(.applicationName)"],
            shortTitle: "Open Assignment",
            systemImageName: "doc.text"
        )
        AppShortcut(
            intent: AddPastedStudentWorkIntent(),
            phrases: ["Add pasted student work in \(.applicationName)"],
            shortTitle: "Paste Work",
            systemImageName: "text.badge.plus"
        )
        AppShortcut(
            intent: CreateAssignmentIntent(),
            phrases: ["Create assignment in \(.applicationName)"],
            shortTitle: "New Assignment",
            systemImageName: "doc.badge.plus"
        )
    }
}
