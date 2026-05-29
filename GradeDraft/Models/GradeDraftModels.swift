import CoreGraphics
import Foundation

// MARK: - Stable local fingerprints

/// A deterministic local fingerprint used to detect stale grading packets and source changes.
/// This is intentionally not represented as encryption or authentication. It is an app-state
/// fingerprint for offline recordkeeping, not a security boundary.
enum StableFingerprint {
    static func fingerprint(_ components: [String]) -> String {
        fingerprint(Data(components.joined(separator: "\u{001F}").utf8))
    }

    static func fingerprint(_ data: Data) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in data {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(format: "fnv1a64-%016llx", hash)
    }
}

// MARK: - Assignment and classroom records

struct AssignmentRecord: Identifiable, Equatable {
    var id: UUID
    var classGroupID: UUID?
    var studentID: UUID?
    var title: String
    /// The assignment prompt or question. Separate from title; used in the grading packet.
    /// Optional for backwards-compatible decoding; nil is equivalent to empty.
    var prompt: String?
    var subject: String
    var gradeLevel: String
    var assessmentPurpose: AssessmentPurpose
    var curriculumReference: String
    var className: String
    var studentDisplayName: String
    var assignmentType: AssignmentType
    var rubricText: String
    var customInstructions: String
    var answerKeyText: String
    var exemplarText: String
    var reviewedStudentText: String
    var sourceInputs: [SourceInputRef]
    var ocrDocument: OCRDocument?
    var ocrReviewStatus: OCRReviewStatus
    var ocrReviewedAt: Date?
    var latestDraft: GradeDraftResult?
    var finalReview: FinalGradeReview?
    var exportRecords: [ExportRecord]
    var auditEvents: [AuditEvent]
    var evidenceReferences: [EvidenceReference]
    var curriculumMappings: [CurriculumMapping]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        classGroupID: UUID? = nil,
        studentID: UUID? = nil,
        title: String = "New Assignment",
        prompt: String? = nil,
        subject: String = "",
        gradeLevel: String = "",
        assessmentPurpose: AssessmentPurpose = .summative,
        curriculumReference: String = "",
        className: String = "",
        studentDisplayName: String = "",
        assignmentType: AssignmentType = .shortAnswer,
        rubricText: String = "",
        customInstructions: String = "",
        answerKeyText: String = "",
        exemplarText: String = "",
        reviewedStudentText: String = "",
        sourceInputs: [SourceInputRef] = [],
        ocrDocument: OCRDocument? = nil,
        ocrReviewStatus: OCRReviewStatus = .notNeeded,
        ocrReviewedAt: Date? = nil,
        latestDraft: GradeDraftResult? = nil,
        finalReview: FinalGradeReview? = nil,
        exportRecords: [ExportRecord] = [],
        auditEvents: [AuditEvent] = [],
        evidenceReferences: [EvidenceReference] = [],
        curriculumMappings: [CurriculumMapping] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.classGroupID = classGroupID
        self.studentID = studentID
        self.title = title
        self.prompt = prompt
        self.subject = subject
        self.gradeLevel = gradeLevel
        self.assessmentPurpose = assessmentPurpose
        self.curriculumReference = curriculumReference
        self.className = className
        self.studentDisplayName = studentDisplayName
        self.assignmentType = assignmentType
        self.rubricText = rubricText
        self.customInstructions = customInstructions
        self.answerKeyText = answerKeyText
        self.exemplarText = exemplarText
        self.reviewedStudentText = reviewedStudentText
        self.sourceInputs = sourceInputs
        self.ocrDocument = ocrDocument
        self.ocrReviewStatus = ocrReviewStatus
        self.ocrReviewedAt = ocrReviewedAt
        self.latestDraft = latestDraft
        self.finalReview = finalReview
        self.exportRecords = exportRecords
        self.auditEvents = auditEvents
        self.evidenceReferences = evidenceReferences
        self.curriculumMappings = curriculumMappings
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Codable with backward-compatible prompt field

    private enum CodingKeys: String, CodingKey {
        case id, classGroupID, studentID, title, prompt, subject, gradeLevel, assessmentPurpose, curriculumReference
        case className, studentDisplayName, assignmentType, rubricText, customInstructions
        case answerKeyText, exemplarText, reviewedStudentText, sourceInputs, ocrDocument
        case ocrReviewStatus, ocrReviewedAt, latestDraft, finalReview
        case exportRecords, auditEvents, evidenceReferences, curriculumMappings, createdAt, updatedAt
    }
}

