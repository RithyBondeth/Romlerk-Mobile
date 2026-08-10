import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/recurrence_rule.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/entities/tag.dart';
import '../../domain/entities/task.dart';
import '../../domain/enums.dart';
import '../../domain/repositories/task_repository.dart';
import '../local/app_database.dart';

/// Drift-backed [TaskRepository].
///
/// Filtering happens in SQL; ordering happens in Dart because the sort key
/// mixes a coalesced date with an enum rank, and a single readable comparator
/// is easier to keep deterministic (and unit-testable) than the SQL equivalent.
class DriftTaskRepository implements TaskRepository {
  DriftTaskRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  /// Palette used when a tag is created implicitly during capture.
  static const List<int> _tagPalette = <int>[
    0xFF4F7CFF,
    0xFF16A34A,
    0xFFEA580C,
    0xFF9333EA,
    0xFF0891B2,
    0xFFDB2777,
  ];

  // ---------------------------------------------------------------- reading

  @override
  Stream<List<Task>> watchTasks(TaskQuery query) async* {
    yield await fetchTasks(query);
    // Any of these tables can change what a hydrated task looks like, so all
    // of them retrigger the query.
    await for (final _ in _db.tableUpdates(
      TableUpdateQuery.onAllTables(<ResultSetImplementation<dynamic, dynamic>>[
        _db.taskRows,
        _db.reminderRows,
        _db.recurrenceRows,
        _db.tagRows,
        _db.taskTagRows,
      ]),
    )) {
      yield await fetchTasks(query);
    }
  }

  @override
  Stream<Task?> watchTask(String id) async* {
    yield await findTask(id);
    await for (final _ in _db.tableUpdates(
      TableUpdateQuery.onAllTables(<ResultSetImplementation<dynamic, dynamic>>[
        _db.taskRows,
        _db.reminderRows,
        _db.recurrenceRows,
        _db.tagRows,
        _db.taskTagRows,
      ]),
    )) {
      yield await findTask(id);
    }
  }

  @override
  Future<List<Task>> fetchTasks(TaskQuery query) async {
    final select = _db.select(_db.taskRows);

    if (query.statuses.isNotEmpty) {
      final wires = query.statuses.map((status) => status.wire).toList();
      select.where((row) => row.status.isIn(wires));
    }
    if (query.priorities.isNotEmpty) {
      final wires = query.priorities.map((priority) => priority.wire).toList();
      select.where((row) => row.priority.isIn(wires));
    }
    if (query.onlyUnscheduled) {
      select.where((row) => row.dueAt.isNull() & row.startAt.isNull());
    }
    if (query.dueAfter != null) {
      final after = query.dueAfter!;
      select.where(
        (row) =>
            row.dueAt.isBiggerOrEqualValue(after) |
            (row.dueAt.isNull() & row.startAt.isBiggerOrEqualValue(after)),
      );
    }
    if (query.dueBefore != null) {
      final before = query.dueBefore!;
      select.where(
        (row) =>
            row.dueAt.isSmallerThanValue(before) |
            (row.dueAt.isNull() & row.startAt.isSmallerThanValue(before)),
      );
    }
    final text = query.text?.trim();
    if (text != null && text.isNotEmpty) {
      final pattern = '%${_escapeLike(text)}%';
      select.where(
        (row) =>
            row.title.like(pattern) |
            row.notes.like(pattern).equals(true),
      );
    }
    if (query.tagIds.isNotEmpty) {
      final tagged = _db.selectOnly(_db.taskTagRows)
        ..addColumns(<Expression<Object>>[_db.taskTagRows.taskId])
        ..where(_db.taskTagRows.tagId.isIn(query.tagIds.toList()));
      select.where(
        (row) => row.id.isInQuery(tagged),
      );
    }

    final rows = await select.get();
    final tasks = await _hydrate(rows);
    return _sorted(tasks);
  }

