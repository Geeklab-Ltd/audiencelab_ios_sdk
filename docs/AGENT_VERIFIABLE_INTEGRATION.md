# Agent-verifiable iOS integration contract

This document is the human companion to the machine-readable contract at [`contracts/ios-sdk.integration.v1.json`](../contracts/ios-sdk.integration.v1.json). It is written so an agent can integrate and certify a supported iOS build **without hidden steps**.

Related: [GEE-510](https://linear.app/geeklabltd/issue/GEE-510/ios-sdk-publish-an-agent-verifiable-native-integration-contract), [GEE-481](https://linear.app/geeklabltd/issue/GEE-481/approval-approve-app-integration-credential-and-readiness-contract).

## Contract identity

| Field | Value |
| --- | --- |
| Contract ID | `audiencelab.ios_sdk.integration` |
| Contract version | `1.0.0` |
| Platform | `native_ios` |
| SDK product | `AudienceLabSDK` |
| SDK version | `1.1.14` (`v1.1.14`) |
| Minimum iOS | `13.0` |
| Repository authority | `Geeklab-Ltd/audiencelab_ios_sdk` |

Deterministic version sources that must stay aligned:

1. `AudienceLabSDK.podspec` → `s.version`
2. `Sources/AudienceLabSDK/Configuration/SDKConfig.swift` → `sdkVersionValue`
3. `contracts/ios-sdk.integration.v1.json` → `sdk.version`

## Credentials (GEE-481)

- Credential kind: environment-scoped **application API key**.
- Runtime header: `geeklab-api-key`.
- Handoff is **one-time / direct** into the integration secret store for the entitled workspace+app.
- Agents may retrieve the key when authorized for that tenant+app, but must **never** write the raw key into git, MCP transcripts, ordinary logs, analytics events, or shared audit payloads.
- Audit may record issuance/use/rotation/presence metadata only.
- Sandbox and production keys are distinct. **Sandbox never implies analysis-ready.**

Inject at runtime only:

```swift
AudienceLab.initialize(
    apiKey: /* from secret store — never commit */,
    options: options
)
```

Use placeholder `YOUR_AUDIENCELAB_API_KEY` in docs and samples only.

## Install steps

### Preferred: Swift Package Manager

1. Obtain the environment API key via one-time handoff; store outside git.
2. Xcode → `File` → `Add Package Dependencies...`
3. URL: `https://github.com/Geeklab-Ltd/audiencelab_ios_sdk.git`
4. Pin to `v1.1.14` (or an approved compatible range).
5. Add product `AudienceLabSDK` to the app target.

### CocoaPods

```ruby
pod 'AudienceLabSDK', :git => 'https://github.com/Geeklab-Ltd/audiencelab_ios_sdk.git', :tag => 'v1.1.14'
```

### XCFramework fallback

Download `AudienceLabSDK.xcframework.zip` for `v1.1.14`, embed with **Embed & Sign**.

## Initialize

```swift
import AudienceLabSDK

let options = AudienceLabOptions()
options.isDevelopmentMode = true   // sandbox / local certification traffic
options.isDebugEnabled = true      // local diagnostics only

AudienceLab.initialize(
    apiKey: "YOUR_AUDIENCELAB_API_KEY",
    options: options
)
```

Production certification builds must use production (or approved prod-like) credentials and `isDevelopmentMode = false`.

No additional Info.plist permission keys are required to initialize.

## Required signals

### Automatic (SDK-emitted)

| Signal | Wire / check | Notes |
| --- | --- | --- |
| Creative token | `AudienceLab.getCreativeToken()` | Required before webhook flush |
| Session lifecycle | `session_start` / `session_end` | 30-minute timeout |
| Retention | `retention` | After token availability |

### Integrator-emitted (minimum one for certification)

Call at least one of:

- `AudienceLab.sendCustomEvent(...)` → `custom`
- `AudienceLab.sendAdEvent(...)` → `custom.ad`
- `AudienceLab.sendPurchaseEvent(...)` → `custom.purchase`

### Analysis-ready (backend consumes; do not invent readiness locally)

Per GEE-481, analysis-ready is **not** “app created”. It requires:

1. Production / approved prod-like credentials bound
2. Supported SDK attested
3. Accepted production signals observed
4. Freshness within policy window
5. No blocking validation failures

Fail closed when any gate is unmet.

### First-signal checklist

1. `AudienceLab.isInitialized == true`
2. Creative token is present and not an organic fallback
3. At least one integrator event is accepted
4. Optional: `checkDataCollectionStatus` reports collection allowed when policy requires it

## Privacy and consent

- SDK does **not** present an ATT prompt.
- IDFA is host-controlled via `setAdvertisingId` / `clearAdvertisingId`. Set IDFA only after ATT authorization when advertising identifier use is intended.
- Metrics can be disabled with `setSDKEnabled(false)` and/or `setMetricsCollectionEnabled(false)`.
- Blacklisted `email` / `phone` user properties are normalized and SHA-256 hashed before persist/send.
- Privacy manifest ships with the SDK at `Sources/AudienceLabSDK/Resources/PrivacyInfo.xcprivacy`:
  - `NSPrivacyTracking = false`
  - UserDefaults accessed API reason `CA92.1`
  - Declared analytics data types for device ID, product interaction, purchase history, and device/other IDs
- Host remains owner of App Store nutrition labels and legal/privacy/export/age declarations.

## Diagnostics

Always available:

- `isInitialized`, `getCreativeToken()`, `getQueueSize()`, `getSDKVersion()`, `getAppVersion()`
- `getSessionId()`, `getSessionIndex()`
- `checkDataCollectionStatus`, `verifyCreativeToken`
- `setRequestResultCallback`

DEBUG-only snapshots (masked identity / key previews): identity, token, device, queue, request debug listener.

Verification evidence must never contain raw API keys.

## Rollback (explicit)

1. `AudienceLab.setSDKEnabled(false)` and/or `setMetricsCollectionEnabled(false)`
2. `AudienceLab.reset()` to clear runtime state and `AudienceLabSDK_` persistence keys
3. Remove SPM / CocoaPods / XCFramework dependency and rebuild
4. Revoke or rotate the environment API key through the Audiencelab credential lifecycle
5. If rolling back a bad upgrade, re-pin the last known-good tag (for example previous `vX.Y.Z`) and rebuild

Do not leave revoked secrets in CI logs or transcripts.

## Machine-checkable verification

From the repository root (no Xcode or network required):

```bash
python3 scripts/verify_ios_integration_contract.py
```

On success, exit code `0` and evidence at:

```text
verification/evidence/latest.json
```

The harness checks contract shape, version consistency, public API anchors, privacy manifest presence, docs presence, credential/rollback/out-of-scope declarations, and secret hygiene.

## Out of scope (Phase 3)

- App Store Connect submission automation (GEE-526)
- Signed build artifact attestations (GEE-528)

This contract certifies **native integration evidence**, not store submission.

## Developer companion

Day-to-day API examples remain in [INTEGRATION.md](INTEGRATION.md) and the root [README.md](../README.md).
