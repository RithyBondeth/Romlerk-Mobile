import 'package:drift/drift.dart';

/// Canonical task row. Timestamps are stored as absolute UTC instants; the
/// timezone context needed to explain them lives on the reminder row.
@DataClassName('TaskRow')
class TaskRows extends Table {
  @override
  String get tableName => 'tasks';

  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 500)();
  TextColumn get notes => text().nullable()();
  TextColumn get status => text().withLength(max: 32)();
  TextColumn get priority => text().withLength(max: 32)();
  DateTimeColumn get startAt => dateTime().nullable()();
  DateTimeColumn get dueAt => dateTime().nullable()();
  IntColumn get durationMinutes => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get occurrenceIndex => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ReminderRow')
class ReminderRows extends Table {
  @override
  String get tableName => 'reminders';

  TextColumn get id => text()();
  TextColumn get taskId =>
      text().references(TaskRows, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get scheduledAt => dateTime()();
  TextColumn get timezone => text().withLength(max: 64)();
  TextColumn get state => text().withLength(max: 32)();

  /// Handle the OS notification scheduler knows this reminder by.
  IntColumn get platformId => integer().nullable()();
  TextColumn get failureCode => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('RecurrenceRow')
class RecurrenceRows extends Table {
  @override
  String get tableName => 'recurrence_rules';

  TextColumn get id => text()();
  TextColumn get taskId =>
      text().references(TaskRows, #id, onDelete: KeyAction.cascade)();
  TextColumn get frequency => text().withLength(max: 32)();
  IntColumn get interval => integer().withDefault(const Constant(1))();

  /// Comma-separated ISO weekday numbers, empty when not a weekly rule.
  TextColumn get byWeekday => text().withDefault(const Constant(''))();
  DateTimeColumn get until => dateTime().nullable()();
  IntColumn get count => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TagRow')
class TagRows extends Table {
  @override
  String get tableName => 'tags';

  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 60)();

  /// Lowercased, whitespace-collapsed name. Unique, so tags never duplicate on
  /// case alone.
  TextColumn get normalizedName => text().withLength(min: 1, max: 60).unique()();
  IntColumn get colorValue => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TaskTagRow')
class TaskTagRows extends Table {
  @override
  String get tableName => 'task_tags';

  TextColumn get taskId =>
      text().references(TaskRows, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId =>
      text().references(TagRows, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => {taskId, tagId};
}

/// Simple key/value store for user preferences.
///
/// Kept in the app database rather than platform preferences so that "erase
/// all data" (FR-25) genuinely clears everything from one place, and so no
/// setting ever ends up in an OS store the user cannot inspect.
@DataClassName('SettingRow')
class SettingRows extends Table {
  @override
  String get tableName => 'settings';

  TextColumn get key => text().withLength(max: 64)();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Local, content-free record of parse attempts (BRD section 15).
///
/// Deliberately has no column that could hold user text: only outcome shape,
/// a coarse latency bucket, and version metadata. Capped and purgeable.
@DataClassName('ParseAuditRow')
class ParseAuditRows extends Table {
  @override
  String get tableName => 'ai_parse_audit';

  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get occurredAt => dateTime()();
  IntColumn get schemaVersion => integer()();
  TextColumn get provider => text().withLength(max: 48)();
  TextColumn get capabilityTier => text().withLength(max: 8)();

  /// Bucketed, not exact: "<1s", "1-3s", "3-7s", ">7s".
  TextColumn get latencyBucket => text().withLength(max: 16)();
  TextColumn get outcome => text().withLength(max: 32)();
  IntColumn get draftCount => integer().withDefault(const Constant(0))();
  TextColumn get errorCode => text().nullable()();
}
