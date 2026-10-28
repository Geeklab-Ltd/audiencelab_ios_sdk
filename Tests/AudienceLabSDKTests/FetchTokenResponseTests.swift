import Foundation
import XCTest
@testable import AudienceLabSDK

final class FetchTokenResponseTests: XCTestCase {
    override func setUp() {
        super.setUp()
        clearPersistedSDKState()
    }

    override func tearDown() {
        clearPersistedSDKState()
        super.tearDown()
    }

    func testLegacyResponsePreservesTokenMessageAndWhitelistedProperties() {
        let response = FetchTokenResponse(payload: [
            "token": "creative-token",
            "message": "ok",
            "wp": [
                "_network": "admob",
                "country": "fi"
            ]
        ])

        XCTAssertEqual(response.token, "creative-token")
        XCTAssertEqual(response.message, "ok")
        XCTAssertEqual(response.whitelistedProperties?["_network"] as? String, "admob")
        XCTAssertEqual(response.whitelistedProperties?["country"] as? String, "fi")
        XCTAssertNil(response.lifecycle)
    }

    func testOptionalLifecycleFieldsParseAndRequiredStatePersists() {
        let apiClient = APIClient(session: .shared)
        let userProperties = UserPropertiesManager()
        let tokenManager = TokenManager(apiClient: apiClient, userPropertiesManager: userProperties)
        let refreshAfter = "2026-12-01T10:15:30.123Z"

        let token = tokenManager.processFetchTokenResponse([
            "token": "creative-token-v2",
            "message": "ok",
            "wp": ["_network": "organic"],
            "x7": "install-123",
            "x9": "same_install.instance_match",
            "xm": refreshAfter
        ])

        XCTAssertEqual(token, "creative-token-v2")
        XCTAssertEqual(tokenManager.installId, "install-123")
        XCTAssertEqual(tokenManager.lifecycleDecisionCode, "same_install.instance_match")
        XCTAssertEqual(tokenManager.lifecycleRefreshAfter, parseFractionalISO8601(refreshAfter))
        XCTAssertEqual(userProperties.whitelisted["_network"], "organic")

        let restored = TokenManager(apiClient: apiClient, userPropertiesManager: UserPropertiesManager())
        XCTAssertEqual(restored.installId, "install-123")
        XCTAssertEqual(restored.lifecycleRefreshAfter, tokenManager.lifecycleRefreshAfter)
        XCTAssertNil(restored.lifecycleDecisionCode)
    }

    func testUnknownDecisionCodeRemainsAvailableForForwardCompatibility() {
        let response = FetchTokenResponse(payload: [
            "token": "creative-token",
            "x9": "future_state.new_evidence"
        ])

        XCTAssertEqual(response.lifecycle?.decisionCode, "future_state.new_evidence")
    }

    func testRefreshAfterAcceptsISO8601WithoutFractionalSeconds() {
        let response = FetchTokenResponse(payload: [
            "token": "creative-token",
            "xm": "2026-12-01T10:15:30Z"
        ])

        XCTAssertNotNil(response.lifecycle?.refreshAfter)
    }

    func testMalformedOptionalFieldsDoNotInvalidateToken() {
        let tokenManager = TokenManager(
            apiClient: APIClient(session: .shared),
            userPropertiesManager: UserPropertiesManager()
        )

        let token = tokenManager.processFetchTokenResponse([
            "token": "legacy-token",
            "x7": 123,
            "x9": true,
            "xm": "not-a-date"
        ])

        XCTAssertEqual(token, "legacy-token")
        XCTAssertNil(tokenManager.installId)
        XCTAssertNil(tokenManager.lifecycleDecisionCode)
        XCTAssertNil(tokenManager.lifecycleRefreshAfter)
    }

    private func clearPersistedSDKState() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("AudienceLabSDK_") {
            defaults.removeObject(forKey: key)
        }
    }

    private func parseFractionalISO8601(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }
}