  @override
  Future<Task?> findTask(String id) async {
    final row = await (_db.select(
      _db.taskRows,
    )..where((task) => task.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    final hydrated = await _hydrate(<TaskRow>[row]);
    return hydrated.first;
  }

  @override
  Future<int> countTasks() async {
    final count = _db.taskRows.id.count();
    final row = await (_db.selectOnly(_db.taskRows)
          ..addColumns(<Expression<Object>>[count]))
        .getSingle();
    return row.read(count) ?? 0;
  }

  @override
  Future<List<Task>> tasksWithPendingReminders() async {
    final reminderRows =
        await (_db.select(_db.reminderRows)..where(
              (reminder) => reminder.state.isIn(<String>[
                ReminderState.pending.wire,
                ReminderState.scheduled.wire,
              ]),
            ))
            .get();
    if (reminderRows.isEmpty) return const <Task>[];
    final taskIds = reminderRows.map((row) => row.taskId).toSet().toList();
    final rows = await (_db.select(
      _db.taskRows,
    )..where((task) => task.id.isIn(taskIds))).get();
    return _hydrate(rows);
  }

  // ---------------------------------------------------------------- writing

  @override
  Future<Task> createTask(Task task) async {
    await _db.transaction(() async {
      await _db.into(_db.taskRows).insert(_taskCompanion(task));
      await _writeRelations(task);
    });
    return (await findTask(task.id))!;
  }

  @override
  Future<Task> updateTask(Task task) async {
    await _db.transaction(() async {
      await (_db.update(
        _db.taskRows,
      )..where((row) => row.id.equals(task.id))).write(_taskCompanion(task));
      await _clearRelations(task.id);
      await _writeRelations(task);
    });
    return (await findTask(task.id))!;
  }

  @override
  Future<void> deleteTask(String id) async {
    await _db.transaction(() async {
      await _clearRelations(id);
      await (_db.delete(_db.taskRows)..where((row) => row.id.equals(id))).go();
    });
  }

  @override
  Future<Task> completeTask(String id, {required DateTime now}) async {
    final task = await findTask(id);
    if (task == null) {
      throw StateError('Cannot complete missing task $id');
    }

    final rule = task.recurrence;
    final anchor = task.effectiveDate;

    // A recurring task with a date rolls forward instead of closing, so the
    // series stays a single row with a single reminder.
    if (rule != null && anchor != null) {
      final next = rule.nextOccurrenceAfter(
        anchor,
        occurrencesSoFar: task.occurrenceIndex + 1,
      );
      if (next != null) {
        final shift = next.difference(anchor);
        return updateTask(
          task.copyWith(
            dueAt: task.dueAt == null ? null : next,
            startAt: task.startAt?.add(shift),
            occurrenceIndex: task.occurrenceIndex + 1,
            updatedAt: now,
            // Re-arm: the scheduler picks this up and books the new time.
            reminder: task.reminder?.copyWith(
              scheduledAt: task.reminder!.scheduledAt.add(shift),
              state: ReminderState.pending,
              clearPlatformId: true,
              clearFailureCode: true,
            ),
          ),
        );
      }
    }

    return updateTask(
      task.copyWith(
        status: TaskStatus.completed,
        completedAt: now,
        updatedAt: now,
        reminder: task.reminder?.copyWith(
          state: ReminderState.cancelled,
          clearPlatformId: true,
        ),
      ),
    );
  }

  @override
  Future<Task> reopenTask(String id) async {
    final task = await findTask(id);
    if (task == null) {
      throw StateError('Cannot reopen missing task $id');
    }
    return updateTask(
      task.copyWith(
        status: TaskStatus.active,
        clearCompletedAt: true,
        updatedAt: DateTime.now(),
      ),
    );
  }

  // ------------------------------------------------------------------- tags

  @override
  Stream<List<Tag>> watchTags() {
    return (_db.select(_db.tagRows)
          ..orderBy(<OrderClauseGenerator<$TagRowsTable>>[
            (row) => OrderingTerm.asc(row.normalizedName),
          ]))
        .watch()
        .map((rows) => rows.map(_toTag).toList());
  }

  @override
  Future<List<Tag>> fetchTags() async {
    final rows =
        await (_db.select(_db.tagRows)
              ..orderBy(<OrderClauseGenerator<$TagRowsTable>>[
                (row) => OrderingTerm.asc(row.normalizedName),
              ]))
            .get();
    return rows.map(_toTag).toList();
  }

  @override
  Future<Tag> ensureTag(String name) async {
    final normalized = Tag.normalize(name);
    if (normalized.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Tag name cannot be empty');
    }
    final existing = await (_db.select(
      _db.tagRows,
    )..where((row) => row.normalizedName.equals(normalized))).getSingleOrNull();
    if (existing != null) return _toTag(existing);

    final tag = Tag(
      id: _uuid.v4(),
      name: name.trim(),
      colorValue: _tagPalette[normalized.hashCode.abs() % _tagPalette.length],
      createdAt: DateTime.now(),
    );
    await _db
        .into(_db.tagRows)
        .insert(
          TagRowsCompanion.insert(
            id: tag.id,
            name: tag.name,
            normalizedName: normalized,
            colorValue: tag.colorValue,
            createdAt: tag.createdAt,
          ),
        );
    return tag;
  }

  @override
  Future<void> deleteTag(String id) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.taskTagRows,
      )..where((row) => row.tagId.equals(id))).go();
      await (_db.delete(_db.tagRows)..where((row) => row.id.equals(id))).go();
    });
  }

  @override
  Future<void> eraseAllData() async {
    await _db.transaction(() async {
      await _db.delete(_db.taskTagRows).go();
      await _db.delete(_db.reminderRows).go();
      await _db.delete(_db.recurrenceRows).go();
      await _db.delete(_db.tagRows).go();
      await _db.delete(_db.taskRows).go();
      await _db.delete(_db.parseAuditRows).go();
    });
  }

  // --------------------------------------------------------------- internals

  Future<void> _writeRelations(Task task) async {
    final reminder = task.reminder;
    if (reminder != null) {
      await _db
          .into(_db.reminderRows)
          .insert(
            ReminderRowsCompanion.insert(
              id: reminder.id,
              taskId: task.id,
              scheduledAt: reminder.scheduledAt,
              timezone: reminder.timezone,
              state: reminder.state.wire,
              platformId: Value<int?>(reminder.platformId),
              failureCode: Value<String?>(reminder.failureCode),
            ),
          );
    }

    final recurrence = task.recurrence;
    if (recurrence != null) {
      await _db
          .into(_db.recurrenceRows)
          .insert(
            RecurrenceRowsCompanion.insert(
              id: _uuid.v4(),
              taskId: task.id,
              frequency: recurrence.frequency.wire,
              interval: Value<int>(recurrence.interval),
              byWeekday: Value<String>(recurrence.byWeekday.join(',')),
              until: Value<DateTime?>(recurrence.until),
              count: Value<int?>(recurrence.count),
            ),
          );
    }

    for (final tag in task.tags) {
      await _db
          .into(_db.taskTagRows)
          .insert(
            TaskTagRowsCompanion.insert(taskId: task.id, tagId: tag.id),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }

  Future<void> _clearRelations(String taskId) async {
    await (_db.delete(
      _db.reminderRows,
    )..where((row) => row.taskId.equals(taskId))).go();
    await (_db.delete(
      _db.recurrenceRows,
    )..where((row) => row.taskId.equals(taskId))).go();
    await (_db.delete(
      _db.taskTagRows,
    )..where((row) => row.taskId.equals(taskId))).go();
  }

  /// Loads reminders, recurrence, and tags for [rows] in three batched queries
  /// rather than per row.
  Future<List<Task>> _hydrate(List<TaskRow> rows) async {
    if (rows.isEmpty) return const <Task>[];
    final ids = rows.map((row) => row.id).toList();

    final reminders = await (_db.select(
      _db.reminderRows,
    )..where((row) => row.taskId.isIn(ids))).get();
    final recurrences = await (_db.select(
      _db.recurrenceRows,
    )..where((row) => row.taskId.isIn(ids))).get();

    final links = await (_db.select(
      _db.taskTagRows,
    )..where((row) => row.taskId.isIn(ids))).get();
    final tagIds = links.map((link) => link.tagId).toSet().toList();
    final tagRows = tagIds.isEmpty
        ? const <TagRow>[]
        : await (_db.select(
            _db.tagRows,
          )..where((row) => row.id.isIn(tagIds))).get();
    final tagsById = <String, Tag>{
      for (final row in tagRows) row.id: _toTag(row),
    };

    final remindersByTask = <String, ReminderRow>{
      for (final row in reminders) row.taskId: row,
    };
    final recurrenceByTask = <String, RecurrenceRow>{
      for (final row in recurrences) row.taskId: row,
    };
    final tagsByTask = <String, List<Tag>>{};
    for (final link in links) {
      final tag = tagsById[link.tagId];
      if (tag == null) continue;
      tagsByTask.putIfAbsent(link.taskId, () => <Tag>[]).add(tag);
    }

    return rows
        .map(
          (row) => _toTask(
            row,
            reminder: remindersByTask[row.id],
            recurrence: recurrenceByTask[row.id],
            tags: tagsByTask[row.id] ?? const <Tag>[],
          ),
        )
        .toList();
  }

  /// Stable list order (US-09): dated tasks before undated, earliest first,
  /// then higher priority, then oldest created. Completed tasks sort by most
  /// recently completed instead.
  static List<Task> _sorted(List<Task> tasks) {
    final sorted = List<Task>.of(tasks);
    sorted.sort((a, b) {
      if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
      if (a.isCompleted && b.isCompleted) {
        final completedA = a.completedAt ?? a.updatedAt;
        final completedB = b.completedAt ?? b.updatedAt;
        return completedB.compareTo(completedA);
      }

      final dateA = a.effectiveDate;
      final dateB = b.effectiveDate;
      if (dateA != null && dateB != null && dateA != dateB) {
        return dateA.compareTo(dateB);
      }
      if (dateA != null && dateB == null) return -1;
      if (dateA == null && dateB != null) return 1;

      if (a.priority.rank != b.priority.rank) {
        return b.priority.rank.compareTo(a.priority.rank);
      }
      final byCreated = a.createdAt.compareTo(b.createdAt);
      if (byCreated != 0) return byCreated;
      // Final tiebreak keeps the order identical between identical runs.
      return a.id.compareTo(b.id);
    });
    return sorted;
  }

  TaskRowsCompanion _taskCompanion(Task task) => TaskRowsCompanion.insert(
    id: task.id,
    title: task.title,
    notes: Value<String?>(task.notes),
    status: task.status.wire,
    priority: task.priority.wire,
    startAt: Value<DateTime?>(task.startAt),
    dueAt: Value<DateTime?>(task.dueAt),
    durationMinutes: Value<int?>(task.durationMinutes),
    createdAt: task.createdAt,
    updatedAt: task.updatedAt,
    completedAt: Value<DateTime?>(task.completedAt),
    occurrenceIndex: Value<int>(task.occurrenceIndex),
  );

  static Tag _toTag(TagRow row) => Tag(
    id: row.id,
    name: row.name,
    colorValue: row.colorValue,
    createdAt: row.createdAt,
  );

  static Task _toTask(
    TaskRow row, {
    ReminderRow? reminder,
    RecurrenceRow? recurrence,
    List<Tag> tags = const <Tag>[],
  }) {
    return Task(
      id: row.id,
      title: row.title,
      notes: row.notes,
      status: TaskStatus.fromWire(row.status),
      priority: TaskPriority.fromWire(row.priority),
      startAt: row.startAt,
      dueAt: row.dueAt,
      durationMinutes: row.durationMinutes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      completedAt: row.completedAt,
      occurrenceIndex: row.occurrenceIndex,
      tags: tags,
      reminder: reminder == null
          ? null
          : Reminder(
              id: reminder.id,
              taskId: reminder.taskId,
              scheduledAt: reminder.scheduledAt,
              timezone: reminder.timezone,
              state: ReminderState.fromWire(reminder.state),
              platformId: reminder.platformId,
              failureCode: reminder.failureCode,
            ),
      recurrence: recurrence == null
          ? null
          : RecurrenceRule(
              frequency: RecurrenceFrequency.fromWire(recurrence.frequency),
              interval: recurrence.interval,
              byWeekday: recurrence.byWeekday.isEmpty
                  ? const <int>[]
                  : recurrence.byWeekday
                        .split(',')
                        .map(int.parse)
                        .toList(),
              until: recurrence.until,
              count: recurrence.count,
            ),
    );
  }

  static String _escapeLike(String value) =>
      value.replaceAll('%', r'\%').replaceAll('_', r'\_');
}
