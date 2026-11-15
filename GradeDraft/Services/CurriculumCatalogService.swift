import Foundation
import GRDB

struct CurriculumFacets: Equatable, Sendable {
    var learningAreas: [String]
    var subjects: [String]
    var yearLevels: [String]
}

struct CurriculumSourceInfo: Equatable, Sendable {
    var id: String
    var name: String
    var version: String
    var sourceVersion: String
    var licenseName: String
    var attribution: String
    var sha256: String
    var jsonldURL: String
}

/// Searches the bundled Australian Curriculum SQLite file on demand. The file is opened read-only on first use;
/// nothing is decoded at launch. Teacher-imported items live in the app database and are searched separately.
actor CurriculumCatalogService {
    static let resourceName = "curriculum_acara_v9"
    static let searchLimit = 50

    static let sourceWarning = "Australian Curriculum references are bundled for offline teacher-controlled reference only. MarkForMe does not claim ACARA endorsement, certification, compliance, or jurisdiction reporting approval. Teachers must explicitly map each reference before it is used in grading context."
    static let icipWarning = "Some Australian Curriculum material relates to Aboriginal and Torres Strait Islander Histories and Cultures and may involve Indigenous Cultural and Intellectual Property considerations. Use, adaptation, and publication must respect applicable cultural protocols and permissions."

    private let bundle: Bundle
    private var queue: DatabaseQueue?

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    // MARK: Bundled catalogue

    /// Full-text search over code, title, description, strand and tags. Each word is a prefix term; best match first.
    /// Filters are exact-match conditions combined with AND. Empty text with a filter returns the filtered items
    /// ordered by code; empty text and no filters returns nothing.
    func search(
        _ text: String,
        learningArea: String? = nil,
        subject: String? = nil,
        yearLevel: String? = nil,
        limit: Int = CurriculumCatalogService.searchLimit
    ) async throws -> [CurriculumItem] {
        let match = Self.matchExpression(for: text)
        var conditions: [String] = []
        var arguments: [any DatabaseValueConvertible] = []
        for (column, value) in [("learningArea", learningArea), ("subject", subject), ("yearLevel", yearLevel)] {
            if let value, !value.isEmpty {
                conditions.append("item.\(column) = ?")
                arguments.append(value)
            }
        }
        guard limit > 0, match != nil || !conditions.isEmpty else { return [] }
        var sql = Self.itemSelect
        let order: String
        if let match {
            sql += " JOIN itemSearch ON itemSearch.rowid = item.rowid"
            conditions.insert("itemSearch MATCH ?", at: 0)
            arguments.insert(match, at: 0)
            order = "bm25(itemSearch), item.id"
        } else {
            order = "item.code, item.id"
        }
        sql += " WHERE " + conditions.joined(separator: " AND ") + " ORDER BY \(order) LIMIT ?"
        arguments.append(limit)
        let queue = try openQueue()
        let statementArguments = StatementArguments(arguments)
        let finalSQL = sql
        return try await queue.read { db in
            try Row.fetchAll(db, sql: finalSQL, arguments: statementArguments).map(Self.curriculumItem(from:))
        }
    }

    /// Sorted distinct non-empty values for the browser's filters.
    func facets() async throws -> CurriculumFacets {
        let queue = try openQueue()
        return try await queue.read { db in
            func distinct(_ column: String) throws -> [String] {
                try String.fetchAll(db, sql: "SELECT DISTINCT \(column) FROM item WHERE \(column) <> ''")
                    .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            }
            return CurriculumFacets(
                learningAreas: try distinct("learningArea"),
                subjects: try distinct("subject"),
                yearLevels: try distinct("yearLevel")
            )
        }
    }

    func sources() async throws -> [CurriculumSourceInfo] {
        let queue = try openQueue()
        return try await queue.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM source ORDER BY id").map { row in
                CurriculumSourceInfo(
                    id: row["id"], name: row["name"], version: row["version"], sourceVersion: row["sourceVersion"],
                    licenseName: row["licenseName"], attribution: row["attribution"],
                    sha256: row["sha256"], jsonldURL: row["jsonldURL"]
                )
            }
        }
    }

    func item(id: String) async throws -> CurriculumItem? {
        try await items(ids: [id]).first
    }

    /// Returns the items found, in the order of `ids`; unknown ids are skipped.
    func items(ids: [String]) async throws -> [CurriculumItem] {
        guard !ids.isEmpty else { return [] }
        let queue = try openQueue()
        let found: [String: CurriculumItem] = try await queue.read { db in
            let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ", ")
            let rows = try Row.fetchAll(
                db,
                sql: Self.itemSelect + " WHERE item.id IN (\(placeholders))",
                arguments: StatementArguments(ids)
            )
            return Dictionary(uniqueKeysWithValues: rows.map(Self.curriculumItem(from:)).map { ($0.id, $0) })
        }
        return ids.compactMap { found[$0] }
    }

    // MARK: Teacher-imported items

    func searchImported(_ text: String, in database: AppDatabase) async throws -> [ImportedCurriculumItem] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let escaped = trimmed
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
        let pattern = "%\(escaped)%"
        return try await database.writer.read { db in
            try ImportedCurriculumItem.fetchAll(
                db,
                sql: """
                SELECT * FROM importedCurriculumItem
                WHERE code LIKE ? ESCAPE '\\' OR title LIKE ? ESCAPE '\\'
                ORDER BY code, title
                LIMIT ?
                """,
                arguments: [pattern, pattern, Self.searchLimit]
            )
        }
    }

    // MARK: Display text

    static func displaySummary(for item: CurriculumItem) -> String {
        let sourceDetail = item.sourceVersion.isEmpty ? item.sourceName : "\(item.sourceName) / \(item.sourceVersion)"
        let level = item.yearLevel.isEmpty ? item.band : item.yearLevel
        return "\(item.code): \(item.title) — \(item.learningArea), \(item.subject), \(level). Source: \(sourceDetail); provenance: \(item.externalURI)"
    }

    static func selectedReferenceSummary(items: [CurriculumItem]) -> String {
        guard !items.isEmpty else { return "" }
        let header = [
            sourceWarning,
            icipWarning,
            "Only teacher-selected references are included."
        ]
        return (header + items.map { "- \(displaySummary(for: $0))" }).joined(separator: "\n")
    }

    // MARK: Database access

    private func openQueue() throws -> DatabaseQueue {
        if let queue { return queue }
        guard let url = bundle.url(forResource: Self.resourceName, withExtension: "sqlite") else {
            throw GradeDraftError.persistenceFailed("The bundled Australian Curriculum database was not found.")
        }
        var configuration = Configuration()
        configuration.readonly = true
        let opened = try DatabaseQueue(path: url.path, configuration: configuration)
        queue = opened
        return opened
    }

    private static let itemSelect = """
        SELECT item.*, source.name AS sourceName, source.version AS sourceVersionLabel, source.sourceVersion AS sourceVersion,
               source.licenseName AS licenseName, source.attribution AS sourceAttribution
        FROM item JOIN source ON source.id = item.sourceID
        """

    /// Each word becomes a quoted prefix term, so teacher text can never be read as FTS5 syntax.
    private static func matchExpression(for text: String) -> String? {
        let words = text
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        guard !words.isEmpty else { return nil }
        return words.map { "\"\($0)\"*" }.joined(separator: " ")
    }

    private static func curriculumItem(from row: Row) -> CurriculumItem {
        func strings(_ column: String) -> [String] {
            let json: String = row[column]
            return (try? JSONDecoder().decode([String].self, from: Data(json.utf8))) ?? []
        }
        let sourceName: String = row["sourceName"]
        let sourceVersion: String = row["sourceVersion"]
        return CurriculumItem(
            id: row["id"],
            source: sourceName,
            version: row["sourceVersionLabel"],
            sourceVersion: sourceVersion,
            learningArea: row["learningArea"],
            subject: row["subject"],
            yearLevel: row["yearLevel"],
            band: row["band"],
            strand: row["strand"],
            substrand: row["substrand"],
            organizer: row["organizer"],
            itemType: row["itemType"],
            catalogKind: row["catalogKind"],
            code: row["code"],
            title: row["title"],
            shortDescription: row["shortDescription"],
            sourceURL: row["sourceURL"],
            externalURI: row["externalURI"],
            provenance: row["provenance"],
            sourceKey: row["sourceKey"],
            sourceName: sourceName,
            altLabels: strings("altLabels"),
            parentIDs: strings("parentIDs"),
            childIDs: strings("childIDs"),
            tags: strings("tags"),
            isOfficial: row["isOfficial"],
            isEditable: false,
            licenseName: row["licenseName"],
            sourceAttribution: row["sourceAttribution"]
        )
    }
}
