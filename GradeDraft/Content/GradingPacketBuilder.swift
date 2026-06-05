import Foundation

// MARK: - Grading packet construction

enum GradingPacketBuilder {
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
            packetVersion: "gradedraft-packet-v2",
            fingerprintSchemaVersion: "v4-content-suite",
            assignment: GradingPacketAssignment(
                assignmentID: input.assignmentID,
                classGroupID: nil,
                studentID: nil,
                title: input.assignmentTitle,
                prompt: input.prompt,
                subject: input.subject,
                gradeLevel: input.gradeLevel,
                className: input.className,
                studentDisplayName: input.studentDisplayName,
                assignmentType: input.assignmentType,
                assessmentPurpose: input.assessmentPurpose
            ),
            curriculumReference: curriculumText.isEmpty ? nil : GradingPacketCurriculumReference(rawText: curriculumText, mappings: []),
            rubric: GradingPacketRubric(rawText: input.rubricText, criteria: criteria),
            teacherInstructions: instructionText.isEmpty ? [] : [GradingPacketTeacherInstruction(id: nil, name: "Teacher custom instructions", text: instructionText, privateTeacherOnly: true)],
            formativeFocus: formativeText.isEmpty ? nil : GradingPacketFormativeFocus(rawText: formativeText),
            answerKey: answerKeyText.isEmpty ? nil : GradingPacketAnswerKey(rawText: answerKeyText),
            exemplar: exemplarText.isEmpty ? nil : GradingPacketExemplar(rawText: exemplarText),
            studentEvidence: GradingPacketStudentEvidence(
                reviewedText: input.reviewedStudentText,
                reviewedTextWithSourceRefs: input.reviewedTextWithSourceRefs,
                ocrReviewStatus: input.ocrReviewStatus,
                ocrReviewedAt: nil,
                ocrQualitySummary: input.ocrQualitySummary.displaySummary,
                hasLowConfidenceOCRText: input.ocrQualitySummary.lowConfidenceLineCount > 0,
                sourceInputCount: input.sourceInputCount,
                evidenceReferenceQuotes: []
            ),
            sourceInputs: [],
            evidenceReferences: [],
            appliedTemplates: [],
            outputRules: GradingPacketOutputRules(
                requireEvidenceQuotes: true,
                requireTeacherReviewForFinalGrade: true,
                doNotInferIntentAbilityEffort: true,
                studentFacingFeedbackOnly: true
            )
        )
    }

    static func modelVisiblePacket(from packet: GradingPacket, identityValues: [String] = []) -> GradingPacket {
        let values = identityValues + [packet.assignment.studentDisplayName, packet.assignment.className]
        var sanitized = packet
        sanitized.assignment.classGroupID = nil
        sanitized.assignment.studentID = nil
        sanitized.assignment.title = redactedText(sanitized.assignment.title, identityValues: values)
        sanitized.assignment.prompt = redactedText(sanitized.assignment.prompt, identityValues: values)
        sanitized.assignment.subject = redactedText(sanitized.assignment.subject, identityValues: values)
        sanitized.assignment.gradeLevel = redactedText(sanitized.assignment.gradeLevel, identityValues: values)
        sanitized.assignment.className = ""
        sanitized.assignment.studentDisplayName = ""
        sanitized.curriculumReference = sanitized.curriculumReference.map {
            GradingPacketCurriculumReference(rawText: redactedText($0.rawText, identityValues: values), mappings: $0.mappings)
        }
        sanitized.rubric.rawText = redactedText(sanitized.rubric.rawText, identityValues: values)
        sanitized.rubric.criteria = sanitized.rubric.criteria.map { criterion in
            GradingPacketRubricCriterion(
                id: criterion.id,
                title: redactedText(criterion.title, identityValues: values),
                maxPoints: criterion.maxPoints,
                descriptor: redactedText(criterion.descriptor, identityValues: values),
                groupTitle: criterion.groupTitle.map { redactedText($0, identityValues: values) }
            )
        }
        sanitized.teacherInstructions = sanitized.teacherInstructions.map { instruction in
            GradingPacketTeacherInstruction(
                id: instruction.id,
                name: instruction.name.map { redactedText($0, identityValues: values) },
                text: redactedText(instruction.text, identityValues: values),
                privateTeacherOnly: instruction.privateTeacherOnly
            )
        }
        sanitized.formativeFocus = sanitized.formativeFocus.map {
            GradingPacketFormativeFocus(rawText: redactedText($0.rawText, identityValues: values))
        }
        sanitized.answerKey = sanitized.answerKey.map {
            GradingPacketAnswerKey(rawText: redactedText($0.rawText, identityValues: values))
        }
        sanitized.exemplar = sanitized.exemplar.map {
            GradingPacketExemplar(rawText: redactedText($0.rawText, identityValues: values))
        }
        sanitized.studentEvidence.reviewedText = redactedText(sanitized.studentEvidence.reviewedText, identityValues: values)
        sanitized.studentEvidence.reviewedTextWithSourceRefs = redactedText(sanitized.studentEvidence.reviewedTextWithSourceRefs, identityValues: values)
        sanitized.studentEvidence.evidenceReferenceQuotes = sanitized.studentEvidence.evidenceReferenceQuotes.map {
            redactedText($0, identityValues: values)
        }
        sanitized.sourceInputs = sanitized.sourceInputs.map { source in
            var copy = source
            copy.localRelativePath = nil
            copy.fileName = nil
            return copy
        }
        sanitized.evidenceReferences = sanitized.evidenceReferences.map { evidence in
            GradingPacketEvidenceReference(
                id: evidence.id,
                sourceInputID: evidence.sourceInputID,
                ocrLineID: evidence.ocrLineID,
                pageIndex: evidence.pageIndex,
                quote: redactedText(evidence.quote, identityValues: values),
                sourceKind: evidence.sourceKind,
                teacherConfirmed: evidence.teacherConfirmed,
                boundingBox: evidence.boundingBox
            )
        }
        return sanitized
    }

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
        if let packet = input.plannedContentGradingPacket {
            sanitized.plannedContentGradingPacket = modelVisiblePacket(from: packet, identityValues: identityValues)
        }
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
    static func report(
        for assignment: AssignmentRecord,
        localAIStatus: LocalAIStatus,
        budgetPlan: PromptBudgetPlan? = nil,
        budgetError: Error? = nil
    ) -> AIReadinessReport {
        let packet = assignment.gradingPacket
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
                id: "ocr-review",
                title: "OCR review",
                detail: assignment.ocrReviewStatus.blocksGrading
                    ? "Review scanned text before drafting feedback."
                    : "Reviewed text is eligible for the grading packet.",
                status: assignment.ocrReviewStatus.blocksGrading ? .blocked : .ready
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
                detail: assignment.hasGradingStandard
                    ? "\(packet.rubric.criteria.count) structured criteria; answer key included: \(packet.answerKey == nil ? "no" : "yes"); exemplar included: \(packet.exemplar == nil ? "no" : "yes")."
                    : "Add a rubric, answer key, exemplar, or grading criteria.",
                status: assignment.hasGradingStandard ? .ready : .blocked
            ),
            AIReadinessCheck(
                id: "rubric-parse",
                title: "Rubric readiness",
                detail: rubricReadinessDetail(for: assignment),
                status: rubricReadinessStatus(for: assignment)
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
                detail: packet.curriculumReference == nil ? "No teacher-selected curriculum reference is included." : "Teacher-selected curriculum reference is included with source/provenance text.",
                status: packet.curriculumReference == nil ? .info : .ready
            ),
            AIReadinessCheck(
                id: "ai-constraints",
                title: "AI constraints",
                detail: constraintSummary(for: assignment),
                status: .ready
            ),
            AIReadinessCheck(
                id: "custom-instruction-lint",
                title: "Custom instruction safety",
                detail: customInstructionSafetySummary(for: assignment),
                status: customInstructionSafetyStatus(for: assignment)
            ),
            AIReadinessCheck(
                id: "sensitive-constraints",
                title: "Sensitive constraints",
                detail: sensitiveConstraintSummary(for: assignment),
                status: sensitiveConstraintStatus(for: assignment)
            ),
            AIReadinessCheck(
                id: "pii-redaction",
                title: "Identity redaction",
                detail: "Student name, student ID, class name, roster membership, file paths, and source filenames are removed from the model-visible packet by default.",
                status: .ready
            ),
            AIReadinessCheck(
                id: "local-tools",
                title: "Local tool policy",
                detail: LocalAIToolPolicy.gradingSession.policySummary,
                status: .ready
            ),
            AIReadinessCheck(
                id: "stale-state",
                title: "Draft and review freshness",
                detail: staleStateSummary(for: assignment),
                status: staleStateStatus(for: assignment)
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
            tokenSummary = "Run the local packet budget check before generation."
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
            assignmentID: assignment.id,
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
            return "Full packet, estimated input \(report.fullPacketTokens ?? 0) tokens, reserved output \(report.reservedOutputTokens)."
        case .compactFullPacket:
            return "Compact packet, estimated input \(report.compactPacketTokens ?? 0) tokens, reserved output \(report.reservedOutputTokens)."
        case .perCriterion:
            let largest = report.perCriterionTokenCounts.values.max() ?? 0
            return "Per-criterion packet, largest estimated input \(largest) tokens, reserved output \(report.reservedOutputTokens)."
        case .unavailable:
            return "Unavailable."
        }
    }

    private static func rubricReadinessDetail(for assignment: AssignmentRecord) -> String {
        let report = RubricReadinessAnalyzer.report(for: assignment)
        if !report.issues.isEmpty {
            return report.issues.joined(separator: " ")
        }
        if !report.warnings.isEmpty {
            return report.warnings.joined(separator: " ")
        }
        return "Structured rubric is ready for local draft planning."
    }

    private static func rubricReadinessStatus(for assignment: AssignmentRecord) -> AIReadinessStatus {
        let report = RubricReadinessAnalyzer.report(for: assignment)
        if !report.issues.isEmpty { return .blocked }
        if !report.warnings.isEmpty { return .needsReview }
        return .ready
    }

    private static func constraintSummary(for assignment: AssignmentRecord) -> String {
        let selected = GradingConstraintTemplates.templates(for: assignment.selectedInstructionTemplateIDs)
        guard !selected.isEmpty else { return "No AI constraint templates are selected." }
        return selected.map(\.title).joined(separator: ", ")
    }

    private static func customInstructionSafetySummary(for assignment: AssignmentRecord) -> String {
        let warnings = CustomInstructionLinter.lint(assignment.customInstructions).map(\.message)
        if warnings.isEmpty {
            return assignment.customInstructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "No custom teacher instructions are included."
                : "Custom teacher instructions did not match known unsafe instruction patterns."
        }
        return warnings.joined(separator: " ")
    }

    private static func customInstructionSafetyStatus(for assignment: AssignmentRecord) -> AIReadinessStatus {
        CustomInstructionLinter.lint(assignment.customInstructions).isEmpty ? .ready : .needsReview
    }

    private static func sensitiveConstraintSummary(for assignment: AssignmentRecord) -> String {
        let sensitive = GradingConstraintTemplates.templates(for: assignment.selectedInstructionTemplateIDs)
            .filter(\.sensitiveContextRequired)
        guard !sensitive.isEmpty else {
            return "No sensitive-context AI constraints are selected."
        }
        return "Teacher-selected sensitive-context constraints: \(sensitive.map(\.title).joined(separator: ", ")). Confirm this context is teacher-known and appropriate before drafting."
    }

    private static func sensitiveConstraintStatus(for assignment: AssignmentRecord) -> AIReadinessStatus {
        GradingConstraintTemplates.templates(for: assignment.selectedInstructionTemplateIDs)
            .contains(where: \.sensitiveContextRequired) ? .needsReview : .ready
    }

    private static func staleStateSummary(for assignment: AssignmentRecord) -> String {
        if assignment.latestDraftIsStale && assignment.finalReviewIsStale {
            return "Existing local draft and final review need rechecking because grading inputs changed."
        }
        if assignment.latestDraftIsStale {
            return "Existing local draft needs rechecking because grading inputs changed."
        }
        if assignment.finalReviewIsStale {
            return "Existing final review needs rechecking because grading inputs changed."
        }
        return "No stale draft or final-review state was detected for the current grading packet."
    }

    private static func staleStateStatus(for assignment: AssignmentRecord) -> AIReadinessStatus {
        (assignment.latestDraftIsStale || assignment.finalReviewIsStale) ? .needsReview : .ready
    }
}

