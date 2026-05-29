import Foundation

final class GRDBAssignmentStore: AssignmentStoring {
    private let database: GradeDraftDatabase

    init(fileManager: FileManager = .default) throws {
        let supportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        database = try GradeDraftDatabase(applicationSupportURL: supportURL)
        try database.bootstrapIfNeeded()
    }

    init(database: GradeDraftDatabase) throws {
        self.database = database
        try database.bootstrapIfNeeded()
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

    func applicationSupportDirectory() throws -> URL {
        try database.applicationSupportDirectory()
    }

    func loadClassGroups() throws -> [ClassGroupRecord] { try database.loadClassGroups() }
    func saveClassGroup(_ classGroup: ClassGroupRecord) throws { try database.saveClassGroup(classGroup) }
    func deleteClassGroup(id: UUID) throws { try database.deleteClassGroup(id: id) }
    func loadStudents() throws -> [StudentRecord] { try database.loadStudents() }
    func saveStudent(_ student: StudentRecord) throws { try database.saveStudent(student) }
    func deleteStudent(id: UUID) throws { try database.deleteStudent(id: id) }
    func loadAssignmentRoster(assignmentID: UUID) throws -> [AssignmentRosterEntry] { try database.loadAssignmentRoster(assignmentID: assignmentID) }
    func saveAssignmentRoster(_ entries: [AssignmentRosterEntry]) throws { try database.saveAssignmentRoster(entries) }
    func saveSourceInputs(_ sourceInputs: [SourceInputRef], assignmentID: UUID) throws { try database.saveSourceInputs(sourceInputs, assignmentID: assignmentID) }
    func saveOCRDocument(_ document: OCRDocument, assignmentID: UUID) throws { try database.saveOCRDocument(document, assignmentID: assignmentID) }
    func saveFinalReview(_ review: FinalGradeReview, assignmentID: UUID) throws { try database.saveFinalReview(review, assignmentID: assignmentID) }
    func saveEvidenceReferences(_ references: [EvidenceReference], assignmentID: UUID) throws { try database.saveEvidenceReferences(references, assignmentID: assignmentID) }
    func loadFullAssignmentGraph(id: UUID) throws -> AssignmentRecord? { try database.loadFullAssignmentGraph(id: id) }
}
