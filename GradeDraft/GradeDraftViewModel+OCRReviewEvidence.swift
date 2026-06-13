import Foundation
import PDFKit
import UIKit
import ZIPFoundation

@MainActor
extension GradeDraftViewModel {
    func markOCRReviewed() {
        guard let currentAssignment = currentSavedAssignmentForAction("Mark scanned text reviewed"),
              let existingDocument = currentAssignment.ocrDocument else { return }
        guard existingDocument.unresolvedLineCount == 0 else {
            errorMessage = "Confirm, correct, or reject every scanned text line before marking the document reviewed. Low-confidence lines require individual teacher action."
            return
        }
        updateAssignment { assignment in
            guard var document = assignment.ocrDocument else { return }
            document.reviewStatus = .reviewed
            document.reviewedAt = Date()
            applyOCRReviewState(&document, to: &assignment)
            assignment.latestDraft = nil
            assignment.finalReview = nil
            assignment.appendAuditEvent(.ocrReviewed, detail: "Teacher marked scanned text reviewed. Reviewed text is now eligible for grading.")
        }
        guard persistOrSurfaceError() else { return }
        statusMessage = "Scanned text reviewed. Draft feedback is now available if Local AI and rubric are ready."
    }

    func applyOCRReviewState(_ document: inout OCRDocument, to assignment: inout AssignmentRecord, reviewedAt now: Date = Date()) {
        if document.hasUnconfirmedLines {
            document.reviewStatus = .needsReview
            document.reviewedAt = nil
            assignment.ocrReviewStatus = .needsReview
            assignment.ocrReviewedAt = nil
        } else {
            document.reviewStatus = .reviewed
            document.reviewedAt = now
            assignment.ocrReviewStatus = .reviewed
            assignment.ocrReviewedAt = now
        }
        assignment.ocrDocument = document
        assignment.reviewedStudentText = document.combinedText
    }

    @discardableResult
    func updateOCRLine(pageID: UUID, lineID: UUID, correctedText: String) -> Bool {
        updateOCRLines([OCRLineCorrection(pageID: pageID, lineID: lineID, correctedText: correctedText)])
    }

    @discardableResult
    func updateOCRLines(_ corrections: [OCRLineCorrection]) -> Bool {
        guard currentSavedAssignmentForAction("Update scanned text lines") != nil else { return false }
        var changedLineCount = 0
        updateAssignment { assignment in
            guard var document = assignment.ocrDocument else { return }
            for correction in corrections {
                for pageIndex in document.pages.indices where document.pages[pageIndex].id == correction.pageID {
                    for lineIndex in document.pages[pageIndex].lines.indices where document.pages[pageIndex].lines[lineIndex].id == correction.lineID {
                        guard document.pages[pageIndex].lines[lineIndex].correctedText != correction.correctedText else { continue }
                        document.pages[pageIndex].lines[lineIndex].correctedText = correction.correctedText
                        document.pages[pageIndex].lines[lineIndex].teacherConfirmed = false
                        changedLineCount += 1
                    }
                }
            }
            guard changedLineCount > 0 else { return }
            applyOCRReviewState(&document, to: &assignment)
            assignment.latestDraft = nil
            assignment.finalReview = nil
            assignment.appendAuditEvent(.inputChanged, detail: "Edited \(changedLineCount) scanned text line(s) during teacher review.")
        }
        guard changedLineCount > 0 else { return !corrections.isEmpty }
        return persistOrSurfaceError()
    }

    func confirmOCRLine(pageID: UUID, lineID: UUID) {
        guard currentSavedAssignmentForAction("Confirm scanned text line") != nil else { return }
        updateAssignment { assignment in
            guard var document = assignment.ocrDocument else { return }
            for pageIndex in document.pages.indices where document.pages[pageIndex].id == pageID {
                for lineIndex in document.pages[pageIndex].lines.indices where document.pages[pageIndex].lines[lineIndex].id == lineID {
                    document.pages[pageIndex].lines[lineIndex].teacherConfirmed = true
                }
            }
            applyOCRReviewState(&document, to: &assignment)
            assignment.latestDraft = nil
            assignment.finalReview = nil
            assignment.appendAuditEvent(.ocrReviewed, detail: "Confirmed scanned text line during teacher review.")
        }
        persistOrSurfaceError()
    }

