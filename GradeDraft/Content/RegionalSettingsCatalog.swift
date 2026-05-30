import Foundation

// MARK: - Regional settings and terminology

struct RegionalSettingsDefinition: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var defaultLocaleIdentifier: String
    var schoolYearLabel: String
    var subjectAreaLabel: String
    var curriculumReferenceLabel: String
    var warnings: [String]
}

enum RegionalSettingsCatalog {
    static let australia = RegionalSettingsDefinition(
        id: "australia",
        name: "Australia",
        defaultLocaleIdentifier: "en_AU",
        schoolYearLabel: "Year level",
        subjectAreaLabel: "Learning area",
        curriculumReferenceLabel: "Curriculum/reference material",
        warnings: [
            "Teacher-entered curriculum references are local planning material unless an official import is actually implemented.",
            "Do not imply ACARA or state/territory authority endorsement without permission.",
            "Use teacher judgment for adjustments, EAL/D context, inclusive practice, and formative assessment interpretation."
        ]
    )

    static let generic = RegionalSettingsDefinition(
        id: "generic",
        name: "Generic",
        defaultLocaleIdentifier: "en",
        schoolYearLabel: "Grade level",
        subjectAreaLabel: "Subject",
        curriculumReferenceLabel: "Curriculum/reference material",
        warnings: [
            "Teacher-entered curriculum references are local planning material unless an official import is actually implemented."
        ]
    )

    static let all = [australia, generic]
}
