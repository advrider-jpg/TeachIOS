import Foundation

// MARK: - Report template source content

enum ReportTemplateCatalog {
    static let studentReportTemplates = [
        #"""
# GradeDraft Student Feedback

**Assignment:** {{assignmentTitle}}
**Student:** {{studentDisplayNameOrLocalIdentifier}}
**Class:** {{classNameOrNotSpecified}}
**Subject:** {{subjectOrNotSpecified}}
**Grade/year level:** {{gradeLevelOrNotSpecified}}
**Assignment type:** {{assignmentTypeDisplayName}}
**Updated:** {{updatedDate}}

> Generated from local app state. GradeDraft does not upload this report.
> This student-facing report excludes private teacher notes and raw model responses.
"""#,
        #"""
## Final teacher-approved grade

**Score:** {{finalTotalScore}} / {{finalMaxScore}}

### Feedback

{{teacherFinalStudentFeedback}}

### Criteria

{{#criteria}}
#### {{criterionName}}
- Final score: {{finalPoints}} / {{maxPoints}}
- Rating: {{ratingOrNotSpecified}}
- Evidence: {{studentFacingEvidence}}
- Explanation: {{studentFacingExplanation}}
{{/criteria}}
"""#,
        #"""
## Formative feedback

**Learning focus:** {{formativeFocus}}

### Evidence noticed

{{evidenceSummary}}

### Current understanding

{{currentUnderstandingFeedback}}

### Next step

{{nextStep}}

> This formative feedback is for learning support and is not a final grade unless the teacher marks it as summative.
"""#
    ]
    static let teacherAuditReportTemplates = [
        #"""
# GradeDraft Teacher Audit Report

**Assignment:** {{assignmentTitle}}
**Student:** {{studentDisplayNameOrLocalIdentifier}}
**Class:** {{classNameOrNotSpecified}}
**Subject:** {{subjectOrNotSpecified}}
**Grade/year level:** {{gradeLevelOrNotSpecified}}
**Assignment type:** {{assignmentTypeDisplayName}}
**Updated:** {{updatedDate}}

> This teacher audit report may include private notes, reviewed text, OCR warnings, source fingerprints, and grading-state metadata. Treat it as sensitive student data.
> Generated from local app state. GradeDraft does not upload this report.
"""#,
        #"""
## Readiness and source state
- OCR review status: {{ocrReviewStatus}}
- Source inputs: {{sourceInputCount}}
- Current grading packet fingerprint: {{packetFingerprint}}
- Draft stale: {{yesNo}}
- Final review stale: {{yesNo}}

## Source inputs
{{sourceInputList}}

## OCR summary
- Engine: {{ocrEngine}}
- Review status: {{ocrReviewStatus}}
- Quality: {{ocrQualitySummary}}
- Reviewed at: {{ocrReviewedAtOrNotReviewed}}

## Reviewed student text

{{reviewedStudentText}}

## Rubric and grading materials

### Rubric
{{rubricText}}

### Custom teacher instructions
{{customInstructions}}

### Formative focus
{{formativeFocusText}}

### Applied templates
{{appliedTemplates}}

### Answer key
{{answerKeyText}}

### Exemplar
{{exemplarText}}

## Model draft
- Draft status: {{draftStatus}}
- Score: {{draftTotalScore}} / {{draftMaxScore}}
- Packet fingerprint: {{draftPacketFingerprint}}

{{draftCriteria}}

### Uncertainty flags
{{uncertaintyFlags}}

### Compliance flags
{{complianceFlags}}

### Private model/teacher notes
{{draftTeacherNotes}}

## Final teacher review
- Status: {{finalStatus}}
- Score: {{finalTotalScore}} / {{finalMaxScore}}
- Packet fingerprint: {{finalPacketFingerprint}}
- Finalized at: {{finalizedAtOrNotFinalized}}

{{finalCriteria}}

### Private teacher notes
{{privateTeacherNotes}}

## Export records
{{exportRecords}}

## Audit events
{{auditEvents}}
"""#,
        #"""
Teacher audit reports may include private notes, OCR uncertainty, source references, draft scoring, final scoring, and reviewed student text. They are sensitive student records and should not be shared with students or families unless reviewed and redacted.
"""#
    ]

    static let studentReportExclusionRules = [
        "Exclude private teacher notes by default.",
        "Exclude raw model responses by default.",
        "Exclude internal compliance flags by default.",
        "Exclude OCR uncertainty flags by default unless the teacher explicitly chooses otherwise.",
        "Exclude source fingerprints and audit events by default."
    ]

    static let teacherAuditRequiredSections = [
        "Assignment packet summary",
        "Rubric and parsed criteria",
        "Teacher instructions",
        "Formative focus",
        "Applied templates",
        "Answer key",
        "Exemplar",
        "Student evidence and OCR status",
        "Draft proposal",
        "Final teacher review",
        "Uncertainty and compliance flags",
        "Export records",
        "Audit events"
    ]
}
