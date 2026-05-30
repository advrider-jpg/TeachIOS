import Foundation
@testable import GradeDraft

enum ExportFixtureFactory {
    static let privateTeacherNote = "PRIVATE_TEACHER_NOTE_SENTINEL"
    static let rawModelResponse = "RAW_MODEL_RESPONSE_SENTINEL"
    static let modelTeacherNote = "MODEL_TEACHER_NOTE_SENTINEL"
    static let teacherRationale = "TEACHER_RATIONALE_SENTINEL"
    static let auditEvent = "AUDIT_EVENT_SENTINEL"
    static let uncertaintyFlag = "UNCERTAINTY_SENTINEL"
    static let complianceFlag = "COMPLIANCE_SENTINEL"
    static let sourcePath = "Sources/source-sentinel.png"
    static let evidenceSourceRef = "ocr-line-sentinel"

    static func sensitiveApprovedAssignment(
        title: String = "Essay about Alice, \"quotes\" and formulas",
        student: String = "Alice Example"
    ) -> AssignmentRecord {
        var assignment = baseAssignment(title: title, student: student)
        assignment.sourceInputs = [
            SourceInputRef(
                sourceType: .scan,
                localRelativePath: sourcePath,
                fileName: "source-sentinel.png",
                mimeType: "image/png",
                contentDigest: "digest-sentinel",
                digestAlgorithm: "fnv1a64",
                teacherIncludedInExport: true
            )
        ]
        let line = OCRLine(
            text: "RAW_OCR_TEXT_SENTINEL",
            confidence: 0.99,
            boundingBox: NormalizedRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
            correctedText: "The student wrote a claim with evidence.",
            teacherConfirmed: true
        )
        assignment.ocrDocument = OCRDocument(
            pages: [OCRPage(sourceInputID: assignment.sourceInputs[0].id, pageIndex: 0, lines: [line])],
            reviewStatus: .reviewed
        )
        assignment.ocrReviewStatus = .reviewed
        assignment.reviewedStudentText = "REVIEWED_STUDENT_TEXT_SENTINEL The student wrote a claim with evidence."
        assignment.latestDraft = GradeDraftResult(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .generated,
            studentResponseSummary: "Draft summary sentinel",
            criteria: [CriterionScore(
                criterionID: "claim",
                criterion: "Claim",
                rating: "Proficient",
                proposedPoints: 3,
                maxPoints: 4,
                evidence: ["The student wrote a claim with evidence."],
                evidenceSourceRefs: [evidenceSourceRef],
                explanation: "Draft explanation sentinel",
                teacherReviewRequired: false
            )],
            totalScore: 3,
            maxScore: 4,
            studentFeedback: "DRAFT_FEEDBACK_SENTINEL",
            teacherNotes: modelTeacherNote,
            uncertaintyFlags: [uncertaintyFlag],
            complianceFlags: [complianceFlag],
            rawModelResponse: rawModelResponse
        )
        assignment.evidenceReferences = [
            EvidenceReference(
                sourceInputID: assignment.sourceInputs[0].id,
                ocrLineID: assignment.ocrDocument?.pages.first?.lines.first?.id,
                pageIndex: 0,
                quote: "The student wrote a claim with evidence.",
                boundingBox: NormalizedRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
                sourceKind: "ocrLine",
                teacherConfirmed: true
            )
        ]
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
                evidence: ["The student wrote a claim with evidence."],
                evidenceSourceRefs: [evidenceSourceRef],
                explanation: "Student-facing final explanation sentinel",
                teacherApproved: true,
                teacherRationale: teacherRationale
            )],
            totalScore: 4,
            maxScore: 4,
            studentFeedback: "Final student feedback sentinel",
            privateTeacherNotes: privateTeacherNote,
            teacherEdited: true
        )
        assignment.appendAuditEvent(.assignmentCreated, detail: auditEvent)
        return assignment
    }

    static func draftOnlyAssignment() -> AssignmentRecord {
        var assignment = baseAssignment(title: "Draft-only assignment", student: "Bob Example")
        assignment.latestDraft = GradeDraftResult(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .generated,
            studentResponseSummary: "Draft summary sentinel",
            criteria: [CriterionScore(
                criterion: "Claim",
                rating: "Developing",
                proposedPoints: 2,
                maxPoints: 4,
                evidence: ["DRAFT_EVIDENCE_SENTINEL"],
                evidenceSourceRefs: [evidenceSourceRef],
                explanation: "Draft explanation sentinel",
                teacherReviewRequired: true
            )],
            totalScore: 2,
            maxScore: 4,
            studentFeedback: "DRAFT_FEEDBACK_SENTINEL",
            teacherNotes: modelTeacherNote,
            uncertaintyFlags: [uncertaintyFlag],
            complianceFlags: [complianceFlag],
            rawModelResponse: rawModelResponse
        )
        return assignment
    }

    static func staleApprovedAssignment() -> AssignmentRecord {
        var assignment = sensitiveApprovedAssignment()
        assignment.reviewedStudentText += " Changed after final review."
        return assignment
    }

    static func inProgressFinalReviewAssignment() -> AssignmentRecord {
        var assignment = sensitiveApprovedAssignment()
        assignment.finalReview?.status = .inProgress
        return assignment
    }

    static func baseAssignment(title: String = "Base Assignment", student: String = "Student Example") -> AssignmentRecord {
        AssignmentRecord(
            title: title,
            prompt: "Explain the claim.",
            subject: "English",
            gradeLevel: "Year 6",
            curriculumReference: "Local curriculum reference",
            className: "6A",
            studentDisplayName: student,
            assignmentType: .essay,
            rubricText: "Claim: 0-4 points",
            customInstructions: "Use teacher judgment.",
            answerKeyText: "Students should provide a claim and evidence.",
            exemplarText: "An exemplar claim cites evidence.",
            reviewedStudentText: "The student wrote a claim with evidence.",
            ocrReviewStatus: .reviewed
        )
    }

    static func temporaryDirectory(_ name: String = "ExportHardening") -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
