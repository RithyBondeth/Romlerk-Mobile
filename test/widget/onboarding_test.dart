import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romlerk_mobile/application/capture_controller.dart';
import 'package:romlerk_mobile/application/providers.dart';
import 'package:romlerk_mobile/core/design/app_theme.dart';
import 'package:romlerk_mobile/data/capture/capture_draft_store.dart';
import 'package:romlerk_mobile/data/local/app_database.dart';
import 'package:romlerk_mobile/data/local/settings_store.dart';
import 'package:romlerk_mobile/features/onboarding/onboarding_page.dart';
import 'package:romlerk_mobile/features/shell/home_shell.dart';
import 'package:romlerk_mobile/l10n/l10n.dart';
import 'package:romlerk_mobile/local_ai/capabilities.dart';
import 'package:romlerk_mobile/local_ai/deterministic/deterministic_parser.dart';
import 'package:romlerk_mobile/local_ai/local_ai.dart';
import 'package:romlerk_mobile/main/app.dart';

import '../support/drift_widget_harness.dart';
import 'system_capture_test.dart' show Scheduler;

class _DeferredParser implements LocalAi {
  final pending = Completer<TaskParseResult>();
  @override
  Future<TaskParseResult> parseTasks(TaskParseRequest request) =>
      pending.future;
  @override
  Future<LocalAiCapabilities> capabilities() async =>
      const LocalAiCapabilities.deterministicOnly();
  @override
  Future<void> cancel(String requestId) async {}
  @override
  Future<DurationSuggestion?> estimateDuration(
    String title, {
    String? notes,
  }) async => null;
}

class _FailingSettings extends SettingsStore {
  _FailingSettings(super.db);
  @override
  Future<void> write(AppSettings settings) =>
      Future.error(StateError('Disk full'));
}

