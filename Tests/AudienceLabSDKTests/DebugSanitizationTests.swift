import Foundation
import XCTest
@testable import AudienceLabSDK

#if DEBUG
final class DebugSanitizationTests: XCTestCase {
    func testSensitiveLifecycleTokenAndDeviceIdentityValuesAreRedactedRecursively() throws {
        let sanitized = DebugUtilities.sanitizedJSONString([
            "aid": "advertising-id-secret",
            "creativeToken": "creative-secret",
            "ifv": "vendor-id-secret",
            "x1": "local-install-secret",
            "safe": "visible",
            "nested": [
                "asid": "app-set-id-secret",
                "ga": "google-advertising-id-secret",
                "token": "response-token-secret",
                "x7": "canonical-install-secret"
            ]
        ])

        XCTAssertFalse(sanitized.contains("advertising-id-secret"))
        XCTAssertFalse(sanitized.contains("app-set-id-secret"))
        XCTAssertFalse(sanitized.contains("creative-secret"))
        XCTAssertFalse(sanitized.contains("google-advertising-id-secret"))
        XCTAssertFalse(sanitized.contains("local-install-secret"))
        XCTAssertFalse(sanitized.contains("response-token-secret"))
        XCTAssertFalse(sanitized.contains("canonical-install-secret"))
        XCTAssertFalse(sanitized.contains("vendor-id-secret"))

        let data = try XCTUnwrap(sanitized.data(using: .utf8))
        let dictionary = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let nested = try XCTUnwrap(dictionary["nested"] as? [String: Any])

        XCTAssertEqual(dictionary["aid"] as? String, "<redacted>")
        XCTAssertEqual(dictionary["creativeToken"] as? String, "<redacted>")
        XCTAssertEqual(dictionary["ifv"] as? String, "<redacted>")
        XCTAssertEqual(dictionary["x1"] as? String, "<redacted>")
        XCTAssertEqual(dictionary["safe"] as? String, "visible")
        XCTAssertEqual(nested["asid"] as? String, "<redacted>")
        XCTAssertEqual(nested["ga"] as? String, "<redacted>")
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
