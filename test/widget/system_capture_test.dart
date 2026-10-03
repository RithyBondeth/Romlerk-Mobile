import 'package:romlerk_mobile/application/capture_controller.dart';
import 'package:romlerk_mobile/data/capture/capture_draft_store.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romlerk_mobile/application/providers.dart';
import 'package:romlerk_mobile/core/design/app_theme.dart';
import 'package:romlerk_mobile/data/local/app_database.dart';
import 'package:romlerk_mobile/data/local/settings_store.dart';
import 'package:romlerk_mobile/features/capture/capture_sheet.dart';
import 'package:romlerk_mobile/features/lock/app_lock_gate.dart';
import 'package:romlerk_mobile/features/shell/home_shell.dart';
import 'package:romlerk_mobile/l10n/app_localizations.dart';
import 'package:romlerk_mobile/services/notifications/reminder_scheduler.dart';
import 'package:romlerk_mobile/services/security/device_authenticator.dart';
import 'package:romlerk_mobile/services/voice/voice_capture_service.dart';
import 'app_lock_gate_test.dart' show FakeAuthenticator;
import 'capture_voice_test.dart' show FakeVoiceCaptureService;
import '../support/drift_widget_harness.dart';

class Scheduler extends ReminderScheduler {
  @override
  Future<void> initialize() async {}
  @override
  Future<Set<int>> pendingPlatformIds() async => {};
  @override
  Future<String?> launchTaskId() async => null;
}

class FailingDraftStore extends CaptureDraftStore {
  FailingDraftStore(super.db);
  @override
  Future<void> write(CaptureState state) async =>
      throw StateError('Storage unavailable');
}

void main() {
  late AppDatabase db;
  const channel = MethodChannel('dev.romlerk/capture');
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await db.close();
  });
  testDriftWidgets(
    'system shared text waits behind app lock then opens capture without saving',
    (tester) async {
      final queue = ['Call Dara tomorrow'];
      var takes = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'peek') {
              takes++;
              return queue.isEmpty
                  ? null
                  : {'id': 'request-1', 'text': queue.first};
            }
            if (call.method == 'acknowledge') {
              final draft = await CaptureDraftStore(db).read();
              expect(draft!.input, queue.first);
              expect(draft.nativeRequestId, call.arguments);
              queue.removeAt(0);
            }
            return null;
          });
      await SettingsStore(db).write(
        const AppSettings(appLockEnabled: true, onboardingComplete: true),
      );
      final auth = FakeAuthenticator()..results.add(UnlockResult.cancelled);
      final voice = FakeVoiceCaptureService(
        availabilityValue: VoiceAvailability.unsupported,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            reminderSchedulerProvider.overrideWithValue(Scheduler()),
            deviceAuthenticatorProvider.overrideWithValue(auth),
            voiceCaptureServiceProvider.overrideWithValue(voice),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (_, child) => AppLockGate(child: child!),
            home: const HomeShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(takes, 0);
      expect(queue, ['Call Dara tomorrow']);
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      expect(find.byType(CaptureSheet), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Call Dara tomorrow',
      );
      expect(await db.select(db.taskRows).get(), isEmpty);
    },
  );
  Future<void> pumpShell(
    WidgetTester tester, {
    CaptureDraftStore? store,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          appUnlockedProvider.overrideWith((ref) => true),
          reminderSchedulerProvider.overrideWithValue(Scheduler()),
          voiceCaptureServiceProvider.overrideWithValue(
            FakeVoiceCaptureService(
              availabilityValue: VoiceAvailability.unsupported,
            ),
          ),
          if (store != null) captureDraftStoreProvider.overrideWithValue(store),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final scenario in ['write fails', 'existing draft', 'interrupted ack']) {
    testDriftWidgets('native capture preserves text when $scenario', (
      tester,
    ) async {
      var acknowledged = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'peek') {
              return {'id': 'pending-id', 'text': 'Shared text'};
            }
            if (call.method == 'acknowledge') {
              acknowledged = true;
              expect(call.arguments, 'pending-id');
            }
            return null;
          });
      if (scenario != 'write fails') {
        await CaptureDraftStore(db).write(
          CaptureState(
            input: 'Previous draft',
            nativeRequestId: scenario == 'interrupted ack'
                ? 'pending-id'
                : 'different-id',
          ),
        );
      }
      await pumpShell(
        tester,
        store: scenario == 'write fails' ? FailingDraftStore(db) : null,
      );
      expect(acknowledged, scenario == 'interrupted ack');
      expect(find.byType(CaptureSheet), findsNothing);
      if (scenario != 'write fails') {
        expect((await CaptureDraftStore(db).read())!.input, 'Previous draft');
      }
      expect(await db.select(db.taskRows).get(), isEmpty);
    });
  }
}
