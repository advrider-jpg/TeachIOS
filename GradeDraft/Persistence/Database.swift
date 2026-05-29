import Foundation
import GRDB

enum GradeDraftDatabaseError: Error, LocalizedError {
    case missingStoreRoot
    case migrationFailed(String)
    case preflightFailed(String)
    case dataCorrupted(String)
}

struct DatabaseBackupDescriptor: Codable {
    let assignmentCount: Int
    let exportCreatedAt: Date
}

/// GRDB entry point for GradeDraft local persistence.
/// Runtime persistence mirrors product data into normalized SQLite tables and retains
/// a legacy JSON payload table only as a lossless compatibility/export backup.
final class GradeDraftDatabase {
    private let databaseQueue: DatabaseQueue
    private let migrations = DatabaseMigrator()
    private let jsonDecoder = JSONDecoder()
    private let jsonEncoder = JSONEncoder()
    private let resolvedDatabaseFolder: URL

    init(applicationSupportURL: URL? = nil) throws {
        let baseURL = applicationSupportURL
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first

        guard let baseURL else {
            throw GradeDraftDatabaseError.missingStoreRoot
        }

        resolvedDatabaseFolder = baseURL.appendingPathComponent("GradeDraft", isDirectory: true)
        try FileManager.default.createDirectory(at: resolvedDatabaseFolder, withIntermediateDirectories: true)

        let dbURL = resolvedDatabaseFolder.appendingPathComponent("gradedraft.sqlite")
        databaseQueue = try DatabaseQueue(path: dbURL.path)
    }

    func loadAssignments() throws -> [AssignmentRecord] {
        try databaseQueue.read { db in
            let payloads = try String.fetchAll(db, sql: "SELECT payload FROM grade_draft_assignment_records ORDER BY updated_at DESC")
            return payloads.map { payload in
                guard let data = payload.data(using: .utf8) else {
                    throw GradeDraftDatabaseError.dataCorrupted("Unable to decode assignment payload bytes.")
                }
                do {
                    return try jsonDecoder.decode(AssignmentRecord.self, from: data)
                } catch {
                    throw GradeDraftDatabaseError.dataCorrupted("Could not decode assignment payload: \(error.localizedDescription)")
                }
            }
        }
    }

    func saveAssignments(_ assignments: [AssignmentRecord]) throws {
        try databaseQueue.write { db in
            for assignment in assignments {
                let payload = try jsonEncoder.encode(assignment)
                let payloadText = String(data: payload, encoding: .utf8) ?? "[]"
                let updatedAt = iso8601.string(from: assignment.updatedAt)
                let id = assignment.id.uuidString
                try db.execute(
                    sql: """
                    INSERT INTO grade_draft_assignment_records (id, payload, updated_at)
                    VALUES (?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET payload = excluded.payload, updated_at = excluded.updated_at
                    """,
                    arguments: [id, payloadText, updatedAt]
                )
                try saveNormalizedAssignment(assignment, in: db)
            }
        }
    }

    func deleteAssignment(id: UUID) throws {
        try databaseQueue.write { db in
            for table in Self.normalizedChildTables {
                try db.execute(sql: "DELETE FROM \(table) WHERE assignment_id = ?", arguments: [id.uuidString])
            }
            try db.execute(sql: "DELETE FROM grade_draft_final_reviews WHERE assignment_id = ?", arguments: [id.uuidString])
            try db.execute(sql: "DELETE FROM grade_draft_drafts WHERE assignment_id = ?", arguments: [id.uuidString])
            try db.execute(sql: "DELETE FROM grade_draft_assignment_records WHERE id = ?", arguments: [id.uuidString])
            try db.execute(sql: "DELETE FROM grade_draft_assignments WHERE id = ?", arguments: [id.uuidString])
        }
    }

    func applicationSupportDirectory() throws -> URL {
        resolvedDatabaseFolder
    }

    func bootstrapIfNeeded() throws {
        var migrator = migrations
        registerMigrations(&migrator)
        do {
            try migrator.migrate(databaseQueue)
        } catch {
            throw GradeDraftDatabaseError.migrationFailed(error.localizedDescription)
        }
    }

