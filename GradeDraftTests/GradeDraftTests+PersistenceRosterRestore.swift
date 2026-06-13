import XCTest
import UIKit
import ZIPFoundation
@testable import GradeDraft

private enum ImportTransactionTestError: Error {
    case injectedOCRFailure
    case injectedSaveFailure
}

private final class ImportTransactionOCRService: OCRServicing, @unchecked Sendable {
    var result: Result<OCRDocument, Error>

    init(result: Result<OCRDocument, Error>) {
        self.result = result
    }

    func recognizeText(in images: [UIImage]) async throws -> OCRDocument {
        try result.get()
    }
}

private func makeImportTransactionImage() -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 60))
    return renderer.image { context in
        UIColor.white.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 80, height: 60))
        UIColor.black.setFill()
        UIBezierPath(rect: CGRect(x: 8, y: 12, width: 64, height: 8)).fill()
    }
}

private func makeImportTransactionPDF() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("import-transaction-\(UUID()).pdf")
    let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 160, height: 120))
    try renderer.writePDF(to: url) { context in
        context.beginPage()
        UIColor.white.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 160, height: 120))
        UIColor.black.setFill()
        UIBezierPath(rect: CGRect(x: 16, y: 24, width: 96, height: 10)).fill()
    }
    return url
}

private func regularFilesUnder(_ root: URL) -> [URL] {
    guard let enumerator = FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else { return [] }
    return enumerator.compactMap { item in
        guard let url = item as? URL else { return nil }
        let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
        return values?.isRegularFile == true ? url : nil
    }
}

