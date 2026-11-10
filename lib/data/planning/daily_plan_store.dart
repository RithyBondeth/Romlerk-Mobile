import 'dart:convert';
import '../local/app_database.dart';
import '../../domain/entities/task.dart';

class DailyPlan {
  const DailyPlan(this.occurrences);
  final Map<String, int> occurrences;
  List<String> get ids => occurrences.keys.toList();
  bool completed(Task task) =>
      task.isCompleted ||
      task.occurrenceIndex > (occurrences[task.id] ?? task.occurrenceIndex);
}

/// Date-scoped plan selections. Kept in the canonical settings table so
/// backup, restore and erasure cover plans without a second store.
class DailyPlanStore {
  DailyPlanStore(this.db);
  final AppDatabase db;
  static String key(DateTime date) =>
      'daily_plan_${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  static bool valid(String key, String value) {
    final match = RegExp(
      r'^daily_plan_(\d{4})-(\d{2})-(\d{2})$',
    ).firstMatch(key);
    if (match == null) return false;
    final date = DateTime.tryParse(key.substring(11));
    if (date == null || DailyPlanStore.key(date) != key) return false;
    try {
      final values = jsonDecode(value) as Map<String, dynamic>;
      return values.length <= 100000 &&
          values.entries.every(
            (e) =>
                e.key.isNotEmpty &&
                e.key.length <= 200 &&
                e.value is int &&
                (e.value as int) >= 0,
          );
    } on Object {
      return false;
    }
  }

  Stream<DailyPlan?> watch(DateTime date) =>
      (db.select(
        db.settingRows,
      )..where((t) => t.key.equals(key(date)))).watchSingleOrNull().map(
        (row) => row == null
            ? null
            : DailyPlan(
                (jsonDecode(row.value) as Map<String, dynamic>)
                    .cast<String, int>(),
              ),
      );
  Future<DailyPlan?> read(DateTime date) async {
    final row = await (db.select(
      db.settingRows,
    )..where((t) => t.key.equals(key(date)))).getSingleOrNull();
    return row == null
        ? null
        : DailyPlan(
            (jsonDecode(row.value) as Map<String, dynamic>).cast<String, int>(),
          );
  }

  Future<void> save(DateTime date, Iterable<Task> tasks) async {
    final previous = await read(date);
    final value = jsonEncode({
      for (final t in tasks)
        t.id: previous?.occurrences[t.id] ?? t.occurrenceIndex,
    });
    if (!valid(key(date), value)) {
      throw const FormatException('Invalid daily plan');
    }
    await db
        .into(db.settingRows)
        .insertOnConflictUpdate(SettingRow(key: key(date), value: value));
  }
}
