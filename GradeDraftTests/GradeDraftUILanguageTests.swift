import CoreGraphics
import Foundation
import XCTest
@testable import GradeDraft

final class GradeDraftUITabAndLanguageTests: XCTestCase {
    func testTopLevelTabsAreV6CanonicalTabsOnly() {
        let labels = GradeDraftTab.allCases.map(\.title)
        XCTAssertEqual(labels, ["Home", "Classes", "Assignments", "Review", "Exports"])

        let disallowedLabels = ["Students", "Settings", "Gradebook", "Grades", "Reports", "Assessments", "Dashboard"]
        XCTAssertTrue(Set(labels).isDisjoint(with: disallowedLabels), "Top-level tabs must stay on the v6 shell vocabulary.")
    }

    func testExportConfirmationCopyMatchesStudentFacingAndTeacherOnlyPrivacyRules() {
        let studentSections = ExportConfirmationKind.studentReportPDF.sections
        let studentItems = studentSections.flatMap(\.items)
        XCTAssertEqual(ExportConfirmationKind.studentReportPDF.title, "Student Report PDF")
        XCTAssertTrue(studentItems.contains("Final grade"))
        XCTAssertTrue(studentItems.contains("Student-facing feedback"))
        XCTAssertTrue(studentItems.contains("Approved evidence excerpts"))
        XCTAssertTrue(studentItems.contains("Private teacher notes"))
        XCTAssertTrue(studentItems.contains("Review history"))
        XCTAssertTrue(studentItems.contains("Unreviewed AI suggestions"))
        XCTAssertTrue(studentItems.contains("Device file details"))
        XCTAssertTrue(studentItems.contains("Internal source details"))
        XCTAssertTrue(studentItems.contains("Other students' information"))

        let teacherItems = ExportConfirmationKind.teacherReviewPDF.sections.flatMap(\.items)
        XCTAssertEqual(ExportConfirmationKind.teacherReviewPDF.title, "Teacher Record PDF")
        XCTAssertTrue(ExportConfirmationKind.teacherReviewPDF.subtitle.contains("Teacher-only record"))
        XCTAssertTrue(teacherItems.contains("Private teacher notes"))
        XCTAssertTrue(teacherItems.contains("Review history"))
        XCTAssertTrue(teacherItems.contains("Scanned-text review details"))
        XCTAssertTrue(teacherItems.contains("Original-file details"))
        XCTAssertTrue(teacherItems.contains("Internal review details"))
    }

    func testRestoreAndAudienceLabelsUseV6TeacherLanguage() {
        XCTAssertEqual(BackupConflictResolution.restoreAsCopy.displayName, "Import as New Copy")
        XCTAssertEqual(GradeDraftUIStatus.studentFacing.rawValue, "Student-facing")
        XCTAssertEqual(GradeDraftUIStatus.studentFacing.chipLabel, "Student-facing")
        XCTAssertEqual(GradeDraftUIStatus.teacherOnly.rawValue, "Teacher-only")
        XCTAssertEqual(GradeDraftUIStatus.teacherOnly.chipLabel, "Teacher-only")
    }

    func testWorkflowLanguageConstantsKeepOCRReviewNamingStable() {
        XCTAssertEqual(GradeDraftWorkflowLanguage.ocrReviewStepLabel, "Check Scanned Text")
        XCTAssertEqual(GradeDraftWorkflowLanguage.reviewScannedTextScreenTitle, "Review Scanned Text")
        XCTAssertEqual(GradeDraftWorkflowLanguage.reviewTextActionLabel, "Review Text")
        XCTAssertEqual(GradeDraftWorkflowLanguage.reviewScannedTextExplanation, "Review scanned text before drafting feedback.")
    }


    func testNativeRefactorSafetyCopyRemainsVisible() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let uiSource = try sourceFiles(in: repoRoot.appendingPathComponent("GradeDraft/UI"))
            .map { try String(contentsOf: repoRoot.appendingPathComponent($0), encoding: .utf8) }
            .joined(separator: "\n")

