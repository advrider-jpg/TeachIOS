import Foundation
import SwiftUI
import UIKit
import XCTest

@testable import GradeDraft

final class NativeUIRefactorSnapshotTests: XCTestCase {
    @MainActor
    func testHomeScreenNativeListSnapshot() {
        let viewModel = NativeUITestFixture.viewModel(selecting: .readyToExport)
        assertNativeSnapshot(screen: "HomeScreen", sourceFile: "HomeScreen.swift", expectedContainer: .list) {
            HomeScreen(viewModel: viewModel)
        }
    }

    @MainActor
    func testClassesScreenNativeListSnapshot() {
        let viewModel = NativeUITestFixture.viewModel(selecting: .readyToExport)
        assertNativeSnapshot(screen: "ClassesScreen", sourceFile: "ClassesScreen.swift", expectedContainer: .list) {
            ClassesScreen(viewModel: viewModel)
        }
    }

    @MainActor
    func testAssignmentsScreenNativeListSnapshot() {
        let viewModel = NativeUITestFixture.viewModel(selecting: .readyToExport)
        assertNativeSnapshot(screen: "AssignmentsScreen", sourceFile: "AssignmentsScreen.swift", expectedContainer: .list) {
            AssignmentsScreen(viewModel: viewModel)
        }
    }

    @MainActor
    func testReviewScreenNativeListSnapshot() {
        let viewModel = NativeUITestFixture.viewModel(selecting: .ocrReview)
        assertNativeSnapshot(screen: "ReviewScreen", sourceFile: "ReviewScreen.swift", expectedContainer: .list) {
            ReviewScreen(viewModel: viewModel)
        }
    }

    @MainActor
    func testAssignmentOverviewNativeFormSnapshot() {
        let viewModel = NativeUITestFixture.viewModel(selecting: .ocrReview)
        let assignmentID = viewModel.assignment.id
        assertNativeSnapshot(screen: "AssignmentOverviewScreen", sourceFile: "AssignmentOverviewScreen.swift", expectedContainer: .form) {
            AssignmentOverviewScreen(viewModel: viewModel, assignmentID: assignmentID)
        }
    }

    @MainActor
    func testStudentWorkNativeFormSnapshot() {
        let viewModel = NativeUITestFixture.viewModel(selecting: .studentWork)
        let assignmentID = viewModel.assignment.id
        assertNativeSnapshot(screen: "StudentWorkScreen", sourceFile: "StudentWorkScreen.swift", expectedContainer: .form) {
            StudentWorkScreen(viewModel: viewModel, assignmentID: assignmentID)
        }
    }

    @MainActor
    func testReviewScannedTextNativeListSnapshot() {
        let viewModel = NativeUITestFixture.viewModel(selecting: .ocrReview)
        let assignmentID = viewModel.assignment.id
        assertNativeSnapshot(screen: "ReviewScannedTextScreen", sourceFile: "ReviewScannedTextScreen.swift", expectedContainer: .list) {
            ReviewScannedTextScreen(viewModel: viewModel, assignmentID: assignmentID)
        }
    }

    @MainActor
    func testFinalReviewNativeFormSnapshot() {
        let viewModel = NativeUITestFixture.viewModel(selecting: .finalReview)
        let assignmentID = viewModel.assignment.id
        assertNativeSnapshot(screen: "FinalReviewScreen", sourceFile: "FinalReviewScreen.swift", expectedContainer: .form) {
            FinalReviewScreen(viewModel: viewModel, assignmentID: assignmentID)
        }
    }

    @MainActor
    func testExportsRestoreScreenNativeFormSnapshot() {
        let viewModel = NativeUITestFixture.viewModel(selecting: .readyToExport)
        assertNativeSnapshot(screen: "ExportsRestoreScreen", sourceFile: "ExportsRestoreScreen.swift", expectedContainer: .form) {
            ExportsRestoreScreen(viewModel: viewModel)
        }
    }