extension AssignmentRecord: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        classGroupID = try container.decodeIfPresent(UUID.self, forKey: .classGroupID)
        studentID = try container.decodeIfPresent(UUID.self, forKey: .studentID)
        title = try container.decode(String.self, forKey: .title)
        prompt = try container.decodeIfPresent(String.self, forKey: .prompt)
        subject = try container.decode(String.self, forKey: .subject)
        gradeLevel = try container.decode(String.self, forKey: .gradeLevel)
        assessmentPurpose = try container.decode(AssessmentPurpose.self, forKey: .assessmentPurpose)
        curriculumReference = (try? container.decodeIfPresent(String.self, forKey: .curriculumReference)) ?? ""
        className = try container.decode(String.self, forKey: .className)
        studentDisplayName = try container.decode(String.self, forKey: .studentDisplayName)
        assignmentType = try container.decode(AssignmentType.self, forKey: .assignmentType)
        rubricText = try container.decode(String.self, forKey: .rubricText)
        customInstructions = try container.decode(String.self, forKey: .customInstructions)
        answerKeyText = try container.decode(String.self, forKey: .answerKeyText)
        exemplarText = try container.decode(String.self, forKey: .exemplarText)
        reviewedStudentText = try container.decode(String.self, forKey: .reviewedStudentText)
        sourceInputs = (try? container.decode([SourceInputRef].self, forKey: .sourceInputs)) ?? []
        ocrDocument = try container.decodeIfPresent(OCRDocument.self, forKey: .ocrDocument)
        ocrReviewStatus = try container.decode(OCRReviewStatus.self, forKey: .ocrReviewStatus)
        ocrReviewedAt = try container.decodeIfPresent(Date.self, forKey: .ocrReviewedAt)
        latestDraft = try container.decodeIfPresent(GradeDraftResult.self, forKey: .latestDraft)
        finalReview = try container.decodeIfPresent(FinalGradeReview.self, forKey: .finalReview)
        exportRecords = (try? container.decode([ExportRecord].self, forKey: .exportRecords)) ?? []
        auditEvents = (try? container.decode([AuditEvent].self, forKey: .auditEvents)) ?? []
        evidenceReferences = (try? container.decode([EvidenceReference].self, forKey: .evidenceReferences)) ?? []
        curriculumMappings = (try? container.decode([CurriculumMapping].self, forKey: .curriculumMappings)) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(classGroupID, forKey: .classGroupID)
        try container.encodeIfPresent(studentID, forKey: .studentID)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(prompt, forKey: .prompt)
        try container.encode(subject, forKey: .subject)
        try container.encode(gradeLevel, forKey: .gradeLevel)
        try container.encode(assessmentPurpose, forKey: .assessmentPurpose)
        try container.encode(curriculumReference, forKey: .curriculumReference)
        try container.encode(className, forKey: .className)
        try container.encode(studentDisplayName, forKey: .studentDisplayName)
        try container.encode(assignmentType, forKey: .assignmentType)
        try container.encode(rubricText, forKey: .rubricText)
        try container.encode(customInstructions, forKey: .customInstructions)
        try container.encode(answerKeyText, forKey: .answerKeyText)
        try container.encode(exemplarText, forKey: .exemplarText)
        try container.encode(reviewedStudentText, forKey: .reviewedStudentText)
        try container.encode(sourceInputs, forKey: .sourceInputs)
        try container.encodeIfPresent(ocrDocument, forKey: .ocrDocument)
        try container.encode(ocrReviewStatus, forKey: .ocrReviewStatus)
        try container.encodeIfPresent(ocrReviewedAt, forKey: .ocrReviewedAt)
        try container.encodeIfPresent(latestDraft, forKey: .latestDraft)
        try container.encodeIfPresent(finalReview, forKey: .finalReview)
        try container.encode(exportRecords, forKey: .exportRecords)
        try container.encode(auditEvents, forKey: .auditEvents)
        try container.encode(evidenceReferences, forKey: .evidenceReferences)
        try container.encode(curriculumMappings, forKey: .curriculumMappings)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    var assignmentInputReady: Bool {
        gradingInput.isReadyForGrading
    }

    var hasGradingStandard: Bool {
        !rubricText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !answerKeyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !exemplarText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var parsedRubric: ParsedRubric {
        RubricParser.parse(rubricText)
    }

    var gradingPacketFingerprint: String {
        StableFingerprint.fingerprint([
            classGroupID?.uuidString ?? "",
            studentID?.uuidString ?? "",
            title,
            prompt ?? "",
            subject,
            gradeLevel,
            assessmentPurpose.rawValue,
            curriculumReference,
            assignmentType.rawValue,
            rubricText,
            customInstructions,
            answerKeyText,
            exemplarText,
            reviewedStudentText,
            ocrReviewStatus.rawValue,
            curriculumMappings.map { "\($0.curriculumItemID):\($0.mappingKind):\($0.rubricCriterionID ?? "")" }.joined(separator: "|"),
            evidenceReferences.map { "\($0.id.uuidString):\($0.sourceKind):\($0.quote):\($0.boundingBox?.stableDisplay ?? "")" }.joined(separator: "|"),
            sourceInputs.map { $0.contentDigest ?? $0.id.uuidString }.joined(separator: "|")
        ])
    }

    var latestDraftIsStale: Bool {
        guard let latestDraft else { return false }
        return latestDraft.packetFingerprint != gradingPacketFingerprint
    }

    var finalReviewIsStale: Bool {
        guard let finalReview else { return false }
        return finalReview.packetFingerprint != gradingPacketFingerprint
    }

    var requiresOCRReviewBeforeGrading: Bool {
        ocrReviewStatus == .needsReview || ocrReviewStatus == .blocked
    }

    var sourceReferencedReviewedText: String {
        guard let ocrDocument, !ocrDocument.pages.isEmpty else { return reviewedStudentText }
        return ocrDocument.pages.sorted { $0.pageIndex < $1.pageIndex }.flatMap { page in
            page.lines.enumerated().compactMap { offset, line in
                guard !line.isRejected, !line.reviewedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                return "[p\(page.pageIndex + 1)-l\(offset + 1)-\(line.id.uuidString.prefix(8))] \(line.reviewedText)"
            }
        }.joined(separator: "\n")
    }

    var gradingInput: GradingInput {
        GradingInput(
            assignmentID: id,
            assignmentTitle: title,
            prompt: prompt ?? "",
            subject: subject,
            gradeLevel: gradeLevel,
            className: className,
            studentDisplayName: studentDisplayName,
            assignmentType: assignmentType,
            rubricText: rubricText,
            parsedRubric: parsedRubric,
            customInstructions: customInstructions,
            answerKeyText: answerKeyText,
            exemplarText: exemplarText,
            assessmentPurpose: assessmentPurpose,
            curriculumReference: curriculumReference,
            reviewedStudentText: reviewedStudentText,
            reviewedTextWithSourceRefs: sourceReferencedReviewedText,
            ocrQualitySummary: ocrDocument?.qualitySummary ?? OCRQualitySummary(),
            ocrReviewStatus: ocrReviewStatus,
            sourceInputCount: sourceInputs.count,
            packetFingerprint: gradingPacketFingerprint,
            hasGradingStandard: hasGradingStandard
        )
    }

    mutating func appendAuditEvent(_ eventType: AuditEventType, detail: String) {
        auditEvents.append(AuditEvent(eventType: eventType, detail: detail))
    }
}

struct StudentRecord: Identifiable, Codable, Equatable {
    var id: UUID
    var displayName: String
    var className: String
    var localIdentifier: String
    var notes: String
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        displayName: String,
        className: String = "",
        localIdentifier: String = "",
        notes: String = "",
        isActive: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.className = className
        self.localIdentifier = localIdentifier
        self.notes = notes
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, displayName, className, localIdentifier, notes, isActive, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        displayName = (try? container.decode(String.self, forKey: .displayName)) ?? ""
        className = (try? container.decode(String.self, forKey: .className)) ?? ""
        localIdentifier = (try? container.decode(String.self, forKey: .localIdentifier)) ?? ""
        notes = (try? container.decode(String.self, forKey: .notes)) ?? ""
        isActive = (try? container.decode(Bool.self, forKey: .isActive)) ?? true
        createdAt = (try? container.decode(Date.self, forKey: .createdAt)) ?? Date()
        updatedAt = (try? container.decode(Date.self, forKey: .updatedAt)) ?? createdAt
    }
}

struct ClassGroupRecord: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var schoolYear: String
    var term: String
    var subject: String
    var gradeLevel: String
    var notes: String
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        schoolYear: String = "",
        term: String = "",
        subject: String = "",
        gradeLevel: String = "",
        notes: String = "",
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.schoolYear = schoolYear
        self.term = term
        self.subject = subject
        self.gradeLevel = gradeLevel
        self.notes = notes
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, schoolYear, term, subject, gradeLevel, notes, isArchived, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        name = (try? container.decode(String.self, forKey: .name)) ?? ""
        schoolYear = (try? container.decode(String.self, forKey: .schoolYear)) ?? ""
        term = (try? container.decode(String.self, forKey: .term)) ?? ""
        subject = (try? container.decode(String.self, forKey: .subject)) ?? ""
        gradeLevel = (try? container.decode(String.self, forKey: .gradeLevel)) ?? ""
        notes = (try? container.decode(String.self, forKey: .notes)) ?? ""
        isArchived = (try? container.decode(Bool.self, forKey: .isArchived)) ?? false
        createdAt = (try? container.decode(Date.self, forKey: .createdAt)) ?? Date()
        updatedAt = (try? container.decode(Date.self, forKey: .updatedAt)) ?? createdAt
    }
}

enum AssignmentRosterStatus: String, CaseIterable, Codable, Equatable, Identifiable {
    case notStarted
    case sourceNeeded
    case ocrReviewNeeded
    case readyForGrading
    case draftGenerated
    case finalReviewInProgress
    case approved
    case exported

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .notStarted: return "Not started"
        case .sourceNeeded: return "Source needed"
        case .ocrReviewNeeded: return "OCR review needed"
        case .readyForGrading: return "Ready for grading"
        case .draftGenerated: return "Draft generated"
        case .finalReviewInProgress: return "Final review in progress"
        case .approved: return "Approved"
        case .exported: return "Exported"
        }
    }
}

struct ClassStudentEnrollment: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var classGroupID: UUID
    var studentID: UUID
    var status: String = "active"
    var sortOrder: Int = 0
    var createdAt: Date = Date()
}

