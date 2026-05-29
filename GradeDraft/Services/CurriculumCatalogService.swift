import Foundation

enum CurriculumCatalogService {
    static let sourceWarning = "Local curriculum references are imported from offline source materials bundled with the repository or provided by the teacher. They are reference aids only; GradeDraft does not claim official endorsement, certification, compliance, or reporting approval."

    static let localCatalog = CurriculumCatalog(
        sources: [
            CurriculumSource(
                id: "australian-curriculum-local-docs",
                name: "Australian Curriculum local source package",
                version: "repository-local",
                provenance: "docs/australiancurriculum/SOURCES.md and related local Markdown source files",
                localPath: "docs/australiancurriculum/"
            )
        ],
        items: [
            CurriculumItem(
                id: "AC-ENG-Y7-RESPOND",
                source: "Australian Curriculum local source package",
                version: "repository-local",
                learningArea: "English",
                subject: "English",
                yearLevel: "Year 7",
                strand: "Literature",
                organizer: "Responding to texts",
                itemType: "content-description",
                code: "AC-ENG-Y7-RESPOND",
                title: "Respond to texts using evidence",
                shortDescription: "Students identify, explain, and support responses to texts using relevant textual evidence.",
                sourceURL: "docs/australiancurriculum/SOURCES.md",
                provenance: "Conservative seed derived from the repository's local Australian Curriculum source package."
            ),
            CurriculumItem(
                id: "AC-MATH-Y6-REASON",
                source: "Australian Curriculum local source package",
                version: "repository-local",
                learningArea: "Mathematics",
                subject: "Mathematics",
                yearLevel: "Year 6",
                strand: "Number",
                organizer: "Reasoning",
                itemType: "content-description",
                code: "AC-MATH-Y6-REASON",
                title: "Explain mathematical reasoning",
                shortDescription: "Students communicate mathematical reasoning and justify conclusions using appropriate language and representations.",
                sourceURL: "docs/australiancurriculum/SOURCES.md",
                provenance: "Conservative seed derived from the repository's local Australian Curriculum source package."
            ),
            CurriculumItem(
                id: "AC-HASS-Y8-SOURCE",
                source: "Australian Curriculum local source package",
                version: "repository-local",
                learningArea: "Humanities and Social Sciences",
                subject: "History",
                yearLevel: "Year 8",
                strand: "Skills",
                organizer: "Source analysis",
                itemType: "content-description",
                code: "AC-HASS-Y8-SOURCE",
                title: "Use evidence from sources",
                shortDescription: "Students analyse sources and use evidence to support historical explanations.",
                sourceURL: "docs/australiancurriculum/SOURCES.md",
                provenance: "Conservative seed derived from the repository's local Australian Curriculum source package."
            )
        ],
        warning: sourceWarning
    )

    static func displaySummary(for item: CurriculumItem) -> String {
        "\(item.code): \(item.title) — \(item.learningArea), \(item.subject), \(item.yearLevel). Source: \(item.source); provenance: \(item.provenance)"
    }

    static func selectedReferenceSummary(items: [CurriculumItem]) -> String {
        guard !items.isEmpty else { return "" }
        let lines = items.map { "- \(displaySummary(for: $0))" }
        return ([sourceWarning] + lines).joined(separator: "\n")
    }

    static func item(id: String, in catalog: CurriculumCatalog = localCatalog) -> CurriculumItem? {
        catalog.items.first { $0.id == id }
    }
}
