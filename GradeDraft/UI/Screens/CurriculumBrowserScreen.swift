import SwiftUI

/// Searches the bundled curriculum catalogue and maps references to one assignment. Nothing enters the
/// grading packet until the teacher adds it or confirms an AI suggestion.
struct CurriculumBrowserScreen: View {
    let setup: AssignmentSetupModel
    let browser: CurriculumBrowserModel

    private struct SearchInput: Hashable {
        var text: String
        var learningArea: String?
        var subject: String?
        var yearLevel: String?
    }

    private var searchInput: SearchInput {
        SearchInput(text: browser.searchText, learningArea: browser.learningArea, subject: browser.subject, yearLevel: browser.yearLevel)
    }

    private var mappings: [CurriculumMapping] {
        setup.setup?.curriculumMappings ?? []
    }

    private var confirmed: [CurriculumMapping] {
        mappings.filter { $0.teacherConfirmed }
    }

    private var suggested: [CurriculumMapping] {
        mappings.filter { $0.suggestedByAI && !$0.teacherConfirmed }
    }

    var body: some View {
        @Bindable var setup = setup
        @Bindable var browser = browser
        list
            .alertMessage($browser.alert)
            .alertMessage($setup.alert)
    }

    private var list: some View {
        @Bindable var browser = browser
        return List {
            Section {
                Text(CurriculumCatalogService.sourceWarning)
                Text(CurriculumCatalogService.icipWarning)
                ForEach(browser.sources, id: \.id) { source in
                    LabeledContent(source.name, value: source.version)
                    if !source.attribution.isEmpty {
                        Text(source.attribution)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("About This Catalogue")
            } footer: {
                Text("MarkForMe does not infer official alignment. AI is not allowed to add curriculum codes; suggestions stay unconfirmed until you confirm them.")
            }

            Section("Mapped to This Assignment") {
                if confirmed.isEmpty {
                    ContentUnavailableView(
                        "No mapped curriculum references",
                        systemImage: "link.slash",
                        description: Text("Search the catalogue and choose Add to include a teacher-selected reference in grading context.")
                    )
                } else {
                    ForEach(confirmed) { mapping in
                        ReferenceRow(display: display(for: mapping), mapping: mapping, setup: setup)
                    }
                }
            }

            Section {
                ForEach(suggested) { mapping in
                    ReferenceRow(display: display(for: mapping), mapping: mapping, setup: setup)
                }
                Button {
                    Task { await setup.suggestCurriculumReferences() }
                } label: {
                    if setup.isSuggestingCurriculum {
                        ProgressView("Suggesting references")
                    } else {
                        Label("Suggest References with On-Device AI", systemImage: "sparkles")
                    }
                }
                .disabled(setup.isSuggestingCurriculum)
                .accessibilityIdentifier("curriculum.suggest")
            } header: {
                Text("Suggested by On-Device AI")
            } footer: {
                Text("Suggested by on-device AI — check before confirming.")
            }

            Section {
                if browser.results.isEmpty {
                    if browser.isSearching {
                        ProgressView()
                    } else if browser.searchText.isEmpty && !browser.hasFilters {
                        ContentUnavailableView(
                            "Search the catalogue",
                            systemImage: "magnifyingglass",
                            description: Text("Search by code, title or description, or choose a filter.")
                        )
                    } else {
                        ContentUnavailableView.search(text: browser.searchText)
                    }
                } else {
                    ForEach(browser.results) { item in
                        ReferenceRow(
                            display: ReferenceDisplay(item),
                            mapping: mappings.first { $0.curriculumItemID == item.id },
                            setup: setup
                        )
                    }
                }
            } header: {
                Text("Catalogue Results")
            } footer: {
                if browser.results.count >= CurriculumCatalogService.searchLimit {
                    Text("Showing the first \(CurriculumCatalogService.searchLimit) matches. Narrow the search or filters to see others.")
                }
            }
        }
        .navigationTitle("Curriculum Catalogue")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $browser.searchText, prompt: "Search code, title, description")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                filterMenu
            }
        }
        .task { await browser.loadFacets() }
        .task(id: searchInput) {
            do {
                try await Task.sleep(for: .milliseconds(250))
            } catch {
                return
            }
            await browser.search()
        }
    }

    private var filterMenu: some View {
        @Bindable var browser = browser
        return Menu {
            if let facets = browser.facets {
                Picker("Learning area", selection: $browser.learningArea) {
                    Text("Any").tag(String?.none)
                    ForEach(facets.learningAreas, id: \.self) { Text($0).tag(Optional($0)) }
                }
                Picker("Subject", selection: $browser.subject) {
                    Text("Any").tag(String?.none)
                    ForEach(facets.subjects, id: \.self) { Text($0).tag(Optional($0)) }
                }
                Picker("Year or band", selection: $browser.yearLevel) {
                    Text("Any").tag(String?.none)
                    ForEach(facets.yearLevels, id: \.self) { Text($0).tag(Optional($0)) }
                }
            }
            Button("Clear Filters", systemImage: "xmark.circle") {
                browser.clearFilters()
            }
            .disabled(!browser.hasFilters && browser.searchText.isEmpty)
        } label: {
            Label("Filters", systemImage: browser.hasFilters
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
        }
        .accessibilityIdentifier("curriculum.filters")
    }

    private func display(for mapping: CurriculumMapping) -> ReferenceDisplay {
        if let item = setup.mappedItems[mapping.curriculumItemID] {
            return ReferenceDisplay(item)
        }
        return ReferenceDisplay(id: mapping.curriculumItemID, code: mapping.curriculumItemID, title: "", description: "", source: "", metadata: "", provenance: [])
    }
}

