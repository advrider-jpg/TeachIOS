import Foundation
import GRDB

// MARK: - Curriculum references

/// One item from the bundled Australian Curriculum catalogue, read by `CurriculumCatalogService`.
struct CurriculumItem: Identifiable, Codable, Equatable, Sendable {
    var id: String
    var source: String
    var version: String
    var sourceVersion: String
    var learningArea: String
    var subject: String
    var yearLevel: String
    var band: String
    var strand: String
    var substrand: String
    var organizer: String
    var itemType: String
    var catalogKind: String
    var code: String
    var title: String
    var shortDescription: String
    var sourceURL: String
    var externalURI: String
    var provenance: String
    var sourceKey: String
    var sourceName: String
    var altLabels: [String]
    var parentIDs: [String]
    var childIDs: [String]
    var tags: [String]
    var isOfficial: Bool
    var isEditable: Bool
    var licenseName: String
    var sourceAttribution: String

    init(
        id: String,
        source: String,
        version: String,
        sourceVersion: String = "",
        learningArea: String,
        subject: String,
        yearLevel: String,
        band: String = "",
        strand: String = "",
        substrand: String = "",
        organizer: String = "",
        itemType: String,
        catalogKind: String = "",
        code: String,
        title: String,
        shortDescription: String,
        sourceURL: String,
        externalURI: String = "",
        provenance: String = "",
        sourceKey: String = "",
        sourceName: String = "",
        altLabels: [String] = [],
        parentIDs: [String] = [],
        childIDs: [String] = [],
        tags: [String] = [],
        isOfficial: Bool = false,
        isEditable: Bool = true,
        licenseName: String = "",
        sourceAttribution: String = ""
    ) {
        self.id = id
        self.source = source
        self.version = version
        self.sourceVersion = sourceVersion.isEmpty ? version : sourceVersion
        self.learningArea = learningArea
        self.subject = subject
        self.yearLevel = yearLevel
        self.band = band
        self.strand = strand
        self.substrand = substrand
        self.organizer = organizer
        self.itemType = itemType
        self.catalogKind = catalogKind.isEmpty ? itemType : catalogKind
        self.code = code
        self.title = title
        self.shortDescription = shortDescription
        self.sourceURL = sourceURL
        self.externalURI = externalURI.isEmpty ? sourceURL : externalURI
        self.provenance = provenance.isEmpty ? sourceURL : provenance
        self.sourceKey = sourceKey
        self.sourceName = sourceName.isEmpty ? source : sourceName
        self.altLabels = altLabels
        self.parentIDs = parentIDs
        self.childIDs = childIDs
        self.tags = tags
        self.isOfficial = isOfficial
        self.isEditable = isEditable
        self.licenseName = licenseName
        self.sourceAttribution = sourceAttribution
    }
}

/// A curriculum reference the teacher imported from a file; searched with the bundled catalogue.
struct ImportedCurriculumItem: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable, Sendable {
    static let databaseTableName = "importedCurriculumItem"

    var id: String
    var code: String
    var title: String
    var shortDescription: String
    var learningArea: String
    var subject: String
    var yearLevel: String
    var strand: String
    var sourceName: String
    var importedAt: Date

    init(
        id: String,
        code: String,
        title: String,
        shortDescription: String = "",
        learningArea: String = "",
        subject: String = "",
        yearLevel: String = "",
        strand: String = "",
        sourceName: String,
        importedAt: Date = Date()
    ) {
        self.id = id
        self.code = code
        self.title = title
        self.shortDescription = shortDescription
        self.learningArea = learningArea
        self.subject = subject
        self.yearLevel = yearLevel
        self.strand = strand
        self.sourceName = sourceName
        self.importedAt = importedAt
    }
}
