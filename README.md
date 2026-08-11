# Romlerk

A local-first, AI-assisted todo app built with Flutter.

You type or say what you need to do; Romlerk turns it into a structured,
editable task on your device and reminds you. There is no account, no server,
and no cloud AI. Everything works in airplane mode.

Built against the product proposal / PRD / BRD in `../docs`. The UX/UI design
document was deliberately **not** followed — the interface here is its own
design.

---

## The central architectural rule

Generative AI is an *enhancement selected at runtime*, never a dependency.
Every capture flow has a deterministic path underneath it, so the app stays a
complete todo app on a device with no on-device model, a disabled one, or a
model that is still downloading.

Four runtime tiers (BRD §14), chosen per request from live capability state —
never from device marketing names:

| Tier | Runtime condition | Experience |
|---|---|---|
| **A** Full local AI | Structured generation available and ready | Generative parse, multi-task extraction |
| **B** Eligible, not ready | Disabled, downloading, initializing, busy | Input retained, rules parser, user-initiated retry |
| **C** Baseline parsing | No generative model | Deterministic dates/times/recurrence + full manual editing |
| **D** Manual core | Parser unavailable | Fast task form, lists, search, notifications |

`CapabilityRouter` enforces this. A generative failure *degrades* to the rules
parser rather than surfacing an error, and the user's text is never discarded.

---

## Layout

```
lib/
  domain/          Entities, enums, draft model, repository contract. No Flutter,
                   no Drift, no platform types.
  data/            Drift schema, repository implementation, JSON/CSV export,
                   local settings store.
  local_ai/        The LocalAi contract and its three implementations:
    deterministic/   Rules parser (tier C) — the reference implementation
    platform/        Method-channel bridge + untrusted-output codec
    capability_router.dart  Picks a path per request, degrades, audits
  services/        Reminder scheduling facade over flutter_local_notifications
  application/     TaskService (persistence ⇄ scheduling), capture controller,
                   Riverpod graph
  core/            Design tokens, theme, formatting, shared widgets
  features/        Screens: today, upcoming, inbox, search, capture,
                   task_detail, settings, shell
```

The dependency rule from NFR-15 holds: the app depends on `TaskRepository` and
`LocalAi`, never on Drift or a vendor API directly. Swapping the store — for a
future syncing one — touches `data/` only.

### The deterministic parser

`lib/local_ai/deterministic/` is a supported *subset* of English, not an
attempt at open-ended understanding. Given the same text and the same
`referenceNow`, it always produces the same drafts, which is what makes it
unit-testable and usable as the benchmark the generative tiers are measured
against.

It handles relative and absolute dates, clock times, parts of day, recurrence,
priority (words and `!`/`!!`/`!!!`), `#tags`, and durations — and reports what
it could not resolve rather than guessing.

Multi-task splitting is deliberately **precision-biased**: a split only happens
when the text after `and`/`then` starts with a known action verb. "Buy milk and
email Ana tonight" splits into two; "Call David and Sam tomorrow" stays one.
Inventing a task the user never asked for is much worse than leaving one to
edit.

### Preview before consequence

Nothing is written until the user confirms. The draft review card:

- shows the **fully resolved local date** ("Tuesday, 11 August at 9:00 AM")
  even when the user typed "tomorrow";
- states every assumption plainly ("No time was specified, so 9:00 AM was
  used", "9:00 AM has already passed today, so this was set for tomorrow");
- **blocks saving** on anything genuinely ambiguous and offers one-tap answers
  instead of picking for you.

### Failure atomicity

A task and its OS notification cannot be one transaction. The order is fixed:
write the task and its reminder *intent*, attempt the platform schedule, record
the real outcome. A refused permission or a rejected schedule produces a saved
task plus a visible warning — never a lost task. Reminder state is reconciled
against the OS on every resume.

---

## Privacy posture

- No first-party backend, account system, or cloud inference.
- The local parse audit log is content-free **by construction**: its columns
  can only hold an outcome, a coarse latency bucket, a capability tier, and a
  schema version. There is no column a task title could go in.
- Settings live in the app database, not platform preferences, so "erase all
  data" genuinely clears one place.
- Fonts are the platform's own. A downloaded webfont would put a network
  request in an app whose whole promise is that it does not need one.
- Copy says "processed on device", never "never uses the internet" — the OS may
  still fetch model or configuration data, and overclaiming is a store-review
  and trust risk.

---

## Running it

```bash
flutter pub get
```

```bash
flutter run
```

Code generation (Drift) after changing `lib/data/local/tables.dart`:

```bash
dart run build_runner build
```

```bash
flutter test
```

iOS uses Swift Package Manager rather than CocoaPods; every plugin in use ships
as a Swift Package, so there is no `Podfile`.

---

## Status

**Working end to end:** no-account first run · manual and natural-language
capture · multi-task extraction · draft review with ambiguity and assumption
cues · Today / Upcoming / Inbox / Search · offline search and filters ·
priority, tags, notes, duration · recurring tasks that roll forward on
completion · local reminders with complete/snooze actions · capability
detection with graceful degradation · JSON and CSV export · erase all data ·
light and dark themes.

**Native adapters, built and wired:** both speak `dev.romlerk/local_ai` — see
[`docs/native_local_ai_contract.md`](docs/native_local_ai_contract.md).

- **iOS** — `ios/Runner/LocalAi/`, Apple Foundation Models with `@Generable`
  guided generation, so the model is structurally constrained to the schema.
  Availability, error taxonomy, and cancellation all map to the shared codes.
- **Android** — `android/app/src/main/kotlin/.../LocalAiBridge.kt`, Gemini Nano
  through ML Kit's GenAI Prompt API, with `FeatureStatus` mapped to the tier
  model and foreground-only enforced against the activity lifecycle.

Two things are worth knowing before trusting tier A:

1. **The small models are worse at dates than the rules parser.** Asked for
   "Friday afternoon" on a Tuesday, Apple's 3B model first answered the
   following *Monday*, and invented both a reminder and a tag that were never
   asked for. Supplying the upcoming dates as an explicit lookup table, and
   tightening the instructions, fixed the ones that were reproducible. A wrong
   date on a reminder is the worst failure this product has, so this needs a
   real benchmark corpus before tier A is trusted over tier C.
2. **Latency is far outside NFR-03 on the simulator** — 9-11 s for a two-task
   input, sometimes past the 25 s ceiling, because the simulator runs the model
   on CPU with no Neural Engine. The BRD's targets (p50 <= 2.5 s, p95 <= 7 s)
   have to be measured on real Apple Intelligence and Gemini Nano hardware
   before any of this is tuned further, which is exactly what the BRD's
   discovery gate asks for.

Neither of these is a blocker, because both degrade to the deterministic
parser and the user always gets a correct, complete result. That is the design
working, not a workaround.

**Not started** (BRD phase 1.1 and beyond): voice capture, calendar export and
read integration, home-screen widgets, App Intents / shortcuts, duration
suggestion, "what should I do now?" ranking, daily planning, purchases,
localization beyond English.

### Test coverage

105 tests. The parser (grammar, ambiguity, multi-task splitting, guard rails),
recurrence including DST and month-length clamping, the repository, the
capability router's degradation paths, failure atomicity and reminder
reconciliation, export formatting, and the Today surface, plus the codec boundary where untrusted native model
output enters the app.