extension GradeDraftTests {
    func testCanApproveAndPersistFinalReviewWhenAllCriteriaApproved() {
        let criterion = FinalCriterionScore(
            criterionID: "claim",
            criterion: "Claim",
            rating: "Proficient",
            proposedPoints: 3,
            finalPoints: 3,
            maxPoints: 4,
            evidence: ["Evidence"],
            explanation: "Strong claim.",
            teacherApproved: true
        )
        let assignment = AssignmentRecord(
            title: "Essay",
            subject: "ELA",
            gradeLevel: "7",
            studentDisplayName: "Kai",
            assignmentType: .essay,
            reviewedStudentText: "Student response",
            latestDraft: nil,
            finalReview: FinalGradeReview(
                packetFingerprint: "packet-1",
                status: .inProgress,
                criteria: [criterion],
                totalScore: 0,
                maxScore: 0,
                studentFeedback: "Good.",
                privateTeacherNotes: "Hidden",
                teacherEdited: true
            )
        )

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        XCTAssertTrue(viewModel.canApproveFinalReview)
        viewModel.approveFinalReview()
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.assignment.finalReview?.status, .approved)
        XCTAssertNotNil(viewModel.assignment.finalReview?.finalizedAt)
    }

    @MainActor
    func testGRDBStoreRoundTripsAssignmentsAndDeletes() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraftTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let store = try GRDBAssignmentStore(applicationSupportURL: root)

        let oldDate = Date(timeIntervalSince1970: 1_700_000_000)
        let assignmentA = AssignmentRecord(
            id: UUID(),
            title: "Essay 1",
            subject: "History",
            gradeLevel: "9",
            studentDisplayName: "Alex",
            assignmentType: .essay,
            reviewedStudentText: "Reviewed text",
            ocrReviewStatus: .reviewed,
            latestDraft: GradeDraftResult(
                generatedAt: oldDate,
                studentResponseSummary: "Summary",
                criteria: [
                    CriterionScore(
                        criterionID: "claim",
                        criterion: "Claim",
                        rating: "Proficient",
                        proposedPoints: 2,
                        maxPoints: 2,
                        evidence: ["Evidence"],
                        explanation: "Good",
                        teacherReviewRequired: false
                    )
                ],
                totalScore: 2,
                maxScore: 2,
                studentFeedback: "Nice",
                teacherNotes: "",
                uncertaintyFlags: []
            ),
            createdAt: oldDate,
            updatedAt: oldDate
        )

        let assignmentB = AssignmentRecord(
            id: UUID(),
            title: "Response",
            subject: "Math",
            gradeLevel: "8",
            studentDisplayName: "Bri",
            assignmentType: .shortAnswer,
            reviewedStudentText: "Short answer",
            ocrReviewStatus: .reviewed,
            createdAt: oldDate.addingTimeInterval(1),
            updatedAt: oldDate.addingTimeInterval(1)
        )

        try store.saveAssignments([assignmentA, assignmentB])
        let loaded = try store.loadAssignments()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertTrue(loaded.contains(assignmentB))
        XCTAssertTrue(loaded.contains(assignmentA))

        try store.deleteAssignment(id: assignmentA.id)
        let afterDelete = try store.loadAssignments()
        XCTAssertEqual(afterDelete.count, 1)
        XCTAssertEqual(afterDelete[0].id, assignmentB.id)
    }

    func testGRDBAssignmentRosterSaveReplacesRemovedEntries() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraftRoster-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = try GRDBAssignmentStore(applicationSupportURL: root)
        let entryA = AssignmentRosterEntry(assignmentID: UUID(), studentID: UUID(), studentDisplayName: "Alex", sortOrder: 0)
        let entryB = AssignmentRosterEntry(assignmentID: UUID(), studentID: UUID(), studentDisplayName: "Bri", sortOrder: 1)

        try store.replaceAssignmentRosterSnapshot([entryA, entryB])
        try store.replaceAssignmentRosterSnapshot([entryB])

        XCTAssertTrue(try store.loadAssignmentRoster(assignmentID: entryA.assignmentID).isEmpty)
        assertRosterEntriesPersistedFieldsEqual(try store.loadAssignmentRoster(assignmentID: entryB.assignmentID), [entryB])
    }

    func testGRDBDeletingAssignmentRemovesRosterRows() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraftRosterDeleteAssignment-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = try GRDBAssignmentStore(applicationSupportURL: root)
        let student = StudentRecord(displayName: "Alex")
        let keptStudent = StudentRecord(displayName: "Bri")
        let removed = AssignmentRecord(studentID: student.id, title: "Removed", studentDisplayName: student.displayName)
        let kept = AssignmentRecord(studentID: keptStudent.id, title: "Kept", studentDisplayName: keptStudent.displayName)
        let removedEntry = AssignmentRosterEntry(assignmentID: removed.id, studentID: student.id, studentDisplayName: student.displayName)
        let keptEntry = AssignmentRosterEntry(assignmentID: kept.id, studentID: keptStudent.id, studentDisplayName: keptStudent.displayName)

        try store.saveStudent(student)
        try store.saveStudent(keptStudent)
        try store.saveAssignments([removed, kept])
        try store.replaceAssignmentRosterSnapshot([removedEntry, keptEntry])
        try store.deleteAssignment(id: removed.id)

        XCTAssertTrue(try store.loadAssignmentRoster(assignmentID: removed.id).isEmpty)
        assertRosterEntriesPersistedFieldsEqual(try store.loadAssignmentRoster(assignmentID: kept.id), [keptEntry])
    }

    func testGRDBSavingAssignmentsPreservesExistingRosterRowsForKeptAssignments() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraftRosterUpdatePreserve-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = try GRDBAssignmentStore(applicationSupportURL: root)
        let student = StudentRecord(displayName: "Alex")
        var assignment = AssignmentRecord(studentID: student.id, title: "Draft", studentDisplayName: student.displayName)
        let entry = AssignmentRosterEntry(assignmentID: assignment.id, studentID: student.id, studentDisplayName: student.displayName)

        try store.saveStudent(student)
        try store.saveAssignments([assignment])
        try store.replaceAssignmentRosterSnapshot([entry])
        assignment.title = "Draft updated"
        try store.saveAssignments([assignment])

        assertRosterEntriesPersistedFieldsEqual(try store.loadAssignmentRoster(assignmentID: assignment.id), [entry])
    }

    func testGRDBDeletingStudentRemovesRosterRows() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraftRosterDeleteStudent-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = try GRDBAssignmentStore(applicationSupportURL: root)
        let removedStudent = StudentRecord(displayName: "Alex")
        let keptStudent = StudentRecord(displayName: "Bri")
        let removedAssignment = AssignmentRecord(studentID: removedStudent.id, title: "Alex work", studentDisplayName: removedStudent.displayName)
        let keptAssignment = AssignmentRecord(studentID: keptStudent.id, title: "Bri work", studentDisplayName: keptStudent.displayName)
        let removedEntry = AssignmentRosterEntry(assignmentID: removedAssignment.id, studentID: removedStudent.id, studentDisplayName: removedStudent.displayName)
        let keptEntry = AssignmentRosterEntry(assignmentID: keptAssignment.id, studentID: keptStudent.id, studentDisplayName: keptStudent.displayName)

        try store.saveStudent(removedStudent)
        try store.saveStudent(keptStudent)
        try store.saveAssignments([removedAssignment, keptAssignment])
        try store.replaceAssignmentRosterSnapshot([removedEntry, keptEntry])
        try store.deleteStudent(id: removedStudent.id)

        XCTAssertTrue(try store.loadAssignmentRoster(assignmentID: removedAssignment.id).isEmpty)
        assertRosterEntriesPersistedFieldsEqual(try store.loadAssignmentRoster(assignmentID: keptAssignment.id), [keptEntry])
    }

    func testGRDBSnapshotReplacementRemovesStaleRosterRows() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraftRosterSnapshot-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = try GRDBAssignmentStore(applicationSupportURL: root)
        let staleStudent = StudentRecord(displayName: "Stale")
        let staleAssignment = AssignmentRecord(studentID: staleStudent.id, title: "Stale", studentDisplayName: staleStudent.displayName)
        let staleEntry = AssignmentRosterEntry(assignmentID: staleAssignment.id, studentID: staleStudent.id, studentDisplayName: staleStudent.displayName)
        let freshStudent = StudentRecord(displayName: "Fresh")
        let freshAssignment = AssignmentRecord(studentID: freshStudent.id, title: "Fresh", studentDisplayName: freshStudent.displayName)
        let freshEntry = AssignmentRosterEntry(assignmentID: freshAssignment.id, studentID: freshStudent.id, studentDisplayName: freshStudent.displayName)

        try store.replaceLocalDataSnapshot(
            AssignmentStoreSnapshot(assignments: [staleAssignment], classGroups: [], students: [staleStudent], rosterEntries: [staleEntry])
        )
        try store.replaceLocalDataSnapshot(
            AssignmentStoreSnapshot(assignments: [freshAssignment], classGroups: [], students: [freshStudent], rosterEntries: [freshEntry])
        )

        XCTAssertTrue(try store.loadAssignmentRoster(assignmentID: staleAssignment.id).isEmpty)
        assertRosterEntriesPersistedFieldsEqual(try store.loadAssignmentRoster(assignmentID: freshAssignment.id), [freshEntry])
        assertStudentsPersistedFieldsEqual(try store.loadStudents(), [freshStudent])
        XCTAssertEqual(try store.loadAssignments().map(\.id), [freshAssignment.id])
    }

    func testLocalJSONAssignmentRosterSaveReplacesRemovedEntries() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraftJSONRoster-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalJSONStore(applicationSupportURL: root)
        let entryA = AssignmentRosterEntry(assignmentID: UUID(), studentID: UUID(), studentDisplayName: "Alex", sortOrder: 0)
        let entryB = AssignmentRosterEntry(assignmentID: UUID(), studentID: UUID(), studentDisplayName: "Bri", sortOrder: 1)

        try store.replaceAssignmentRosterSnapshot([entryA, entryB])
        try store.replaceAssignmentRosterSnapshot([entryB])

        XCTAssertTrue(try store.loadAssignmentRoster(assignmentID: entryA.assignmentID).isEmpty)
        assertRosterEntriesPersistedFieldsEqual(try store.loadAssignmentRoster(assignmentID: entryB.assignmentID), [entryB])
    }

    func testLocalJSONDeletingAssignmentRemovesRosterRows() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraftJSONRosterDeleteAssignment-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalJSONStore(applicationSupportURL: root)
        let student = StudentRecord(displayName: "Alex")
        let keptStudent = StudentRecord(displayName: "Bri")
        let removed = AssignmentRecord(studentID: student.id, title: "Removed", studentDisplayName: student.displayName)
        let kept = AssignmentRecord(studentID: keptStudent.id, title: "Kept", studentDisplayName: keptStudent.displayName)
        let removedEntry = AssignmentRosterEntry(assignmentID: removed.id, studentID: student.id, studentDisplayName: student.displayName)
        let keptEntry = AssignmentRosterEntry(assignmentID: kept.id, studentID: keptStudent.id, studentDisplayName: keptStudent.displayName)

        try store.saveStudent(student)
        try store.saveStudent(keptStudent)
        try store.saveAssignments([removed, kept])
        try store.replaceAssignmentRosterSnapshot([removedEntry, keptEntry])
        try store.deleteAssignment(id: removed.id)

        XCTAssertTrue(try store.loadAssignmentRoster(assignmentID: removed.id).isEmpty)
        assertRosterEntriesPersistedFieldsEqual(try store.loadAssignmentRoster(assignmentID: kept.id), [keptEntry])
    }

    func testLocalJSONSavingAssignmentsPreservesExistingRosterRowsForKeptAssignments() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraftJSONRosterUpdatePreserve-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalJSONStore(applicationSupportURL: root)
        let student = StudentRecord(displayName: "Alex")
        var assignment = AssignmentRecord(studentID: student.id, title: "Draft", studentDisplayName: student.displayName)
        let entry = AssignmentRosterEntry(assignmentID: assignment.id, studentID: student.id, studentDisplayName: student.displayName)

        try store.saveStudent(student)
        try store.saveAssignments([assignment])
        try store.replaceAssignmentRosterSnapshot([entry])
        assignment.title = "Draft updated"
        try store.saveAssignments([assignment])

        assertRosterEntriesPersistedFieldsEqual(try store.loadAssignmentRoster(assignmentID: assignment.id), [entry])
    }

    func testLocalJSONDeletingStudentRemovesRosterRows() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraftJSONRosterDeleteStudent-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalJSONStore(applicationSupportURL: root)
        let removedStudent = StudentRecord(displayName: "Alex")
        let keptStudent = StudentRecord(displayName: "Bri")
        let removedAssignment = AssignmentRecord(studentID: removedStudent.id, title: "Alex work", studentDisplayName: removedStudent.displayName)
        let keptAssignment = AssignmentRecord(studentID: keptStudent.id, title: "Bri work", studentDisplayName: keptStudent.displayName)
        let removedEntry = AssignmentRosterEntry(assignmentID: removedAssignment.id, studentID: removedStudent.id, studentDisplayName: removedStudent.displayName)
        let keptEntry = AssignmentRosterEntry(assignmentID: keptAssignment.id, studentID: keptStudent.id, studentDisplayName: keptStudent.displayName)

        try store.saveStudent(removedStudent)
        try store.saveStudent(keptStudent)
        try store.saveAssignments([removedAssignment, keptAssignment])
        try store.replaceAssignmentRosterSnapshot([removedEntry, keptEntry])
        try store.deleteStudent(id: removedStudent.id)

        XCTAssertTrue(try store.loadAssignmentRoster(assignmentID: removedAssignment.id).isEmpty)
        assertRosterEntriesPersistedFieldsEqual(try store.loadAssignmentRoster(assignmentID: keptAssignment.id), [keptEntry])
    }

    func testLocalJSONSnapshotReplacementRemovesStaleRosterRows() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraftJSONRosterSnapshot-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalJSONStore(applicationSupportURL: root)
        let staleStudent = StudentRecord(displayName: "Stale")
        let staleAssignment = AssignmentRecord(studentID: staleStudent.id, title: "Stale", studentDisplayName: staleStudent.displayName)
        let staleEntry = AssignmentRosterEntry(assignmentID: staleAssignment.id, studentID: staleStudent.id, studentDisplayName: staleStudent.displayName)
        let freshStudent = StudentRecord(displayName: "Fresh")
        let freshAssignment = AssignmentRecord(studentID: freshStudent.id, title: "Fresh", studentDisplayName: freshStudent.displayName)
        let freshEntry = AssignmentRosterEntry(assignmentID: freshAssignment.id, studentID: freshStudent.id, studentDisplayName: freshStudent.displayName)

        try store.replaceLocalDataSnapshot(
            AssignmentStoreSnapshot(assignments: [staleAssignment], classGroups: [], students: [staleStudent], rosterEntries: [staleEntry])
        )
        try store.replaceLocalDataSnapshot(
            AssignmentStoreSnapshot(assignments: [freshAssignment], classGroups: [], students: [freshStudent], rosterEntries: [freshEntry])
        )

        XCTAssertTrue(try store.loadAssignmentRoster(assignmentID: staleAssignment.id).isEmpty)
        assertRosterEntriesPersistedFieldsEqual(try store.loadAssignmentRoster(assignmentID: freshAssignment.id), [freshEntry])
        assertStudentsPersistedFieldsEqual(try store.loadStudents(), [freshStudent])
        XCTAssertEqual(try store.loadAssignments().map(\.id), [freshAssignment.id])
    }

    func testLocalJSONStoreSurfacesCorruptRosterFile() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraftCorruptRoster-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalJSONStore(applicationSupportURL: root)
        let supportDirectory = try store.applicationSupportDirectory()
        let rosterURL = supportDirectory.appendingPathComponent("roster-v3.json")
        try Data("{".utf8).write(to: rosterURL)

        XCTAssertThrowsError(try store.loadAssignmentRoster(assignmentID: UUID())) { error in
            XCTAssertTrue(error.localizedDescription.contains("roster-v3.json"))
        }
    }

    func testGRDBInjectedRootIsRespectedAndNotDefaultDirectory() throws {
        let injectedRoot = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraftInjected-\(UUID())")
        defer { try? FileManager.default.removeItem(at: injectedRoot) }
        try FileManager.default.createDirectory(at: injectedRoot, withIntermediateDirectories: true)

        let store = try GRDBAssignmentStore(applicationSupportURL: injectedRoot)
        let supportDir = try store.applicationSupportDirectory()

        // The support directory must be inside the injected root, not the default App Support path
        XCTAssertTrue(supportDir.path.hasPrefix(injectedRoot.path),
                      "Expected support dir \(supportDir.path) to be under injected root \(injectedRoot.path)")

        let defaultAppSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        if let defaultPath = defaultAppSupport?.appendingPathComponent("GradeDraft").path {
            XCTAssertNotEqual(supportDir.path, defaultPath,
                              "Injected root should produce a different path than the default App Support path")
        }
    }

    func testGRDBBootstrapIsIdempotent() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraftBootstrap-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let store1 = try GRDBAssignmentStore(applicationSupportURL: root)
        let store2 = try GRDBAssignmentStore(applicationSupportURL: root)

        // Both bootstraps should succeed; loading on an already-migrated DB should not throw
        let assignments = [AssignmentRecord(title: "Idempotent test")]
        try store1.saveAssignments(assignments)
        let loaded = try store2.loadAssignments()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].title, "Idempotent test")
    }

    func testStudentReportExcludesPrivateTeacherNotes() {
        var assignment = AssignmentRecord(title: "Response 1", subject: "ELA", gradeLevel: "5")
        assignment.reviewedStudentText = "Student text"
        assignment.rubricText = "Claim: 0-4 points"
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .approved,
            criteria: [FinalCriterionScore(
                criterionID: "claim",
                criterion: "Claim",
                rating: "Proficient",
                proposedPoints: 3,
                finalPoints: 4,
                maxPoints: 4,
                evidence: ["Student text"],
                explanation: "Clear claim.",
                teacherApproved: true
            )],
            totalScore: 4,
            maxScore: 4,
            studentFeedback: "Good claim.",
            privateTeacherNotes: "Sensitive private note.",
            teacherEdited: true
        )

        let student = MarkdownReportBuilder.studentMarkdown(for: assignment)
        XCTAssertTrue(student.contains("Final teacher-approved grade"))
        XCTAssertTrue(student.contains("Good claim."))
        XCTAssertFalse(student.contains("Sensitive private note"))

        let audit = MarkdownReportBuilder.teacherAuditMarkdown(for: assignment)
        XCTAssertTrue(audit.contains("Sensitive private note"))
    }

    // MARK: - Content-source consistency tests

    func testPromptPersistsInGRDBRoundTrip() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraftPrompt-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let store = try GRDBAssignmentStore(applicationSupportURL: root)
        var record = AssignmentRecord(title: "Prompt persistence test")
        record.prompt = "Describe the water cycle."

        try store.saveAssignments([record])
        let loaded = try store.loadAssignments()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].prompt, "Describe the water cycle.")
    }

    func testLaunchRequestPayloadRoundTripsThroughStore() {
        let defaults = UserDefaults(suiteName: "GradeDraftTests.\(UUID().uuidString)")!
        let id = UUID()
        let request = AppLaunchRequest(
            destination: .studentWork,
            assignmentID: id,
            action: .applyPastedStudentText,
            payloadText: "Student answer"
        )

        AppLaunchRequestStore.save(request, defaults: defaults)

        XCTAssertEqual(AppLaunchRequestStore.consume(defaults: defaults), request)
        XCTAssertNil(AppLaunchRequestStore.consume(defaults: defaults))
    }

    @MainActor
    func testShortcutPastedStudentWorkActionSavesReviewedInputLocally() {
        var assignment = AssignmentRecord(
            title: "Short answer",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: "Old text"
        )
        assignment.latestDraft = GradeDraftResult(
            packetFingerprint: "old-packet",
            studentResponseSummary: "Old",
            criteria: [],
            totalScore: 0,
            maxScore: 0,
            studentFeedback: "Old",
            teacherNotes: "Old",
            uncertaintyFlags: []
        )
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: "old-packet",
            criteria: [FinalCriterionScore(
                criterion: "Claim",
                rating: "",
                proposedPoints: 1,
                finalPoints: 1,
                maxPoints: 2,
                evidence: [],
                explanation: "",
                teacherApproved: true
            )],
            totalScore: 1,
            maxScore: 2,
            studentFeedback: "",
            privateTeacherNotes: "",
            teacherEdited: true
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.handleLaunchRequest(AppLaunchRequest(
            destination: .studentWork,
            assignmentID: assignment.id,
            action: .applyPastedStudentText,
            payloadText: "  New student answer  "
        ))

        XCTAssertEqual(viewModel.assignment.reviewedStudentText, "New student answer")
        XCTAssertEqual(viewModel.assignment.ocrReviewStatus, .notNeeded)
        XCTAssertEqual(viewModel.assignment.sourceInputs.first?.sourceType, .pastedText)
        XCTAssertNil(viewModel.assignment.latestDraft)
        XCTAssertNil(viewModel.assignment.finalReview)
        XCTAssertTrue(viewModel.statusMessage.contains("saved locally"))
    }

    @MainActor
    func testShortcutPastedStudentWorkRequiresExplicitAssignmentTarget() {
        let assignment = AssignmentRecord(
            title: "Do not replace",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: "Keep this reviewed text"
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.handleLaunchRequest(AppLaunchRequest(
            destination: .studentWork,
            action: .applyPastedStudentText,
            payloadText: "New shortcut text"
        ))

        XCTAssertEqual(viewModel.assignment.reviewedStudentText, "Keep this reviewed text")
        XCTAssertEqual(store.assignments.first?.reviewedStudentText, "Keep this reviewed text")
        XCTAssertTrue(viewModel.errorMessage?.contains("choose an assignment") == true)
    }

    @MainActor
    func testShortcutRecommendedAIConstraintsPersistWithoutSensitiveTemplates() {
        let assignment = AssignmentRecord(
            title: "Short answer",
            assessmentPurpose: .summative,
            rubricText: "Claim: 0-2 points",
            answerKeyText: "Expected claim.",
            reviewedStudentText: "Student wrote a claim.",
            ocrReviewStatus: .notNeeded
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.handleLaunchRequest(AppLaunchRequest(
            destination: .packetPreview,
            assignmentID: assignment.id,
            action: .applyRecommendedAIConstraints
        ))

        XCTAssertFalse(viewModel.assignment.selectedInstructionTemplateIDs.isEmpty)
        XCTAssertFalse(viewModel.assignment.selectedInstructionTemplateIDs.contains("eald-sensitive"))
        XCTAssertFalse(viewModel.assignment.selectedInstructionTemplateIDs.contains("adjustment-context"))
    }

    @MainActor
    func testCriterionAcceptAndRejectActionsPersistTeacherDecision() {
        var assignment = AssignmentRecord(
            title: "Essay",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: "Student text."
        )
        let criterionID = UUID()
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            criteria: [FinalCriterionScore(
                id: criterionID,
                criterion: "Claim",
                rating: "Developing",
                proposedPoints: 3,
                finalPoints: 0,
                maxPoints: 2,
                evidence: [],
                explanation: "Draft explanation.",
                teacherApproved: false
            )],
            totalScore: 0,
            maxScore: 2,
            studentFeedback: "",
            privateTeacherNotes: "",
            teacherEdited: false
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.acceptFinalReviewCriterion(id: criterionID)
        XCTAssertEqual(viewModel.assignment.finalReview?.criteria.first?.finalPoints, 2)
        XCTAssertEqual(viewModel.assignment.finalReview?.criteria.first?.teacherApproved, true)
        XCTAssertEqual(viewModel.assignment.finalReview?.status, .inProgress)

        viewModel.rejectFinalReviewCriterion(id: criterionID)
        XCTAssertEqual(viewModel.assignment.finalReview?.criteria.first?.teacherApproved, false)
        XCTAssertTrue(viewModel.assignment.finalReview?.criteria.first?.teacherRationale.contains("rejected") == true)
    }

    @MainActor
    func testApprovedManualFinalReviewEnablesStudentExport() {
        var assignment = AssignmentRecord(
            title: "Essay",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: "Student text."
        )
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .approved,
            criteria: [FinalCriterionScore(
                criterion: "Claim",
                rating: "",
                proposedPoints: 0,
                finalPoints: 2,
                maxPoints: 2,
                evidence: [],
                explanation: "",
                teacherApproved: true
            )],
            totalScore: 2,
            maxScore: 2,
            studentFeedback: "Good work.",
            privateTeacherNotes: "",
            teacherEdited: true
        )

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        XCTAssertTrue(viewModel.canExportStudentReport, "Approved manual final review should enable student export")
    }

    func testManualFinalReviewSurvivesGRDBRoundTrip() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraftManual-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let store = try GRDBAssignmentStore(applicationSupportURL: root)

        var assignment = AssignmentRecord(title: "Manual review round trip")
        assignment.rubricText = "Claim: 0-2 points"
        assignment.reviewedStudentText = "Student wrote this."
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .inProgress,
            criteria: [FinalCriterionScore(
                criterionID: "criterion-1",
                criterion: "Claim",
                rating: "",
                proposedPoints: 0,
                finalPoints: 1,
                maxPoints: 2,
                evidence: ["Student wrote this."],
                explanation: "Partial claim.",
                teacherApproved: false,
                teacherRationale: "Manual teacher-created final review."
            )],
            totalScore: 1,
            maxScore: 2,
            studentFeedback: "",
            privateTeacherNotes: "My private note",
            teacherEdited: false
        )

        try store.saveAssignments([assignment])
        let loaded = try store.loadAssignments()

        XCTAssertEqual(loaded.count, 1)
        let loadedReview = loaded[0].finalReview
        XCTAssertNotNil(loadedReview)
        XCTAssertEqual(loadedReview?.criteria.count, 1)
        XCTAssertEqual(loadedReview?.criteria[0].criterion, "Claim")
        XCTAssertEqual(loadedReview?.criteria[0].finalPoints, 1)
        XCTAssertEqual(loadedReview?.privateTeacherNotes, "My private note")
    }

    // MARK: - Criterion management tests

    @MainActor
    func testStudentReportBlockedWithoutApprovedFinalReview() {
        let assignment = AssignmentRecord(
            title: "Essay",
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: "Student text."
        )
        // No finalReview at all
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)
        XCTAssertFalse(viewModel.canExportStudentReport, "Student export blocked without final review")
    }

    @MainActor
    func testStudentReportBlockedWhenFinalReviewIsStale() {
        var assignment = AssignmentRecord(
            title: "Essay",
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: "Student text."
        )
        // finalReview with a different packet fingerprint (stale)
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: "stale-fingerprint",
            status: .approved,
            criteria: [FinalCriterionScore(
                criterion: "Claim",
                rating: "",
                proposedPoints: 3,
                finalPoints: 3,
                maxPoints: 4,
                evidence: ["student text"],
                explanation: "Good.",
                teacherApproved: true
            )],
            totalScore: 3,
            maxScore: 4,
            studentFeedback: "Good.",
            privateTeacherNotes: "",
            teacherEdited: true
        )

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        XCTAssertTrue(viewModel.assignment.finalReviewIsStale, "Final review should be stale")
        XCTAssertFalse(viewModel.canExportStudentReport, "Student export blocked when stale")
    }

    @MainActor
    func testStudentReportExcludesRawModelResponse() {
        var assignment = AssignmentRecord(title: "Essay", subject: "ELA", gradeLevel: "6")
        assignment.reviewedStudentText = "Student text"
        assignment.rubricText = "Claim: 0-4 points"
        assignment.latestDraft = GradeDraftResult(
            studentResponseSummary: "Summary",
            criteria: [],
            totalScore: 0,
            maxScore: 0,
            studentFeedback: "Draft feedback",
            teacherNotes: "Private model note.",
            uncertaintyFlags: [],
            rawModelResponse: "Raw JSON blob should not appear"
        )
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .approved,
            criteria: [FinalCriterionScore(
                criterion: "Claim",
                rating: "",
                proposedPoints: 0,
                finalPoints: 3,
                maxPoints: 4,
                evidence: [],
                explanation: "",
                teacherApproved: true
            )],
            totalScore: 3,
            maxScore: 4,
            studentFeedback: "Teacher final feedback.",
            privateTeacherNotes: "",
            teacherEdited: true
        )

        let report = MarkdownReportBuilder.studentMarkdown(for: assignment)
        XCTAssertFalse(report.contains("Raw JSON blob"), "Student report must not include raw model response")
        XCTAssertFalse(report.contains("Private model note"), "Student report must not include raw model teacher notes")
        XCTAssertTrue(report.contains("Teacher final feedback"), "Student report should include teacher final feedback")
    }

    func testDeleteAssignmentRemovesRecord() {
        let assignment = AssignmentRecord(title: "To delete", rubricText: "Claim: 0-4 points")
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        XCTAssertEqual(viewModel.assignments.count, 1)
        viewModel.deleteCurrentAssignment()
        // After deletion one blank starter assignment is created if empty
        XCTAssertFalse(viewModel.assignments.contains { $0.id == assignment.id }, "Deleted assignment should not remain")
    }

    @MainActor
    func testEvidenceReferenceModelStoresBoundingBoxTraceability() {
        let sourceID = UUID()
        let lineID = UUID()
        let reference = EvidenceReference(
            sourceInputID: sourceID,
            ocrLineID: lineID,
            pageIndex: 0,
            quote: "Student evidence",
            startOffset: 0,
            endOffset: 16,
            boundingBox: NormalizedRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
            sourceKind: "ocrLine",
            teacherConfirmed: true
        )
        XCTAssertEqual(reference.sourceInputID, sourceID)
        XCTAssertEqual(reference.ocrLineID, lineID)
        XCTAssertEqual(reference.boundingBox?.width, 0.3)
        XCTAssertTrue(reference.displaySource.contains("page 1"))
    }

    func testStudentReportDoesNotExposeEvidenceSourceRefs() {
        var assignment = AssignmentRecord(title: "Privacy", reviewedStudentText: "Evidence")
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .approved,
            criteria: [FinalCriterionScore(
                criterion: "Claim",
                rating: "",
                proposedPoints: 0,
                finalPoints: 1,
                maxPoints: 1,
                evidence: ["Evidence"],
                evidenceSourceRefs: ["source:secret:page:0:ocrLine:secret"],
                explanation: "Evidence supports claim.",
                teacherApproved: true
            )],
            totalScore: 1,
            maxScore: 1,
            studentFeedback: "Good.",
            privateTeacherNotes: "Private",
            teacherEdited: true
        )
        let report = MarkdownReportBuilder.studentMarkdown(for: assignment)
        XCTAssertFalse(report.contains("source:secret"))
        XCTAssertFalse(report.contains("Private"))
    }

    func testFullBackupArchiveCanBeReadBack() throws {
        let assignment = AssignmentRecord(title: "Backup", reviewedStudentText: "Text")
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("backup-\(UUID()).zip")
        defer { try? FileManager.default.removeItem(at: destination) }
        let written = try BundleExportService.writeFullBackup(assignments: [assignment], sourceFiles: [], to: destination)
        let restored = try BundleExportService.readBackupAssignments(from: written)
        XCTAssertEqual(restored.count, 1)
        XCTAssertEqual(restored[0].title, "Backup")
    }

    func testSourceInputStoresPDFMetadata() {
        let source = SourceInputRef(sourceType: .pdf, fileName: "work.pdf", mimeType: "application/pdf", pdfPageCount: 2)
        XCTAssertEqual(source.fileName, "work.pdf")
        XCTAssertEqual(source.mimeType, "application/pdf")
        XCTAssertEqual(source.pdfPageCount, 2)
    }

    func testStudentReportDoesNotRequireAuthentication() async {
        let alwaysDeny = StubExportAuthenticationService(result: ExportAuthenticationResult(allowed: false, authenticationPerformed: true, message: "Denied"))
        let assignment = AssignmentRecord(title: "Test")
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let vm = GradeDraftViewModel(assignments: [assignment], store: store, exportAuthenticationService: alwaysDeny)
        let allowed = await vm.authenticateForExportIfNeeded(.studentMarkdown)
        XCTAssertTrue(allowed, "Student-facing exports must not require authentication")
        XCTAssertNil(vm.lastExportAuthenticationResult, "No auth result should be set for student exports")
    }

    @MainActor
    func testFullBackupBlockedWhenAuthFails() async {
        let alwaysDeny = StubExportAuthenticationService(result: ExportAuthenticationResult(allowed: false, authenticationPerformed: true, message: nil))
        let assignment = AssignmentRecord(title: "Test")
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let vm = GradeDraftViewModel(assignments: [assignment], store: store, exportAuthenticationService: alwaysDeny)
        await vm.performConfirmedExport(.fullBackup)
        XCTAssertNil(vm.exportURL, "Full backup must not be created when auth fails")
    }

    @MainActor
    func testPreviewBackupRestoreDoesNotMutateAssignments() throws {
        let local = AssignmentRecord(title: "Local")
        let store = InMemoryAssignmentStore(assignments: [local])
        let vm = GradeDraftViewModel(assignments: [local], store: store)
        let initialCount = vm.assignments.count

        // Build a minimal backup JSON
        let backup = [AssignmentRecord(title: "From Backup")]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-backup-\(UUID()).json")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        vm.previewBackupRestore(from: url)

        XCTAssertEqual(vm.assignments.count, initialCount, "Preview must not mutate assignments")
        XCTAssertNotNil(vm.pendingRestorePreview, "Pending restore preview must be set")
        XCTAssertNotNil(vm.pendingRestoreFileURL, "Pending restore file URL must be staged")
    }

    @MainActor
    func testCancelPendingRestoreDoesNotMutate() throws {
        let local = AssignmentRecord(title: "Local")
        let store = InMemoryAssignmentStore(assignments: [local])
        let vm = GradeDraftViewModel(assignments: [local], store: store)
        let initialCount = vm.assignments.count

        let backup = [AssignmentRecord(title: "From Backup")]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-cancel-\(UUID()).json")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        vm.previewBackupRestore(from: url)
        vm.cancelPendingRestore()

        XCTAssertEqual(vm.assignments.count, initialCount, "Cancel must not mutate assignments")
        XCTAssertNil(vm.pendingRestorePreview, "Pending restore preview must be cleared")
        XCTAssertNil(vm.pendingRestoreFileURL, "Pending restore file URL must be cleared")
    }

    @MainActor
    func testConfirmPendingRestoreMutatesAssignments() throws {
        let local = AssignmentRecord(title: "Local")
        let store = InMemoryAssignmentStore(assignments: [local])
        let vm = GradeDraftViewModel(assignments: [local], store: store)

        let backup = [AssignmentRecord(title: "New From Backup")]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-confirm-\(UUID()).json")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        vm.backupConflictResolution = .restoreAsCopy
        vm.previewBackupRestore(from: url)
        XCTAssertEqual(vm.assignments.count, 1, "Before confirm, assignments unchanged")
        vm.confirmPendingRestore()
        XCTAssertTrue(vm.assignments.contains { $0.title.contains("Backup") || $0.title == "New From Backup" }, "After confirm, backup assignment should exist")
    }

    @MainActor
    func testConfirmPendingRestoreKeepsPreviewWhenRelatedRecordSaveFails() throws {
        var backupAssignment = AssignmentRecord(title: "From Backup", className: "7A", studentDisplayName: "Alex")
        let student = StudentRecord(displayName: "Alex", className: "7A", localIdentifier: "A-1")
        backupAssignment.studentID = student.id
        let classGroup = ClassGroupRecord(name: "7A")
        let rosterEntry = AssignmentRosterEntry(
            assignmentID: backupAssignment.id,
            studentID: student.id,
            studentDisplayName: student.displayName,
            localIdentifier: student.localIdentifier,
            sortOrder: 0
        )
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("backup-failure-\(UUID()).zip")
        defer { try? FileManager.default.removeItem(at: destination) }
        try BundleExportService.writeFullBackup(
            assignments: [backupAssignment],
            sourceFiles: [],
            to: destination,
            classGroups: [classGroup],
            students: [student],
            rosterEntries: [rosterEntry]
        )
        let local = AssignmentRecord(title: "Local")
        let store = InMemoryAssignmentStore(assignments: [local])
        store.replaceSnapshotError = NSError(
            domain: "GradeDraftTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "snapshot persistence failed"]
        )
        let vm = GradeDraftViewModel(assignments: [local], store: store)

        vm.previewBackupRestore(from: destination)
        XCTAssertNotNil(vm.pendingRestorePreview)
        vm.confirmPendingRestore()

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertNotNil(vm.pendingRestorePreview)
        XCTAssertNotNil(vm.pendingRestoreFileURL)
        XCTAssertFalse(vm.statusMessage.hasPrefix("Restored 1 assignment"))
    }

    @MainActor
    func testClearCurrentStudentWorkDoesNotDeleteSourceFilesWhenPersistenceFails() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraftClearWorkFailure-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let assignmentID = UUID()
        let relativePath = "Sources/\(assignmentID.uuidString)/page-1.txt"
        let sourceURL = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: sourceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("source".utf8).write(to: sourceURL)
        var assignment = AssignmentRecord(id: assignmentID, title: "Clear work")
        assignment.sourceInputs = [SourceInputRef(sourceType: .scan, localRelativePath: relativePath, fileName: "page-1.txt")]
        assignment.reviewedStudentText = "Reviewed text"
        assignment.ocrReviewStatus = .reviewed
        let store = InMemoryAssignmentStore(assignments: [assignment])
        store.appSupportDirectory = root
        store.saveAssignmentsError = GradeDraftError.persistenceFailed("save failed")
        let vm = GradeDraftViewModel(assignments: [assignment], store: store)

        vm.clearCurrentStudentWork()

        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path), "Source files must not be removed before the cleared assignment record is persisted.")
        XCTAssertEqual(vm.assignment.sourceInputs.count, 1)
        XCTAssertEqual(store.assignments.first?.sourceInputs.count, 1)
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertFalse(vm.statusMessage.contains("Student work cleared"))
    }

    // MARK: - Change 5: Stale status tests

    @MainActor
    func testAssignmentRosterStatusStaleReviewBeatsExported() {
        var record = AssignmentRecord(title: "Stale")
        record.rubricText = "Claim: 0-4 points"
        let finalReview = FinalGradeReview(
            packetFingerprint: "OLD-STALE-FINGERPRINT",
            status: .approved,
            criteria: [FinalCriterionScore(criterionID: "c1", criterion: "Claim", rating: "Proficient", proposedPoints: 4, finalPoints: 4, maxPoints: 4, evidence: [], explanation: "Good", teacherApproved: true)],
            totalScore: 4, maxScore: 4, studentFeedback: "Good job", privateTeacherNotes: "", teacherEdited: true
        )
        record.finalReview = finalReview
        record.exportRecords = [ExportRecord(exportKind: .studentPDF, contentFingerprint: "fp", includesPrivateTeacherNotes: false, includesOriginalSources: false)]

        // finalReview.packetFingerprint won't match gradingPacketFingerprint
        // so finalReviewIsStale = true => should return .needsRecheck
        let store = InMemoryAssignmentStore(assignments: [record])
        let vm = GradeDraftViewModel(assignments: [record], store: store)
        let status = vm.assignmentRosterStatus(for: vm.assignment)
        XCTAssertEqual(status, .needsRecheck, "Stale final review must produce needsRecheck, not exported")
    }

    func testAssignmentRosterStatusNeedsRecheckDisplayName() {
        XCTAssertEqual(AssignmentRosterStatus.needsRecheck.displayName, "Needs recheck")
    }

    func testAssignmentRosterStatusNeedsRecheckV6Status() {
        XCTAssertEqual(AssignmentRosterStatus.needsRecheck.v6Status, .needsRecheck)
    }

    // MARK: - Change 6: Rubric import mode tests

    @MainActor
    func testDeleteCurrentAssignmentRemovesRosterEntries() {
        let student = StudentRecord(displayName: "Alice")
        var assignment = AssignmentRecord(title: "To delete")
        assignment.studentID = student.id
        assignment.studentDisplayName = student.displayName
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let vm = GradeDraftViewModel(assignments: [assignment], store: store)
        vm.students = [student]

        // Manually add a roster entry for this assignment
        let entry = AssignmentRosterEntry(assignmentID: assignment.id, studentID: student.id, studentDisplayName: "Alice")
        vm.assignmentRosterEntries = [entry]

        vm.deleteCurrentAssignment()
        XCTAssertFalse(vm.assignmentRosterEntries.contains { $0.assignmentID == assignment.id }, "Roster entries for deleted assignment must be removed")
    }

    @MainActor
    func testDeleteStudentPersistsRosterRemoval() {
        let student = StudentRecord(displayName: "Alice")
        var assignment = AssignmentRecord(title: "Student cleanup", studentDisplayName: student.displayName)
        assignment.studentID = student.id
        let entry = AssignmentRosterEntry(
            assignmentID: assignment.id,
            studentID: student.id,
            studentDisplayName: student.displayName
        )
        let store = InMemoryAssignmentStore(assignments: [assignment], students: [student], rosterEntries: [entry])
        let vm = GradeDraftViewModel(assignments: [assignment], store: store)
        vm.students = [student]
        vm.assignmentRosterEntries = [entry]

        vm.deleteStudent(id: student.id)

        XCTAssertFalse(store.rosterEntries.contains { $0.studentID == student.id })
    }

    @MainActor
    func testDeleteStudentFailureRollsBackMemoryAndStoredRoster() {
        let student = StudentRecord(displayName: "Alice")
        var assignment = AssignmentRecord(title: "Student cleanup", studentDisplayName: student.displayName)
        assignment.studentID = student.id
        let entry = AssignmentRosterEntry(assignmentID: assignment.id, studentID: student.id, studentDisplayName: student.displayName)
        let store = InMemoryAssignmentStore(assignments: [assignment], students: [student], rosterEntries: [entry])
        store.replaceSnapshotError = NSError(domain: "GradeDraftTests", code: 42)
        let vm = GradeDraftViewModel(assignments: [assignment], store: store)
        vm.students = [student]
        vm.assignmentRosterEntries = [entry]

        vm.deleteStudent(id: student.id)

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertTrue(vm.students.contains { $0.id == student.id })
        XCTAssertEqual(store.rosterEntries, [entry])
        XCTAssertEqual(vm.assignmentRosterEntries.map(\.assignmentID), [entry.assignmentID])
        XCTAssertEqual(vm.assignmentRosterEntries.map(\.studentID), [entry.studentID])
        XCTAssertFalse(vm.statusMessage.contains("deleted"))
    }

    @MainActor
    func testRosterCSVImportFailureDoesNotPersistPartialGraph() {
        let existing = AssignmentRecord(title: "Existing", className: "6A", studentDisplayName: "Existing")
        let store = InMemoryAssignmentStore(assignments: [existing])
        store.replaceSnapshotError = NSError(domain: "GradeDraftTests", code: 43)
        let vm = GradeDraftViewModel(assignments: [existing], store: store)
        let csv = "Student,ID\nAlice,A1\nBob,B2"

        vm.createAssignmentsFromRosterCSV(csv, className: "6A")

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertEqual(store.assignments.map(\.id), [existing.id])
        XCTAssertTrue(store.classGroups.isEmpty)
        XCTAssertTrue(store.students.isEmpty)
        XCTAssertTrue(store.rosterEntries.isEmpty)
        XCTAssertEqual(vm.assignments.map(\.id), [existing.id])
    }

    @MainActor
    func testCreateAssignmentsFromRosterCSVPersistsExistingAndNewRosterEntries() {
        let existingStudentID = UUID()
        var existing = AssignmentRecord(title: "Existing", className: "7A", studentDisplayName: "Existing Student")
        existing.studentID = existingStudentID
        let store = InMemoryAssignmentStore(assignments: [existing])
        let vm = GradeDraftViewModel(assignments: [existing], store: store)

        vm.createAssignmentsFromRosterCSV("displayName,localIdentifier\nNew Student,N-1", className: "7A")

        XCTAssertTrue(store.rosterEntries.contains { $0.assignmentID == existing.id })
        XCTAssertTrue(store.rosterEntries.contains { $0.studentDisplayName == "New Student" })
        XCTAssertEqual(store.rosterEntries.count, 2)
        XCTAssertNil(vm.errorMessage)
    }

    @MainActor
    func testCreateAssignmentsFromRosterCSVSurfacesRosterPersistenceFailure() {
        let assignment = AssignmentRecord(title: "Template", className: "7A")
        let store = InMemoryAssignmentStore(assignments: [assignment])
        store.replaceSnapshotError = NSError(
            domain: "GradeDraftTests",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "roster persistence failed"]
        )
        let vm = GradeDraftViewModel(assignments: [assignment], store: store)

        vm.createAssignmentsFromRosterCSV("displayName,localIdentifier\nNew Student,N-1", className: "7A")

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertFalse(vm.statusMessage.hasPrefix("Created 1 roster assignment"))
    }

    // MARK: - Change 8: OCR centralized state tests

    @MainActor
    func testUnchangedOCRLineCommitDoesNotPersistAgain() {
        let line = OCRLine(text: "hello", confidence: 0.9, boundingBox: .zero, correctedText: "world", teacherConfirmed: false)
        let page = OCRPage(pageIndex: 0, lines: [line])
        var assignment = AssignmentRecord(title: "OCR No-op", ocrReviewStatus: .needsReview)
        assignment.ocrDocument = OCRDocument(pages: [page])

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let vm = GradeDraftViewModel(assignments: [assignment], store: store)

        vm.updateOCRLine(pageID: page.id, lineID: line.id, correctedText: "world")

        XCTAssertEqual(store.saveAssignmentsCallCount, 0, "Committing unchanged OCR text should not create another durable save.")
        XCTAssertTrue(vm.assignment.auditEvents.isEmpty, "Unchanged OCR text should not create a misleading edit audit event.")
    }

    @MainActor
    func testBatchOCRLineCorrectionsPersistOnceForLargePage() {
        let lines = (0..<120).map { index in
            OCRLine(text: "line \(index)", confidence: 0.92, boundingBox: .zero, teacherConfirmed: true)
        }
        let page = OCRPage(pageIndex: 0, lines: lines)
        var document = OCRDocument(pages: [page])
        document.reviewStatus = .reviewed
        document.reviewedAt = Date()
        var assignment = AssignmentRecord(title: "OCR Batch", ocrReviewStatus: .reviewed)
        assignment.ocrDocument = document
        assignment.ocrReviewedAt = Date()

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let vm = GradeDraftViewModel(assignments: [assignment], store: store)
        let corrections = lines.map { line in
            OCRLineCorrection(pageID: page.id, lineID: line.id, correctedText: "\(line.rawText) corrected")
        }

        vm.updateOCRLines(corrections)

        XCTAssertEqual(store.saveAssignmentsCallCount, 1, "Batch OCR corrections should create one durable save for the page, not one save per line.")
        XCTAssertEqual(vm.assignment.ocrReviewStatus, .needsReview)
        XCTAssertEqual(vm.assignment.ocrDocument?.reviewStatus, .needsReview)
        XCTAssertNil(vm.assignment.ocrDocument?.reviewedAt)
        XCTAssertNil(vm.assignment.ocrReviewedAt)
        XCTAssertEqual(vm.assignment.ocrDocument?.pages.first?.lines.filter { !$0.teacherConfirmed }.count, lines.count)
    }

    @MainActor
    func testUnchangedBatchOCRLineCorrectionsDoNotPersist() {
        let lines = (0..<12).map { index in
            OCRLine(text: "line \(index)", confidence: 0.92, boundingBox: .zero, correctedText: "kept \(index)", teacherConfirmed: false)
        }
        let page = OCRPage(pageIndex: 0, lines: lines)
        var assignment = AssignmentRecord(title: "OCR Batch No-op", ocrReviewStatus: .needsReview)
        assignment.ocrDocument = OCRDocument(pages: [page])

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let vm = GradeDraftViewModel(assignments: [assignment], store: store)
        let corrections = lines.map { line in
            OCRLineCorrection(pageID: page.id, lineID: line.id, correctedText: line.reviewedText)
        }

        vm.updateOCRLines(corrections)

        XCTAssertEqual(store.saveAssignmentsCallCount, 0, "Unchanged batch OCR corrections should not create a durable save.")
        XCTAssertTrue(vm.assignment.auditEvents.isEmpty, "Unchanged batch OCR corrections should not create a misleading edit audit event.")
    }

    @MainActor
    func testBatchOCRLineCorrectionsReportPersistenceFailure() {
        let line = OCRLine(text: "line", confidence: 0.92, boundingBox: .zero, teacherConfirmed: true)
        let page = OCRPage(pageIndex: 0, lines: [line])
        var assignment = AssignmentRecord(title: "OCR Batch Failure", ocrReviewStatus: .reviewed)
        assignment.ocrDocument = OCRDocument(pages: [page], reviewStatus: .reviewed, reviewedAt: Date())
        assignment.ocrReviewedAt = Date()

        let store = InMemoryAssignmentStore(assignments: [assignment])
        store.saveAssignmentsError = GradeDraftError.persistenceFailed("Injected OCR batch save failure.")
        let vm = GradeDraftViewModel(assignments: [assignment], store: store)

        let saved = vm.updateOCRLines([
            OCRLineCorrection(pageID: page.id, lineID: line.id, correctedText: "corrected")
        ])

        XCTAssertFalse(saved, "Failed OCR batch persistence must report failure so staged UI edits remain visible.")
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertEqual(store.saveAssignmentsCallCount, 0)
    }

    // MARK: - Change 9: Source path safety tests

    func testLegacyJSONRestoreSanitizesUnsafeSourcePaths() throws {
        let unsafeSource = SourceInputRef(
            sourceType: .photo,
            localRelativePath: "/absolute/bad.png",
            fileName: "bad.png"
        )
        var backupRecord = AssignmentRecord(title: "From Backup")
        backupRecord.sourceInputs = [unsafeSource]

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode([backupRecord])
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("legacy-test-\(UUID()).json")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let store = InMemoryAssignmentStore(assignments: [])
        let vm = GradeDraftViewModel(assignments: [], store: store)
        vm.previewBackupRestore(from: url)
        vm.confirmPendingRestore()

        let restored = vm.assignments.first { $0.title == "From Backup" }
        XCTAssertNotNil(restored, "Backup assignment should be restored")
        let paths = restored?.sourceInputs.map { $0.localRelativePath }
        XCTAssertTrue(paths?.allSatisfy { $0 == nil } ?? false, "Unsafe source path must be stripped")
    }

    @MainActor
    func testPhotoImportRollsBackFilesAndVisibleStateWhenOCRFails() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraftPhotoOCRRollback-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let assignment = AssignmentRecord(title: "Photo OCR rollback", reviewedStudentText: "Previous reviewed text")
        let store = InMemoryAssignmentStore(assignments: [assignment])
        store.appSupportDirectory = root
        let ocr = ImportTransactionOCRService(result: .failure(ImportTransactionTestError.injectedOCRFailure))
        let viewModel = GradeDraftViewModel(assignments: [assignment], ocrService: ocr, store: store)

        await viewModel.applyPhotoImages([makeImportTransactionImage()])

        XCTAssertTrue(regularFilesUnder(root).isEmpty, "Failed OCR import must remove copied student source files.")
        XCTAssertEqual(viewModel.assignment.reviewedStudentText, "Previous reviewed text")
        XCTAssertTrue(viewModel.assignment.sourceInputs.isEmpty)
        XCTAssertNil(viewModel.assignment.ocrDocument)
        XCTAssertEqual(store.saveAssignmentsCallCount, 0)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.statusMessage.contains("Text recognition complete"))
    }

    @MainActor
    func testPhotoImportRollsBackFilesAndVisibleStateWhenSaveFails() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraftPhotoSaveRollback-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let assignment = AssignmentRecord(title: "Photo save rollback", reviewedStudentText: "Previous reviewed text")
        let store = InMemoryAssignmentStore(assignments: [assignment])
        store.appSupportDirectory = root
        store.saveAssignmentsError = ImportTransactionTestError.injectedSaveFailure
        let document = OCRDocument(pages: [
            OCRPage(pageIndex: 0, lines: [
                OCRLine(text: "Imported text", confidence: 0.93, boundingBox: .zero)
            ])
        ])
        let ocr = ImportTransactionOCRService(result: .success(document))
        let viewModel = GradeDraftViewModel(assignments: [assignment], ocrService: ocr, store: store)

        await viewModel.applyPhotoImages([makeImportTransactionImage()])

        XCTAssertTrue(regularFilesUnder(root).isEmpty, "Failed durable save must remove copied student source files.")
        XCTAssertEqual(viewModel.assignment.reviewedStudentText, "Previous reviewed text")
        XCTAssertTrue(viewModel.assignment.sourceInputs.isEmpty)
        XCTAssertNil(viewModel.assignment.ocrDocument)
        XCTAssertEqual(store.assignments.first?.reviewedStudentText, "Previous reviewed text")
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.statusMessage.contains("Text recognition complete"))
    }

    @MainActor
    func testPDFImportRollsBackOriginalAndRenderedSourcesWhenSaveFails() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraftPDFSaveRollback-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let pdfURL = try makeImportTransactionPDF()
        defer { try? FileManager.default.removeItem(at: pdfURL) }
        let assignment = AssignmentRecord(title: "PDF save rollback", reviewedStudentText: "Previous PDF text")
        let store = InMemoryAssignmentStore(assignments: [assignment])
        store.appSupportDirectory = root
        store.saveAssignmentsError = ImportTransactionTestError.injectedSaveFailure
        let document = OCRDocument(pages: [
            OCRPage(pageIndex: 0, lines: [
                OCRLine(text: "OCR PDF text", confidence: 0.88, boundingBox: .zero)
            ])
        ])
        let ocr = ImportTransactionOCRService(result: .success(document))
        let viewModel = GradeDraftViewModel(assignments: [assignment], ocrService: ocr, store: store)

        await viewModel.applyPDFFile(pdfURL)

        XCTAssertTrue(regularFilesUnder(root).isEmpty, "Failed PDF durable save must remove both original PDF and rendered page files.")
        XCTAssertEqual(viewModel.assignment.reviewedStudentText, "Previous PDF text")
        XCTAssertTrue(viewModel.assignment.sourceInputs.isEmpty)
        XCTAssertNil(viewModel.assignment.ocrDocument)
        XCTAssertEqual(store.assignments.first?.reviewedStudentText, "Previous PDF text")
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.statusMessage.contains("PDF imported"))
    }

    // MARK: - Private helpers
}
