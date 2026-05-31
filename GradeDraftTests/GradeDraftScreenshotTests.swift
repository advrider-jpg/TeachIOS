import SwiftUI
import UIKit
import XCTest

@testable import GradeDraft

/// Renders every core app page to PNG files stored in the app's
/// Documents/GradeDraftScreenshots/ directory, which CI can retrieve via
/// `xcrun simctl get_app_container`.
/// Each image is also attached as an XCTAttachment (visible in the .xcresult bundle).
@MainActor
final class GradeDraftScreenshotTests: XCTestCase {
    private static let corePageScreenshots: [CorePageScreenshotCase] = [
        CorePageScreenshotCase(imageName: "01-home", sourceFile: "HomeScreen.swift"),
        CorePageScreenshotCase(imageName: "02-classes", sourceFile: "ClassesScreen.swift"),
        CorePageScreenshotCase(imageName: "03-class-detail-roster", sourceFile: "ClassDetailRosterScreen.swift"),
        CorePageScreenshotCase(imageName: "04-assignments", sourceFile: "AssignmentsScreen.swift"),
        CorePageScreenshotCase(imageName: "05-assignment-overview", sourceFile: "AssignmentOverviewScreen.swift"),
        CorePageScreenshotCase(imageName: "06-student-work", sourceFile: "StudentWorkScreen.swift"),
        CorePageScreenshotCase(imageName: "07-review", sourceFile: "ReviewScreen.swift"),
        CorePageScreenshotCase(imageName: "08-review-scanned-text", sourceFile: "ReviewScannedTextScreen.swift"),
        CorePageScreenshotCase(imageName: "09-final-review", sourceFile: "FinalReviewScreen.swift"),
        CorePageScreenshotCase(imageName: "10-exports-restore", sourceFile: "ExportsRestoreScreen.swift"),
        CorePageScreenshotCase(imageName: "11-settings-local-privacy", sourceFile: "SettingsAboutLocalPrivacyScreen.swift"),
        CorePageScreenshotCase(imageName: "12-rubric-instructions", sourceFile: "RubricInstructionsScreen.swift")
    ]

    // MARK: - Coverage Contract

    func testCorePageScreenshotManifestMatchesScreenFiles() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let screensURL = repoRoot
            .appendingPathComponent("GradeDraft")
            .appendingPathComponent("UI")
            .appendingPathComponent("Screens")

        let screenSourceFiles = try FileManager.default.contentsOfDirectory(atPath: screensURL.path)
            .filter { $0.hasSuffix("Screen.swift") }
            .filter { $0 != "ScreenModels.swift" }
        let expectedSourceFiles = Set(Self.corePageScreenshots.map(\.sourceFile))
        XCTAssertEqual(Set(screenSourceFiles), expectedSourceFiles,
                       "Every core app page under GradeDraft/UI/Screens must have a screenshot case.")

