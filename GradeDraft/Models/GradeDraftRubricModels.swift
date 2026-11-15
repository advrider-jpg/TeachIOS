import Foundation

// MARK: - Rubric records

struct ParsedRubric: Codable, Equatable, Sendable {
    var criteria: [RubricCriterion]
    var issues: [String]
    var groups: [String]

    init(criteria: [RubricCriterion] = [], issues: [String] = [], groups: [String] = []) {
        self.criteria = criteria
        self.issues = issues
        self.groups = groups
    }

    var isStructured: Bool {
        !criteria.isEmpty
    }

    /// The assignment's maximum: the sum of every criterion's maximum points.
    var totalMaxPoints: Double {
        criteria.reduce(0) { $0 + $1.maxPoints }
    }

    func criterion(id: String) -> RubricCriterion? {
        criteria.first { $0.id == id }
    }
}

struct RubricCriterion: Identifiable, Codable, Equatable, Sendable {
    var id: String
    var title: String
    var maxPoints: Double
    var descriptor: String
    var sortOrder: Int
    var groupTitle: String?
    var levels: [RubricLevel]
    var explicitID: String?

    init(
        id: String,
        title: String,
        maxPoints: Double,
        descriptor: String,
        sortOrder: Int,
        groupTitle: String? = nil,
        levels: [RubricLevel] = [],
        explicitID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.maxPoints = maxPoints
        self.descriptor = descriptor
        self.sortOrder = sortOrder
        self.groupTitle = groupTitle
        self.levels = levels
        self.explicitID = explicitID
    }
}

struct RubricLevel: Identifiable, Codable, Equatable, Sendable {
    var id: String
    var label: String
    var points: Double
    var minPoints: Double?
    var maxPoints: Double?
    var descriptor: String
    var sortOrder: Int

    init(
        id: String,
        label: String,
        points: Double,
        minPoints: Double? = nil,
        maxPoints: Double? = nil,
        descriptor: String,
        sortOrder: Int
    ) {
        self.id = id
        self.label = label
        self.points = points
        self.minPoints = minPoints
        self.maxPoints = maxPoints
        self.descriptor = descriptor
        self.sortOrder = sortOrder
    }
}

struct RubricParseIssue: Identifiable, Codable, Equatable, Sendable {
    var id: UUID = UUID()
    var severity: String
    var message: String
    var lineNumber: Int?
}

struct RubricImportPreview: Codable, Equatable, Sendable {
    var rawMarkdown: String
    var parsedRubric: ParsedRubric
    var detectedCriteria: [RubricCriterion]
    var detectedLevels: [RubricLevel]
    var issues: [RubricParseIssue]
    var fallbackRawTextAvailable: Bool