/// What a reference row shows, whatever it was read from.
private struct ReferenceDisplay {
    var id: String
    var code: String
    var title: String
    var description: String
    var source: String
    var metadata: String
    var provenance: [String]

    init(id: String, code: String, title: String, description: String, source: String, metadata: String, provenance: [String]) {
        self.id = id
        self.code = code
        self.title = title
        self.description = description
        self.source = source
        self.metadata = metadata
        self.provenance = provenance
    }

    init(_ item: CurriculumItem) {
        var lines = ["Source: \(item.sourceName)", "Version: \(item.sourceVersion)"]
        if !item.externalURI.isEmpty { lines.append("URI: \(item.externalURI)") }
        if !item.licenseName.isEmpty { lines.append("License: \(item.licenseName)") }
        if !item.sourceAttribution.isEmpty { lines.append(item.sourceAttribution) }
        self.init(
            id: item.id,
            code: item.code,
            title: item.title,
            description: item.shortDescription,
            source: item.sourceName,
            metadata: [item.learningArea, item.subject, item.yearLevel.isEmpty ? item.band : item.yearLevel]
                .filter { !$0.isEmpty }
                .joined(separator: " • "),
            provenance: lines
        )
    }
}

/// One curriculum reference with the action that fits its state: Add, Remove, or Confirm and Reject.
private struct ReferenceRow: View {
    var display: ReferenceDisplay
    var mapping: CurriculumMapping?
    var setup: AssignmentSetupModel

    private var isSuggestion: Bool {
        mapping.map { $0.suggestedByAI && !$0.teacherConfirmed } ?? false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(display.code.isEmpty ? display.title : display.code)
                .font(.headline)
            if !display.code.isEmpty && !display.title.isEmpty {
                Text(display.title)
            }
            if !display.description.isEmpty {
                Text(display.description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if !display.metadata.isEmpty {
                Text(display.metadata)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !display.source.isEmpty {
                Label(display.source, systemImage: "books.vertical")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if isSuggestion {
                Label("Suggested by on-device AI — check before confirming", systemImage: "sparkles")
                    .font(.caption)
            }
            if !display.provenance.isEmpty {
                DisclosureGroup("Source details") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(display.provenance, id: \.self) { Text($0) }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            actions
        }
        .buttonStyle(.borderless)
    }

    @ViewBuilder
    private var actions: some View {
        if let mapping {
            if isSuggestion {
                ViewThatFits(in: .horizontal) {
                    HStack {
                        confirmButton(mapping)
                        rejectButton(mapping)
                    }
                    VStack(alignment: .leading) {
                        confirmButton(mapping)
                        rejectButton(mapping)
                    }
                }
            } else {
                Button(role: .destructive) {
                    Task { await setup.removeMapping(id: mapping.id) }
                } label: {
                    Label("Remove", systemImage: "link.slash")
                }
                .accessibilityIdentifier("curriculum.remove.\(display.id)")
            }
        } else {
            Button {
                Task { await setup.addMapping(itemID: display.id) }
            } label: {
                Label("Add to Assignment", systemImage: "plus.circle")
            }
            .accessibilityIdentifier("curriculum.add.\(display.id)")
        }
    }

    private func confirmButton(_ mapping: CurriculumMapping) -> some View {
        Button {
            Task { await setup.confirmMapping(id: mapping.id) }
        } label: {
            Label("Confirm", systemImage: "checkmark.circle")
        }
        .accessibilityIdentifier("curriculum.confirm.\(display.id)")
    }

    private func rejectButton(_ mapping: CurriculumMapping) -> some View {
        Button(role: .destructive) {
            Task { await setup.removeMapping(id: mapping.id) }
        } label: {
            Label("Reject", systemImage: "xmark.circle")
        }
        .accessibilityIdentifier("curriculum.reject.\(display.id)")
    }
}

#if DEBUG
private struct CurriculumBrowserPreview: View {
    @State private var model = PreviewFixtures.makeAppModel()

    var body: some View {
        NavigationStack {
            RouteDestination(route: .curriculum(assignmentID: PreviewFixtures.assignmentID), app: model)
        }
        .environment(model)
        .task { await model.observeLists() }
    }
}

#Preview("Light") {
    CurriculumBrowserPreview()
}

#Preview("Dark") {
    CurriculumBrowserPreview()
        .preferredColorScheme(.dark)
}

#Preview("Largest text") {
    CurriculumBrowserPreview()
        .dynamicTypeSize(.accessibility3)
}
#endif
