import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import VisionKit

struct DeleteAssignmentConfirmationSheet: View {
    var warning: ExportWarningDefinition
    var assignmentTitle: String
    var onCancel: () -> Void
    var onConfirm: () -> Void

    @State private var acknowledged = false
    @State private var typedConfirmation = ""

    private var canDelete: Bool {
        acknowledged && typedConfirmation.trimmingCharacters(in: .whitespacesAndNewlines) == "DELETE"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    WarningBanner(title: warning.title.trimmingCharacters(in: .whitespacesAndNewlines), message: warning.body.trimmingCharacters(in: .whitespacesAndNewlines), status: .teacherOnly)
                    if !warning.checklist.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Checklist")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ForEach(warning.checklist, id: \.self) { item in
                                Label(item, systemImage: "checkmark.circle")
                                    .font(.caption)
                            }
                        }
                    }
                    Toggle(isOn: $acknowledged) {
                        Text("I understand this action is irreversible and will permanently delete \"\(assignmentTitle)\" and all associated records.")
                            .font(.subheadline.weight(.semibold))
                    }
                    .toggleStyle(.switch)
                    if acknowledged {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(warning.escalatedConfirmation ?? "Type DELETE to confirm.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            TextField("Type DELETE", text: $typedConfirmation)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .padding(10)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    Button(role: .destructive, action: onConfirm) {
                        Label("Delete Assignment", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: GradeDraftLayout.minimumTapTarget)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canDelete)
                }
                .padding(GradeDraftLayout.screenPadding)
            }
            .navigationTitle("Delete Assignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}

struct StudentWorkScreen: View {
    @ObservedObject var viewModel: GradeDraftViewModel
    var assignmentID: UUID
    @State private var showingScanner = false
    @State private var showingPDFImporter = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingClearConfirm = false
    @State private var showingDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GradeDraftLayout.deepSectionSpacing) {
                let assignment = viewModel.assignment
                DeepWorkflowHeader(
                    title: "Student Work",
                    subtitle: "Add student work for teacher-reviewed grading.",
                    status: assignment.reviewedStudentText.isEmpty ? .addStudentWork : .onTrack
                )

                GroupedListCard(title: "Attached files", subtitle: "Original files stay on this device unless you export them.") {
                    if assignment.sourceInputs.isEmpty {
                        EmptyState(title: "Add student work", message: "Scan, import a photo or PDF, or paste text directly.", systemImage: "doc.badge.plus")
                    } else {
                        ForEach(assignment.sourceInputs) { source in
                            WorkAttachmentRow(source: source)
                            if source.id != assignment.sourceInputs.last?.id { Divider().padding(.leading, 56) }
                        }
                    }
                }
                .padding(.horizontal, GradeDraftLayout.screenPadding)

                GroupedListCard(title: "Add student work", subtitle: "Import locally. No student work is uploaded.") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            PrimaryActionButton(title: "Scan", systemImage: "doc.viewfinder", action: { showingScanner = true }, disabled: !VNDocumentCameraViewController.isSupported || viewModel.isWorking)
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Label("Import Photo", systemImage: "photo")
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: GradeDraftLayout.minimumTapTarget)
                            }
                            .buttonStyle(.bordered)
                            .disabled(viewModel.isWorking)
                        }
                        SecondaryActionButton(title: "Import PDF", systemImage: "doc.richtext", action: { showingPDFImporter = true }, disabled: viewModel.isWorking)
                        DestructiveActionButton(title: "Clear Work", systemImage: "trash", action: { showingClearConfirm = true }, disabled: assignment.reviewedStudentText.isEmpty && assignment.sourceInputs.isEmpty)
                    }
                    .padding(GradeDraftLayout.rowHorizontalPadding)
                }
                .padding(.horizontal, GradeDraftLayout.screenPadding)

                GroupedListCard(title: "Work preview", subtitle: "Review or paste the text GradeDraft can use.") {
                    WorkPreviewCard(text: binding(\.reviewedStudentText))
                    HStack(spacing: 8) {
                        SecondaryActionButton(title: "Use pasted text as reviewed", systemImage: "checkmark.circle", action: {
                            viewModel.applyPastedStudentText(viewModel.assignment.reviewedStudentText)
                        }, disabled: assignment.reviewedStudentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal, GradeDraftLayout.rowHorizontalPadding)
                    .padding(.bottom, 12)
                }
                .padding(.horizontal, GradeDraftLayout.screenPadding)

                GroupedListCard(title: "Student work status", subtitle: "Teacher review gates remain required.") {
                    BlockingIssueRow(
                        title: assignment.ocrReviewStatus.v6Status.rawValue,
                        detail: assignment.ocrReviewStatus.blocksGrading ? GradeDraftWorkflowLanguage.reviewScannedTextExplanation : "Student work is ready for teacher review.",
                        status: assignment.ocrReviewStatus.v6Status
                    )
                }
                .padding(.horizontal, GradeDraftLayout.screenPadding)

                if let deleteWarning = ExportWarningCatalog.warning(id: "delete-local-data-warning") {
                    GroupedListCard(title: "Danger Zone", subtitle: "Permanent actions that cannot be undone.") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(deleteWarning.body.trimmingCharacters(in: .whitespacesAndNewlines))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            DestructiveActionButton(title: "Delete Assignment", systemImage: "trash", action: { showingDeleteConfirm = true })
                        }
                        .padding(GradeDraftLayout.rowHorizontalPadding)
                    }
                    .padding(.horizontal, GradeDraftLayout.screenPadding)
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear { viewModel.selectAssignment(assignmentID) }
        .sheet(isPresented: $showingScanner) {
            DocumentScannerView { images in
                Task { await viewModel.applyScannedImages(images) }
            } onCancel: {
                viewModel.statusMessage = "Scan canceled."
            } onError: { error in
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .fileImporter(isPresented: $showingPDFImporter, allowedContentTypes: [.pdf]) { result in
            if case .success(let url) = result {
                Task { await viewModel.applyPDFFile(url) }
            }
        }
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    await viewModel.applyPhotoImages([image])
                } else {
                    viewModel.errorMessage = "The selected photo could not be imported."
                }
                selectedPhoto = nil
            }
        }
        .confirmationDialog(clearWarningTitle, isPresented: $showingClearConfirm, titleVisibility: .visible) {
            Button(clearWarningPrimaryButton, role: .destructive) { viewModel.clearCurrentStudentWork() }
            Button(clearWarningSecondaryButton, role: .cancel) {}
        } message: {
            Text(clearWarningBody)
        }
        .sheet(isPresented: $showingDeleteConfirm) {
            if let deleteWarning = ExportWarningCatalog.warning(id: "delete-local-data-warning") {
                DeleteAssignmentConfirmationSheet(
                    warning: deleteWarning,
                    assignmentTitle: viewModel.assignment.title,
                    onCancel: { showingDeleteConfirm = false },
                    onConfirm: {
                        showingDeleteConfirm = false
                        viewModel.deleteCurrentAssignment()
                    }
                )
            }
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<AssignmentRecord, Value>) -> Binding<Value> {
        Binding(
            get: { viewModel.assignment[keyPath: keyPath] },
            set: { value in viewModel.updateAssignment { $0[keyPath: keyPath] = value } }
        )
    }

    private var clearWarningTitle: String {
        ExportWarningCatalog.clearStudentWorkWarning.title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var clearWarningBody: String {
        ExportWarningCatalog.clearStudentWorkWarning.body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var clearWarningPrimaryButton: String {
        ExportWarningCatalog.clearStudentWorkWarning.primaryButton.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var clearWarningSecondaryButton: String {
        ExportWarningCatalog.clearStudentWorkWarning.secondaryButton.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
