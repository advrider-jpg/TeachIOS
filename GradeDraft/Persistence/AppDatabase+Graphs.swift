import Foundation
import GRDB

// Reading and writing whole submissions and assignment setups. Every read uses one query per table
// (filtered through a join on `submission` or `assignment`), then assembles the values in memory.

enum SubmissionScope: Sendable {
    case all
    case assignment(UUID)
    /// Submissions of the assignment that have a draft or a final review.
    case gradedInAssignment(UUID)
    case submission(UUID)

    /// A condition on the `submission` table.
    var whereClause: String {
        switch self {
        case .all: return "1"
        case .assignment: return "submission.assignmentID = ?"
        case .gradedInAssignment:
            return """
                submission.assignmentID = ? AND (EXISTS (SELECT 1 FROM draft WHERE draft.submissionID = submission.id)
                OR EXISTS (SELECT 1 FROM finalReview WHERE finalReview.submissionID = submission.id))
                """
        case .submission: return "submission.id = ?"
        }
    }

    var arguments: StatementArguments {
        switch self {
        case .all: return StatementArguments()
        case .assignment(let id), .gradedInAssignment(let id), .submission(let id): return [id]
        }
    }
}

enum AssignmentScope: Sendable {
    case all
    case classGroup(UUID)
    case assignment(UUID)

    /// A condition on the `assignment` table.
    var whereClause: String {
        switch self {
        case .all: return "1"
        case .classGroup: return "assignment.classGroupID = ?"
        case .assignment: return "assignment.id = ?"
        }
    }

    var arguments: StatementArguments {
        switch self {
        case .all: return StatementArguments()
        case .classGroup(let id), .assignment(let id): return [id]
        }
    }
}

extension AppDatabase {
    // MARK: - Decoding

    static func fetch<Record: FetchableRecord & TableRecord>(
        _ type: Record.Type,
        _ db: Database,
        sql: String,
        arguments: StatementArguments = StatementArguments()
    ) throws -> [Record] {
        try fetch(type, db, table: Record.databaseTableName, sql: sql, arguments: arguments)
    }

    /// Decodes each row; a row that cannot be decoded (unknown enum value, bad UUID, bad JSON)
    /// throws `AppDatabaseError.dataCorrupted` naming the table and row. Nothing is defaulted.
    static func fetch<Record: FetchableRecord>(
        _ type: Record.Type,
        _ db: Database,
        table: String,
        sql: String,
        arguments: StatementArguments = StatementArguments()
    ) throws -> [Record] {
        let rows = try Row.fetchAll(db, sql: sql, arguments: arguments)
        return try rows.map { row in
            do {
                return try Record(row: row)
            } catch {
                throw AppDatabaseError.dataCorrupted(table: table, rowID: rowIdentifier(row), underlying: error)
            }
        }
    }

    private static func rowIdentifier(_ row: Row) -> String {
        let columns = row.hasColumn("id") ? ["id"] : row.columnNames.filter { $0.hasSuffix("ID") }
        return columns.map { column -> String in
            let value: DatabaseValue = row[column]
            return UUID.fromDatabaseValue(value)?.uuidString ?? value.description
        }.joined(separator: "/")
    }

    // MARK: - Submissions

