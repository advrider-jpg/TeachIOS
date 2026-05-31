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
            Form {
                Section {
                    WarningBanner(title: warning.title.trimmingCharacters(in: .whitespacesAndNewlines), message: warning.body.trimmingCharacters(in: .whitespacesAndNewlines), status: .teacherOnly)
                    if !warning.checklist.isEmpty {
                        DisclosureGroup {
                            ForEach(warning.checklist, id: \.self) { item in
                                Label(item, systemImage: "checkmark.circle")
                            }
                        } label: {
                            Text("Checklist")
                        }
                    }
                    Toggle(isOn: $acknowledged) {
                        Text("I understand this action is irreversible and will permanently delete \"\(assignmentTitle)\" and all associated records.")
                    }
                    if acknowledged {
                        TextField("Type DELETE", text: $typedConfirmation)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                    }
                    Button(role: .destructive, action: onConfirm) {
                        Label("Delete Assignment", systemImage: "trash")
                    }
                    .disabled(!canDelete)
                } header: {
                    Text("Delete Assignment")
                } footer: {
                    Text(warning.escalatedConfirmation ?? "Type DELETE to confirm.")
                }
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

    private var assignment: AssignmentRecord { viewModel.assignment }

    var body: some View {
        Form {
            Section("Attached Files") {
                if assignment.sourceInputs.isEmpty {
                    ContentUnavailableView(
                        "Add student work",
                        systemImage: "doc.badge.plus",
                        description: Text("Scan, import a photo or PDF, or paste text directly.")
                    )
                } else {
                    ForEach(assignment.sourceInputs) { source in
                        WorkAttachmentRow(source: source)
                    }
                }
            } footer: {
                Text("Original files stay on this device unless you export them.")
            }

            Section("Add Student Work") {
                Button {
                    showingScanner = true
                } label: {
                    Label("Scan Paper Work", systemImage: "doc.viewfinder")
                }
                .disabled(!VNDocumentCameraViewController.isSupported || viewModel.isWorking)

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Choose Photo", systemImage: "photo")
                }
                .disabled(viewModel.isWorking)

                Button {
                    showingPDFImporter = true
                } label: {
                    Label("Import PDF", systemImage: "doc.richtext")
                }
                .disabled(viewModel.isWorking)
            } footer: {
                Text("Import locally. No student work is uploaded.")
            }

            Section("Work Preview") {
                TextEditor(text: binding(\.reviewedStudentText))
                    .frame(minHeight: 180)
                    .accessibilityLabel("Reviewed student work text")
                Button {
                    viewModel.applyPastedStudentText(viewModel.assignment.reviewedStudentText)
                } label: {
                    Label("Use Pasted Text as Reviewed", systemImage: "checkmark.circle")
                }
                .disabled(assignment.reviewedStudentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } footer: {
                Text("Review or paste the text GradeDraft can use. OCR text must be reviewed before grading.")
            }

            Section("Student Work Status") {
                BlockingIssueRow(
                    title: assignment.ocrReviewStatus.v6Status.rawValue,
                    detail: assignment.ocrReviewStatus.blocksGrading ? GradeDraftWorkflowLanguage.reviewScannedTextExplanation : "Student work is ready for teacher review.",
                    status: assignment.ocrReviewStatus.v6Status
                )
            } footer: {
                Text("Teacher review gates remain required.")
            }

            Section("Danger Zone") {
                Button(role: .destructive) {
                    showingClearConfirm = true
                } label: {
                    Label("Clear Work", systemImage: "trash")
                }
                .disabled(assignment.reviewedStudentText.isEmpty && assignment.sourceInputs.isEmpty)

                if let deleteWarning = ExportWarningCatalog.warning(id: "delete-local-data-warning") {
                    Text(deleteWarning.body.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("Delete Assignment", systemImage: "trash")
                    }
                }
            } footer: {
                Text("Permanent actions cannot be undone.")
            }
        }
        .navigationTitle("Student Work")
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
