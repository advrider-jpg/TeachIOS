import SwiftUI

@main
struct GradeDraftApp: App {
    var body: some Scene {
        WindowGroup {
            if ProcessInfo.processInfo.arguments.contains("--ui-core-lane-test") {
                ContentView(viewModel: GradeDraftViewModel(
                    assignments: Self.uiCoreLaneAssignments(),
                    gradingService: UnavailableLocalGradingService()
                ))
            } else if ProcessInfo.processInfo.arguments.contains("--ui-smoke-test") {
                ContentView(viewModel: GradeDraftViewModel(
                    assignments: Self.uiSmokeAssignments(),
                    gradingService: UnavailableLocalGradingService()
                ))
            } else {
                ContentView()
            }
        }
    }

    private static func uiSmokeAssignments() -> [AssignmentRecord] {
        [
            AssignmentRecord(
                title: "UI Smoke Assignment",
                subject: "English",
                gradeLevel: "Year 6",
                className: "UI Smoke",
                studentDisplayName: "Test Student",
                rubricText: "Claim: 0-4 points",
                reviewedStudentText: "This local UI smoke fixture has reviewed text but no final approval or export artifact."
            )
        ]
    }

    private static func uiCoreLaneAssignments() -> [AssignmentRecord] {
        var assignment = AssignmentRecord(
            title: "UI Core Lane Assignment",
            subject: "English",
            gradeLevel: "Year 6",
            className: "UI Core Lane",
            studentDisplayName: "Core Lane Student",
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: "The student makes a clear claim and supports it with relevant evidence.",
            ocrReviewStatus: .notNeeded
        )
        assignment.sourceInputs = [
            SourceInputRef(
                sourceType: .pastedText,
                fileName: "Pasted student work",
                teacherIncludedInExport: false
            )
        ]
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .inProgress,
            criteria: [
                FinalCriterionScore(
                    criterionID: "claim",
                    criterion: "Claim",
                    rating: "Proficient",
                    proposedPoints: 3,
                    finalPoints: 3,
                    maxPoints: 4,
                    evidence: ["clear claim"],
                    explanation: "The reviewed text includes a clear claim supported by evidence.",
                    teacherApproved: true
                )
            ],
            totalScore: 3,
            maxScore: 4,
            studentFeedback: "Your claim is clear and supported. Add one more specific detail to strengthen the response.",
            privateTeacherNotes: "UI test fixture note for teacher-only audit surfaces.",
            teacherEdited: true
        )
        assignment.appendAuditEvent(.sourceCaptured, detail: "UI test fixture uses pasted student work already saved as reviewed local input.")
        assignment.appendAuditEvent(.finalReviewStarted, detail: "UI test fixture starts with an in-progress teacher review so the app-driving test can approve and export.")
        return [assignment]
    }
}