    static func fetchGraphs(_ db: Database, scope: SubmissionScope) throws -> [SubmissionGraph] {
        let condition = scope.whereClause
        let arguments = scope.arguments
        func rows<Record: FetchableRecord & TableRecord>(_ type: Record.Type, _ sql: String) throws -> [Record] {
            try fetch(type, db, sql: sql, arguments: arguments)
        }

        let submissions = try rows(Submission.self, "SELECT submission.* FROM submission WHERE \(condition) ORDER BY submission.createdAt")
        guard !submissions.isEmpty else { return [] }

        let students = try rows(Student.self, """
            SELECT student.* FROM student
            WHERE student.id IN (SELECT submission.studentID FROM submission WHERE \(condition))
            """)
        let sources = try rows(SourceInputRef.self, """
            SELECT sourceInput.* FROM sourceInput
            JOIN submission ON submission.id = sourceInput.submissionID
            WHERE \(condition) ORDER BY sourceInput.pageIndex, sourceInput.createdAt
            """)
        let documents = try rows(OCRDocumentRow.self, """
            SELECT ocrDocument.* FROM ocrDocument
            JOIN submission ON submission.id = ocrDocument.submissionID
            WHERE \(condition)
            """)
        let pages = try rows(OCRPageRow.self, """
            SELECT ocrPage.* FROM ocrPage
            JOIN ocrDocument ON ocrDocument.id = ocrPage.documentID
            JOIN submission ON submission.id = ocrDocument.submissionID
            WHERE \(condition) ORDER BY ocrPage.pageIndex
            """)
        let lines = try rows(OCRLineRow.self, """
            SELECT ocrLine.* FROM ocrLine
            JOIN ocrPage ON ocrPage.id = ocrLine.pageID
            JOIN ocrDocument ON ocrDocument.id = ocrPage.documentID
            JOIN submission ON submission.id = ocrDocument.submissionID
            WHERE \(condition) ORDER BY ocrLine.lineOrder
            """)
        let drafts = try rows(DraftRow.self, """
            SELECT draft.* FROM draft
            JOIN submission ON submission.id = draft.submissionID
            WHERE \(condition)
            """)
        let draftCriteria = try rows(DraftCriterionRow.self, """
            SELECT draftCriterion.* FROM draftCriterion
            JOIN draft ON draft.id = draftCriterion.draftID
            JOIN submission ON submission.id = draft.submissionID
            WHERE \(condition) ORDER BY draftCriterion.sortOrder
            """)
        let reviews = try rows(FinalReviewRow.self, """
            SELECT finalReview.* FROM finalReview
            JOIN submission ON submission.id = finalReview.submissionID
            WHERE \(condition)
            """)
        let reviewCriteria = try rows(FinalReviewCriterionRow.self, """
            SELECT finalReviewCriterion.* FROM finalReviewCriterion
            JOIN finalReview ON finalReview.id = finalReviewCriterion.finalReviewID
            JOIN submission ON submission.id = finalReview.submissionID
            WHERE \(condition) ORDER BY finalReviewCriterion.sortOrder
            """)
        let criterionEvidence = try rows(FinalCriterionEvidenceRow.self, """
            SELECT finalCriterionEvidence.* FROM finalCriterionEvidence
            JOIN finalReviewCriterion ON finalReviewCriterion.id = finalCriterionEvidence.finalReviewCriterionID
            JOIN finalReview ON finalReview.id = finalReviewCriterion.finalReviewID
            JOIN submission ON submission.id = finalReview.submissionID
            WHERE \(condition) ORDER BY finalCriterionEvidence.sortOrder
            """)
        let evidence = try rows(EvidenceReference.self, """
            SELECT evidence.* FROM evidence
            JOIN submission ON submission.id = evidence.submissionID
            WHERE \(condition) ORDER BY evidence.createdAt
            """)
        let exports = try rows(ExportRecord.self, """
            SELECT exportRecord.* FROM exportRecord
            JOIN submission ON submission.id = exportRecord.submissionID
            WHERE \(condition) ORDER BY exportRecord.createdAt
            """)
        let audit = try rows(AuditEvent.self, """
            SELECT auditEvent.* FROM auditEvent
            JOIN submission ON submission.id = auditEvent.submissionID
            WHERE \(condition) ORDER BY auditEvent.timestamp
            """)

        let studentsByID = Dictionary(students.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let sourcesBySubmission = Dictionary(grouping: sources, by: \.submissionID)
        let documentBySubmission = Dictionary(documents.map { ($0.submissionID, $0) }, uniquingKeysWith: { first, _ in first })
        let pagesByDocument = Dictionary(grouping: pages, by: \.documentID)
        let linesByPage = Dictionary(grouping: lines, by: \.pageID)
        let draftBySubmission = Dictionary(drafts.map { ($0.submissionID, $0) }, uniquingKeysWith: { first, _ in first })
        let criteriaByDraft = Dictionary(grouping: draftCriteria, by: \.draftID)
        let reviewBySubmission = Dictionary(reviews.map { ($0.submissionID, $0) }, uniquingKeysWith: { first, _ in first })
        let criteriaByReview = Dictionary(grouping: reviewCriteria, by: \.finalReviewID)
        let evidenceByCriterion = Dictionary(grouping: criterionEvidence, by: \.finalReviewCriterionID)
        let evidenceBySubmission = Dictionary(grouping: evidence, by: \.submissionID)
        let exportsBySubmission = Dictionary(grouping: exports) { $0.submissionID }
        let auditBySubmission = Dictionary(grouping: audit) { $0.submissionID }

        return try submissions.map { submission in
            guard let student = studentsByID[submission.studentID] else {
                throw AppDatabaseError.dataCorrupted(
                    table: Submission.databaseTableName,
                    rowID: submission.id.uuidString,
                    underlying: MissingRelatedRowError(detail: "The submission's student is missing.")
                )
            }
            let ocr = documentBySubmission[submission.id].map { row in
                OCRDocument(
                    id: row.id,
                    engine: row.engine,
                    engineVersion: row.engineVersion,
                    pages: (pagesByDocument[row.id] ?? []).map { page in
                        OCRPage(
                            id: page.id,
                            sourceInputID: page.sourceInputID,
                            pageIndex: page.pageIndex,
                            pixelWidth: page.pixelWidth,
                            pixelHeight: page.pixelHeight,
                            lines: (linesByPage[page.id] ?? []).map(\.line)
                        )
                    },
                    createdAt: row.createdAt,
                    reviewStatus: row.reviewStatus,
                    reviewedAt: row.reviewedAt
                )
            }
            let draft = draftBySubmission[submission.id].map { row in
                row.draft(criteria: (criteriaByDraft[row.id] ?? []).map(\.score))
            }
            let finalReview = reviewBySubmission[submission.id].map { row in
                row.review(criteria: (criteriaByReview[row.id] ?? []).map { criterion in
                    criterion.score(evidenceIDs: (evidenceByCriterion[criterion.id] ?? []).map(\.evidenceID))
                })
            }
            return SubmissionGraph(
                submission: submission,
                student: student,
                sources: sourcesBySubmission[submission.id] ?? [],
                ocr: ocr,
                draft: draft,
                finalReview: finalReview,
                evidence: evidenceBySubmission[submission.id] ?? [],
                exports: exportsBySubmission[submission.id] ?? [],
                audit: auditBySubmission[submission.id] ?? []
            )
        }
    }

    // MARK: - Assignment setups

    static func fetchSetups(_ db: Database, scope: AssignmentScope) throws -> [AssignmentSetup] {
        let condition = scope.whereClause
        let arguments = scope.arguments
        let assignments = try fetch(
            Assignment.self, db,
            sql: "SELECT assignment.* FROM assignment WHERE \(condition) ORDER BY assignment.updatedAt DESC",
            arguments: arguments
        )
        guard !assignments.isEmpty else { return [] }
        let templates = try fetch(
            AppliedTemplateRecord.self, db,
            sql: """
            SELECT appliedTemplate.* FROM appliedTemplate
            JOIN assignment ON assignment.id = appliedTemplate.assignmentID
            WHERE \(condition) ORDER BY appliedTemplate.appliedAt
            """,
            arguments: arguments
        )
        let mappings = try fetch(
            CurriculumMapping.self, db,
            sql: """
            SELECT curriculumMapping.* FROM curriculumMapping
            JOIN assignment ON assignment.id = curriculumMapping.assignmentID
            WHERE \(condition) ORDER BY curriculumMapping.createdAt
            """,
            arguments: arguments
        )
        let templatesByAssignment = Dictionary(grouping: templates, by: \.assignmentID)
        let mappingsByAssignment = Dictionary(grouping: mappings, by: \.assignmentID)
        return assignments.map { assignment in
            AssignmentSetup(
                assignment: assignment,
                appliedTemplates: templatesByAssignment[assignment.id] ?? [],
                curriculumMappings: mappingsByAssignment[assignment.id] ?? []
            )
        }
    }

    // MARK: - Inserting

    static func insertSources(_ sources: [SourceInputRef], submissionID: UUID, _ db: Database) throws {
        for source in sources {
            var source = source
            source.submissionID = submissionID
            try source.insert(db)
        }
    }

    static func insertOCR(_ document: OCRDocument, submissionID: UUID, _ db: Database) throws {
        try OCRDocumentRow(
            id: document.id,
            submissionID: submissionID,
            engine: document.engine,
            engineVersion: document.engineVersion,
            reviewStatus: document.reviewStatus,
            reviewedAt: document.reviewedAt,
            createdAt: document.createdAt
        ).insert(db)
        for page in document.pages {
            try OCRPageRow(
                id: page.id,
                documentID: document.id,
                sourceInputID: page.sourceInputID,
                pageIndex: page.pageIndex,
                pixelWidth: page.pixelWidth,
                pixelHeight: page.pixelHeight
            ).insert(db)
            for (order, line) in page.lines.enumerated() {
                try OCRLineRow(line, pageID: page.id, lineOrder: order).insert(db)
            }
        }
    }

    static func insertDraft(_ draft: GradeDraftResult, submissionID: UUID, _ db: Database) throws {
        try DraftRow(draft, submissionID: submissionID).insert(db)
        for (order, criterion) in draft.criteria.enumerated() {
            try DraftCriterionRow(criterion, draftID: draft.id, sortOrder: order).insert(db)
        }
    }

    static func insertFinalReview(_ review: FinalGradeReview, submissionID: UUID, _ db: Database) throws {
        try FinalReviewRow(review, submissionID: submissionID).insert(db)
        for (order, criterion) in review.criteria.enumerated() {
            try FinalReviewCriterionRow(criterion, finalReviewID: review.id, sortOrder: order).insert(db)
            for (evidenceOrder, evidenceID) in criterion.evidenceIDs.enumerated() {
                try FinalCriterionEvidenceRow(finalReviewCriterionID: criterion.id, evidenceID: evidenceID, sortOrder: evidenceOrder).insert(db)
            }
        }
    }

    /// One submission and everything under it. Evidence goes in after the scanned text it may cite
    /// and before the final review that may attach it.
    static func insertGraph(_ graph: SubmissionGraph, _ db: Database) throws {
        let submissionID = graph.submission.id
        try graph.submission.insert(db)
        try insertSources(graph.sources, submissionID: submissionID, db)
        if let ocr = graph.ocr { try insertOCR(ocr, submissionID: submissionID, db) }
        for item in graph.evidence {
            var item = item
            item.submissionID = submissionID
            try item.insert(db)
        }
        if let draft = graph.draft { try insertDraft(draft, submissionID: submissionID, db) }
        if let review = graph.finalReview { try insertFinalReview(review, submissionID: submissionID, db) }
        for export in graph.exports { try export.insert(db) }
        for event in graph.audit { try event.insert(db) }
    }

    static func insert(_ tree: RestoreTree, _ db: Database) throws {
        try tree.setup.assignment.insert(db)
        for template in tree.setup.appliedTemplates { try template.insert(db) }
        for mapping in tree.setup.curriculumMappings { try mapping.insert(db) }
        for graph in tree.graphs { try insertGraph(graph, db) }
        for event in tree.audit { try event.insert(db) }
        for export in tree.exports { try export.insert(db) }
    }
}

// MARK: - One assignment from a backup

/// An assignment from a backup with all of its submissions and assignment-level records.
struct RestoreTree: Sendable {
    var setup: AssignmentSetup
    var graphs: [SubmissionGraph]
    var audit: [AuditEvent]
    var exports: [ExportRecord]

