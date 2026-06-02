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

    private var assignment: AssignmentRecord { viewModel.assignment(for: assignmentID) ?? viewModel.assignment }
    private var instructionTemplateOptions: [(String, String)] { TeacherInstructionTemplateCatalog.all.map { ($0.id, $0.name) } }
    private var answerKeyTemplates: [AnswerKeyTemplate] { AnswerKeyTemplateCatalog.templates(for: assignment.assignmentType) }
    private var exemplarTemplates: [ExemplarTemplate] { ExemplarTemplateCatalog.templates(for: assignment.assignmentType) }
    private var formativeTemplates: [FormativeFocusTemplate] { FormativeFocusTemplateCatalog.templates(for: assignment.assignmentType) }
    private var answerKeyTemplateOptions: [(String, String)] { answerKeyTemplates.map { ($0.id, $0.name) } }
    private var exemplarTemplateOptions: [(String, String)] { exemplarTemplates.map { ($0.id, $0.name) } }
    private var formativeTemplateOptions: [(String, String)] { formativeTemplates.map { ($0.id, $0.name) } }

    var body: some View {
        Form {
            Section {
                RubricStationeryPage(
                    title: "Rubric & Instructions",
                    subtitle: "Teacher-selected rubric, local templates, and curriculum references for this grading packet.",
                    tapeLabel: "Setup packet",
                    annotation: "Only teacher-reviewed setup content enters grading context.",
                    status: assignment.hasGradingStandard ? .onTrack : .needsAttention
                ) {
            if !assignment.hasGradingStandard {
                RubricStationeryCard(title: "Needs Attention", tapeLabel: "Fix first", status: .needsAttention, showsPaperclip: true) {
                    WarningBanner(
                        title: "Add a grading standard",
                        message: "Add a rubric, answer key, exemplar, or grading criteria before drafting feedback.",
                        status: .needsAttention
                    )
                }
            }

            RubricStationeryCard(
                title: "Rubric Setup",
                tapeLabel: "Rubric",
                annotation: "Templates and imports are local. Review rubric text before grading.",
                status: assignment.parsedRubric.criteria.isEmpty ? .needsAttention : .onTrack,
                showsPaperclip: true
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    RubricFieldRow(title: "Template") {
                        Picker("Template", selection: $selectedTemplateID) {
                            ForEach(RubricTemplates.builtIn) { template in
                                Text(template.name).tag(template.id)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Button(action: applyTemplate) {
                            Label("Apply Template", systemImage: "checkmark.circle")
                                .frame(minHeight: GradeDraftLayout.minimumTapTarget)
                        }
                        .buttonStyle(.borderedProminent)
                        Button {
                            showingRubricImporter = true
                        } label: {
                            Label("Import Rubric File", systemImage: "doc.badge.plus")
                                .frame(minHeight: GradeDraftLayout.minimumTapTarget)
                        }
                        .buttonStyle(.bordered)
                    }
                    RubricPaperTextEditor(title: "Rubric or grading criteria", text: rubricTextBinding, minHeight: 150)
                }
            }

            if let preview = viewModel.latestRubricPreview {
                RubricStationeryCard(
                    title: preview.issues.isEmpty ? "Preview Import" : "Imported with Warnings",
                    tapeLabel: "Import preview",
                    annotation: "Review the criteria before using them for teacher-reviewed grading.",
                    status: preview.issues.isEmpty ? .onTrack : .needsAttention
                ) {
                    VStack(alignment: .leading, spacing: 12) {
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
                        VStack(alignment: .leading, spacing: 10) {
                            Button {
                                viewModel.confirmMarkdownRubricImport(preview, useStructuredImport: true)
                            } label: {
                                Label("Confirm Structured Import", systemImage: "checkmark.circle")
                                    .frame(minHeight: GradeDraftLayout.minimumTapTarget)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(preview.detectedCriteria.isEmpty)
                            Button {
                                viewModel.confirmMarkdownRubricImport(preview, useStructuredImport: false)
                            } label: {
                                Label("Use Rubric Text", systemImage: "text.alignleft")
                                    .frame(minHeight: GradeDraftLayout.minimumTapTarget)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            RubricStationeryCard(
                title: "Instruction and Answer Key Templates",
                tapeLabel: "Template drawer",
                annotation: "Choose whether to append or replace when teacher-entered content already exists."
            ) {
                VStack(alignment: .leading, spacing: 12) {
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
                }
            }

            RubricStationeryCard(
                title: "AI Grading Constraints",
                tapeLabel: "Local AI",
                annotation: "GradeDraft drafts suggestions only. The teacher approves the final grade.",
                status: .teacherOnly
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    if case .unavailable(let message) = viewModel.localAIStatus {
                        WarningBanner(
                            title: "Local AI unavailable",
                            message: message,
                            status: .needsAttention
                        )
                    }
                    RubricHandwrittenNote(
                        "These prompts guide the local draft only. Sensitive templates are never selected automatically.",
                        status: .teacherOnly
                    )
                    VStack(alignment: .leading, spacing: 10) {
                        Button {
                            viewModel.selectAssignment(assignmentID)
                            viewModel.applyRecommendedAIConstraintTemplates()
                        } label: {
                            Label("Apply Recommended", systemImage: "checklist.checked")
                                .frame(minHeight: GradeDraftLayout.minimumTapTarget)
                        }
                        .buttonStyle(.borderedProminent)
                        Button {
                            viewModel.selectAssignment(assignmentID)
                            viewModel.clearAIConstraintTemplates()
                        } label: {
                            Label("Clear", systemImage: "xmark.circle")
                                .frame(minHeight: GradeDraftLayout.minimumTapTarget)
                        }
                        .buttonStyle(.bordered)
                    }
                    ForEach(GradingConstraintTemplates.builtIn) { template in
                        RubricFieldRow(title: template.title) {
                            Toggle(isOn: Binding(
                                get: { assignment.selectedInstructionTemplateIDs.contains(template.id) },
                                set: { _ in
                                    viewModel.selectAssignment(assignmentID)
                                    viewModel.toggleAIConstraintTemplate(template.id)
                                }
                            )) {
                                VStack(alignment: .leading, spacing: 4) {
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
                    }
                }
            }

            RubricStationeryCard(title: "Criteria", tapeLabel: "Criteria", status: assignment.parsedRubric.criteria.isEmpty ? .needsAttention : .onTrack) {
                if assignment.parsedRubric.criteria.isEmpty {
                    ContentUnavailableView(
                        "No structured criteria detected",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Drafts and manual grading still require teacher review.")
                    )
                } else {
                    VStack(alignment: .leading, spacing: 12) {
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
            }

            RubricStationeryCard(
                title: "Curriculum Reference",
                tapeLabel: "Curriculum",
                annotation: "Only teacher-selected references enter grading context.",
                status: assignment.curriculumMappings.isEmpty && assignment.curriculumReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .notStarted : .onTrack,
                showsPaperclip: true
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    RubricHandwrittenNote(viewModel.curriculumCatalog.warning, status: .teacherOnly)
                    NavigationLink {
                        CurriculumBrowserScreen(viewModel: viewModel, assignmentID: assignmentID)
                    } label: {
                        Label("Browse Australian Curriculum Catalog", systemImage: "book.closed")
                            .frame(minHeight: GradeDraftLayout.minimumTapTarget)
                    }
                    .buttonStyle(.borderedProminent)
                    Button {
                        showingCurriculumImporter = true
                    } label: {
                        Label("Import Teacher-Provided Curriculum Reference", systemImage: "doc.badge.plus")
                            .frame(minHeight: GradeDraftLayout.minimumTapTarget)
                    }
                    .buttonStyle(.bordered)
                    RubricPaperTextEditor(title: "Teacher-selected curriculum or reference material", text: binding(\.curriculumReference), minHeight: 110)
                }
            }

            RubricStationeryCard(
                title: "Teacher Instructions",
                tapeLabel: "Teacher notes",
                annotation: "These instructions are teacher-facing and remain part of the local grading packet.",
                status: assignment.customInstructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && assignment.formativeFocusText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .notStarted : .onTrack
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    textEditor("Custom teacher instructions", text: binding(\.customInstructions), minHeight: 120)
                    textEditor("Formative focus", text: binding(\.formativeFocusText), minHeight: 90)
                }
            }

                RubricStationeryCard(
                    title: "Answer Key and Exemplar",
                    tapeLabel: "Answer key",
                    annotation: "Grading cannot begin until scanned text is reviewed and a grading standard is supplied.",
                    status: assignment.hasGradingStandard ? .onTrack : .needsAttention
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        textEditor("Answer key", text: binding(\.answerKeyText), minHeight: 100)
                        textEditor("Exemplar response", text: binding(\.exemplarText), minHeight: 100)
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .stationeryScreen()
        .navigationTitle("Rubric & Instructions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            viewModel.selectAssignment(assignmentID)
            resetTemplateSelections()
        }
        .onChange(of: assignment.assignmentType) { _, _ in
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
            switch result {
            case .success(let url):
                viewModel.selectAssignment(assignmentID)
                viewModel.importMarkdownRubric(from: url)
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .fileImporter(isPresented: $showingCurriculumImporter, allowedContentTypes: [.plainText, .commaSeparatedText, .item]) { result in
            switch result {
            case .success(let url):
                viewModel.selectAssignment(assignmentID)
                viewModel.importCurriculumReference(from: url)
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }

    private func templateControl(title: String, detail: String, selection: Binding<String>, options: [(String, String)], actionTitle: String, action: @escaping () -> Void) -> some View {
        RubricFieldRow(title: title, detail: detail) {
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
                .labelsHidden()
                .pickerStyle(.menu)
            }
            Button(action: action) {
                Label(actionTitle, systemImage: "text.badge.plus")
                    .frame(minHeight: GradeDraftLayout.minimumTapTarget)
            }
            .buttonStyle(.bordered)
            .disabled(options.isEmpty)
        }
    }

    private func textEditor(_ title: String, text: Binding<String>, minHeight: CGFloat) -> some View {
        RubricPaperTextEditor(title: title, text: text, minHeight: minHeight)
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<AssignmentRecord, Value>) -> Binding<Value> {
        Binding(
            get: { assignment[keyPath: keyPath] },
            set: { value in
                viewModel.selectAssignment(assignmentID)
                viewModel.updateAssignment { $0[keyPath: keyPath] = value }
            }
        )
    }

    private var rubricTextBinding: Binding<String> {
        Binding(
            get: { assignment.rubricText },
            set: { newText in
                viewModel.selectAssignment(assignmentID)
                viewModel.updateRubricText(newText)
            }
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
        viewModel.selectAssignment(assignmentID)
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
        viewModel.selectAssignment(assignmentID)
        viewModel.applyTemplate(template)
    }
}
