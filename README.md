# AudienceLab iOS SDK

## Introduction

AudienceLab provides privacy-centric measurement for iOS apps and games by connecting campaign performance to creative-level analytics.

## Objectives

- Enable iOS developers to integrate AudienceLab into their apps with a lightweight native SDK.
- Capture session, retention, ad, purchase, and custom events for AudienceLab reporting.

## Prerequisites

Developers will need:

- an iOS app or game project
- minimum iOS version `14.0`
- Xcode with Swift Package Manager or CocoaPods support
- an AudienceLab API key

No additional app permissions are required to initialize the SDK.

## Integrating AudienceLab SDK into iOS

This section provides the recommended ways to integrate the AudienceLab iOS SDK into your project.

### Option 1: Swift Package Manager (Recommended)

In Xcode:

1. Open your app project.
2. Go to `File` -> `Add Package Dependencies...`
3. Enter the AudienceLab iOS SDK repository URL:

```text
https://github.com/Geeklab-Ltd/audiencelab_ios_sdk.git
```

4. Choose the version rule that matches your release policy.
5. Add the `AudienceLabSDK` product to your app target.

### Option 2: CocoaPods

If your project uses CocoaPods, add the SDK directly from the release repository:

```ruby
pod 'AudienceLabSDK', :git => 'https://github.com/Geeklab-Ltd/audiencelab_ios_sdk.git', :tag => 'v<version>'
```

### Option 3: XCFramework

If you are not using a package manager:

1. Download the latest `AudienceLabSDK.xcframework.zip` asset from the release.
2. Unzip it.
3. Drag `AudienceLabSDK.xcframework` into your Xcode project.
4. Link it to your app target.

## Configure the SDK

Initialize the SDK early in app startup:

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

The SDK automatically uses your app bundle version for `app_version`; you do not need to supply it manually.

For more detailed setup instructions, see the [Integration Guide](docs/INTEGRATION.md).

## Finalizing SDK Integration

After configuration:

1. Build your iOS app
2. Launch the app and verify SDK initialization succeeds
3. Confirm the SDK receives a creative token successfully
4. Verify events are sent without runtime errors

## Event Tracking

### Purchase Events

Use purchase events to track completed purchases:

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

### Ad Events

Use ad events to track ad impressions and rewarded ads:

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

### Custom Events

Use custom events for app-specific actions:

```swift
AudienceLab.sendCustomEvent(
    name: "level_start",
    params: [
        "level": 1,
        "mode": "normal"
    ]
)
```

## User Properties

The SDK supports both whitelisted (`wp`) and blacklisted (`bp`) user properties.

For blacklisted `email` and `phone` values, the iOS SDK automatically normalizes and SHA-256 hashes the value before it is stored or sent.

## Version Information

Current SDK line:

- minimum iOS version: `14.0`
- Swift Package Manager product: `AudienceLabSDK`
- CocoaPods spec: `AudienceLabSDK`

# Additional References

- [Integration Guide](docs/INTEGRATION.md)
- [Changelog](CHANGELOG.md)
- [License](LICENSE.md)
