import XCTest
@testable import GradeDraft

// MARK: - AssignmentType / AssessmentPurpose

final class EnumDisplayNameTests: XCTestCase {
    func testAssignmentTypeDisplayNames() {
        for type in AssignmentType.allCases {
            XCTAssertFalse(type.displayName.isEmpty, "\(type.rawValue) should have a display name")
        }
    }

    func testAssessmentPurposeDisplayNames() {
        for purpose in AssessmentPurpose.allCases {
            XCTAssertFalse(purpose.displayName.isEmpty, "\(purpose.rawValue) should have a display name")
        }
    }

    func testSourceTypeDisplayNames() {
        for sourceType in SourceType.allCases {
            XCTAssertFalse(sourceType.displayName.isEmpty, "\(sourceType.rawValue) should have a display name")
        }
    }

    func testExportKindDisplayNames() {
        let allKinds: [ExportKind] = [.studentMarkdown, .teacherAuditMarkdown, .studentPDF, .teacherAuditPDF, .csvGradebook, .zipArchive, .fullBackupArchive, .backupJSON, .assignmentGradebookArchive]
        for kind in allKinds {
            XCTAssertFalse(kind.displayName.isEmpty, "\(kind.rawValue) should have a display name")
        }
    }
}