    func rejectOCRLine(pageID: UUID, lineID: UUID) {
        guard currentSavedAssignmentForAction("Reject scanned text line") != nil else { return }
        updateAssignment { assignment in
            guard var document = assignment.ocrDocument else { return }
            for pageIndex in document.pages.indices where document.pages[pageIndex].id == pageID {
                for lineIndex in document.pages[pageIndex].lines.indices where document.pages[pageIndex].lines[lineIndex].id == lineID {
                    document.pages[pageIndex].lines[lineIndex].isRejected = true
                    document.pages[pageIndex].lines[lineIndex].teacherConfirmed = true
                }
            }
            applyOCRReviewState(&document, to: &assignment)
            assignment.latestDraft = nil
            assignment.finalReview = nil
            assignment.appendAuditEvent(.inputChanged, detail: "Rejected scanned text line during teacher review; original file details were preserved and line text was excluded from reviewed text.")
        }
        persistOrSurfaceError()
    }

    func markOCRPageReviewed(pageID: UUID) {
        guard currentSavedAssignmentForAction("Mark scanned text page reviewed") != nil else { return }
        var foundPage = false
        var blockedLowConfidenceLines = 0
        updateAssignment { assignment in
            guard var document = assignment.ocrDocument else { return }
            for pageIndex in document.pages.indices where document.pages[pageIndex].id == pageID {
                foundPage = true
                blockedLowConfidenceLines = document.pages[pageIndex].lines.filter {
                    !$0.isRejected && !$0.teacherConfirmed && $0.confidence < OCRQualitySummary.lowConfidenceThreshold
                }.count
                guard blockedLowConfidenceLines == 0 else { return }
                for lineIndex in document.pages[pageIndex].lines.indices where !document.pages[pageIndex].lines[lineIndex].isRejected {
                    document.pages[pageIndex].lines[lineIndex].teacherConfirmed = true
                }
            }
            guard foundPage else { return }
            guard blockedLowConfidenceLines == 0 else { return }
            applyOCRReviewState(&document, to: &assignment)
            assignment.latestDraft = nil
            assignment.finalReview = nil
            assignment.appendAuditEvent(.ocrReviewed, detail: "Teacher marked a scanned page reviewed after resolving every active line on that page.")
        }
        guard foundPage else { return }
        if blockedLowConfidenceLines > 0 {
            errorMessage = "Review each low-confidence OCR line before marking the page reviewed."
            return
        }
        persistOrSurfaceError()
    }

    func nextUnreviewedLine(after currentLineID: UUID? = nil) -> (pageID: UUID, lineID: UUID)? {
        guard let currentAssignment = currentSavedAssignmentForAction("Find next unreviewed scanned text line"),
              let document = currentAssignment.ocrDocument else { return nil }
        let unresolved = document.pages.sorted { $0.pageIndex < $1.pageIndex }.flatMap { page in
            page.lines.filter { $0.needsReview }.map { (page.id, $0.id) }
        }
        guard !unresolved.isEmpty else { return nil }
        guard let currentLineID, let currentIndex = unresolved.firstIndex(where: { $0.1 == currentLineID }) else { return unresolved.first }
        return unresolved[(currentIndex + 1) % unresolved.count]
    }

    func addOCRLineEvidenceToFinalReview(pageID: UUID, lineID: UUID, criterionID: UUID?) {
        guard let currentAssignment = currentSavedAssignmentForAction("Add scanned text evidence"),
              var review = currentAssignment.finalReview,
              let document = currentAssignment.ocrDocument,
              let page = document.pages.first(where: { $0.id == pageID }),
              let line = page.lines.first(where: { $0.id == lineID }) else { return }
        let quote = line.reviewedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !quote.isEmpty else { return }
        let evidenceRef = EvidenceReference(
            sourceInputID: page.sourceInputID,
            ocrLineID: line.id,
            pageIndex: page.pageIndex,
            quote: quote,
            startOffset: nil,
            endOffset: nil,
            boundingBox: line.boundingBox,
            sourceKind: "ocrLine",
            teacherConfirmed: line.teacherConfirmed
        )
        let sourceRef = evidenceSourceReference(page: page, line: line, evidenceID: evidenceRef.id)
        let targetIndex: Int
        if let criterionID, let found = review.criteria.firstIndex(where: { $0.id == criterionID }) {
            targetIndex = found
        } else {
            targetIndex = review.criteria.startIndex
        }
        guard review.criteria.indices.contains(targetIndex) else { return }
        review.criteria[targetIndex].evidence.append(quote)
        var refs = review.criteria[targetIndex].evidenceSourceRefs ?? []
        refs.append(sourceRef)
        review.criteria[targetIndex].evidenceSourceRefs = refs
        review.criteria[targetIndex].teacherApproved = false
        review.teacherEdited = true
        updateAssignment { assignment in
            assignment.evidenceReferences.append(evidenceRef)
            assignment.finalReview = GradeTotals.applyingDeterministicTotals(to: review)
            assignment.appendAuditEvent(.inputChanged, detail: "Linked scanned text evidence to final-review criterion.")
        }
        persistOrSurfaceError()
    }

