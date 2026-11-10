# Mobile UI redesign

Romlerk uses a soft blue background, raised white surfaces, and cobalt blue
primary actions. The dark theme uses navy surfaces and a lighter
blue accent. Status colors remain distinct for overdue tasks and warnings.

## Typography

English uses bundled Ubuntu Regular, Medium, and Bold. Khmer uses bundled
Koh Santepheap Regular and Bold (interpreting the requested “Koh Sopheap” as
this family). Ubuntu is the primary family and Koh Santepheap the fallback,
so mixed English/Khmer content selects the right font by script. Open line
boxes and zero tracking keep Khmer marks readable. No fonts are fetched at
runtime.

Upstream: [Ubuntu](https://github.com/google/fonts/tree/main/ufl/ubuntu),
[Koh Santepheap](https://github.com/google/fonts/tree/main/ofl/kohsantepheap).
Licenses are bundled beside each family in `assets/fonts/`.

## Screen changes

- Today: an illustrated planning card with saved progress, a single focus action, and clearer
  sections for overdue, today, and completed tasks.
- Upcoming: date filters above the schedule; All restores every scheduled day.
- Inbox: an illustrated introduction, shared task cards, larger completion targets, and an illustrated empty
  state explaining where unscheduled tasks live.
- Notes: dated previews, mixed-language text, and a labelled creation action.
- Search: consistent input, status segments, filters, and task results.
- Capture: an introductory heading, clearer input surface, reviewed drafts, and
  persistent actions above the keyboard.
- Task and note editors: stronger headings, readable fields, grouped metadata,
  and visible autosave status.
- Settings, app lock, and onboarding: matching surfaces, clearer groups, and
  content that remains scrollable with large text or short screens.

Bundled Open Doodles illustrations use navy line art and blue accents. They
appear on populated screens as well as empty states, including Upcoming, Inbox,
Notes, Search, Capture, planning, editors, lock, and onboarding. Artwork stacks
above text on narrow screens with enlarged text and is excluded from screen
reader announcements. Settings and onboarding also show the app's mascot.

The original mascot icon keeps its artwork and pose, with orange accents
recolored blue. The source is preserved beside the new blue source. Launcher
icons, native splash images, and the in-app logo are exported from that blue
source; see [branding instructions](../assets/branding/README.md).

The persistent dock floats in a rounded pill, inset from screen edges and the
home indicator, with a separate capture action above it. One blue selection
surface glides between destinations and expands to reveal the active label
beside its icon. Inactive tabs show their icon; all labels remain available to
screen readers and long-press tooltips. Large text can wrap within the active
row. Icons lift and settle, and held presses compress their tab. Capture stays
within thumb reach. Peer tabs retain their
state and scroll offsets. Motion uses brief press feedback, eased tab changes,
animated completion marks, and progress changes. Reduced motion uses immediate
states; scroll controllers jump instead of receiving an invalid zero-duration
animation.

## Previews

These renders use bundled fonts, real screen widgets, and an in-memory fixture.
They show sample tasks and notes, not the user's stored data.

| Screen | English light | Khmer light | English dark | Khmer dark |
| --- | --- | --- | --- | --- |
| Today | [Preview](ui-previews/en-light-today.png) | [Preview](ui-previews/km-light-today.png) | [Preview](ui-previews/en-dark-today.png) | [Preview](ui-previews/km-dark-today.png) |
| Upcoming | [Preview](ui-previews/en-light-upcoming.png) | [Preview](ui-previews/km-light-upcoming.png) | [Preview](ui-previews/en-dark-upcoming.png) | [Preview](ui-previews/km-dark-upcoming.png) |
| Inbox | [Preview](ui-previews/en-light-inbox.png) | [Preview](ui-previews/km-light-inbox.png) | [Preview](ui-previews/en-dark-inbox.png) | [Preview](ui-previews/km-dark-inbox.png) |
| Notes | [Preview](ui-previews/en-light-notes.png) | [Preview](ui-previews/km-light-notes.png) | [Preview](ui-previews/en-dark-notes.png) | [Preview](ui-previews/km-dark-notes.png) |
| Search | [Preview](ui-previews/en-light-search.png) | [Preview](ui-previews/km-light-search.png) | [Preview](ui-previews/en-dark-search.png) | [Preview](ui-previews/km-dark-search.png) |

Additional English previews: [Capture](ui-previews/en-light-capture.png),
[task editor](ui-previews/en-light-task-detail.png),
[note editor](ui-previews/en-light-note-detail.png),
[settings](ui-previews/en-light-settings.png), and
[onboarding running in the iOS simulator](ui-previews/ios-onboarding.png).

Regenerate the preview images:

```sh
flutter test test/widget/redesign_layout_test.dart --dart-define=ROMLERK_WRITE_PREVIEWS=true
```

## Verification

The layout checks render English and Khmer with the bundled fonts, light and
dark themes, 320×640 and 390×844 phones, and a 768×1024 tablet. They include
200% text size, reduced motion, a keyboard, all main tabs, editors, planning,
capture, and onboarding. Interaction checks cover the Upcoming date filter,
floating dock clearances, interrupted selection movement, held presses,
screen-reader selection, keyboard activation, horizontal active labels, and
immediate selection under reduced motion.
The existing capture, autosave, planning, search, and reminder tests continue
to cover product behavior.

Validation completed: `flutter analyze --no-pub` is clean; all 280 tests pass;
the iOS simulator debug build succeeds and launches to onboarding; the Android
debug APK builds successfully. The Android home-screen widget uses the same
blue accent and surface colors.
