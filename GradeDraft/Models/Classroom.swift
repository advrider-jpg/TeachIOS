import Foundation
import GRDB

// MARK: - Classes, students and enrolment

struct ClassGroup: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable, Sendable {
    static let databaseTableName = "classGroup"

    var id: UUID
    var name: String
    var schoolYear: String
    var term: String
    var subject: String
    var gradeLevel: String
    var notes: String
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        schoolYear: String = "",
        term: String = "",
        subject: String = "",
        gradeLevel: String = "",
        notes: String = "",
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.schoolYear = schoolYear
        self.term = term
        self.subject = subject
        self.gradeLevel = gradeLevel
        self.notes = notes
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// A student. Class membership lives only in `Enrollment`.
struct Student: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable, Sendable {
    static let databaseTableName = "student"

    var id: UUID
    var displayName: String
    var localIdentifier: String
    var notes: String
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        displayName: String,
        localIdentifier: String = "",
        notes: String = "",
        isActive: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.localIdentifier = localIdentifier
        self.notes = notes
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct EnrollmentID: Hashable, Sendable {
    var classGroupID: UUID
    var studentID: UUID
}

struct Enrollment: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable, Sendable {
    static let databaseTableName = "enrollment"

    var classGroupID: UUID
    var studentID: UUID
    var sortOrder: Int

    var id: EnrollmentID { EnrollmentID(classGroupID: classGroupID, studentID: studentID) }

    init(classGroupID: UUID, studentID: UUID, sortOrder: Int = 0) {
        self.classGroupID = classGroupID
        self.studentID = studentID
        self.sortOrder = sortOrder
    }
}

// MARK: - Roster import

/// One student read from a roster file by `RosterImportService`.
struct RosterImportRow: Equatable, Sendable {
    var displayName: String
    var localIdentifier: String
    var className: String
    var notes: String

    init(displayName: String, localIdentifier: String = "", className: String = "", notes: String = "") {
        self.displayName = displayName
        self.localIdentifier = localIdentifier
        self.className = className
        self.notes = notes
    }
}

/// What happened to a roster: the file-reading half (`RosterImportService`) fills the column and
/// row details; the saving half (`AppDatabase.importRoster`) fills `imported` and `warnings`.
struct RosterImportResult: Equatable, Sendable {
    var imported: Int
    var ignoredBlankColumns: Int
    var unrecognisedColumns: [String]
    var skippedRows: [String]
    var hasHeaderRow: Bool
    var warnings: [String]

    init(
        imported: Int = 0,
        ignoredBlankColumns: Int = 0,
        unrecognisedColumns: [String] = [],
        skippedRows: [String] = [],
        hasHeaderRow: Bool = false,
        warnings: [String] = []
    ) {
        self.imported = imported
        self.ignoredBlankColumns = ignoredBlankColumns
        self.unrecognisedColumns = unrecognisedColumns
        self.skippedRows = skippedRows
        self.hasHeaderRow = hasHeaderRow
        self.warnings = warnings
    }
}
