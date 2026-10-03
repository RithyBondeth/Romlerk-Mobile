import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romlerk_mobile/application/providers.dart';
import 'package:romlerk_mobile/application/task_service.dart';
import 'package:romlerk_mobile/core/design/app_theme.dart';
import 'package:romlerk_mobile/data/local/app_database.dart';
import 'package:romlerk_mobile/data/repositories/drift_task_repository.dart';
import 'package:romlerk_mobile/domain/entities/note.dart';
import 'package:romlerk_mobile/domain/entities/reminder.dart';
import 'package:romlerk_mobile/domain/entities/recurrence_rule.dart';
import 'package:romlerk_mobile/domain/entities/task.dart';
import 'package:romlerk_mobile/domain/enums.dart';
import 'package:romlerk_mobile/domain/repositories/note_repository.dart';
import 'package:romlerk_mobile/features/notes/note_detail_page.dart';
import 'package:romlerk_mobile/features/task_detail/task_detail_page.dart';
import 'package:romlerk_mobile/l10n/app_localizations.dart';
import 'package:romlerk_mobile/services/notifications/reminder_scheduler.dart';
import '../support/drift_widget_harness.dart';

class Notes implements NoteRepository {
  Note? note = Note(
    id: 'note',
    title: 'Original',
    content: '',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  bool fail = false;
  @override
  Future<Note?> getNoteById(String id) async => note;
  @override
  Future<Note> saveNote(Note next) async {
    if (fail) throw StateError('Disk unavailable');
    return note = next;
  }

  @override
  Future<void> deleteNote(String id) async {
    note = null;
  }

  @override
  Stream<List<Note>> watchAllNotes({String? text}) => Stream.value([?note]);
}

class Scheduler extends ReminderScheduler {
  @override
  Future<void> cancel(int? id) async {}
}

void main() {
  late AppDatabase db;
  late DriftTaskRepository tasks;
  late Notes notes;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tasks = DriftTaskRepository(db);
    notes = Notes();
  });
  tearDown(() => db.close());
  Future<void> open(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          noteRepositoryProvider.overrideWithValue(notes),
          taskServiceProvider.overrideWithValue(
            TaskService(repository: tasks, scheduler: Scheduler()),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => page),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testDriftWidgets('note autosaves while focus stays in the field', (
    tester,
  ) async {
    await open(tester, const NoteDetailPage(noteId: 'note'));
    await tester.enterText(
      find.byKey(const ValueKey('note-title')),
      'New title',
    );
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(notes.note!.title, 'New title');
    expect(find.text('Saved'), findsOneWidget);
  });
  testDriftWidgets('back flushes edits before the debounce expires', (
    tester,
  ) async {
    await open(tester, const NoteDetailPage(noteId: 'note'));
    await tester.enterText(
      find.byKey(const ValueKey('note-content')),
      'Quick edit',
    );
    await tester.tap(find.byType(IconButton).first);
    await tester.pumpAndSettle();
    expect(notes.note!.content, 'Quick edit');
    expect(find.text('Open'), findsOneWidget);
    expect(find.byType(NoteDetailPage), findsNothing);
  });
  testDriftWidgets(
    'failed note writes retain edits and prevent leaving until retry succeeds',
    (tester) async {
      await open(tester, const NoteDetailPage(noteId: 'note'));
      notes.fail = true;
      await tester.enterText(
        find.byKey(const ValueKey('note-title')),
        'Keep this draft',
      );
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(NoteDetailPage), findsOneWidget);
      expect(notes.note!.title, 'Original');
      notes.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(notes.note!.title, 'Keep this draft');
    },
  );
  testDriftWidgets('backgrounding flushes pending note edits', (tester) async {
    await open(tester, const NoteDetailPage(noteId: 'note'));
    await tester.enterText(
      find.byKey(const ValueKey('note-title')),
      'Background draft',
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(notes.note!.title, 'Background draft');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
  testDriftWidgets(
    'task title autosaves without submitting and duration can be edited',
    (tester) async {
      final now = DateTime.now();
      await tasks.createTask(
        Task(
          id: 'task',
          title: 'Before',
          status: TaskStatus.active,
          priority: TaskPriority.none,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await open(tester, const TaskDetailPage(taskId: 'task'));
      await tester.enterText(find.byKey(const ValueKey('task-title')), 'After');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect((await tasks.findTask('task'))!.title, 'After');
      final takes = find.text('Takes');
      await tester.ensureVisible(takes);
      await tester.tap(takes);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        '45',
      );
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect((await tasks.findTask('task'))!.durationMinutes, 45);
      expect(tester.takeException(), isNull);
    },
  );
  testDriftWidgets(
    'metadata editors persist tags, recurrence, priority and date removal',
    (tester) async {
      final now = DateTime.now();
      await tasks.createTask(
        Task(
          id: 'task',
          title: 'Edit all fields',
          status: TaskStatus.active,
          priority: TaskPriority.none,
          createdAt: now,
          updatedAt: now,
          dueAt: DateTime(2035),
          reminder: Reminder(
            id: 'alarm',
            taskId: 'task',
            scheduledAt: DateTime(2035),
            timezone: 'UTC',
            state: ReminderState.scheduled,
            platformId: 3,
          ),
          recurrence: const RecurrenceRule(
            frequency: RecurrenceFrequency.daily,
          ),
        ),
      );
      await open(tester, const TaskDetailPage(taskId: 'task'));
      Future<void> row(String label) async {
        final finder = find.text(label);
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await row('Tags');
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Work, work, Home',
      );
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(
        (await tasks.findTask('task'))!.tags.map((t) => t.normalizedName),
        unorderedEquals(['work', 'home']),
      );
      await row('Repeats');
      await tester.enterText(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextField),
            )
            .first,
        '2',
      );
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect((await tasks.findTask('task'))!.recurrence!.interval, 2);
      await row('Repeats');
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect((await tasks.findTask('task'))!.recurrence, isNull);
      await row('Reminder');
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect((await tasks.findTask('task'))!.reminder, isNull);
      await row('Due');
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect((await tasks.findTask('task'))!.dueAt, isNull);
      await row('Priority');
      await tester.tap(find.text('High'));
      await tester.pumpAndSettle();
      expect((await tasks.findTask('task'))!.priority, TaskPriority.high);
      expect(tester.takeException(), isNull);
    },
  );
}
