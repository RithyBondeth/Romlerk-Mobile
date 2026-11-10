import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romlerk_mobile/application/providers.dart';
import 'package:romlerk_mobile/core/design/app_theme.dart';
import 'package:romlerk_mobile/core/design/design_tokens.dart';
import 'package:romlerk_mobile/data/local/app_database.dart';
import 'package:romlerk_mobile/data/local/settings_store.dart';
import 'package:romlerk_mobile/data/repositories/drift_note_repository.dart';
import 'package:romlerk_mobile/data/repositories/drift_task_repository.dart';
import 'package:romlerk_mobile/domain/entities/note.dart';
import 'package:romlerk_mobile/domain/entities/task.dart';
import 'package:romlerk_mobile/domain/enums.dart';
import 'package:romlerk_mobile/features/onboarding/onboarding_page.dart';
import 'package:romlerk_mobile/features/settings/settings_page.dart';
import 'package:romlerk_mobile/features/task_detail/task_detail_page.dart';
import 'package:romlerk_mobile/features/notes/note_detail_page.dart';
import 'package:romlerk_mobile/features/capture/capture_sheet.dart';
import 'package:romlerk_mobile/features/today/daily_planning_sheet.dart';
import 'package:romlerk_mobile/features/shell/home_shell.dart';
import 'package:romlerk_mobile/features/shell/floating_navigation_bar.dart';
import 'package:romlerk_mobile/l10n/app_localizations.dart';
import 'package:romlerk_mobile/services/voice/voice_capture_service.dart';
import 'package:romlerk_mobile/local_ai/capabilities.dart';

import '../support/drift_widget_harness.dart';
import 'capture_voice_test.dart' show FakeVoiceCaptureService;
import 'system_capture_test.dart' show Scheduler;

