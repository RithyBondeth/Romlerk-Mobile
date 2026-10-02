# Device test checklist

What the simulator can't prove: on-device voice, Face ID, notification
buttons, the home-screen widget, and privacy settings on real hardware. Run
this on a physical iPhone before each release (about 15–20 minutes).

## Setup

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Under **Signing & Capabilities**, pick your team for **Runner**, then for
   **RomlerkWidgetExtension**. Automatic signing adds the App Group
   `group.dev.romlerk.app`; if it reports an error instead, stop there.
3. Choose the iPhone as the run destination and press **Run**.
4. Delete any leftover build with the old `com.example` bundle ID, so you
   don't mix up the two apps.

## 1. Notification buttons (FR-11)

- [ ] Capture "test in 2 minutes" and save. Allow notifications when asked.
- [ ] **Lock the phone.** When the notification arrives, long-press it and
      tap **Snooze 15 min**.
      Expected: it disappears. Open Romlerk, and the reminder is about 15
      minutes later.
- [ ] Capture another one, **swipe Romlerk away** in the app switcher, then
      tap **Complete** on the notification.
      Expected: open the app, and the task is under Done.
- [ ] Repeat with Romlerk **open on screen**. Pull down Notification Center
      and tap Complete.
      Expected: the list updates right away.

## 2. Voice (FR-16)

- [ ] Open capture. If there is **no mic button**, record the iOS version
      and phone language; that means on-device recognition isn't available.
- [ ] Tap the mic.
      Expected: first "Voice stays on this phone", then the iOS microphone
      and speech prompts.
- [ ] Say "Call David tomorrow at 9 a.m."
      Expected: text appears as you speak, stops about 2 seconds after you
      finish, and stays editable before Continue.
- [ ] Turn on **Airplane Mode** and try again.
      Expected: it still works (proof that recognition is on-device).

## 3. App Lock

- [ ] In Settings, turn on **App Lock**. It asks for Face ID first.
- [ ] Leave the app for **more than 30 seconds**, then return.
      Expected: the lock screen appears and Face ID unlocks it.
- [ ] Leave for **less than 30 seconds**.
      Expected: no lock.
- [ ] Open the **app switcher** while Romlerk is open.
      Expected: the preview hides your tasks.
- [ ] Fail Face ID on purpose.
      Expected: the passcode still gets you in.

## 4. Widget (FR-22)

- [ ] Long-press the Home Screen, tap **+**, search "Romlerk", and add the
      **Today** widget.
      Expected: top task, plus overdue and today counts.
- [ ] Complete that task in the app.
      Expected: the widget updates within a few seconds.
- [ ] Turn on **Hide task text in notifications**.
      Expected: the widget shows counts only, no titles.

## 5. Privacy settings

- [ ] With **Hide task text** still on, schedule a reminder two minutes out.
      Expected: the notification says "Reminder" and "You have a task due",
      with no task title.
- [ ] Turn **Include tasks in phone backup** off.
      Expected: it says the change takes effect at the next start. Quit and
      reopen; all tasks are still there.

## 6. Khmer (optional)

- [ ] Set the iPhone language to Khmer and reopen Romlerk.
      Expected: screens, dates, notifications, and the widget are all in
      Khmer. Note any wording to change.

## Reporting a failure

Note the step, what you saw, and a screenshot. For a crash, run from Xcode
and copy the red error text from the console.
