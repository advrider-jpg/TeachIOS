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
            mappings: curriculumMappings.map { mapping in
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

    /// Deterministic local app-state fingerprint for the typed packet. This is not a security claim.
    var gradingPacketFingerprint: String {
        StableFingerprint.fingerprint(encodedGradingPacket)
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
