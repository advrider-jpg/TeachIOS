import GRDB

extension AppDatabase {
    static func makeMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif
        migrator.registerMigration("v1") { db in
            try db.create(table: "classGroup") { table in
                table.primaryKey("id", .blob)
                table.column("name", .text).notNull()
                table.column("schoolYear", .text).notNull().defaults(to: "")
                table.column("term", .text).notNull().defaults(to: "")
                table.column("subject", .text).notNull().defaults(to: "")
                table.column("gradeLevel", .text).notNull().defaults(to: "")
                table.column("notes", .text).notNull().defaults(to: "")
                table.column("isArchived", .boolean).notNull().defaults(to: false)
                table.column("createdAt", .datetime).notNull()
                table.column("updatedAt", .datetime).notNull()
            }
            try db.create(table: "student") { table in
                table.primaryKey("id", .blob)
                table.column("displayName", .text).notNull()
                table.column("localIdentifier", .text).notNull().defaults(to: "")
                table.column("notes", .text).notNull().defaults(to: "")
                table.column("isActive", .boolean).notNull().defaults(to: true)
                table.column("createdAt", .datetime).notNull()
                table.column("updatedAt", .datetime).notNull()
            }
            try db.create(table: "enrollment") { table in
                table.column("classGroupID", .blob).notNull().references("classGroup", onDelete: .cascade)
                table.column("studentID", .blob).notNull().indexed().references("student", onDelete: .cascade)
                table.column("sortOrder", .integer).notNull().defaults(to: 0)
                table.primaryKey(["classGroupID", "studentID"])
            }
            try db.create(table: "assignment") { table in
                table.primaryKey("id", .blob)
                table.column("classGroupID", .blob).notNull().indexed().references("classGroup", onDelete: .cascade)
                table.column("title", .text).notNull()
                table.column("prompt", .text).notNull().defaults(to: "")
                table.column("subject", .text).notNull().defaults(to: "")
                table.column("gradeLevel", .text).notNull().defaults(to: "")
                table.column("assessmentPurpose", .text).notNull()
                table.column("curriculumReference", .text).notNull().defaults(to: "")
                table.column("assignmentType", .text).notNull()
                table.column("rubricText", .text).notNull().defaults(to: "")
                table.column("rubricImportMode", .text).notNull()
                table.column("confirmedRubric", .text)               // JSON ParsedRubric, nullable
                table.column("customInstructions", .text).notNull().defaults(to: "")
                table.column("constraintTemplateIDs", .text).notNull() // JSON [String]
                table.column("answerKeyText", .text).notNull().defaults(to: "")
                table.column("exemplarText", .text).notNull().defaults(to: "")
                table.column("formativeFocusText", .text).notNull().defaults(to: "")
                table.column("createdAt", .datetime).notNull()
                table.column("updatedAt", .datetime).notNull()
            }
            try db.create(table: "appliedTemplate") { table in
                table.primaryKey("id", .blob)
                table.column("assignmentID", .blob).notNull().indexed().references("assignment", onDelete: .cascade)
                table.column("templateID", .text).notNull()
                table.column("templateName", .text).notNull()
                table.column("templateKind", .text).notNull()
                table.column("insertionMode", .text).notNull()
                table.column("appliedAt", .datetime).notNull()
            }
            try db.create(table: "curriculumMapping") { table in
                table.primaryKey("id", .blob)
                table.column("assignmentID", .blob).notNull().indexed().references("assignment", onDelete: .cascade)
                table.column("curriculumItemID", .text).notNull()
                table.column("mappingKind", .text).notNull()
                table.column("rubricCriterionID", .text)
                table.column("suggestedByAI", .boolean).notNull().defaults(to: false)
                table.column("teacherConfirmed", .boolean).notNull().defaults(to: true)
                table.column("createdAt", .datetime).notNull()
            }
            try db.create(table: "submission") { table in
                table.primaryKey("id", .blob)
                table.column("assignmentID", .blob).notNull().references("assignment", onDelete: .cascade)
                table.column("studentID", .blob).notNull().indexed().references("student", onDelete: .cascade)
                table.column("inputKind", .text).notNull()            // "none" | "pasted" | "scanned"
                table.column("pastedText", .text)                     // only for inputKind == pasted
                table.column("createdAt", .datetime).notNull()
                table.column("updatedAt", .datetime).notNull()
                table.uniqueKey(["assignmentID", "studentID"])
            }
            try db.create(table: "sourceInput") { table in
                table.primaryKey("id", .blob)
                table.column("submissionID", .blob).notNull().indexed().references("submission", onDelete: .cascade)
                table.column("sourceType", .text).notNull()
                table.column("pageIndex", .integer)
                table.column("localRelativePath", .text)
                table.column("fileName", .text)
                table.column("mimeType", .text)
                table.column("sha256", .text)
                table.column("pixelWidth", .integer)
                table.column("pixelHeight", .integer)
                table.column("pdfPageCount", .integer)
                table.column("includedInTeacherArchive", .boolean).notNull().defaults(to: false)
                table.column("createdAt", .datetime).notNull()
            }
            try db.create(table: "ocrDocument") { table in
                table.primaryKey("id", .blob)
                table.column("submissionID", .blob).notNull().unique().references("submission", onDelete: .cascade)
                table.column("engine", .text).notNull()
                table.column("engineVersion", .text).notNull()
                table.column("reviewStatus", .text).notNull()         // needsReview | reviewed | blocked
                table.column("reviewedAt", .datetime)
                table.column("createdAt", .datetime).notNull()
            }
            try db.create(table: "ocrPage") { table in
                table.primaryKey("id", .blob)
                table.column("documentID", .blob).notNull().indexed().references("ocrDocument", onDelete: .cascade)
                table.column("sourceInputID", .blob).references("sourceInput", onDelete: .setNull)
                table.column("pageIndex", .integer).notNull()
                table.column("pixelWidth", .integer)
                table.column("pixelHeight", .integer)
            }
            try db.create(table: "ocrLine") { table in
                table.primaryKey("id", .blob)
                table.column("pageID", .blob).notNull().indexed().references("ocrPage", onDelete: .cascade)
                table.column("lineOrder", .integer).notNull()
                table.column("paragraphIndex", .integer)
                table.column("rawText", .text).notNull()
                table.column("correctedText", .text)
                table.column("origin", .text).notNull()               // visionOCR | pdfTextLayer
                table.column("confidence", .double)                   // nil for pdfTextLayer
                table.column("bboxX", .double); table.column("bboxY", .double)
                table.column("bboxWidth", .double); table.column("bboxHeight", .double)
                table.column("teacherConfirmed", .boolean).notNull().defaults(to: false)
                table.column("isRejected", .boolean).notNull().defaults(to: false)
            }
            try db.create(table: "draft") { table in
                table.primaryKey("id", .blob)
                table.column("submissionID", .blob).notNull().unique().references("submission", onDelete: .cascade)
                table.column("generatedAt", .datetime).notNull()
                table.column("packetFingerprint", .text).notNull()
                table.column("status", .text).notNull()
                table.column("studentResponseSummary", .text).notNull().defaults(to: "")
                table.column("studentFeedback", .text).notNull().defaults(to: "")
                table.column("teacherNotes", .text).notNull().defaults(to: "")
                table.column("uncertaintyFlags", .text).notNull()     // JSON [String]
                table.column("complianceFlags", .text).notNull()      // JSON [String]
                table.column("modelAudit", .text)                     // JSON LocalModelDraftAudit
            }
            try db.create(table: "draftCriterion") { table in
                table.primaryKey("id", .blob)
                table.column("draftID", .blob).notNull().indexed().references("draft", onDelete: .cascade)
                table.column("sortOrder", .integer).notNull()
                table.column("criterionID", .text).notNull()
                table.column("criterionTitle", .text)
                table.column("maxPoints", .double)
                table.column("rating", .text).notNull()
                table.column("proposedPoints", .double).notNull()
                table.column("evidenceQuotes", .text).notNull()       // JSON [String], model output kept as written
                table.column("explanation", .text).notNull()
                table.column("teacherReviewRequired", .boolean).notNull()
                table.column("nextStep", .text).notNull()
                table.column("confidence", .text).notNull()
                table.column("uncertaintyFlags", .text).notNull()     // JSON [String]
            }
            try db.create(table: "finalReview") { table in
                table.primaryKey("id", .blob)
                table.column("submissionID", .blob).notNull().unique().references("submission", onDelete: .cascade)
                table.column("createdAt", .datetime).notNull()
                table.column("finalizedAt", .datetime)
                table.column("packetFingerprint", .text).notNull()
                table.column("status", .text).notNull()               // inProgress | approved
                table.column("studentFeedback", .text).notNull().defaults(to: "")
                table.column("privateTeacherNotes", .text).notNull().defaults(to: "")
                table.column("teacherEdited", .boolean).notNull().defaults(to: false)
            }
            try db.create(table: "finalReviewCriterion") { table in
                table.primaryKey("id", .blob)
                table.column("finalReviewID", .blob).notNull().indexed().references("finalReview", onDelete: .cascade)
                table.column("sortOrder", .integer).notNull()
                table.column("criterionID", .text).notNull()
                table.column("criterionTitle", .text)
                table.column("maxPoints", .double)
                table.column("rating", .text).notNull()
                table.column("proposedPoints", .double).notNull()
                table.column("finalPoints", .double).notNull()
                table.column("explanation", .text).notNull()
                table.column("teacherApproved", .boolean).notNull().defaults(to: false)
                table.column("teacherRationale", .text).notNull().defaults(to: "")
            }
            try db.create(table: "evidence") { table in
                table.primaryKey("id", .blob)
                table.column("submissionID", .blob).notNull().indexed().references("submission", onDelete: .cascade)
                table.column("ocrLineID", .blob).references("ocrLine", onDelete: .setNull)
                table.column("pageIndex", .integer)
                table.column("quote", .text).notNull()
                table.column("startOffset", .integer)
                table.column("endOffset", .integer)
                table.column("bboxX", .double); table.column("bboxY", .double)
                table.column("bboxWidth", .double); table.column("bboxHeight", .double)
                table.column("sourceKind", .text).notNull()           // EvidenceSourceKind raw value
                table.column("teacherConfirmed", .boolean).notNull().defaults(to: false)
                table.column("createdAt", .datetime).notNull()
            }
            try db.create(table: "finalCriterionEvidence") { table in
                table.column("finalReviewCriterionID", .blob).notNull().references("finalReviewCriterion", onDelete: .cascade)
                table.column("evidenceID", .blob).notNull().indexed().references("evidence", onDelete: .cascade)
                table.column("sortOrder", .integer).notNull()
                table.primaryKey(["finalReviewCriterionID", "evidenceID"])
            }
            try db.create(table: "exportRecord") { table in
                table.primaryKey("id", .blob)
                table.column("assignmentID", .blob).indexed().references("assignment", onDelete: .cascade) // nil = full backup
                table.column("submissionID", .blob).indexed().references("submission", onDelete: .cascade) // nil = class-level export
                table.column("kind", .text).notNull()
                table.column("createdAt", .datetime).notNull()
                table.column("contentSHA256", .text).notNull()
                table.column("includesPrivateTeacherNotes", .boolean).notNull()
                table.column("includesOriginalSources", .boolean).notNull()
            }
            try db.create(table: "auditEvent") { table in
                table.primaryKey("id", .blob)
                table.column("assignmentID", .blob).notNull().indexed().references("assignment", onDelete: .cascade)
                table.column("submissionID", .blob).indexed().references("submission", onDelete: .cascade)
                table.column("timestamp", .datetime).notNull()
                table.column("eventType", .text).notNull()
                table.column("actor", .text).notNull()
                table.column("detail", .text).notNull()
            }
        }
        return migrator
    }
}
