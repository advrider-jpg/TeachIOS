import XCTest
import ZIPFoundation
@testable import GradeDraft

final class InMemoryAssignmentStore: AssignmentStoring {
    private(set) var assignments: [AssignmentRecord]
    private(set) var classGroups: [ClassGroupRecord]
    private(set) var students: [StudentRecord]
    private(set) var rosterEntries: [AssignmentRosterEntry]
    var saveAssignmentsError: Error?
    var saveClassGroupError: Error?
    var saveStudentError: Error?
    var saveRosterError: Error?
    var replaceSnapshotError: Error?
    private(set) var saveAssignmentsCallCount = 0
    var appSupportDirectory: URL = FileManager.default.temporaryDirectory

    init(
        assignments: [AssignmentRecord] = [],
        classGroups: [ClassGroupRecord] = [],
        students: [StudentRecord] = [],
        rosterEntries: [AssignmentRosterEntry] = []
    ) {
        self.assignments = assignments
        self.classGroups = classGroups
        self.students = students
        self.rosterEntries = rosterEntries
    }

    func loadAssignments() throws -> [AssignmentRecord] { assignments }
    func saveAssignments(_ assignments: [AssignmentRecord]) throws {
        if let saveAssignmentsError { throw saveAssignmentsError }
        saveAssignmentsCallCount += 1
        self.assignments = assignments
    }
    func deleteAssignment(id: UUID) throws { assignments.removeAll { $0.id == id } }
    func applicationSupportDirectory() throws -> URL { appSupportDirectory }
    func loadClassGroups() throws -> [ClassGroupRecord] { classGroups }
    func saveClassGroup(_ classGroup: ClassGroupRecord) throws {
        if let saveClassGroupError { throw saveClassGroupError }
        if let idx = classGroups.firstIndex(where: { $0.id == classGroup.id }) { classGroups[idx] = classGroup } else { classGroups.append(classGroup) }
    }
    func deleteClassGroup(id: UUID) throws { classGroups.removeAll { $0.id == id } }
    func loadStudents() throws -> [StudentRecord] { students }
    func saveStudent(_ student: StudentRecord) throws {
        if let saveStudentError { throw saveStudentError }
        if let idx = students.firstIndex(where: { $0.id == student.id }) { students[idx] = student } else { students.append(student) }
    }
    func deleteStudent(id: UUID) throws { students.removeAll { $0.id == id } }
    func loadAssignmentRoster(assignmentID: UUID) throws -> [AssignmentRosterEntry] {
        rosterEntries.filter { $0.assignmentID == assignmentID }
    }
    func loadAssignmentRosterSnapshot() throws -> [AssignmentRosterEntry] { rosterEntries }
    func replaceAssignmentRosterSnapshot(_ entries: [AssignmentRosterEntry]) throws {
        if let saveRosterError { throw saveRosterError }
        self.rosterEntries = entries
    }
    func replaceLocalDataSnapshot(_ snapshot: AssignmentStoreSnapshot) throws {
        if let replaceSnapshotError { throw replaceSnapshotError }
        self.assignments = snapshot.assignments
        self.classGroups = snapshot.classGroups
        self.students = snapshot.students
        self.rosterEntries = snapshot.rosterEntries
    }
    func saveSourceInputs(_ sourceInputs: [SourceInputRef], assignmentID: UUID) throws {}
    func saveOCRDocument(_ document: OCRDocument, assignmentID: UUID) throws {}
    func saveFinalReview(_ review: FinalGradeReview, assignmentID: UUID) throws {}
    func saveEvidenceReferences(_ references: [EvidenceReference], assignmentID: UUID) throws {}
    func loadFullAssignmentGraph(id: UUID) throws -> AssignmentRecord? { assignments.first { $0.id == id } }
}

private struct RosterEntryPersistedFields: Equatable {
    let id: UUID
    let assignmentID: UUID
    let studentID: UUID
    let studentDisplayName: String
    let localIdentifier: String
    let status: AssignmentRosterStatus
    let sortOrder: Int

    init(_ entry: AssignmentRosterEntry) {
        id = entry.id
        assignmentID = entry.assignmentID
        studentID = entry.studentID
        studentDisplayName = entry.studentDisplayName
        localIdentifier = entry.localIdentifier
        status = entry.status
        sortOrder = entry.sortOrder
    }
}

private struct StudentPersistedFields: Equatable {
    let id: UUID
    let displayName: String
    let className: String
    let localIdentifier: String
    let notes: String
    let isActive: Bool

    init(_ student: StudentRecord) {
        id = student.id
        displayName = student.displayName
        className = student.className
        localIdentifier = student.localIdentifier
        notes = student.notes
        isActive = student.isActive
    }
}

func assertRosterEntriesPersistedFieldsEqual(
    _ actual: [AssignmentRosterEntry],
    _ expected: [AssignmentRosterEntry],
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertEqual(actual.map(RosterEntryPersistedFields.init), expected.map(RosterEntryPersistedFields.init), file: file, line: line)
}

