import SwiftUI
import UIKit
import XCTest

@testable import GradeDraft

/// Renders key app screens to PNG files stored in the app's Documents/GradeDraftScreenshots/
/// directory, which CI can retrieve via `xcrun simctl get_app_container`.
/// Each image is also attached as an XCTAttachment (visible in the .xcresult bundle).
@MainActor
final class GradeDraftScreenshotTests: XCTestCase {

    // MARK: - Screens

    func testCaptureAllScreens() {
        let screenshotDir = prepareScreenshotDirectory()

        // 1. Fresh assignment — home state every new user sees
        let emptyStore = InMemoryAssignmentStore()
        let emptyVM = GradeDraftViewModel(assignments: [AssignmentRecord()], store: emptyStore)
        snapshot("01-new-assignment", ContentView(viewModel: emptyVM), to: screenshotDir)

        // 2. Assignment ready to grade (rubric + reviewed scanned text, no draft yet)
        let readyAssignment = makeBaseAssignment()
        let readyStore = InMemoryAssignmentStore(assignments: [readyAssignment])
        let readyVM = GradeDraftViewModel(assignments: [readyAssignment], store: readyStore)
        snapshot("02-ready-to-grade", ContentView(viewModel: readyVM), to: screenshotDir)

        // 3. Draft generated — AI suggestion awaiting teacher review
        var draftAssignment = makeBaseAssignment()
        draftAssignment.latestDraft = makeDraft(for: draftAssignment)
        let draftStore = InMemoryAssignmentStore(assignments: [draftAssignment])
        let draftVM = GradeDraftViewModel(assignments: [draftAssignment], store: draftStore)
        snapshot("03-draft-generated", ContentView(viewModel: draftVM), to: screenshotDir)

        // 4. Final review — teacher has approved all criteria
        var approvedAssignment = makeBaseAssignment()
        approvedAssignment.latestDraft = makeDraft(for: approvedAssignment)
        approvedAssignment.finalReview = makeFinalReview(for: approvedAssignment, status: .approved)
        let approvedStore = InMemoryAssignmentStore(assignments: [approvedAssignment])
        let approvedVM = GradeDraftViewModel(assignments: [approvedAssignment], store: approvedStore)
        snapshot("04-approved-final-review", ContentView(viewModel: approvedVM), to: screenshotDir)

        // 5. Gradebook — class roster with mixed completion states
        let classAssignments = makeClassRoster()
        let rosterStore = InMemoryAssignmentStore(assignments: classAssignments)
        let rosterVM = GradeDraftViewModel(assignments: classAssignments, store: rosterStore)
        snapshot("05-class-gradebook", ContentView(viewModel: rosterVM), to: screenshotDir)

        // 6. Manual final review in-progress (no AI draft)
        var manualAssignment = makeBaseAssignment()
        manualAssignment.finalReview = makeFinalReview(for: manualAssignment, status: .inProgress)
        let manualStore = InMemoryAssignmentStore(assignments: [manualAssignment])
        let manualVM = GradeDraftViewModel(assignments: [manualAssignment], store: manualStore)
        snapshot("06-manual-final-review", ContentView(viewModel: manualVM), to: screenshotDir)
    }

    // MARK: - Rendering

    private func snapshot<V: View>(_ name: String, _ view: V, to dir: URL?) {
        let image = render(view)
        if let dir, let data = image.pngData() {
            try? data.write(to: dir.appendingPathComponent("\(name).png"))
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func render<V: View>(_ view: V, size: CGSize = CGSize(width: 1024, height: 768)) -> UIImage {
        let controller = UIHostingController(rootView: view)
        controller.overrideUserInterfaceStyle = .light
        controller.view.frame = CGRect(origin: .zero, size: size)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.35))
        controller.view.layoutIfNeeded()
        let renderer = UIGraphicsImageRenderer(bounds: controller.view.bounds)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }

