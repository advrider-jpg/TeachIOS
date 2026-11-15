import SwiftUI
import UniformTypeIdentifiers

/// The parts of the assignment setup, each one collapsible section. The checklist at the top scrolls to them.
private enum RubricPart: String, CaseIterable, Hashable, Identifiable {
    case rubricText
    case criteria
    case instructions
    case constraints
    case answerKey
    case exemplar
    case formativeFocus
    case curriculum

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rubricText: return "Rubric"
        case .criteria: return "Detected Criteria"
        case .instructions: return "Teacher Instructions"
        case .constraints: return "AI Grading Constraints"
        case .answerKey: return "Answer Key"
        case .exemplar: return "Exemplar Response"
        case .formativeFocus: return "Formative Focus"
        case .curriculum: return "Curriculum Reference"
        }
    }
}

/// A template the teacher picked from a menu, waiting for the append/replace choice when the field already has text.
private enum TemplateTarget: Identifiable {
    case instruction(TeacherInstructionTemplate)
    case answerKey(AnswerKeyTemplate)
    case exemplar(ExemplarTemplate)
    case formativeFocus(FormativeFocusTemplate)

    var id: String {
        switch self {
        case .instruction(let template): return "instruction-\(template.id)"
        case .answerKey(let template): return "answerKey-\(template.id)"
        case .exemplar(let template): return "exemplar-\(template.id)"
        case .formativeFocus(let template): return "formative-\(template.id)"
        }
    }
}

struct RubricInstructionsScreen: View {
    @Bindable var model: AssignmentSetupModel

    @State private var expanded: Set<RubricPart> = [.rubricText, .criteria]
    @State private var showingRubricImporter = false
    @State private var showingCurriculumImporter = false
    @State private var pendingTemplate: TemplateTarget?
    @State private var pendingSensitiveTemplate: GradingConstraintTemplate?

    private static let rubricFileTypes: [UTType] = [.plainText, .text] + [UTType("net.daringfireball.markdown")].compactMap { $0 }
    private static let curriculumFileTypes: [UTType] = [.plainText, .commaSeparatedText, .text, .spreadsheet]

    var body: some View {
        Group {
            if let setup = model.setup {
                content(setup)
            }
        }
        .navigationTitle("Rubric & Instructions")
        .navigationBarTitleDisplayMode(.inline)
        .alertMessage($model.alert)
        .confirmationDialog(
            "Existing content found",
            isPresented: Binding(get: { pendingTemplate != nil }, set: { if !$0 { pendingTemplate = nil } }),
            titleVisibility: .visible,
            presenting: pendingTemplate
        ) { target in
            Button("Append to Existing Content") { apply(target, mode: .append) }
                .accessibilityIdentifier("rubric.templateAppend")
            Button("Replace Existing Content", role: .destructive) { apply(target, mode: .replace) }
                .accessibilityIdentifier("rubric.templateReplace")
            Button("Append Again") { apply(target, mode: .appendAgain) }
                .accessibilityIdentifier("rubric.templateAppendAgain")
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Choose how MarkForMe should insert this template. Teacher-entered content is not deleted unless you choose Replace.")
        }
        .sheet(item: Binding(get: { pendingSensitiveTemplate.map(SensitiveTemplateItem.init(template:)) }, set: { pendingSensitiveTemplate = $0?.template })) { item in
            sensitiveTemplateSheet(item.template)
        }
    }

    private func content(_ setup: AssignmentSetup) -> some View {
        ScrollViewReader { proxy in
            List {
                checklistSection(setup, proxy: proxy)
                rubricTextSection(setup)
                if let preview = model.rubricPreview {
                    importPreviewSection(preview)
                }
                if let suggestion = model.suggestedRubric {
                    suggestionSection(suggestion)
                }
                criteriaSection(setup)
                instructionsSection(setup)
                constraintsSection(setup)
                answerKeySection(setup)
                exemplarSection(setup)
                formativeFocusSection(setup)
                curriculumSection(setup)
            }
            .listStyle(.sidebar)
        }
    }

    // MARK: - Checklist