    /// Every source path in the tree, in a fixed order (the same order after `copyWithNewIDs()`).
    var sourcePaths: [String] {
        graphs.flatMap { $0.sources.compactMap(\.localRelativePath) }
    }

    /// The same records under new IDs, with every internal reference and source path rewritten.
    func copyWithNewIDs() -> RestoreTree {
        let ids = IDMap()
        var copy = self
        let assignmentID = ids.new(setup.id)
        copy.setup.assignment.id = assignmentID
        copy.setup.appliedTemplates = setup.appliedTemplates.map { template in
            var template = template
            template.id = ids.new(template.id)
            template.assignmentID = assignmentID
            return template
        }
        copy.setup.curriculumMappings = setup.curriculumMappings.map { mapping in
            var mapping = mapping
            mapping.id = ids.new(mapping.id)
            mapping.assignmentID = assignmentID
            return mapping
        }
        copy.graphs = graphs.map { graph in
            Self.copy(graph, assignmentID: assignmentID, ids: ids)
        }
        copy.audit = audit.map { event in
            var event = event
            event.id = ids.new(event.id)
            event.assignmentID = assignmentID
            event.submissionID = event.submissionID.flatMap(ids.existing)
            return event
        }
        copy.exports = exports.map { export in
            var export = export
            export.id = ids.new(export.id)
            export.assignmentID = assignmentID
            export.submissionID = export.submissionID.flatMap(ids.existing)
            return export
        }
        return copy
    }