        XCTAssertTrue(uiSource.contains("Student-facing exports omit private teacher notes"))
        XCTAssertTrue(uiSource.contains("MarkForMe drafts suggestions only"))
        XCTAssertTrue(uiSource.contains("No student work is uploaded"))
        XCTAssertTrue(uiSource.contains("Opening the share sheet sends the selected file to another app"))
        XCTAssertTrue(uiSource.contains(GradeDraftWorkflowLanguage.reviewScannedTextExplanation))
    }

    func testLegacyGradeResultViewIsNotRoutedFromActiveNativeScreens() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let screensURL = repoRoot.appendingPathComponent("GradeDraft/UI/Screens")
        let screenSource = try FileManager.default
            .contentsOfDirectory(at: screensURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            .filter { $0.pathExtension == "swift" }
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")
        XCTAssertFalse(screenSource.contains("GradeResultView("), "Active v6 screens should render native final-review rows instead of routing to legacy GradeResultView.")
    }

    func testSharedActionButtonsAllowDynamicTypeWrapping() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let buttonsSource = try String(
            contentsOf: repoRoot.appendingPathComponent("GradeDraft/UI/DesignSystem/Buttons.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(buttonsSource.contains("@Environment(\\.dynamicTypeSize)"))
        XCTAssertTrue(buttonsSource.contains("ActionButtonLabel("))
        XCTAssertTrue(buttonsSource.contains("isAccessibilitySize ? nil : 3"))
        XCTAssertTrue(buttonsSource.contains(".fixedSize(horizontal: false, vertical: true)"))
        XCTAssertFalse(buttonsSource.contains("Label(title, systemImage: systemImage ?? \"arrow.right\")\n                .lineLimit(2)"))
        XCTAssertFalse(buttonsSource.contains("Label(title, systemImage: systemImage ?? \"arrow.right.circle\")\n                .lineLimit(2)"))
    }

    func testExportAndOCRAccessibilityLabelsCarryAudienceAndReviewState() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let exportSource = try String(
            contentsOf: repoRoot.appendingPathComponent("GradeDraft/UI/Screens/ExportsRestoreScreen.swift"),
            encoding: .utf8
        )
        let ocrSource = try String(
            contentsOf: repoRoot.appendingPathComponent("GradeDraft/UI/DesignSystem/OCRComponents.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(exportSource.contains("LabeledContent(\"Audience\", value: artifact.audienceStatus.fullAccessibilityLabel)"))
        XCTAssertTrue(exportSource.contains(".accessibilityLabel(\"Export audience\")"))
        XCTAssertTrue(exportSource.contains(".accessibilityLabel(\"Review share warning for \\(artifact.displayName)\")"))
        XCTAssertTrue(exportSource.contains(".accessibilityLabel(\"Copy text from \\(artifact.displayName)\")"))
        XCTAssertTrue(exportSource.contains("Requires clipboard warning confirmation."))
        XCTAssertTrue(ocrSource.contains(".accessibilityLabel(\"Scanned text line review status\")"))
        XCTAssertTrue(ocrSource.contains("var accessibilityReviewValue: String"))
        XCTAssertTrue(ocrSource.contains("Confidence \\(confidence) percent"))
        XCTAssertTrue(ocrSource.contains("Text: \\(text)."))
    }

    func testVisibleTeacherFacingStringsDoNotUseImplementationLanguage() throws {
        let forbiddenTerms = [
            "stale draft",
            "stale drafts",
            "draft stale",
            "parse warning",
            "parse warnings",
            "parsed with warnings",
            "raw model output",
            "audit events",
            "internal source metadata",
            "local file paths",
            "source metadata",
            "source path",
            "source preview",
            "source status",
            "Teacher Audit PDF",
            "Student PDF",
            "Student-safe",
            "Restore as Copy",
            "Ready for grading",
            "OCR issues",
            "scanned text review needed"
        ]

        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let scannedFiles = [
            "GradeDraft/ContentView.swift",
            "GradeDraft/GradeDraftViewModel.swift",
            "GradeDraft/Models/GradeDraftModels.swift",
            "GradeDraft/Export/PDFExportService.swift",
            "GradeDraft/Export/BundleExportService.swift",
            "GradeDraft/Services/LocalJSONStore.swift",
            "GradeDraft/Views/GradeResultView.swift",
            "GradeDraft/Views/LocalCapabilityBanner.swift"
        ] + sourceFiles(in: repoRoot.appendingPathComponent("GradeDraft/UI"))

        var failures: [String] = []
        for relativePath in scannedFiles {
            let url = repoRoot.appendingPathComponent(relativePath)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let source = try String(contentsOf: url, encoding: .utf8)
            let visibleStrings = SwiftStringLiteralScanner.stringLiterals(in: source)
            for literal in visibleStrings {
                for term in forbiddenTerms where literal.range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
                    failures.append("\(relativePath): \(term) found in \"\(literal)\"")
                }
            }
        }

        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    private func sourceFiles(in directory: URL) -> [String] {
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else { return [] }
        let repoRoot = directory.deletingLastPathComponent().deletingLastPathComponent()
        return enumerator.compactMap { item in
            guard let url = item as? URL, url.pathExtension == "swift" else { return nil }
            return url.path.replacingOccurrences(of: repoRoot.path + "/", with: "")
        }
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

private enum SwiftStringLiteralScanner {
    static func stringLiterals(in source: String) -> [String] {
        let characters = Array(source)
        var index = 0
        var literals: [String] = []
        var isLineComment = false
        var isBlockComment = false

        while index < characters.count {
            let character = characters[index]
            let next = index + 1 < characters.count ? characters[index + 1] : "\0"

            if isLineComment {
                if character == "\n" { isLineComment = false }
                index += 1
                continue
            }
            if isBlockComment {
                if character == "*", next == "/" {
                    isBlockComment = false
                    index += 2
                } else {
                    index += 1
                }
                continue
            }
            if character == "/", next == "/" {
                isLineComment = true
                index += 2
                continue
            }
            if character == "/", next == "*" {
                isBlockComment = true
                index += 2
                continue
            }
            guard character == "\"" else {
                index += 1
                continue
            }

            let parsed = parseStringLiteral(characters, start: index)
            if let value = parsed.value {
                literals.append(value)
            }
            index = parsed.endIndex
        }

        return literals
    }

    private static func parseStringLiteral(_ characters: [Character], start: Int) -> (value: String?, endIndex: Int) {
        var index = start
        var hashCount = 0
        while index > 0, characters[index - 1] == "#" {
            hashCount += 1
            index -= 1
        }

        let isTripleQuoted = start + 2 < characters.count && characters[start + 1] == "\"" && characters[start + 2] == "\""
        var cursor = start + (isTripleQuoted ? 3 : 1)
        var value = ""
        while cursor < characters.count {
            if isTripleQuoted,
               cursor + 2 < characters.count,
               characters[cursor] == "\"",
               characters[cursor + 1] == "\"",
               characters[cursor + 2] == "\"" {
                return (value, cursor + 3 + hashCount)
            }
            if !isTripleQuoted, characters[cursor] == "\"" {
                return (value, cursor + 1 + hashCount)
            }
            if characters[cursor] == "\\" {
                value.append(characters[cursor])
                cursor += 1
                if cursor < characters.count {
                    value.append(characters[cursor])
                    cursor += 1
                }
                continue
            }
            value.append(characters[cursor])
            cursor += 1
        }
        return (nil, characters.count)
    }
}
