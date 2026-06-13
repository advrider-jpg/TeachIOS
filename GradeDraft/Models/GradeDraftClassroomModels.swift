import CoreGraphics
import Foundation

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
    var rubricImportMode: RubricImportMode
    var confirmedParsedRubric: ParsedRubric?
    var customInstructions: String
    var selectedInstructionTemplateIDs: [String]
    var answerKeyText: String
    var exemplarText: String
    var formativeFocusText: String
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
    var appliedTemplates: [AppliedTemplateRecord]
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
        rubricImportMode: RubricImportMode = .automatic,
        confirmedParsedRubric: ParsedRubric? = nil,
        customInstructions: String = "",
        selectedInstructionTemplateIDs: [String] = GradingConstraintTemplates.defaultSelectedIDs,
        answerKeyText: String = "",
        exemplarText: String = "",
        formativeFocusText: String = "",
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
        appliedTemplates: [AppliedTemplateRecord] = [],
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
        self.rubricImportMode = rubricImportMode
        self.confirmedParsedRubric = confirmedParsedRubric
        self.customInstructions = customInstructions
        self.selectedInstructionTemplateIDs = selectedInstructionTemplateIDs
        self.answerKeyText = answerKeyText
        self.exemplarText = exemplarText
        self.formativeFocusText = formativeFocusText
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
        self.appliedTemplates = appliedTemplates
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Codable with backward-compatible prompt field

    private enum CodingKeys: String, CodingKey {
        case id, classGroupID, studentID, title, prompt, subject, gradeLevel, assessmentPurpose, curriculumReference
        case className, studentDisplayName, assignmentType, rubricText, rubricImportMode, confirmedParsedRubric
        case customInstructions, selectedInstructionTemplateIDs
        case answerKeyText, exemplarText, formativeFocusText, reviewedStudentText, sourceInputs, ocrDocument
        case ocrReviewStatus, ocrReviewedAt, latestDraft, finalReview
        case exportRecords, auditEvents, evidenceReferences, curriculumMappings, appliedTemplates, createdAt, updatedAt
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
        rubricImportMode = (try? container.decode(RubricImportMode.self, forKey: .rubricImportMode)) ?? .automatic
        confirmedParsedRubric = try container.decodeIfPresent(ParsedRubric.self, forKey: .confirmedParsedRubric)
        customInstructions = try container.decode(String.self, forKey: .customInstructions)
        selectedInstructionTemplateIDs = (try? container.decode([String].self, forKey: .selectedInstructionTemplateIDs)) ?? []
        answerKeyText = try container.decode(String.self, forKey: .answerKeyText)
        exemplarText = try container.decode(String.self, forKey: .exemplarText)
        formativeFocusText = (try? container.decode(String.self, forKey: .formativeFocusText)) ?? ""
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
        appliedTemplates = (try? container.decode([AppliedTemplateRecord].self, forKey: .appliedTemplates)) ?? []
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
        try container.encode(rubricImportMode, forKey: .rubricImportMode)
        try container.encodeIfPresent(confirmedParsedRubric, forKey: .confirmedParsedRubric)
        try container.encode(customInstructions, forKey: .customInstructions)
        try container.encode(selectedInstructionTemplateIDs, forKey: .selectedInstructionTemplateIDs)
        try container.encode(answerKeyText, forKey: .answerKeyText)
        try container.encode(exemplarText, forKey: .exemplarText)
        try container.encode(formativeFocusText, forKey: .formativeFocusText)
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
        try container.encode(appliedTemplates, forKey: .appliedTemplates)
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
        switch rubricImportMode {
        case .structuredConfirmed:
            return confirmedParsedRubric ?? RubricParser.parse(rubricText)
        case .rawTextOnly:
            return ParsedRubric(
                criteria: [],
                issues: rubricText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? [] : ["Rubric was saved as raw text; structured criteria were not teacher-confirmed."],
                groups: []
            )
        case .automatic:
            return RubricParser.parse(rubricText)
        }
    }

    var latestDraftIsStale: Bool {
        guard let latestDraft else { return false }
        return latestDraft.packetFingerprint != gradingPacketFingerprint
    }

    var finalReviewIsStale: Bool {
        guard let finalReview else { return false }
        return finalReview.packetFingerprint != gradingSourceFingerprint
    }

    var isStudentFacingExportReady: Bool {
        guard let finalReview else { return false }
        guard finalReview.status == .approved else { return false }
        return !finalReviewIsStale
    }

    var gradingSourceFingerprint: String {
        var sourceOnly = self
        sourceOnly.evidenceReferences = []
        return sourceOnly.gradingPacketFingerprint
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
            selectedInstructionTemplateIDs: selectedInstructionTemplateIDs,
            selectedInstructionTemplateText: GradingConstraintTemplates.combinedText(for: selectedInstructionTemplateIDs),
            selectedInstructionTemplateFingerprint: GradingConstraintTemplates.fingerprint(for: selectedInstructionTemplateIDs),
            formativeFocusText: formativeFocusText,
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
            hasGradingStandard: hasGradingStandard,
            plannedContentGradingPacket: plannedContentGradingPacket
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
    case needsRecheck
    case approved
    case exported

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .notStarted: return "Not started"
        case .sourceNeeded: return "Add student work"
        case .ocrReviewNeeded: return "Review scanned text"
        case .readyForGrading: return "Ready for teacher review"
        case .draftGenerated: return "Review final grade"
        case .finalReviewInProgress: return "Review final grade"
        case .needsRecheck: return "Needs recheck"
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
    var kind: String
    var name: String
    var version: String
    var sourceVersion: String
    var provenance: String
    var localPath: String
    var jsonldURL: String
    var retrievedAt: Date
    var importedAt: Date
    var sha256: String
    var licenseName: String

    init(
        id: String,
        kind: String = "localReference",
        name: String,
        version: String,
        sourceVersion: String = "",
        provenance: String,
        localPath: String,
        jsonldURL: String = "",
        retrievedAt: Date = Date(),
        importedAt: Date = Date(),
        sha256: String = "",
        licenseName: String = ""
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.version = version
        self.sourceVersion = sourceVersion.isEmpty ? version : sourceVersion
        self.provenance = provenance
        self.localPath = localPath
        self.jsonldURL = jsonldURL
        self.retrievedAt = retrievedAt
        self.importedAt = importedAt
        self.sha256 = sha256
        self.licenseName = licenseName
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, name, version, sourceVersion, provenance, localPath, jsonldURL, retrievedAt, importedAt, sha256, licenseName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = (try? container.decode(String.self, forKey: .kind)) ?? "localReference"
        name = try container.decode(String.self, forKey: .name)
        version = try container.decode(String.self, forKey: .version)
        sourceVersion = (try? container.decode(String.self, forKey: .sourceVersion)) ?? version
        provenance = try container.decode(String.self, forKey: .provenance)
        localPath = (try? container.decode(String.self, forKey: .localPath)) ?? ""
        jsonldURL = (try? container.decode(String.self, forKey: .jsonldURL)) ?? ""
        retrievedAt = (try? container.decode(Date.self, forKey: .retrievedAt)) ?? Date()
        importedAt = (try? container.decode(Date.self, forKey: .importedAt)) ?? retrievedAt
        sha256 = (try? container.decode(String.self, forKey: .sha256)) ?? ""
        licenseName = (try? container.decode(String.self, forKey: .licenseName)) ?? ""
    }
}