struct AssignmentRosterEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var assignmentID: UUID
    var studentID: UUID
    var studentDisplayName: String
    var localIdentifier: String
    var status: AssignmentRosterStatus
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        assignmentID: UUID,
        studentID: UUID,
        studentDisplayName: String,
        localIdentifier: String = "",
        status: AssignmentRosterStatus = .notStarted,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.assignmentID = assignmentID
        self.studentID = studentID
        self.studentDisplayName = studentDisplayName
        self.localIdentifier = localIdentifier
        self.status = status
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct StudentWorkRecord: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var assignmentID: UUID
    var studentID: UUID?
    var legacyAssignmentRecordID: UUID?
    var reviewedStudentText: String
    var ocrReviewStatus: OCRReviewStatus
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}

struct RosterRejectedRow: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var rowNumber: Int
    var rawText: String
    var reason: String
}

struct RosterImportPreview: Codable, Equatable {
    var className: String
    var students: [StudentRecord]
    var duplicateNames: [String]
    var rejectedRows: [String]
    var rejectedRowDetails: [RosterRejectedRow]
    var warnings: [String]
    var hasHeaderRow: Bool

    init(
        className: String = "",
        students: [StudentRecord] = [],
        duplicateNames: [String] = [],
        rejectedRows: [String] = [],
        rejectedRowDetails: [RosterRejectedRow] = [],
        warnings: [String] = [],
        hasHeaderRow: Bool = false
    ) {
        self.className = className
        self.students = students
        self.duplicateNames = duplicateNames
        self.rejectedRows = rejectedRows
        self.rejectedRowDetails = rejectedRowDetails
        self.warnings = warnings
        self.hasHeaderRow = hasHeaderRow
    }
}

struct CurriculumSource: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var version: String
    var provenance: String
    var localPath: String
    var importedAt: Date = Date()
}

struct CurriculumItem: Identifiable, Codable, Equatable {
    var id: String
    var source: String
    var version: String
    var learningArea: String
    var subject: String
    var yearLevel: String
    var strand: String
    var organizer: String
    var itemType: String
    var code: String
    var title: String
    var shortDescription: String
    var sourceURL: String
    var provenance: String

    init(
        id: String,
        source: String,
        version: String,
        learningArea: String,
        subject: String,
        yearLevel: String,
        strand: String = "",
        organizer: String = "",
        itemType: String,
        code: String,
        title: String,
        shortDescription: String,
        sourceURL: String,
        provenance: String = ""
    ) {
        self.id = id
        self.source = source
        self.version = version
        self.learningArea = learningArea
        self.subject = subject
        self.yearLevel = yearLevel
        self.strand = strand
        self.organizer = organizer
        self.itemType = itemType
        self.code = code
        self.title = title
        self.shortDescription = shortDescription
        self.sourceURL = sourceURL
        self.provenance = provenance
    }

    private enum CodingKeys: String, CodingKey {
        case id, source, version, learningArea, subject, yearLevel, strand, organizer, itemType, code, title, shortDescription, sourceURL, provenance
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        source = try container.decode(String.self, forKey: .source)
        version = try container.decode(String.self, forKey: .version)
        learningArea = try container.decode(String.self, forKey: .learningArea)
        subject = try container.decode(String.self, forKey: .subject)
        yearLevel = try container.decode(String.self, forKey: .yearLevel)
        strand = (try? container.decode(String.self, forKey: .strand)) ?? ""
        organizer = (try? container.decode(String.self, forKey: .organizer)) ?? ""
        itemType = try container.decode(String.self, forKey: .itemType)
        code = try container.decode(String.self, forKey: .code)
        title = try container.decode(String.self, forKey: .title)
        shortDescription = try container.decode(String.self, forKey: .shortDescription)
        sourceURL = try container.decode(String.self, forKey: .sourceURL)
        provenance = (try? container.decode(String.self, forKey: .provenance)) ?? sourceURL
    }
}

struct CurriculumCatalog: Codable, Equatable {
    var sources: [CurriculumSource]
    var items: [CurriculumItem]
    var warning: String

    func filtered(learningArea: String = "", subject: String = "", yearLevel: String = "", searchText: String = "") -> [CurriculumItem] {
        let normalizedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return items.filter { item in
            let learningAreaMatch = learningArea.isEmpty || item.learningArea.localizedCaseInsensitiveContains(learningArea)
            let subjectMatch = subject.isEmpty || item.subject.localizedCaseInsensitiveContains(subject)
            let yearLevelMatch = yearLevel.isEmpty || item.yearLevel.localizedCaseInsensitiveContains(yearLevel)
            let searchMatch = normalizedSearch.isEmpty || [item.code, item.title, item.shortDescription, item.learningArea, item.subject]
                .joined(separator: " ")
                .lowercased()
                .contains(normalizedSearch)
            return learningAreaMatch && subjectMatch && yearLevelMatch && searchMatch
        }
    }
}

struct CurriculumMapping: Identifiable, Codable, Equatable {
    var id: UUID
    var curriculumItemID: String
    var mappingKind: String
    var rubricCriterionID: String?
    var evidenceReferenceID: UUID?
    var teacherSelected: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        curriculumItemID: String,
        mappingKind: String,
        rubricCriterionID: String? = nil,
        evidenceReferenceID: UUID? = nil,
        teacherSelected: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.curriculumItemID = curriculumItemID
        self.mappingKind = mappingKind
        self.rubricCriterionID = rubricCriterionID
        self.evidenceReferenceID = evidenceReferenceID
        self.teacherSelected = teacherSelected
        self.createdAt = createdAt
    }
}

struct EvidenceReference: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var sourceInputID: UUID?
    var ocrLineID: UUID?
    var pageIndex: Int?
    var quote: String
    var startOffset: Int?
    var endOffset: Int?
    var boundingBox: NormalizedRect?
    var sourceKind: String
    var teacherConfirmed: Bool
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        sourceInputID: UUID? = nil,
        ocrLineID: UUID? = nil,
        pageIndex: Int? = nil,
        quote: String,
        startOffset: Int? = nil,
        endOffset: Int? = nil,
        boundingBox: NormalizedRect? = nil,
        sourceKind: String,
        teacherConfirmed: Bool,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceInputID = sourceInputID
        self.ocrLineID = ocrLineID
        self.pageIndex = pageIndex
        self.quote = quote
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.boundingBox = boundingBox
        self.sourceKind = sourceKind
        self.teacherConfirmed = teacherConfirmed
        self.createdAt = createdAt
    }

    var displaySource: String {
        let page = pageIndex.map { "page \($0 + 1)" } ?? "reviewed text"
        if let ocrLineID { return "\(page), OCR line \(ocrLineID.uuidString.prefix(8))" }
        return page
    }
}

struct BackupArchiveManifest: Codable, Equatable {
    var archiveID: UUID = UUID()
    var archiveKind: String
    var schemaVersion: String = "gradedraft-backup-v3"
    var createdAt: Date = Date()
    var includesStudentData: Bool = true
    var includesPrivateTeacherNotes: Bool
    var includesOriginalSources: Bool
    var sourceFileCount: Int
    var recordCounts: [String: Int]
    var contentHashes: [String: String]
    var restoreCompatibility: String = "Compatible with GradeDraft local backup restore v3 when schemaVersion begins with gradedraft-backup-v."
}

enum BackupConflictResolution: String, CaseIterable, Codable, Equatable, Identifiable {
    case keepLocal
    case replaceLocal
    case restoreAsCopy

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .keepLocal: return "Keep local"
        case .replaceLocal: return "Replace local"
        case .restoreAsCopy: return "Restore as copy"
        }
    }
}

struct BackupRestorePreview: Codable, Equatable {
    var archiveKind: String
    var schemaVersion: String
    var assignmentCount: Int
    var classCount: Int
    var studentCount: Int
    var sourceFileCount: Int
    var conflictAssignmentIDs: [UUID]
    var warnings: [String]

