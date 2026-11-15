#if DEBUG
import Foundation
import GRDB

/// Shared sample data for `#Preview`s and the UI tests (Debug only; this folder is a development asset).
/// One class of three students and one assignment with a three-criterion rubric. The three submissions
/// cover the main states: no work yet, scanned text that needs review, and an approved final grade.
enum PreviewFixtures {
    static let classGroupID = UUID(uuidString: "6F1A0C2E-0000-4000-8000-000000000001") ?? UUID()
    static let assignmentID = UUID(uuidString: "6F1A0C2E-0000-4000-8000-000000000002") ?? UUID()
    static let noWorkSubmissionID = UUID(uuidString: "6F1A0C2E-0000-4000-8000-000000000011") ?? UUID()
    static let scannedSubmissionID = UUID(uuidString: "6F1A0C2E-0000-4000-8000-000000000012") ?? UUID()
    static let approvedSubmissionID = UUID(uuidString: "6F1A0C2E-0000-4000-8000-000000000013") ?? UUID()

    static let rubricText = """
    Claim: 0-4 points
    Evidence: 0-4 points
    Organisation: 0-2 points
    """

    static let approvedText = "Plants need sunlight to make food. The leaves catch the light, so a plant kept in a dark cupboard turns yellow and weak."

    /// An in-memory database holding the fixture.
    static func makeDatabase() throws -> AppDatabase {
        let database = try AppDatabase.inMemory()
        try seed(database)
        return database
    }

    /// An app model over the fixture database, with on-device AI reported as unavailable.
    @MainActor
    static func makeAppModel() -> AppModel {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PreviewStorage-\(UUID().uuidString)", isDirectory: true)
        return AppModel(
            openStorage: { AppModel.Storage(database: try makeDatabase(), root: root) },
            services: previewServices()
        )
    }

    @MainActor
    static func previewServices() -> AppServices {
        var services = AppServices.live()
        services.grading = UnavailableLocalGradingService()
        return services
    }

    static func seed(_ database: AppDatabase) throws {
        let now = Date()
        let classGroup = ClassGroup(id: classGroupID, name: "Year 6 Science", schoolYear: "2026", term: "Term 4", subject: "Science", gradeLevel: "Year 6")
        let students = [
            Student(displayName: "Ava Chen", localIdentifier: "S001"),
            Student(displayName: "Noah Williams", localIdentifier: "S002"),
            Student(displayName: "Zoë Nguyen", localIdentifier: "S003")
        ]
        let assignment = Assignment(
            id: assignmentID,
            classGroupID: classGroupID,
            title: "Why plants need light",
            prompt: "Explain why plants need sunlight. Use evidence from the experiment.",
            subject: "Science",
            gradeLevel: "Year 6",
            assignmentType: .paragraphResponse,
            rubricText: rubricText
        )
        let setup = AssignmentSetup(assignment: assignment)
        let rubric = setup.parsedRubric.criteria

        let noWork = SubmissionGraph(
            submission: Submission(id: noWorkSubmissionID, assignmentID: assignmentID, studentID: students[0].id),
            student: students[0]
        )

        let scanned = SubmissionGraph(
            submission: Submission(id: scannedSubmissionID, assignmentID: assignmentID, studentID: students[1].id, inputKind: .scanned),
            student: students[1],
            ocr: OCRDocument(
                pages: [
                    OCRPage(pageIndex: 0, lines: [
                        OCRLine(text: "Plants use light to make their food.", confidence: 0.94,
                                boundingBox: NormalizedRect(x: 0.1, y: 0.8, width: 0.8, height: 0.05), origin: .visionOCR, paragraphIndex: 0),
                        OCRLine(text: "Without lite the leafs go yelow.", confidence: 0.52,
                                boundingBox: NormalizedRect(x: 0.1, y: 0.72, width: 0.7, height: 0.05), origin: .visionOCR, paragraphIndex: 0)
                    ])
                ],
                reviewStatus: .needsReview
            )
        )

        let approvedSubmission = Submission(
            id: approvedSubmissionID, assignmentID: assignmentID, studentID: students[2].id,
            inputKind: .pasted, pastedText: approvedText
        )
        var approved = SubmissionGraph(submission: approvedSubmission, student: students[2])
        let fingerprint = try approved.packetFingerprint(setup: setup)
        let points = [3.0, 3.0, 2.0]
        approved.finalReview = FinalGradeReview(
            createdAt: now,
            finalizedAt: now,
            packetFingerprint: fingerprint,
            status: .approved,
            criteria: zip(rubric, points).map { criterion, score in
                FinalCriterionScore(
                    criterionID: criterion.id, rating: "Proficient", proposedPoints: score, finalPoints: score,
                    explanation: "Supported by the reviewed text.", teacherApproved: true
                )
            },
            studentFeedback: "Your explanation is clear. Next time, name the part of the experiment that shows this.",
            privateTeacherNotes: "Sample teacher note.",
            teacherEdited: true
        )

        try database.writer.write { db in
            try classGroup.insert(db)
            for (order, student) in students.enumerated() {
                try student.insert(db)
                try Enrollment(classGroupID: classGroupID, studentID: student.id, sortOrder: order).insert(db)
            }
            try assignment.insert(db)
            try AppDatabase.insertGraph(noWork, db)
            try AppDatabase.insertGraph(scanned, db)
            try AppDatabase.insertGraph(approved, db)
        }
    }
}
#endif
