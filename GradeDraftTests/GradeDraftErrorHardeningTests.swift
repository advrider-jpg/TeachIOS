import XCTest
@testable import GradeDraft

// MARK: - GradeDraftError messages

final class GradeDraftErrorHardeningTests: XCTestCase {
    func testAllErrorsHaveDescriptions() {
        let errors: [GradeDraftError] = [
            .missingRubric,
            .missingStudentText,
            .ocrReviewRequired,
            .localModelUnavailable("reason"),
            .malformedModelResponse("detail"),
            .invalidModelGrade("detail"),
            .ocrFailed("detail"),
            .persistenceFailed("detail"),
            .exportFailed("detail")
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "\(error) should have a description")
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    func testErrorEquality() {
        XCTAssertEqual(GradeDraftError.missingRubric, GradeDraftError.missingRubric)
        XCTAssertNotEqual(GradeDraftError.missingRubric, GradeDraftError.missingStudentText)
        XCTAssertEqual(
            GradeDraftError.localModelUnavailable("a"),
            GradeDraftError.localModelUnavailable("a")
        )
        XCTAssertNotEqual(
            GradeDraftError.localModelUnavailable("a"),
            GradeDraftError.localModelUnavailable("b")
        )
    }

    func testNoProhibitedLabelsInErrorMessages() {
        let prohibited = ["auto-grade", "AutoGrade", "Accept AI grade", "AI final grade", "one-click grade", "Guaranteed Score"]
        let errors: [GradeDraftError] = [.missingRubric, .missingStudentText, .ocrReviewRequired]
        for error in errors {
            for term in prohibited {
                XCTAssertFalse(error.localizedDescription.contains(term))
            }
        }
    }
}
