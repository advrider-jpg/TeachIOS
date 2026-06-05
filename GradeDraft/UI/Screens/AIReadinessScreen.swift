import SwiftUI

struct AIReadinessScreen: View {
    @ObservedObject var viewModel: GradeDraftViewModel
    var assignmentID: UUID

    private var assignment: AssignmentRecord? {
        viewModel.assignment(for: assignmentID)
    }

    private var report: AIReadinessReport? {
        guard viewModel.aiReadinessReport?.assignmentID == assignmentID else { return nil }
        return viewModel.aiReadinessReport
    }

    private var preview: AIPacketPreview? {
        guard viewModel.aiPacketPreview?.assignmentID == assignmentID else { return nil }
        return viewModel.aiPacketPreview
    }

    var body: some View {
        Form {
            if let assignment {
                Section {
                    header(for: assignment)
                }

                Section("Readiness Checks") {
                    if let report {
                        ForEach(report.checks) { check in
                            readinessRow(check)
                        }
                    } else {
                        Text("Refresh readiness to inspect this assignment's local AI gates.")
                            .foregroundStyle(.secondary)
                    }
                }

                if let report, !report.promptInjectionRisks.isEmpty {
                    Section("Prompt-Injection Review") {
                        Label("Review flagged packet fields before drafting.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        ForEach(report.promptInjectionRisks, id: \.self) { field in
                            Text(field)
                                .font(.caption)
                        }
                    }
                }

                if let preview {
                    Section("Included in Local Draft") {
                        packetList(preview.includedInLocalDraft, systemImage: "checkmark.circle")
                    }

                    Section("Not Sent to Model") {
                        packetList(preview.notSentToModel, systemImage: "eye.slash")
                    }

                    Section("Generation Plan") {
                        packetList(preview.generationPlan, systemImage: "slider.horizontal.3")
                    }

                    Section("Technical Packet") {
                        LabeledContent("Prompt version", value: preview.promptVersion)
                        LabeledContent("Prompt fingerprint", value: preview.promptFingerprint)
                        LabeledContent("Packet fingerprint", value: preview.packetFingerprint)
                        DisclosureGroup("Model-visible metadata") {
                            packetList(preview.modelVisibleMetadata, systemImage: "number")
                        }
                        DisclosureGroup("Prompt preview") {
                            Text(preview.technicalPromptPreview)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                }

                Section {
                    Button {
                        viewModel.selectAssignment(assignmentID)
                        viewModel.buildAIPacketPreview()
                    } label: {
                        Label("Refresh Packet Preview", systemImage: "arrow.clockwise")
                    }

                    NavigationLink {
                        RubricInstructionsScreen(viewModel: viewModel, assignmentID: assignmentID)
                    } label: {
                        Label("Edit Rubric and Constraints", systemImage: "slider.horizontal.3")
                    }

                    if assignment.ocrReviewStatus.blocksGrading {
                        NavigationLink {
                            ReviewScannedTextScreen(viewModel: viewModel, assignmentID: assignmentID)
                        } label: {
                            Label(GradeDraftWorkflowLanguage.reviewTextActionLabel, systemImage: "text.viewfinder")
                        }
                    }

                    NavigationLink {
                        FinalReviewScreen(viewModel: viewModel, assignmentID: assignmentID)
                    } label: {
                        Label("Open Final Review", systemImage: "checklist")
                    }
                } header: {
                    Text("Actions")
                } footer: {
                    Text("This screen prepares and explains the local AI packet. It does not generate a draft, approve a grade, export a report, upload data, or read other students.")
                }
            } else {
                ContentUnavailableView(
                    "Assignment not found",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Return to Assignments and choose a saved assignment.")
                )
            }
        }
        .navigationTitle("AI Readiness")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            viewModel.selectAssignment(assignmentID)
            viewModel.refreshAIReadiness()
        }
    }

    private func header(for assignment: AssignmentRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(assignment.title.isEmpty ? "Assignment" : assignment.title)
                .font(.headline)
            if let report {
                Label(report.localAIStatusSummary, systemImage: statusIcon(report.canGenerate ? .ready : .needsReview))
                    .foregroundStyle(statusColor(report.canGenerate ? .ready : .needsReview))
                Text(report.recommendedNextAction)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LabeledContent("PII redaction", value: report.piiRedactionSummary)
                LabeledContent("Token plan", value: report.tokenEstimateSummary)
            } else {
                Text("No readiness report has been generated for this assignment yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func readinessRow(_ check: AIReadinessCheck) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: statusIcon(check.status))
                .foregroundStyle(statusColor(check.status))
            VStack(alignment: .leading, spacing: 3) {
                Text(check.title)
                    .font(.subheadline.weight(.semibold))
                Text(check.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func packetList(_ items: [String], systemImage: String) -> some View {
        ForEach(items, id: \.self) { item in
            Label(item, systemImage: systemImage)
                .font(.caption)
        }
    }

    private func statusIcon(_ status: AIReadinessStatus) -> String {
        switch status {
        case .ready:
            return "checkmark.circle"
        case .needsReview:
            return "exclamationmark.circle"
        case .blocked, .unavailable:
            return "xmark.octagon"
        case .info:
            return "info.circle"
        }
    }

    private func statusColor(_ status: AIReadinessStatus) -> Color {
        switch status {
        case .ready:
            return .green
        case .needsReview, .info:
            return .orange
        case .blocked, .unavailable:
            return .red
        }
    }
}