struct CurriculumItem: Identifiable, Codable, Equatable {
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

    private enum CodingKeys: String, CodingKey {
        case id, source, version, sourceVersion, learningArea, subject, yearLevel, band, strand, substrand, organizer, itemType, catalogKind, code, title, shortDescription, sourceURL, externalURI, provenance, sourceKey, sourceName, altLabels, parentIDs, childIDs, tags, isOfficial, isEditable, licenseName, sourceAttribution
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        source = try container.decode(String.self, forKey: .source)
        version = try container.decode(String.self, forKey: .version)
        sourceVersion = (try? container.decode(String.self, forKey: .sourceVersion)) ?? version
        learningArea = try container.decode(String.self, forKey: .learningArea)
        subject = try container.decode(String.self, forKey: .subject)
        yearLevel = try container.decode(String.self, forKey: .yearLevel)
        band = (try? container.decode(String.self, forKey: .band)) ?? ""
        strand = (try? container.decode(String.self, forKey: .strand)) ?? ""
        substrand = (try? container.decode(String.self, forKey: .substrand)) ?? ""
        organizer = (try? container.decode(String.self, forKey: .organizer)) ?? ""
        itemType = try container.decode(String.self, forKey: .itemType)
        catalogKind = (try? container.decode(String.self, forKey: .catalogKind)) ?? itemType
        code = try container.decode(String.self, forKey: .code)
        title = try container.decode(String.self, forKey: .title)
        shortDescription = try container.decode(String.self, forKey: .shortDescription)
        sourceURL = try container.decode(String.self, forKey: .sourceURL)
        externalURI = (try? container.decode(String.self, forKey: .externalURI)) ?? sourceURL
        provenance = (try? container.decode(String.self, forKey: .provenance)) ?? sourceURL
        sourceKey = (try? container.decode(String.self, forKey: .sourceKey)) ?? ""
        sourceName = (try? container.decode(String.self, forKey: .sourceName)) ?? source
        altLabels = (try? container.decode([String].self, forKey: .altLabels)) ?? []
        parentIDs = (try? container.decode([String].self, forKey: .parentIDs)) ?? []
        childIDs = (try? container.decode([String].self, forKey: .childIDs)) ?? []
        tags = (try? container.decode([String].self, forKey: .tags)) ?? []
        isOfficial = (try? container.decode(Bool.self, forKey: .isOfficial)) ?? false
        isEditable = (try? container.decode(Bool.self, forKey: .isEditable)) ?? true
        licenseName = (try? container.decode(String.self, forKey: .licenseName)) ?? ""
        sourceAttribution = (try? container.decode(String.self, forKey: .sourceAttribution)) ?? ""
    }
}

