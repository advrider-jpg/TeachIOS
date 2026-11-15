import Foundation

// MARK: - Grading packet construction

enum GradingPacketBuilder {
    /// The one place a submission becomes model input. Graded text is only the submission's teacher-reviewed
    /// text (`SubmissionGraph.reviewedText`), never raw scanned text or source images. `className` is the
    /// submission's class name, used only to redact it from model-visible text. `mappedItems` are the catalog
    /// items behind the setup's teacher-confirmed curriculum mappings (never unconfirmed AI suggestions); they
    /// join the teacher's own curriculum reference text in the packet's curriculum section.
    static func gradingInput(
        setup: AssignmentSetup, graph: SubmissionGraph, className: String, mappedItems: [CurriculumItem]
    ) throws -> GradingInput {
        let assignment = setup.assignment
        let templateIDs = assignment.constraintTemplateIDs
        let reviewedText = graph.reviewedText
        let answerKeyText = GradeDraftTemplateApplication.withoutTemplateMarkers(assignment.answerKeyText)
        let exemplarText = GradeDraftTemplateApplication.withoutTemplateMarkers(assignment.exemplarText)
        // Pasted work is teacher-supplied text and needs no scanned-text review; scanned work is gated on the
        // teacher's review of its lines.
        let ocrReviewStatus: OCRReviewStatus = graph.submission.inputKind == .pasted
            ? .reviewed
            : graph.ocr?.reviewStatus ?? .needsReview
        let hasGradingStandard = !assignment.rubricText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !answerKeyText.isEmpty
            || !exemplarText.isEmpty
        let curriculumReference = [
            assignment.curriculumReference.trimmingCharacters(in: .whitespacesAndNewlines),
            CurriculumCatalogService.selectedReferenceSummary(items: mappedItems)
        ].filter { !$0.isEmpty }.joined(separator: "\n\n")
        return GradingInput(
            assignmentID: assignment.id,
            assignmentTitle: assignment.title,
            prompt: assignment.prompt,
            subject: assignment.subject,
            gradeLevel: assignment.gradeLevel,
            className: className,
            studentDisplayName: graph.student.displayName,
            assignmentType: assignment.assignmentType,
            rubricText: assignment.rubricText,
            parsedRubric: setup.parsedRubric,
            customInstructions: GradeDraftTemplateApplication.withoutTemplateMarkers(assignment.customInstructions),
            selectedInstructionTemplateIDs: templateIDs,
            selectedInstructionTemplateText: GradingConstraintTemplates.combinedText(for: templateIDs),
            selectedInstructionTemplateFingerprint: GradingConstraintTemplates.fingerprint(for: templateIDs),
            formativeFocusText: GradeDraftTemplateApplication.withoutTemplateMarkers(assignment.formativeFocusText),
            answerKeyText: answerKeyText,
            exemplarText: exemplarText,
            assessmentPurpose: assignment.assessmentPurpose,
            curriculumReference: curriculumReference,
            reviewedStudentText: reviewedText,
            reviewedTextWithSourceRefs: sourceReferencedText(ocr: graph.ocr, reviewedText: reviewedText),
            ocrQualitySummary: graph.ocr?.qualitySummary ?? OCRQualitySummary(),
            ocrReviewStatus: ocrReviewStatus,
            sourceInputCount: graph.sources.count,
            packetFingerprint: try graph.packetFingerprint(setup: setup),
            hasGradingStandard: hasGradingStandard
        )
    }

    /// The reviewed lines of a scanned submission, each tagged with its page and line so the model can cite it,
    /// for example "[p1-l2-abcdef12] The water cycle begins with evaporation." Rejected lines are left out,
    /// exactly as in the reviewed text. Pasted work has no lines and is used as written.
    private static func sourceReferencedText(ocr: OCRDocument?, reviewedText: String) -> String {
        guard let ocr, !ocr.pages.isEmpty else { return reviewedText }
        return ocr.pages.sorted { $0.pageIndex < $1.pageIndex }.flatMap { page in
            page.lines.enumerated().compactMap { offset, line in
                guard !line.isRejected, !line.reviewedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                return "[p\(page.pageIndex + 1)-l\(offset + 1)-\(line.id.uuidString.prefix(8))] \(line.reviewedText)"
            }
        }.joined(separator: "\n")
    }

