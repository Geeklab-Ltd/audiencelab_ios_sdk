# Fetch-token response compatibility

The Audiencelab iOS SDK accepts the existing fetch-token response and three optional lifecycle fields. This is an additive contract: responses without lifecycle fields continue to work unchanged.

## Existing response fields

| Field | Type | Handling |
| --- | --- | --- |
| `token` | string | Required for a successful token fetch and persisted by the existing token flow. |
| `message` | string | Optional response message. |
| `wp` | object | Optional backend-managed whitelisted properties, merged using the existing rules. |

## Optional lifecycle fields

| Wire key | Meaning | Type | SDK handling |
| --- | --- | --- | --- |
| `x7` | Canonical install ID | string | Persisted for later event-contract work. |
| `x9` | Lifecycle decision code | string | Retained for the current runtime only. Values are open-ended so newer backend decisions do not break older SDKs. |
| `xm` | Refresh-after time | ISO-8601 string | Parsed as a date and persisted for later refresh-gating work. Fractional seconds are optional. |

Lifecycle fields are applied only when the response also contains a valid token. Missing or malformed optional fields do not invalidate an otherwise valid legacy response. An omitted lifecycle field leaves any previously persisted value unchanged.

This contract does not collect installation evidence, detect reinstalls, schedule refresh requests, perform click matching, or decide re-attribution eligibility. Those behaviors belong to separate lifecycle and backend work.