enum RubricReadinessAnalyzer {
    static func report(for assignment: AssignmentRecord) -> RubricReadinessReport {
        let parsed = assignment.parsedRubric
        var issues: [String] = []
        var warnings: [String] = []
        let trimmedRubric = assignment.rubricText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedRubric.isEmpty && assignment.answerKeyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && assignment.exemplarText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("Add a rubric, answer key, exemplar, or grading criteria.")
        }
        if !trimmedRubric.isEmpty && parsed.criteria.isEmpty {
            warnings.append("Rubric text has no teacher-confirmed point-bearing criteria; local AI must mark every criterion for teacher review.")
        }
        let duplicateTitles = duplicateNormalizedTitles(parsed.criteria)
        if !duplicateTitles.isEmpty {
            warnings.append("Duplicate rubric criteria detected: \(duplicateTitles.joined(separator: ", ")).")
        }
        let missingPoints = parsed.criteria.filter { $0.maxPoints <= 0 }.map(\.title)
        if !missingPoints.isEmpty {
            warnings.append("Criteria without positive max points: \(missingPoints.joined(separator: ", ")).")
        }
        warnings.append(contentsOf: parsed.issues)
        let combined = [
            assignment.rubricText,
            assignment.customInstructions,
            assignment.answerKeyText,
            assignment.exemplarText
        ].joined(separator: "\n")
        if containsContradictionLanguage(combined) {
            warnings.append("Possible contradictory grading instructions detected; teacher review is required before relying on the draft.")
        }
        let customInstructionWarnings = CustomInstructionLinter.lint(assignment.customInstructions)
        warnings.append(contentsOf: customInstructionWarnings.map(\.message))
        if requiresNonTextualJudgment(combined) && assignment.sourceInputs.isEmpty {
            warnings.append("Rubric may require visual, diagram, handwriting, audio, or performance judgment that is not represented in reviewed text.")
        }
        if assignment.assessmentPurpose == .summative {
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
    static func lint(_ instructions: String) -> [CustomInstructionLintIssue] {
        let text = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }
        let rules: [(CustomInstructionLintCategory, [String], String)] = [
            (
                .ignoreRubric,
                [#"ignore (the )?rubric"#, #"rubric no longer matters"#],
                "Custom instructions appear to override the rubric; teacher review is required."
            ),
            (
                .fullMarks,
                [#"always (give|award) full (marks|credit)"#, #"give full (marks|credit)"#, #"award full (marks|credit)"#],
                "Custom instructions appear to require full marks regardless of evidence; teacher review is required."
            ),
            (
                .effortInference,
                [#"grade based on effort"#, #"assume (the )?student tried hard"#, #"tried hard"#],
                "Custom instructions refer to effort or intent, which the local model must not infer."
            ),
            (
                .handwritingPenalty,
                [#"penali[sz]e handwriting"#, #"mark down handwriting"#],
                "Custom instructions appear to penalize handwriting even though this grading lane is text-evidence only."
            ),
            (
                .studentBackground,
                [#"use (the )?student'?s background"#, #"consider (the )?student'?s background"#, #"language background"#],
                "Custom instructions refer to student background; protected or demographic context must not be inferred."
            ),
            (
                .noEvidence,
                [#"do not require evidence"#, #"no evidence required"#, #"ignore evidence"#],
                "Custom instructions appear to remove the evidence requirement; teacher review is required."
            ),
            (
                .finalGrade,
                [#"make (the )?grade final"#, #"final grade"#, #"approve (the )?grade"#],
                "Custom instructions appear to ask for final-grade behavior; the teacher must approve final grades in app."
            )
        ]
        return rules.compactMap { category, patterns, message in
            patterns.contains { pattern in
                text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
            } ? CustomInstructionLintIssue(category: category, message: message) : nil
        }
    }
}

enum AIPacketPreviewBuilder {
    static func preview(for assignment: AssignmentRecord, plan: PromptBudgetPlan) -> AIPacketPreview {
        let input = assignment.gradingInput
        let sanitizedInput = GradingPacketBuilder.modelVisibleInput(from: input)
        let mode: PromptPacketMode = plan.mode == .compactFullPacket ? .compact : .full
        let prompt: String
        switch plan.mode {
        case .fullPacket, .compactFullPacket:
            prompt = PromptBuilder.gradingInstructionsText(input: sanitizedInput) + "\n\n" + PromptBuilder.fullPacketPromptText(input: sanitizedInput, mode: mode)
        case .perCriterion:
            let firstCriterion = sanitizedInput.parsedRubric.criteria.first
            prompt = PromptBuilder.gradingInstructionsText(input: sanitizedInput) + "\n\n" + firstCriterion.map {
                PromptBuilder.singleCriterionPromptText(input: sanitizedInput, criterion: $0)
            }.nonEmptyOr("Per-criterion generation selected, but no criterion prompt is available.")
        case .unavailable:
            prompt = PromptBuilder.gradingInstructionsText(input: sanitizedInput)
        }

        let packet = assignment.gradingPacket
        let risks = PromptInjectionRiskDetector.risks(in: packet)
        let selectedTemplates = GradingConstraintTemplates.templates(for: assignment.selectedInstructionTemplateIDs)
        return AIPacketPreview(
            assignmentID: assignment.id,
            includedInLocalDraft: [
                "Reviewed student response text: \(packet.studentEvidence.reviewedText.count) characters; OCR status: \(packet.studentEvidence.ocrReviewStatus.displayName).",
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
                "Estimated input: \(estimatedInputText(for: plan.report)).",
                "Reserved output: \(plan.report.reservedOutputTokens) tokens.",
                "Local-only: yes.",
                "Teacher review required before finalization: yes."
            ],
            promptVersion: GradeDraftPromptVersion.currentFoundationModelsTyped,
            promptFingerprint: plan.report.promptFingerprint,
            packetFingerprint: input.packetFingerprint,
            modelVisibleMetadata: [
                "Assignment ID: \(input.assignmentID.uuidString)",
                "Subject: \(input.subject.nonEmptyOr("Not specified."))",
                "Grade/year level: \(input.gradeLevel.nonEmptyOr("Not specified."))",
                "Assessment purpose: \(input.assessmentPurpose.rawValue)",
                "Source input count: \(input.sourceInputCount)",
                "Identity fields: redacted"
            ],
            technicalPromptPreview: prompt
        )
    }

    private static func estimatedInputText(for report: PromptBudgetReport) -> String {
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

extension AssignmentRecord {
    /// Typed packet assembled from the assignment record. Prompt construction, local app-state
    /// fingerprinting, and reports use this one explicit source object.
    var gradingPacket: GradingPacket {
        let parsed = parsedRubric
        let criteria = parsed.criteria.map { criterion in
            GradingPacketRubricCriterion(
                id: criterion.id,
                title: criterion.title,
                maxPoints: criterion.maxPoints,
                descriptor: criterion.descriptor,
                groupTitle: criterion.groupTitle
            )
        }
        let trimmedCurriculum = curriculumReference.trimmingCharacters(in: .whitespacesAndNewlines)
        let curriculum = trimmedCurriculum.isEmpty ? nil : GradingPacketCurriculumReference(
            rawText: trimmedCurriculum,
            mappings: curriculumMappings.filter { $0.teacherSelected }.map { mapping in
                [mapping.curriculumItemID, mapping.mappingKind, mapping.rubricCriterionID ?? "", mapping.evidenceReferenceID?.uuidString ?? ""].joined(separator: ":")
            }
        )
        let instructionText = GradeDraftTemplateApplication.withoutTemplateMarkers(customInstructions)
        let teacherInstructions = instructionText.isEmpty ? [] : [
            GradingPacketTeacherInstruction(id: nil, name: "Teacher custom instructions", text: instructionText, privateTeacherOnly: true)
        ]
        let formativeText = GradeDraftTemplateApplication.withoutTemplateMarkers(formativeFocusText)
        let formativeFocus = formativeText.isEmpty ? nil : GradingPacketFormativeFocus(rawText: formativeText)
        let answerKeyClean = GradeDraftTemplateApplication.withoutTemplateMarkers(answerKeyText)
        let exemplarClean = GradeDraftTemplateApplication.withoutTemplateMarkers(exemplarText)
        let answerKey = answerKeyClean.isEmpty ? nil : GradingPacketAnswerKey(rawText: answerKeyClean)
        let exemplar = exemplarClean.isEmpty ? nil : GradingPacketExemplar(rawText: exemplarClean)
        return GradingPacket(
            packetVersion: "gradedraft-packet-v2",
            fingerprintSchemaVersion: gradingPacketFingerprintVersion,
            assignment: GradingPacketAssignment(
                assignmentID: id,
                classGroupID: classGroupID,
                studentID: studentID,
                title: title,
                prompt: prompt ?? "",
                subject: subject,
                gradeLevel: gradeLevel,
                className: className,
                studentDisplayName: studentDisplayName,
                assignmentType: assignmentType,
                assessmentPurpose: assessmentPurpose
            ),
            curriculumReference: curriculum,
            rubric: GradingPacketRubric(rawText: rubricText, criteria: criteria),
            teacherInstructions: teacherInstructions,
            formativeFocus: formativeFocus,
            answerKey: answerKey,
            exemplar: exemplar,
            studentEvidence: GradingPacketStudentEvidence(
                reviewedText: reviewedStudentText,
                reviewedTextWithSourceRefs: sourceReferencedReviewedText,
                ocrReviewStatus: ocrReviewStatus,
                ocrReviewedAt: ocrReviewedAt,
                ocrQualitySummary: ocrDocument?.qualitySummary.displaySummary ?? OCRQualitySummary().displaySummary,
                hasLowConfidenceOCRText: ocrDocument?.hasLowConfidenceText ?? false,
                sourceInputCount: sourceInputs.count,
                evidenceReferenceQuotes: evidenceReferences.map(\.quote)
            ),
            sourceInputs: sourceInputs.map { source in
                GradingPacketSourceInput(
                    id: source.id,
                    sourceType: source.sourceType,
                    pageIndex: source.pageIndex,
                    localRelativePath: source.localRelativePath,
                    fileName: source.fileName,
                    contentDigest: source.contentDigest,
                    digestAlgorithm: source.digestAlgorithm,
                    teacherIncludedInExport: source.teacherIncludedInExport
                )
            },
            evidenceReferences: evidenceReferences.map { evidence in
                GradingPacketEvidenceReference(
                    id: evidence.id,
                    sourceInputID: evidence.sourceInputID,
                    ocrLineID: evidence.ocrLineID,
                    pageIndex: evidence.pageIndex,
                    quote: evidence.quote,
                    sourceKind: evidence.sourceKind,
                    teacherConfirmed: evidence.teacherConfirmed,
                    boundingBox: evidence.boundingBox?.stableDisplay
                )
            },
            appliedTemplates: appliedTemplates,
            outputRules: GradingPacketOutputRules(
                requireEvidenceQuotes: true,
                requireTeacherReviewForFinalGrade: true,
                doNotInferIntentAbilityEffort: true,
                studentFacingFeedbackOnly: true
            )
        )
    }

    /// Backwards-compatible API name retained for existing callers.
    var plannedContentGradingPacket: GradingPacket { gradingPacket }

    var gradingPacketFingerprintVersion: String { "v4-content-suite" }

    /// Deterministic local app-state fingerprint for the typed packet and AI constraint templates. This is not a security claim.
    var gradingPacketFingerprint: String {
        let packetFP = StableFingerprint.fingerprint(encodedGradingPacket)
        let templateFP = GradingConstraintTemplates.fingerprint(for: selectedInstructionTemplateIDs)
        if selectedInstructionTemplateIDs.isEmpty {
            return packetFP
        }
        return StableFingerprint.fingerprint([packetFP, templateFP])
    }

    /// Backwards-compatible API name retained for existing callers.
    var plannedContentPacketFingerprint: String { gradingPacketFingerprint }

    private var encodedGradingPacket: Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(gradingPacket)) ?? Data()
    }
}
