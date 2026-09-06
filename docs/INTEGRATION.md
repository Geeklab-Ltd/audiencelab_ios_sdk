# AudienceLab iOS SDK Integration

This guide is for iOS developers integrating the released AudienceLab iOS SDK.

## Requirements

- iOS `13.0` or newer
- Xcode project or workspace
- AudienceLab API key

No additional app permissions are required to initialize the SDK.

## Recommended Integration: Swift Package Manager

Add the package in Xcode:

1. Open your app project.
2. Go to `File` -> `Add Package Dependencies...`
3. Enter:

```text
https://github.com/Geeklab-Ltd/audiencelab_ios_sdk.git
```

4. Select the version rule that fits your project.
5. Add the `AudienceLabSDK` product to your app target.

## Alternative Integration: CocoaPods

If your project uses CocoaPods, reference the release repository directly:

```ruby
pod 'AudienceLabSDK', :git => 'https://github.com/Geeklab-Ltd/audiencelab_ios_sdk.git', :tag => 'v<version>'
```

## Fallback Integration: XCFramework

If you received a release XCFramework instead of using a package manager:

1. Download `AudienceLabSDK.xcframework.zip` from the release.
2. Unzip it.
3. Drag `AudienceLabSDK.xcframework` into your Xcode project.
4. In your app target, open **General** -> **Frameworks, Libraries, and Embedded Content**.
5. Verify `AudienceLabSDK.xcframework` is listed and set to **Embed & Sign**.

## Configuration

Initialize the SDK early in app startup.

```swift
import AudienceLabSDK

let options = AudienceLabOptions()
options.isDevelopmentMode = true
options.isDebugEnabled = true

AudienceLab.initialize(
    apiKey: "YOUR_AUDIENCELAB_API_KEY",
    options: options
)
```

Configuration notes:

- `isDevelopmentMode` controls whether traffic is sent as development or release traffic.
- `isDebugEnabled` enables local SDK debug logging and diagnostics.
- `app_version` is derived automatically from the host app bundle version.

## RevenueCat Attributes

After `Purchases.configure` and before the first paywall, copy AudienceLab's device id onto the RevenueCat subscriber (safe every cold start):

```swift
Purchases.shared.attribution.setAttributes(AudienceLab.getRevenueCatAttributes())
```

## Sending Events

Initialize the SDK before sending events.

### Ad Event

```swift
AudienceLab.sendAdEvent(
    adId: "rewarded_video_1",
    name: "rewarded_video",
    source: "admob",
    watchTime: 30.0,
    reward: true,
    mediaSource: "campaign_a",
    channel: "rewarded",
    value: 0.75,
    currency: "USD"
)
```

### Purchase Event

```swift
AudienceLab.sendPurchaseEvent(
    itemId: "starter_pack",
    itemName: "Starter Pack",
    value: 4.99,
    currency: "USD",
    status: "success",
    transactionId: "order-123"
)
```

### Custom Event

```swift
AudienceLab.sendCustomEvent(
    name: "level_start",
    params: [
        "level": 1,
        "mode": "normal"
    ]
)
```

Retention metrics are sent automatically by the SDK once initialization and token flow complete successfully. There is no separate manual retention call required during normal integration.

## User Properties

The iOS SDK supports two property sets:

- **whitelisted** properties
- **blacklisted** properties

Set a whitelisted property:

```swift
AudienceLab.setUserProperty(
    key: "favorite_character",
    value: "mage",
    set: .whitelisted
)
```

Set a blacklisted property:

```swift
AudienceLab.setUserProperty(
    key: "external_id",
    value: "user-123",
    set: .blacklisted
)
```

Special handling for blacklisted properties:

- `email`
- `phone`

When either key is set as a blacklisted property, the iOS SDK automatically normalizes and SHA-256 hashes the value before persisting or sending it.

```swift
AudienceLab.setUserProperty(
    key: "email",
    value: "player@example.com",
    set: .blacklisted
)

AudienceLab.setUserProperty(
    key: "phone",
    value: "+358 40 123 4567",
    set: .blacklisted
)
```

Reserved whitelisted keys beginning with `_` are backend-managed and should not be set manually by the integrating app.

## Minimal Verification

After integration, verify:

1. the app builds successfully
2. `AudienceLab.initialize(...)` succeeds
3. a creative token is obtained successfully with your API key
4. ad, purchase, and custom events can be sent without runtime errors
5. queued events flush after token availability

For agent-driven certification without hidden steps, use the published contract and harness:

- [`AGENT_VERIFIABLE_INTEGRATION.md`](AGENT_VERIFIABLE_INTEGRATION.md)
- [`contracts/ios-sdk.integration.v1.json`](../contracts/ios-sdk.integration.v1.json)
- `python3 scripts/verify_ios_integration_contract.py` → `verification/evidence/latest.json`

## Privacy manifest

The SDK ships `Sources/AudienceLabSDK/Resources/PrivacyInfo.xcprivacy` (UserDefaults reason `CA92.1`, `NSPrivacyTracking = false`). Host apps remain responsible for ATT when using IDFA via `setAdvertisingId`, App Store nutrition labels, and legal declarations.

## Credentials and rollback

Inject the AudienceLab API key at runtime from a secret store. Prefer one-time handoff; never commit raw keys or write them into transcripts/logs. To roll back: disable metrics / call `AudienceLab.reset()`, remove the package dependency, and revoke or rotate the environment credential.
