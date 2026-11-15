import Foundation
import AppIntents
import GRDB
import Observation

/// App-wide state: the open store, the list data the tab roots show, each tab's navigation path, the
/// background-work registry and the services. Per-record state lives in the per-route models
/// (`SubmissionSession`, `AssignmentSetupModel`, `RosterModel`, `CurriculumBrowserModel`), each keyed by ID.
@Observable @MainActor
final class AppModel {
    /// Where the app's saved work lives once storage is open.
    struct Storage {
        var database: AppDatabase
        /// `AppDatabase.storageDirectory`; source paths are relative to it.
        var root: URL
    }

    private(set) var database: AppDatabase?
    private(set) var storageRoot: URL?
    /// Set when the saved-work database could not be opened; the window shows `StorageErrorView`.
    private(set) var startupError: AppDatabaseError?

    // List data, refreshed whenever the tables they read change.
    private(set) var classGroups: [ClassGroup] = []
    private(set) var assignmentSummaries: [AssignmentSummary] = []
    private(set) var submissionSummaries: [SubmissionSummary] = []
    private(set) var listsLoaded = false

    var selectedTab: AppTab = .home
    var paths: [AppTab: [Route]] = [:]

    /// For this model's own actions (add or delete a class or assignment) and list loading.
    var alert: AlertMessage?

    let backgroundWork = BackgroundWork()
    let services: AppServices
    let backupRestore: BackupRestoreModel
    private(set) var importer: (any SourceImporting)?

    @ObservationIgnored private let openStorageHandler: @MainActor () throws -> Storage

    /// - Parameters:
    ///   - openStorage: opens the database; production opens it on disk. Tests pass an in-memory database.
    ///   - services: the AI, import, curriculum and authentication services.
    init(
        openStorage: @escaping @MainActor () throws -> Storage = AppModel.openOnDisk,
        services: AppServices? = nil
    ) {
        self.openStorageHandler = openStorage
        self.services = services ?? AppServices.live()
        self.backupRestore = BackupRestoreModel()
        backupRestore.app = self
        self.openStorage()
    }

    static func openOnDisk() throws -> Storage {
        let database = try AppDatabase.openOnDisk()
        return Storage(database: database, root: try AppDatabase.storageDirectory())
    }

    /// Registers what Shortcuts use: the open store and this model (so a Shortcut can create through the
    /// model and open the result). Called at launch and again after **Try Again** reopens storage.
    static func registerDependencies(_ appModel: AppModel) {
        if let database = appModel.database {
            AppDependencyManager.shared.add { database }
        }
        AppDependencyManager.shared.add { appModel }
    }

    /// Opens storage; called at launch and by **Try Again** on the storage error screen.
    func openStorage() {
        do {
            let storage = try openStorageHandler()
            database = storage.database
            storageRoot = storage.root
            importer = services.makeImporter(storage.root)
            startupError = nil
        } catch let error as AppDatabaseError {
            startupError = error
        } catch {
            startupError = .openFailed(underlying: error)
        }
    }

    /// The open database, or the storage error. Per-route models call this before every read or write.
    func requireDatabase() throws -> AppDatabase {
        guard let database else { throw startupError ?? AppDatabaseError.openFailed(underlying: StorageNotOpenError()) }
        return database
    }

    func requireStorageRoot() throws -> URL {
        guard let storageRoot else { throw startupError ?? AppDatabaseError.openFailed(underlying: StorageNotOpenError()) }
        return storageRoot
    }

    func requireImporter() throws -> any SourceImporting {
        guard let importer else { throw startupError ?? AppDatabaseError.openFailed(underlying: StorageNotOpenError()) }
        return importer
    }

    // MARK: - Lists

    /// Keeps the list data current for as long as the calling task runs (the shell's `.task`).
    func observeLists() async {
        guard let database else { return }
        let observation = ValueObservation
            .tracking(region: DatabaseRegion.fullDatabase, fetch: { _ in true })
            .values(in: database.writer)
        do {
            for try await _ in observation {
                await refreshLists(database)
            }
        } catch {
            alert = AlertMessage(title: "Saved work could not be read", error: error)
        }
    }

    private func refreshLists(_ database: AppDatabase) async {
        do {
            async let classes = database.classGroups()
            async let assignments = database.assignmentSummaries(inClass: nil)
            async let submissions = database.submissionSummaries(assignmentID: nil)
            classGroups = try await classes
            assignmentSummaries = try await assignments
            submissionSummaries = try await submissions
            listsLoaded = true
        } catch {
            alert = AlertMessage(title: "Saved work could not be read", error: error)
        }
    }

    func className(for classGroupID: UUID) -> String {
        classGroups.first { $0.id == classGroupID }?.name ?? ""
    }

