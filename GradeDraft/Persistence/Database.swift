import Foundation
import GRDB

enum GradeDraftDatabaseError: Error, LocalizedError {
    case missingStoreRoot
    case migrationFailed(String)
    case preflightFailed(String)
    case dataCorrupted(String)

    var errorDescription: String? {
        switch self {
        case .missingStoreRoot: return "Could not resolve a local application-support folder."
        case .migrationFailed(let detail): return "Local database migration failed: \(detail)"
        case .preflightFailed(let detail): return "Local backup preflight failed: \(detail)"
        case .dataCorrupted(let detail): return "Local database data is corrupted: \(detail)"
        }
    }
}

struct DatabaseBackupDescriptor: Codable {
    let assignmentCount: Int
    let exportCreatedAt: Date
}

/// GRDB entry point for GradeDraft local persistence.
/// The primary load/save path uses normalized SQLite tables. The JSON payload table
/// is retained only as a compatibility and export fallback.
final class GradeDraftDatabase {
    private let databaseQueue: DatabaseQueue
    private let jsonDecoder = JSONDecoder()
    private let jsonEncoder = JSONEncoder()
    private let resolvedDatabaseFolder: URL

    init(applicationSupportURL: URL? = nil) throws {
        jsonDecoder.dateDecodingStrategy = .iso8601
        jsonEncoder.dateEncodingStrategy = .iso8601
        jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let baseURL = applicationSupportURL
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let baseURL else { throw GradeDraftDatabaseError.missingStoreRoot }

        resolvedDatabaseFolder = baseURL.appendingPathComponent("GradeDraft", isDirectory: true)
        try FileManager.default.createDirectory(at: resolvedDatabaseFolder, withIntermediateDirectories: true)
        databaseQueue = try DatabaseQueue(path: resolvedDatabaseFolder.appendingPathComponent("gradedraft.sqlite").path)
    }

    func bootstrapIfNeeded() throws {
        var migrator = DatabaseMigrator()
        registerMigrations(&migrator)
        do {
            try migrator.migrate(databaseQueue)
        } catch {
            throw GradeDraftDatabaseError.migrationFailed(error.localizedDescription)
        }
    }

    func loadAssignments() throws -> [AssignmentRecord] {
        try databaseQueue.read { db in
            let normalizedCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM grade_draft_assignments") ?? 0
            if normalizedCount > 0 {
                return try loadNormalizedAssignments(in: db)
            }
            return try loadPayloadAssignments(in: db)
        }
    }

    func saveAssignments(_ assignments: [AssignmentRecord]) throws {
        try databaseQueue.write { db in
            let idsToKeep = Set(assignments.map { $0.id.uuidString })
            let existingIDs = try String.fetchAll(db, sql: "SELECT id FROM grade_draft_assignments")
            for existingID in existingIDs where !idsToKeep.contains(existingID) {
                try deleteAssignmentRows(id: existingID, in: db)
            }
            for assignment in assignments {
                let payload = try jsonEncoder.encode(assignment)
                let payloadText = String(data: payload, encoding: .utf8) ?? "{}"
                try db.execute(
                    sql: """
                    INSERT INTO grade_draft_assignment_records (id, payload, updated_at)
                    VALUES (?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET payload = excluded.payload, updated_at = excluded.updated_at
                    """,
                    arguments: [assignment.id.uuidString, payloadText, iso8601.string(from: assignment.updatedAt)]
                )
                try saveNormalizedAssignment(assignment, in: db)
            }
        }
    }

    func deleteAssignment(id: UUID) throws {
        try databaseQueue.write { db in
            try deleteAssignmentRows(id: id.uuidString, in: db)
        }
    }

    func applicationSupportDirectory() throws -> URL { resolvedDatabaseFolder }

