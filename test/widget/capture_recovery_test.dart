import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romlerk_mobile/application/capture_controller.dart';
import 'package:romlerk_mobile/application/providers.dart';
import 'package:romlerk_mobile/core/design/app_theme.dart';
import 'package:romlerk_mobile/data/capture/capture_draft_store.dart';
import 'package:romlerk_mobile/data/local/app_database.dart';
import 'package:romlerk_mobile/features/capture/capture_sheet.dart';
import 'package:romlerk_mobile/l10n/app_localizations.dart';
import 'package:romlerk_mobile/services/voice/voice_capture_service.dart';
import 'capture_voice_test.dart' show FakeVoiceCaptureService;
import '../support/drift_widget_harness.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          voiceCaptureServiceProvider.overrideWithValue(
            FakeVoiceCaptureService(
              availabilityValue: VoiceAvailability.unsupported,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => CaptureSheet.show(context),
                child: const Text('Capture'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testDriftWidgets('dismiss and resume keeps typed input; discard clears it', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Capture'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ហៅ ដារ៉ា tomorrow');
    await tester.tap(find.byTooltip('Close and keep draft'));
    await tester.pumpAndSettle();
    expect(find.byType(CaptureSheet), findsNothing);
    expect((await CaptureDraftStore(db).read())!.input, 'ហៅ ដារ៉ា tomorrow');
    await tester.tap(find.text('Capture'));
    await tester.pumpAndSettle();
    expect(find.text('Resume your capture?'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'ហៅ ដារ៉ា tomorrow',
    );
    await tester.tap(find.byTooltip('Close and keep draft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Capture'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(await CaptureDraftStore(db).read(), isNull);
    expect(await db.select(db.taskRows).get(), isEmpty);
    await tester.tap(find.byTooltip('Close and keep draft'));
    await tester.pumpAndSettle();
  });

  testDriftWidgets('saved draft resumes after widget and provider recreation', (
    tester,
  ) async {
    await CaptureDraftStore(
      db,
    ).write(const CaptureState(input: 'Recovered after restart'));
    await pump(tester);
    await tester.tap(find.text('Capture'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Recovered after restart',
    );
    await tester.tap(find.byTooltip('Close and keep draft'));
    await tester.pumpAndSettle();
  });
}