    @MainActor
    func testSettingsPrivacyNativeFormSnapshot() {
        let viewModel = NativeUITestFixture.viewModel(selecting: .readyToExport)
        assertNativeSnapshot(screen: "SettingsAboutLocalPrivacyScreen", sourceFile: "SettingsAboutLocalPrivacyScreen.swift", expectedContainer: .form) {
            SettingsAboutLocalPrivacyScreen(viewModel: viewModel)
        }
    }

    @MainActor
    func testRubricInstructionsNativeFormSnapshot() {
        let viewModel = NativeUITestFixture.viewModel(selecting: .readyToExport)
        let assignmentID = viewModel.assignment.id
        assertNativeSnapshot(screen: "RubricInstructionsScreen", sourceFile: "RubricInstructionsScreen.swift", expectedContainer: .form) {
            RubricInstructionsScreen(viewModel: viewModel, assignmentID: assignmentID)
        }
    }

    @MainActor
    private func assertNativeSnapshot<Content: View>(
        screen: String,
        sourceFile: String,
        expectedContainer: NativeContainer,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        @ViewBuilder content: () -> Content
    ) {
        let snapshot = NativeHostedScreenSnapshot.make(
            screen: screen,
            sourceFile: sourceFile,
            expectedContainer: expectedContainer,
            content: content
        )
        XCTAssertTrue(snapshot.renderedNativeContainerPresent,
                      "\(screen) should host a rendered native \(expectedContainer.rawValue)-backed hierarchy.",
                      file: file, line: line)

        // Compare directly against the committed reference so CI never tries to write snapshots.
        let referenceName = testName.replacingOccurrences(of: "()", with: "")
        let referenceURL = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent()
            .appendingPathComponent("__Snapshots__")
            .appendingPathComponent("NativeUIRefactorSnapshotTests")
            .appendingPathComponent("\(referenceName).1.txt")
        guard let stored = try? String(contentsOf: referenceURL, encoding: .utf8) else {
            XCTFail("Missing snapshot reference: \(referenceURL.lastPathComponent). "
                + "Run the test locally and commit the generated file.",
                    file: file, line: line)
            return
        }
        // Normalize line endings for comparison so Windows-authored files always match.
        let normalizedStored = stored.replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: CharacterSet.newlines)
        let normalizedActual = snapshot.renderedSummary
            .trimmingCharacters(in: CharacterSet.newlines)
        XCTAssertEqual(normalizedActual, normalizedStored,
                       "Snapshot mismatch for \(screen). Update the .txt file in "
                       + "__Snapshots__/NativeUIRefactorSnapshotTests/ if the source changed intentionally.",
                       file: file, line: line)
    }
}

private enum NativeContainer: String {
    case list = "List"
    case form = "Form"
}

private struct NativeHostedScreenSnapshot {
    var renderedSummary: String
    var renderedNativeContainerPresent: Bool

    @MainActor
    static func make<Content: View>(
        screen: String,
        sourceFile: String,
        expectedContainer: NativeContainer,
        @ViewBuilder content: () -> Content
    ) -> NativeHostedScreenSnapshot {
        let hosted = UIHostingController(rootView: AnyView(NavigationStack { content() }))
        let frame = CGRect(origin: .zero, size: CGSize(width: 390, height: 844))
        let window = UIWindow(frame: frame)
        window.rootViewController = hosted
        window.isHidden = false
        hosted.view.frame = frame
        hosted.loadViewIfNeeded()
        hosted.view.setNeedsLayout()
        hosted.view.layoutIfNeeded()
        window.layoutIfNeeded()

        let renderedContainerPresent = renderedHierarchyContainsNativeContainer(
            expectedContainer,
            rootView: hosted.view
        )
        let renderedClassNames = renderedViewClassNames(hosted.view)
        let nativeControls = renderedNativeControls(in: renderedClassNames)

        let summary = [
            [
                "screen: \(screen)",
                "hostedController: UIHostingController",
                "hostedViewLoaded: \(hosted.isViewLoaded)",
                "hostedViewSize: \(Int(hosted.view.bounds.width))x\(Int(hosted.view.bounds.height))",
                "expectedContainer: \(expectedContainer.rawValue)",
                "renderedNativeContainerPresent: \(renderedContainerPresent)",
                "nativeControls:"
            ],
            bulletLines(nativeControls)
        ].flatMap { $0 }.joined(separator: "\n")

        return NativeHostedScreenSnapshot(
            renderedSummary: summary,
            renderedNativeContainerPresent: renderedContainerPresent
        )
    }