    var summary: String {
        "Backup contains \(assignmentCount) assignment(s), \(classCount) class(es), \(studentCount) student(s), and \(sourceFileCount) source file(s); \(conflictAssignmentIDs.count) conflict(s) detected."
    }
}

enum AssignmentType: String, CaseIterable, Codable, Identifiable {
    case shortAnswer
    case essay
    case paragraphResponse
    case labWriteup
    case readingComprehension

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .shortAnswer:
            return "Short answer"
        case .essay:
            return "Essay"
        case .paragraphResponse:
            return "Paragraph response"
        case .labWriteup:
            return "Lab write-up"
        case .readingComprehension:
            return "Reading comprehension"
        }
    }
}

enum AssessmentPurpose: String, CaseIterable, Codable, Equatable, Identifiable {
    case formative
    case summative
    case practice
    case diagnostic
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .formative:
            return "Formative"
        case .summative:
            return "Summative"
        case .practice:
            return "Practice"
        case .diagnostic:
            return "Diagnostic"
        case .other:
            return "Other"
        }
    }
}

// MARK: - Source input and OCR records

enum SourceType: String, CaseIterable, Codable, Identifiable {
    case pastedText
    case scan
    case photo
    case pdf
    case handwrittenWork
    case visualArtifact

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pastedText:
            return "Pasted text"
        case .scan:
            return "Document scan"
        case .photo:
            return "Imported photo"
        case .pdf:
            return "PDF"
        case .handwrittenWork:
            return "Handwritten work"
        case .visualArtifact:
            return "Visual artifact"
        }
    }
}

struct SourceInputRef: Identifiable, Codable, Equatable {
    var id: UUID
    var sourceType: SourceType
    var pageIndex: Int?
    var localRelativePath: String?
    var fileName: String?
    var mimeType: String?
    var contentDigest: String?
    var digestAlgorithm: String?
    var imageWidth: Double?
    var imageHeight: Double?
    var pdfPageCount: Int?
    var teacherIncludedInExport: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        sourceType: SourceType,
        pageIndex: Int? = nil,
        localRelativePath: String? = nil,
        fileName: String? = nil,
        mimeType: String? = nil,
        contentDigest: String? = nil,
        digestAlgorithm: String? = nil,
        imageWidth: Double? = nil,
        imageHeight: Double? = nil,
        pdfPageCount: Int? = nil,
        teacherIncludedInExport: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceType = sourceType
        self.pageIndex = pageIndex
        self.localRelativePath = localRelativePath
        self.fileName = fileName
        self.mimeType = mimeType
        self.contentDigest = contentDigest
        self.digestAlgorithm = digestAlgorithm
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.pdfPageCount = pdfPageCount
        self.teacherIncludedInExport = teacherIncludedInExport
        self.createdAt = createdAt
    }
}

enum OCRReviewStatus: String, CaseIterable, Codable, Identifiable {
    case notNeeded
    case needsReview
    case reviewed
    case blocked

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .notNeeded:
            return "No OCR review needed"
        case .needsReview:
            return "Needs OCR review"
        case .reviewed:
            return "OCR reviewed"
        case .blocked:
            return "OCR blocked"
        }
    }

    var blocksGrading: Bool {
        self == .needsReview || self == .blocked
    }
}

struct OCRDocument: Identifiable, Codable, Equatable {
    var id: UUID
    var engine: String
    var engineVersion: String
    var pages: [OCRPage]
    var createdAt: Date
    var reviewStatus: OCRReviewStatus
    var reviewedAt: Date?

    init(
        id: UUID = UUID(),
        engine: String = "Apple Vision",
        engineVersion: String = "system",
        pages: [OCRPage],
        createdAt: Date = Date(),
        reviewStatus: OCRReviewStatus = .needsReview,
        reviewedAt: Date? = nil
    ) {
        self.id = id
        self.engine = engine
        self.engineVersion = engineVersion
        self.pages = pages
        self.createdAt = createdAt
        self.reviewStatus = reviewStatus
        self.reviewedAt = reviewedAt
    }

    var rawCombinedText: String {
        pages
            .sorted { $0.pageIndex < $1.pageIndex }
            .map { $0.lines.map(\.rawText).joined(separator: "\n") }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")
    }

    var combinedText: String {
        pages
            .sorted { $0.pageIndex < $1.pageIndex }
            .map { page in
                page.lines
                    .filter { !$0.isRejected }
                    .map(\.reviewedText)
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    .joined(separator: "\n")
            }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")
    }

    var allLines: [OCRLine] {
        pages.flatMap(\.lines)
    }

    var activeLines: [OCRLine] {
        allLines.filter { !$0.isRejected }
    }

    var hasLowConfidenceText: Bool {
        activeLines.contains { $0.confidence < OCRQualitySummary.lowConfidenceThreshold }
    }

    var hasUnconfirmedLines: Bool {
        activeLines.contains { !$0.teacherConfirmed }
    }

    var unresolvedLineCount: Int {
        activeLines.filter { $0.needsReview }.count
    }

    var qualitySummary: OCRQualitySummary {
        OCRQualitySummary(lines: allLines)
    }

    func markingAllLinesConfirmed(reviewedAt: Date = Date()) -> OCRDocument {
        var copy = self
        copy.reviewStatus = .reviewed
        copy.reviewedAt = reviewedAt
        copy.pages = copy.pages.map { page in
            var page = page
            page.lines = page.lines.map { line in
                var line = line
                if !line.isRejected {
                    line.teacherConfirmed = true
                }
                return line
            }
            return page
        }
        return copy
    }

    func pageReviewStatus(pageID: UUID) -> OCRReviewStatus {
        guard let page = pages.first(where: { $0.id == pageID }) else { return .blocked }
        return page.lines.filter { !$0.isRejected }.contains { !$0.teacherConfirmed } ? .needsReview : .reviewed
    }
}

struct OCRPage: Identifiable, Codable, Equatable {
    var id: UUID
    var sourceInputID: UUID?
    var pageIndex: Int
    var imageWidth: Double?
    var imageHeight: Double?
    var lines: [OCRLine]

    init(
        id: UUID = UUID(),
        sourceInputID: UUID? = nil,
        pageIndex: Int,
        imageWidth: Double? = nil,
        imageHeight: Double? = nil,
        lines: [OCRLine]
    ) {
        self.id = id
        self.sourceInputID = sourceInputID
        self.pageIndex = pageIndex
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.lines = lines
    }

    var unresolvedLineCount: Int {
        lines.filter { $0.needsReview }.count
    }
}

struct OCRLine: Identifiable, Codable, Equatable {
    var id: UUID
    var rawText: String
    var correctedText: String?
    var confidence: Float
    var boundingBox: NormalizedRect
    var teacherConfirmed: Bool
    var isRejected: Bool

    init(
        id: UUID = UUID(),
        text: String,
        confidence: Float,
        boundingBox: NormalizedRect,
        correctedText: String? = nil,
        teacherConfirmed: Bool = false,
        isRejected: Bool = false
    ) {
        self.id = id
        self.rawText = text
        self.correctedText = correctedText
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.teacherConfirmed = teacherConfirmed
        self.isRejected = isRejected
    }

    private enum CodingKeys: String, CodingKey {
        case id, rawText, correctedText, confidence, boundingBox, teacherConfirmed, isRejected
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        rawText = try container.decode(String.self, forKey: .rawText)
        correctedText = try container.decodeIfPresent(String.self, forKey: .correctedText)
        confidence = try container.decode(Float.self, forKey: .confidence)
        boundingBox = try container.decode(NormalizedRect.self, forKey: .boundingBox)
        teacherConfirmed = try container.decode(Bool.self, forKey: .teacherConfirmed)
        isRejected = (try? container.decode(Bool.self, forKey: .isRejected)) ?? false
    }