const _writePreviews = bool.fromEnvironment('ROMLERK_WRITE_PREVIEWS');
final _now = DateTime(2026, 10, 5, 8, 30);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entry in manifest) {
      final loader = FontLoader(entry['family'] as String);
      for (final font in entry['fonts'] as List) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(
    WidgetTester tester, {
    bool realApp = false,
    Locale locale = const Locale('en'),
    bool dark = false,
    Size size = const Size(390, 844),
    double scale = 1,
    bool reduced = false,
    double keyboard = 0,
    LocalAi? parser,
    SettingsStore? settings,
    GlobalKey? previewKey,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => _now),
          if (realApp) ...[
            reminderSchedulerProvider.overrideWithValue(Scheduler()),
            capabilitiesProvider.overrideWith(
              (ref) async => const LocalAiCapabilities.deterministicOnly(),
            ),
          ] else
            reminderSchedulerProvider.overrideWith(
              (ref) =>
                  throw StateError('Onboarding must not use notifications'),
            ),
          if (parser != null)
            onboardingParserProvider.overrideWithValue(parser),
          if (settings != null)
            settingsStoreProvider.overrideWithValue(settings),
        ],
        child: realApp
            ? const App()
            : RepaintBoundary(
                key: previewKey,
                child: Consumer(
                  builder: (context, ref, _) => MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: dark ? AppTheme.dark() : AppTheme.light(),
                    locale:
                        ref
                                .watch(settingsProvider)
                                .valueOrNull
                                ?.languagePreference ==
                            LanguagePreference.km
                        ? const Locale('km')
                        : ref
                                  .watch(settingsProvider)
                                  .valueOrNull
                                  ?.languagePreference ==
                              LanguagePreference.en
                        ? const Locale('en')
                        : locale,
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(scale),
                        disableAnimations: reduced,
                        viewInsets: EdgeInsets.only(bottom: keyboard),
                      ),
                      child: child!,
                    ),
                    home: const OnboardingPage(),
                  ),
                ),
              ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();
  }

  Future<void> preview(WidgetTester tester, GlobalKey key, String name) async {
    if (!_writePreviews) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'docs/ui-previews/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testDriftWidgets(
    'skip completes first run, preserves settings, and stays completed after relaunch',
    (tester) async {
      await SettingsStore(db).write(
        const AppSettings(
          defaultReminderHour: 14,
          themePreference: ThemePreference.dark,
        ),
      );
      await pump(tester, realApp: true);
      expect(find.byType(OnboardingPage), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeShell), findsOneWidget);
      final settings = await SettingsStore(db).read();
      expect(settings.onboardingComplete, isTrue);
      expect(settings.defaultReminderHour, 14);
      expect(settings.themePreference, ThemePreference.dark);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await pump(tester, realApp: true);
      expect(find.byType(OnboardingPage), findsNothing);
      expect(find.byType(HomeShell), findsOneWidget);
    },
  );

  testDriftWidgets(
    'language switches the app immediately and persists after relaunch',
    (tester) async {
      await pump(tester, realApp: true);
      await tester.tap(find.byKey(const ValueKey('onboarding-language-km')));
      await tester.pumpAndSettle();
      final khmer = lookupAppLocalizations(const Locale('km'));
      expect(find.text(khmer.onboardWelcomeTitle), findsOneWidget);
      expect(
        (await SettingsStore(db).read()).languagePreference,
        LanguagePreference.km,
      );
      await next(tester);
      expect(find.text(khmer.onboardTryTitle), findsOneWidget);
      expect(find.text(khmer.skip), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await pump(tester, realApp: true);
      expect(find.text(khmer.onboardWelcomeTitle), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingPage)),
      );
      expect(container.read(localeProvider), 'km');
    },
  );

  testDriftWidgets(
    'following phone language updates while an explicit choice stays selected',
    (tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('en');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      await pump(tester, realApp: true);
      tester.platformDispatcher.localeTestValue = const Locale('km');
      await tester.pumpAndSettle();
      expect(
        find.text(
          lookupAppLocalizations(const Locale('km')).onboardWelcomeTitle,
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('onboarding-language-en')));
      await tester.pumpAndSettle();
      tester.platformDispatcher.localeTestValue = const Locale('km', 'KH');
      await tester.pumpAndSettle();
      expect(find.text('Your day, a little lighter.'), findsOneWidget);
    },
  );

  testDriftWidgets(
    'preview uses the real parser, invalidates edits, and creates no task, reminder or capture draft',
    (tester) async {
      await pump(tester);
      await next(tester);
      await tester.enterText(
        find.byType(TextField),
        'Call Mom tomorrow at 9am',
      );
      await tester.pump();
      await tester.tap(find.text('Preview task'));
      await tester.pumpAndSettle();
      expect(find.text('Call Mom'), findsOneWidget);
      expect(find.textContaining('Tuesday, 6 October'), findsOneWidget);
      expect(find.textContaining('9:00'), findsOneWidget);
      expect(await db.select(db.taskRows).get(), isEmpty);
      expect(await db.select(db.reminderRows).get(), isEmpty);
      expect(await db.select(db.parseAuditRows).get(), isEmpty);
      expect(await CaptureDraftStore(db).read(), isNull);
      expect((await SettingsStore(db).read()).onboardingComplete, isFalse);
      await tester.enterText(find.byType(TextField), 'Buy milk');
      await tester.pumpAndSettle();
      expect(find.text('Call Mom'), findsNothing);
      await tester.pump();
      await tester.tap(find.text('Preview task'));
      await tester.pumpAndSettle();
      expect(
        find.text('No date yet. This would go to your Inbox.'),
        findsOneWidget,
      );
      await next(tester);
      await tester.runAsync(
        () async =>
            expect((await SettingsStore(db).read()).onboardingComplete, isTrue),
      );
      expect(await db.select(db.taskRows).get(), isEmpty);
    },
  );

  testDriftWidgets(
    'ambiguous times ask for clarification instead of showing an invented schedule',
    (tester) async {
      await pump(tester);
      await next(tester);
      await tester.enterText(find.byType(TextField), 'Call Mom tomorrow at 5');
      await tester.pump();
      await tester.tap(find.text('Preview task'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Try adding AM or PM'), findsOneWidget);
    },
  );

  testDriftWidgets('a late parse cannot replace edited input or its preview', (
    tester,
  ) async {
    final parser = _DeferredParser();
    await pump(tester, parser: parser);
    await next(tester);
    await tester.enterText(find.byType(TextField), 'Call Mom tomorrow at 9am');
    await tester.pump();
    await tester.tap(find.text('Preview task'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Buy milk');
    final result = await DeterministicTaskParser().parseTasks(
      TaskParseRequest(
        requestId: 'old',
        text: 'Call Mom tomorrow at 9am',
        referenceNow: _now,
        timezone: 'Asia/Phnom_Penh',
        locale: 'en',
      ),
    );
    parser.pending.complete(result);
    await tester.pumpAndSettle();
    expect(find.text('Call Mom'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Buy milk',
    );
    expect(find.text('Reading…'), findsNothing);
  });

  testDriftWidgets(
    'parse failure keeps input editable and lets the user skip',
    (tester) async {
      final parser = _DeferredParser();
      await pump(tester, parser: parser);
      await next(tester);
      await tester.enterText(find.byType(TextField), 'Buy milk');
      await tester.pump();
      await tester.tap(find.text('Preview task'));
      await tester.pump();
      parser.pending.completeError(StateError('Parser unavailable'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Couldn’t preview'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Buy milk',
      );
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect((await SettingsStore(db).read()).onboardingComplete, isTrue);
    },
  );

  testDriftWidgets(
    'completion write failure stays in onboarding with retry available',
    (tester) async {
      await pump(tester, settings: _FailingSettings(db));
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(
        find.text('Couldn’t finish setup. Please try again.'),
        findsOneWidget,
      );
      expect((await SettingsStore(db).read()).onboardingComplete, isFalse);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Skip'))
            .onPressed,
        isNotNull,
      );
    },
  );

  for (final (locale, dark, size, scale, keyboard, reduced) in [
    (const Locale('en'), false, const Size(390, 844), 1.0, 0.0, false),
    (const Locale('km'), false, const Size(390, 844), 1.0, 0.0, false),
    (const Locale('en'), true, const Size(390, 844), 1.0, 0.0, false),
    (const Locale('km'), true, const Size(390, 844), 1.0, 0.0, false),
    (const Locale('en'), false, const Size(320, 640), 2.0, 260.0, true),
    (const Locale('km'), true, const Size(320, 640), 2.0, 260.0, true),
  ]) {
    testDriftWidgets(
      'both steps fit ${locale.languageCode}, dark=$dark, scale=$scale, keyboard=$keyboard',
      (tester) async {
        final key = GlobalKey();
        await pump(
          tester,
          locale: locale,
          dark: dark,
          size: size,
          scale: scale,
          keyboard: keyboard,
          reduced: reduced,
          previewKey: key,
        );
        expect(tester.takeException(), isNull);
        final strings = lookupAppLocalizations(locale);
        if (scale == 1) {
          await preview(
            tester,
            key,
            '${locale.languageCode}-${dark ? 'dark' : 'light'}-onboarding-welcome',
          );
        }
        await next(tester);
        expect(tester.takeException(), isNull);
        expect(find.text(strings.skip), findsOneWidget);
        final example = find.text(strings.onboardUseExample);
        await tester.ensureVisible(example);
        await tester.pumpAndSettle();
        await tester.tap(example);
        await tester.pumpAndSettle();
        expect(find.text(strings.onboardUnderstood), findsOneWidget);
        final actionRect = tester.getRect(
          find.byKey(const ValueKey('onboarding-next')),
        );
        expect(actionRect.bottom, lessThanOrEqualTo(size.height - keyboard));
        expect(actionRect.height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
        if (scale == 1) {
          await preview(
            tester,
            key,
            '${locale.languageCode}-${dark ? 'dark' : 'light'}-onboarding-preview',
          );
        }
        await tester.tap(find.byTooltip(strings.onboardBack));
        await tester.pumpAndSettle();
        expect(find.text(strings.onboardWelcomeTitle), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
