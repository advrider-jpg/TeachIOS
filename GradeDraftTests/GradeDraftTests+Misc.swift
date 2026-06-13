import XCTest
import ZIPFoundation
@testable import GradeDraft

extension GradeDraftTests {
    func testJSONExtractorFindsFirstObjectAndIgnoresBracesInStrings() {
        let raw = "Here is the draft:\n```json\n{\"studentResponseSummary\":\"uses { braces } in text\",\"criteria\":[]}\n``` trailing"
        XCTAssertEqual(
            JSONExtractor.extractFirstJSONObject(from: raw),
            "{\"studentResponseSummary\":\"uses { braces } in text\",\"criteria\":[]}"
        )
    }

    func testOldRecordWithoutPromptDecodesSuccessfully() throws {
        // Encode a record, strip the prompt key, then decode — simulating data
        // saved before the prompt field was added.
        let original = AssignmentRecord(title: "Legacy Assignment")
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(original)
        var jsonObject = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        )
        jsonObject.removeValue(forKey: "prompt")
        let legacyData = try JSONSerialization.data(withJSONObject: jsonObject)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AssignmentRecord.self, from: legacyData)
        XCTAssertNil(decoded.prompt, "prompt should be nil when absent in stored JSON")
        XCTAssertEqual(decoded.title, "Legacy Assignment")
    }
}