    static func packet(from input: GradingInput) -> GradingPacket {
        let criteria = input.parsedRubric.criteria.map { criterion in
            GradingPacketRubricCriterion(
                id: criterion.id,
                title: criterion.title,
                maxPoints: criterion.maxPoints,
                descriptor: criterion.descriptor,
                groupTitle: criterion.groupTitle
            )
        }
        let curriculumText = input.curriculumReference.trimmingCharacters(in: .whitespacesAndNewlines)
        let instructionText = input.customInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        let formativeText = input.formativeFocusText.trimmingCharacters(in: .whitespacesAndNewlines)
        let answerKeyText = input.answerKeyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let exemplarText = input.exemplarText.trimmingCharacters(in: .whitespacesAndNewlines)
        return GradingPacket(
            packetVersion: "gradedraft-packet-v3",
            assignment: GradingPacketAssignment(
                assignmentID: input.assignmentID,
                title: input.assignmentTitle,
                prompt: input.prompt,
                subject: input.subject,
                gradeLevel: input.gradeLevel,
                className: input.className,
                studentDisplayName: input.studentDisplayName,
                assignmentType: input.assignmentType,
                assessmentPurpose: input.assessmentPurpose
            ),
            curriculumReference: curriculumText.isEmpty ? nil : GradingPacketCurriculumReference(rawText: curriculumText),
            rubric: GradingPacketRubric(rawText: input.rubricText, criteria: criteria),
            teacherInstructions: instructionText.isEmpty ? [] : [GradingPacketTeacherInstruction(name: "Teacher custom instructions", text: instructionText, privateTeacherOnly: true)],
            formativeFocus: formativeText.isEmpty ? nil : GradingPacketFormativeFocus(rawText: formativeText),
            answerKey: answerKeyText.isEmpty ? nil : GradingPacketAnswerKey(rawText: answerKeyText),
            exemplar: exemplarText.isEmpty ? nil : GradingPacketExemplar(rawText: exemplarText),
            studentEvidence: GradingPacketStudentEvidence(
                reviewedText: input.reviewedStudentText,
                reviewedTextWithSourceRefs: input.reviewedTextWithSourceRefs,
                ocrReviewStatus: input.ocrReviewStatus,
                ocrQualitySummary: input.ocrQualitySummary.displaySummary,
                hasLowConfidenceOCRText: input.ocrQualitySummary.lowConfidenceLineCount > 0,
                sourceInputCount: input.sourceInputCount
            ),
            outputRules: GradingPacketOutputRules(
                requireEvidenceQuotes: true,
                requireTeacherReviewForFinalGrade: true,
                doNotInferIntentAbilityEffort: true,
                studentFacingFeedbackOnly: true
            )
        )
    }

    /// The same input with student and class identity removed from every model-visible field.
    static func modelVisibleInput(from input: GradingInput) -> GradingInput {
        let identityValues = [input.studentDisplayName, input.className]
        var sanitized = input
        sanitized.assignmentTitle = redactedText(sanitized.assignmentTitle, identityValues: identityValues)
        sanitized.prompt = redactedText(sanitized.prompt, identityValues: identityValues)
        sanitized.subject = redactedText(sanitized.subject, identityValues: identityValues)
        sanitized.gradeLevel = redactedText(sanitized.gradeLevel, identityValues: identityValues)
        sanitized.className = ""
        sanitized.studentDisplayName = ""
        sanitized.rubricText = redactedText(sanitized.rubricText, identityValues: identityValues)
        sanitized.parsedRubric = redactedParsedRubric(sanitized.parsedRubric, identityValues: identityValues)
        sanitized.customInstructions = redactedText(sanitized.customInstructions, identityValues: identityValues)
        sanitized.formativeFocusText = redactedText(sanitized.formativeFocusText, identityValues: identityValues)
        sanitized.answerKeyText = redactedText(sanitized.answerKeyText, identityValues: identityValues)
        sanitized.exemplarText = redactedText(sanitized.exemplarText, identityValues: identityValues)
        sanitized.curriculumReference = redactedText(sanitized.curriculumReference, identityValues: identityValues)
        sanitized.reviewedStudentText = redactedText(sanitized.reviewedStudentText, identityValues: identityValues)
        sanitized.reviewedTextWithSourceRefs = redactedText(sanitized.reviewedTextWithSourceRefs, identityValues: identityValues)
        return sanitized
    }

