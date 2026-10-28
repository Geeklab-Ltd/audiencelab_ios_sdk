import Foundation
import XCTest
@testable import AudienceLabSDK

#if DEBUG
final class DebugSanitizationTests: XCTestCase {
    func testSensitiveLifecycleAndTokenValuesAreRedactedRecursively() throws {
        let sanitized = DebugUtilities.sanitizedJSONString([
            "creativeToken": "creative-secret",
            "x1": "local-install-secret",
            "safe": "visible",
            "nested": [
                "token": "response-token-secret",
                "x7": "canonical-install-secret"
            ]
        ])

        XCTAssertFalse(sanitized.contains("creative-secret"))
        XCTAssertFalse(sanitized.contains("local-install-secret"))
        XCTAssertFalse(sanitized.contains("response-token-secret"))
        XCTAssertFalse(sanitized.contains("canonical-install-secret"))

        let data = try XCTUnwrap(sanitized.data(using: .utf8))
        let dictionary = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let nested = try XCTUnwrap(dictionary["nested"] as? [String: Any])

        XCTAssertEqual(dictionary["creativeToken"] as? String, "<redacted>")
        XCTAssertEqual(dictionary["x1"] as? String, "<redacted>")
        XCTAssertEqual(dictionary["safe"] as? String, "visible")
        XCTAssertEqual(nested["token"] as? String, "<redacted>")
        XCTAssertEqual(nested["x7"] as? String, "<redacted>")
    }

    func testUnstructuredResponseBodyIsOmitted() {
        XCTAssertEqual(
            DebugUtilities.sanitizedJSONString("token=response-token-secret"),
            "<non-JSON response omitted>"
        )
    }
}
#endif
