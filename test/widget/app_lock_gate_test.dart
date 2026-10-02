import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romlerk_mobile/application/providers.dart';
import 'package:romlerk_mobile/core/design/app_theme.dart';
import 'package:romlerk_mobile/data/local/app_database.dart';
import 'package:romlerk_mobile/data/local/settings_store.dart';
import 'package:romlerk_mobile/features/lock/app_lock_gate.dart';
import 'package:romlerk_mobile/services/security/device_authenticator.dart';
import 'package:romlerk_mobile/l10n/app_localizations.dart';
import '../support/drift_widget_harness.dart';

class FakeAuthenticator implements DeviceAuthenticator {
  final List<UnlockResult> results = <UnlockResult>[];
  int calls = 0;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<UnlockResult> authenticate(String reason) async {
    calls++;
    return results.isEmpty ? UnlockResult.unlocked : results.removeAt(0);
  }
}

void main() {
  late AppDatabase database;
  late FakeAuthenticator auth;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    auth = FakeAuthenticator();
  });
  tearDown(() => database.close());

  Future<void> pump(WidgetTester tester, {required bool lockOn}) async {
    await SettingsStore(database).write(AppSettings(appLockEnabled: lockOn));
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(database),
          deviceAuthenticatorProvider.overrideWithValue(auth),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => AppLockGate(child: child!),
          home: const Scaffold(body: Text('Call the clinic')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool contentVisible(WidgetTester tester) =>
      find.text('Romlerk is locked').evaluate().isEmpty;

  testDriftWidgets('off by default: no prompt, content shown', (tester) async {
    await pump(tester, lockOn: false);
    expect(auth.calls, 0);
    expect(contentVisible(tester), isTrue);
  });

  testDriftWidgets('on: cold start asks, and unlocking reveals content', (
    tester,
  ) async {
    await pump(tester, lockOn: true);
    expect(auth.calls, 1);
    expect(contentVisible(tester), isTrue);
  });

  testDriftWidgets('cancelling keeps it locked until Unlock succeeds', (
    tester,
  ) async {
    auth.results.add(UnlockResult.cancelled);
    await pump(tester, lockOn: true);
    expect(contentVisible(tester), isFalse);

    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(auth.calls, 2);
    expect(contentVisible(tester), isTrue);
  });

  testDriftWidgets('a phone with no passcode never locks its owner out', (
    tester,
  ) async {
    auth.results.add(UnlockResult.unavailable);
    await pump(tester, lockOn: true);
    expect(contentVisible(tester), isTrue);
    expect((await SettingsStore(database).read()).appLockEnabled, isFalse);
  });
}