    private static func redactedParsedRubric(_ parsedRubric: ParsedRubric, identityValues: [String]) -> ParsedRubric {
        ParsedRubric(
            criteria: parsedRubric.criteria.map { criterion in
                RubricCriterion(
                    id: criterion.id,
                    title: redactedText(criterion.title, identityValues: identityValues),
                    maxPoints: criterion.maxPoints,
                    descriptor: redactedText(criterion.descriptor, identityValues: identityValues),
                    sortOrder: criterion.sortOrder,
                    groupTitle: criterion.groupTitle.map { redactedText($0, identityValues: identityValues) },
                    levels: criterion.levels.map { level in
                        RubricLevel(
                            id: level.id,
                            label: redactedText(level.label, identityValues: identityValues),
                            points: level.points,
                            minPoints: level.minPoints,
                            maxPoints: level.maxPoints,
                            descriptor: redactedText(level.descriptor, identityValues: identityValues),
                            sortOrder: level.sortOrder
                        )
                    },
                    explicitID: criterion.explicitID
                )
            },
            issues: parsedRubric.issues.map { redactedText($0, identityValues: identityValues) },
            groups: parsedRubric.groups.map { redactedText($0, identityValues: identityValues) }
        )
    }

    private static func redactedText(_ text: String, identityValues: [String]) -> String {
        identityValues
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 }
            .reduce(text) { current, value in
                current.replacingOccurrences(of: value, with: "[redacted identity]", options: [.caseInsensitive])
            }
    }
}

