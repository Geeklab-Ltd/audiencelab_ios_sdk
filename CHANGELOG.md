# Changelog

All notable changes to this package are documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

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
