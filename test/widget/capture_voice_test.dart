import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romlerk_mobile/application/providers.dart';
import 'package:romlerk_mobile/core/design/app_theme.dart';
import 'package:romlerk_mobile/data/local/app_database.dart';
import 'package:romlerk_mobile/data/local/settings_store.dart';
import 'package:romlerk_mobile/features/capture/capture_sheet.dart';
import 'package:romlerk_mobile/services/voice/voice_capture_service.dart';
import 'package:romlerk_mobile/l10n/app_localizations.dart';
import '../support/drift_widget_harness.dart';

/// Scripted stand-in for the native recognizer.
class FakeVoiceCaptureService implements VoiceCaptureService {
  FakeVoiceCaptureService({
    this.availabilityValue = VoiceAvailability.available,
    this.grantPermission = true,
  });

  VoiceAvailability availabilityValue;
  bool grantPermission;
  int permissionRequests = 0;
  int starts = 0;

  final StreamController<VoiceCaptureState> _states =
      StreamController<VoiceCaptureState>.broadcast();
  VoiceCaptureState _state = VoiceCaptureState.idle;

  void _emit(VoiceCaptureState next) {
    _state = next;
    _states.add(next);
  }

  void speak(String text) => _emit(_state.copyWith(transcript: text));

  @override
  Stream<VoiceCaptureState> get stateStream => _states.stream;

  @override
  VoiceCaptureState get state => _state;

  @override
  Future<VoiceAvailability> availability() async => availabilityValue;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    if (grantPermission) availabilityValue = VoiceAvailability.available;
    return grantPermission;
  }

  @override
  Future<void> start() async {
    starts++;
    _emit(const VoiceCaptureState(status: VoiceCaptureStatus.listening));
  }

  @override
  Future<void> stop() async {
    _emit(
      VoiceCaptureState(
        status: VoiceCaptureStatus.idle,
        transcript: _state.transcript,
      ),
    );
  }

  @override
  Future<void> cancel() async {
    if (_state.isActive) _emit(VoiceCaptureState.idle);
  }

  @override
  void dispose() => _states.close();
}

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  final mic = find.byTooltip('Speak a task');

  Future<void> pumpCapture(
    WidgetTester tester,
    FakeVoiceCaptureService voice,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(database),
          clockProvider.overrideWithValue(() => DateTime(2026, 8, 10, 14, 30)),
          voiceCaptureServiceProvider.overrideWithValue(voice),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: CaptureSheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String fieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testDriftWidgets('no microphone where on-device voice is unsupported', (
    tester,
  ) async {
    await pumpCapture(
      tester,
      FakeVoiceCaptureService(availabilityValue: VoiceAvailability.unsupported),
    );
    expect(mic, findsNothing);
  });

  testDriftWidgets('privacy is explained before the permission prompt', (
    tester,
  ) async {
    final voice = FakeVoiceCaptureService(
      availabilityValue: VoiceAvailability.permissionNeeded,
    );
    await pumpCapture(tester, voice);

    await tester.tap(mic);
    await tester.pumpAndSettle();
    expect(find.text('Voice stays on this phone'), findsOneWidget);

    // Declining asks for nothing and records nothing.
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(voice.permissionRequests, 0);
    expect(voice.starts, 0);

    await tester.tap(mic);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Continue'),
      ),
    );
    await tester.pumpAndSettle();
    expect(voice.permissionRequests, 1);
    expect(voice.starts, 1);
    expect(find.text('Listening…'), findsOneWidget);

    final settings = await SettingsStore(database).read();
    expect(settings.voicePrivacyAcknowledged, isTrue);
  });

  testDriftWidgets('the transcript lands in the editable field', (
    tester,
  ) async {
    final voice = FakeVoiceCaptureService();
    await SettingsStore(
      database,
    ).write(const AppSettings(voicePrivacyAcknowledged: true));
    await pumpCapture(tester, voice);

    await tester.tap(mic);
    await tester.pumpAndSettle();
    expect(find.text('Voice stays on this phone'), findsNothing);

    voice.speak('Call David tomorrow at 9');
    await tester.pumpAndSettle();
    expect(fieldText(tester), 'Call David tomorrow at 9');

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Listening…'), findsNothing);
    expect(fieldText(tester), 'Call David tomorrow at 9');
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text('Continue'),
              matching: find.byWidgetPredicate((w) => w is FilledButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
  });

  testDriftWidgets('cancel puts back exactly what was typed', (tester) async {
    final voice = FakeVoiceCaptureService();
    await SettingsStore(
      database,
    ).write(const AppSettings(voicePrivacyAcknowledged: true));
    await pumpCapture(tester, voice);

    await tester.enterText(find.byType(TextField), 'Buy milk');
    await tester.tap(mic);
    await tester.pumpAndSettle();
    voice.speak('and eggs');
    await tester.pumpAndSettle();
    expect(fieldText(tester), 'Buy milk and eggs');

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(fieldText(tester), 'Buy milk');
  });
}