enum AIReadinessAnalyzer {
    /// `input` comes from `GradingPacketBuilder.gradingInput(setup:graph:className:mappedItems:)`; the staleness flags from
    /// `SubmissionGraph.draftIsStale(setup:)` and `finalReviewIsStale(setup:)`.
    static func report(
        input: GradingInput,
        draftIsStale: Bool,
        finalReviewIsStale: Bool,
        localAIStatus: LocalAIStatus,
        supportsCurrentLocale: Bool,
        budgetPlan: PromptBudgetPlan? = nil,
        budgetError: Error? = nil
    ) -> AIReadinessReport {
        let packet = GradingPacketBuilder.packet(from: input)
        let localStatusSummary: String
        let localStatus: AIReadinessStatus
        switch localAIStatus {
        case .available:
            localStatusSummary = "Local AI is available on this device."
            localStatus = .ready
        case .unavailable(let message):
            localStatusSummary = message
            localStatus = .unavailable
        }

        var checks: [AIReadinessCheck] = [
            AIReadinessCheck(
                id: "local-ai",
                title: "Local AI availability",
                detail: localStatusSummary,
                status: localStatus
            ),
            AIReadinessCheck(
                id: "model-language",
                title: "Language support",
                detail: supportsCurrentLocale
                    ? "The on-device model supports this device's language and region."
                    : "The on-device model can't read this language. Use manual review.",
                status: supportsCurrentLocale ? .ready : .blocked
            ),
            AIReadinessCheck(
                id: "ocr-review",
                title: "scanned text review",
                detail: input.ocrReviewStatus.blocksGrading
                    ? "Review scanned text before drafting feedback."
                    : "Reviewed text is eligible for the grading packet.",
                status: input.ocrReviewStatus.blocksGrading ? .blocked : .ready
            ),
            AIReadinessCheck(
                id: "student-evidence",
                title: "Student evidence",
                detail: packet.studentEvidence.reviewedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "Add or review student work before drafting feedback."
                    : "\(packet.studentEvidence.reviewedText.count) reviewed characters are available.",
                status: packet.studentEvidence.reviewedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .blocked : .ready
            ),
            AIReadinessCheck(
                id: "grading-standard",
                title: "Grading standard",
                detail: input.hasGradingStandard
                    ? "\(packet.rubric.criteria.count) structured criteria; answer key included: \(packet.answerKey == nil ? "no" : "yes"); exemplar included: \(packet.exemplar == nil ? "no" : "yes")."
                    : "Add a rubric, answer key, exemplar, or grading criteria.",
                status: input.hasGradingStandard ? .ready : .blocked
            ),
            AIReadinessCheck(
                id: "rubric-parse",
                title: "Rubric readiness",
                detail: rubricReadinessDetail(for: input),
                status: rubricReadinessStatus(for: input)
            ),
            AIReadinessCheck(
                id: "answer-key",
                title: "Answer key",
                detail: packet.answerKey == nil ? "No answer key is included." : "Answer key is included as teacher-supplied grading material.",
                status: packet.answerKey == nil ? .info : .ready
            ),
            AIReadinessCheck(
                id: "exemplar",
                title: "Exemplar",
                detail: packet.exemplar == nil ? "No exemplar is included." : "Exemplar is included as teacher-supplied grading material.",
                status: packet.exemplar == nil ? .info : .ready
            ),
            AIReadinessCheck(
                id: "curriculum-reference",
                title: "Curriculum reference",
                detail: packet.curriculumReference == nil ? "No teacher-written curriculum reference is included." : "Teacher-written curriculum reference is included.",
                status: packet.curriculumReference == nil ? .info : .ready
            ),
            AIReadinessCheck(
                id: "ai-constraints",
                title: "AI constraints",
                detail: constraintSummary(for: input),
                status: .ready
            ),
            AIReadinessCheck(
                id: "custom-instruction-lint",
                title: "Custom instruction safety",
                detail: customInstructionSafetySummary(for: input),
                status: customInstructionSafetyStatus(for: input)
            ),
            AIReadinessCheck(
                id: "sensitive-constraints",
                title: "Sensitive constraints",
                detail: sensitiveConstraintSummary(for: input),
                status: sensitiveConstraintStatus(for: input)
            ),
            AIReadinessCheck(
                id: "pii-redaction",
                title: "Identity redaction",
                detail: "Student name, student ID, class name, roster membership, file paths, and source filenames are removed from the model-visible packet by default.",
                status: .ready
            ),
            AIReadinessCheck(
                id: "stale-state",
                title: "Draft and review freshness",
                detail: staleStateSummary(draftIsStale: draftIsStale, finalReviewIsStale: finalReviewIsStale),
                status: (draftIsStale || finalReviewIsStale) ? .needsReview : .ready
            )
        ]

        let risks = PromptInjectionRiskDetector.risks(in: packet)
        checks.append(
            AIReadinessCheck(
                id: "prompt-injection",
                title: "Prompt-injection risk",
                detail: risks.isEmpty
                    ? "No common prompt-injection phrases were detected in reviewed packet text."
                    : "\(risks.count) packet section(s) include text that must be treated only as quoted evidence.",
                status: risks.isEmpty ? .ready : .needsReview
            )
        )

        let generationMode: LocalModelGenerationMode
        let tokenSummary: String
        if let budgetPlan {
            generationMode = budgetPlan.mode
            tokenSummary = Self.tokenSummary(for: budgetPlan.report)
            checks.append(
                AIReadinessCheck(
                    id: "budget-plan",
                    title: "Packet budget",
                    detail: tokenSummary,
                    status: budgetPlan.mode == .unavailable ? .blocked : .ready
                )
            )
        } else if let budgetError {
            generationMode = .unavailable
            tokenSummary = budgetError.localizedDescription
            checks.append(
                AIReadinessCheck(
                    id: "budget-plan",
                    title: "Packet budget",
                    detail: tokenSummary,
                    status: .blocked
                )
            )
        } else {
            generationMode = .unavailable
            tokenSummary = "Measure the grading packet before drafting."
            checks.append(
                AIReadinessCheck(
                    id: "budget-plan",
                    title: "Packet budget",
                    detail: tokenSummary,
                    status: .info
                )
            )
        }

        let blocked = checks.contains { $0.status == .blocked || $0.status == .unavailable }
        let canGenerate = !blocked && budgetPlan != nil
        let nextAction: String
        if canGenerate {
            nextAction = risks.isEmpty
                ? "Preview the packet, then draft locally when the teacher confirms."
                : "Review the flagged packet text, then draft locally only if it is still appropriate."
        } else if let firstBlocker = checks.first(where: { $0.status == .blocked || $0.status == .unavailable }) {
            nextAction = firstBlocker.detail
        } else {
            nextAction = "Prepare the local packet preview."
        }

        return AIReadinessReport(
            assignmentID: input.assignmentID,
            localAIStatusSummary: localStatusSummary,
            canGenerate: canGenerate,
            checks: checks,
            promptInjectionRisks: risks,
            piiRedactionSummary: "Identity metadata is retained in local assignment records but excluded from model-visible prompts by default.",
            plannedGenerationMode: generationMode,
            tokenEstimateSummary: tokenSummary,
            recommendedNextAction: nextAction
        )
    }