    init(rawMarkdown: String, parsedRubric: ParsedRubric) {
        self.rawMarkdown = rawMarkdown
        self.parsedRubric = parsedRubric
        self.detectedCriteria = parsedRubric.criteria
        self.detectedLevels = parsedRubric.criteria.flatMap(\.levels)
        self.issues = parsedRubric.issues.map { RubricParseIssue(severity: "warning", message: $0, lineNumber: nil) }
        self.fallbackRawTextAvailable = !rawMarkdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum RubricParser {
    static func parse(_ text: String) -> ParsedRubric {
        let lines = text.components(separatedBy: .newlines)
        var criteria: [RubricCriterion] = []
        var issues: [String] = []
        var groupStack: [String] = []
        var seenKeys: Set<String> = []

        for (lineNumber, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if trimmed.hasPrefix("#") {
                let heading = trimmed.replacingOccurrences(of: #"^#{1,6}\s*"#, with: "", options: .regularExpression)
                if !heading.isEmpty { groupStack.append(heading) }
                continue
            }
            let plain = trimmed
                .replacingOccurrences(of: #"^[-*•]\s*"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"^\d+[.)]\s*"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: "__", with: "")
            guard let maxPoints = maxPoints(in: plain) else { continue }
            guard let title = criterionTitle(from: plain), !title.isEmpty else { continue }
            let key = normalized(title)
            if seenKeys.contains(key) {
                issues.append("Duplicate criterion ignored at line \(lineNumber + 1): \(title)")
                continue
            }
            seenKeys.insert(key)
            let order = criteria.count
            let id = explicitCriterionID(in: plain) ?? stableCriterionID(order: order, title: title, maxPoints: maxPoints)
            criteria.append(
                RubricCriterion(
                    id: id,
                    title: title,
                    maxPoints: maxPoints,
                    descriptor: plain,
                    sortOrder: order,
                    groupTitle: groupStack.last,
                    levels: levels(in: plain, criterionID: id),
                    explicitID: explicitCriterionID(in: plain)
                )
            )
        }

        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("Rubric text is empty.")
        } else if criteria.isEmpty {
            issues.append("No explicit point-bearing criteria were detected. The raw rubric text remains available for teacher review and grading context.")
        }

        return ParsedRubric(criteria: criteria, issues: issues, groups: Array(Set(groupStack)).sorted())
    }

    static func stableCriterionID(order: Int, title: String, maxPoints: Double) -> String {
        "criterion-\(order + 1)-\(ContentDigest.sha256Hex(title + "\u{1F}" + String(maxPoints)).prefix(8))"
    }

    static func maxPoints(in line: String) -> Double? {
        let pattern = #"(?i)(?:0\s*[-–]\s*)?(\d+(?:\.\d+)?)\s*(?:points?|pts?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: range), match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: line) else {
            return nil
        }
        return Double(line[valueRange])
    }

    static func pointRange(in line: String) -> (Double?, Double?) {
        let pattern = #"(?i)(\d+(?:\.\d+)?)\s*[-–]\s*(\d+(?:\.\d+)?)\s*(?:points?|pts?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return (nil, nil) }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: range), match.numberOfRanges > 2,
              let lowRange = Range(match.range(at: 1), in: line),
              let highRange = Range(match.range(at: 2), in: line) else { return (nil, nil) }
        return (Double(line[lowRange]), Double(line[highRange]))
    }

    static func criterionTitle(from line: String) -> String? {
        let strippedID = line.replacingOccurrences(of: #"^\[[A-Za-z0-9_-]+\]\s*"#, with: "", options: .regularExpression)
        if let colon = strippedID.firstIndex(of: ":") {
            return String(strippedID[..<colon]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let dashRange = strippedID.range(of: #"\s[-–—]\s"#, options: .regularExpression) {
            return String(strippedID[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return strippedID.replacingOccurrences(
            of: #"(?i)\b(?:0\s*[-–]\s*)?\d+(?:\.\d+)?\s*(?:points?|pts?)\b.*$"#,
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func explicitCriterionID(in line: String) -> String? {
        let pattern = #"^\[([A-Za-z0-9_-]+)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: range), match.numberOfRanges > 1,
              let idRange = Range(match.range(at: 1), in: line) else { return nil }
        return String(line[idRange])
    }

    static func levels(in line: String, criterionID: String) -> [RubricLevel] {
        let knownLabels = ["Excellent", "Proficient", "Developing", "Beginning", "Meets", "Exceeds", "Approaches"]
        var levels: [RubricLevel] = []
        for label in knownLabels where line.localizedCaseInsensitiveContains(label) {
            let (min, max) = pointRange(in: line)
            let points = max ?? maxPoints(in: line) ?? 0
            levels.append(
                RubricLevel(
                    id: "\(criterionID)-level-\(levels.count + 1)-\(label.lowercased())",
                    label: label,
                    points: points,
                    minPoints: min,
                    maxPoints: max,
                    descriptor: line,
                    sortOrder: levels.count
                )
            )
        }
        return levels
    }

    static func normalized(_ text: String) -> String {
        text.lowercased().replacingOccurrences(of: #"[^a-z0-9]+"#, with: "", options: .regularExpression)
    }
}