    private static func copy(_ graph: SubmissionGraph, assignmentID: UUID, ids: IDMap) -> SubmissionGraph {
        var graph = graph
        let originalSubmissionID = graph.submission.id
        let submissionID = ids.new(originalSubmissionID)
        let oldPrefix = "Sources/\(originalSubmissionID.uuidString)/"
        let newPrefix = "Sources/\(submissionID.uuidString)/"
        graph.submission.id = submissionID
        graph.submission.assignmentID = assignmentID

        graph.sources = graph.sources.map { source in
            var source = source
            source.id = ids.new(source.id)
            source.submissionID = submissionID
            if let path = source.localRelativePath, path.hasPrefix(oldPrefix) {
                source.localRelativePath = newPrefix + path.dropFirst(oldPrefix.count)
            }
            return source
        }
        if var ocr = graph.ocr {
            ocr.id = ids.new(ocr.id)
            ocr.pages = ocr.pages.map { page in
                var page = page
                page.id = ids.new(page.id)
                page.sourceInputID = page.sourceInputID.flatMap(ids.existing)
                page.lines = page.lines.map { line in
                    var line = line
                    line.id = ids.new(line.id)
                    return line
                }
                return page
            }
            graph.ocr = ocr
        }
        graph.evidence = graph.evidence.map { item in
            var item = item
            item.id = ids.new(item.id)
            item.submissionID = submissionID
            item.ocrLineID = item.ocrLineID.flatMap(ids.existing)
            return item
        }
        if var draft = graph.draft {
            draft.id = ids.new(draft.id)
            draft.criteria = draft.criteria.map { criterion in
                var criterion = criterion
                criterion.id = ids.new(criterion.id)
                return criterion
            }
            graph.draft = draft
        }
        if var review = graph.finalReview {
            review.id = ids.new(review.id)
            review.criteria = review.criteria.map { criterion in
                var criterion = criterion
                criterion.id = ids.new(criterion.id)
                criterion.evidenceIDs = criterion.evidenceIDs.compactMap(ids.existing)
                return criterion
            }
            graph.finalReview = review
        }
        graph.exports = graph.exports.map { export in
            var export = export
            export.id = ids.new(export.id)
            export.assignmentID = assignmentID
            export.submissionID = submissionID
            return export
        }
        graph.audit = graph.audit.map { event in
            var event = event
            event.id = ids.new(event.id)
            event.assignmentID = assignmentID
            event.submissionID = submissionID
            return event
        }
        return graph
    }
}

/// Old ID → new ID while copying one assignment.
private final class IDMap {
    private var map: [UUID: UUID] = [:]

    func new(_ old: UUID) -> UUID {
        if let mapped = map[old] { return mapped }
        let fresh = UUID()
        map[old] = fresh
        return fresh
    }

    /// The new ID of a record already copied, or nil for a reference outside the copied assignment.
    func existing(_ old: UUID) -> UUID? {
        map[old]
    }
}