    private static func tokenSummary(for report: PromptBudgetReport) -> String {
        switch report.selectedMode {
        case .fullPacket:
            return "Full packet: \(report.fullPacketTokens ?? 0) input tokens measured, \(report.reservedOutputTokens) reserved for output, of \(report.contextSizeTokens)."
        case .compactFullPacket:
            return "Compact packet: \(report.compactPacketTokens ?? 0) input tokens measured, \(report.reservedOutputTokens) reserved for output, of \(report.contextSizeTokens)."
        case .perCriterion:
            let largest = report.perCriterionTokenCounts.values.max() ?? 0
            return "Criterion by criterion: up to \(largest) input tokens measured per criterion, \(report.reservedOutputTokens) reserved for output, of \(report.contextSizeTokens)."
        case .unavailable:
            return "Unavailable."
        }
    }

    private static func rubricReadinessDetail(for input: GradingInput) -> String {
        let report = RubricReadinessAnalyzer.report(for: input)
        if !report.issues.isEmpty {
            return report.issues.joined(separator: " ")
        }
        if !report.warnings.isEmpty {
            return report.warnings.joined(separator: " ")
        }
        return "Structured rubric is ready for local draft planning."
    }

    private static func rubricReadinessStatus(for input: GradingInput) -> AIReadinessStatus {
        let report = RubricReadinessAnalyzer.report(for: input)
        if !report.issues.isEmpty { return .blocked }
        if !report.warnings.isEmpty { return .needsReview }
        return .ready
    }

    private static func constraintSummary(for input: GradingInput) -> String {
        let selected = GradingConstraintTemplates.templates(for: input.selectedInstructionTemplateIDs)
        guard !selected.isEmpty else { return "No AI constraint templates are selected." }
        return selected.map(\.title).joined(separator: ", ")
    }

    private static func customInstructionSafetySummary(for input: GradingInput) -> String {
        let warnings = CustomInstructionLinter.lint(input.customInstructions).map(\.message)
        if warnings.isEmpty {
            return input.customInstructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "No custom teacher instructions are included."
                : "Custom teacher instructions did not match known unsafe instruction patterns."
        }
        return warnings.joined(separator: " ")
    }

    private static func customInstructionSafetyStatus(for input: GradingInput) -> AIReadinessStatus {
        CustomInstructionLinter.lint(input.customInstructions).isEmpty ? .ready : .needsReview
    }

    private static func sensitiveConstraintSummary(for input: GradingInput) -> String {
        let sensitive = GradingConstraintTemplates.templates(for: input.selectedInstructionTemplateIDs)
            .filter(\.sensitiveContextRequired)
        guard !sensitive.isEmpty else {
            return "No sensitive-context AI constraints are selected."
        }
        return "Teacher-selected sensitive-context constraints: \(sensitive.map(\.title).joined(separator: ", ")). Confirm this context is teacher-known and appropriate before drafting."
    }

    private static func sensitiveConstraintStatus(for input: GradingInput) -> AIReadinessStatus {
        GradingConstraintTemplates.templates(for: input.selectedInstructionTemplateIDs)
            .contains(where: \.sensitiveContextRequired) ? .needsReview : .ready
    }