    private struct ChecklistItem: Identifiable {
        var part: RubricPart
        var value: String
        var status: GradeDraftUIStatus
        var id: RubricPart { part }
    }

    private func checklistItems(_ setup: AssignmentSetup) -> [ChecklistItem] {
        let assignment = setup.assignment
        let criteria = setup.parsedRubric.criteria
        let hasRubric = !assignment.rubricText.isWhitespaceOnly
        let selectedConstraints = assignment.constraintTemplateIDs.count
        let mappings = setup.curriculumMappings.count
        let aiAvailable = model.localAIStatus == .available
        return [
            ChecklistItem(part: .rubricText, value: hasRubric ? "Added" : "Not added", status: hasRubric ? .onTrack : .needsAttention),
            ChecklistItem(part: .criteria, value: criteria.isEmpty ? "None detected" : "\(criteria.count) criteria",
                          status: criteria.isEmpty ? .needsAttention : .onTrack),
            ChecklistItem(part: .instructions, value: assignment.customInstructions.isWhitespaceOnly ? "Not started" : "Added",
                          status: assignment.customInstructions.isWhitespaceOnly ? .notStarted : .onTrack),
            ChecklistItem(
                part: .constraints,
                value: !aiAvailable ? "On-device AI unavailable" : (selectedConstraints == 0 ? "None selected" : "\(selectedConstraints) selected"),
                status: selectedConstraints == 0 ? .notStarted : .teacherOnly
            ),
            ChecklistItem(part: .answerKey, value: assignment.answerKeyText.isWhitespaceOnly ? "Optional" : "Added",
                          status: assignment.answerKeyText.isWhitespaceOnly ? .notStarted : .onTrack),
            ChecklistItem(part: .exemplar, value: assignment.exemplarText.isWhitespaceOnly ? "Optional" : "Added",
                          status: assignment.exemplarText.isWhitespaceOnly ? .notStarted : .onTrack),
            ChecklistItem(part: .formativeFocus, value: assignment.formativeFocusText.isWhitespaceOnly ? "Optional" : "Added",
                          status: assignment.formativeFocusText.isWhitespaceOnly ? .notStarted : .onTrack),
            ChecklistItem(
                part: .curriculum,
                value: mappings > 0 ? "\(mappings) mapped" : (assignment.curriculumReference.isWhitespaceOnly ? "Not started" : "Reference added"),
                status: mappings > 0 || !assignment.curriculumReference.isWhitespaceOnly ? .onTrack : .notStarted
            )
        ]
    }

