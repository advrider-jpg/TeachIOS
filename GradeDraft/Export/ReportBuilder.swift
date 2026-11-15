import Foundation

/// Builds the structured report for one submission. Wording follows the content document:
/// student report 16.1-16.2 and 25.1-25.2, Teacher Record 17 and 25.3.
enum ReportBuilder {
    // MARK: - Student report

    /// Only an approved, current final review produces a student report. Everything private
    /// (teacher notes, model output, audit metadata, file paths, other students, coordinates)
    /// is never read here.
    static func studentReport(setup: AssignmentSetup, submission: SubmissionGraph, generatedAt: Date) throws -> ReportDocument {
        guard ExportPolicy.allowsStudentReport(setup: setup, submission: submission),
              let review = submission.finalReview else {
            throw ReportError.notApproved
        }

        let title = "MarkForMe Student Feedback"
        var blocks = header(setup: setup, submission: submission, updated: review.finalizedAt ?? generatedAt)
        blocks.append(.paragraph("Generated from local app state. MarkForMe does not upload this report."))
        blocks.append(.paragraph("This student-facing report excludes private teacher notes and raw model responses."))

        blocks.append(.heading(level: 2, text: "Final teacher-approved grade"))
        blocks.append(.keyValue(label: "Score", value: scoreText(total: review.totalScore, max: maxScore(of: review.criteria.map(\.criterionID), setup: setup))))

        blocks.append(.heading(level: 3, text: "Feedback"))
        blocks.append(.paragraph(nonEmpty(review.studentFeedback, "No feedback provided.")))

        blocks.append(.heading(level: 3, text: "Criteria"))
        for criterion in review.criteria {
            blocks.append(.heading(level: 4, text: criterionTitle(criterion.criterionID, setup: setup)))
            var items = [
                "Final score: " + scoreText(total: criterion.finalPoints, max: criterionMax(criterion.criterionID, setup: setup)),
                "Rating: " + nonEmpty(criterion.rating, "Not specified")
            ]
            let quotes = evidenceQuotes(criterion.evidenceIDs, in: submission)
            if !quotes.isEmpty {
                items.append("Evidence: " + quotes.map { "\"\($0)\"" }.joined(separator: "; "))
            }
            items.append("Explanation: " + nonEmpty(criterion.explanation, "None provided."))
            blocks.append(.bulletList(items))
        }

        return ReportDocument(title: title, blocks: blocks)
    }

    // MARK: - Teacher Record

    static func teacherRecord(setup: AssignmentSetup, submission: SubmissionGraph, generatedAt: Date) -> ReportDocument {
        let assignment = setup.assignment
        let title = "MarkForMe Teacher Record"
        var blocks = header(setup: setup, submission: submission, updated: submission.submission.updatedAt)
        blocks.append(.paragraph("This teacher record may include private notes, reviewed text, scanned text warnings, source fingerprints, and grading-state metadata. Treat it as sensitive student data."))
        blocks.append(.paragraph("Generated from local app state. MarkForMe does not upload this report."))
        blocks.append(.keyValue(label: "Report generated", value: dateText(generatedAt)))

        // Readiness and source state
        var readiness: [String] = []
        if let ocr = submission.ocr {
            readiness.append("Scanned text review status: \(ocr.reviewStatus.displayName)")
        }
        readiness.append("Source inputs: \(submission.sources.count)")
        readiness.append("Current grading packet fingerprint: \((try? submission.packetFingerprint(setup: setup)) ?? "Unknown")")
        readiness.append("Draft stale: " + (submission.draft == nil ? "No draft" : (try? submission.draftIsStale(setup: setup)).map(yesNo) ?? "Unknown"))
        readiness.append("Final review stale: " + (submission.finalReview == nil ? "No final review" : (try? submission.finalReviewIsStale(setup: setup)).map(yesNo) ?? "Unknown"))
        blocks.append(.heading(level: 2, text: "Readiness and source state"))
        blocks.append(.bulletList(readiness))

        // Source inputs
        blocks.append(.heading(level: 2, text: "Source inputs"))
        if submission.sources.isEmpty {
            blocks.append(.paragraph("No source files recorded."))
        } else {
            blocks.append(.bulletList(submission.sources.map { source in
                let page = source.pageIndex.map { "page \($0 + 1)" } ?? "no page"
                let name = source.fileName ?? source.localRelativePath ?? "not recorded"
                return "\(source.sourceType.displayName), \(page): \(name) [SHA-256: \(source.sha256 ?? "none")]"
            }))
        }

        // Scanned text summary
        if let ocr = submission.ocr {
            blocks.append(.heading(level: 2, text: "Scanned text summary"))
            blocks.append(.bulletList([
                "Engine: \(ocr.engine)",
                "Review status: \(ocr.reviewStatus.displayName)",
                "Quality: \(ocr.qualitySummary.displaySummary)",
                "Reviewed at: " + (ocr.reviewedAt.map(dateText) ?? "Not reviewed")
            ]))
        }

        // Reviewed student text
        blocks.append(.heading(level: 2, text: "Reviewed student text"))
        let reviewedText = submission.reviewedText
        if reviewedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blocks.append(.paragraph("No reviewed student text saved."))
        } else {
            blocks.append(.studentText(reviewedText))
        }

