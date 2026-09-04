# Changelog

All notable changes to this package are documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [1.1.14] - 2026-09-04

### Added

- Added `getRevenueCatAttributes()` to return an `audienceLabId` map for RevenueCat subscriber attributes, so purchases and renewals can be attributed to the AudienceLab install.

## [1.1.13] - 2026-04-29

### Changed

- Lowered the SDK minimum supported iOS version from `14.0` to `13.0` for Swift Package Manager and CocoaPods distribution metadata.

## [1.1.12] - 2026-03-24

### Fixed

- `initialize` now always applies `AudienceLabOptions` values for `isSDKEnabled`, `isMetricsEnabled`, and `isDebugEnabled` instead of preserving previously persisted state. Calling `initialize` with `isSDKEnabled = true` after a prior `setSDKEnabled(false)` now correctly re-enables the SDK.
- Calling `initialize` when the SDK is already initialized now re-applies the provided (or default) configuration instead of silently returning.
- `SDKConfig.setInitialConfig` now defaults to `AudienceLabOptions()` when `options` is `nil`, ensuring the SDK defaults to enabled on every `initialize` call.

### Added

- Advertising ID (IDFA) set via `setAdvertisingId` is now included as `ga` in creative token request when value is set.
- Doc comment on `setAdvertisingId` clarifying it can be called before or after `initialize`; calling before ensures inclusion in the first creative token request.

## [1.1.11] - 2026-03-19

### Added

- Runtime-only SDK initialization (`initialize(apiKey:options:)`) with delayed API key injection.
- SDK master toggle (`setSDKEnabled`/`isSDKEnabled`), metrics toggle (`setMetricsCollectionEnabled`/`isMetricsCollectionEnabled`), debug toggle (`setDebugEnabled`/`isDebugEnabled`), and runtime version getters.
- Host-app-controlled development mode through `AudienceLabOptions.isDevelopmentMode`.
- Session management with 30-minute timeout rollover and automatic session events.
- Creative token fetching, validation, and retry/backoff.
- Ad event, purchase event, and custom event tracking with optional `dedupe_key`.
- Offline queue with max 200 events, max age 24 hours, and reconnect flush.
- Retention tracking with first/last login, retention day, and daily-send guard.
- Whitelisted/blacklisted user properties with size/key/value/count limits.
- Diagnostics APIs (identity, token, device, queue, and request debugging) available in DEBUG builds.
- Public getters for whitelisted and blacklisted user properties.
- User property API using `AudienceLabUserPropertySet` (`whitelisted` / `blacklisted`).
- Distribution via Swift Package Manager, CocoaPods, and manual XCFramework.

### Changed

- Webhook delivery is gated on a valid creative token instead of sending with an organic fallback.
- Retention state is prepared at launch before the first session event, and automatic daily retention sending follows token availability.
- Whitelisted user properties preserve backend-managed underscore-prefixed keys and reject manual attempts to set them.
- Blacklisted `email` and `phone` values are normalized and SHA-256 hashed before they are persisted or sent.