struct CurriculumCatalog: Codable, Equatable {
    var schemaVersion: String
    var catalogID: String
    var displayName: String
    var sourceVersion: String
    var filesUpdated: String
    var generatedAt: Date
    var generatedBy: String
    var licenseName: String
    var attributionText: String
    var nonEndorsementWarning: String
    var icipWarning: String
    var sources: [CurriculumSource]
    var items: [CurriculumItem]
    var relationships: [String]
    var tags: [String]
    var warning: String

    init(
        schemaVersion: String = "legacy-local",
        catalogID: String = "teacher-provided-local-reference-catalog",
        displayName: String = "Local curriculum reference catalog",
        sourceVersion: String = "repository-local",
        filesUpdated: String = "",
        generatedAt: Date = Date(),
        generatedBy: String = "MarkForMe",
        licenseName: String = "",
        attributionText: String = "",
        nonEndorsementWarning: String = "",
        icipWarning: String = "",
        sources: [CurriculumSource],
        items: [CurriculumItem],
        relationships: [String] = [],
        tags: [String] = [],
        warning: String
    ) {
        self.schemaVersion = schemaVersion
        self.catalogID = catalogID
        self.displayName = displayName
        self.sourceVersion = sourceVersion
        self.filesUpdated = filesUpdated
        self.generatedAt = generatedAt
        self.generatedBy = generatedBy
        self.licenseName = licenseName
        self.attributionText = attributionText
        self.nonEndorsementWarning = nonEndorsementWarning.isEmpty ? warning : nonEndorsementWarning
        self.icipWarning = icipWarning
        self.sources = sources
        self.items = items
        self.relationships = relationships
        self.tags = tags
        self.warning = warning
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, catalogID, displayName, sourceVersion, filesUpdated, generatedAt, generatedBy, licenseName, attributionText, nonEndorsementWarning, icipWarning, sources, items, relationships, tags, warning
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = (try? container.decode(String.self, forKey: .schemaVersion)) ?? "legacy-local"
        catalogID = (try? container.decode(String.self, forKey: .catalogID)) ?? "teacher-provided-local-reference-catalog"
        displayName = (try? container.decode(String.self, forKey: .displayName)) ?? "Local curriculum reference catalog"
        sourceVersion = (try? container.decode(String.self, forKey: .sourceVersion)) ?? "repository-local"
        filesUpdated = (try? container.decode(String.self, forKey: .filesUpdated)) ?? ""
        generatedAt = (try? container.decode(Date.self, forKey: .generatedAt)) ?? Date()
        generatedBy = (try? container.decode(String.self, forKey: .generatedBy)) ?? "MarkForMe"
        licenseName = (try? container.decode(String.self, forKey: .licenseName)) ?? ""
        attributionText = (try? container.decode(String.self, forKey: .attributionText)) ?? ""
        nonEndorsementWarning = (try? container.decode(String.self, forKey: .nonEndorsementWarning)) ?? ""
        icipWarning = (try? container.decode(String.self, forKey: .icipWarning)) ?? ""
        sources = try container.decode([CurriculumSource].self, forKey: .sources)
        items = try container.decode([CurriculumItem].self, forKey: .items)
        relationships = (try? container.decode([String].self, forKey: .relationships)) ?? []
        tags = (try? container.decode([String].self, forKey: .tags)) ?? []
        warning = (try? container.decode(String.self, forKey: .warning)) ?? nonEndorsementWarning
        if nonEndorsementWarning.isEmpty { nonEndorsementWarning = warning }
    }