const _writePreviews = bool.fromEnvironment('ROMLERK_WRITE_PREVIEWS');
final _previewKey = GlobalKey();
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

  Future<void> seed({bool khmer = false}) async {
    final tasks = DriftTaskRepository(db);
    for (final (id, title, due, priority) in [
      (
        'late',
        khmer ? 'បង់ថ្លៃអ៊ីនធឺណិត' : 'Pay the internet bill',
        DateTime(2026, 10, 4, 17),
        TaskPriority.high,
      ),
      (
        'today',
        khmer
            ? 'ពិនិត្យគម្រោងថ្មីជាមួយ ដារ៉ា'
            : 'Review the new concept with Dara',
        DateTime(2026, 10, 5, 10),
        TaskPriority.medium,
      ),
      (
        'today2',
        khmer
            ? 'ទិញគ្រឿងទេសសម្រាប់អាហារពេលល្ងាច'
            : 'Pick up groceries for dinner',
        DateTime(2026, 10, 5, 17, 30),
        TaskPriority.none,
      ),
      (
        'future',
        khmer ? 'ជួបក្រុមការងារ' : 'Meet the design team',
        DateTime(2026, 10, 6, 9),
        TaskPriority.medium,
      ),
      (
        'future2',
        khmer
            ? 'រៀបចំផែនការសម្រាប់សប្តាហ៍ក្រោយ'
            : 'Plan next week’s priorities',
        DateTime(2026, 10, 8, 14),
        TaskPriority.none,
      ),
      (
        'inbox',
        khmer ? 'អានសៀវភៅថ្មី' : 'Read the book Sovann recommended',
        null,
        TaskPriority.none,
      ),
    ]) {
      await tasks.createTask(
        Task(
          id: id,
          title: title,
          dueAt: due,
          status: TaskStatus.active,
          priority: priority,
          durationMinutes: 25,
          createdAt: _now,
          updatedAt: _now,
        ),
      );
    }
    final notes = DriftNoteRepository(db);
    await notes.saveNote(
      Note(
        id: 'note',
        title: khmer ? 'គំនិតសម្រាប់ចុងសប្តាហ៍' : 'A slower weekend',
        content: khmer
            ? 'ផឹកកាហ្វេពេលព្រឹក អានសៀវភៅ និងចំណាយពេលជាមួយគ្រួសារ។'
            : 'Coffee by the river, a few chapters of a good book, and time with family. Keep Saturday open.',
        createdAt: _now,
        updatedAt: _now,
      ),
    );
    await notes.saveNote(
      Note(
        id: 'note2',
        title: 'Romlerk · គំនិតថ្មី',
        content: 'Make a little room for what matters. កត់ត្រាគំនិតសំខាន់ៗ។',
        createdAt: _now,
        updatedAt: _now,
      ),
    );
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    required Locale locale,
    required Size size,
    bool dark = false,
    double scale = 1,
    bool reduced = false,
    double keyboard = 0,
    double bottomInset = 0,
    Widget home = const HomeShell(),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWithValue(locale),
          clockProvider.overrideWithValue(() => _now),
          reminderSchedulerProvider.overrideWithValue(Scheduler()),
          capabilitiesProvider.overrideWith(
            (ref) async => const LocalAiCapabilities.deterministicOnly(),
          ),
          voiceCaptureServiceProvider.overrideWithValue(
            FakeVoiceCaptureService(
              availabilityValue: VoiceAvailability.unsupported,
            ),
          ),
        ],
        child: RepaintBoundary(
          key: _previewKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: reduced,
                viewInsets: EdgeInsets.only(bottom: keyboard),
                padding: EdgeInsets.only(bottom: bottomInset),
                viewPadding: EdgeInsets.only(bottom: bottomInset),
              ),
              child: child!,
            ),
            home: home,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> preview(WidgetTester tester, String name) async {
    if (!_writePreviews) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_previewKey),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('docs/ui-previews/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final (locale, size, dark, scale, reduced) in [
    (const Locale('en'), const Size(390, 844), false, 1.0, false),
    (const Locale('en'), const Size(390, 844), true, 1.0, false),
    (const Locale('km'), const Size(390, 844), false, 1.0, false),
    (const Locale('km'), const Size(390, 844), true, 1.0, false),
    (const Locale('en'), const Size(320, 640), false, 2.0, true),
    (const Locale('km'), const Size(320, 640), true, 2.0, true),
    (const Locale('en'), const Size(768, 1024), false, 1.0, false),
  ]) {
    testDriftWidgets(
      'all tabs fit ${locale.languageCode}, $size, dark=$dark, scale=$scale, reduced=$reduced',
      (tester) async {
        await seed(khmer: locale.languageCode == 'km');
        await pumpApp(
          tester,
          locale: locale,
          size: size,
          dark: dark,
          scale: scale,
          reduced: reduced,
        );
        final strings = lookupAppLocalizations(locale);
        final labels = [
          strings.today,
          strings.upcoming,
          strings.inbox,
          strings.notes,
          strings.search,
        ];
        for (var i = 0; i < labels.length; i++) {
          await tester.tap(find.byType(FloatingNavigationItem).at(i));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: labels[i]);
          final visibleLabels = find.descendant(
            of: find.byType(FloatingNavigationBar),
            matching: find.byType(Text),
          );
          expect(visibleLabels, findsOneWidget);
          expect(tester.widget<Text>(visibleLabels).data, labels[i]);
          final selected = find.byType(FloatingNavigationItem).at(i);
          final icon = find.descendant(
            of: selected,
            matching: find.byType(Icon),
          );
          expect(
            tester.getCenter(icon).dy,
            closeTo(tester.getCenter(visibleLabels).dy, 1.5),
          );
          for (var j = 0; j < labels.length; j++) {
            final item = find.byType(FloatingNavigationItem).at(j);
            expect(tester.getRect(item).width, greaterThanOrEqualTo(47.99));
            expect(tester.getRect(item).height, greaterThanOrEqualTo(48));
            expect(tester.getSemantics(item).label, labels[j]);
          }
          if (size.width == 390) {
            await preview(
              tester,
              '${locale.languageCode}-${dark ? 'dark' : 'light'}-${['today', 'upcoming', 'inbox', 'notes', 'search'][i]}',
            );
          }
        }
      },
    );
  }

  testDriftWidgets('floating dock clears screen edges and the home indicator', (
    tester,
  ) async {
    await seed();
    await pumpApp(
      tester,
      locale: const Locale('en'),
      size: const Size(390, 844),
      bottomInset: 34,
    );
    final dock = tester.getRect(
      find.byKey(const ValueKey('floating-navigation-surface')),
    );
    expect(dock.left, greaterThanOrEqualTo(16));
    expect(390 - dock.right, greaterThanOrEqualTo(16));
    expect(844 - dock.bottom, greaterThanOrEqualTo(34));

    // The final row can still scroll above the controls.
    final list = find
        .descendant(
          of: find.byType(HomeShell),
          matching: find.byType(CustomScrollView),
        )
        .first;
    await tester.drag(list, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.text('Pick up groceries for dinner')).bottom,
      lessThan(dock.top),
    );
    expect(tester.takeException(), isNull);
  });

  testDriftWidgets('selection glides and retargets during a rapid tab change', (
    tester,
  ) async {
    await seed();
    await pumpApp(
      tester,
      locale: const Locale('en'),
      size: const Size(390, 844),
    );
    final indicator = find.byKey(
      const ValueKey('floating-navigation-indicator'),
    );
    final tabs = find.byType(FloatingNavigationItem);
    final start = tester.getCenter(indicator).dx;
    final target = tester.getCenter(tabs.at(4)).dx;
    await tester.tap(tabs.at(4));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final moving = tester.getCenter(indicator).dx;
    expect(moving, greaterThan(start));
    expect(moving, lessThan(target));

    await tester.tap(tabs.at(1));
    await tester.pumpAndSettle();
    expect(
      tester.getCenter(indicator).dx,
      closeTo(tester.getCenter(tabs.at(1)).dx, 0.5),
    );
    expect(
      tester
          .widget<FloatingNavigationBar>(find.byType(FloatingNavigationBar))
          .selectedIndex,
      1,
    );
    expect(
      tester.getSemantics(tabs.at(1)).flagsCollection.isSelected,
      ui.Tristate.isTrue,
    );
    await tester.tap(find.text('Capture a new task'));
    await tester.pumpAndSettle();
    expect(find.byType(CaptureSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testDriftWidgets('tabs respond to a held press and release', (tester) async {
    await seed();
    await pumpApp(
      tester,
      locale: const Locale('en'),
      size: const Size(390, 844),
    );
    final tab = find.byType(FloatingNavigationItem).at(2);
    final control = find.descendant(of: tab, matching: find.byType(InkWell));
    final resting = tester.getRect(control).width;
    final press = await tester.startGesture(tester.getCenter(tab));
    await tester.pump();
    await tester.pump(Motion.micro);
    expect(tester.getRect(control).width, lessThan(resting));
    await press.up();
    await tester.pumpAndSettle();
    expect(tester.getRect(tab).width, greaterThan(resting));
    expect(
      tester
          .widget<FloatingNavigationBar>(find.byType(FloatingNavigationBar))
          .selectedIndex,
      2,
    );
    expect(tester.takeException(), isNull);
  });

  testDriftWidgets('icon-only destinations keep keyboard and spoken labels', (
    tester,
  ) async {
    await seed();
    await pumpApp(
      tester,
      locale: const Locale('en'),
      size: const Size(390, 844),
    );
    final tab = find.byType(FloatingNavigationItem).at(1);
    final content = find.descendant(of: tab, matching: find.byType(Row));
    Focus.of(tester.element(content)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FloatingNavigationBar>(find.byType(FloatingNavigationBar))
          .selectedIndex,
      1,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FloatingNavigationBar>(find.byType(FloatingNavigationBar))
          .selectedIndex,
      2,
    );
    final spoken = tester.getSemantics(
      find.byType(FloatingNavigationItem).at(2),
    );
    expect(spoken.label, 'Inbox');
    expect(spoken.flagsCollection.isSelected, ui.Tristate.isTrue);
    expect(spoken.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
    expect(tester.takeException(), isNull);
  });

  testDriftWidgets('reduced motion moves the selection without travel', (
    tester,
  ) async {
    await seed();
    await pumpApp(
      tester,
      locale: const Locale('km'),
      size: const Size(320, 640),
      reduced: true,
      scale: 2,
    );
    final tab = find.byType(FloatingNavigationItem).at(4);
    await tester.tap(tab);
    await tester.pump();
    final indicator = find.byKey(
      const ValueKey('floating-navigation-indicator'),
    );
    expect(
      tester.getCenter(indicator).dx,
      closeTo(tester.getCenter(tab).dx, 0.5),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testDriftWidgets('upcoming date filters and All restore the full schedule', (
    tester,
  ) async {
    await seed();
    await pumpApp(
      tester,
      locale: const Locale('en'),
      size: const Size(390, 844),
    );
    await tester.tap(find.byType(FloatingNavigationItem).at(1));
    await tester.pumpAndSettle();
    final chips = find.byType(ChoiceChip);
    await tester.tap(chips.at(1));
    await tester.pumpAndSettle();
    expect(find.text('Meet the design team'), findsOneWidget);
    expect(find.text('Plan next week’s priorities'), findsNothing);
    await tester.tap(chips.first);
    await tester.pumpAndSettle();
    expect(find.text('Plan next week’s priorities'), findsOneWidget);
  });

  testDriftWidgets('onboarding stays readable at 200 percent Khmer text', (
    tester,
  ) async {
    await pumpApp(
      tester,
      locale: const Locale('km'),
      size: const Size(320, 640),
      scale: 2,
      reduced: true,
      home: const OnboardingPage(),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(
      find.text(lookupAppLocalizations(const Locale('km')).next),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testDriftWidgets('settings, capture, and editors render with bundled fonts', (
    tester,
  ) async {
    await seed();
    await SettingsStore(db).write(const AppSettings(onboardingComplete: true));
    await pumpApp(
      tester,
      locale: const Locale('en'),
      size: const Size(390, 844),
    );
    await tester.tap(find.byTooltip('Settings').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await preview(tester, 'en-light-settings');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review the new concept with Dara'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await preview(tester, 'en-light-task-detail');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingNavigationItem).at(3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A slower weekend'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await preview(tester, 'en-light-note-detail');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Capture a new task'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await preview(tester, 'en-light-capture');
  });
  testDriftWidgets('secondary screens fit large Khmer text and a keyboard', (
    tester,
  ) async {
    await seed(khmer: true);
    for (final home in <Widget>[
      const SettingsPage(),
      const TaskDetailPage(taskId: 'today'),
      const NoteDetailPage(noteId: 'note'),
      const DailyPlanningSheet(tasks: []),
      const Scaffold(body: CaptureSheet()),
    ]) {
      await pumpApp(
        tester,
        locale: const Locale('km'),
        size: const Size(320, 640),
        dark: true,
        scale: 2,
        reduced: true,
        home: home,
        keyboard: home is Scaffold ? 240 : 0,
      );
      expect(
        tester.takeException(),
        isNull,
        reason: home.runtimeType.toString(),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    }
  });
}