    var text: String {
        reviewedText
    }

    var reviewedText: String {
        guard !isRejected else { return "" }
        let corrected = correctedText?.trimmingCharacters(in: .whitespacesAndNewlines)
        return corrected?.isEmpty == false ? corrected! : rawText
    }

    var needsReview: Bool {
        guard !isRejected else { return false }
        return confidence < OCRQualitySummary.lowConfidenceThreshold || !teacherConfirmed
    }

    var reviewStatusLabel: String {
        if isRejected { return "rejected" }
        if teacherConfirmed { return correctedText == nil ? "confirmed" : "corrected" }
        if correctedText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true { return "blockedFromGrading" }
        return "unreviewed"
    }
}

struct OCRQualitySummary: Codable, Equatable {
    static let lowConfidenceThreshold: Float = 0.70

    var lineCount: Int
    var lowConfidenceLineCount: Int
    var unconfirmedLineCount: Int
    var averageConfidence: Float
    var minimumConfidence: Float?
    var rejectedLineCount: Int

    init(
        lineCount: Int = 0,
        lowConfidenceLineCount: Int = 0,
        unconfirmedLineCount: Int = 0,
        averageConfidence: Float = 0,
        minimumConfidence: Float? = nil,
        rejectedLineCount: Int = 0
    ) {
        self.lineCount = lineCount
        self.lowConfidenceLineCount = lowConfidenceLineCount
        self.unconfirmedLineCount = unconfirmedLineCount
        self.averageConfidence = averageConfidence
        self.minimumConfidence = minimumConfidence
        self.rejectedLineCount = rejectedLineCount
    }

    private enum CodingKeys: String, CodingKey {
        case lineCount, lowConfidenceLineCount, unconfirmedLineCount, averageConfidence, minimumConfidence, rejectedLineCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lineCount = try container.decode(Int.self, forKey: .lineCount)
        lowConfidenceLineCount = try container.decode(Int.self, forKey: .lowConfidenceLineCount)
        unconfirmedLineCount = try container.decode(Int.self, forKey: .unconfirmedLineCount)
        averageConfidence = try container.decode(Float.self, forKey: .averageConfidence)
        minimumConfidence = try container.decodeIfPresent(Float.self, forKey: .minimumConfidence)
        rejectedLineCount = (try? container.decode(Int.self, forKey: .rejectedLineCount)) ?? 0
    }

    init(lines: [OCRLine]) {
        rejectedLineCount = lines.filter(\.isRejected).count
        let activeLines = lines.filter { !$0.isRejected }
        lineCount = activeLines.count
        lowConfidenceLineCount = activeLines.filter { $0.confidence < Self.lowConfidenceThreshold }.count
        unconfirmedLineCount = activeLines.filter { !$0.teacherConfirmed }.count
        if activeLines.isEmpty {
            averageConfidence = 0
            minimumConfidence = nil
        } else {
            averageConfidence = activeLines.map(\.confidence).reduce(0, +) / Float(activeLines.count)
            minimumConfidence = activeLines.map(\.confidence).min()
        }
    }

    var requiresTeacherOCRReview: Bool {
        lowConfidenceLineCount > 0 || unconfirmedLineCount > 0
    }

    var displaySummary: String {
        guard lineCount > 0 || rejectedLineCount > 0 else {
            return "No OCR text has been captured."
        }
        let average = Int((averageConfidence * 100).rounded())
        let rejectedText = rejectedLineCount > 0 ? " \(rejectedLineCount) rejected line(s) excluded from reviewed text." : ""
        if lowConfidenceLineCount == 0 && unconfirmedLineCount == 0 {
            return "OCR captured \(lineCount) confirmed text line(s) with average confidence \(average)%.\(rejectedText)"
        }
        return "OCR captured \(lineCount) text line(s); \(lowConfidenceLineCount) low-confidence and \(unconfirmedLineCount) unconfirmed. Average confidence \(average)%.\(rejectedText)"
    }
}

// swiftlint:disable identifier_name
struct NormalizedRect: Codable, Equatable {
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat

    static let zero = NormalizedRect(x: 0, y: 0, width: 0, height: 0)

    var stableDisplay: String {
        "x:\(Self.format(x)) y:\(Self.format(y)) w:\(Self.format(width)) h:\(Self.format(height))"
    }

    private static func format(_ value: CGFloat) -> String {
        String(format: "%.4f", Double(value))
    }
}
// swiftlint:enable identifier_name

// MARK: - Rubric records

struct ParsedRubric: Codable, Equatable {
    var criteria: [RubricCriterion]
    var issues: [String]
    var groups: [String]

    init(criteria: [RubricCriterion] = [], issues: [String] = [], groups: [String] = []) {
        self.criteria = criteria
        self.issues = issues
        self.groups = groups
    }

    private enum CodingKeys: String, CodingKey {
        case criteria, issues, groups
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        criteria = (try? container.decode([RubricCriterion].self, forKey: .criteria)) ?? []
        issues = (try? container.decode([String].self, forKey: .issues)) ?? []
        groups = (try? container.decode([String].self, forKey: .groups)) ?? []
    }

    var isStructured: Bool {
        !criteria.isEmpty
    }
}

struct RubricCriterion: Identifiable, Codable, Equatable {
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

    private enum CodingKeys: String, CodingKey {
        case id, title, maxPoints, descriptor, sortOrder, groupTitle, levels, explicitID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        maxPoints = try container.decode(Double.self, forKey: .maxPoints)
        descriptor = try container.decode(String.self, forKey: .descriptor)
        sortOrder = try container.decode(Int.self, forKey: .sortOrder)
        groupTitle = try container.decodeIfPresent(String.self, forKey: .groupTitle)
        levels = (try? container.decode([RubricLevel].self, forKey: .levels)) ?? []
        explicitID = try container.decodeIfPresent(String.self, forKey: .explicitID)
    }
}

struct RubricLevel: Identifiable, Codable, Equatable {
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

    private enum CodingKeys: String, CodingKey {
        case id, label, points, minPoints, maxPoints, descriptor, sortOrder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        label = try container.decode(String.self, forKey: .label)
        points = try container.decode(Double.self, forKey: .points)
        minPoints = try container.decodeIfPresent(Double.self, forKey: .minPoints)
        maxPoints = try container.decodeIfPresent(Double.self, forKey: .maxPoints)
        descriptor = try container.decode(String.self, forKey: .descriptor)
        sortOrder = try container.decode(Int.self, forKey: .sortOrder)
    }
}

struct RubricParseIssue: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var severity: String
    var message: String
    var lineNumber: Int?
}

struct RubricImportPreview: Codable, Equatable {
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
        "criterion-\(order + 1)-\(StableFingerprint.fingerprint([title, String(maxPoints)]).suffix(8))"
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

// MARK: - Grading records

struct GradingInput: Codable, Equatable {
    var assignmentID: UUID
    var assignmentTitle: String
    var prompt: String
    var subject: String
    var gradeLevel: String
    var className: String
    var studentDisplayName: String
    var assignmentType: AssignmentType
    var rubricText: String
    var parsedRubric: ParsedRubric
    var customInstructions: String
    var answerKeyText: String
    var exemplarText: String
    var assessmentPurpose: AssessmentPurpose
    var curriculumReference: String
    var reviewedStudentText: String
    var reviewedTextWithSourceRefs: String
    var ocrQualitySummary: OCRQualitySummary
    var ocrReviewStatus: OCRReviewStatus
    var sourceInputCount: Int
    var packetFingerprint: String
    var hasGradingStandard: Bool