        // Rubric and grading materials
        blocks.append(.heading(level: 2, text: "Rubric and grading materials"))
        appendMaterial("Rubric", assignment.rubricText, empty: "No rubric saved.", to: &blocks)
        appendMaterial("Custom teacher instructions", GradeDraftTemplateApplication.withoutTemplateMarkers(assignment.customInstructions), empty: "No custom teacher instructions saved.", to: &blocks)
        appendMaterial("Formative focus", GradeDraftTemplateApplication.withoutTemplateMarkers(assignment.formativeFocusText), empty: "No formative focus saved.", to: &blocks)
        appendMaterial("Answer key", GradeDraftTemplateApplication.withoutTemplateMarkers(assignment.answerKeyText), empty: "No answer key saved.", to: &blocks)
        appendMaterial("Exemplar", GradeDraftTemplateApplication.withoutTemplateMarkers(assignment.exemplarText), empty: "No exemplar saved.", to: &blocks)
        if !setup.appliedTemplates.isEmpty {
            blocks.append(.heading(level: 3, text: "Applied templates"))
            blocks.append(.bulletList(setup.appliedTemplates.sorted { $0.appliedAt < $1.appliedAt }.map {
                "\(dateText($0.appliedAt)): \($0.templateKind.displayName), \($0.templateName) [id: \($0.templateID); mode: \($0.insertionMode.rawValue)]"
            }))
        }
        let constraintTemplates = GradingConstraintTemplates.templates(for: assignment.constraintTemplateIDs)
        if !constraintTemplates.isEmpty {
            blocks.append(.heading(level: 3, text: "AI constraint templates selected by the teacher"))
            blocks.append(.bulletList(constraintTemplates.map { "\($0.title): \($0.text)" }))
        }
        if !assignment.curriculumReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !setup.curriculumMappings.isEmpty {
            blocks.append(.heading(level: 3, text: "Curriculum references"))
            if !assignment.curriculumReference.isEmpty {
                blocks.append(.paragraph(assignment.curriculumReference))
            }
            if !setup.curriculumMappings.isEmpty {
                blocks.append(.bulletList(setup.curriculumMappings.map { "\($0.curriculumItemID) (\($0.mappingKind))" }))
            }
        }

