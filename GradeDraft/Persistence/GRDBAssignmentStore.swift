import Foundation

final class GRDBAssignmentStore: AssignmentStoring {
    private let database: GradeDraftDatabase

    init(applicationSupportURL: URL? = nil, fileManager: FileManager = .default) throws {
        let supportURL = applicationSupportURL
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first

        guard let supportURL else {
            throw NSError(domain: "GRDBAssignmentStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Application support directory unavailable."])
        }

        database = try GradeDraftDatabase(applicationSupportURL: supportURL)
        try database.bootstrapIfNeeded()
    }

    func applicationSupportDirectory() throws -> URL {
        try database.applicationSupportDirectory()
    }

    func loadAssignments() throws -> [AssignmentRecord] {
        try database.loadAssignments()
    }

    func saveAssignments(_ assignments: [AssignmentRecord]) throws {
        try database.saveAssignments(assignments)
    }

    func deleteAssignment(id: UUID) throws {
        try database.deleteAssignment(id: id)
    }
}
