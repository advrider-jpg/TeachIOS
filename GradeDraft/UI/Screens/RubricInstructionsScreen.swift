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
        Form {
            if !assignment.hasGradingStandard {
                Section("Needs Attention") {
                    WarningBanner(
                        title: "Add a grading standard",
                        message: "Add a rubric, answer key, exemplar, or grading criteria before drafting feedback.",
                        status: .needsAttention
                    )
                }
            }

            Section("Rubric Setup") {
                Picker("Template", selection: $selectedTemplateID) {
                    ForEach(RubricTemplates.builtIn) { template in
                        Text(template.name).tag(template.id)
                    }
                }
                Button(action: applyTemplate) {
                    Label("Apply Template", systemImage: "checkmark.circle")
                }
                Button {
                    showingRubricImporter = true
                } label: {
                    Label("Import Rubric File", systemImage: "doc.badge.plus")
                }
                TextEditor(text: rubricTextBinding)
                    .frame(minHeight: 150)
                    .accessibilityLabel("Rubric or grading criteria")
            } footer: {
                Text("Templates and imports are local. Review rubric text before grading.")
            }

            if let preview = viewModel.latestRubricPreview {
                Section(preview.issues.isEmpty ? "Preview Import" : "Imported with Warnings") {
                    GradeDraftStatusLabeledContent(title: "Detected Criteria", value: "\(preview.detectedCriteria.count)", status: preview.issues.isEmpty ? .onTrack : .needsAttention)
                    LabeledContent("Scoring Bands", value: "\(preview.detectedLevels.count)")
                    ForEach(preview.detectedCriteria) { criterion in
                        DisclosureGroup {
                            if !criterion.descriptor.isEmpty {
                                Text(criterion.descriptor)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            LabeledContent("Max Points", value: GradeTotals.formatted(criterion.maxPoints))
                            ForEach(criterion.levels) { level in
                                LabeledContent(level.label, value: GradeTotals.formatted(level.points))
                            }
                        } label: {
                            RubricCriterionRow(criterion: criterion)
                        }
                    }
                    if !preview.issues.isEmpty {
                        DisclosureGroup("Import Warnings") {
                            ForEach(preview.issues, id: \.id) { issue in
                                Label(issue.message, systemImage: "exclamationmark.triangle")
                                    .font(.subheadline)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    Button {
                        viewModel.confirmMarkdownRubricImport(preview, useStructuredImport: true)
                    } label: {
                        Label("Confirm Structured Import", systemImage: "checkmark.circle")
                    }
                    .disabled(preview.detectedCriteria.isEmpty)
                    Button {
                        viewModel.confirmMarkdownRubricImport(preview, useStructuredImport: false)
                    } label: {
                        Label("Use Rubric Text", systemImage: "text.alignleft")
                    }
                } footer: {
                    Text("Review the criteria before using them for teacher-reviewed grading.")
                }
            }

            Section("Planned Content Templates") {
                templateControl(
                    title: "Teacher instruction template",
                    detail: "Adds teacher-only custom instructions. Existing text is never removed without confirmation.",
                    selection: $selectedInstructionTemplateID,
                    options: instructionTemplateOptions,
                    actionTitle: "Insert Instruction",
                    action: { requestTemplateApplication(.teacherInstruction) }
                )
                templateControl(
                    title: "Answer-key template",
                    detail: "Filtered for this assignment type and inserted into Answer key.",
                    selection: $selectedAnswerKeyTemplateID,
                    options: answerKeyTemplateOptions,
                    actionTitle: "Insert Answer Key",
                    action: { requestTemplateApplication(.answerKey) }
                )
                templateControl(
                    title: "Exemplar template",
                    detail: "Filtered for this assignment type and inserted into Exemplar response.",
                    selection: $selectedExemplarTemplateID,
                    options: exemplarTemplateOptions,
                    actionTitle: "Insert Exemplar",
                    action: { requestTemplateApplication(.exemplar) }
                )
                templateControl(
                    title: "Formative focus template",
                    detail: "Filtered for this assignment type and stored as dedicated formative focus guidance.",
                    selection: $selectedFormativeTemplateID,
                    options: formativeTemplateOptions,
                    actionTitle: "Insert Formative Focus",
                    action: { requestTemplateApplication(.formativeFocus) }
                )
            } footer: {
                Text("Choose whether to append or replace when teacher-entered content already exists.")
            }

            Section("AI Grading Constraints") {
                Text("These prompts guide the local draft only. Sensitive templates are never selected automatically and should be selected only when the teacher has supplied that context.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button(action: viewModel.applyRecommendedAIConstraintTemplates) {
                    Label("Apply Recommended", systemImage: "checklist.checked")
                }
                Button(action: viewModel.clearAIConstraintTemplates) {
                    Label("Clear", systemImage: "xmark.circle")
                }
                ForEach(GradingConstraintTemplates.builtIn) { template in
                    Toggle(isOn: Binding(
                        get: { viewModel.assignment.selectedInstructionTemplateIDs.contains(template.id) },
                        set: { _ in viewModel.toggleAIConstraintTemplate(template.id) }
                    )) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.title)
                            Text(template.text)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            if template.sensitiveContextRequired {
                                Label("Select only when teacher-provided context exists. GradeDraft must not infer it.", systemImage: "exclamationmark.triangle")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            } footer: {
                Text("GradeDraft drafts suggestions only. The teacher approves the final grade.")
            }

            Section("Criteria") {
                if assignment.parsedRubric.criteria.isEmpty {
                    ContentUnavailableView(
                        "No structured criteria detected",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Drafts and manual grading still require teacher review.")
                    )
                } else {
                    ForEach(assignment.parsedRubric.criteria) { criterion in
                        DisclosureGroup {
                            if !criterion.descriptor.isEmpty {
                                Text(criterion.descriptor)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            LabeledContent("Max Points", value: GradeTotals.formatted(criterion.maxPoints))
                            if !criterion.levels.isEmpty {
                                ForEach(criterion.levels) { level in
                                    LabeledContent(level.label, value: GradeTotals.formatted(level.points))
                                }
                            }
                        } label: {
                            RubricCriterionRow(criterion: criterion)
                        }
                    }
                }
            }

            Section("Curriculum Reference") {
                Text(viewModel.curriculumCatalog.warning)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button {
                    showingCurriculumImporter = true
                } label: {
                    Label("Import Curriculum Reference", systemImage: "book")
                }
                TextField("Search local curriculum", text: $viewModel.curriculumSearchText)
                TextField("Learning area", text: $viewModel.curriculumLearningAreaFilter)
                TextField("Year level", text: $viewModel.curriculumYearLevelFilter)
                ForEach(Array(viewModel.filteredCurriculumItems.prefix(8))) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(CurriculumCatalogService.displaySummary(for: item))
                            .font(.subheadline)
                        Text(item.shortDescription)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button {
                            viewModel.mapCurriculumItemToCurrentAssignment(item)
                        } label: {
                            Label("Map", systemImage: "link")
                        }
                    }
                }
                TextEditor(text: binding(\.curriculumReference))
                    .frame(minHeight: 110)
                    .accessibilityLabel("Curriculum or reference material")
            } footer: {
                Text("Optional local reference. Confirm against your jurisdiction before reporting.")
            }

            Section("Teacher Instructions") {
                textEditor("Custom teacher instructions", text: binding(\.customInstructions), minHeight: 120)
                textEditor("Formative focus", text: binding(\.formativeFocusText), minHeight: 90)
            } footer: {
                Text("These instructions are teacher-facing and remain part of the local grading packet.")
            }

            Section("Answer Key and Exemplar") {
                textEditor("Answer key", text: binding(\.answerKeyText), minHeight: 100)
                textEditor("Exemplar response", text: binding(\.exemplarText), minHeight: 100)
            } footer: {
                Text("Grading cannot begin until scanned text is reviewed and a grading standard is supplied.")
            }
        }
        .navigationTitle("Rubric & Instructions")
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
            Text(detail).font(.footnote).foregroundStyle(.secondary)
            if options.isEmpty {
                Text("No compatible template is available for this assignment type.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Picker(title, selection: selection) {
                    ForEach(options, id: \.0) { option in
                        Text(option.1).tag(option.0)
                    }
                }
            }
            Button(action: action) {
                Label(actionTitle, systemImage: "text.badge.plus")
            }
            .disabled(options.isEmpty)
        }
        .padding(.vertical, 4)
    }

    private func textEditor(_ title: String, text: Binding<String>, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            TextEditor(text: text)
                .frame(minHeight: minHeight)
                .accessibilityLabel(title)
        }
        .padding(.vertical, 4)
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<AssignmentRecord, Value>) -> Binding<Value> {
        Binding(
            get: { viewModel.assignment[keyPath: keyPath] },
            set: { value in viewModel.updateAssignment { $0[keyPath: keyPath] = value } }
        )
    }

    private var rubricTextBinding: Binding<String> {
        Binding(
            get: { viewModel.assignment.rubricText },
            set: { newText in viewModel.updateRubricText(newText) }
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
