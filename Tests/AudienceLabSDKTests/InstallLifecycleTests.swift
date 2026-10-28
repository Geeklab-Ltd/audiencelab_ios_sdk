import Foundation
import XCTest
@testable import AudienceLabSDK

final class InstallLifecycleTests: XCTestCase {
    func testInstallInstanceIdIsStableAndExcludedFromBackup() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("InstallInstanceStoreTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let firstStore = InstallInstanceStore(directoryURL: directoryURL)
        let first = try firstStore.loadOrCreate()
        let repeated = try firstStore.loadOrCreate()
        let relaunched = try InstallInstanceStore(directoryURL: directoryURL).loadOrCreate()

        XCTAssertNotNil(UUID(uuidString: first))
        XCTAssertEqual(repeated, first)
        XCTAssertEqual(relaunched, first)
        XCTAssertEqual(
            try directoryURL.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup,
            true
        )
        XCTAssertEqual(
            try directoryURL
                .appendingPathComponent("install-instance-id")
                .resourceValues(forKeys: [.isExcludedFromBackupKey])
                .isExcludedFromBackup,
            true
        )
    }

    func testFetchTokenPayloadIncludesOnlyLifecycleSchemaAndInstallInstanceId() {
        let context = TestContext()
        let manager = context.makeTokenManager(installInstanceId: "local-install-123")

        let payload = manager.fetchTokenPayload(device: Self.device)

        XCTAssertEqual(payload["x0"] as? Int, 2)
        XCTAssertEqual(payload["x1"] as? String, "local-install-123")
        XCTAssertNil(payload["x2"])
        XCTAssertNil(payload["x3"])
    }

    func testCachedTokenPerformsOneNonBlockingUpgradeRegistration() {
        let context = TestContext()
        context.persistence.set("cached-token", for: "AudienceLabSDK_CreativeToken")
        let apiClient = MockTokenAPIClient(result: .success([
            "token": "cached-token",
            "message": "legacy-compatible"
        ]))
        let manager = context.makeTokenManager(apiClient: apiClient, installInstanceId: "local-install-123")
        var tokenCompletionDelivered = false
        apiClient.onPost = {
            XCTAssertTrue(tokenCompletionDelivered)
        }

        manager.fetchCreativeToken { result in
            XCTAssertEqual(try? result.get(), "cached-token")
            tokenCompletionDelivered = true
        }

        XCTAssertEqual(apiClient.postBodies.count, 1)
        XCTAssertEqual(apiClient.postBodies.first?["x0"] as? Int, 2)
        XCTAssertEqual(apiClient.postBodies.first?["x1"] as? String, "local-install-123")

        manager.fetchCreativeToken { _ in }
        XCTAssertEqual(apiClient.postBodies.count, 1)

        let nextLaunchClient = MockTokenAPIClient(result: .success(["token": "cached-token"]))
        let nextLaunchManager = context.makeTokenManager(
            apiClient: nextLaunchClient,
            installInstanceId: "local-install-123"
        )
        nextLaunchManager.fetchCreativeToken { _ in }
        XCTAssertTrue(nextLaunchClient.postBodies.isEmpty)
    }

    func testRestoredStateRegistersAgainWhenLocalInstallInstanceChanges() {
        let context = TestContext()
        context.persistence.set("cached-token", for: "AudienceLabSDK_CreativeToken")
        context.persistence.set("install-from-backup", for: "AudienceLabSDK_InstallId")
        context.persistence.set(2, for: "AudienceLabSDK_LifecycleRegistrationVersion")
        context.persistence.set("previous-local-install", for: "AudienceLabSDK_RegisteredInstallInstanceId")
        let apiClient = MockTokenAPIClient(result: .failure(.noData))
        let manager = context.makeTokenManager(apiClient: apiClient, installInstanceId: "new-local-install")

        XCTAssertNil(manager.installId)
        manager.fetchCreativeToken { _ in }

        XCTAssertEqual(apiClient.postBodies.count, 1)
        XCTAssertEqual(apiClient.postBodies.first?["x1"] as? String, "new-local-install")
        XCTAssertNil(manager.installId)
    }

    func testEventEnvelopeIncludesCanonicalInstallIdWhenCached() {
        let envelope = EventEnvelope(
            type: "custom",
            eventId: "event-123",
            createdAt: "2026-12-01 10:15:30",
            creativeToken: "creative-token",
            installId: "install-123",
            deviceName: "iPhone",
            deviceModel: "iPhone17,1",
            osSystem: "iOS 26.0",
            utcOffset: 0,
            retentionDay: nil,
            sdkVersion: "2.0.0",
            appVersion: "1.0.0",
            sdkType: "ios",
            developmentMode: false,
            ifv: nil,
            ga: nil,
            lat: nil,
            wp: [:],
            bp: [:],
            dedupeKey: nil,
            payload: [:]
        )

        XCTAssertEqual(envelope.toDictionary()["x7"] as? String, "install-123")
    }

    private static let device = DeviceInfo(
        deviceName: "Test iPhone",
        deviceModel: "iPhone17,1",
        osVersion: "iOS 26.0",
        screenWidth: 1179,
        screenHeight: 2556,
        dpi: 460,
        gpuVersion: "Metal",
        gpuVendor: "Apple",
        gpuRenderer: "Apple GPU",
        gpuContent: nil,
        batteryLevel: 1,
        lowBattery: false,
        installedFonts: []
    )
}

private final class TestContext {
    let suiteName: String
    let defaults: UserDefaults
    let persistence: PersistenceManager

    init() {
        suiteName = "InstallLifecycleTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        persistence = PersistenceManager(defaults: defaults)
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func makeTokenManager(
        apiClient: TokenAPIClient = MockTokenAPIClient(result: .success(["token": "token"])),
        installInstanceId: String
    ) -> TokenManager {
        TokenManager(
            apiClient: apiClient,
            userPropertiesManager: UserPropertiesManager(),
            persistence: persistence,
            installInstanceStore: FixedInstallInstanceStore(identifier: installInstanceId)
        )
    }
}

private final class MockTokenAPIClient: TokenAPIClient {
    let result: Result<[String: Any], APIClientError>
    var postBodies: [[String: Any]] = []
    var onPost: (() -> Void)?

    init(result: Result<[String: Any], APIClientError>) {
        self.result = result
    }

    func post(
        path: String,
        body: [String: Any],
        completion: @escaping (Result<[String: Any], APIClientError>) -> Void
    ) {
        postBodies.append(body)
        onPost?()
        completion(result)
    }
}