    private static func staleStateSummary(draftIsStale: Bool, finalReviewIsStale: Bool) -> String {
        if draftIsStale && finalReviewIsStale {
            return "Existing local draft and final review need rechecking because grading inputs changed."
        }
        if draftIsStale {
            return "Existing local draft needs rechecking because grading inputs changed."
        }
        if finalReviewIsStale {
            return "Existing final review needs rechecking because grading inputs changed."
        }
        return "No stale draft or final-review state was detected for the current grading packet."
    }
}

enum RubricReadinessAnalyzer {
    static func report(for input: GradingInput) -> RubricReadinessReport {
        let parsed = input.parsedRubric
        var issues: [String] = []
        var warnings: [String] = []
        if !input.hasGradingStandard {
            issues.append("Add a rubric, answer key, exemplar, or grading criteria.")
        }
        if !input.rubricText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && parsed.criteria.isEmpty {
            warnings.append("Rubric text has no teacher-confirmed point-bearing criteria; local AI must mark every criterion for teacher review.")
        }
        let duplicateTitles = duplicateNormalizedTitles(parsed.criteria)
        if !duplicateTitles.isEmpty {
            warnings.append("Duplicate rubric criteria detected: \(duplicateTitles.joined(separator: ", ")).")
        }
        if parsed.issues.contains(where: { $0.localizedCaseInsensitiveContains("Duplicate criterion") }) {
            warnings.append("Duplicate rubric criteria detected in the imported rubric.")
        }
        let missingPoints = parsed.criteria.filter { $0.maxPoints <= 0 }.map(\.title)
        if !missingPoints.isEmpty {
            warnings.append("Criteria without positive max points: \(missingPoints.joined(separator: ", ")).")
        }
        warnings.append(contentsOf: parsed.issues)
        let combined = [
            input.rubricText,
            input.customInstructions,
            input.answerKeyText,
            input.exemplarText
        ].joined(separator: "\n")
        if containsContradictionLanguage(combined) {
            warnings.append("Possible contradictory grading instructions detected; teacher review is required before relying on the draft.")
        }
        let customInstructionWarnings = CustomInstructionLinter.lint(input.customInstructions)
        warnings.append(contentsOf: customInstructionWarnings.map(\.message))
        if requiresNonTextualJudgment(combined) && input.sourceInputCount == 0 {
            warnings.append("Rubric may require visual, diagram, handwriting, audio, or performance judgment that is not represented in reviewed text.")
        }
        if input.assessmentPurpose == .summative {
            warnings.append("Summative assessment selected; review friction remains higher and teacher final approval is required.")
        }
        return RubricReadinessReport(
            issues: Array(Set(issues)).sorted(),
            warnings: Array(Set(warnings)).sorted(),
            canUseForDrafting: issues.isEmpty
        )
    }

    private static func duplicateNormalizedTitles(_ criteria: [RubricCriterion]) -> [String] {
        var seen: [String: String] = [:]
        var duplicates: Set<String> = []
        for criterion in criteria {
            let key = RubricParser.normalized(criterion.title)
            if let existing = seen[key] {
                duplicates.insert(existing)
            } else {
                seen[key] = criterion.title
            }
        }
        return Array(duplicates).sorted()
    }

    private static func containsContradictionLanguage(_ text: String) -> Bool {
        let patterns = [
            #"ignore (the )?rubric"#,
            #"rubric no longer matters"#,
            #"always award full credit"#,
            #"never award full credit"#,
            #"contradict(s|ory)? the answer key"#,
            #"use the answer key instead of the rubric"#
        ]
        return patterns.contains { text.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil }
    }

    private static func requiresNonTextualJudgment(_ text: String) -> Bool {
        let patterns = [
            #"\bdiagram\b"#,
            #"\bdrawing\b"#,
            #"\bhandwriting\b"#,
            #"\bperformance\b"#,
            #"\boral presentation\b"#,
            #"\baudio\b"#,
            #"\bvideo\b"#,
            #"\bvisual\b"#,
            #"\bgraph\b"#,
            #"\bsymbolic notation\b"#
        ]
        return patterns.contains { text.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil }
    }
}