    func loadClassGroups() throws -> [ClassGroupRecord] {
        try databaseQueue.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM class_groups ORDER BY updated_at DESC").map { row in
                ClassGroupRecord(
                    id: uuid(row, "id"),
                    name: text(row, "name"),
                    schoolYear: text(row, "school_year"),
                    term: text(row, "term"),
                    subject: text(row, "subject"),
                    gradeLevel: text(row, "year_level"),
                    notes: text(row, "notes"),
                    isArchived: bool(row, "is_archived"),
                    createdAt: date(row, "created_at"),
                    updatedAt: date(row, "updated_at")
                )
            }
        }
    }

    func saveClassGroup(_ classGroup: ClassGroupRecord) throws {
        try databaseQueue.write { db in
            try db.execute(sql: """
            INSERT INTO class_groups (id, name, school_year, term, subject, year_level, notes, is_archived, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET name = excluded.name, school_year = excluded.school_year, term = excluded.term,
            subject = excluded.subject, year_level = excluded.year_level, notes = excluded.notes, is_archived = excluded.is_archived,
            updated_at = excluded.updated_at
            """, arguments: [
                classGroup.id.uuidString, classGroup.name, classGroup.schoolYear, classGroup.term, classGroup.subject,
                classGroup.gradeLevel, classGroup.notes, classGroup.isArchived, iso8601.string(from: classGroup.createdAt),
                iso8601.string(from: classGroup.updatedAt)
            ])
        }
    }

    func deleteClassGroup(id: UUID) throws {
        try databaseQueue.write { db in
            try db.execute(sql: "DELETE FROM class_students WHERE class_group_id = ?", arguments: [id.uuidString])
            try db.execute(sql: "DELETE FROM class_groups WHERE id = ?", arguments: [id.uuidString])
        }
    }

    func loadStudents() throws -> [StudentRecord] {
        try databaseQueue.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM students ORDER BY updated_at DESC").map { row in
                StudentRecord(
                    id: uuid(row, "id"),
                    displayName: text(row, "display_name"),
                    className: text(row, "class_name"),
                    localIdentifier: text(row, "local_identifier"),
                    notes: text(row, "notes"),
                    isActive: bool(row, "is_active", defaultValue: true),
                    createdAt: date(row, "created_at"),
                    updatedAt: date(row, "updated_at")
                )
            }
        }
    }

    func saveStudent(_ student: StudentRecord) throws {
        try databaseQueue.write { db in
            try db.execute(sql: """
            INSERT INTO students (id, display_name, local_identifier, class_name, notes, is_active, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET display_name = excluded.display_name, local_identifier = excluded.local_identifier,
            class_name = excluded.class_name, notes = excluded.notes, is_active = excluded.is_active, updated_at = excluded.updated_at
            """, arguments: [student.id.uuidString, student.displayName, student.localIdentifier, student.className, student.notes, student.isActive, iso8601.string(from: student.createdAt), iso8601.string(from: student.updatedAt)])
        }
    }

    func deleteStudent(id: UUID) throws {
        try databaseQueue.write { db in
            try db.execute(sql: "DELETE FROM class_students WHERE student_id = ?", arguments: [id.uuidString])
            try db.execute(sql: "DELETE FROM assignment_roster_entries WHERE student_id = ?", arguments: [id.uuidString])
            try db.execute(sql: "DELETE FROM students WHERE id = ?", arguments: [id.uuidString])
        }
    }

    func loadAssignmentRoster(assignmentID: UUID) throws -> [AssignmentRosterEntry] {
        try databaseQueue.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM assignment_roster_entries WHERE assignment_id = ? ORDER BY sort_order", arguments: [assignmentID.uuidString]).map { row in
                AssignmentRosterEntry(
                    id: uuid(row, "id"),
                    assignmentID: uuid(row, "assignment_id"),
                    studentID: uuid(row, "student_id"),
                    studentDisplayName: text(row, "student_display_name"),
                    localIdentifier: text(row, "local_identifier"),
                    status: AssignmentRosterStatus(rawValue: text(row, "status")) ?? .notStarted,
                    sortOrder: int(row, "sort_order"),
                    createdAt: date(row, "created_at"),
                    updatedAt: date(row, "updated_at")
                )
            }
        }
    }

    func saveAssignmentRoster(_ entries: [AssignmentRosterEntry]) throws {
        try databaseQueue.write { db in
            for entry in entries {
                try db.execute(sql: """
                INSERT INTO assignment_roster_entries (id, assignment_id, student_id, student_display_name, local_identifier, status, sort_order, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET student_display_name = excluded.student_display_name, local_identifier = excluded.local_identifier,
                status = excluded.status, sort_order = excluded.sort_order, updated_at = excluded.updated_at
                """, arguments: [entry.id.uuidString, entry.assignmentID.uuidString, entry.studentID.uuidString, entry.studentDisplayName, entry.localIdentifier, entry.status.rawValue, entry.sortOrder, iso8601.string(from: entry.createdAt), iso8601.string(from: entry.updatedAt)])
            }
        }
    }

    func saveSourceInputs(_ sourceInputs: [SourceInputRef], assignmentID: UUID) throws {
        try databaseQueue.write { db in
            try db.execute(sql: "DELETE FROM grade_draft_source_inputs WHERE assignment_id = ?", arguments: [assignmentID.uuidString])
            for source in sourceInputs { try saveSourceInput(source, assignmentID: assignmentID.uuidString, in: db) }
        }
    }

    func saveOCRDocument(_ document: OCRDocument, assignmentID: UUID) throws {
        try databaseQueue.write { db in
            try db.execute(sql: "DELETE FROM grade_draft_ocr_lines WHERE assignment_id = ?", arguments: [assignmentID.uuidString])
            try saveOCRDocumentRows(document, assignmentID: assignmentID.uuidString, in: db)
        }
    }

    func saveFinalReview(_ review: FinalGradeReview, assignmentID: UUID) throws {
        try databaseQueue.write { db in
            try db.execute(sql: "DELETE FROM grade_draft_final_criteria WHERE assignment_id = ?", arguments: [assignmentID.uuidString])
            try db.execute(sql: "DELETE FROM grade_draft_final_reviews WHERE assignment_id = ?", arguments: [assignmentID.uuidString])
            try saveFinalReviewRows(review, assignmentID: assignmentID.uuidString, in: db)
        }
    }

    func saveEvidenceReferences(_ references: [EvidenceReference], assignmentID: UUID) throws {
        try databaseQueue.write { db in
            try db.execute(sql: "DELETE FROM grade_draft_evidence_references WHERE assignment_id = ?", arguments: [assignmentID.uuidString])
            for evidence in references { try saveEvidence(evidence, assignmentID: assignmentID.uuidString, in: db) }
        }
    }

    func loadFullAssignmentGraph(id: UUID) throws -> AssignmentRecord? {
        try loadAssignments().first { $0.id == id }
    }

    func preflightAuditBundle() throws -> URL {
        let backupFolder = resolvedDatabaseFolder.appendingPathComponent("Backup", isDirectory: true)
        try FileManager.default.createDirectory(at: backupFolder, withIntermediateDirectories: true)
        guard FileManager.default.isWritableFile(atPath: backupFolder.path) else {
            throw GradeDraftDatabaseError.preflightFailed("Backup folder is not writable.")
        }
        return backupFolder
    }

    func readBackupDescriptor() throws -> DatabaseBackupDescriptor {
        let count = try databaseQueue.read { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM grade_draft_assignments") ?? 0 }
        return DatabaseBackupDescriptor(assignmentCount: count, exportCreatedAt: Date())
    }

    func removeCompatibilityPayloadsForValidation() throws {
        try databaseQueue.write { db in
            try db.execute(sql: "DELETE FROM grade_draft_assignment_records")
        }
    }

    // MARK: - Save normalized graph

    private func saveNormalizedAssignment(_ assignment: AssignmentRecord, in db: Database) throws {
        let id = assignment.id.uuidString
        try deleteAssignmentRows(id: id, in: db, keepPayload: true)
        try db.execute(sql: """
        INSERT INTO grade_draft_assignments (
            id, class_group_id, student_id, title, prompt, subject, grade_level, class_name, student_display_name,
            assignment_type, assessment_purpose, curriculum_reference, rubric_text, custom_instructions, answer_key_text,
            exemplar_text, reviewed_student_text, ocr_review_status, ocr_reviewed_at, grading_packet_fingerprint, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET class_group_id = excluded.class_group_id, student_id = excluded.student_id, title = excluded.title,
        prompt = excluded.prompt, subject = excluded.subject, grade_level = excluded.grade_level, class_name = excluded.class_name,
        student_display_name = excluded.student_display_name, assignment_type = excluded.assignment_type, assessment_purpose = excluded.assessment_purpose,
        curriculum_reference = excluded.curriculum_reference, rubric_text = excluded.rubric_text, custom_instructions = excluded.custom_instructions,
        answer_key_text = excluded.answer_key_text, exemplar_text = excluded.exemplar_text, reviewed_student_text = excluded.reviewed_student_text,
        ocr_review_status = excluded.ocr_review_status, ocr_reviewed_at = excluded.ocr_reviewed_at, grading_packet_fingerprint = excluded.grading_packet_fingerprint,
        updated_at = excluded.updated_at
        """, arguments: [
            id, assignment.classGroupID?.uuidString, assignment.studentID?.uuidString, assignment.title, assignment.prompt ?? "",
            assignment.subject, assignment.gradeLevel, assignment.className, assignment.studentDisplayName, assignment.assignmentType.rawValue,
            assignment.assessmentPurpose.rawValue, assignment.curriculumReference, assignment.rubricText, assignment.customInstructions,
            assignment.answerKeyText, assignment.exemplarText, assignment.reviewedStudentText, assignment.ocrReviewStatus.rawValue,
            assignment.ocrReviewedAt.map { iso8601.string(from: $0) }, assignment.gradingPacketFingerprint,
            iso8601.string(from: assignment.createdAt), iso8601.string(from: assignment.updatedAt)
        ])
        for source in assignment.sourceInputs { try saveSourceInput(source, assignmentID: id, in: db) }
        if let document = assignment.ocrDocument { try saveOCRDocumentRows(document, assignmentID: id, in: db) }
        if let draft = assignment.latestDraft { try saveDraftRows(draft, assignmentID: id, in: db) }
        if let final = assignment.finalReview { try saveFinalReviewRows(final, assignmentID: id, in: db) }
        for evidence in assignment.evidenceReferences { try saveEvidence(evidence, assignmentID: id, in: db) }
        for mapping in assignment.curriculumMappings { try saveCurriculumMapping(mapping, assignmentID: id, in: db) }
        for export in assignment.exportRecords { try saveExport(export, assignmentID: id, in: db) }
        for event in assignment.auditEvents { try saveAuditEvent(event, assignmentID: id, in: db) }
    }

    private func saveSourceInput(_ source: SourceInputRef, assignmentID: String, in db: Database) throws {
        try db.execute(sql: """
        INSERT INTO grade_draft_source_inputs (id, assignment_id, source_type, page_index, local_relative_path, file_name, mime_type, content_digest, digest_algorithm, image_width, image_height, pdf_page_count, teacher_included_in_export, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, arguments: [source.id.uuidString, assignmentID, source.sourceType.rawValue, source.pageIndex, source.localRelativePath, source.fileName, source.mimeType, source.contentDigest, source.digestAlgorithm, source.imageWidth, source.imageHeight, source.pdfPageCount, source.teacherIncludedInExport, iso8601.string(from: source.createdAt)])
    }

    private func saveOCRDocumentRows(_ document: OCRDocument, assignmentID: String, in db: Database) throws {
        for page in document.pages {
            try db.execute(sql: """
            INSERT INTO ocr_pages (id, ocr_document_id, student_work_id, source_input_id, page_index, width, height, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET source_input_id = excluded.source_input_id, page_index = excluded.page_index, width = excluded.width, height = excluded.height
            """, arguments: [page.id.uuidString, document.id.uuidString, assignmentID, page.sourceInputID?.uuidString, page.pageIndex, page.imageWidth, page.imageHeight, iso8601.string(from: document.createdAt)])
            for line in page.lines {
                try db.execute(sql: """
                INSERT INTO grade_draft_ocr_lines (id, assignment_id, page_id, source_input_id, page_index, raw_text, corrected_text, confidence, bbox_x, bbox_y, bbox_width, bbox_height, teacher_confirmed, is_rejected)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, arguments: [line.id.uuidString, assignmentID, page.id.uuidString, page.sourceInputID?.uuidString, page.pageIndex, line.rawText, line.correctedText, line.confidence, Double(line.boundingBox.x), Double(line.boundingBox.y), Double(line.boundingBox.width), Double(line.boundingBox.height), line.teacherConfirmed, line.isRejected])
            }
        }
    }

    private func saveDraftRows(_ draft: GradeDraftResult, assignmentID: String, in db: Database) throws {
        try db.execute(sql: """
        INSERT INTO grade_draft_drafts (id, assignment_id, packet_fingerprint, status, total_score, max_score, student_feedback, teacher_notes, raw_model_response, generated_at, student_response_summary, uncertainty_flags_json, compliance_flags_json)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, arguments: [draft.id.uuidString, assignmentID, draft.packetFingerprint, draft.status.rawValue, draft.totalScore, draft.maxScore, draft.studentFeedback, draft.teacherNotes, draft.rawModelResponse, iso8601.string(from: draft.generatedAt), draft.studentResponseSummary, try jsonString(draft.uncertaintyFlags), try jsonString(draft.complianceFlags)])
        for criterion in draft.criteria {
            try db.execute(sql: """
            INSERT INTO grade_draft_draft_criteria (id, assignment_id, draft_id, criterion_id, criterion, rating, proposed_points, max_points, evidence_json, evidence_refs_json, explanation, teacher_review_required, next_step, confidence, criterion_uncertainty_flags_json)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, arguments: [criterion.id.uuidString, assignmentID, draft.id.uuidString, criterion.criterionID, criterion.criterion, criterion.rating, criterion.proposedPoints, criterion.maxPoints, try jsonString(criterion.evidence), try jsonString(criterion.evidenceSourceRefs), criterion.explanation, criterion.teacherReviewRequired, criterion.nextStep, criterion.confidence, try jsonString(criterion.criterionUncertaintyFlags)])
        }
    }

    private func saveFinalReviewRows(_ final: FinalGradeReview, assignmentID: String, in db: Database) throws {
        try db.execute(sql: """
        INSERT INTO grade_draft_final_reviews (id, assignment_id, packet_fingerprint, status, total_score, max_score, student_feedback, private_teacher_notes, teacher_edited, created_at, finalized_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, arguments: [final.id.uuidString, assignmentID, final.packetFingerprint, final.status.rawValue, final.totalScore, final.maxScore, final.studentFeedback, final.privateTeacherNotes, final.teacherEdited, iso8601.string(from: final.createdAt), final.finalizedAt.map { iso8601.string(from: $0) }])
        for criterion in final.criteria {
            try db.execute(sql: """
            INSERT INTO grade_draft_final_criteria (id, assignment_id, final_review_id, criterion_id, criterion, rating, proposed_points, final_points, max_points, evidence_json, evidence_refs_json, explanation, teacher_approved, teacher_rationale)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, arguments: [criterion.id.uuidString, assignmentID, final.id.uuidString, criterion.criterionID, criterion.criterion, criterion.rating, criterion.proposedPoints, criterion.finalPoints, criterion.maxPoints, try jsonString(criterion.evidence), try jsonString(criterion.evidenceSourceRefs ?? []), criterion.explanation, criterion.teacherApproved, criterion.teacherRationale])
        }
    }

    private func saveEvidence(_ evidence: EvidenceReference, assignmentID: String, in db: Database) throws {
        try db.execute(sql: """
        INSERT INTO grade_draft_evidence_references (id, assignment_id, source_input_id, ocr_line_id, page_index, quote, start_offset, end_offset, bbox_x, bbox_y, bbox_width, bbox_height, source_kind, teacher_confirmed, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, arguments: [evidence.id.uuidString, assignmentID, evidence.sourceInputID?.uuidString, evidence.ocrLineID?.uuidString, evidence.pageIndex, evidence.quote, evidence.startOffset, evidence.endOffset, evidence.boundingBox.map { Double($0.x) }, evidence.boundingBox.map { Double($0.y) }, evidence.boundingBox.map { Double($0.width) }, evidence.boundingBox.map { Double($0.height) }, evidence.sourceKind, evidence.teacherConfirmed, iso8601.string(from: evidence.createdAt)])
    }

    private func saveCurriculumMapping(_ mapping: CurriculumMapping, assignmentID: String, in db: Database) throws {
        try db.execute(sql: """
        INSERT INTO grade_draft_curriculum_mappings (id, assignment_id, curriculum_item_id, mapping_kind, rubric_criterion_id, evidence_reference_id, teacher_selected, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, arguments: [mapping.id.uuidString, assignmentID, mapping.curriculumItemID, mapping.mappingKind, mapping.rubricCriterionID, mapping.evidenceReferenceID?.uuidString, mapping.teacherSelected, iso8601.string(from: mapping.createdAt)])
    }

    private func saveExport(_ export: ExportRecord, assignmentID: String, in db: Database) throws {
        try db.execute(sql: """
        INSERT INTO grade_draft_export_records (id, assignment_id, export_kind, content_fingerprint, includes_private_teacher_notes, includes_original_sources, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """, arguments: [export.id.uuidString, assignmentID, export.exportKind.rawValue, export.contentFingerprint, export.includesPrivateTeacherNotes, export.includesOriginalSources, iso8601.string(from: export.createdAt)])
    }

    private func saveAuditEvent(_ event: AuditEvent, assignmentID: String, in db: Database) throws {
        try db.execute(sql: """
        INSERT INTO grade_draft_audit_events (id, assignment_id, event_type, actor, detail, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
        """, arguments: [event.id.uuidString, assignmentID, event.eventType.rawValue, event.actor, event.detail, iso8601.string(from: event.timestamp)])
    }

    // MARK: - Load normalized graph

    private func loadNormalizedAssignments(in db: Database) throws -> [AssignmentRecord] {
        let rows = try Row.fetchAll(db, sql: "SELECT * FROM grade_draft_assignments ORDER BY updated_at DESC")
        return try rows.map { row in
            let assignmentID = uuid(row, "id")
            let idText = assignmentID.uuidString
            return AssignmentRecord(
                id: assignmentID,
                classGroupID: optionalUUID(row, "class_group_id"),
                studentID: optionalUUID(row, "student_id"),
                title: text(row, "title"),
                prompt: optionalText(row, "prompt").flatMap { $0.isEmpty ? nil : $0 },
                subject: text(row, "subject"),
                gradeLevel: text(row, "grade_level"),
                assessmentPurpose: AssessmentPurpose(rawValue: text(row, "assessment_purpose")) ?? .summative,
                curriculumReference: text(row, "curriculum_reference"),
                className: text(row, "class_name"),
                studentDisplayName: text(row, "student_display_name"),
                assignmentType: AssignmentType(rawValue: text(row, "assignment_type")) ?? .shortAnswer,
                rubricText: text(row, "rubric_text"),
                customInstructions: text(row, "custom_instructions"),
                answerKeyText: text(row, "answer_key_text"),
                exemplarText: text(row, "exemplar_text"),
                reviewedStudentText: text(row, "reviewed_student_text"),
                sourceInputs: try loadSourceInputs(assignmentID: idText, in: db),
                ocrDocument: try loadOCRDocument(assignmentID: idText, in: db),
                ocrReviewStatus: OCRReviewStatus(rawValue: text(row, "ocr_review_status")) ?? .notNeeded,
                ocrReviewedAt: optionalDate(row, "ocr_reviewed_at"),
                latestDraft: try loadLatestDraft(assignmentID: idText, in: db),
                finalReview: try loadFinalReview(assignmentID: idText, in: db),
                exportRecords: try loadExportRecords(assignmentID: idText, in: db),
                auditEvents: try loadAuditEvents(assignmentID: idText, in: db),
                evidenceReferences: try loadEvidenceReferences(assignmentID: idText, in: db),
                curriculumMappings: try loadCurriculumMappings(assignmentID: idText, in: db),
                createdAt: date(row, "created_at"),
                updatedAt: date(row, "updated_at")
            )
        }
    }

    private func loadPayloadAssignments(in db: Database) throws -> [AssignmentRecord] {
        let payloads = try String.fetchAll(db, sql: "SELECT payload FROM grade_draft_assignment_records ORDER BY updated_at DESC")
        return try payloads.map { payload in
            guard let data = payload.data(using: .utf8) else { throw GradeDraftDatabaseError.dataCorrupted("Unable to decode assignment payload bytes.") }
            return try jsonDecoder.decode(AssignmentRecord.self, from: data)
        }
    }

    private func loadSourceInputs(assignmentID: String, in db: Database) throws -> [SourceInputRef] {
        try Row.fetchAll(db, sql: "SELECT * FROM grade_draft_source_inputs WHERE assignment_id = ? ORDER BY COALESCE(page_index, -1), created_at", arguments: [assignmentID]).map { row in
            SourceInputRef(
                id: uuid(row, "id"),
                sourceType: SourceType(rawValue: text(row, "source_type")) ?? .pastedText,
                pageIndex: optionalInt(row, "page_index"),
                localRelativePath: optionalText(row, "local_relative_path"),
                fileName: optionalText(row, "file_name"),
                mimeType: optionalText(row, "mime_type"),
                contentDigest: optionalText(row, "content_digest"),
                digestAlgorithm: optionalText(row, "digest_algorithm"),
                imageWidth: optionalDouble(row, "image_width"),
                imageHeight: optionalDouble(row, "image_height"),
                pdfPageCount: optionalInt(row, "pdf_page_count"),
                teacherIncludedInExport: bool(row, "teacher_included_in_export"),
                createdAt: date(row, "created_at")
            )
        }
    }

    private func loadOCRDocument(assignmentID: String, in db: Database) throws -> OCRDocument? {
        let rows = try Row.fetchAll(db, sql: "SELECT * FROM grade_draft_ocr_lines WHERE assignment_id = ? ORDER BY page_index, rowid", arguments: [assignmentID])
        guard !rows.isEmpty else { return nil }
        let grouped = Dictionary(grouping: rows) { text($0, "page_id") }
        let pages: [OCRPage] = grouped.values.map { pageRows in
            let first = pageRows[0]
            let lines = pageRows.map { row in
                OCRLine(
                    id: uuid(row, "id"),
                    text: text(row, "raw_text"),
                    confidence: Float(double(row, "confidence")),
                    boundingBox: NormalizedRect(x: CGFloat(double(row, "bbox_x")), y: CGFloat(double(row, "bbox_y")), width: CGFloat(double(row, "bbox_width")), height: CGFloat(double(row, "bbox_height"))),
                    correctedText: optionalText(row, "corrected_text"),
                    teacherConfirmed: bool(row, "teacher_confirmed"),
                    isRejected: bool(row, "is_rejected")
                )
            }
            return OCRPage(
                id: uuid(first, "page_id"),
                sourceInputID: optionalUUID(first, "source_input_id"),
                pageIndex: int(first, "page_index"),
                lines: lines
            )
        }.sorted { $0.pageIndex < $1.pageIndex }
        let document = OCRDocument(pages: pages, reviewStatus: pages.flatMap(\.lines).contains { $0.needsReview } ? .needsReview : .reviewed)
        return document
    }

    private func loadLatestDraft(assignmentID: String, in db: Database) throws -> GradeDraftResult? {
        guard let row = try Row.fetchOne(db, sql: "SELECT * FROM grade_draft_drafts WHERE assignment_id = ? ORDER BY generated_at DESC LIMIT 1", arguments: [assignmentID]) else { return nil }
        let draftID = uuid(row, "id")
        let criteria = try Row.fetchAll(db, sql: "SELECT * FROM grade_draft_draft_criteria WHERE draft_id = ? ORDER BY rowid", arguments: [draftID.uuidString]).map { criterionRow in
            CriterionScore(
                id: uuid(criterionRow, "id"),
                criterionID: optionalText(criterionRow, "criterion_id"),
                criterion: text(criterionRow, "criterion"),
                rating: text(criterionRow, "rating"),
                proposedPoints: double(criterionRow, "proposed_points"),
                maxPoints: double(criterionRow, "max_points"),
                evidence: decodeJSONString(text(criterionRow, "evidence_json"), defaultValue: [String]()),
                evidenceSourceRefs: decodeJSONString(text(criterionRow, "evidence_refs_json"), defaultValue: [String]()),
                explanation: text(criterionRow, "explanation"),
                teacherReviewRequired: bool(criterionRow, "teacher_review_required"),
                nextStep: text(criterionRow, "next_step"),
                confidence: text(criterionRow, "confidence"),
                criterionUncertaintyFlags: decodeJSONString(text(criterionRow, "criterion_uncertainty_flags_json"), defaultValue: [String]())
            )
        }
        return GradeDraftResult(
            id: draftID,
            generatedAt: date(row, "generated_at"),
            packetFingerprint: text(row, "packet_fingerprint"),
            status: DraftStatus(rawValue: text(row, "status")) ?? .teacherReviewRequired,
            studentResponseSummary: text(row, "student_response_summary"),
            criteria: criteria,
            totalScore: double(row, "total_score"),
            maxScore: double(row, "max_score"),
            studentFeedback: text(row, "student_feedback"),
            teacherNotes: text(row, "teacher_notes"),
            uncertaintyFlags: decodeJSONString(text(row, "uncertainty_flags_json"), defaultValue: [String]()),
            complianceFlags: decodeJSONString(text(row, "compliance_flags_json"), defaultValue: [String]()),
            rawModelResponse: optionalText(row, "raw_model_response")
        )
    }

    private func loadFinalReview(assignmentID: String, in db: Database) throws -> FinalGradeReview? {
        guard let row = try Row.fetchOne(db, sql: "SELECT * FROM grade_draft_final_reviews WHERE assignment_id = ? ORDER BY created_at DESC LIMIT 1", arguments: [assignmentID]) else { return nil }
        let reviewID = uuid(row, "id")
        let criteria = try Row.fetchAll(db, sql: "SELECT * FROM grade_draft_final_criteria WHERE final_review_id = ? ORDER BY rowid", arguments: [reviewID.uuidString]).map { criterionRow in
            FinalCriterionScore(
                id: uuid(criterionRow, "id"),
                criterionID: optionalText(criterionRow, "criterion_id"),
                criterion: text(criterionRow, "criterion"),
                rating: text(criterionRow, "rating"),
                proposedPoints: double(criterionRow, "proposed_points"),
                finalPoints: double(criterionRow, "final_points"),
                maxPoints: double(criterionRow, "max_points"),
                evidence: decodeJSONString(text(criterionRow, "evidence_json"), defaultValue: [String]()),
                evidenceSourceRefs: decodeJSONString(text(criterionRow, "evidence_refs_json"), defaultValue: [String]()),
                explanation: text(criterionRow, "explanation"),
                teacherApproved: bool(criterionRow, "teacher_approved"),
                teacherRationale: text(criterionRow, "teacher_rationale")
            )
        }
        return FinalGradeReview(
            id: reviewID,
            createdAt: date(row, "created_at"),
            finalizedAt: optionalDate(row, "finalized_at"),
            packetFingerprint: text(row, "packet_fingerprint"),
            status: FinalReviewStatus(rawValue: text(row, "status")) ?? .inProgress,
            criteria: criteria,
            totalScore: double(row, "total_score"),
            maxScore: double(row, "max_score"),
            studentFeedback: text(row, "student_feedback"),
            privateTeacherNotes: text(row, "private_teacher_notes"),
            teacherEdited: bool(row, "teacher_edited")
        )
    }

    private func loadEvidenceReferences(assignmentID: String, in db: Database) throws -> [EvidenceReference] {
        try Row.fetchAll(db, sql: "SELECT * FROM grade_draft_evidence_references WHERE assignment_id = ? ORDER BY created_at", arguments: [assignmentID]).map { row in
            EvidenceReference(
                id: uuid(row, "id"),
                sourceInputID: optionalUUID(row, "source_input_id"),
                ocrLineID: optionalUUID(row, "ocr_line_id"),
                pageIndex: optionalInt(row, "page_index"),
                quote: text(row, "quote"),
                startOffset: optionalInt(row, "start_offset"),
                endOffset: optionalInt(row, "end_offset"),
                boundingBox: optionalDouble(row, "bbox_x").map { _ in NormalizedRect(x: CGFloat(double(row, "bbox_x")), y: CGFloat(double(row, "bbox_y")), width: CGFloat(double(row, "bbox_width")), height: CGFloat(double(row, "bbox_height"))) },
                sourceKind: text(row, "source_kind"),
                teacherConfirmed: bool(row, "teacher_confirmed"),
                createdAt: date(row, "created_at")
            )
        }
    }

    private func loadCurriculumMappings(assignmentID: String, in db: Database) throws -> [CurriculumMapping] {
        try Row.fetchAll(db, sql: "SELECT * FROM grade_draft_curriculum_mappings WHERE assignment_id = ? ORDER BY created_at", arguments: [assignmentID]).map { row in
            CurriculumMapping(
                id: uuid(row, "id"),
                curriculumItemID: text(row, "curriculum_item_id"),
                mappingKind: text(row, "mapping_kind"),
                rubricCriterionID: optionalText(row, "rubric_criterion_id"),
                evidenceReferenceID: optionalUUID(row, "evidence_reference_id"),
                teacherSelected: bool(row, "teacher_selected", defaultValue: true),
                createdAt: date(row, "created_at")
            )
        }
    }

    private func loadExportRecords(assignmentID: String, in db: Database) throws -> [ExportRecord] {
        try Row.fetchAll(db, sql: "SELECT * FROM grade_draft_export_records WHERE assignment_id = ? ORDER BY created_at", arguments: [assignmentID]).map { row in
            ExportRecord(
                id: uuid(row, "id"),
                exportKind: ExportKind(rawValue: text(row, "export_kind")) ?? .teacherAuditMarkdown,
                createdAt: date(row, "created_at"),
                contentFingerprint: text(row, "content_fingerprint"),
                includesPrivateTeacherNotes: bool(row, "includes_private_teacher_notes"),
                includesOriginalSources: bool(row, "includes_original_sources")
            )
        }
    }

    private func loadAuditEvents(assignmentID: String, in db: Database) throws -> [AuditEvent] {
        try Row.fetchAll(db, sql: "SELECT * FROM grade_draft_audit_events WHERE assignment_id = ? ORDER BY created_at", arguments: [assignmentID]).map { row in
            AuditEvent(
                id: uuid(row, "id"),
                timestamp: date(row, "created_at"),
                eventType: AuditEventType(rawValue: text(row, "event_type")) ?? .inputChanged,
                actor: text(row, "actor"),
                detail: text(row, "detail")
            )
        }
    }

    private func deleteAssignmentRows(id: String, in db: Database, keepPayload: Bool = false) throws {
        let tables = [
            "grade_draft_source_inputs", "grade_draft_ocr_lines", "grade_draft_drafts", "grade_draft_draft_criteria",
            "grade_draft_final_reviews", "grade_draft_final_criteria", "grade_draft_evidence_references", "grade_draft_curriculum_mappings",
            "grade_draft_export_records", "grade_draft_audit_events", "assignment_roster_entries"
        ]
        for table in tables {
            try db.execute(sql: "DELETE FROM \(table) WHERE assignment_id = ?", arguments: [id])
        }
        if !keepPayload { try db.execute(sql: "DELETE FROM grade_draft_assignment_records WHERE id = ?", arguments: [id]) }
        try db.execute(sql: "DELETE FROM grade_draft_assignments WHERE id = ?", arguments: [id])
    }

    // MARK: - Migrations

    private func registerMigrations(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("001_core_schema") { db in
            try self.createCoreTables(in: db)
            try self.createProductTables(in: db)
        }
        migrator.registerMigration("002_json_payload_compatibility") { db in
            try self.createCoreTables(in: db)
        }
        migrator.registerMigration("003_required_product_schema") { db in
            try self.createProductTables(in: db)
        }
        migrator.registerMigration("006_all_features_completion_v3") { db in
            try self.createCoreTables(in: db)
            try self.createProductTables(in: db)
            try self.addColumnIfNeeded(db, table: "grade_draft_assignments", column: "class_group_id", definition: "TEXT")
            try self.addColumnIfNeeded(db, table: "grade_draft_assignments", column: "student_id", definition: "TEXT")
            try self.addColumnIfNeeded(db, table: "grade_draft_assignments", column: "ocr_reviewed_at", definition: "TEXT")
            try self.addColumnIfNeeded(db, table: "grade_draft_ocr_lines", column: "is_rejected", definition: "BOOLEAN NOT NULL DEFAULT 0")
            try self.addColumnIfNeeded(db, table: "grade_draft_drafts", column: "student_response_summary", definition: "TEXT NOT NULL DEFAULT ''")
            try self.addColumnIfNeeded(db, table: "grade_draft_drafts", column: "uncertainty_flags_json", definition: "TEXT NOT NULL DEFAULT '[]'")
            try self.addColumnIfNeeded(db, table: "grade_draft_drafts", column: "compliance_flags_json", definition: "TEXT NOT NULL DEFAULT '[]'")
            try self.addColumnIfNeeded(db, table: "grade_draft_draft_criteria", column: "next_step", definition: "TEXT NOT NULL DEFAULT ''")
            try self.addColumnIfNeeded(db, table: "grade_draft_draft_criteria", column: "confidence", definition: "TEXT NOT NULL DEFAULT ''")
            try self.addColumnIfNeeded(db, table: "grade_draft_draft_criteria", column: "criterion_uncertainty_flags_json", definition: "TEXT NOT NULL DEFAULT '[]'")
            try self.addColumnIfNeeded(db, table: "grade_draft_curriculum_mappings", column: "rubric_criterion_id", definition: "TEXT")
            try self.addColumnIfNeeded(db, table: "grade_draft_curriculum_mappings", column: "evidence_reference_id", definition: "TEXT")
            try self.addColumnIfNeeded(db, table: "class_groups", column: "notes", definition: "TEXT")
            try self.addColumnIfNeeded(db, table: "class_groups", column: "is_archived", definition: "BOOLEAN NOT NULL DEFAULT 0")
            try self.migrateLegacyPayloads(in: db)
        }
    }

    private func createCoreTables(in db: Database) throws {
        try db.execute(sql: """
        CREATE TABLE IF NOT EXISTS grade_draft_assignment_records (id TEXT PRIMARY KEY, payload TEXT NOT NULL, updated_at TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS grade_draft_assignments (
            id TEXT PRIMARY KEY, class_group_id TEXT, student_id TEXT, title TEXT NOT NULL, prompt TEXT NOT NULL DEFAULT '',
            subject TEXT NOT NULL, grade_level TEXT NOT NULL, class_name TEXT NOT NULL DEFAULT '', student_display_name TEXT NOT NULL DEFAULT '',
            assignment_type TEXT NOT NULL, assessment_purpose TEXT NOT NULL DEFAULT 'summative', curriculum_reference TEXT NOT NULL DEFAULT '',
            rubric_text TEXT NOT NULL DEFAULT '', custom_instructions TEXT NOT NULL DEFAULT '', answer_key_text TEXT NOT NULL DEFAULT '',
            exemplar_text TEXT NOT NULL DEFAULT '', reviewed_student_text TEXT NOT NULL DEFAULT '', ocr_review_status TEXT NOT NULL DEFAULT 'notNeeded',
            ocr_reviewed_at TEXT, grading_packet_fingerprint TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL, updated_at TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS grade_draft_source_inputs (id TEXT PRIMARY KEY, assignment_id TEXT NOT NULL, source_type TEXT NOT NULL, page_index INTEGER, local_relative_path TEXT, file_name TEXT, mime_type TEXT, content_digest TEXT, digest_algorithm TEXT, image_width REAL, image_height REAL, pdf_page_count INTEGER, teacher_included_in_export BOOLEAN NOT NULL, created_at TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS grade_draft_ocr_lines (id TEXT PRIMARY KEY, assignment_id TEXT NOT NULL, page_id TEXT NOT NULL, source_input_id TEXT, page_index INTEGER NOT NULL, raw_text TEXT NOT NULL, corrected_text TEXT, confidence REAL NOT NULL, bbox_x REAL NOT NULL, bbox_y REAL NOT NULL, bbox_width REAL NOT NULL, bbox_height REAL NOT NULL, teacher_confirmed BOOLEAN NOT NULL, is_rejected BOOLEAN NOT NULL DEFAULT 0);
        CREATE TABLE IF NOT EXISTS grade_draft_drafts (id TEXT PRIMARY KEY, assignment_id TEXT NOT NULL, packet_fingerprint TEXT NOT NULL, status TEXT NOT NULL, total_score REAL NOT NULL, max_score REAL NOT NULL, student_feedback TEXT NOT NULL, teacher_notes TEXT NOT NULL, raw_model_response TEXT, generated_at TEXT NOT NULL, student_response_summary TEXT NOT NULL DEFAULT '', uncertainty_flags_json TEXT NOT NULL DEFAULT '[]', compliance_flags_json TEXT NOT NULL DEFAULT '[]');
        CREATE TABLE IF NOT EXISTS grade_draft_draft_criteria (id TEXT PRIMARY KEY, assignment_id TEXT NOT NULL, draft_id TEXT NOT NULL, criterion_id TEXT, criterion TEXT NOT NULL, rating TEXT NOT NULL, proposed_points REAL NOT NULL, max_points REAL NOT NULL, evidence_json TEXT NOT NULL, evidence_refs_json TEXT NOT NULL, explanation TEXT NOT NULL, teacher_review_required BOOLEAN NOT NULL, next_step TEXT NOT NULL DEFAULT '', confidence TEXT NOT NULL DEFAULT '', criterion_uncertainty_flags_json TEXT NOT NULL DEFAULT '[]');
        CREATE TABLE IF NOT EXISTS grade_draft_final_reviews (id TEXT PRIMARY KEY, assignment_id TEXT NOT NULL, packet_fingerprint TEXT NOT NULL, status TEXT NOT NULL, total_score REAL NOT NULL, max_score REAL NOT NULL, student_feedback TEXT NOT NULL, private_teacher_notes TEXT NOT NULL, teacher_edited BOOLEAN NOT NULL, created_at TEXT NOT NULL, finalized_at TEXT);
        CREATE TABLE IF NOT EXISTS grade_draft_final_criteria (id TEXT PRIMARY KEY, assignment_id TEXT NOT NULL, final_review_id TEXT NOT NULL, criterion_id TEXT, criterion TEXT NOT NULL, rating TEXT NOT NULL, proposed_points REAL NOT NULL, final_points REAL NOT NULL, max_points REAL NOT NULL, evidence_json TEXT NOT NULL, evidence_refs_json TEXT NOT NULL, explanation TEXT NOT NULL, teacher_approved BOOLEAN NOT NULL, teacher_rationale TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS grade_draft_evidence_references (id TEXT PRIMARY KEY, assignment_id TEXT NOT NULL, source_input_id TEXT, ocr_line_id TEXT, page_index INTEGER, quote TEXT NOT NULL, start_offset INTEGER, end_offset INTEGER, bbox_x REAL, bbox_y REAL, bbox_width REAL, bbox_height REAL, source_kind TEXT NOT NULL, teacher_confirmed BOOLEAN NOT NULL, created_at TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS grade_draft_curriculum_mappings (id TEXT PRIMARY KEY, assignment_id TEXT NOT NULL, curriculum_item_id TEXT NOT NULL, mapping_kind TEXT NOT NULL, rubric_criterion_id TEXT, evidence_reference_id TEXT, teacher_selected BOOLEAN NOT NULL, created_at TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS grade_draft_export_records (id TEXT PRIMARY KEY, assignment_id TEXT NOT NULL, export_kind TEXT NOT NULL, content_fingerprint TEXT NOT NULL, includes_private_teacher_notes BOOLEAN NOT NULL, includes_original_sources BOOLEAN NOT NULL, created_at TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS grade_draft_audit_events (id TEXT PRIMARY KEY, assignment_id TEXT NOT NULL, event_type TEXT NOT NULL, actor TEXT NOT NULL, detail TEXT NOT NULL, created_at TEXT NOT NULL);
        """)
    }

    private func createProductTables(in db: Database) throws {
        let statements = [
            "CREATE TABLE IF NOT EXISTS class_groups (id TEXT PRIMARY KEY, name TEXT NOT NULL, school_year TEXT, term TEXT, subject TEXT, year_level TEXT, notes TEXT, is_archived BOOLEAN NOT NULL DEFAULT 0, created_at TEXT NOT NULL, updated_at TEXT NOT NULL);",
            "CREATE TABLE IF NOT EXISTS students (id TEXT PRIMARY KEY, display_name TEXT NOT NULL, local_identifier TEXT, class_name TEXT, notes TEXT, is_active BOOLEAN NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL);",
            "CREATE TABLE IF NOT EXISTS class_students (id TEXT PRIMARY KEY, class_group_id TEXT NOT NULL, student_id TEXT NOT NULL, status TEXT, sort_order INTEGER, created_at TEXT NOT NULL);",
            "CREATE TABLE IF NOT EXISTS assignment_roster_entries (id TEXT PRIMARY KEY, assignment_id TEXT NOT NULL, student_id TEXT NOT NULL, student_display_name TEXT, local_identifier TEXT, status TEXT, sort_order INTEGER, created_at TEXT NOT NULL, updated_at TEXT NOT NULL);",
            "CREATE TABLE IF NOT EXISTS student_work (id TEXT PRIMARY KEY, assignment_id TEXT NOT NULL, student_id TEXT, reviewed_student_text TEXT, ocr_review_status TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL);",
            "CREATE TABLE IF NOT EXISTS source_inputs (id TEXT PRIMARY KEY, assignment_id TEXT, student_work_id TEXT, source_type TEXT, page_index INTEGER, local_relative_path TEXT, file_name TEXT, mime_type TEXT, content_digest TEXT, digest_algorithm TEXT, created_at TEXT NOT NULL);",
            "CREATE TABLE IF NOT EXISTS pdf_sources (id TEXT PRIMARY KEY, source_input_id TEXT NOT NULL, page_count INTEGER, digital_text_available BOOLEAN, created_at TEXT NOT NULL);",
            "CREATE TABLE IF NOT EXISTS ocr_documents (id TEXT PRIMARY KEY, student_work_id TEXT NOT NULL, engine TEXT, engine_version TEXT, review_status TEXT, created_at TEXT NOT NULL, reviewed_at TEXT);",
            "CREATE TABLE IF NOT EXISTS ocr_pages (id TEXT PRIMARY KEY, ocr_document_id TEXT NOT NULL, student_work_id TEXT, source_input_id TEXT, page_index INTEGER, width REAL, height REAL, created_at TEXT NOT NULL);",
            "CREATE TABLE IF NOT EXISTS ocr_lines (id TEXT PRIMARY KEY, ocr_page_id TEXT NOT NULL, source_input_id TEXT, raw_text TEXT, corrected_text TEXT, confidence REAL, bbox_x REAL, bbox_y REAL, bbox_width REAL, bbox_height REAL, teacher_confirmed BOOLEAN, is_rejected BOOLEAN, created_at TEXT NOT NULL);",
            "CREATE TABLE IF NOT EXISTS ocr_line_revisions (id TEXT PRIMARY KEY, ocr_line_id TEXT NOT NULL, previous_text TEXT, corrected_text TEXT, created_at TEXT NOT NULL);",
            "CREATE TABLE IF NOT EXISTS rubrics (id TEXT PRIMARY KEY, assignment_id TEXT, raw_markdown TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL);",
            "CREATE TABLE IF NOT EXISTS rubric_criteria (id TEXT PRIMARY KEY, rubric_id TEXT, title TEXT, max_points REAL, descriptor TEXT, group_title TEXT, sort_order INTEGER);",
            "CREATE TABLE IF NOT EXISTS rubric_levels (id TEXT PRIMARY KEY, criterion_id TEXT, label TEXT, min_points REAL, max_points REAL, descriptor TEXT, sort_order INTEGER);",
            "CREATE TABLE IF NOT EXISTS teacher_instructions (id TEXT PRIMARY KEY, assignment_id TEXT NOT NULL, body TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL);",
            "CREATE TABLE IF NOT EXISTS answer_keys (id TEXT PRIMARY KEY, assignment_id TEXT NOT NULL, body TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL);",
            "CREATE TABLE IF NOT EXISTS expected_elements (id TEXT PRIMARY KEY, assignment_id TEXT NOT NULL, body TEXT, sort_order INTEGER);",
            "CREATE TABLE IF NOT EXISTS exemplars (id TEXT PRIMARY KEY, assignment_id TEXT NOT NULL, body TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL);",
            "CREATE TABLE IF NOT EXISTS curriculum_items (id TEXT PRIMARY KEY, source TEXT, version TEXT, learning_area TEXT, subject TEXT, year_level TEXT, strand TEXT, organizer TEXT, item_type TEXT, code TEXT, title TEXT, description TEXT, source_url TEXT, provenance TEXT);",
            "CREATE TABLE IF NOT EXISTS curriculum_mappings (id TEXT PRIMARY KEY, assignment_id TEXT, rubric_criterion_id TEXT, student_work_id TEXT, curriculum_item_id TEXT NOT NULL, mapping_kind TEXT, teacher_selected BOOLEAN, created_at TEXT NOT NULL);",
            "CREATE TABLE IF NOT EXISTS grading_packets (id TEXT PRIMARY KEY, student_work_id TEXT, assignment_id TEXT NOT NULL, rubric_id TEXT, packet_fingerprint TEXT NOT NULL, reviewed_text_snapshot TEXT, prompt_snapshot TEXT, teacher_instructions_snapshot TEXT, answer_key_snapshot TEXT, exemplar_snapshot TEXT, curriculum_snapshot TEXT, created_at TEXT NOT NULL);",
            "CREATE TABLE IF NOT EXISTS grade_proposals (id TEXT PRIMARY KEY, grading_packet_id TEXT, assignment_id TEXT, generated_at TEXT NOT NULL, status TEXT, student_response_summary TEXT, total_score REAL, max_score REAL, student_feedback TEXT, teacher_notes TEXT, raw_model_response TEXT, uncertainty_flags_json TEXT, compliance_flags_json TEXT);",
            "CREATE TABLE IF NOT EXISTS grade_proposal_criteria (id TEXT PRIMARY KEY, grade_proposal_id TEXT NOT NULL, criterion_id TEXT, criterion_title TEXT, rating TEXT, proposed_points REAL, max_points REAL, explanation TEXT, teacher_review_required BOOLEAN, sort_order INTEGER);",
            "CREATE TABLE IF NOT EXISTS teacher_reviews (id TEXT PRIMARY KEY, assignment_id TEXT NOT NULL, status TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL);",
            "CREATE TABLE IF NOT EXISTS final_reviews (id TEXT PRIMARY KEY, student_work_id TEXT, assignment_id TEXT, grading_packet_id TEXT, packet_fingerprint TEXT, status TEXT, total_score REAL, max_score REAL, student_feedback TEXT, private_teacher_notes TEXT, teacher_edited BOOLEAN, created_at TEXT NOT NULL, finalized_at TEXT);",
            "CREATE TABLE IF NOT EXISTS final_review_criteria (id TEXT PRIMARY KEY, final_review_id TEXT NOT NULL, criterion_id TEXT, criterion_title TEXT, rating TEXT, proposed_points REAL, final_points REAL, max_points REAL, explanation TEXT, teacher_rationale TEXT, teacher_approved BOOLEAN, sort_order INTEGER);",
            "CREATE TABLE IF NOT EXISTS evidence_references (id TEXT PRIMARY KEY, assignment_id TEXT, source_input_id TEXT, ocr_line_id TEXT, page_index INTEGER, quote TEXT, start_offset INTEGER, end_offset INTEGER, bbox_x REAL, bbox_y REAL, bbox_width REAL, bbox_height REAL, source_kind TEXT, teacher_confirmed BOOLEAN, created_at TEXT NOT NULL);",
            "CREATE TABLE IF NOT EXISTS export_records (id TEXT PRIMARY KEY, assignment_id TEXT, final_review_id TEXT, export_type TEXT, file_name TEXT, local_path TEXT, content_fingerprint TEXT, created_at TEXT NOT NULL, includes_student_feedback BOOLEAN, includes_teacher_notes BOOLEAN, includes_audit_trail BOOLEAN, includes_original_sources BOOLEAN);",
            "CREATE TABLE IF NOT EXISTS audit_events (id TEXT PRIMARY KEY, entity_type TEXT, entity_id TEXT, assignment_id TEXT, event_type TEXT, event_timestamp TEXT NOT NULL, details TEXT);",
            "CREATE TABLE IF NOT EXISTS backup_restore_events (id TEXT PRIMARY KEY, archive_id TEXT, event_type TEXT, details TEXT, created_at TEXT NOT NULL);"
        ]
        for statement in statements { try db.execute(sql: statement) }
    }

    private func addColumnIfNeeded(_ db: Database, table: String, column: String, definition: String) throws {
        let existing = try db.columns(in: table).map(\.name)
        if !existing.contains(column) {
            try db.execute(sql: "ALTER TABLE \(table) ADD COLUMN \(column) \(definition)")
        }
    }

    private func migrateLegacyPayloads(in db: Database) throws {
        let payloads = try Row.fetchAll(db, sql: "SELECT id, payload FROM grade_draft_assignment_records")
        for row in payloads {
            let idValue = text(row, "id")
            let exists = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM grade_draft_assignments WHERE id = ?", arguments: [idValue]) ?? 0
            guard exists == 0, let data = text(row, "payload").data(using: .utf8) else { continue }
            if let assignment = try? jsonDecoder.decode(AssignmentRecord.self, from: data) {
                try saveNormalizedAssignment(assignment, in: db)
            }
        }
    }

    // MARK: - Utilities

    private func jsonString<T: Encodable>(_ value: T) throws -> String {
        let data = try jsonEncoder.encode(value)
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    private func decodeJSONString<T: Decodable>(_ value: String, defaultValue: T) -> T {
        guard let data = value.data(using: .utf8) else { return defaultValue }
        return (try? jsonDecoder.decode(T.self, from: data)) ?? defaultValue
    }

    nonisolated(unsafe) private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private var iso8601: ISO8601DateFormatter { Self.iso8601 }

    private func text(_ row: Row, _ column: String, defaultValue: String = "") -> String { optionalText(row, column) ?? defaultValue }
    private func optionalText(_ row: Row, _ column: String) -> String? { let value: String? = row[column]; return value }
    private func int(_ row: Row, _ column: String, defaultValue: Int = 0) -> Int { optionalInt(row, column) ?? defaultValue }
    private func optionalInt(_ row: Row, _ column: String) -> Int? { let value: Int? = row[column]; return value }
    private func double(_ row: Row, _ column: String, defaultValue: Double = 0) -> Double { optionalDouble(row, column) ?? defaultValue }
    private func optionalDouble(_ row: Row, _ column: String) -> Double? { let value: Double? = row[column]; return value }
    private func bool(_ row: Row, _ column: String, defaultValue: Bool = false) -> Bool { let value: Bool? = row[column]; return value ?? defaultValue }
    private func uuid(_ row: Row, _ column: String) -> UUID { UUID(uuidString: text(row, column)) ?? UUID() }
    private func optionalUUID(_ row: Row, _ column: String) -> UUID? { optionalText(row, column).flatMap(UUID.init(uuidString:)) }
    private func date(_ row: Row, _ column: String) -> Date { optionalDate(row, column) ?? Date() }
    private func optionalDate(_ row: Row, _ column: String) -> Date? {
        guard let value = optionalText(row, column), !value.isEmpty else { return nil }
        return iso8601.date(from: value)
    }
}
