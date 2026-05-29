import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import VisionKit

struct StudentWorkScreen: View {
    @ObservedObject var viewModel: GradeDraftViewModel
    var assignmentID: UUID
    @State private var showingScanner = false
    @State private var showingPDFImporter = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingClearConfirm = false

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
        .confirmationDialog("Clear student work?", isPresented: $showingClearConfirm, titleVisibility: .visible) {
            Button("Clear Work", role: .destructive) { clearWork() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the current attached files, reviewed text, draft suggestions, and final review from this assignment record.")
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<AssignmentRecord, Value>) -> Binding<Value> {
        Binding(
            get: { viewModel.assignment[keyPath: keyPath] },
            set: { value in viewModel.updateAssignment { $0[keyPath: keyPath] = value } }
        )
    }

    private func clearWork() {
        viewModel.updateAssignment { assignment in
            assignment.ocrDocument = nil
            assignment.ocrReviewStatus = .notNeeded
            assignment.ocrReviewedAt = nil
            assignment.sourceInputs = []
            assignment.reviewedStudentText = ""
            assignment.latestDraft = nil
            assignment.finalReview = nil
            assignment.appendAuditEvent(.inputChanged, detail: "Teacher cleared student work and reviewed text.")
        }
    }
}