    private func checklistSection(_ setup: AssignmentSetup, proxy: ScrollViewProxy) -> some View {
        Section {
            if !setup.assignment.hasGradingStandard {
                Label(ReadinessIssue.missingGradingStandard.message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            ForEach(checklistItems(setup)) { item in
                Button {
                    expanded.insert(item.part)
                    Task { @MainActor in
                        // The section's rows exist only once it is expanded.
                        try? await Task.sleep(for: .milliseconds(100))
                        withAnimation { proxy.scrollTo(item.part, anchor: .top) }
                    }
                } label: {
                    LabeledContent {
                        StatusLabel(item.status, subject: "\(item.part.title) status")
                    } label: {
                        Text(item.part.title)
                        Text(item.value)
                    }
                }
                .accessibilityIdentifier("rubric.checklist.\(item.part.rawValue)")
            }
        } header: {
            Text("Setup Checklist")
        } footer: {
            Text("Tap a row to go to that part of the setup. Only teacher-reviewed setup content enters the grading packet.")
        }
    }

    // MARK: - Rubric text

    private func rubricTextSection(_ setup: AssignmentSetup) -> some View {
        Section(isExpanded: expansion(.rubricText)) {
            Menu {
                ForEach(RubricTemplates.builtIn) { template in
                    Button(template.name) {
                        Task { await model.applyRubricTemplate(template) }
                    }
                }
            } label: {
                Label("Apply Rubric Template", systemImage: "list.bullet.clipboard")
            }
            .id(RubricPart.rubricText)
            .accessibilityIdentifier("rubric.applyTemplate")

            Button {
                showingRubricImporter = true
            } label: {
                Label("Import Rubric File", systemImage: "doc.badge.plus")
            }
            .accessibilityIdentifier("rubric.importFile")
            .fileImporter(isPresented: $showingRubricImporter, allowedContentTypes: Self.rubricFileTypes) { result in
                switch result {
                case .success(let url):
                    model.importRubricFile(at: url)
                case .failure(let error):
                    model.alert = AlertMessage(title: "Rubric file not read", error: error)
                }
            }

            TextField("Rubric or grading criteria", text: model.text(\.rubricText), axis: .vertical)
                .accessibilityIdentifier("rubric.text")

            if model.canSuggestRubric {
                if case .unavailable(let message) = model.localAIStatus {
                    Label(message, systemImage: "cpu")
                        .foregroundStyle(.secondary)
                }
                Button {
                    Task { await model.suggestRubricCriteria() }
                } label: {
                    if model.isSuggestingRubric {
                        Label {
                            Text("Suggesting Criteria…")
                        } icon: {
                            ProgressView()
                        }
                    } else {
                        Label("Suggest Criteria with On-Device AI", systemImage: "sparkles")
                    }
                }
                .disabled(model.isSuggestingRubric || model.localAIStatus != .available)
                .accessibilityIdentifier("rubric.suggestCriteria")
            }
        } header: {
            Text(RubricPart.rubricText.title)
        }
    }

    private func importPreviewSection(_ preview: RubricImportPreview) -> some View {
        Section {
            LabeledContent("Detected criteria", value: "\(preview.detectedCriteria.count)")
            LabeledContent("Scoring bands", value: "\(preview.detectedLevels.count)")
            ForEach(preview.detectedCriteria) { criterion in
                criterionRow(criterion)
            }
            ForEach(preview.issues) { issue in
                Label(issue.message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            Button {
                Task { await model.confirmRubricPreview(structured: true) }
            } label: {
                Label("Confirm Structured Import", systemImage: "checkmark.circle")
            }
            .disabled(preview.detectedCriteria.isEmpty)
            .accessibilityIdentifier("rubric.confirmStructuredImport")
            Button {
                Task { await model.confirmRubricPreview(structured: false) }
            } label: {
                Label("Use Rubric Text Only", systemImage: "text.alignleft")
            }
            .accessibilityIdentifier("rubric.useRubricText")
            Button(role: .destructive) {
                model.discardRubricPreview()
            } label: {
                Label("Discard Import", systemImage: "xmark.circle")
            }
            .accessibilityIdentifier("rubric.discardImport")
        } header: {
            Text(preview.issues.isEmpty ? "Import Preview" : "Imported with Warnings")
        } footer: {
            Text("Review the criteria before using them for grading. Nothing is saved until you confirm.")
        }
    }

    private func suggestionSection(_ suggestion: ParsedRubric) -> some View {
        Section {
            ForEach(suggestion.criteria) { criterion in
                criterionRow(criterion)
            }
            LabeledContent("Total", value: "\(GradeTotals.formatted(suggestion.totalMaxPoints)) points")
            Button {
                Task { await model.confirmSuggestedRubric() }
            } label: {
                Label("Confirm Suggested Criteria", systemImage: "checkmark.circle")
            }
            .accessibilityIdentifier("rubric.confirmSuggestion")
            Button(role: .destructive) {
                model.discardSuggestedRubric()
            } label: {
                Label("Discard Suggestion", systemImage: "xmark.circle")
            }
            .accessibilityIdentifier("rubric.discardSuggestion")
        } header: {
            Text("Suggested by on-device AI — check before confirming")
        } footer: {
            Text("The suggestion is not saved until you confirm it.")
        }
    }

    // MARK: - Criteria

    private func criteriaSection(_ setup: AssignmentSetup) -> some View {
        let rubric = setup.parsedRubric
        return Section(isExpanded: expansion(.criteria)) {
            Group {
                if rubric.criteria.isEmpty {
                    ContentUnavailableView(
                        "No structured criteria detected",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Drafts and manual grading still require teacher review.")
                    )
                } else {
                    LabeledContent("Total", value: "\(rubric.criteria.count) criteria · \(GradeTotals.formatted(rubric.totalMaxPoints)) points")
                }
            }
            .id(RubricPart.criteria)
            ForEach(rubric.criteria) { criterion in
                criterionRow(criterion)
            }
            ForEach(rubric.issues, id: \.self) { issue in
                Label(issue, systemImage: "info.circle")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(RubricPart.criteria.title)
        }
    }

    private func criterionRow(_ criterion: RubricCriterion) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent(criterion.title, value: "\(GradeTotals.formatted(criterion.maxPoints)) points")
            if let group = criterion.groupTitle, !group.isWhitespaceOnly {
                Text(group)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !criterion.descriptor.isWhitespaceOnly {
                Text(criterion.descriptor)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if !criterion.levels.isEmpty {
                RubricFlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(criterion.levels) { level in
                        Text("\(level.label) · \(GradeTotals.formatted(level.points))")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.fill.tertiary, in: Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Instructions and templates

    private func instructionsSection(_ setup: AssignmentSetup) -> some View {
        Section(isExpanded: expansion(.instructions)) {
            TextField("Custom teacher instructions", text: model.text(\.customInstructions), axis: .vertical)
                .id(RubricPart.instructions)
                .accessibilityIdentifier("rubric.instructions")
            templateMenu(
                title: "Insert Instruction Template",
                templates: TeacherInstructionTemplateCatalog.all,
                identifier: "rubric.instructionTemplate",
                name: \.name
            ) { template in
                request(.instruction(template), existing: setup.assignment.customInstructions)
            }
        } header: {
            Text(RubricPart.instructions.title)
        }
    }

    private func answerKeySection(_ setup: AssignmentSetup) -> some View {
        Section(isExpanded: expansion(.answerKey)) {
            TextField("Answer key", text: model.text(\.answerKeyText), axis: .vertical)
                .id(RubricPart.answerKey)
                .accessibilityIdentifier("rubric.answerKey")
            templateMenu(
                title: "Insert Answer-Key Template",
                templates: AnswerKeyTemplateCatalog.templates(for: setup.assignment.assignmentType),
                identifier: "rubric.answerKeyTemplate",
                name: \.name
            ) { template in
                request(.answerKey(template), existing: setup.assignment.answerKeyText)
            }
        } header: {
            Text(RubricPart.answerKey.title)
        }
    }

    private func exemplarSection(_ setup: AssignmentSetup) -> some View {
        Section(isExpanded: expansion(.exemplar)) {
            TextField("Exemplar response", text: model.text(\.exemplarText), axis: .vertical)
                .id(RubricPart.exemplar)
                .accessibilityIdentifier("rubric.exemplar")
            templateMenu(
                title: "Insert Exemplar Template",
                templates: ExemplarTemplateCatalog.templates(for: setup.assignment.assignmentType),
                identifier: "rubric.exemplarTemplate",
                name: \.name
            ) { template in
                request(.exemplar(template), existing: setup.assignment.exemplarText)
            }
        } header: {
            Text(RubricPart.exemplar.title)
        }
    }

    private func formativeFocusSection(_ setup: AssignmentSetup) -> some View {
        Section(isExpanded: expansion(.formativeFocus)) {
            TextField("Formative focus", text: model.text(\.formativeFocusText), axis: .vertical)
                .id(RubricPart.formativeFocus)
                .accessibilityIdentifier("rubric.formativeFocus")
            templateMenu(
                title: "Insert Formative Focus Template",
                templates: FormativeFocusTemplateCatalog.templates(for: setup.assignment.assignmentType),
                identifier: "rubric.formativeTemplate",
                name: \.name
            ) { template in
                request(.formativeFocus(template), existing: setup.assignment.formativeFocusText)
            }
        } header: {
            Text(RubricPart.formativeFocus.title)
        }
    }

    @ViewBuilder
    private func templateMenu<Template: Identifiable>(
        title: String,
        templates: [Template],
        identifier: String,
        name: @escaping (Template) -> String,
        choose: @escaping (Template) -> Void
    ) -> some View {
        if templates.isEmpty {
            Text("No compatible template is available for this assignment type.")
                .foregroundStyle(.secondary)
        } else {
            Menu {
                ForEach(templates) { template in
                    Button(name(template)) { choose(template) }
                }
            } label: {
                Label(title, systemImage: "text.badge.plus")
            }
            .accessibilityIdentifier(identifier)
        }
    }

    private func request(_ target: TemplateTarget, existing: String) {
        if existing.isWhitespaceOnly {
            apply(target, mode: .append)
        } else {
            pendingTemplate = target
        }
    }

    private func apply(_ target: TemplateTarget, mode: TemplateInsertionMode) {
        pendingTemplate = nil
        Task {
            switch target {
            case .instruction(let template):
                await model.applyInstructionTemplate(template, mode: mode)
            case .answerKey(let template):
                await model.applyAnswerKeyTemplate(template, mode: mode)
            case .exemplar(let template):
                await model.applyExemplarTemplate(template, mode: mode)
            case .formativeFocus(let template):
                await model.applyFormativeFocusTemplate(template, mode: mode)
            }
        }
    }

    // MARK: - AI grading constraints

    private func constraintsSection(_ setup: AssignmentSetup) -> some View {
        Section(isExpanded: expansion(.constraints)) {
            Group {
                if case .unavailable(let message) = model.localAIStatus {
                    Label(message, systemImage: "cpu")
                        .foregroundStyle(.secondary)
                } else {
                    Text("These prompts guide the local draft only. Sensitive templates are never selected automatically.")
                        .foregroundStyle(.secondary)
                }
            }
            .id(RubricPart.constraints)
            ForEach(GradingConstraintTemplates.builtIn) { template in
                Toggle(isOn: constraintBinding(template, selected: setup.assignment.constraintTemplateIDs)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(template.title)
                        Text(template.text)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        if template.sensitiveContextRequired {
                            Label("Select only when teacher-provided context exists. MarkForMe must not infer it.", systemImage: "exclamationmark.triangle")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .accessibilityIdentifier("rubric.constraint.\(template.id)")
            }
        } header: {
            Text(RubricPart.constraints.title)
        }
    }

    private func constraintBinding(_ template: GradingConstraintTemplate, selected: [String]) -> Binding<Bool> {
        Binding(
            get: { selected.contains(template.id) },
            set: { isOn in
                let isSelected = selected.contains(template.id)
                guard isOn != isSelected else { return }
                if isOn, template.sensitiveContextRequired {
                    pendingSensitiveTemplate = template
                } else {
                    model.toggleConstraintTemplate(template.id)
                }
            }
        )
    }

    private func sensitiveTemplateSheet(_ template: GradingConstraintTemplate) -> some View {
        NavigationStack {
            Form {
                Section("Teacher-Provided Context Required") {
                    Text("Use sensitive context only when it was provided by the teacher or school record and is relevant to the grading task.")
                    Text("The local model must not infer disability, language background, support needs, or protected characteristics from the student work.")
                    Text("This template guides how feedback is phrased; it does not lower or raise marks unless the rubric or teacher instructions explicitly require an adjustment.")
                }
                Section("Template") {
                    Text(template.title)
                        .font(.headline)
                    Text(template.text)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Sensitive Context")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { pendingSensitiveTemplate = nil }
                        .accessibilityIdentifier("rubric.sensitiveCancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm Teacher-Provided Context") {
                        if model.setup?.assignment.constraintTemplateIDs.contains(template.id) == false {
                            model.toggleConstraintTemplate(template.id)
                        }
                        pendingSensitiveTemplate = nil
                    }
                    .accessibilityIdentifier("rubric.sensitiveConfirm")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Curriculum

    private func curriculumSection(_ setup: AssignmentSetup) -> some View {
        Section(isExpanded: expansion(.curriculum)) {
            Text(CurriculumCatalogService.sourceWarning)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .id(RubricPart.curriculum)
            ForEach(Array(setup.curriculumMappings.enumerated()), id: \.element.id) { index, mapping in
                mappingRow(mapping, index: index)
            }
            NavigationLink(value: Route.curriculum(assignmentID: model.assignmentID)) {
                Label("Browse Australian Curriculum", systemImage: "book.closed")
            }
            .accessibilityIdentifier("rubric.curriculumBrowse")
            Button {
                Task { await model.suggestCurriculumReferences() }
            } label: {
                if model.isSuggestingCurriculum {
                    Label {
                        Text("Suggesting References…")
                    } icon: {
                        ProgressView()
                    }
                } else {
                    Label("Suggest References with On-Device AI", systemImage: "sparkles")
                }
            }
            .disabled(model.isSuggestingCurriculum || model.localAIStatus != .available)
            .accessibilityIdentifier("rubric.curriculumSuggest")
            Button {
                showingCurriculumImporter = true
            } label: {
                Label("Import Teacher-Provided Curriculum File", systemImage: "doc.badge.plus")
            }
            .accessibilityIdentifier("rubric.curriculumImport")
            .fileImporter(isPresented: $showingCurriculumImporter, allowedContentTypes: Self.curriculumFileTypes) { result in
                switch result {
                case .success(let url):
                    Task { await model.importCurriculumFile(at: url) }
                case .failure(let error):
                    model.alert = AlertMessage(title: "Curriculum file not read", error: error)
                }
            }
            if let fileName = model.lastCurriculumImportFileName {
                Label("Imported from \(fileName)", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            }
            TextField("Teacher-selected curriculum or reference material", text: model.text(\.curriculumReference), axis: .vertical)
                .accessibilityIdentifier("rubric.curriculumReference")
        } header: {
            Text(RubricPart.curriculum.title)
        }
    }

    private func mappingRow(_ mapping: CurriculumMapping, index: Int) -> some View {
        let item = model.mappedItems[mapping.curriculumItemID]
        return VStack(alignment: .leading, spacing: 6) {
            Text(item.map { "\($0.code): \($0.title)" } ?? mapping.curriculumItemID)
            if let item, !item.shortDescription.isWhitespaceOnly {
                Text(item.shortDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let item {
                Text("Source: \(item.sourceName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !mapping.teacherConfirmed {
                Label("Suggested by on-device AI — not used until you confirm it", systemImage: "sparkles")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                HStack {
                    Button("Confirm") {
                        Task { await model.confirmMapping(id: mapping.id) }
                    }
                    .accessibilityIdentifier("rubric.mappingConfirm.\(index)")
                    Button("Reject", role: .destructive) {
                        Task { await model.removeMapping(id: mapping.id) }
                    }
                    .accessibilityIdentifier("rubric.mappingReject.\(index)")
                }
                .buttonStyle(.borderless)
            }
        }
        .swipeActions {
            Button("Remove", role: .destructive) {
                Task { await model.removeMapping(id: mapping.id) }
            }
            .accessibilityIdentifier("rubric.mappingRemove.\(index)")
        }
    }

    // MARK: - Helpers

    private func expansion(_ part: RubricPart) -> Binding<Bool> {
        Binding(
            get: { expanded.contains(part) },
            set: { isExpanded in
                if isExpanded { expanded.insert(part) } else { expanded.remove(part) }
            }
        )
    }
}

/// `sheet(item:)` needs an `Identifiable` value; the constraint template's own ID serves.
private struct SensitiveTemplateItem: Identifiable {
    var template: GradingConstraintTemplate
    var id: String { template.id }
}

#if DEBUG
#Preview("Light") {
    ScreenPreview { app in RouteDestination(route: .rubric(PreviewFixtures.assignmentID), app: app) }
}

#Preview("Dark") {
    ScreenPreview { app in RouteDestination(route: .rubric(PreviewFixtures.assignmentID), app: app) }
        .preferredColorScheme(.dark)
}

#Preview("Accessibility XXXL") {
    ScreenPreview { app in RouteDestination(route: .rubric(PreviewFixtures.assignmentID), app: app) }
        .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
