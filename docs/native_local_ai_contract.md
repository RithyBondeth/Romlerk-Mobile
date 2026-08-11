# Native `LocalAi` bridge contract

Channel: `dev.romlerk/local_ai` (`MethodChannel`, standard codec).

Both native adapters implement the same three methods. The Dart side treats
everything returned here as **untrusted**: `LocalAiCapabilities.fromMap` and
`DraftCodec` validate it, and any structural problem discards the whole result
and falls back to the deterministic parser. A native adapter can therefore
never corrupt stored data — the worst it can do is be ignored.

If the channel has no receiver at all, `MissingPluginException` is caught and
reported as `NO_NATIVE_ADAPTER`, which is a normal tier-C state, not an error.

---

## `capabilities() -> Map`

```jsonc
{
  "provider":     "appleFoundationModels" | "mlKitGenAI",
  "availability": "available" | "notEligible" | "disabled"
                | "modelNotReady" | "busy" | "unknown",
  "features":     ["structuredText"],          // subset; see AiFeature
  "baseModel":    "apple-on-device-2026.1",    // optional, diagnostics only
  "languages":    ["en", "da"],                // BCP-47; empty = unrestricted
  "constraints": {
    "foregroundOnly":     true,
    "quotaPossible":      true,
    "maxInputCharacters": 1000
  },
  "reason": "DEVICE_NOT_ELIGIBLE"              // optional, when unavailable
}
```

`baseModel` is for regression analysis only. It must never be anything that
could identify a user or a device.

## `parseTasks(Map) -> Map`

Arguments in:

| Key | Type | Notes |
|---|---|---|
| `requestId` | String | Correlation and cancellation only |
| `text` | String | The user's raw input |
| `referenceNow` | String | ISO-8601; **the** anchor for relative dates |
| `timezone` | String | IANA name |
| `locale` | String | BCP-47 |
| `knownTags` | List\<String\> | Prefer these over inventing near-duplicates |
| `allowMultipleTasks` | bool | |
| `schemaVersion` | int | The version Dart expects back |

Result out:

```jsonc
{
  "schemaVersion": 1,
  "provider": "appleFoundationModels",
  "tasks": [
    {
      "title": "Call David",                    // required, non-empty, <= 200
      "notes": null,                            // <= 2000
      "startAt":    null,                       // ISO-8601 or null
      "dueAt":      "2026-08-11T09:00:00+02:00",
      "reminderAt": "2026-08-11T09:00:00+02:00",
      "recurrence": {                           // or null
        "frequency": "daily|weekly|monthly|yearly",
        "interval":  1,                         // 1..365
        "byWeekday": [1, 5],                    // ISO weekdays, Mon=1
        "until":     null,
        "count":     null
      },
      "priority":  "none|low|medium|high",
      "durationMinutes": null,                  // 1..1440
      "durationIsEstimate": false,
      "tags": ["work"],                         // <= 10
      "ambiguities": [
        {
          "field":  "dueAt",
          "reason": "\"later\" doesn't say when. Pick a time.",
          "sourceSpan": "later",
          "alternatives": [
            { "label": "This evening", "dateTime": "2026-08-10T19:00:00+02:00" }
          ]
        }
      ],
      "warnings": [
        { "code": "TIME_ASSUMED", "message": "…", "field": "dueAt" }
      ],
      "confidenceByField": { "dueAt": 0.9 }
    }
  ]
}
```

Rejected outright by `DraftCodec` (whole result discarded, tier C runs):
a `schemaVersion` newer than Dart's, more than 8 tasks, more than 10 tags,
an unknown `priority` or `frequency`, an out-of-range `interval` or
`durationMinutes`, an unparseable timestamp, or over-long text.

A `reminderAt` earlier than `referenceNow` is silently dropped rather than
rejected — a reminder must never be scheduled into the past.

## `cancel(Map) -> void`

`{"requestId": "…"}`. Must be safe to call for an unknown id and must never
throw.

---

## Errors

Native code raises a `FlutterError`/`PlatformException` whose **code** is one
of the `LocalAiErrorCode` wire values. Anything unrecognised becomes `UNKNOWN`.

`MODEL_UNAVAILABLE` · `MODEL_DISABLED` · `MODEL_NOT_READY` · `BUSY_OR_QUOTA` ·
`BACKGROUND_BLOCKED` · `UNSUPPORTED_LANGUAGE` · `OUTPUT_INVALID` ·
`PARSE_TIMEOUT` · `CANCELLED` · `INPUT_TOO_LONG` · `UNKNOWN`

Every one of these degrades to the deterministic parser. None of them is shown
to the user as a failure unless the deterministic parser also fails.

The message must never contain user task text — these codes reach the local
audit log.

---

## Why the two adapters differ

**iOS** uses `@Generable` guided generation, so the model is structurally
constrained to the schema and decoding cannot produce a shape mismatch.

**Android** prompts for JSON and parses it, because ML Kit's typed structured
output currently needs a KSP plugin plus an alpha `genai-schema-compiler`
artifact. That is a heavy, unstable build dependency for a payload `DraftCodec`
already validates. Malformed JSON simply becomes `OUTPUT_INVALID` and the
deterministic parser runs — which is the designed behaviour, not a workaround.
Worth revisiting once typed output leaves alpha.
