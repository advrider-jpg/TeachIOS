import SwiftUI
import UniformTypeIdentifiers

private enum PlannedTemplateTarget: String, Identifiable {
    case teacherInstruction
    case answerKey
    case exemplar
    case formativeFocus

    var id: String { rawValue }
}

struct RubricInstructionsScreen: View {
    @ObservedObject var viewModel: GradeDraftViewModel
    var assignmentID: UUID
    @State private var selectedTemplateID: String = RubricTemplates.builtIn.first?.id ?? ""
    @State private var selectedInstructionTemplateID: String = TeacherInstructionTemplateCatalog.all.first?.id ?? ""
    @State private var selectedAnswerKeyTemplateID: String = AnswerKeyTemplateCatalog.all.first?.id ?? ""
    @State private var selectedExemplarTemplateID: String = ExemplarTemplateCatalog.all.first?.id ?? ""
    @State private var selectedFormativeTemplateID: String = FormativeFocusTemplateCatalog.all.first?.id ?? ""
    @State private var showingRubricImporter = false
    @State private var showingCurriculumImporter = false
    @State private var pendingTemplateApplication: PlannedTemplateTarget?

    private var assignment: AssignmentRecord { viewModel.assignment }
    private var instructionTemplateOptions: [(String, String)] { TeacherInstructionTemplateCatalog.all.map { ($0.id, $0.name) } }
    private var answerKeyTemplates: [AnswerKeyTemplate] { AnswerKeyTemplateCatalog.templates(for: assignment.assignmentType) }
    private var exemplarTemplates: [ExemplarTemplate] { ExemplarTemplateCatalog.templates(for: assignment.assignmentType) }
    private var formativeTemplates: [FormativeFocusTemplate] { FormativeFocusTemplateCatalog.templates(for: assignment.assignmentType) }
    private var answerKeyTemplateOptions: [(String, String)] { answerKeyTemplates.map { ($0.id, $0.name) } }
    private var exemplarTemplateOptions: [(String, String)] { exemplarTemplates.map { ($0.id, $0.name) } }
    private var formativeTemplateOptions: [(String, String)] { formativeTemplates.map { ($0.id, $0.name) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GradeDraftLayout.deepSectionSpacing) {
                DeepWorkflowHeader(
                    title: "Rubric & Instructions",
                    subtitle: "Rubric import, criteria, instructions, and curriculum reference.",
                    status: assignment.hasGradingStandard ? .onTrack : .needsAttention
                )

                if !assignment.hasGradingStandard {
                    WarningBanner(
                        title: "Add a grading standard",
                        message: "Add a rubric, answer key, exemplar, or grading criteria before drafting feedback.",
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

                GroupedListCard(title: "Planned content templates", subtitle: "Choose whether to append or replace when teacher-entered content already exists.") {
                    VStack(alignment: .leading, spacing: 14) {
                        templateControl(
                            title: "Teacher instruction template",
                            detail: "Adds teacher-only custom instructions. Existing text is never removed without confirmation.",
                            selection: $selectedInstructionTemplateID,
                            options: instructionTemplateOptions,
                            actionTitle: "Insert Instruction",
                            action: { requestTemplateApplication(.teacherInstruction) }
                        )
                        Divider()
                        templateControl(
                            title: "Answer-key template",
                            detail: "Filtered for this assignment type and inserted into Answer key.",
                            selection: $selectedAnswerKeyTemplateID,
                            options: answerKeyTemplateOptions,
                            actionTitle: "Insert Answer Key",
                            action: { requestTemplateApplication(.answerKey) }
                        )
                        Divider()
                        templateControl(
                            title: "Exemplar template",
                            detail: "Filtered for this assignment type and inserted into Exemplar response.",
                            selection: $selectedExemplarTemplateID,
                            options: exemplarTemplateOptions,
                            actionTitle: "Insert Exemplar",
                            action: { requestTemplateApplication(.exemplar) }
                        )
                        Divider()
                        templateControl(
                            title: "Formative focus template",
                            detail: "Filtered for this assignment type and stored as dedicated formative focus guidance.",
                            selection: $selectedFormativeTemplateID,
                            options: formativeTemplateOptions,
                            actionTitle: "Insert Formative Focus",
                            action: { requestTemplateApplication(.formativeFocus) }
                        )
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
                    textEditor(title: "Formative focus", text: binding(\.formativeFocusText), minHeight: 80, hint: "Optional formative feedback focus, misconceptions, or next-step emphasis.")
                    textEditor(title: "Answer key", text: binding(\.answerKeyText), minHeight: 80, hint: "Expected elements, misconceptions, or partial credit.")
                    textEditor(title: "Exemplar response", text: binding(\.exemplarText), minHeight: 80, hint: "Teacher-supplied exemplar.")
                    textEditor(title: "Curriculum / reference material", text: binding(\.curriculumReference), minHeight: 100, hint: "Teacher-entered or imported curriculum reference.")
                    Text("Grading cannot begin until scanned text is reviewed and a grading standard is supplied.")
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
        .onAppear {
            viewModel.selectAssignment(assignmentID)
            resetTemplateSelections()
        }
        .onChange(of: viewModel.assignment.assignmentType) { _, _ in
            resetTemplateSelections()
        }
        .confirmationDialog(
            "Existing content found",
            isPresented: Binding(get: { pendingTemplateApplication != nil }, set: { if !$0 { pendingTemplateApplication = nil } }),
            titleVisibility: .visible
        ) {
            Button("Append to Existing Content") { performPendingTemplateApplication(mode: .append) }
            Button("Replace Existing Content", role: .destructive) { performPendingTemplateApplication(mode: .replace) }
            Button("Append Again") { performPendingTemplateApplication(mode: .appendAgain) }
            Button("Cancel", role: .cancel) { pendingTemplateApplication = nil }
        } message: {
            Text("Choose how GradeDraft should insert this template. Teacher-entered content is not deleted unless you choose Replace.")
        }
        .fileImporter(isPresented: $showingRubricImporter, allowedContentTypes: [.plainText, .item]) { result in
            if case .success(let url) = result { viewModel.importMarkdownRubric(from: url) }
        }
        .fileImporter(isPresented: $showingCurriculumImporter, allowedContentTypes: [.plainText, .commaSeparatedText, .item]) { result in
            if case .success(let url) = result { viewModel.importCurriculumReference(from: url) }
        }
    }

    private func templateControl(title: String, detail: String, selection: Binding<String>, options: [(String, String)], actionTitle: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(detail).font(.caption).foregroundStyle(.secondary)
            if options.isEmpty {
                Text("No compatible template is available for this assignment type.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Picker(title, selection: selection) {
                    ForEach(options, id: \.0) { option in
                        Text(option.1).tag(option.0)
                    }
                }
                .pickerStyle(.menu)
            }
            SecondaryActionButton(title: actionTitle, systemImage: "text.badge.plus", action: action, disabled: options.isEmpty)
        }
    }

    private func textEditor(title: String, text: Binding<String>, minHeight: CGFloat, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
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

    private func resetTemplateSelections() {
        if !RubricTemplates.builtIn.contains(where: { $0.id == selectedTemplateID }) {
            selectedTemplateID = RubricTemplates.builtIn.first?.id ?? ""
        }
        if !instructionTemplateOptions.contains(where: { $0.0 == selectedInstructionTemplateID }) {
            selectedInstructionTemplateID = instructionTemplateOptions.first?.0 ?? ""
        }
        if !answerKeyTemplateOptions.contains(where: { $0.0 == selectedAnswerKeyTemplateID }) {
            selectedAnswerKeyTemplateID = answerKeyTemplateOptions.first?.0 ?? ""
        }
        if !exemplarTemplateOptions.contains(where: { $0.0 == selectedExemplarTemplateID }) {
            selectedExemplarTemplateID = exemplarTemplateOptions.first?.0 ?? ""
        }
        if !formativeTemplateOptions.contains(where: { $0.0 == selectedFormativeTemplateID }) {
            selectedFormativeTemplateID = formativeTemplateOptions.first?.0 ?? ""
        }
    }

    private func existingContent(for target: PlannedTemplateTarget) -> String {
        switch target {
        case .teacherInstruction: return assignment.customInstructions
        case .answerKey: return assignment.answerKeyText
        case .exemplar: return assignment.exemplarText
        case .formativeFocus: return assignment.formativeFocusText
        }
    }

    private func requestTemplateApplication(_ target: PlannedTemplateTarget) {
        if existingContent(for: target).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            performTemplateApplication(target, mode: .append)
        } else {
            pendingTemplateApplication = target
        }
    }

    private func performPendingTemplateApplication(mode: TemplateInsertionMode) {
        guard let target = pendingTemplateApplication else { return }
        pendingTemplateApplication = nil
        performTemplateApplication(target, mode: mode)
    }

    private func performTemplateApplication(_ target: PlannedTemplateTarget, mode: TemplateInsertionMode) {
        switch target {
        case .teacherInstruction:
            guard let template = TeacherInstructionTemplateCatalog.template(id: selectedInstructionTemplateID) else { return }
            viewModel.applyTeacherInstructionTemplate(template, mode: mode)
        case .answerKey:
            guard let template = AnswerKeyTemplateCatalog.template(id: selectedAnswerKeyTemplateID) else { return }
            viewModel.applyAnswerKeyTemplate(template, mode: mode)
        case .exemplar:
            guard let template = ExemplarTemplateCatalog.template(id: selectedExemplarTemplateID) else { return }
            viewModel.applyExemplarTemplate(template, mode: mode)
        case .formativeFocus:
            guard let template = FormativeFocusTemplateCatalog.template(id: selectedFormativeTemplateID) else { return }
            viewModel.applyFormativeFocusTemplate(template, mode: mode)
        }
    }

    private func applyTemplate() {
        guard let template = RubricTemplates.builtIn.first(where: { $0.id == selectedTemplateID }) else { return }
        viewModel.applyTemplate(template)
    }
}
