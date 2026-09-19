# Native voice bridge contract

Channel: `dev.romlerk/voice` (`MethodChannel`, standard codec).

Implemented by `ios/Runner/LocalAi/VoiceBridge.swift` and
`android/app/src/main/kotlin/.../VoiceBridge.kt`; consumed by
`PlatformVoiceCaptureService`.

**The one rule:** recognition is on-device or it does not happen. iOS sets
`requiresOnDeviceRecognition`; Android uses
`SpeechRecognizer.createOnDeviceSpeechRecognizer` (API 31+). Neither falls back
to a server recognizer, because NFR-07 says voice content never leaves the
device. Where on-device recognition is missing the adapter says so, and the app
hides the microphone.

If the channel has no receiver (desktop, web, tests), `MissingPluginException`
is caught and treated as `unsupported`.

---

## Dart → native

### `availability({locale}) -> {status}`

No prompts. `status` is one of:

| status | meaning |
|---|---|
| `available` | on-device recognizer present, permissions granted |
| `permissionNeeded` | supported; the user has not been asked (Android: or declined without "don't ask again") |
| `permissionDenied` | declined; only system Settings can change it (iOS only — Android cannot tell) |
| `unsupported` | no on-device recognizer on this device/OS |
| `languageUnsupported` | on-device recognition exists, not for `locale` (iOS; Android reports this from `start`) |

### `requestPermission() -> bool`

Shows the OS prompts (iOS: speech recognition, then microphone). Called only
after the user taps the microphone and has seen the privacy explanation.

### `start({locale}) -> null`

Begins listening. Fails with a `PlatformException` whose `code` is one of the
error codes below.

### `stop() -> null`

Stops recording. The recognizer then sends a final `onTranscript` and
`onEnded`.

### `cancel() -> null`

Stops and discards. No further events are sent for that session.

## Native → Dart

### `onTranscript({text, isFinal})`

The best transcript so far, replacing the previous one.

### `onEnded({error?})`

The session is over. `error` is absent on success.

## Error codes

`NO_SPEECH`, `PERMISSION_DENIED`, `LANGUAGE_UNSUPPORTED`, `BUSY`,
`UNAVAILABLE`, `RECOGNITION_FAILED`. Anything else is read as
`RECOGNITION_FAILED`. A transcript received before an error is kept.

## Dart-side behaviour

- Listening stops after 2.5 s without a new partial transcript (iOS's
  on-device recognizer does not end on silence by itself) and after 60 s
  regardless.
- The transcript is written into the capture text field. It is edited and
  parsed exactly like typed text; nothing is parsed or saved from audio
  directly.
