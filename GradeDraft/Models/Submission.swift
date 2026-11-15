import Foundation
import GRDB

// MARK: - One student's work under a class-level assignment

enum SubmissionInputKind: String, CaseIterable, Codable, Equatable, Sendable {
    case none
    case pasted
    case scanned
}

struct Submission: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable, Sendable {
    static let databaseTableName = "submission"

    var id: UUID
    var assignmentID: UUID
    var studentID: UUID
    var inputKind: SubmissionInputKind
    /// Only for `inputKind == .pasted`.
    var pastedText: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        assignmentID: UUID,
        studentID: UUID,
        inputKind: SubmissionInputKind = .none,
        pastedText: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.assignmentID = assignmentID
        self.studentID = studentID
        self.inputKind = inputKind
        self.pastedText = pastedText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// A submission with everything that belongs to it, assembled by `AppDatabase`.
struct SubmissionGraph: Codable, Equatable, Sendable, Identifiable {
    var submission: Submission
    var student: Student
    var sources: [SourceInputRef]
    var ocr: OCRDocument?
    var draft: GradeDraftResult?
    var finalReview: FinalGradeReview?
    var evidence: [EvidenceReference]
    var exports: [ExportRecord]
    var audit: [AuditEvent]

    init(
        submission: Submission,
        student: Student,
        sources: [SourceInputRef] = [],
        ocr: OCRDocument? = nil,
        draft: GradeDraftResult? = nil,
        finalReview: FinalGradeReview? = nil,
        evidence: [EvidenceReference] = [],
        exports: [ExportRecord] = [],
        audit: [AuditEvent] = []
    ) {
        self.submission = submission
        self.student = student
        self.sources = sources
        self.ocr = ocr
        self.draft = draft
        self.finalReview = finalReview
        self.evidence = evidence
        self.exports = exports
        self.audit = audit
    }

    var id: UUID { submission.id }

    /// The text that is graded: pasted text, or the teacher-reviewed scanned lines.
    var reviewedText: String {
        switch submission.inputKind {
        case .none: return ""
        case .pasted: return submission.pastedText ?? ""
        case .scanned: return ocr?.combinedText ?? ""
        }
    }

    /// SHA-256 of the setup's canonical encoding, a newline, and the reviewed text.
    func packetFingerprint(setup: AssignmentSetup) throws -> String {
        Self.packetFingerprint(setupEncoding: try setup.canonicalEncoding(), reviewedText: reviewedText)
    }

    func draftIsStale(setup: AssignmentSetup) throws -> Bool {
        guard let draft else { return false }
        return draft.packetFingerprint != (try packetFingerprint(setup: setup))
    }

    func finalReviewIsStale(setup: AssignmentSetup) throws -> Bool {
        guard let finalReview else { return false }
        return finalReview.packetFingerprint != (try packetFingerprint(setup: setup))
    }

    func rosterStatus(setup: AssignmentSetup) throws -> RosterStatus {
        try rosterStatus(currentFingerprint: packetFingerprint(setup: setup))
    }

    /// Shared by the store, which encodes each setup once for all of its submissions.
    static func packetFingerprint(setupEncoding: Data, reviewedText: String) -> String {
        var packet = setupEncoding
        packet.append(Data("\n".utf8))
        packet.append(Data(reviewedText.utf8))
        return ContentDigest.sha256Hex(packet)
    }

    func rosterStatus(currentFingerprint: String) -> RosterStatus {
        switch submission.inputKind {
        case .none:
            return .notStarted
        case .scanned:
            guard ocr?.reviewStatus == .reviewed else { return .ocrReviewNeeded }
        case .pasted:
            break
        }
        if let finalReview {
            guard finalReview.packetFingerprint == currentFingerprint else { return .needsRecheck }
            switch finalReview.status {
            case .inProgress:
                return .finalReviewInProgress
            case .approved:
                let finalizedAt = finalReview.finalizedAt ?? finalReview.createdAt
                return exports.contains { $0.createdAt >= finalizedAt } ? .exported : .approved
            }
        }
        if let draft {
            return draft.packetFingerprint == currentFingerprint ? .draftGenerated : .needsRecheck
        }
        return .readyForGrading
    }
}

/// Where a submission stands, computed from its records (never stored).
enum RosterStatus: String, CaseIterable, Equatable, Identifiable, Sendable {
    case notStarted
    case ocrReviewNeeded
    case readyForGrading
    case draftGenerated
    case finalReviewInProgress
    case needsRecheck
    case approved
    case exported

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .notStarted: return "Not started"
        case .ocrReviewNeeded: return "Review scanned text"
        case .readyForGrading: return "Ready for teacher review"
        case .draftGenerated: return "Review final grade"
        case .finalReviewInProgress: return "Review final grade"
        case .needsRecheck: return "Needs recheck"
        case .approved: return "Approved"
        case .exported: return "Exported"
        }
    }
}

// MARK: - List rows

struct AssignmentSummary: Identifiable, Equatable, Sendable {
    var assignment: Assignment
    var className: String
    var submissionCount: Int

    var id: UUID { assignment.id }
}

struct SubmissionSummary: Identifiable, Equatable, Sendable {
    var id: UUID
    var assignmentID: UUID
    var assignmentTitle: String
    var classGroupID: UUID
    var className: String
    var studentID: UUID
    var studentName: String
    var localIdentifier: String
    /// Position of the student in the class roster; nil when the student is no longer enrolled.
    var rosterOrder: Int?
    var rosterStatus: RosterStatus
    var lastExportedAt: Date?
    var updatedAt: Date
}
