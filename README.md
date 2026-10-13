<div align="center">

# Romlerk — Mobile

**A local-first, AI-assisted todo app for iOS and Android. Type or say what you need to do, and Romlerk turns it into a structured task on your device.**

![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Riverpod](https://img.shields.io/badge/Riverpod-0175C2?style=for-the-badge&logo=flutter&logoColor=white)
![SQLite](https://img.shields.io/badge/SQLite-003B57?style=for-the-badge&logo=sqlite&logoColor=white)

</div>

---

## Overview

Romlerk is a privacy-first todo app. You type or speak what you need to do, and Romlerk turns it into a structured, editable task on your device and reminds you about it. There is no account, no server, and no cloud AI, and everything works in airplane mode.

The core design rule is that **generative AI is an enhancement chosen at runtime, never a dependency.** Every capture flow has a deterministic parser underneath it, so Romlerk stays a complete todo app on devices with no on-device model, a disabled one, or one that is still downloading.

## Features

- **Natural-language capture** in English and Khmer, with multi-task extraction.
- **On-device AI:** Apple Foundation Models on iOS and Gemini Nano through ML Kit on Android. Both fall back gracefully to a deterministic rules parser.
- **Draft review before saving:** fully resolved dates, plainly stated assumptions, and one-tap answers for anything ambiguous.
- **Today, Upcoming, Inbox, and Search,** with offline filters.
- **Priorities, tags, notes, durations,** and recurring tasks that roll forward when completed.
- **Local reminders** with complete and snooze actions.
- **Daily planning,** notes, and undo.
- **Voice capture** using on-device speech recognition only.
- **Optional App Lock** with biometrics or the device passcode.
- **Home-screen widgets,** calendar export, JSON and CSV export, OS backup control, and "erase all data".
- **English and Khmer localization** with bundled fonts, plus light and dark themes.

## Capability Tiers

| Tier | Runtime condition | Experience |
| --- | --- | --- |
| **A** Full local AI | Structured generation available and ready | Generative parsing and multi-task extraction |
| **B** Eligible, not ready | Disabled, downloading, initializing, or busy | Input kept, rules parser, user-initiated retry |
| **C** Baseline parsing | No generative model | Deterministic dates, times, recurrence, and full manual editing |
| **D** Manual core | Parser unavailable | Fast task form, lists, search, notifications |

`CapabilityRouter` picks a tier for each request. A generative failure falls back to the rules parser, and the user's text is never discarded.

## Tech Stack

| Area | Technology |
| --- | --- |
| Framework | Flutter, Dart |
| State management | Riverpod |
| Database | Drift (SQLite) |
| On-device AI | Apple Foundation Models (iOS), Gemini Nano through ML Kit GenAI (Android) |
| Notifications | flutter_local_notifications, timezone |
| Platform | local_auth, home_widget, share_plus, file_selector |
| Localization | Flutter gen-l10n (English and Khmer) |
| CI | GitHub Actions |

## Getting Started

### Prerequisites

- Flutter SDK
- Xcode for iOS (Swift Package Manager, no CocoaPods), and Android Studio or the Android SDK for Android

### Installation

```bash
git clone https://github.com/RithyBondeth/Romlerk-Mobile.git
cd Romlerk-Mobile
flutter pub get
flutter run
```

After changing `lib/data/local/tables.dart`, regenerate the Drift code:

```bash
dart run build_runner build
```

### Testing

```bash
flutter test
```

Before a release, run [`docs/device-test-checklist.md`](docs/device-test-checklist.md) on real hardware.

### Android Release Signing

Copy `android/key.properties.example` to `android/key.properties`, set the keystore path, alias, and passwords, then run `flutter build appbundle --release`.

## Project Structure

```text
Romlerk-Mobile/
├── lib/
│   ├── domain/        # Entities, enums, drafts, repository contracts (pure Dart)
│   ├── data/          # Drift schema, repositories, export, backup, settings
│   ├── local_ai/      # LocalAi contract, deterministic parser, platform bridge, router
│   ├── services/      # Reminders, voice, calendar, widgets, device authentication
│   ├── application/   # Task service, capture controller, undo, Riverpod graph
│   ├── core/          # Design tokens, theme, motion, shared widgets
│   ├── features/      # today, upcoming, inbox, search, capture, notes, task_detail,
│   │                  # settings, onboarding, lock, shell
│   └── l10n/          # English and Khmer ARB files
├── docs/              # Native AI and voice contracts, device checklist, design notes
├── integration_test/
└── test/
```

## Privacy

- No first-party backend, account system, or cloud inference.
- The local parse audit log holds no content by design: it stores only outcomes, latency buckets, and capability tiers.
- Voice uses on-device recognition only.
- You choose whether tasks are included in the phone's encrypted OS backup.

## Related Repositories

- [Romlerk-Web](https://github.com/RithyBondeth/Romlerk-Web): the landing page for Romlerk

## Author

**Rithy Bondeth** — Full Stack Developer & AI Engineer

[![Portfolio](https://img.shields.io/badge/Portfolio-0A0A0A?style=for-the-badge&logo=vercel&logoColor=white)](https://bondeth.dev)
[![GitHub](https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/RithyBondeth)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/rithy-bondeth-484073282/)