        let expectedImageNames = Set(Self.corePageScreenshots.map(\.imageName))
        XCTAssertEqual(expectedImageNames.count, Self.corePageScreenshots.count,
                       "Core app page screenshot names must be unique.")
    }

    // MARK: - Core Pages

    func testCaptureHomeScreen() throws {
        let viewModel = makeCorePageViewModel(selecting: .readyToExport)
        try snapshot("01-home", NavigationStack { HomeScreen(viewModel: viewModel) }, to: prepareScreenshotDirectory())
    }

    func testCaptureClassesScreen() throws {
        let viewModel = makeCorePageViewModel(selecting: .readyToExport)
        try snapshot("02-classes", NavigationStack { ClassesScreen(viewModel: viewModel) }, to: prepareScreenshotDirectory())
    }

    func testCaptureClassDetailRosterScreen() throws {
        let viewModel = makeCorePageViewModel(selecting: .readyToExport)
        let classSummary = try XCTUnwrap(viewModel.classSummaries.first)
        try snapshot("03-class-detail-roster",
                     NavigationStack { ClassDetailRosterScreen(viewModel: viewModel, classSummary: classSummary) },
                     to: prepareScreenshotDirectory())
    }

    func testCaptureAssignmentsScreen() throws {
        let viewModel = makeCorePageViewModel(selecting: .readyToExport)
        try snapshot("04-assignments", NavigationStack { AssignmentsScreen(viewModel: viewModel) }, to: prepareScreenshotDirectory())
    }

    func testCaptureAssignmentOverviewScreen() throws {
        let viewModel = makeCorePageViewModel(selecting: .ocrReview)
        let assignmentID = viewModel.assignment.id
        try snapshot("05-assignment-overview",
                     NavigationStack { AssignmentOverviewScreen(viewModel: viewModel, assignmentID: assignmentID) },
                     to: prepareScreenshotDirectory())
    }

    func testCaptureStudentWorkScreen() throws {
        let viewModel = makeCorePageViewModel(selecting: .studentWork)
        let assignmentID = viewModel.assignment.id
        try snapshot("06-student-work",
                     NavigationStack { StudentWorkScreen(viewModel: viewModel, assignmentID: assignmentID) },
                     to: prepareScreenshotDirectory())
    }

    func testCaptureReviewScreen() throws {
        let viewModel = makeCorePageViewModel(selecting: .ocrReview)
        try snapshot("07-review", NavigationStack { ReviewScreen(viewModel: viewModel) }, to: prepareScreenshotDirectory())
    }

    func testCaptureReviewScannedTextScreen() throws {
        let viewModel = makeCorePageViewModel(selecting: .ocrReview)
        let assignmentID = viewModel.assignment.id
        try snapshot("08-review-scanned-text",
                     NavigationStack { ReviewScannedTextScreen(viewModel: viewModel, assignmentID: assignmentID) },
                     to: prepareScreenshotDirectory())
    }

    func testCaptureFinalReviewScreen() throws {
        let viewModel = makeCorePageViewModel(selecting: .finalReview)
        let assignmentID = viewModel.assignment.id
        try snapshot("09-final-review",
                     NavigationStack { FinalReviewScreen(viewModel: viewModel, assignmentID: assignmentID) },
                     to: prepareScreenshotDirectory())
    }

    func testCaptureExportsRestoreScreen() throws {
        let viewModel = makeCorePageViewModel(selecting: .readyToExport)
        try snapshot("10-exports-restore",
                     NavigationStack { ExportsRestoreScreen(viewModel: viewModel) },
                     to: prepareScreenshotDirectory())
    }

    func testCaptureSettingsLocalPrivacyScreen() throws {
        let viewModel = makeCorePageViewModel(selecting: .readyToExport)
        try snapshot("11-settings-local-privacy",
                     NavigationStack { SettingsAboutLocalPrivacyScreen(viewModel: viewModel) },
                     to: prepareScreenshotDirectory())
    }

    func testCaptureRubricInstructionsScreen() throws {
        let viewModel = makeCorePageViewModel(selecting: .readyToExport)
        let assignmentID = viewModel.assignment.id
        try snapshot("12-rubric-instructions",
                     NavigationStack { RubricInstructionsScreen(viewModel: viewModel, assignmentID: assignmentID) },
                     to: prepareScreenshotDirectory())
    }

    // MARK: - Rendering

    private func snapshot<V: View>(_ name: String, _ view: V, to dir: URL) throws {
        let image = render(view)
        let data = try XCTUnwrap(image.pngData())
        try data.write(to: dir.appendingPathComponent("\(name).png"))

        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func render<V: View>(_ view: V, size: CGSize = CGSize(width: 390, height: 844)) -> UIImage {
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

    private func prepareScreenshotDirectory() throws -> URL {
        let docs = try XCTUnwrap(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first)
        let dir = docs.appendingPathComponent("GradeDraftScreenshots")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Sample data factories

    private func makeCorePageViewModel(selecting selection: CoreScreenshotAssignmentSelection) -> GradeDraftViewModel {
        let assignments = makeAssignments()
        let store = InMemoryAssignmentStore(assignments: assignments)
        let viewModel = GradeDraftViewModel(assignments: assignments, store: store)
        viewModel.exportURL = URL(fileURLWithPath: "/tmp/gradedraft-student-report.md")
        viewModel.exportKind = .studentMarkdown
        viewModel.latestRosterPreview = RosterImportService.preview(
            csvText: "Name,Student ID\nAlex Thompson,A001\nBailey Chen,B002\nCameron Smith,C003",
            defaultClassName: "6A"
        )

        let selectedTitle: String
        switch selection {
        case .readyToExport:
            selectedTitle = "Ready to Export Essay"
        case .ocrReview:
            selectedTitle = "OCR Review Essay"
        case .finalReview:
            selectedTitle = "Final Review Essay"
        case .studentWork:
            selectedTitle = "Student Work Intake"
        }
        if let selected = viewModel.assignments.first(where: { $0.title == selectedTitle }) {
            viewModel.selectAssignment(selected.id)
        }
        return viewModel
    }

    private func makeAssignments() -> [AssignmentRecord] {
        var ready = baseAssignment(title: "Ready to Export Essay", student: "Alex Thompson")
        ready.latestDraft = draft(for: ready)
        ready.finalReview = finalReview(for: ready, status: .approved)
        ready.exportRecords = [
            ExportRecord(
                exportKind: .studentMarkdown,
                createdAt: fixedDate,
                contentFingerprint: "student-report-fingerprint",
                includesPrivateTeacherNotes: false,
                includesOriginalSources: false
            )
        ]

        var ocr = baseAssignment(title: "OCR Review Essay", student: "Bailey Chen")
        let sourceID = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
        ocr.sourceInputs = [
            SourceInputRef(
                id: sourceID,
                sourceType: .scan,
                pageIndex: 0,
                fileName: "bailey-scan.jpg",
                contentDigest: "scan-digest",
                digestAlgorithm: "fnv1a64",
                imageWidth: 1200,
                imageHeight: 1600,
                teacherIncludedInExport: false,
                createdAt: fixedDate
            )
        ]
        ocr.ocrDocument = OCRDocument(
            pages: [
                OCRPage(
                    sourceInputID: sourceID,
                    pageIndex: 0,
                    imageWidth: 1200,
                    imageHeight: 1600,
                    lines: [
                        OCRLine(text: "The school should extend lunch.",
                                confidence: 0.62,
                                boundingBox: NormalizedRect(x: 0.12, y: 0.72, width: 0.72, height: 0.05)),
                        OCRLine(text: "Students need time to eat and reset.",
                                confidence: 0.93,
                                boundingBox: NormalizedRect(x: 0.12, y: 0.64, width: 0.70, height: 0.05),
                                teacherConfirmed: true)
                    ]
                )
            ],
            createdAt: fixedDate,
            reviewStatus: .needsReview
        )
        ocr.ocrReviewStatus = .needsReview
        ocr.reviewedStudentText = "The school should extend lunch. Students need time to eat and reset."
        ocr.latestDraft = draft(for: ocr)
        ocr.finalReview = finalReview(for: ocr, status: .inProgress)

        var final = baseAssignment(title: "Final Review Essay", student: "Cameron Smith")
        final.latestDraft = draft(for: final)
        final.finalReview = finalReview(for: final, status: .inProgress)

        var intake = baseAssignment(title: "Student Work Intake", student: "Dana Wilson")
        intake.reviewedStudentText = ""
        intake.sourceInputs = [
            SourceInputRef(
                sourceType: .pastedText,
                fileName: "pasted-work.txt",
                contentDigest: "pasted-digest",
                digestAlgorithm: "fnv1a64",
                teacherIncludedInExport: false,
                createdAt: fixedDate
            )
        ]
        intake.ocrReviewStatus = .notNeeded

        return [ready, ocr, final, intake]
    }

    private var fixedDate: Date {
        Date(timeIntervalSince1970: 1_700_000_000)
    }

    private func baseAssignment(title: String, student: String) -> AssignmentRecord {
        AssignmentRecord(
            title: title,
            subject: "English",
            gradeLevel: "Year 6",
            className: "6A",
            studentDisplayName: student,
            assignmentType: .essay,
            rubricText: "Claim: 0-4 pts\nEvidence: 0-3 pts\nLanguage: 0-3 pts",
            reviewedStudentText: "The school should have longer lunch breaks because students need time to eat, reset, and return ready to learn.",
            ocrReviewStatus: .reviewed,
            createdAt: fixedDate,
            updatedAt: fixedDate
        )
    }

    private func draft(for assignment: AssignmentRecord) -> GradeDraftResult {
        GradeDraftResult(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .teacherReviewRequired,
            studentResponseSummary: "Student makes a clear claim and supports it with relevant reasons.",
            criteria: [
                CriterionScore(
                    criterionID: "claim",
                    criterion: "Claim",
                    rating: "Proficient",
                    proposedPoints: 3,
                    maxPoints: 4,
                    evidence: ["The school should have longer lunch breaks"],
                    explanation: "The response states a clear position.",
                    teacherReviewRequired: false
                ),
                CriterionScore(
                    criterionID: "evidence",
                    criterion: "Evidence",
                    rating: "Developing",
                    proposedPoints: 2,
                    maxPoints: 3,
                    evidence: ["students need time to eat"],
                    explanation: "The response includes a reason, but more precise support would strengthen it.",
                    teacherReviewRequired: false
                )
            ],
            totalScore: 5,
            maxScore: 7,
            studentFeedback: "Your claim is clear. Add one more specific example to strengthen the evidence.",
            teacherNotes: "Check evidence before approving.",
            uncertaintyFlags: []
        )
    }

    private func finalReview(for assignment: AssignmentRecord, status: FinalReviewStatus) -> FinalGradeReview {
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
                    explanation: "The response states a clear position.",
                    teacherApproved: status == .approved
                ),
                FinalCriterionScore(
                    criterionID: "evidence",
                    criterion: "Evidence",
                    rating: "Developing",
                    proposedPoints: 2,
                    finalPoints: 2,
                    maxPoints: 3,
                    evidence: ["students need time to eat"],
                    explanation: "The response gives a reason but needs more precise support.",
                    teacherApproved: status == .approved
                )
            ],
            totalScore: 5,
            maxScore: 7,
            studentFeedback: "Your claim is clear. Add one more specific example to strengthen the evidence.",
            privateTeacherNotes: "Evidence support remains the growth area.",
            teacherEdited: true
        )
    }
}

private struct CorePageScreenshotCase: Equatable {
    var imageName: String
    var sourceFile: String
}

private enum CoreScreenshotAssignmentSelection {
    case readyToExport
    case ocrReview
    case finalReview
    case studentWork
}