    func preflightAuditBundle() throws -> URL {
        let backupFolder = resolvedDatabaseFolder.appendingPathComponent("Backup", isDirectory: true)
        try FileManager.default.createDirectory(at: backupFolder, withIntermediateDirectories: true)

        var valuesAreWritable = false
        try backupFolder.withUnsafeFileSystemRepresentation { representation in
            guard let path = representation else {
                throw GradeDraftDatabaseError.preflightFailed("Could not resolve backup folder path.")
            }
            valuesAreWritable = FileManager.default.isWritableFile(atPath: String(cString: path))
        }

        if !valuesAreWritable {
            throw GradeDraftDatabaseError.preflightFailed("Backup folder is not writable.")
        }
        return backupFolder
    }

    func readBackupDescriptor() throws -> DatabaseBackupDescriptor {
        let dbURL = resolvedDatabaseFolder.appendingPathComponent("gradedraft.sqlite")
        guard FileManager.default.fileExists(atPath: dbURL.path) else {
            return DatabaseBackupDescriptor(assignmentCount: 0, exportCreatedAt: Date())
        }

        let assignmentRowCount = try databaseQueue.read { db in
            let value = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM grade_draft_assignment_records") ?? 0
            return value
        }
        return DatabaseBackupDescriptor(
            assignmentCount: assignmentRowCount,
            exportCreatedAt: Date()
        )
    }


    nonisolated(unsafe) private static let normalizedChildTables = [
        "grade_draft_source_inputs",
        "grade_draft_ocr_lines",
        "grade_draft_draft_criteria",
        "grade_draft_final_criteria",
        "grade_draft_evidence_references",
        "grade_draft_curriculum_mappings",
        "grade_draft_export_records",
        "grade_draft_audit_events"
    ]

