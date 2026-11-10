// End-to-end run of the real app on a device or emulator: real database,
// real notification scheduling, real screens.
//
//   flutter test integration_test -d <device>
//
// On Android 13+, grant notifications first so no system dialog blocks the
// run (see docs/device-test-checklist.md for the manual counterpart):
//   adb shell pm grant dev.romlerk.app android.permission.POST_NOTIFICATIONS

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:romlerk_mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Pumps frames until [finder] matches, without pumpAndSettle's
  /// requirement that every animation has stopped.
  Future<void> pumpUntil(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) return;
    }
    throw TestFailure('Timed out waiting for $finder');
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tapNav(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      ),
    );
    await settle(tester);
  }

  Future<void> capture(WidgetTester tester, String text) async {
    await tester.tap(find.text('What needs doing?'));
    await pumpUntil(tester, find.byType(TextField));
    await tester.enterText(find.byType(TextField).first, text);
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await pumpUntil(tester, find.text('Save task'));
    await tester.tap(find.text('Save task'));
    await settle(tester);
  }

  final notifications = FlutterLocalNotificationsPlugin();

  Future<List<PendingNotificationRequest>> pending() =>
      notifications.pendingNotificationRequests();

  testWidgets('capture, remind, search, complete, and hide previews', (
    tester,
  ) async {
    app.main();
    await pumpUntil(
      tester,
      find.byWidgetPredicate(
        (widget) =>
            (widget is Text && widget.data == 'Skip') ||
            widget is NavigationBar,
      ),
      timeout: const Duration(seconds: 30),
    );

    // First launch shows the intro.
    if (find.text('Skip').evaluate().isNotEmpty) {
      await tester.tap(find.text('Skip'));
      await pumpUntil(tester, find.byType(NavigationBar));
    }

    // --- Capture with a real reminder. "Task saved" (not the "no reminder
    // will arrive" warning) means the OS accepted the notification.
    await capture(tester, 'Call David tomorrow at 9am');
    await pumpUntil(tester, find.text('Task saved'));

    await capture(tester, 'Stretch in 2 minutes');
    await pumpUntil(tester, find.text('Task saved'));

    var scheduled = await pending();
    expect(
      scheduled.map((request) => request.title),
      containsAll(<String>['Call David', 'Stretch']),
      reason: 'both reminders are registered with the OS',
    );

    // --- Upcoming lists tomorrow's task.
    await tapNav(tester, 'Upcoming');
    await pumpUntil(tester, find.text('Call David'));

    // --- Search with the due filters.
    await tapNav(tester, 'Search');
    await pumpUntil(tester, find.text('Stretch'));
    await tester.tap(find.widgetWithText(FilterChip, 'Today'));
    await settle(tester);
    expect(find.text('Stretch'), findsOneWidget);
    expect(find.text('Call David'), findsNothing);
    await tester.tap(find.widgetWithText(FilterChip, 'Next 7 days'));
    await settle(tester);
    expect(find.text('Stretch'), findsOneWidget);
    expect(find.text('Call David'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'Next 7 days'));
    await settle(tester);

    // --- Complete from the detail page; its reminder is withdrawn.
    await tester.tap(find.text('Call David'));
    await pumpUntil(tester, find.text('Mark complete'));
    await tester.tap(find.text('Mark complete'));
    await settle(tester);
    // System Back: the detail page draws its own arrow, not the stock one.
    await tester.binding.handlePopRoute();
    await settle(tester);
    await tester.tap(find.text('Done'));
    await pumpUntil(tester, find.text('Call David'));
    scheduled = await pending();
    expect(
      scheduled.map((request) => request.title),
      isNot(contains('Call David')),
      reason: 'completing a task cancels its reminder',
    );

    // --- Hiding previews rewrites reminders already scheduled.
    await tester.tap(find.byTooltip('Settings').first);
    await pumpUntil(tester, find.text('Hide task text in notifications'));
    expect(find.text('Include tasks in phone backup'), findsOneWidget);
    expect(find.text('App Lock'), findsOneWidget);
    await tester.tap(find.text('Hide task text in notifications'));
    await settle(tester);
    await pumpUntil(tester, find.text('Hide task text in notifications'));
    scheduled = await pending();
    expect(scheduled, isNotEmpty);
    expect(
      scheduled.map((request) => request.title),
      everyElement('Reminder'),
      reason: 'no task title left in any scheduled notification',
    );

    // --- The reminder actually fires (Android can report it on screen).
    if (Platform.isAndroid) {
      final android = notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()!;
      final deadline = DateTime.now().add(const Duration(minutes: 6));
      var shown = <ActiveNotification>[];
      while (DateTime.now().isBefore(deadline)) {
        shown = await android.getActiveNotifications();
        if (shown.isNotEmpty) break;
        await tester.pump(const Duration(seconds: 5));
      }
      expect(
        shown.map((notification) => notification.title),
        contains('Reminder'),
        reason: 'the scheduled reminder was delivered to the shade',
      );
    }
  });
}
