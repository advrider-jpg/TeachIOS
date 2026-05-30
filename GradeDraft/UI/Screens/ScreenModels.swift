import SwiftUI

enum ReviewSegment: String, CaseIterable, Identifiable {
    case all = "All"
    case scannedText = "Scanned Text"
    case finalReview = "Final Review"
    case needsRecheck = "Needs Recheck"

    var id: String { rawValue }
}


struct ReviewNavigationItem: Identifiable, Equatable {
    enum Destination: Equatable {
        case studentWork(UUID)
        case reviewScannedText(UUID)
        case finalReview(UUID)
        case assignmentOverview(UUID)
    }

    var id: String
    var title: String
    var detail: String
    var countText: String?
    var status: GradeDraftUIStatus
    var actionLabel: String
    var destination: Destination

    @ViewBuilder
    func destinationView(viewModel: GradeDraftViewModel) -> some View {
        switch destination {
        case .studentWork(let id):
            StudentWorkScreen(viewModel: viewModel, assignmentID: id)
        case .reviewScannedText(let id):
            ReviewScannedTextScreen(viewModel: viewModel, assignmentID: id)
        case .finalReview(let id):
            FinalReviewScreen(viewModel: viewModel, assignmentID: id)
        case .assignmentOverview(let id):
            AssignmentOverviewScreen(viewModel: viewModel, assignmentID: id)
        }
    }
}


struct ClassSummary: Identifiable, Equatable {
    var id: String { name.lowercased() }
    var name: String
    var subject: String
    var studentCount: Int
    var assignmentCount: Int
}


struct RecentExportRow: Identifiable, Equatable {
    var id: String
    var assignmentTitle: String
    var kind: ExportKind
    var createdAt: Date
}


extension GradeDraftViewModel {
    func assignment(for id: UUID) -> AssignmentRecord? {
        assignments.first(where: { $0.id == id })
    }