    private func saveNormalizedAssignment(_ assignment: AssignmentRecord, in db: Database) throws {
        let id = assignment.id.uuidString
        for table in Self.normalizedChildTables {
            try db.execute(sql: "DELETE FROM \(table) WHERE assignment_id = ?", arguments: [id])
        }
        try db.execute(sql: "DELETE FROM grade_draft_final_reviews WHERE assignment_id = ?", arguments: [id])
        try db.execute(sql: "DELETE FROM grade_draft_drafts WHERE assignment_id = ?", arguments: [id])

        try db.execute(sql: """
        INSERT INTO grade_draft_assignments (
            id, title, prompt, subject, grade_level, class_name, student_display_name,
            assignment_type, assessment_purpose, curriculum_reference, rubric_text,
            custom_instructions, answer_key_text, exemplar_text, reviewed_student_text,
            ocr_review_status, grading_packet_fingerprint, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            title = excluded.title,
            prompt = excluded.prompt,
            subject = excluded.subject,
            grade_level = excluded.grade_level,
            class_name = excluded.class_name,
            student_display_name = excluded.student_display_name,
            assignment_type = excluded.assignment_type,
            assessment_purpose = excluded.assessment_purpose,
            curriculum_reference = excluded.curriculum_reference,
            rubric_text = excluded.rubric_text,
            custom_instructions = excluded.custom_instructions,
            answer_key_text = excluded.answer_key_text,
            exemplar_text = excluded.exemplar_text,
            reviewed_student_text = excluded.reviewed_student_text,
            ocr_review_status = excluded.ocr_review_status,
            grading_packet_fingerprint = excluded.grading_packet_fingerprint,
            updated_at = excluded.updated_at
        """, arguments: [
            id,
            assignment.title,
            assignment.prompt ?? "",
            assignment.subject,
            assignment.gradeLevel,
            assignment.className,
            assignment.studentDisplayName,
            assignment.assignmentType.rawValue,
            assignment.assessmentPurpose.rawValue,
            assignment.curriculumReference,
            assignment.rubricText,
            assignment.customInstructions,
            assignment.answerKeyText,
            assignment.exemplarText,
            assignment.reviewedStudentText,
            assignment.ocrReviewStatus.rawValue,
            assignment.gradingPacketFingerprint,
            iso8601.string(from: assignment.createdAt),
            iso8601.string(from: assignment.updatedAt)
        ])

        for source in assignment.sourceInputs {
            try db.execute(sql: """
            INSERT INTO grade_draft_source_inputs (id, assignment_id, source_type, page_index, local_relative_path, file_name, mime_type, content_digest, digest_algorithm, image_width, image_height, pdf_page_count, teacher_included_in_export, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, arguments: [source.id.uuidString, id, source.sourceType.rawValue, source.pageIndex, source.localRelativePath, source.fileName, source.mimeType, source.contentDigest, source.digestAlgorithm, source.imageWidth, source.imageHeight, source.pdfPageCount, source.teacherIncludedInExport, iso8601.string(from: source.createdAt)])
        }

        if let document = assignment.ocrDocument {
            for page in document.pages {
                for line in page.lines {
                    try db.execute(sql: """
                    INSERT INTO grade_draft_ocr_lines (id, assignment_id, page_id, source_input_id, page_index, raw_text, corrected_text, confidence, bbox_x, bbox_y, bbox_width, bbox_height, teacher_confirmed)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """, arguments: [line.id.uuidString, id, page.id.uuidString, page.sourceInputID?.uuidString, page.pageIndex, line.rawText, line.correctedText, line.confidence, Double(line.boundingBox.x), Double(line.boundingBox.y), Double(line.boundingBox.width), Double(line.boundingBox.height), line.teacherConfirmed])
                }
            }
        }

        if let draft = assignment.latestDraft {
            try db.execute(sql: """
            INSERT INTO grade_draft_drafts (id, assignment_id, packet_fingerprint, status, total_score, max_score, student_feedback, teacher_notes, raw_model_response, generated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, arguments: [draft.id.uuidString, id, draft.packetFingerprint, draft.status.rawValue, draft.totalScore, draft.maxScore, draft.studentFeedback, draft.teacherNotes, draft.rawModelResponse, iso8601.string(from: draft.generatedAt)])
            for criterion in draft.criteria {
                try db.execute(sql: """
                INSERT INTO grade_draft_draft_criteria (id, assignment_id, draft_id, criterion_id, criterion, rating, proposed_points, max_points, evidence_json, evidence_refs_json, explanation, teacher_review_required)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, arguments: [criterion.id.uuidString, id, draft.id.uuidString, criterion.criterionID, criterion.criterion, criterion.rating, criterion.proposedPoints, criterion.maxPoints, jsonString(criterion.evidence), jsonString(criterion.evidenceSourceRefs), criterion.explanation, criterion.teacherReviewRequired])
            }
        }

        if let final = assignment.finalReview {
            try db.execute(sql: """
            INSERT INTO grade_draft_final_reviews (id, assignment_id, packet_fingerprint, status, total_score, max_score, student_feedback, private_teacher_notes, teacher_edited, created_at, finalized_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, arguments: [final.id.uuidString, id, final.packetFingerprint, final.status.rawValue, final.totalScore, final.maxScore, final.studentFeedback, final.privateTeacherNotes, final.teacherEdited, iso8601.string(from: final.createdAt), final.finalizedAt.map { iso8601.string(from: $0) }])
            for criterion in final.criteria {
                try db.execute(sql: """
                INSERT INTO grade_draft_final_criteria (id, assignment_id, final_review_id, criterion_id, criterion, rating, proposed_points, final_points, max_points, evidence_json, evidence_refs_json, explanation, teacher_approved, teacher_rationale)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, arguments: [criterion.id.uuidString, id, final.id.uuidString, criterion.criterionID, criterion.criterion, criterion.rating, criterion.proposedPoints, criterion.finalPoints, criterion.maxPoints, jsonString(criterion.evidence), jsonString(criterion.evidenceSourceRefs ?? []), criterion.explanation, criterion.teacherApproved, criterion.teacherRationale])
            }
        }

        for evidence in assignment.evidenceReferences {
            try db.execute(sql: """
            INSERT INTO grade_draft_evidence_references (id, assignment_id, source_input_id, ocr_line_id, page_index, quote, start_offset, end_offset, bbox_x, bbox_y, bbox_width, bbox_height, source_kind, teacher_confirmed, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, arguments: [evidence.id.uuidString, id, evidence.sourceInputID?.uuidString, evidence.ocrLineID?.uuidString, evidence.pageIndex, evidence.quote, evidence.startOffset, evidence.endOffset, evidence.boundingBox.map { Double($0.x) }, evidence.boundingBox.map { Double($0.y) }, evidence.boundingBox.map { Double($0.width) }, evidence.boundingBox.map { Double($0.height) }, evidence.sourceKind, evidence.teacherConfirmed, iso8601.string(from: evidence.createdAt)])
        }
        for mapping in assignment.curriculumMappings {
            try db.execute(sql: """
            INSERT INTO grade_draft_curriculum_mappings (id, assignment_id, curriculum_item_id, mapping_kind, teacher_selected, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """, arguments: [mapping.id.uuidString, id, mapping.curriculumItemID, mapping.mappingKind, mapping.teacherSelected, iso8601.string(from: mapping.createdAt)])
        }

        for export in assignment.exportRecords {
            try db.execute(sql: """
            INSERT INTO grade_draft_export_records (id, assignment_id, export_kind, content_fingerprint, includes_private_teacher_notes, includes_original_sources, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """, arguments: [export.id.uuidString, id, export.exportKind.rawValue, export.contentFingerprint, export.includesPrivateTeacherNotes, export.includesOriginalSources, iso8601.string(from: export.createdAt)])
        }
        for event in assignment.auditEvents {
            try db.execute(sql: """
            INSERT INTO grade_draft_audit_events (id, assignment_id, event_type, actor, detail, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """, arguments: [event.id.uuidString, id, event.eventType.rawValue, event.actor, event.detail, iso8601.string(from: event.timestamp)])
        }
    }

    private func jsonString<T: Encodable>(_ value: T) throws -> String {
        let data = try jsonEncoder.encode(value)
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    nonisolated(unsafe) private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private var iso8601: ISO8601DateFormatter {
        Self.iso8601
    }

    private func registerMigrations(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("001_core_schema") { db in
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS grade_draft_assignments (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                subject TEXT NOT NULL,
                grade_level TEXT NOT NULL,
                assignment_type TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );
            """)
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS grade_draft_audit_ledger (
                id TEXT PRIMARY KEY,
                assignment_id TEXT NOT NULL,
                event_type TEXT NOT NULL,
                event_detail TEXT NOT NULL,
                created_at TEXT NOT NULL
            );
            """)
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS grade_draft_exports (
                id TEXT PRIMARY KEY,
                assignment_id TEXT NOT NULL,
                export_kind TEXT NOT NULL,
                payload_path TEXT NOT NULL,
                created_at TEXT NOT NULL
            );
            """)
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_audit_assignment_id ON grade_draft_audit_ledger(assignment_id);")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_exports_assignment_id ON grade_draft_exports(assignment_id);")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_exports_created_at ON grade_draft_exports(created_at);")
        }

        migrator.registerMigration("002_assignment_records_json") { db in
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS grade_draft_assignment_records (
                id TEXT PRIMARY KEY,
                payload TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );
            """)
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_assignment_records_updated_at ON grade_draft_assignment_records(updated_at);")
        }

        migrator.registerMigration("003_audit_replay_guardrails") { db in
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS grade_draft_bundle_backup_preflight (
                id TEXT PRIMARY KEY,
                assignment_id TEXT NOT NULL,
                packet_digest TEXT NOT NULL,
                expected_items INTEGER NOT NULL,
                checked_at TEXT NOT NULL
            );
            """)
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_backup_preflight_assignment_id ON grade_draft_bundle_backup_preflight(assignment_id);")
        }




        migrator.registerMigration("005_required_product_schema_tables") { db in
            let statements = [
                """
                CREATE TABLE IF NOT EXISTS class_groups (
                    id TEXT PRIMARY KEY, name TEXT NOT NULL, school_year TEXT, term TEXT,
                    jurisdiction TEXT, sector TEXT, year_level TEXT, subject TEXT,
                    created_at TEXT NOT NULL, updated_at TEXT NOT NULL, archived_at TEXT
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS students (
                    id TEXT PRIMARY KEY, display_name TEXT NOT NULL, local_identifier TEXT, notes TEXT,
                    created_at TEXT NOT NULL, updated_at TEXT NOT NULL, archived_at TEXT
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS class_students (
                    class_id TEXT NOT NULL, student_id TEXT NOT NULL, status TEXT NOT NULL, sort_order INTEGER NOT NULL,
                    created_at TEXT NOT NULL, PRIMARY KEY (class_id, student_id)
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS assignments (
                    id TEXT PRIMARY KEY, class_id TEXT, title TEXT NOT NULL, prompt TEXT, subject TEXT,
                    grade_level TEXT, assignment_type TEXT, assessment_purpose TEXT, curriculum_reference TEXT,
                    rubric_id TEXT, teacher_instructions TEXT, answer_key_id TEXT, exemplar_id TEXT,
                    created_at TEXT NOT NULL, updated_at TEXT NOT NULL, archived_at TEXT
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS assignment_roster_entries (
                    id TEXT PRIMARY KEY, assignment_id TEXT NOT NULL, student_id TEXT NOT NULL, status TEXT NOT NULL,
                    sort_order INTEGER NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS student_work (
                    id TEXT PRIMARY KEY, assignment_id TEXT NOT NULL, student_id TEXT, legacy_assignment_record_id TEXT,
                    reviewed_student_text TEXT, ocr_review_status TEXT, ocr_reviewed_at TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS source_inputs (
                    id TEXT PRIMARY KEY, student_work_id TEXT NOT NULL, source_type TEXT NOT NULL, local_relative_path TEXT,
                    file_name TEXT, mime_type TEXT, page_index INTEGER, content_digest TEXT, digest_algorithm TEXT,
                    image_width REAL, image_height REAL, pdf_page_count INTEGER, teacher_included_in_export BOOLEAN NOT NULL, created_at TEXT NOT NULL
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS pdf_sources (
                    id TEXT PRIMARY KEY, source_input_id TEXT NOT NULL, page_count INTEGER NOT NULL,
                    digital_text_available BOOLEAN NOT NULL, extracted_text TEXT, rendered_page_folder TEXT, created_at TEXT NOT NULL
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS ocr_documents (
                    id TEXT PRIMARY KEY, student_work_id TEXT NOT NULL, engine TEXT, engine_version TEXT, review_status TEXT,
                    created_at TEXT NOT NULL, reviewed_at TEXT, quality_line_count INTEGER, quality_low_confidence_count INTEGER,
                    quality_unconfirmed_count INTEGER, quality_average_confidence REAL, quality_minimum_confidence REAL
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS ocr_pages (
                    id TEXT PRIMARY KEY, ocr_document_id TEXT NOT NULL, source_input_id TEXT, page_index INTEGER,
                    image_width REAL, image_height REAL
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS ocr_lines (
                    id TEXT PRIMARY KEY, ocr_page_id TEXT NOT NULL, line_index INTEGER, raw_text TEXT NOT NULL,
                    corrected_text TEXT, reviewed_text TEXT NOT NULL, confidence REAL, bounding_x REAL, bounding_y REAL,
                    bounding_width REAL, bounding_height REAL, review_status TEXT, teacher_confirmed BOOLEAN NOT NULL,
                    reviewed_at TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS ocr_line_revisions (
                    id TEXT PRIMARY KEY, ocr_line_id TEXT NOT NULL, previous_text TEXT, new_text TEXT, review_action TEXT, created_at TEXT NOT NULL
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS evidence_references (
                    id TEXT PRIMARY KEY, student_work_id TEXT NOT NULL, source_input_id TEXT, ocr_line_id TEXT, page_index INTEGER,
                    quote TEXT NOT NULL, start_offset INTEGER, end_offset INTEGER, bounding_x REAL, bounding_y REAL,
                    bounding_width REAL, bounding_height REAL, source_kind TEXT, teacher_confirmed BOOLEAN NOT NULL, created_at TEXT NOT NULL
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS rubrics (id TEXT PRIMARY KEY, title TEXT NOT NULL, description TEXT, source TEXT, total_possible_points REAL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, archived_at TEXT);
                """,
                """
                CREATE TABLE IF NOT EXISTS rubric_criteria (id TEXT PRIMARY KEY, rubric_id TEXT NOT NULL, stable_id TEXT, title TEXT NOT NULL, description TEXT, max_points REAL, evidence_required BOOLEAN, sort_order INTEGER);
                """,
                """
                CREATE TABLE IF NOT EXISTS rubric_levels (id TEXT PRIMARY KEY, criterion_id TEXT NOT NULL, label TEXT, min_points REAL, max_points REAL, descriptor TEXT, sort_order INTEGER);
                """,
                """
                CREATE TABLE IF NOT EXISTS teacher_instructions (id TEXT PRIMARY KEY, assignment_id TEXT, scope TEXT, text TEXT NOT NULL, priority TEXT, student_facing BOOLEAN, private_teacher_only BOOLEAN, created_at TEXT NOT NULL);
                """,
                """
                CREATE TABLE IF NOT EXISTS answer_keys (id TEXT PRIMARY KEY, assignment_id TEXT, prompt TEXT, exact_answer TEXT, teacher_notes TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL);
                """,
                """
                CREATE TABLE IF NOT EXISTS answer_key_elements (id TEXT PRIMARY KEY, answer_key_id TEXT NOT NULL, description TEXT NOT NULL, required BOOLEAN, point_value REAL, acceptable_wording TEXT, evidence_required BOOLEAN);
                """,
                """
                CREATE TABLE IF NOT EXISTS exemplars (id TEXT PRIMARY KEY, assignment_id TEXT, title TEXT, text TEXT, source TEXT, quality_level TEXT, use_for_scoring BOOLEAN, teacher_notes TEXT, created_at TEXT NOT NULL);
                """,
                """
                CREATE TABLE IF NOT EXISTS curriculum_sources (id TEXT PRIMARY KEY, name TEXT NOT NULL, version TEXT, source_url TEXT, local_path TEXT, imported_at TEXT NOT NULL);
                """,
                """
                CREATE TABLE IF NOT EXISTS curriculum_items (id TEXT PRIMARY KEY, source_id TEXT, external_id TEXT, learning_area TEXT, subject TEXT, year_level TEXT, strand TEXT, substrand TEXT, item_type TEXT, code TEXT, title TEXT, short_description TEXT, source_url TEXT, version TEXT, created_at TEXT NOT NULL);
                """,
                """
                CREATE TABLE IF NOT EXISTS curriculum_mappings (id TEXT PRIMARY KEY, assignment_id TEXT, rubric_id TEXT, rubric_criterion_id TEXT, student_work_id TEXT, curriculum_item_id TEXT NOT NULL, mapping_kind TEXT, teacher_selected BOOLEAN, created_at TEXT NOT NULL);
                """,
                """
                CREATE TABLE IF NOT EXISTS grading_packets (id TEXT PRIMARY KEY, student_work_id TEXT NOT NULL, assignment_id TEXT NOT NULL, rubric_id TEXT, packet_fingerprint TEXT NOT NULL, reviewed_text_snapshot TEXT, prompt_snapshot TEXT, teacher_instructions_snapshot TEXT, answer_key_snapshot TEXT, exemplar_snapshot TEXT, curriculum_snapshot TEXT, created_at TEXT NOT NULL);
                """,
                """
                CREATE TABLE IF NOT EXISTS grade_proposals (id TEXT PRIMARY KEY, grading_packet_id TEXT NOT NULL, generated_at TEXT NOT NULL, status TEXT, student_response_summary TEXT, total_score REAL, max_score REAL, student_feedback TEXT, teacher_notes TEXT, raw_model_response TEXT, uncertainty_flags_json TEXT, compliance_flags_json TEXT);
                """,
                """
                CREATE TABLE IF NOT EXISTS criterion_scores (id TEXT PRIMARY KEY, grade_proposal_id TEXT NOT NULL, criterion_id TEXT, criterion_title TEXT, rating TEXT, proposed_points REAL, max_points REAL, explanation TEXT, teacher_review_required BOOLEAN, next_step TEXT, confidence TEXT, sort_order INTEGER);
                """,
                """
                CREATE TABLE IF NOT EXISTS final_reviews (id TEXT PRIMARY KEY, student_work_id TEXT NOT NULL, grading_packet_id TEXT, packet_fingerprint TEXT, status TEXT, total_score REAL, max_score REAL, student_feedback TEXT, private_teacher_notes TEXT, teacher_edited BOOLEAN, created_at TEXT NOT NULL, finalized_at TEXT);
                """,
                """
                CREATE TABLE IF NOT EXISTS final_criterion_scores (id TEXT PRIMARY KEY, final_review_id TEXT NOT NULL, criterion_id TEXT, criterion_title TEXT, rating TEXT, proposed_points REAL, final_points REAL, max_points REAL, explanation TEXT, teacher_rationale TEXT, teacher_approved BOOLEAN, sort_order INTEGER);
                """,
                """
                CREATE TABLE IF NOT EXISTS proposal_criterion_evidence (criterion_score_id TEXT NOT NULL, evidence_reference_id TEXT NOT NULL, PRIMARY KEY (criterion_score_id, evidence_reference_id));
                """,
                """
                CREATE TABLE IF NOT EXISTS final_criterion_evidence (final_criterion_score_id TEXT NOT NULL, evidence_reference_id TEXT NOT NULL, PRIMARY KEY (final_criterion_score_id, evidence_reference_id));
                """,
                """
                CREATE TABLE IF NOT EXISTS export_records (id TEXT PRIMARY KEY, final_review_id TEXT, export_type TEXT, file_name TEXT, local_path TEXT, created_at TEXT NOT NULL, includes_student_feedback BOOLEAN, includes_teacher_notes BOOLEAN, includes_audit_trail BOOLEAN);
                """,
                """
                CREATE TABLE IF NOT EXISTS backup_records (id TEXT PRIMARY KEY, backup_kind TEXT, manifest_json TEXT, local_path TEXT, created_at TEXT NOT NULL, restored_at TEXT);
                """,
                """
                CREATE TABLE IF NOT EXISTS audit_events (id TEXT PRIMARY KEY, entity_type TEXT, entity_id TEXT, event_type TEXT, event_timestamp TEXT NOT NULL, details TEXT);
                """
            ]
            for statement in statements { try db.execute(sql: statement) }
        }

        migrator.registerMigration("004_normalized_product_schema") { db in
            try db.execute(sql: "ALTER TABLE grade_draft_assignments ADD COLUMN prompt TEXT NOT NULL DEFAULT ''")
            try db.execute(sql: "ALTER TABLE grade_draft_assignments ADD COLUMN class_name TEXT NOT NULL DEFAULT ''")
            try db.execute(sql: "ALTER TABLE grade_draft_assignments ADD COLUMN student_display_name TEXT NOT NULL DEFAULT ''")
            try db.execute(sql: "ALTER TABLE grade_draft_assignments ADD COLUMN assessment_purpose TEXT NOT NULL DEFAULT 'summative'")
            try db.execute(sql: "ALTER TABLE grade_draft_assignments ADD COLUMN curriculum_reference TEXT NOT NULL DEFAULT ''")
            try db.execute(sql: "ALTER TABLE grade_draft_assignments ADD COLUMN rubric_text TEXT NOT NULL DEFAULT ''")
            try db.execute(sql: "ALTER TABLE grade_draft_assignments ADD COLUMN custom_instructions TEXT NOT NULL DEFAULT ''")
            try db.execute(sql: "ALTER TABLE grade_draft_assignments ADD COLUMN answer_key_text TEXT NOT NULL DEFAULT ''")
            try db.execute(sql: "ALTER TABLE grade_draft_assignments ADD COLUMN exemplar_text TEXT NOT NULL DEFAULT ''")
            try db.execute(sql: "ALTER TABLE grade_draft_assignments ADD COLUMN reviewed_student_text TEXT NOT NULL DEFAULT ''")
            try db.execute(sql: "ALTER TABLE grade_draft_assignments ADD COLUMN ocr_review_status TEXT NOT NULL DEFAULT 'notNeeded'")
            try db.execute(sql: "ALTER TABLE grade_draft_assignments ADD COLUMN grading_packet_fingerprint TEXT NOT NULL DEFAULT ''")
            try db.execute(sql: "ALTER TABLE grade_draft_assignments ADD COLUMN created_at TEXT NOT NULL DEFAULT ''")

            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS grade_draft_source_inputs (
                id TEXT PRIMARY KEY, assignment_id TEXT NOT NULL, source_type TEXT NOT NULL,
                page_index INTEGER, local_relative_path TEXT, file_name TEXT, mime_type TEXT,
                content_digest TEXT, digest_algorithm TEXT, image_width REAL, image_height REAL,
                pdf_page_count INTEGER, teacher_included_in_export BOOLEAN NOT NULL, created_at TEXT NOT NULL
            );
            """)
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS grade_draft_ocr_lines (
                id TEXT PRIMARY KEY, assignment_id TEXT NOT NULL, page_id TEXT NOT NULL, source_input_id TEXT,
                page_index INTEGER NOT NULL, raw_text TEXT NOT NULL, corrected_text TEXT, confidence REAL NOT NULL,
                bbox_x REAL NOT NULL, bbox_y REAL NOT NULL, bbox_width REAL NOT NULL, bbox_height REAL NOT NULL,
                teacher_confirmed BOOLEAN NOT NULL
            );
            """)
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS grade_draft_drafts (
                id TEXT PRIMARY KEY, assignment_id TEXT NOT NULL, packet_fingerprint TEXT NOT NULL,
                status TEXT NOT NULL, total_score REAL NOT NULL, max_score REAL NOT NULL,
                student_feedback TEXT NOT NULL, teacher_notes TEXT NOT NULL, raw_model_response TEXT,
                generated_at TEXT NOT NULL
            );
            """)
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS grade_draft_draft_criteria (
                id TEXT PRIMARY KEY, assignment_id TEXT NOT NULL, draft_id TEXT NOT NULL, criterion_id TEXT,
                criterion TEXT NOT NULL, rating TEXT NOT NULL, proposed_points REAL NOT NULL, max_points REAL NOT NULL,
                evidence_json TEXT NOT NULL, evidence_refs_json TEXT NOT NULL, explanation TEXT NOT NULL,
                teacher_review_required BOOLEAN NOT NULL
            );
            """)
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS grade_draft_final_reviews (
                id TEXT PRIMARY KEY, assignment_id TEXT NOT NULL, packet_fingerprint TEXT NOT NULL,
                status TEXT NOT NULL, total_score REAL NOT NULL, max_score REAL NOT NULL,
                student_feedback TEXT NOT NULL, private_teacher_notes TEXT NOT NULL, teacher_edited BOOLEAN NOT NULL,
                created_at TEXT NOT NULL, finalized_at TEXT
            );
            """)
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS grade_draft_final_criteria (
                id TEXT PRIMARY KEY, assignment_id TEXT NOT NULL, final_review_id TEXT NOT NULL, criterion_id TEXT,
                criterion TEXT NOT NULL, rating TEXT NOT NULL, proposed_points REAL NOT NULL, final_points REAL NOT NULL,
                max_points REAL NOT NULL, evidence_json TEXT NOT NULL, evidence_refs_json TEXT NOT NULL,
                explanation TEXT NOT NULL, teacher_approved BOOLEAN NOT NULL, teacher_rationale TEXT NOT NULL
            );
            """)
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS grade_draft_evidence_references (
                id TEXT PRIMARY KEY, assignment_id TEXT NOT NULL, source_input_id TEXT, ocr_line_id TEXT, page_index INTEGER,
                quote TEXT NOT NULL, start_offset INTEGER, end_offset INTEGER, bbox_x REAL, bbox_y REAL, bbox_width REAL, bbox_height REAL,
                source_kind TEXT NOT NULL, teacher_confirmed BOOLEAN NOT NULL, created_at TEXT NOT NULL
            );
            """)
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS grade_draft_curriculum_mappings (
                id TEXT PRIMARY KEY, assignment_id TEXT NOT NULL, curriculum_item_id TEXT NOT NULL,
                mapping_kind TEXT NOT NULL, teacher_selected BOOLEAN NOT NULL, created_at TEXT NOT NULL
            );
            """)
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS grade_draft_export_records (
                id TEXT PRIMARY KEY, assignment_id TEXT NOT NULL, export_kind TEXT NOT NULL,
                content_fingerprint TEXT NOT NULL, includes_private_teacher_notes BOOLEAN NOT NULL,
                includes_original_sources BOOLEAN NOT NULL, created_at TEXT NOT NULL
            );
            """)
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS grade_draft_audit_events (
                id TEXT PRIMARY KEY, assignment_id TEXT NOT NULL, event_type TEXT NOT NULL,
                actor TEXT NOT NULL, detail TEXT NOT NULL, created_at TEXT NOT NULL
            );
            """)
        }
    }
}
