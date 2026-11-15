import GRDB

extension AppDatabase {
    static func makeMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif
        migrator.registerMigration("v1") { db in
            try db.create(table: "classGroup") { t in
                t.primaryKey("id", .blob)
                t.column("name", .text).notNull()
                t.column("schoolYear", .text).notNull().defaults(to: "")
                t.column("term", .text).notNull().defaults(to: "")
                t.column("subject", .text).notNull().defaults(to: "")
                t.column("gradeLevel", .text).notNull().defaults(to: "")
                t.column("notes", .text).notNull().defaults(to: "")
                t.column("isArchived", .boolean).notNull().defaults(to: false)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(table: "student") { t in
                t.primaryKey("id", .blob)
                t.column("displayName", .text).notNull()
                t.column("localIdentifier", .text).notNull().defaults(to: "")
                t.column("notes", .text).notNull().defaults(to: "")
                t.column("isActive", .boolean).notNull().defaults(to: true)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(table: "enrollment") { t in
                t.column("classGroupID", .blob).notNull().references("classGroup", onDelete: .cascade)
                t.column("studentID", .blob).notNull().indexed().references("student", onDelete: .cascade)
                t.column("sortOrder", .integer).notNull().defaults(to: 0)
                t.primaryKey(["classGroupID", "studentID"])
            }
            try db.create(table: "assignment") { t in
                t.primaryKey("id", .blob)
                t.column("classGroupID", .blob).notNull().indexed().references("classGroup", onDelete: .cascade)
                t.column("title", .text).notNull()
                t.column("prompt", .text).notNull().defaults(to: "")
                t.column("subject", .text).notNull().defaults(to: "")
                t.column("gradeLevel", .text).notNull().defaults(to: "")
                t.column("assessmentPurpose", .text).notNull()
                t.column("curriculumReference", .text).notNull().defaults(to: "")
                t.column("assignmentType", .text).notNull()
                t.column("rubricText", .text).notNull().defaults(to: "")
                t.column("rubricImportMode", .text).notNull()
                t.column("confirmedRubric", .text)               // JSON ParsedRubric, nullable
                t.column("customInstructions", .text).notNull().defaults(to: "")
                t.column("constraintTemplateIDs", .text).notNull() // JSON [String]
                t.column("answerKeyText", .text).notNull().defaults(to: "")
                t.column("exemplarText", .text).notNull().defaults(to: "")
                t.column("formativeFocusText", .text).notNull().defaults(to: "")
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(table: "appliedTemplate") { t in
                t.primaryKey("id", .blob)
                t.column("assignmentID", .blob).notNull().indexed().references("assignment", onDelete: .cascade)
                t.column("templateID", .text).notNull()
                t.column("templateName", .text).notNull()
                t.column("templateKind", .text).notNull()
                t.column("insertionMode", .text).notNull()
                t.column("appliedAt", .datetime).notNull()
            }
            try db.create(table: "curriculumMapping") { t in
                t.primaryKey("id", .blob)
                t.column("assignmentID", .blob).notNull().indexed().references("assignment", onDelete: .cascade)
                t.column("curriculumItemID", .text).notNull()
                t.column("mappingKind", .text).notNull()
                t.column("rubricCriterionID", .text)
                t.column("suggestedByAI", .boolean).notNull().defaults(to: false)
                t.column("teacherConfirmed", .boolean).notNull().defaults(to: true)
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(table: "submission") { t in
                t.primaryKey("id", .blob)
                t.column("assignmentID", .blob).notNull().references("assignment", onDelete: .cascade)
                t.column("studentID", .blob).notNull().indexed().references("student", onDelete: .cascade)
                t.column("inputKind", .text).notNull()            // "none" | "pasted" | "scanned"
                t.column("pastedText", .text)                     // only for inputKind == pasted
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.uniqueKey(["assignmentID", "studentID"])
            }
            try db.create(table: "sourceInput") { t in
                t.primaryKey("id", .blob)
                t.column("submissionID", .blob).notNull().indexed().references("submission", onDelete: .cascade)
                t.column("sourceType", .text).notNull()
                t.column("pageIndex", .integer)
                t.column("localRelativePath", .text)
                t.column("fileName", .text)
                t.column("mimeType", .text)
                t.column("sha256", .text)
                t.column("pixelWidth", .integer)
                t.column("pixelHeight", .integer)
                t.column("pdfPageCount", .integer)
                t.column("includedInTeacherArchive", .boolean).notNull().defaults(to: false)
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(table: "ocrDocument") { t in
                t.primaryKey("id", .blob)
                t.column("submissionID", .blob).notNull().unique().references("submission", onDelete: .cascade)
                t.column("engine", .text).notNull()
                t.column("engineVersion", .text).notNull()
                t.column("reviewStatus", .text).notNull()         // needsReview | reviewed | blocked
                t.column("reviewedAt", .datetime)
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(table: "ocrPage") { t in
                t.primaryKey("id", .blob)
                t.column("documentID", .blob).notNull().indexed().references("ocrDocument", onDelete: .cascade)
                t.column("sourceInputID", .blob).references("sourceInput", onDelete: .setNull)
                t.column("pageIndex", .integer).notNull()
                t.column("pixelWidth", .integer)
                t.column("pixelHeight", .integer)
            }
            try db.create(table: "ocrLine") { t in
                t.primaryKey("id", .blob)
                t.column("pageID", .blob).notNull().indexed().references("ocrPage", onDelete: .cascade)
                t.column("lineOrder", .integer).notNull()
                t.column("paragraphIndex", .integer)
                t.column("rawText", .text).notNull()
                t.column("correctedText", .text)
                t.column("origin", .text).notNull()               // visionOCR | pdfTextLayer
                t.column("confidence", .double)                   // nil for pdfTextLayer
                t.column("bboxX", .double); t.column("bboxY", .double)
                t.column("bboxWidth", .double); t.column("bboxHeight", .double)
                t.column("teacherConfirmed", .boolean).notNull().defaults(to: false)
                t.column("isRejected", .boolean).notNull().defaults(to: false)
            }
            try db.create(table: "draft") { t in
                t.primaryKey("id", .blob)
                t.column("submissionID", .blob).notNull().unique().references("submission", onDelete: .cascade)
                t.column("generatedAt", .datetime).notNull()
                t.column("packetFingerprint", .text).notNull()
                t.column("status", .text).notNull()
                t.column("studentResponseSummary", .text).notNull().defaults(to: "")
                t.column("studentFeedback", .text).notNull().defaults(to: "")
                t.column("teacherNotes", .text).notNull().defaults(to: "")
                t.column("uncertaintyFlags", .text).notNull()     // JSON [String]
                t.column("complianceFlags", .text).notNull()      // JSON [String]
                t.column("modelAudit", .text)                     // JSON LocalModelDraftAudit
            }
            try db.create(table: "draftCriterion") { t in
                t.primaryKey("id", .blob)
                t.column("draftID", .blob).notNull().indexed().references("draft", onDelete: .cascade)
                t.column("sortOrder", .integer).notNull()
                t.column("criterionID", .text).notNull()
                t.column("criterionTitle", .text)
                t.column("maxPoints", .double)
                t.column("rating", .text).notNull()
                t.column("proposedPoints", .double).notNull()
                t.column("evidenceQuotes", .text).notNull()       // JSON [String], model output kept as written
                t.column("explanation", .text).notNull()
                t.column("teacherReviewRequired", .boolean).notNull()
                t.column("nextStep", .text).notNull()
                t.column("confidence", .text).notNull()
                t.column("uncertaintyFlags", .text).notNull()     // JSON [String]
            }
            try db.create(table: "finalReview") { t in
                t.primaryKey("id", .blob)
                t.column("submissionID", .blob).notNull().unique().references("submission", onDelete: .cascade)
                t.column("createdAt", .datetime).notNull()
                t.column("finalizedAt", .datetime)
                t.column("packetFingerprint", .text).notNull()
                t.column("status", .text).notNull()               // inProgress | approved
                t.column("studentFeedback", .text).notNull().defaults(to: "")
                t.column("privateTeacherNotes", .text).notNull().defaults(to: "")
                t.column("teacherEdited", .boolean).notNull().defaults(to: false)
            }
            try db.create(table: "finalReviewCriterion") { t in
                t.primaryKey("id", .blob)
                t.column("finalReviewID", .blob).notNull().indexed().references("finalReview", onDelete: .cascade)
                t.column("sortOrder", .integer).notNull()
                t.column("criterionID", .text).notNull()
                t.column("criterionTitle", .text)
                t.column("maxPoints", .double)
                t.column("rating", .text).notNull()
                t.column("proposedPoints", .double).notNull()
                t.column("finalPoints", .double).notNull()
                t.column("explanation", .text).notNull()
                t.column("teacherApproved", .boolean).notNull().defaults(to: false)
                t.column("teacherRationale", .text).notNull().defaults(to: "")
            }
            try db.create(table: "evidence") { t in
                t.primaryKey("id", .blob)
                t.column("submissionID", .blob).notNull().indexed().references("submission", onDelete: .cascade)
                t.column("ocrLineID", .blob).references("ocrLine", onDelete: .setNull)
                t.column("pageIndex", .integer)
                t.column("quote", .text).notNull()
                t.column("startOffset", .integer)
                t.column("endOffset", .integer)
                t.column("bboxX", .double); t.column("bboxY", .double)
                t.column("bboxWidth", .double); t.column("bboxHeight", .double)
                t.column("sourceKind", .text).notNull()           // EvidenceSourceKind raw value
                t.column("teacherConfirmed", .boolean).notNull().defaults(to: false)
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(table: "finalCriterionEvidence") { t in
                t.column("finalReviewCriterionID", .blob).notNull().references("finalReviewCriterion", onDelete: .cascade)
                t.column("evidenceID", .blob).notNull().indexed().references("evidence", onDelete: .cascade)
                t.column("sortOrder", .integer).notNull()
                t.primaryKey(["finalReviewCriterionID", "evidenceID"])
            }
            try db.create(table: "exportRecord") { t in
                t.primaryKey("id", .blob)
                t.column("assignmentID", .blob).indexed().references("assignment", onDelete: .cascade) // nil = full backup
                t.column("submissionID", .blob).indexed().references("submission", onDelete: .cascade) // nil = class-level export
                t.column("kind", .text).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("contentSHA256", .text).notNull()
                t.column("includesPrivateTeacherNotes", .boolean).notNull()
                t.column("includesOriginalSources", .boolean).notNull()
            }
            try db.create(table: "auditEvent") { t in
                t.primaryKey("id", .blob)
                t.column("assignmentID", .blob).notNull().indexed().references("assignment", onDelete: .cascade)
                t.column("submissionID", .blob).indexed().references("submission", onDelete: .cascade)
                t.column("timestamp", .datetime).notNull()
                t.column("eventType", .text).notNull()
                t.column("actor", .text).notNull()
                t.column("detail", .text).notNull()
            }
            try db.create(table: "importedCurriculumItem") { t in
                t.primaryKey("id", .text)
                t.column("code", .text).notNull()
                t.column("title", .text).notNull()
                t.column("shortDescription", .text).notNull().defaults(to: "")
                t.column("learningArea", .text).notNull().defaults(to: "")
                t.column("subject", .text).notNull().defaults(to: "")
                t.column("yearLevel", .text).notNull().defaults(to: "")
                t.column("strand", .text).notNull().defaults(to: "")
                t.column("sourceName", .text).notNull()
                t.column("importedAt", .datetime).notNull()
            }
        }
        return migrator
    }
}