    @MainActor
    private static func renderedHierarchyContainsNativeContainer(_ container: NativeContainer, rootView: UIView) -> Bool {
        let classNames = renderedViewClassNames(rootView)
        switch container {
        case .list:
            return classNames.contains { className in
                className.contains("CollectionView") || className.contains("TableView") || className.contains("List")
            }
        case .form:
            return classNames.contains { className in
                className.contains("CollectionView") || className.contains("TableView") || className.contains("Form")
            }
        }
    }

    @MainActor
    private static func renderedViewClassNames(_ view: UIView) -> [String] {
        [String(describing: type(of: view))] + view.subviews.flatMap(renderedViewClassNames)
    }

    private static func renderedNativeControls(in classNames: [String]) -> [String] {
        let rendered = [
            ("CollectionView", "CollectionView"),
            ("TableView", "TableView"),
            ("List", "List"),
            ("Form", "Form"),
            ("ScrollView", "ScrollView"),
            ("Navigation", "Navigation")
        ].compactMap { needle, label in
            classNames.contains { $0.contains(needle) } ? label : nil
        }
        return rendered.isEmpty ? ["none"] : rendered
    }

    private static func bulletLines(_ values: [String]) -> [String] {
        if values.isEmpty { return ["- none"] }
        return values.map { "- \($0)" }
    }
}

private enum NativeAssignmentSelection {
    case readyToExport
    case ocrReview
    case finalReview
    case studentWork
}

private enum NativeUITestFixture {
    @MainActor
    static func viewModel(selecting selection: NativeAssignmentSelection) -> GradeDraftViewModel {
        let assignments = makeAssignments()
        let store = InMemoryAssignmentStore(assignments: assignments)
        let viewModel = GradeDraftViewModel(assignments: assignments, store: store)

        let selectedTitle: String
        switch selection {
        case .readyToExport:
            selectedTitle = "Ready to Export Essay"
        case .ocrReview:
            selectedTitle = "Check Scanned Text Essay"
        case .finalReview:
            selectedTitle = "Final Review Essay"
        case .studentWork:
            selectedTitle = "Student Work Intake"
        }
        if let selected = viewModel.assignments.first(where: { $0.title == selectedTitle }) {
            viewModel.selectAssignment(selected.id)
            let exportURL = URL(fileURLWithPath: "/tmp/gradedraft-student-report.md")
            viewModel.exportURL = exportURL
            viewModel.exportKind = .studentMarkdown
            viewModel.preparedExportArtifact = PreparedExportArtifact(
                assignmentID: selected.id,
                kind: .studentMarkdown,
                url: exportURL,
                createdAt: Date(timeIntervalSince1970: 1_800_000_000)
            )
        }
        return viewModel
    }

    private static func makeAssignments() -> [AssignmentRecord] {
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

        var ocr = baseAssignment(title: "Check Scanned Text Essay", student: "Bailey Chen")
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
                        OCRLine(text: "The school should extend lunch.", confidence: 0.62, boundingBox: NormalizedRect(x: 0.12, y: 0.72, width: 0.72, height: 0.05)),
                        OCRLine(text: "Students need time to eat and reset.", confidence: 0.93, boundingBox: NormalizedRect(x: 0.12, y: 0.64, width: 0.70, height: 0.05), teacherConfirmed: true)
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

    private static var fixedDate: Date {
        Date(timeIntervalSince1970: 1_700_000_000)
    }

    private static func baseAssignment(title: String, student: String) -> AssignmentRecord {
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

    private static func draft(for assignment: AssignmentRecord) -> GradeDraftResult {
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

    private static func finalReview(for assignment: AssignmentRecord, status: FinalReviewStatus) -> FinalGradeReview {
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