    // MARK: - Classes and assignments

    @discardableResult
    func addClass(name: String) async -> UUID? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            alert = AlertMessage(title: "Class not added", message: "Enter a class name.")
            return nil
        }
        do {
            let classGroup = ClassGroup(name: trimmed)
            try await requireDatabase().save(classGroup)
            return classGroup.id
        } catch {
            alert = AlertMessage(title: "Class not added", error: error)
            return nil
        }
    }

    /// Deletes the class with its assignments, their submissions and those submissions' source files.
    func deleteClass(id: UUID) async {
        do {
            let paths = try await requireDatabase().deleteClassGroup(id: id)
            reportCleanup(paths)
        } catch {
            alert = AlertMessage(title: "Class not deleted", error: error)
        }
    }

    /// Creates a class-level assignment; the store creates one submission per enrolled student.
    @discardableResult
    func createAssignment(title: String, classGroupID: UUID) async -> UUID? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            alert = AlertMessage(title: "Assignment not created", message: "Enter an assignment title.")
            return nil
        }
        do {
            return try await createAssignment(title: trimmed, classGroupID: classGroupID, auditDetail: "Assignment created for the class.")
        } catch {
            alert = AlertMessage(title: "Assignment not created", error: error)
            return nil
        }
    }

    /// The creation itself, for callers that report failure their own way (Shortcuts). `title` is already trimmed
    /// and non-empty. Throws instead of setting `alert`.
    func createAssignment(title: String, classGroupID: UUID, auditDetail: String) async throws -> UUID {
        let database = try requireDatabase()
        let assignment = Assignment(classGroupID: classGroupID, title: title)
        try await database.createAssignment(assignment)
        try await database.appendAudit(AuditEvent(
            assignmentID: assignment.id, submissionID: nil, eventType: .assignmentCreated, detail: auditDetail
        ))
        return assignment.id
    }

    /// Deletes the assignment with its submissions and their source files.
    func deleteAssignment(id: UUID) async {
        do {
            let paths = try await requireDatabase().deleteAssignment(id: id)
            reportCleanup(paths)
        } catch {
            alert = AlertMessage(title: "Assignment not deleted", error: error)
        }
    }

    private func reportCleanup(_ paths: [String]) {
        guard let storageRoot else { return }
        let failed = SourceFileCleanup.delete(paths, storageRoot: storageRoot)
        if !failed.isEmpty {
            alert = AlertMessage(title: "Files not deleted", message: SourceFileCleanup.failureMessage(failed))
        }
    }

    // MARK: - Navigation

    func path(for tab: AppTab) -> [Route] {
        paths[tab] ?? []
    }

    func setPath(_ path: [Route], for tab: AppTab) {
        paths[tab] = path
    }

    /// "Next student": replaces the last screen of the tab's path, so Back returns to the same parent.
    func replaceLast(in tab: AppTab, with route: Route) {
        var path = paths[tab] ?? []
        if path.isEmpty {
            path.append(route)
        } else {
            path[path.count - 1] = route
        }
        paths[tab] = path
    }

    /// The next submission in roster order under the same assignment, or nil at the end of the roster.
    func nextSubmission(after submissionID: UUID) -> SubmissionSummary? {
        guard let current = submissionSummaries.first(where: { $0.id == submissionID }) else { return nil }
        let siblings = submissionSummaries.filter { $0.assignmentID == current.assignmentID }
        guard let index = siblings.firstIndex(where: { $0.id == submissionID }), index + 1 < siblings.count else { return nil }
        return siblings[index + 1]
    }

    /// Opens an assignment's screen on the Assignments tab (after a Shortcut creates it).
    func openAssignment(_ id: UUID) {
        paths[.assignments] = [.assignment(id)]
        selectedTab = .assignments
    }

    /// Opens a submission from a Shortcut. An ID that is not saved still opens its route, which then
    /// shows the not-found state; nothing else is opened in its place.
    func open(_ submissionID: UUID, destination: SubmissionDestination) {
        let assignmentID = submissionSummaries.first { $0.id == submissionID }?.assignmentID
        var path: [Route] = assignmentID.map { [.assignment($0)] } ?? []
        path.append(.submission(submissionID))
        let tab: AppTab
        switch destination {
        case .overview:
            tab = .assignments
        case .finalReview:
            tab = .assignments
            path.append(.finalReview(submissionID))
        case .aiDraft, .aiReadiness:
            tab = .review
            path.append(.aiDraft(submissionID))
        }
        paths[tab] = path
        selectedTab = tab
    }
}

private struct StorageNotOpenError: LocalizedError {
    var errorDescription: String? { "Saved work is not open." }
}
