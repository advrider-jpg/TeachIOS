import CoreGraphics
import Foundation
import XCTest
@testable import GradeDraft

final class GradeDraftUITabAndLanguageTests: XCTestCase {
    func testTopLevelTabsAreCanonicalTabsOnly() {
        let labels = AppTab.allCases.map(\.title)
        XCTAssertEqual(labels, ["Home", "Classes", "Assignments", "Review", "Exports"])

        let disallowedLabels = ["Students", "Settings", "Gradebook", "Grades", "Reports", "Assessments", "Dashboard"]
        XCTAssertTrue(Set(labels).isDisjoint(with: disallowedLabels), "Top-level tabs must stay on the shell vocabulary.")
    }

    func testRestoreAndAudienceLabelsUseTeacherLanguage() {
        XCTAssertEqual(RestoreResolution.restoreAsCopy.displayName, "Import as New Copy")
        XCTAssertEqual(GradeDraftUIStatus.studentFacing.rawValue, "Student-facing")
        XCTAssertEqual(GradeDraftUIStatus.teacherOnly.rawValue, "Teacher-only")
    }
}

final class GradeDraftOCRPreviewMappingTests: XCTestCase {
    func testScaledImageRectMapperAccountsForVerticalLetterboxing() {
        let imageSize = CGSize(width: 1_000, height: 500)
        let containerSize = CGSize(width: 300, height: 300)
        let imageRect = ScaledImageRectMapper.displayedImageRect(imageSize: imageSize, in: containerSize)
        XCTAssertEqual(imageRect.origin.x, 0, accuracy: 0.001)
        XCTAssertEqual(imageRect.origin.y, 75, accuracy: 0.001)
        XCTAssertEqual(imageRect.width, 300, accuracy: 0.001)
        XCTAssertEqual(imageRect.height, 150, accuracy: 0.001)

        let mapped = ScaledImageRectMapper.mappedRect(
            NormalizedRect(x: 0.10, y: 0.20, width: 0.50, height: 0.40),
            imageSize: imageSize,
            in: containerSize
        )
        XCTAssertEqual(mapped.minX, 30, accuracy: 0.001)
        XCTAssertEqual(mapped.minY, 135, accuracy: 0.001)
        XCTAssertEqual(mapped.width, 150, accuracy: 0.001)
        XCTAssertEqual(mapped.height, 60, accuracy: 0.001)
    }

    func testScaledImageRectMapperAccountsForHorizontalLetterboxing() {
        let imageSize = CGSize(width: 500, height: 1_000)
        let containerSize = CGSize(width: 300, height: 300)
        let imageRect = ScaledImageRectMapper.displayedImageRect(imageSize: imageSize, in: containerSize)
        XCTAssertEqual(imageRect.origin.x, 75, accuracy: 0.001)
        XCTAssertEqual(imageRect.origin.y, 0, accuracy: 0.001)
        XCTAssertEqual(imageRect.width, 150, accuracy: 0.001)
        XCTAssertEqual(imageRect.height, 300, accuracy: 0.001)

        let mapped = ScaledImageRectMapper.mappedRect(
            NormalizedRect(x: 0.20, y: 0.10, width: 0.40, height: 0.50),
            imageSize: imageSize,
            in: containerSize
        )
        XCTAssertEqual(mapped.minX, 105, accuracy: 0.001)
        XCTAssertEqual(mapped.minY, 120, accuracy: 0.001)
        XCTAssertEqual(mapped.width, 60, accuracy: 0.001)
        XCTAssertEqual(mapped.height, 150, accuracy: 0.001)
    }
}
