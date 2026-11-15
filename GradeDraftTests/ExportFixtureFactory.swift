import Foundation
@testable import GradeDraft

/// One student's work under one assignment, as the export, report and restore tests use it.
struct ExportFixture {
    var classGroup: ClassGroup
    var setup: AssignmentSetup
    var submission: SubmissionGraph

    var className: String { classGroup.name }

    /// The id of the rubric's one criterion ("Claim: 0-4 points").
    var criterionID: String {
        setup.parsedRubric.criteria.first?.id ?? "claim"
    }

    /// The text line of a scanned fixture, when it has one.
    var ocrLine: OCRLine? {
        submission.ocr?.pages.first?.lines.first
    }

    /// The path of the fixture's source file, when it has one (`Sources/<submissionID>/<file>`).
    var sourceRelativePath: String? {
        submission.sources.first?.localRelativePath
    }

    /// What the app's own screens would hold for this class: the class, the student, their enrolment,
    /// the assignment setup and the submission.
    var snapshot: BackupSnapshot {
        BackupSnapshot(
            classGroups: [classGroup],
            students: [submission.student],
            enrollments: [Enrollment(classGroupID: classGroup.id, studentID: submission.student.id)],
            assignments: [setup],
            submissions: [submission]
        )
    }

    /// The fingerprint the fixture's draft and final review are checked against.
    func currentFingerprint() throws -> String {
        try submission.packetFingerprint(setup: setup)
    }

    func studentReportMarkdown(generatedAt: Date = Date(timeIntervalSince1970: 0)) throws -> String {
        MarkdownRenderer.render(try ReportBuilder.studentReport(setup: setup, submission: submission, generatedAt: generatedAt))
    }

    func teacherRecordMarkdown(generatedAt: Date = Date(timeIntervalSince1970: 0)) -> String {
        MarkdownRenderer.render(ReportBuilder.teacherRecord(setup: setup, submission: submission, generatedAt: generatedAt))
    }
}

/// Builders for the export, report and restore tests. The sentinels contain no characters Markdown
/// escapes, so a leak into a report shows up as a plain substring match.
enum ExportFixtureFactory {
    static let privateTeacherNote = "PRIVATE-TEACHER-NOTE-SENTINEL"
    static let modelTeacherNote = "MODEL-TEACHER-NOTE-SENTINEL"
    static let teacherRationale = "TEACHER-RATIONALE-SENTINEL"
    static let auditEvent = "AUDIT-EVENT-SENTINEL"
    static let uncertaintyFlag = "UNCERTAINTY-SENTINEL"
    static let complianceFlag = "COMPLIANCE-SENTINEL"
    static let draftFeedback = "DRAFT-FEEDBACK-SENTINEL"
    static let draftEvidence = "DRAFT-EVIDENCE-SENTINEL"
    static let reviewedTextSentinel = "REVIEWED-STUDENT-TEXT-SENTINEL"
    static let rawOCRTextSentinel = "RAW-OCR-TEXT-SENTINEL"
    static let sourceFileName = "source-sentinel.png"
    static let sourceDigest = "digest-sentinel"
    static let reviewedSentence = "The student wrote a claim with evidence."
    static let className = "6A"