    var isReadyForGrading: Bool {
        hasGradingStandard &&
        !reviewedStudentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !ocrReviewStatus.blocksGrading
    }
}

enum DraftStatus: String, Codable, Equatable {
    case generated
    case stale
    case teacherReviewRequired
}

struct GradeDraftResult: Identifiable, Codable, Equatable {
    var id: UUID
    var generatedAt: Date
    var packetFingerprint: String
    var status: DraftStatus
    var studentResponseSummary: String
    var criteria: [CriterionScore]
    var totalScore: Double
    var maxScore: Double
    var studentFeedback: String
    var teacherNotes: String
    var uncertaintyFlags: [String]
    var complianceFlags: [String]
    var rawModelResponse: String?

    init(
        id: UUID = UUID(),
        generatedAt: Date = Date(),
        packetFingerprint: String = "",
        status: DraftStatus = .teacherReviewRequired,
        studentResponseSummary: String,
        criteria: [CriterionScore],
        totalScore: Double,
        maxScore: Double,
        studentFeedback: String,
        teacherNotes: String,
        uncertaintyFlags: [String],
        complianceFlags: [String] = [],
        rawModelResponse: String? = nil
    ) {
        self.id = id
        self.generatedAt = Date(timeIntervalSinceReferenceDate: floor(generatedAt.timeIntervalSinceReferenceDate * 1000) / 1000)
        self.packetFingerprint = packetFingerprint
        self.status = status
        self.studentResponseSummary = studentResponseSummary
        self.criteria = criteria
        self.totalScore = totalScore
        self.maxScore = maxScore
        self.studentFeedback = studentFeedback
        self.teacherNotes = teacherNotes
        self.uncertaintyFlags = uncertaintyFlags
        self.complianceFlags = complianceFlags
        self.rawModelResponse = rawModelResponse
    }
}

struct CriterionScore: Identifiable, Codable, Equatable {
    var id: UUID
    var criterionID: String?
    var criterion: String
    var rating: String
    var proposedPoints: Double
    var maxPoints: Double
    var evidence: [String]
    var evidenceSourceRefs: [String]
    var explanation: String
    var teacherReviewRequired: Bool
    var nextStep: String
    var confidence: String
    var criterionUncertaintyFlags: [String]

    init(
        id: UUID = UUID(),
        criterionID: String? = nil,
        criterion: String,
        rating: String,
        proposedPoints: Double,
        maxPoints: Double,
        evidence: [String],
        evidenceSourceRefs: [String] = [],
        explanation: String,
        teacherReviewRequired: Bool,
        nextStep: String = "",
        confidence: String = "",
        criterionUncertaintyFlags: [String] = []
    ) {
        self.id = id
        self.criterionID = criterionID
        self.criterion = criterion
        self.rating = rating
        self.proposedPoints = proposedPoints
        self.maxPoints = maxPoints
        self.evidence = evidence
        self.evidenceSourceRefs = evidenceSourceRefs
        self.explanation = explanation
        self.teacherReviewRequired = teacherReviewRequired
        self.nextStep = nextStep
        self.confidence = confidence
        self.criterionUncertaintyFlags = criterionUncertaintyFlags
    }
}

enum FinalReviewStatus: String, Codable, Equatable {
    case inProgress
    case approved
    case stale
}

struct FinalGradeReview: Identifiable, Codable, Equatable {
    var id: UUID
    var createdAt: Date
    var finalizedAt: Date?
    var packetFingerprint: String
    var status: FinalReviewStatus
    var criteria: [FinalCriterionScore]
    var totalScore: Double
    var maxScore: Double
    var studentFeedback: String
    var privateTeacherNotes: String
    var teacherEdited: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        finalizedAt: Date? = nil,
        packetFingerprint: String = "",
        status: FinalReviewStatus = .inProgress,
        criteria: [FinalCriterionScore],
        totalScore: Double,
        maxScore: Double,
        studentFeedback: String,
        privateTeacherNotes: String,
        teacherEdited: Bool
    ) {
        self.id = id
        self.createdAt = createdAt
        self.finalizedAt = finalizedAt
        self.packetFingerprint = packetFingerprint
        self.status = status
        self.criteria = criteria
        self.totalScore = totalScore
        self.maxScore = maxScore
        self.studentFeedback = studentFeedback
        self.privateTeacherNotes = privateTeacherNotes
        self.teacherEdited = teacherEdited
    }

    var allCriteriaApproved: Bool {
        !criteria.isEmpty && criteria.allSatisfy(\.teacherApproved)
    }
}

struct FinalCriterionScore: Identifiable, Codable, Equatable {
    var id: UUID
    var criterionID: String?
    var criterion: String
    var rating: String
    var proposedPoints: Double
    var finalPoints: Double
    var maxPoints: Double
    var evidence: [String]
    var evidenceSourceRefs: [String]?
    var explanation: String
    var teacherApproved: Bool
    var teacherRationale: String

    init(
        id: UUID = UUID(),
        criterionID: String? = nil,
        criterion: String,
        rating: String,
        proposedPoints: Double,
        finalPoints: Double,
        maxPoints: Double,
        evidence: [String],
        evidenceSourceRefs: [String]? = nil,
        explanation: String,
        teacherApproved: Bool = false,
        teacherRationale: String = ""
    ) {
        self.id = id
        self.criterionID = criterionID
        self.criterion = criterion
        self.rating = rating
        self.proposedPoints = proposedPoints
        self.finalPoints = finalPoints
        self.maxPoints = maxPoints
        self.evidence = evidence
        self.evidenceSourceRefs = evidenceSourceRefs
        self.explanation = explanation
        self.teacherApproved = teacherApproved
        self.teacherRationale = teacherRationale
    }

    init(from draft: CriterionScore) {
        self.init(
            criterionID: draft.criterionID,
            criterion: draft.criterion,
            rating: draft.rating,
            proposedPoints: draft.proposedPoints,
            finalPoints: draft.proposedPoints,
            maxPoints: draft.maxPoints,
            evidence: draft.evidence,
            evidenceSourceRefs: draft.evidenceSourceRefs,
            explanation: draft.explanation,
            teacherApproved: false,
            teacherRationale: draft.teacherReviewRequired ? "Review required by draft." : ""
        )
    }
}

// MARK: - Export and audit

enum ExportKind: String, Codable, Equatable, Identifiable {
    case studentMarkdown
    case teacherAuditMarkdown
    case studentPDF
    case teacherAuditPDF
    case csvGradebook
    case zipArchive
    case fullBackupArchive
    case backupJSON

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .studentMarkdown:
            return "Student Markdown report"
        case .teacherAuditMarkdown:
            return "Teacher audit Markdown report"
        case .studentPDF:
            return "Student PDF report"
        case .teacherAuditPDF:
            return "Teacher audit PDF report"
        case .csvGradebook:
            return "CSV grade summary"
        case .zipArchive:
            return "Teacher archive ZIP"
        case .fullBackupArchive:
            return "Full local backup archive"
        case .backupJSON:
            return "Local JSON backup"
        }
    }
}

struct ExportRecord: Identifiable, Codable, Equatable {
    var id: UUID
    var exportKind: ExportKind
    var createdAt: Date
    var contentFingerprint: String
    var includesPrivateTeacherNotes: Bool
    var includesOriginalSources: Bool

