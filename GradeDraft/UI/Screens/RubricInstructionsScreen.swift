import SwiftUI
import UniformTypeIdentifiers

struct RubricInstructionsScreen: View {
    @ObservedObject var viewModel: GradeDraftViewModel
    var assignmentID: UUID
    @State private var selectedTemplateID: String = RubricTemplates.builtIn.first?.id ?? ""
    @State private var showingRubricImporter = false
    @State private var showingCurriculumImporter = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GradeDraftLayout.deepSectionSpacing) {
                let assignment = viewModel.assignment
                DeepWorkflowHeader(
                    title: "Rubric & Instructions",
                    subtitle: "Rubric import, criteria, instructions, and curriculum reference.",
                    status: assignment.hasGradingStandard ? .onTrack : .needsAttention
                )

                if !assignment.hasGradingStandard {
                    WarningBanner(
                        title: "Rubric needs fixes",
                        message: "Rubric needs fixes before grading. Review the highlighted criteria and import warnings.",
                        status: .needsAttention
                    )
                    .padding(.horizontal, GradeDraftLayout.screenPadding)
                }

                GroupedListCard(title: "Rubric setup", subtitle: "Apply a local template or import a teacher-provided rubric.") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Template", selection: $selectedTemplateID) {
                            ForEach(RubricTemplates.builtIn) { template in
                                Text(template.name).tag(template.id)
                            }
                        }
                        .pickerStyle(.menu)
                        HStack(spacing: 8) {
                            SecondaryActionButton(title: "Apply Template", systemImage: "checklist", action: applyTemplate)
                            SecondaryActionButton(title: "Import Rubric", systemImage: "square.and.arrow.down", action: { showingRubricImporter = true })
                        }
                        SecondaryActionButton(title: "Import Curriculum Reference", systemImage: "book", action: { showingCurriculumImporter = true })
                    }
                    .padding(GradeDraftLayout.rowHorizontalPadding)
                }
                .padding(.horizontal, GradeDraftLayout.screenPadding)

                if let preview = viewModel.latestRubricPreview {
                    RubricImportPreviewCard(
                        preview: preview,
                        onConfirmStructured: { viewModel.confirmMarkdownRubricImport(preview, useStructuredImport: true) },
                        onUseText: { viewModel.confirmMarkdownRubricImport(preview, useStructuredImport: false) }
                    )
                    .padding(.horizontal, GradeDraftLayout.screenPadding)
                }

                GroupedListCard(title: "Criteria", subtitle: "Detected structured criteria for scoring.") {
                    if assignment.parsedRubric.criteria.isEmpty {
                        EmptyState(title: "No structured criteria detected", message: "Drafts and manual grading still require teacher review.", systemImage: "list.bullet.rectangle")
                    } else {
                        ForEach(assignment.parsedRubric.criteria) { criterion in
                            RubricCriterionRow(criterion: criterion)
                            if criterion.id != assignment.parsedRubric.criteria.last?.id { Divider().padding(.leading, 56) }
                        }
                    }
                }
                .padding(.horizontal, GradeDraftLayout.screenPadding)

                GroupedListCard(title: "Local curriculum catalog", subtitle: "Optional local reference. Confirm against your jurisdiction before reporting.") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(viewModel.curriculumCatalog.warning)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Search local curriculum", text: $viewModel.curriculumSearchText)
                            .textFieldStyle(.roundedBorder)
                        HStack(spacing: 8) {
                            TextField("Learning area", text: $viewModel.curriculumLearningAreaFilter)
                                .textFieldStyle(.roundedBorder)
                            TextField("Year level", text: $viewModel.curriculumYearLevelFilter)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(GradeDraftLayout.rowHorizontalPadding)
                    ForEach(viewModel.filteredCurriculumItems.prefix(8)) { item in
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(CurriculumCatalogService.displaySummary(for: item))
                                    .font(.subheadline)
                                    .lineLimit(2)
                                Text(item.shortDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 8)
                            SecondaryActionButton(title: "Map", systemImage: "link", action: { viewModel.mapCurriculumItemToCurrentAssignment(item) })
                                .frame(width: 94)
                        }
                        .padding(.horizontal, GradeDraftLayout.rowHorizontalPadding)
                        .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, GradeDraftLayout.screenPadding)

                GroupedListCard(title: "Instructions", subtitle: "Long instructions stay in detail panels, not list rows.") {
                    textEditor(title: "Rubric / grading criteria", text: binding(\.rubricText), minHeight: 160, hint: "Paste rubric, answer key, or grading criteria.")
                    textEditor(title: "Custom teacher instructions", text: binding(\.customInstructions), minHeight: 90, hint: "Optional custom grading rules.")
                    textEditor(title: "Answer key", text: binding(\.answerKeyText), minHeight: 80, hint: "Expected elements, misconceptions, or partial credit.")
                    textEditor(title: "Exemplar response", text: binding(\.exemplarText), minHeight: 80, hint: "Teacher-supplied exemplar.")
                    textEditor(title: "Curriculum / reference material", text: binding(\.curriculumReference), minHeight: 100, hint: "Teacher-entered or imported curriculum reference.")
                    Text("Grading cannot begin until scanned text is reviewed and rubric issues are fixed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, GradeDraftLayout.rowHorizontalPadding)
                        .padding(.bottom, 12)
                }
                .padding(.horizontal, GradeDraftLayout.screenPadding)
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear { viewModel.selectAssignment(assignmentID) }
        .fileImporter(isPresented: $showingRubricImporter, allowedContentTypes: [.plainText, .item]) { result in
            if case .success(let url) = result { viewModel.importMarkdownRubric(from: url) }
        }
        .fileImporter(isPresented: $showingCurriculumImporter, allowedContentTypes: [.plainText, .commaSeparatedText, .item]) { result in
            if case .success(let url) = result { viewModel.importCurriculumReference(from: url) }
        }
    }

    private func textEditor(title: String, text: Binding<String>, minHeight: CGFloat, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            TextEditor(text: text)
                .frame(minHeight: minHeight)
                .padding(8)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(hint)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
        }
        .padding(GradeDraftLayout.rowHorizontalPadding)
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<AssignmentRecord, Value>) -> Binding<Value> {
        Binding(
            get: { viewModel.assignment[keyPath: keyPath] },
            set: { value in viewModel.updateAssignment { $0[keyPath: keyPath] = value } }
        )
    }

    private func applyTemplate() {
        guard let template = RubricTemplates.builtIn.first(where: { $0.id == selectedTemplateID }) else { return }
        viewModel.applyTemplate(template)
    }
}