    var classSummaries: [ClassSummary] {
        let classNames = Set(classGroups.map(\.name) + assignments.map(\.className).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        return classNames.sorted().map { name in
            let matchingAssignments = assignments.filter { $0.className.caseInsensitiveCompare(name) == .orderedSame }
            let explicitClass = classGroups.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
            let matchingStudents = students.filter { $0.className.caseInsensitiveCompare(name) == .orderedSame }
            return ClassSummary(
                name: name,
                subject: explicitClass?.subject.nilIfBlank ?? matchingAssignments.first?.subject ?? "Class",
                studentCount: matchingStudents.isEmpty ? Set(matchingAssignments.map(\.studentDisplayName).filter { !$0.isEmpty }).count : matchingStudents.count,
                assignmentCount: matchingAssignments.count
            )
        }
    }

    var scannedTextReviewAssignments: [AssignmentRecord] {
        assignments.filter { $0.ocrReviewStatus.blocksGrading }
    }

    var finalReviewAssignments: [AssignmentRecord] {
        assignments.filter { assignment in
            let savedReviewNeedsAttention = assignment.finalReview != nil && assignment.finalReview?.status != .approved
            let suggestionNeedsFinalReview = assignment.latestDraft != nil && assignment.finalReview == nil
            return savedReviewNeedsAttention || suggestionNeedsFinalReview
        }
    }

    var readyToExportAssignments: [AssignmentRecord] {
        assignments.filter { $0.finalReview?.status == .approved && !$0.finalReviewIsStale }
    }

    var assignmentsNeedingAction: [AssignmentRecord] {
        assignments.filter { v6Status(for: $0) != .approved && v6Status(for: $0) != .exported && v6Status(for: $0) != .readyToExport }
    }

    var homeAttentionItems: [ReviewNavigationItem] {
        Array(reviewItems(for: .all).prefix(6))
    }

    var recentExportRows: [RecentExportRow] {
        assignments.flatMap { assignment in
            assignment.exportRecords.map { record in
                RecentExportRow(
                    id: "\(assignment.id.uuidString)-\(record.id.uuidString)",
                    assignmentTitle: assignment.title,
                    kind: record.exportKind,
                    createdAt: record.createdAt
                )
            }
        }
        .sorted { $0.createdAt > $1.createdAt }
        .prefix(6)
        .map { $0 }
    }

    func reviewItems(for segment: ReviewSegment) -> [ReviewNavigationItem] {
        assignments.compactMap { assignment in
            let status = v6Status(for: assignment)
            let item: ReviewNavigationItem?
            switch status {
            case .addStudentWork:
                item = ReviewNavigationItem(
                    id: "work-\(assignment.id.uuidString)",
                    title: "Add student work",
                    detail: rowDetail(for: assignment),
                    countText: nil,
                    status: .addStudentWork,
                    actionLabel: "Add Work",
                    destination: .studentWork(assignment.id)
                )
            case .reviewScannedText, .textNeedsAttention:
                let count = assignment.ocrDocument?.unresolvedLineCount ?? 0
                item = ReviewNavigationItem(
                    id: "text-\(assignment.id.uuidString)",
                    title: GradeDraftUIStatus.reviewScannedText.rawValue,
                    detail: rowDetail(for: assignment),
                    countText: "\(count) lines",
                    status: status,
                    actionLabel: GradeDraftWorkflowLanguage.reviewTextActionLabel,
                    destination: .reviewScannedText(assignment.id)
                )
            case .needsRecheck:
                item = ReviewNavigationItem(
                    id: "recheck-\(assignment.id.uuidString)",
                    title: "Needs recheck",
                    detail: rowDetail(for: assignment),
                    countText: nil,
                    status: .needsRecheck,
                    actionLabel: "Recheck Review",
                    destination: .finalReview(assignment.id)
                )
            case .reviewFinalGrade:
                item = ReviewNavigationItem(
                    id: "final-\(assignment.id.uuidString)",
                    title: "Review final grade",
                    detail: rowDetail(for: assignment),
                    countText: nil,
                    status: .reviewFinalGrade,
                    actionLabel: "Final Review",
                    destination: .finalReview(assignment.id)
                )
            default:
                item = nil
            }
            guard let item else { return nil }
            switch segment {
            case .all:
                return item
            case .scannedText:
                return item.status == .reviewScannedText || item.status == .textNeedsAttention ? item : nil
            case .finalReview:
                return item.status == .reviewFinalGrade ? item : nil
            case .needsRecheck:
                return item.status == .needsRecheck ? item : nil
            }
        }
    }

    func v6Status(for assignment: AssignmentRecord) -> GradeDraftUIStatus {
        if assignment.finalReviewIsStale || assignment.latestDraftIsStale {
            return .needsRecheck
        }
        // Only show "Exported" when the approved final review is still current.
        // If the final review is nil (e.g. a new draft was started after export) or
        // not approved, fall through so the assignment surfaces in the review queue.
        if assignment.finalReview?.status == .approved,
           assignment.exportRecords.contains(where: { $0.exportKind == .studentPDF || $0.exportKind == .zipArchive }) {
            return .exported
        }
        if assignment.finalReview?.status == .approved {
            return .readyToExport
        }
        if assignment.finalReview != nil || assignment.latestDraft != nil {
            return .reviewFinalGrade
        }
        if assignment.ocrReviewStatus == .blocked {
            return .textNeedsAttention
        }
        if assignment.ocrReviewStatus.blocksGrading {
            return .reviewScannedText
        }
        if assignment.reviewedStudentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .addStudentWork
        }
        if assignment.hasGradingStandard {
            return .readyForTeacherReview
        }
        return .notStarted
    }

    func v6ActionLabel(for assignment: AssignmentRecord) -> String {
        switch v6Status(for: assignment) {
        case .reviewScannedText, .textNeedsAttention:
            return GradeDraftWorkflowLanguage.reviewTextActionLabel
        case .reviewFinalGrade:
            return "Final Review"
        case .readyToExport:
            return "Export"
        case .exported:
            return "View Export"
        case .needsRecheck:
            return "Recheck Review"
        case .addStudentWork:
            return "Add Work"
        case .readyForTeacherReview, .inProgress:
            return "Final Review"
        case .notStarted, .needsAttention, .fixBeforeContinuing, .onTrack, .approved, .studentFacing, .teacherOnly:
            return "Open"
        }
    }

    private func rowDetail(for assignment: AssignmentRecord) -> String {
        [assignment.studentDisplayName.nilIfBlank ?? "No student selected", assignment.className.nilIfBlank, assignment.title.nilIfBlank]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}