    func addManualEvidenceToFinalReview(criterionID: UUID?, quote: String) {
        guard let currentAssignment = currentSavedAssignmentForAction("Add manual evidence"),
              var review = currentAssignment.finalReview else { return }
        let cleanedQuote = quote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedQuote.isEmpty else { return }
        let evidenceRef = EvidenceReference(
            sourceInputID: nil,
            ocrLineID: nil,
            pageIndex: nil,
            quote: cleanedQuote,
            startOffset: nil,
            endOffset: nil,
            boundingBox: nil,
            sourceKind: "manualTeacherEntry",
            teacherConfirmed: true
        )
        let targetIndex: Int
        if let criterionID, let found = review.criteria.firstIndex(where: { $0.id == criterionID }) {
            targetIndex = found
        } else {
            targetIndex = review.criteria.startIndex
        }
        guard review.criteria.indices.contains(targetIndex) else { return }
        review.criteria[targetIndex].evidence.append(cleanedQuote)
        var refs = review.criteria[targetIndex].evidenceSourceRefs ?? []
        refs.append("evidence:\(evidenceRef.id.uuidString):manualTeacherEntry")
        review.criteria[targetIndex].evidenceSourceRefs = refs
        review.criteria[targetIndex].teacherApproved = false
        review.teacherEdited = true
        updateAssignment { assignment in
            assignment.evidenceReferences.append(evidenceRef)
            assignment.finalReview = GradeTotals.applyingDeterministicTotals(to: review)
            assignment.appendAuditEvent(.inputChanged, detail: "Added manual teacher evidence to final-review criterion.")
        }
        persistOrSurfaceError()
    }

    func removeEvidenceFromFinalReview(criterionID: UUID, evidenceIndex: Int) {
        guard let currentAssignment = currentSavedAssignmentForAction("Remove final-review evidence"),
              var review = currentAssignment.finalReview,
              let criterionIndex = review.criteria.firstIndex(where: { $0.id == criterionID }),
              review.criteria[criterionIndex].evidence.indices.contains(evidenceIndex) else { return }
        let removedQuote = review.criteria[criterionIndex].evidence.remove(at: evidenceIndex)
        var removedEvidenceID: UUID?
        if var refs = review.criteria[criterionIndex].evidenceSourceRefs, refs.indices.contains(evidenceIndex) {
            let ref = refs.remove(at: evidenceIndex)
            removedEvidenceID = evidenceID(in: ref)
            review.criteria[criterionIndex].evidenceSourceRefs = refs
        }
        review.criteria[criterionIndex].teacherApproved = false
        review.teacherEdited = true
        updateAssignment { assignment in
            if let removedEvidenceID {
                assignment.evidenceReferences.removeAll { $0.id == removedEvidenceID }
            } else {
                assignment.evidenceReferences.removeAll { $0.quote == removedQuote }
            }
            assignment.finalReview = GradeTotals.applyingDeterministicTotals(to: review)
            assignment.appendAuditEvent(.inputChanged, detail: "Removed evidence from final-review criterion and synchronized source references.")
        }
        persistOrSurfaceError()
    }

    func clearEvidenceFromFinalReview(criterionID: UUID) {
        guard let currentAssignment = currentSavedAssignmentForAction("Clear final-review evidence"),
              var review = currentAssignment.finalReview,
              let criterionIndex = review.criteria.firstIndex(where: { $0.id == criterionID }) else { return }
        let ids = (review.criteria[criterionIndex].evidenceSourceRefs ?? []).compactMap(evidenceID(in:))
        review.criteria[criterionIndex].evidence = []
        review.criteria[criterionIndex].evidenceSourceRefs = []
        review.criteria[criterionIndex].teacherApproved = false
        review.teacherEdited = true
        updateAssignment { assignment in
            assignment.evidenceReferences.removeAll { ids.contains($0.id) }
            assignment.finalReview = GradeTotals.applyingDeterministicTotals(to: review)
            assignment.appendAuditEvent(.inputChanged, detail: "Cleared criterion evidence and source references.")
        }
        persistOrSurfaceError()
    }

    func evidenceID(in sourceReference: String) -> UUID? {
        guard let range = sourceReference.range(of: #"evidence:([A-Fa-f0-9-]{36})"#, options: .regularExpression) else { return nil }
        let match = String(sourceReference[range])
        return UUID(uuidString: match.replacingOccurrences(of: "evidence:", with: ""))
    }
}
