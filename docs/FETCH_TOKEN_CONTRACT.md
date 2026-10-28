# Fetch-token response compatibility

The Audiencelab iOS SDK registers a local installation with the existing fetch-token endpoint and accepts three optional lifecycle response fields. This is an additive contract: responses without lifecycle fields continue to work unchanged.

## Registration request fields

| Wire key | Meaning | Type | SDK handling |
| --- | --- | --- | --- |
| `x0` | Lifecycle schema version | integer | Sent as `2`. |
| `x1` | Local install-instance ID | string | Random UUID created once per installation. |

The install-instance ID is stored in the app's Application Support directory and excluded from device backups. It survives app and SDK updates, is deleted with the app sandbox on uninstall, and is not restored from backup. The SDK does not send platform installation timestamps in this contract.

## Existing response fields

| Field | Type | Handling |
| --- | --- | --- |
| `token` | string | Required for a successful token fetch and persisted by the existing token flow. |
| `message` | string | Optional response message. |
| `wp` | object | Optional backend-managed whitelisted properties, merged using the existing rules. |

## Optional lifecycle fields

| Wire key | Meaning | Type | SDK handling |
| --- | --- | --- | --- |
| `x7` | Canonical install ID | string | Persisted and added to ordinary events. |
| `x9` | Lifecycle decision code | string | Persisted as an open-ended string so newer backend decisions do not break older SDKs. |
| `xm` | Refresh-after time | ISO-8601 string | Parsed as a date and persisted for later refresh-gating work. Fractional seconds are optional. |

Lifecycle fields are applied only when the response also contains a valid token. Missing or malformed optional fields do not invalidate an otherwise valid legacy response. An omitted lifecycle field leaves any previously persisted value unchanged.

When an upgraded SDK already has a creative token but has not registered lifecycle schema `2`, token access succeeds immediately and one fetch-token registration starts without blocking event delivery. The registration marker is tied to the local install-instance ID, so state restored from backup cannot suppress registration after a reinstall. Cached lifecycle context from a different local instance is discarded before events are created. A successful response marks the current instance registration complete even when the backend returns only legacy fields, preventing another registration on every app open. A failed request may be retried on a later launch.

Ordinary events include `x7` whenever a canonical install ID has been cached. Queued events created before registration are enriched with the cached `x7` when they are later flushed.

This contract does not collect installation evidence, detect reinstalls, schedule refresh requests, perform click matching, or decide re-attribution eligibility. Those behaviors belong to separate lifecycle and backend work.