    /// Scanned work with a reviewed text line, a source file, evidence, an AI draft and an approved,
    /// current final review (the "approved and current" state).
    static func sensitiveApprovedAssignment(
        title: String = "Essay about Alice, \"quotes\" and formulas",
        student: String = "Alice Example"
    ) throws -> ExportFixture {
        var fixture = try baseAssignment(title: title, student: student)
        let submissionID = fixture.submission.submission.id

        let source = SourceInputRef(
            submissionID: submissionID,
            sourceType: .scan,
            pageIndex: 0,
            localRelativePath: "Sources/\(submissionID.uuidString)/\(sourceFileName)",
            fileName: sourceFileName,
            mimeType: "image/png",
            sha256: sourceDigest,
            includedInTeacherArchive: true
        )
        let box = NormalizedRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
        let line = OCRLine(
            text: rawOCRTextSentinel,
            confidence: 0.99,
            boundingBox: box,
            origin: .visionOCR,
            correctedText: reviewedTextSentinel + " " + reviewedSentence,
            teacherConfirmed: true
        )
        fixture.submission.submission.inputKind = .scanned
        fixture.submission.submission.pastedText = nil
        fixture.submission.sources = [source]
        fixture.submission.ocr = OCRDocument(
            pages: [OCRPage(sourceInputID: source.id, pageIndex: 0, lines: [line])],
            reviewStatus: .reviewed
        )
        let evidence = EvidenceReference(
            submissionID: submissionID,
            ocrLineID: line.id,
            pageIndex: 0,
            quote: reviewedSentence,
            boundingBox: box,
            sourceKind: .ocrLine,
            teacherConfirmed: true
        )
        fixture.submission.evidence = [evidence]

        let fingerprint = try fixture.currentFingerprint()
        fixture.submission.draft = GradeDraftResult(
            packetFingerprint: fingerprint,
            status: .generated,
            studentResponseSummary: "Draft summary sentinel",
            criteria: [CriterionScore(
                criterionID: fixture.criterionID,
                rating: "Proficient",
                proposedPoints: 3,
                evidenceQuotes: [reviewedSentence],
                explanation: "Draft explanation sentinel",
                teacherReviewRequired: false
            )],
            studentFeedback: draftFeedback,
            teacherNotes: modelTeacherNote,
            uncertaintyFlags: [uncertaintyFlag],
            complianceFlags: [complianceFlag]
        )
        fixture.submission.finalReview = FinalGradeReview(
            finalizedAt: Date(timeIntervalSince1970: 1_700_000_000),
            packetFingerprint: fingerprint,
            status: .approved,
            criteria: [FinalCriterionScore(
                criterionID: fixture.criterionID,
                rating: "Proficient",
                proposedPoints: 3,
                finalPoints: 4,
                explanation: "Student-facing final explanation sentinel",
                teacherApproved: true,
                teacherRationale: teacherRationale,
                evidenceIDs: [evidence.id]
            )],
            studentFeedback: "Final student feedback sentinel",
            privateTeacherNotes: privateTeacherNote,
            teacherEdited: true
        )
        fixture.submission.audit = [
            AuditEvent(
                assignmentID: fixture.setup.id,
                submissionID: submissionID,
                eventType: .assignmentCreated,
                detail: auditEvent
            )
        ]
        return fixture
    }

    /// Pasted work with an AI draft and no final review (the "none" state).
    static func draftOnlyAssignment() throws -> ExportFixture {
        var fixture = try baseAssignment(title: "Draft-only assignment", student: "Bob Example")
        fixture.submission.draft = GradeDraftResult(
            packetFingerprint: try fixture.currentFingerprint(),
            status: .generated,
            studentResponseSummary: "Draft summary sentinel",
            criteria: [CriterionScore(
                criterionID: fixture.criterionID,
                rating: "Developing",
                proposedPoints: 2,
                evidenceQuotes: [draftEvidence],
                explanation: "Draft explanation sentinel",
                teacherReviewRequired: true
            )],
            studentFeedback: draftFeedback,
            teacherNotes: modelTeacherNote,
            uncertaintyFlags: [uncertaintyFlag],
            complianceFlags: [complianceFlag]
        )
        return fixture
    }

    /// An approved final review whose grading inputs changed afterwards (the "approved but stale" state).
    static func staleApprovedAssignment() throws -> ExportFixture {
        var fixture = try sensitiveApprovedAssignment()
        let line = try requireLine(fixture)
        fixture.submission.ocr?.pages[0].lines[0].correctedText = (line.correctedText ?? "") + " Changed after final review."
        return fixture
    }

    /// A final review that has not been approved yet (the "in progress" state).
    static func inProgressFinalReviewAssignment() throws -> ExportFixture {
        var fixture = try sensitiveApprovedAssignment()
        fixture.submission.finalReview?.status = .inProgress
        fixture.submission.finalReview?.finalizedAt = nil
        return fixture
    }

    /// Pasted work, no draft, no final review.
    static func baseAssignment(title: String = "Base Assignment", student: String = "Student Example") throws -> ExportFixture {
        let classGroup = ClassGroup(name: className)
        let assignment = Assignment(
            classGroupID: classGroup.id,
            title: title,
            prompt: "Explain the claim.",
            subject: "English",
            gradeLevel: "Year 6",
            curriculumReference: "Local curriculum reference",
            assignmentType: .essay,
            rubricText: "Claim: 0-4 points",
            customInstructions: "Use teacher judgment.",
            answerKeyText: "Students should provide a claim and evidence.",
            exemplarText: "An exemplar claim cites evidence."
        )
        let studentRecord = Student(displayName: student)
        let submission = SubmissionGraph(
            submission: Submission(
                assignmentID: assignment.id,
                studentID: studentRecord.id,
                inputKind: .pasted,
                pastedText: reviewedSentence
            ),
            student: studentRecord
        )
        return ExportFixture(classGroup: classGroup, setup: AssignmentSetup(assignment: assignment), submission: submission)
    }

    static func temporaryDirectory(_ name: String = "ExportHardening") -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func requireLine(_ fixture: ExportFixture) throws -> OCRLine {
        guard let line = fixture.ocrLine else {
            throw FixtureError.missingLine
        }
        return line
    }

    private enum FixtureError: Error {
        case missingLine
    }
}