    private func prepareScreenshotDirectory() -> URL? {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = docs.appendingPathComponent("GradeDraftScreenshots")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Sample data factories

    private func makeBaseAssignment() -> AssignmentRecord {
        AssignmentRecord(
            title: "Year 6 Persuasive Essay",
            subject: "English",
            gradeLevel: "Year 6",
            className: "6A",
            studentDisplayName: "Alex Thompson",
            assignmentType: .essay,
            rubricText: """
            Claim: 0–4 pts — Student states a clear, arguable position.
            Evidence: 0–3 pts — Student supports claim with relevant evidence.
            Language: 0–3 pts — Appropriate academic language and structure.
            """,
            reviewedStudentText: """
            The school should have longer lunch breaks. Students need adequate time to eat properly — studies show rushed meals lead to poor nutrition and reduced afternoon concentration. Moreover, lunch time provides essential social opportunities that support mental wellbeing. Extending lunch from 20 to 40 minutes would benefit both health and academic outcomes.
            """,
            ocrReviewStatus: .reviewed
        )
    }

    private func makeDraft(for assignment: AssignmentRecord) -> GradeDraftResult {
        GradeDraftResult(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .teacherReviewRequired,
            studentResponseSummary: "Student provides a clear claim with two supporting reasons backed by research.",
            criteria: [
                CriterionScore(
                    criterionID: "claim",
                    criterion: "Claim",
                    rating: "Proficient",
                    proposedPoints: 3,
                    maxPoints: 4,
                    evidence: ["The school should have longer lunch breaks"],
                    explanation: "Clear, arguable claim stated directly in the opening sentence.",
                    teacherReviewRequired: false
                ),
                CriterionScore(
                    criterionID: "evidence",
                    criterion: "Evidence",
                    rating: "Developing",
                    proposedPoints: 2,
                    maxPoints: 3,
                    evidence: ["studies show rushed meals lead to poor nutrition"],
                    explanation: "One piece of research-backed evidence cited; additional specific examples would strengthen the argument.",
                    teacherReviewRequired: false
                ),
                CriterionScore(
                    criterionID: "language",
                    criterion: "Language",
                    rating: "Proficient",
                    proposedPoints: 2,
                    maxPoints: 3,
                    evidence: [],
                    explanation: "Academic language used consistently throughout; minor improvements possible.",
                    teacherReviewRequired: false
                )
            ],
            totalScore: 7,
            maxScore: 10,
            studentFeedback: "Well done establishing a clear position. Your research citation adds credibility — try including one more specific example to further support your claim about social benefits.",
            teacherNotes: "Review evidence criterion before approving. Student references 'studies' without naming them.",
            uncertaintyFlags: []
        )
    }

    private func makeFinalReview(for assignment: AssignmentRecord, status: FinalReviewStatus) -> FinalGradeReview {
        FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: status,
            criteria: [
                FinalCriterionScore(
                    criterionID: "claim",
                    criterion: "Claim",
                    rating: "Proficient",
                    proposedPoints: 3,
                    finalPoints: 3,
                    maxPoints: 4,
                    evidence: ["The school should have longer lunch breaks"],
                    explanation: "Clear claim stated in opening sentence.",
                    teacherApproved: status == .approved
                ),
                FinalCriterionScore(
                    criterionID: "evidence",
                    criterion: "Evidence",
                    rating: "Developing",
                    proposedPoints: 2,
                    finalPoints: 2,
                    maxPoints: 3,
                    evidence: ["studies show rushed meals lead to poor nutrition"],
                    explanation: "One citation present; vague source reference.",
                    teacherApproved: status == .approved
                ),
                FinalCriterionScore(
                    criterionID: "language",
                    criterion: "Language",
                    rating: "Proficient",
                    proposedPoints: 2,
                    finalPoints: 2,
                    maxPoints: 3,
                    evidence: [],
                    explanation: "Academic language consistent throughout.",
                    teacherApproved: status == .approved
                )
            ],
            totalScore: 7,
            maxScore: 10,
            studentFeedback: "Good work establishing a clear position and supporting it with evidence. To improve, name your sources specifically and include a second example for the social benefits argument.",
            privateTeacherNotes: "Solid effort. Source citation needs work next time.",
            teacherEdited: true
        )
    }

    private func makeClassRoster() -> [AssignmentRecord] {
        let rubric = "Claim: 0–4 pts\nEvidence: 0–3 pts\nLanguage: 0–3 pts"
        func base(_ student: String) -> AssignmentRecord {
            AssignmentRecord(
                title: "Year 6 Persuasive Essay",
                subject: "English",
                gradeLevel: "Year 6",
                className: "6A",
                studentDisplayName: student,
                assignmentType: .essay,
                rubricText: rubric,
                reviewedStudentText: "Student response for \(student).",
                ocrReviewStatus: .reviewed
            )
        }

        var alex = base("Alex Thompson")
        alex.finalReview = makeFinalReview(for: alex, status: .approved)

        var bailey = base("Bailey Chen")
        bailey.finalReview = makeFinalReview(for: bailey, status: .approved)

        var cameron = base("Cameron Smith")
        cameron.latestDraft = makeDraft(for: cameron)

        var dana = base("Dana Wilson")
        dana.latestDraft = makeDraft(for: dana)
        dana.finalReview = makeFinalReview(for: dana, status: .inProgress)

        let elliot = base("Elliot Park")

        var fiona = base("Fiona Brooks")
        fiona.ocrReviewStatus = .needsReview

        return [alex, bailey, cameron, dana, elliot, fiona]
    }
}