        // Model draft
        if let draft = submission.draft {
            blocks.append(.heading(level: 2, text: "Model draft"))
            blocks.append(.bulletList([
                "Draft status: " + ((try? submission.draftIsStale(setup: setup)).map { $0 ? "Needs recheck" : "Ready for teacher review" } ?? "Unknown"),
                "Score: " + scoreText(total: draft.totalScore, max: maxScore(of: draft.criteria.map(\.criterionID), setup: setup)),
                "Packet fingerprint: \(draft.packetFingerprint)"
            ]))
            blocks.append(.heading(level: 3, text: "Draft student feedback"))
            blocks.append(.paragraph(nonEmpty(draft.studentFeedback, "No draft student feedback provided.")))
            blocks.append(.heading(level: 3, text: "Draft criteria"))
            for criterion in draft.criteria {
                blocks.append(.heading(level: 4, text: criterionTitle(criterion.criterionID, setup: setup)))
                var items = [
                    "Score: " + scoreText(total: criterion.proposedPoints, max: criterionMax(criterion.criterionID, setup: setup)),
                    "Rating: " + nonEmpty(criterion.rating, "Not specified"),
                    "Explanation: " + nonEmpty(criterion.explanation, "None provided.")
                ]
                for quote in criterion.evidenceQuotes { items.append("Evidence: \(quote)") }
                if criterion.teacherReviewRequired { items.append("Teacher review required: yes") }
                blocks.append(.bulletList(items))
            }
            if !draft.uncertaintyFlags.isEmpty {
                blocks.append(.heading(level: 3, text: "Uncertainty flags"))
                blocks.append(.bulletList(draft.uncertaintyFlags))
            }
            if !draft.complianceFlags.isEmpty {
                blocks.append(.heading(level: 3, text: "Compliance flags"))
                blocks.append(.bulletList(draft.complianceFlags))
            }
            if !draft.teacherNotes.isEmpty {
                blocks.append(.heading(level: 3, text: "Private model/teacher notes"))
                blocks.append(.paragraph(draft.teacherNotes))
            }
        }

        // Final teacher review
        if let review = submission.finalReview {
            blocks.append(.heading(level: 2, text: "Final teacher review"))
            blocks.append(.bulletList([
                "Status: " + (review.status == .approved ? "Approved" : "Review final grade"),
                "Score: " + scoreText(total: review.totalScore, max: maxScore(of: review.criteria.map(\.criterionID), setup: setup)),
                "Packet fingerprint: \(review.packetFingerprint)",
                "Finalized at: " + (review.finalizedAt.map(dateText) ?? "Not finalized")
            ]))
            blocks.append(.heading(level: 3, text: "Student feedback"))
            blocks.append(.paragraph(nonEmpty(review.studentFeedback, "No feedback provided.")))
            blocks.append(.heading(level: 3, text: "Final criteria"))
            for criterion in review.criteria {
                blocks.append(.heading(level: 4, text: criterionTitle(criterion.criterionID, setup: setup)))
                let max = criterionMax(criterion.criterionID, setup: setup)
                var items = [
                    "Final score: " + scoreText(total: criterion.finalPoints, max: max),
                    "Suggestion score: " + scoreText(total: criterion.proposedPoints, max: max),
                    "Rating: " + nonEmpty(criterion.rating, "Not specified"),
                    "Explanation: " + nonEmpty(criterion.explanation, "None provided.")
                ]
                for quote in evidenceQuotes(criterion.evidenceIDs, in: submission) { items.append("Evidence: \(quote)") }
                if !criterion.teacherRationale.isEmpty { items.append("Teacher rationale: \(criterion.teacherRationale)") }
                blocks.append(.bulletList(items))
            }
            if !review.privateTeacherNotes.isEmpty {
                blocks.append(.heading(level: 3, text: "Private teacher notes"))
                blocks.append(.paragraph(review.privateTeacherNotes))
            }
        }

        // Evidence, export records, audit events
        if !submission.evidence.isEmpty {
            blocks.append(.heading(level: 2, text: "Evidence"))
            blocks.append(.bulletList(submission.evidence.map { reference in
                let page = reference.pageIndex.map { "page \($0 + 1)" } ?? "reviewed text"
                var line = "\"\(reference.quote)\" (\(page))"
                if let ocrLineID = reference.ocrLineID { line += " — text line \(ocrLineID.uuidString.prefix(8))" }
                if let box = reference.boundingBox { line += " — bbox: \(box.stableDisplay)" }
                return line
            }))
        }