    func filtered(catalogKind: String = "", subject: String = "", learningArea: String = "", yearLevel: String = "", searchText: String = "") -> [CurriculumItem] {
        let normalizedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return items.filter { item in
            let kindMatch = catalogKind.isEmpty || item.catalogKind.localizedCaseInsensitiveContains(catalogKind) || item.itemType.localizedCaseInsensitiveContains(catalogKind)
            let learningAreaMatch = learningArea.isEmpty || item.learningArea.localizedCaseInsensitiveContains(learningArea)
            let subjectMatch = subject.isEmpty || item.subject.localizedCaseInsensitiveContains(subject)
            let yearLevelMatch = yearLevel.isEmpty || item.yearLevel.localizedCaseInsensitiveContains(yearLevel) || item.band.localizedCaseInsensitiveContains(yearLevel)
            let searchable = ([item.code, item.title, item.shortDescription, item.learningArea, item.subject, item.strand, item.substrand, item.organizer] + item.altLabels + item.tags)
                .joined(separator: " ")
                .lowercased()
            let searchMatch = normalizedSearch.isEmpty || searchable.contains(normalizedSearch)
            return kindMatch && learningAreaMatch && subjectMatch && yearLevelMatch && searchMatch
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
        if let ocrLineID { return "\(page), text line \(ocrLineID.uuidString.prefix(8))" }
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
    var restoreCompatibility: String = "Compatible with MarkForMe local backup restore v3 when schemaVersion begins with gradedraft-backup-v."
}

struct ExportArchiveInventoryItem: Codable, Equatable, Identifiable {
    var id: String { path }
    var path: String
    var category: String
    var includesStudentData: Bool
    var includesPrivateTeacherNotes: Bool
    var includesOriginalSources: Bool
    var includesInternalMetadata: Bool
    var description: String
}

enum BackupConflictResolution: String, CaseIterable, Codable, Equatable, Identifiable {
    case keepLocal
    case replaceLocal
    case restoreAsCopy

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .keepLocal: return "Keep Current Records"
        case .replaceLocal: return "Replace Current Records"
        case .restoreAsCopy: return "Import as New Copy"
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
        "Backup contains \(assignmentCount) assignment(s), \(classCount) class(es), \(studentCount) student(s), and \(sourceFileCount) original file(s). Matching records found: \(conflictAssignmentIDs.count)."
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
