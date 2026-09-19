import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'database_storage.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// Local SQLite store. The canonical task database for the MVP — there is no
/// server copy, so recovery behaviour matters more than usual (NFR-19).
@DriftDatabase(
  tables: [
    TaskRows,
    ReminderRows,
    RecurrenceRows,
    TagRows,
    TaskTagRows,
    SettingRows,
    ParseAuditRows,
    NoteRows,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// A second connection from the notification-action isolate, which runs
  /// beside the app rather than instead of it. It never moves the file (see
  /// [DatabaseStorage.currentDatabaseFile]).
  AppDatabase.forActionIsolate() : super(_openExistingConnection());

  /// Test constructor: pass `NativeDatabase.memory()`.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _createIndexes();
    },
    // Forward-only migrations. Each future step is added here and covered by a
    // migration test before shipping.
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(noteRows);
      }
      await _createIndexes();
    },
    beforeOpen: (details) async {
      // Required for the ON DELETE CASCADE declarations to actually fire.
      await customStatement('PRAGMA foreign_keys = ON');
      await _pruneParseAudit();
    },
  );

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tasks_due_at ON tasks (due_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks (status)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_reminders_task ON reminders (task_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_recurrence_task '
      'ON recurrence_rules (task_id)',
    );
  }

  /// Keeps the content-free audit log bounded (NFR-14).
  static const int maxAuditRows = 200;

  Future<void> _pruneParseAudit() async {
    await customStatement('''
      DELETE FROM ai_parse_audit
      WHERE id NOT IN (
        SELECT id FROM ai_parse_audit ORDER BY id DESC LIMIT $maxAuditRows
      )
    ''');
  }

  Future<void> pruneParseAudit() => _pruneParseAudit();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // Resolved here, before the file is opened, because honouring the backup
    // choice may mean moving it.
    final file = await const DatabaseStorage().resolveDatabaseFile();
    return NativeDatabase.createInBackground(file, setup: (db) => db.execute(_busyTimeout));
  });
}

LazyDatabase _openExistingConnection() {
  return LazyDatabase(() async {
    final file = await const DatabaseStorage().currentDatabaseFile();
    return NativeDatabase(file, setup: (db) => db.execute(_busyTimeout));
  });
}

/// The app and the notification-action isolate can hold the file open at
/// the same time. Waiting briefly for the other's write lock beats failing
/// with SQLITE_BUSY, which would drop a Complete tap on the floor.
const String _busyTimeout = 'PRAGMA busy_timeout = 5000;';