        blocks.append(.heading(level: 2, text: "Export records"))
        if submission.exports.isEmpty {
            blocks.append(.paragraph("No exports recorded."))
        } else {
            blocks.append(.bulletList(submission.exports.sorted { $0.createdAt < $1.createdAt }.map {
                "\(dateText($0.createdAt)): \($0.kind.displayName); private notes included: \($0.includesPrivateTeacherNotes ? "yes" : "no"); original files included: \($0.includesOriginalSources ? "yes" : "no"); SHA-256: \($0.contentSHA256)"
            }))
        }

        blocks.append(.heading(level: 2, text: "Audit events"))
        if submission.audit.isEmpty {
            blocks.append(.paragraph("No audit events recorded."))
        } else {
            blocks.append(.bulletList(submission.audit.sorted { $0.timestamp < $1.timestamp }.map {
                "\(dateText($0.timestamp)): \($0.eventType.rawValue), \($0.detail)"
            }))
        }

        return ReportDocument(title: title, blocks: blocks)
    }

    // MARK: - Shared pieces

    private static func header(setup: AssignmentSetup, submission: SubmissionGraph, updated: Date) -> [ReportBlock] {
        let assignment = setup.assignment
        let student = submission.student
        let studentName = [student.displayName, student.localIdentifier].first { !$0.isEmpty } ?? ""
        return [
            .keyValue(label: "Assignment", value: assignment.title),
            .keyValue(label: "Student", value: nonEmpty(studentName, "Not specified")),
            .keyValue(label: "Subject", value: nonEmpty(assignment.subject, "Not specified")),
            .keyValue(label: "Grade/year level", value: nonEmpty(assignment.gradeLevel, "Not specified")),
            .keyValue(label: "Assignment type", value: assignment.assignmentType.displayName),
            .keyValue(label: "Updated", value: dateText(updated))
        ]
    }

    private static func appendMaterial(_ heading: String, _ value: String, empty: String, to blocks: inout [ReportBlock]) {
        blocks.append(.heading(level: 3, text: heading))
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        blocks.append(.paragraph(trimmed.isEmpty ? empty : trimmed))
    }

    private static func dateText(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private static func yesNo(_ value: Bool) -> String { value ? "Yes" : "No" }

    private static func nonEmpty(_ value: String, _ placeholder: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? placeholder : value
    }

    private static func scoreText(total: Double, max: Double?) -> String {
        guard let max else { return GradeTotals.formatted(total) }
        return "\(GradeTotals.formatted(total)) / \(GradeTotals.formatted(max))"
    }

    // Criterion titles and maximum points are read from the assignment's rubric (never stored on results).

    private static func rubricCriterion(_ id: String, setup: AssignmentSetup) -> RubricCriterion? {
        setup.parsedRubric.criteria.first { $0.id == id }
    }

    private static func criterionTitle(_ id: String, setup: AssignmentSetup) -> String {
        rubricCriterion(id, setup: setup)?.title ?? id
    }

    private static func criterionMax(_ id: String, setup: AssignmentSetup) -> Double? {
        rubricCriterion(id, setup: setup)?.maxPoints
    }

    private static func maxScore(of criterionIDs: [String], setup: AssignmentSetup) -> Double? {
        var total = 0.0
        for id in criterionIDs {
            guard let maxPoints = criterionMax(id, setup: setup) else { return nil }
            total += maxPoints
        }
        return total
    }

    private static func evidenceQuotes(_ ids: [UUID], in submission: SubmissionGraph) -> [String] {
        ids.compactMap { id in submission.evidence.first { $0.id == id }?.quote }
    }
}
