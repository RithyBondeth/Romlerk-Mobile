# First-run onboarding

The introduction has two optional steps:

1. **Welcome:** the blue illustration, a short explanation, and English/Khmer language choice.
2. **Try capture:** enter a sentence or use the localized example, then preview its task title and exact date. The baseline parser is the same one used by normal capture.

Skip is visible on both steps. Start my day and Skip persist completion while preserving existing preferences; returning users go directly to the app. Settings → Show introduction again replays the flow. There is no account setup or permission request.

The preview is explicitly labelled as a preview. It creates no task, reminder, audit entry, or recovery draft. Editing input invalidates the previous result, and late results cannot replace newer text. Ambiguous times ask for more detail. Failures retain input and offer retry or Skip.

Language choice persists locally and updates the app, capture locale, date formatting, and notification wording. Settings offers English, Khmer, or Follow phone language. Following the phone reacts to locale changes; an explicit choice takes precedence. Changing wording preserves the existing notification scheduler and its subscriptions. Full backups preserve the preference, legacy backups without it follow the phone, and invalid values are rejected before restore.

Motion uses an eased horizontal page transition and a brief preview fade. Reduced motion changes pages immediately. Progress indicators have fixed geometry and an announced step count. Both steps scroll with large text or the keyboard; the primary action stays above it. Ubuntu and Koh Santepheap remain bundled.

## Previews

| Screen | English light | Khmer light | English dark | Khmer dark |
| --- | --- | --- | --- | --- |
| Welcome | [Preview](ui-previews/en-light-onboarding-welcome.png) | [Preview](ui-previews/km-light-onboarding-welcome.png) | [Preview](ui-previews/en-dark-onboarding-welcome.png) | [Preview](ui-previews/km-dark-onboarding-welcome.png) |
| Parsed example | [Preview](ui-previews/en-light-onboarding-preview.png) | [Preview](ui-previews/km-light-onboarding-preview.png) | [Preview](ui-previews/en-dark-onboarding-preview.png) | [Preview](ui-previews/km-dark-onboarding-preview.png) |

[Welcome running in the iOS simulator](ui-previews/ios-onboarding-welcome.png).
Widget previews use a fixed 5 October 2026 clock and no user data.

Regenerate widget previews:

```sh
flutter test test/widget/onboarding_test.dart --dart-define=ROMLERK_WRITE_PREVIEWS=true
```

## Validation

Flutter analysis is clean. All 295 tests pass, including first-run completion/relaunch, saved language and system-locale changes, real parser output, ambiguous time, late results, parse/storage failures, backup round trips and legacy compatibility. Layouts cover both languages and themes, 390×844 and 320×640 screens, 200% text, a 260px keyboard, and reduced motion. Existing navigation, capture, editing, search, reminder and restore tests remain green. The iOS simulator debug build compiles and launches to the new welcome screen.

Physical-device onboarding and notification permission dialogs have not been tested in this change; onboarding itself never requests those permissions.
