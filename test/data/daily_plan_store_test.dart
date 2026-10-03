import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romlerk_mobile/data/local/app_database.dart';
import 'package:romlerk_mobile/data/planning/daily_plan_store.dart';
import 'package:romlerk_mobile/domain/entities/task.dart';
import 'package:romlerk_mobile/domain/enums.dart';

void main() {
  late AppDatabase db;
  final day = DateTime(2026, 10, 3);
  Task task(int occurrence) => Task(
    id: 'task',
    title: 'Daily',
    status: TaskStatus.active,
    priority: TaskPriority.none,
    createdAt: day,
    updatedAt: day,
    occurrenceIndex: occurrence,
  );
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());
  test(
    'reopening a plan preserves the recurring occurrence baseline',
    () async {
      await DailyPlanStore(db).save(day, [task(2)]);
      var plan = (await DailyPlanStore(db).watch(day).first)!;
      expect(plan.completed(task(2)), isFalse);
      expect(plan.completed(task(3)), isTrue);
      await DailyPlanStore(db).save(day, [task(3)]);
      plan = (await DailyPlanStore(db).watch(day).first)!;
      expect(plan.completed(task(3)), isTrue);
      expect(
        await DailyPlanStore(db).watch(day.add(const Duration(days: 1))).first,
        isNull,
      );
    },
  );
  test(
    'empty plans are saved and malformed dates/values are rejected',
    () async {
      await DailyPlanStore(db).save(day, []);
      expect((await DailyPlanStore(db).watch(day).first)!.ids, isEmpty);
      expect(DailyPlanStore.valid('daily_plan_2026-02-30', '{}'), isFalse);
      expect(
        DailyPlanStore.valid(DailyPlanStore.key(day), jsonEncode({'task': -1})),
        isFalse,
      );
      expect(DailyPlanStore.valid(DailyPlanStore.key(day), '[]'), isFalse);
    },
  );
}