func assertStudentsPersistedFieldsEqual(
    _ actual: [StudentRecord],
    _ expected: [StudentRecord],
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertEqual(actual.map(StudentPersistedFields.init), expected.map(StudentPersistedFields.init), file: file, line: line)
}

struct StubExportAuthenticationService: ExportAuthenticationServicing {
    var result: ExportAuthenticationResult
    func authenticateForSensitiveExport(reason: String) async -> ExportAuthenticationResult { result }
}

final class SlowCancellableGradingService: GradingServicing, CapabilityChecking, @unchecked Sendable {
    var localAIStatus: LocalAIStatus { .available }

    func draftGrade(input: GradingInput, progress: AIGenerationProgressHandler?) async throws -> GradeDraftResult {
        await progress?(
            AIGenerationProgress(
                stage: .requestingModel,
                detail: "Test service is waiting.",
                completedUnitCount: 0,
                totalUnitCount: 1,
                canCancel: true
            )
        )
        try await Task.sleep(nanoseconds: 5_000_000_000)
        try Task.checkCancellation()
        return GradeDraftResult(
            packetFingerprint: input.packetFingerprint,
            studentResponseSummary: "Summary",
            criteria: [
                CriterionScore(
                    criterionID: input.parsedRubric.criteria.first?.id,
                    criterion: input.parsedRubric.criteria.first?.title ?? "Claim",
                    rating: "Draft",
                    proposedPoints: 1,
                    maxPoints: input.parsedRubric.criteria.first?.maxPoints ?? 1,
                    evidence: [input.reviewedStudentText],
                    explanation: "Draft explanation.",
                    teacherReviewRequired: false
                )
            ],
            totalScore: 1,
            maxScore: input.parsedRubric.criteria.first?.maxPoints ?? 1,
            studentFeedback: "Draft feedback.",
            teacherNotes: "Teacher review required before final approval.",
            uncertaintyFlags: []
        )
    }
}

final class ImmediateProgressGradingService: GradingServicing, CapabilityChecking, @unchecked Sendable {
    var localAIStatus: LocalAIStatus { .available }

    func draftGrade(input: GradingInput, progress: AIGenerationProgressHandler?) async throws -> GradeDraftResult {
        await progress?(
            AIGenerationProgress(
                stage: .validatingInputs,
                detail: "Inputs checked.",
                canCancel: true
            )
        )
        return GradeDraftResult(
            packetFingerprint: input.packetFingerprint,
            studentResponseSummary: "Summary",
            criteria: [
                CriterionScore(
                    criterionID: input.parsedRubric.criteria.first?.id,
                    criterion: input.parsedRubric.criteria.first?.title ?? "Claim",
                    rating: "Draft",
                    proposedPoints: 1,
                    maxPoints: input.parsedRubric.criteria.first?.maxPoints ?? 1,
                    evidence: [input.reviewedStudentText],
                    explanation: "Draft explanation.",
                    teacherReviewRequired: false
                )
            ],
            totalScore: 1,
            maxScore: input.parsedRubric.criteria.first?.maxPoints ?? 1,
            studentFeedback: "Draft feedback.",
            teacherNotes: "Teacher review required before final approval.",
            uncertaintyFlags: []
        )
    }
}

final class ImmediateRewriteGradingService: GradingServicing, CapabilityChecking, @unchecked Sendable {
    var localAIStatus: LocalAIStatus { .available }

    func draftGrade(input: GradingInput, progress: AIGenerationProgressHandler?) async throws -> GradeDraftResult {
        try await ImmediateProgressGradingService().draftGrade(input: input, progress: progress)
    }

    func rewriteFeedback(input: FeedbackRewriteInput, progress: AIGenerationProgressHandler?) async throws -> FeedbackRewriteResult {
        await progress?(
            AIGenerationProgress(
                stage: .rewritingFeedback,
                detail: "Rewriting feedback.",
                canCancel: true
            )
        )
        return FeedbackRewriteResult(
            rewrittenFeedback: "The response states a clear claim and can improve by adding one more supporting detail.",
            teacherReviewNotes: ["Review rewritten feedback before export."]
        )
    }
}

@MainActor
final class GradeDraftTests: XCTestCase {
    func sampleInput(rubric: String = "Claim: 0-4 points") -> GradingInput {
        let parsed = RubricParser.parse(rubric)
        return GradingInput(
            assignmentID: UUID(),
            assignmentTitle: "Essay",
            prompt: "",
            subject: "ELA",
            gradeLevel: "6",
            className: "6A",
            studentDisplayName: "Student A",
            assignmentType: .essay,
            rubricText: rubric,
            parsedRubric: parsed,
            customInstructions: "",
            answerKeyText: "",
            exemplarText: "",
            assessmentPurpose: .summative,
            curriculumReference: "",
            reviewedStudentText: "Student response",
            reviewedTextWithSourceRefs: "Student response",
            ocrQualitySummary: OCRQualitySummary(),
            ocrReviewStatus: .notNeeded,
            sourceInputCount: 1,
            packetFingerprint: "packet-1",
            hasGradingStandard: !rubric.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
    }
}
