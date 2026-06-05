import SwiftUI

struct AIPacketPreviewScreen: View {
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
                } footer: {
                    Text("This preview is deterministic app-side preparation. It does not generate a draft, approve a grade, export a report, upload data, or read other students.")
                }

                Section("Readiness") {
                    if let report {
                        readinessSummary(report)
                        if !report.promptInjectionRisks.isEmpty {
                            DisclosureGroup("Prompt-injection flags") {
                                packetList(report.promptInjectionRisks, systemImage: "exclamationmark.triangle")
                            }
                        }
                    } else {
                        Text("Prepare the packet preview to inspect this assignment's local AI gates.")
                            .foregroundStyle(.secondary)
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
                        LabeledContent("Prepared", value: preview.generatedAt.formatted(date: .abbreviated, time: .shortened))
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
                } else {
                    Section("Packet Preview") {
                        ContentUnavailableView(
                            "Packet preview not ready",
                            systemImage: "doc.text.magnifyingglass",
                            description: Text(report?.recommendedNextAction ?? "Prepare the local AI packet preview to see what the model-visible prompt would contain.")
                        )
                    }
                }

                Section("Actions") {
                    Button {
                        viewModel.selectAssignment(assignmentID)
                        viewModel.buildAIPacketPreview()
                    } label: {
                        Label("Prepare Packet Preview", systemImage: "arrow.clockwise")
                    }

                    NavigationLink {
                        AIReadinessScreen(viewModel: viewModel, assignmentID: assignmentID)
                    } label: {
                        Label("Open AI Readiness", systemImage: "checkmark.shield")
                    }

                    NavigationLink {
                        RubricInstructionsScreen(viewModel: viewModel, assignmentID: assignmentID)
                    } label: {
                        Label("Edit Rubric and Constraints", systemImage: "slider.horizontal.3")
                    }

                    NavigationLink {
                        FinalReviewScreen(viewModel: viewModel, assignmentID: assignmentID)
                    } label: {
                        Label("Open Final Review", systemImage: "checklist")
                    }
                }
            } else {
                ContentUnavailableView(
                    "Assignment not found",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Return to Assignments and choose a saved assignment.")
                )
            }
        }
        .navigationTitle("AI Packet Preview")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            viewModel.selectAssignment(assignmentID)
            viewModel.buildAIPacketPreview()
        }
    }

    private func header(for assignment: AssignmentRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(assignment.title.nilIfBlank ?? "Assignment")
                .font(.headline)
            Text(assignment.subject.nilIfBlank ?? "No subject set")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let preview {
                LabeledContent("Prompt version", value: preview.promptVersion)
                LabeledContent("Packet fingerprint", value: preview.packetFingerprint)
            } else if let report {
                Label(report.recommendedNextAction, systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(statusColor(report.canGenerate ? .ready : .needsReview))
            }
        }
    }

    private func readinessSummary(_ report: AIReadinessReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(report.localAIStatusSummary, systemImage: statusIcon(report.canGenerate ? .ready : .needsReview))
                .foregroundStyle(statusColor(report.canGenerate ? .ready : .needsReview))
            Text(report.recommendedNextAction)
                .font(.caption)
                .foregroundStyle(.secondary)
            LabeledContent("PII redaction", value: report.piiRedactionSummary)
            LabeledContent("Token plan", value: report.tokenEstimateSummary)
            ForEach(report.checks) { check in
                readinessRow(check)
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
