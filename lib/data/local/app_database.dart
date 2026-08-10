import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Test constructor: pass `NativeDatabase.memory()`.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _createIndexes();
    },
    // Forward-only migrations. Each future step is added here and covered by a
    // migration test before shipping.
    onUpgrade: (Migrator m, int from, int to) async {
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
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'romlerk.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