enum CustomInstructionLintCategory: String, Codable, Equatable, Sendable {
    case ignoreRubric
    case fullMarks
    case effortInference
    case handwritingPenalty
    case studentBackground
    case noEvidence
    case finalGrade
}

struct CustomInstructionLintIssue: Codable, Equatable, Identifiable, Sendable {
    var id: String { category.rawValue }
    var category: CustomInstructionLintCategory
    var message: String
}

enum CustomInstructionLinter {
    private struct LintRule {
        let category: CustomInstructionLintCategory
        let patterns: [String]
        let message: String
    }

    static func lint(_ instructions: String) -> [CustomInstructionLintIssue] {
        let text = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }
        let rules: [LintRule] = [
            LintRule(
                category: .ignoreRubric,
                patterns: [#"ignore (the )?rubric"#, #"rubric no longer matters"#],
                message: "Custom instructions appear to override the rubric; teacher review is required."
            ),
            LintRule(
                category: .fullMarks,
                patterns: [#"always (give|award) full (marks|credit)"#, #"give full (marks|credit)"#, #"award full (marks|credit)"#],
                message: "Custom instructions appear to require full marks regardless of evidence; teacher review is required."
            ),
            LintRule(
                category: .effortInference,
                patterns: [#"grade based on effort"#, #"assume (the )?student tried hard"#, #"tried hard"#],
                message: "Custom instructions refer to effort or intent, which the local model must not infer."
            ),
            LintRule(
                category: .handwritingPenalty,
                patterns: [#"penali[sz]e handwriting"#, #"mark down handwriting"#],
                message: "Custom instructions appear to penalize handwriting even though this grading lane is text-evidence only."
            ),
            LintRule(
                category: .studentBackground,
                patterns: [#"use (the )?student'?s background"#, #"consider (the )?student'?s background"#, #"language background"#],
                message: "Custom instructions refer to student background; protected or demographic context must not be inferred."
            ),
            LintRule(
                category: .noEvidence,
                patterns: [#"do not require evidence"#, #"no evidence required"#, #"ignore evidence"#],
                message: "Custom instructions appear to remove the evidence requirement; teacher review is required."
            ),
            LintRule(
                category: .finalGrade,
                patterns: [#"make (the )?grade final"#, #"final grade"#, #"approve (the )?grade"#],
                message: "Custom instructions appear to ask for final-grade behavior; the teacher must approve final grades in app."
            )
        ]
        return rules.compactMap { rule in
            rule.patterns.contains { pattern in
                text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
            } ? CustomInstructionLintIssue(category: rule.category, message: rule.message) : nil
        }
    }
}

enum AIPacketPreviewBuilder {
    static func preview(input: GradingInput, plan: PromptBudgetPlan) -> AIPacketPreview {
        let sanitizedInput = GradingPacketBuilder.modelVisibleInput(from: input)
        let mode: PromptPacketMode = plan.mode == .compactFullPacket ? .compact : .full
        let prompt: String
        switch plan.mode {
        case .fullPacket, .compactFullPacket:
            prompt = PromptBuilder.gradingInstructionsText() + "\n\n" + PromptBuilder.fullPacketPromptText(input: sanitizedInput, mode: mode)
        case .perCriterion:
            let firstCriterion = sanitizedInput.parsedRubric.criteria.first
            prompt = PromptBuilder.gradingInstructionsText() + "\n\n" + firstCriterion.map {
                PromptBuilder.singleCriterionPromptText(input: sanitizedInput, criterion: $0)
            }.nonEmptyOr("Per-criterion generation selected, but no criterion prompt is available.")
        case .unavailable:
            prompt = PromptBuilder.gradingInstructionsText()
        }

        let packet = GradingPacketBuilder.packet(from: input)
        let risks = PromptInjectionRiskDetector.risks(in: packet)
        let selectedTemplates = GradingConstraintTemplates.templates(for: input.selectedInstructionTemplateIDs)
        return AIPacketPreview(
            assignmentID: input.assignmentID,
            includedInLocalDraft: [
                "Reviewed student response text: \(packet.studentEvidence.reviewedText.count) characters; scanned text status: \(packet.studentEvidence.ocrReviewStatus.displayName).",
                "Rubric criteria: \(packet.rubric.criteria.count); total possible points: \(GradeTotals.formatted(packet.rubric.criteria.reduce(0.0) { $0 + $1.maxPoints })).",
                "Teacher instructions: \(packet.teacherInstructions.count) block(s).",
                "Answer key: \(packet.answerKey == nil ? "not included" : "included").",
                "Exemplar: \(packet.exemplar == nil ? "not included" : "included").",
                "Curriculum references: \(packet.curriculumReference == nil ? "not included" : "included").",
                "AI constraints: \(selectedTemplates.map(\.title).joined(separator: ", ").nonEmptyOr("none selected")).",
                "Prompt-injection review: \(risks.isEmpty ? "no common risk phrases detected" : "\(risks.count) section(s) flagged for teacher review")."
            ],
            notSentToModel: [
                "Student name.",
                "Student ID.",
                "Class name and roster membership.",
                "Other student submissions.",
                "Export history.",
                "Local gradebook history.",
                "Device contacts, calendar, photos, and network data.",
                "Local source filenames and file paths."
            ],
            generationPlan: [
                "Mode: \(plan.mode.displayName).",
                "Measured input: \(measuredInputText(for: plan.report)).",
                "Reserved output: \(plan.report.reservedOutputTokens) tokens.",
                "Local-only: yes.",
                "Teacher review required before finalization: yes."
            ],
            promptVersion: GradeDraftPromptVersion.currentFoundationModelsTyped,
            promptFingerprint: plan.report.promptFingerprint,
            packetFingerprint: input.packetFingerprint,
            modelVisibleMetadata: [
                "Subject: \(input.subject.nonEmptyOr("Not specified."))",
                "Grade/year level: \(input.gradeLevel.nonEmptyOr("Not specified."))",
                "Assessment purpose: \(input.assessmentPurpose.rawValue)",
                "Source input count: \(input.sourceInputCount)",
                "Identity fields: redacted"
            ],
            technicalPromptPreview: prompt
        )
    }

    private static func measuredInputText(for report: PromptBudgetReport) -> String {
        switch report.selectedMode {
        case .fullPacket:
            return "\(report.fullPacketTokens ?? 0) tokens"
        case .compactFullPacket:
            return "\(report.compactPacketTokens ?? 0) tokens"
        case .perCriterion:
            return "up to \(report.perCriterionTokenCounts.values.max() ?? 0) tokens per criterion"
        case .unavailable:
            return "unavailable"
        }
    }
}

private enum PromptInjectionRiskDetector {
    static func risks(in packet: GradingPacket) -> [String] {
        let sections: [(String, String)] = [
            ("reviewed student text", packet.studentEvidence.reviewedText),
            ("teacher instructions", packet.teacherInstructions.map(\.text).joined(separator: "\n")),
            ("answer key", packet.answerKey?.rawText ?? ""),
            ("exemplar", packet.exemplar?.rawText ?? ""),
            ("curriculum reference", packet.curriculumReference?.rawText ?? "")
        ]
        return sections.compactMap { title, text in
            containsRiskPhrase(text) ? title : nil
        }
    }

    private static func containsRiskPhrase(_ text: String) -> Bool {
        let patterns = [
            #"ignore (all )?(previous|prior|above) instructions"#,
            #"reveal (the )?(hidden )?(prompt|instructions)"#,
            #"award full credit"#,
            #"give me 100"#,
            #"output only"#,
            #"bypass teacher review"#,
            #"rubric no longer matters"#
        ]
        return patterns.contains { pattern in
            text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }
}

private extension Optional where Wrapped == String {
    func nonEmptyOr(_ fallback: String) -> String {
        switch self {
        case .some(let value):
            return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : value
        case .none:
            return fallback
        }
    }
}

private extension String {
    func nonEmptyOr(_ fallback: String) -> String {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : self
    }
}

extension LocalModelGenerationMode {
    var displayName: String {
        switch self {
        case .fullPacket:
            return "Full packet"
        case .compactFullPacket:
            return "Compact packet"
        case .perCriterion:
            return "Per criterion"
        case .unavailable:
            return "Unavailable"
        }
    }
}