    init(
        id: UUID = UUID(),
        exportKind: ExportKind,
        createdAt: Date = Date(),
        contentFingerprint: String,
        includesPrivateTeacherNotes: Bool,
        includesOriginalSources: Bool
    ) {
        self.id = id
        self.exportKind = exportKind
        self.createdAt = createdAt
        self.contentFingerprint = contentFingerprint
        self.includesPrivateTeacherNotes = includesPrivateTeacherNotes
        self.includesOriginalSources = includesOriginalSources
    }
}

enum AuditEventType: String, Codable, Equatable {
    case assignmentCreated
    case sourceCaptured
    case ocrCompleted
    case ocrReviewed
    case inputChanged
    case draftGenerated
    case draftMarkedStale
    case finalReviewStarted
    case finalApproved
    case exportPrepared
    case persistenceSaved
}

struct AuditEvent: Identifiable, Codable, Equatable {
    var id: UUID
    var timestamp: Date
    var eventType: AuditEventType
    var actor: String
    var detail: String

    init(id: UUID = UUID(), timestamp: Date = Date(), eventType: AuditEventType, actor: String = "teacher-or-local-system", detail: String) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.actor = actor
        self.detail = detail
    }
}

// MARK: - Templates and errors

struct RubricTemplate: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var assignmentType: AssignmentType
    var assessmentPurpose: AssessmentPurpose
    var description: String
    var rubricText: String
    var customInstructions: String
}

