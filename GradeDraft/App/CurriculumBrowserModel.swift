import Foundation
import Observation

/// Searching the bundled curriculum catalogue. Mapping a result to
/// the assignment is done through `AssignmentSetupModel`.
@Observable @MainActor
final class CurriculumBrowserModel {
    var searchText = ""
    var learningArea: String?
    var subject: String?
    var yearLevel: String?

    private(set) var facets: CurriculumFacets?
    private(set) var sources: [CurriculumSourceInfo] = []
    private(set) var results: [CurriculumItem] = []
    private(set) var isSearching = false
    var alert: AlertMessage?

    @ObservationIgnored let app: AppModel

    init(app: AppModel) {
        self.app = app
    }

    var hasFilters: Bool {
        [learningArea, subject, yearLevel].contains { !($0 ?? "").isEmpty }
    }

    /// The filter values and source details; called once when the browser opens.
    func loadFacets() async {
        do {
            let catalog = app.services.curriculumCatalog
            facets = try await catalog.facets()
            sources = try await catalog.sources()
        } catch {
            alert = AlertMessage(title: "Curriculum catalogue not available", error: error)
        }
    }

    /// Runs the search for the current text and filters. The screen calls it from
    /// `.task(id:)` on the search inputs, so a newer search replaces an older one.
    func search() async {
        let text = searchText
        isSearching = true
        defer { isSearching = false }
        do {
            let catalog = app.services.curriculumCatalog
            let found = try await catalog.search(text, learningArea: learningArea, subject: subject, yearLevel: yearLevel)
            try Task.checkCancellation()
            results = found
        } catch is CancellationError {
        } catch {
            alert = AlertMessage(title: "Search failed", error: error)
        }
    }

    func clearFilters() {
        searchText = ""
        learningArea = nil
        subject = nil
        yearLevel = nil
        results = []
    }
}