enum RubricTemplates {
    static let builtIn: [RubricTemplate] = [
        RubricTemplate(
            id: "short-answer-4pt",
            name: "4-point short answer",
            assignmentType: .shortAnswer,
            assessmentPurpose: .summative,
            description: "Fast rubric for constructed responses and exit tickets.",
            rubricText: """
            Claim / direct answer: 0-1 point
            - 1: directly answers the question or makes a clear claim.
            - 0: does not answer the question or is off topic.

            Evidence / support: 0-2 points
            - 2: includes accurate, relevant evidence or details.
            - 1: includes partial, vague, or minimally relevant evidence.
            - 0: includes no relevant evidence.

            Explanation: 0-1 point
            - 1: explains how the evidence supports the answer.
            - 0: gives evidence without explanation or has no explanation.
            """,
            customInstructions: "Do not penalize spelling, grammar, or handwriting unless they materially interfere with meaning. Award equivalent wording when the meaning is correct. Cite the reviewed student text for each criterion or mark teacher review required."
        ),
        RubricTemplate(
            id: "paragraph-response-8pt",
            name: "8-point paragraph response",
            assignmentType: .paragraphResponse,
            assessmentPurpose: .summative,
            description: "Claim, evidence, reasoning, and clarity for one-paragraph responses.",
            rubricText: """
            Clear claim/topic sentence: 0-2 points
            - 2: clear, focused claim that answers the prompt.
            - 1: claim is present but vague, incomplete, or only partly responsive.
            - 0: no clear claim.

            Relevant evidence: 0-2 points
            - 2: at least two accurate and relevant details, examples, or quotations.
            - 1: one relevant detail or partially relevant evidence.
            - 0: no relevant evidence.

            Reasoning/explanation: 0-2 points
            - 2: clearly explains how the evidence supports the claim.
            - 1: explanation is present but underdeveloped.
            - 0: no reasoning or explanation.

            Organization and clarity: 0-2 points
            - 2: coherent, complete paragraph with logical flow.
            - 1: understandable but choppy, repetitive, or incomplete.
            - 0: difficult to follow or not written as a response.
            """,
            customInstructions: "Keep feedback specific and actionable. Do not invent missing evidence. If OCR quality is uncertain, flag teacher review. Do not make claims about student effort, ability, or intent."
        ),
        RubricTemplate(
            id: "essay-20pt",
            name: "20-point essay",
            assignmentType: .essay,
            assessmentPurpose: .summative,
            description: "General essay rubric for claim, structure, evidence, analysis, and conventions.",
            rubricText: """
            Thesis/claim: 0-4 points
            - 4: clear, precise, and responsive thesis or controlling claim.
            - 3: clear claim with minor limitation or lack of precision.
            - 2: partially responsive, vague, or inconsistent claim.
            - 1: minimal or unclear claim.
            - 0: no discernible claim or off-topic response.

            Evidence: 0-4 points
            - 4: accurate, relevant, and sufficient evidence throughout.
            - 3: mostly relevant evidence with minor gaps.
            - 2: some relevant evidence but insufficient, vague, or uneven.
            - 1: minimal evidence.
            - 0: no relevant evidence.

            Analysis/reasoning: 0-4 points
            - 4: consistently explains how evidence supports the claim.
            - 3: generally explains evidence with minor gaps.
            - 2: some explanation, but reasoning is underdeveloped.
            - 1: minimal explanation or mostly summary.
            - 0: no analysis or reasoning.

            Organization: 0-4 points
            - 4: logical structure with effective transitions and paragraphing.
            - 3: organized overall with minor lapses.
            - 2: uneven organization that sometimes disrupts meaning.
            - 1: limited organization.
            - 0: disorganized or not developed as an essay.

            Language/conventions: 0-4 points
            - 4: clear language and conventions support meaning.
            - 3: minor errors that do not interfere with meaning.
            - 2: errors or awkward language sometimes interfere with meaning.
            - 1: frequent errors make meaning difficult.
            - 0: conventions or language prevent reliable understanding.
            """,
            customInstructions: "Use the rubric criteria exactly. The draft grade must cite text evidence for each criterion. Do not reward length alone. Do not infer effort, ability, or intent. Mark teacher review required when evidence is missing or when the rubric descriptor is ambiguous."
        ),
        RubricTemplate(
            id: "lab-writeup-16pt",
            name: "16-point lab write-up",
            assignmentType: .labWriteup,
            assessmentPurpose: .summative,
            description: "For written science reports, lab reflections, and conclusions.",
            rubricText: """
            Question / purpose: 0-2 points
            - 2: clearly states the investigation question or purpose.
            - 1: states a partial or vague question/purpose.
            - 0: missing or unrelated.

            Hypothesis or prediction: 0-2 points
            - 2: gives a testable hypothesis or prediction linked to the investigation.
            - 1: gives a prediction that is vague, incomplete, or weakly linked.
            - 0: missing or unrelated.

            Method / procedure summary: 0-3 points
            - 3: accurately summarizes the relevant procedure or variables.
            - 2: mostly accurate but missing a meaningful detail.
            - 1: minimal or unclear method description.
            - 0: missing or inaccurate.

            Data / observations: 0-3 points
            - 3: includes relevant data or observations and identifies patterns.
            - 2: includes some relevant data or observations.
            - 1: includes minimal or unclear data/observations.
            - 0: missing.

            Conclusion: 0-3 points
            - 3: answers the question and connects to the data.
            - 2: answers the question with limited data connection.
            - 1: gives a weak or unsupported conclusion.
            - 0: missing or unrelated.

            Scientific reasoning: 0-3 points
            - 3: explains why the data support the conclusion using appropriate scientific ideas.
            - 2: gives some scientific reasoning with gaps.
            - 1: minimal or unclear reasoning.
            - 0: no scientific reasoning.
            """,
            customInstructions: "Grade only the written content provided. Do not infer experimental performance beyond the text. Flag missing data, unclear vocabulary, diagram dependence, or unsupported scientific claims for teacher review."
        ),
        RubricTemplate(
            id: "reading-comprehension-10pt",
            name: "10-point reading comprehension response",
            assignmentType: .readingComprehension,
            assessmentPurpose: .summative,
            description: "For text-based responses to a reading prompt.",
            rubricText: """
            Direct answer: 0-2 points
            - 2: answers the question accurately and completely.
            - 1: partially answers the question or is somewhat accurate.
            - 0: does not answer the question or is inaccurate.

            Text evidence: 0-3 points
            - 3: cites or describes accurate, relevant evidence from the text.
            - 2: includes relevant but limited or partially explained evidence.
            - 1: includes vague, weak, or minimally relevant evidence.
            - 0: includes no relevant evidence.

            Inference/explanation: 0-3 points
            - 3: clearly explains how the evidence supports the answer or inference.
            - 2: provides some explanation with minor gaps.
            - 1: explanation is minimal, unclear, or mostly restates evidence.
            - 0: no explanation.

            Clarity: 0-2 points
            - 2: response is clear and understandable.
            - 1: response is understandable but incomplete, repetitive, or unclear in places.
            - 0: response is too unclear to assess reliably.
            """,
            customInstructions: "Use only the reviewed student response and the supplied answer key or prompt. If the student refers to text evidence that is not included in the reviewed text, mark teacher review required rather than assuming the reference is correct."
        ),
        RubricTemplate(
            id: "science-explanation-12pt",
            name: "12-point science explanation",
            assignmentType: .shortAnswer,
            assessmentPurpose: .summative,
            description: "For written scientific explanations using concepts, evidence, and reasoning.",
            rubricText: """
            Concept understanding: 0-4 points
            - 4: accurately explains the key scientific concept or relationship.
            - 3: mostly accurate with minor gaps or imprecision.
            - 2: partially accurate but includes meaningful gaps or confusion.
            - 1: minimal accurate understanding.
            - 0: inaccurate, missing, or unrelated.

            Use of evidence/data: 0-3 points
            - 3: uses relevant data, observations, or examples to support the explanation.
            - 2: uses some relevant evidence but connection is limited.
            - 1: includes minimal or weak evidence.
            - 0: no relevant evidence.

            Scientific reasoning: 0-3 points
            - 3: clearly connects evidence to the concept using scientific reasoning.
            - 2: gives some reasoning with gaps.
            - 1: reasoning is minimal or unclear.
            - 0: no reasoning.

            Scientific vocabulary and clarity: 0-2 points
            - 2: uses appropriate vocabulary clearly.
            - 1: uses some vocabulary but imprecisely or with clarity issues.
            - 0: vocabulary is missing, misleading, or prevents reliable assessment.
            """,
            customInstructions: "Do not grade diagrams, tables, equations, or experimental setup unless the relevant information appears in the reviewed text or was entered by the teacher. Flag any missing data, diagram dependence, or uncertain vocabulary for teacher review."
        ),
        RubricTemplate(
            id: "hass-source-response-12pt",
            name: "12-point HASS source response",
            assignmentType: .paragraphResponse,
            assessmentPurpose: .summative,
            description: "For history, geography, civics, economics, and source-based written responses.",
            rubricText: """
            Understanding of source or context: 0-3 points
            - 3: accurately identifies relevant source/context information.
            - 2: mostly accurate with minor gaps.
            - 1: limited or partially accurate understanding.
            - 0: inaccurate, missing, or unrelated.

            Use of evidence: 0-3 points
            - 3: uses specific, relevant evidence from the source or provided material.
            - 2: uses some relevant evidence but lacks specificity or completeness.
            - 1: evidence is vague, weak, or minimally relevant.
            - 0: no relevant evidence.

            Reasoning / interpretation: 0-4 points
            - 4: explains the significance, cause/effect, perspective, pattern, or relationship clearly.
            - 3: generally sound reasoning with minor gaps.
            - 2: partial reasoning with meaningful gaps.
            - 1: minimal reasoning or mostly description.
            - 0: no relevant reasoning.

            Communication: 0-2 points
            - 2: clear, organized response using relevant terms.
            - 1: understandable but unclear, incomplete, or loosely organized.
            - 0: too unclear to assess reliably.
            """,
            customInstructions: "Do not assume source facts that are not in the reviewed student response, prompt, answer key, or teacher-provided context. Mark teacher review required when the response depends on a source excerpt not included in the grading packet."
        ),
        RubricTemplate(
            id: "formative-exit-ticket-8pt",
            name: "8-point formative exit ticket",
            assignmentType: .shortAnswer,
            assessmentPurpose: .formative,
            description: "Evidence and next-step feedback for quick formative checks.",
            rubricText: """
            Shows current understanding: 0-3 points
            - 3: shows clear understanding of the focus concept or skill.
            - 2: shows partial understanding with a small gap or imprecision.
            - 1: shows limited understanding or a significant misconception.
            - 0: does not yet show the focus concept or skill.

            Uses relevant evidence or reasoning: 0-2 points
            - 2: includes relevant evidence, reasoning, or explanation.
            - 1: includes limited or unclear evidence/reasoning.
            - 0: no supporting evidence or reasoning.

            Identifies or applies key vocabulary/strategy: 0-1 point
            - 1: uses an appropriate key term, strategy, or representation in text.
            - 0: does not use the expected term/strategy or it is unclear.

            Actionable next step: 0-2 points
            - 2: response makes the next teaching or learning step clear.
            - 1: some next-step need is visible but requires teacher interpretation.
            - 0: evidence is insufficient to determine a next step.
            """,
            customInstructions: "This is formative. Emphasize what the student appears to understand from the evidence and one concrete next step. Do not present the output as a final summative grade by default."
        ),
        RubricTemplate(
            id: "reflection-response-12pt",
            name: "12-point reflection response",
            assignmentType: .paragraphResponse,
            assessmentPurpose: .summative,
            description: "For written learning reflections and task reflections.",
            rubricText: """
            Connection to task or learning goal: 0-3 points
            - 3: clearly connects reflection to the task, goal, or learning focus.
            - 2: mostly connected with minor gaps.
            - 1: weak or vague connection.
            - 0: no clear connection.

            Specific evidence or example: 0-3 points
            - 3: includes a specific example from the work, process, or learning.
            - 2: includes a relevant but limited example.
            - 1: includes a vague or minimal example.
            - 0: no specific example.

            Explanation of learning: 0-3 points
            - 3: explains what was learned or improved with clear reasoning.
            - 2: gives some explanation with gaps.
            - 1: minimal explanation.
            - 0: no explanation.

            Next step: 0-3 points
            - 3: identifies a specific and realistic next step.
            - 2: identifies a general next step.
            - 1: next step is vague or only implied.
            - 0: no next step.
            """,
            customInstructions: "Assess only the written reflection. Do not infer effort, attitude, motivation, or personality. Feedback should be supportive, specific, and focused on the evidence in the response."
        )
    ]
}
enum GradeDraftError: LocalizedError, Equatable {
    case missingRubric
    case missingStudentText
    case ocrReviewRequired
    case localModelUnavailable(String)
    case malformedModelResponse(String)
    case invalidModelGrade(String)
    case ocrFailed(String)
    case persistenceFailed(String)
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingRubric:
            return "Add a rubric, answer key, or exemplar before drafting a feedback suggestion."
        case .missingStudentText:
            return "Add or review the student text before drafting a feedback suggestion."
        case .ocrReviewRequired:
            return "Review and confirm OCR text before drafting a feedback suggestion."
        case .localModelUnavailable(let message):
            return message
        case .malformedModelResponse(let message):
            return "The local model returned a response the app could not parse: \(message)"
        case .invalidModelGrade(let message):
            return "The local model returned an invalid grade draft: \(message)"
        case .ocrFailed(let message):
            return "OCR failed: \(message)"
        case .persistenceFailed(let message):
            return "Could not save local data: \(message)"
        case .exportFailed(let message):
            return "Could not export the local report: \(message)"
        }
    }
}

