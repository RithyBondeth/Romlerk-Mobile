import '../domain/entities/task.dart';
import '../domain/enums.dart';

/// Evaluated task recommendation with explanation factors for FR-18.
class RankedTask {
  const RankedTask({
    required this.task,
    required this.score,
    required this.reasons,
  });

  final Task task;
  final double score;
  final List<String> reasons;
}

/// Rule-based deterministic task ranking engine (FR-18).
///
/// Ranks active commitments to help users decide "What should I do now?" without
/// taking control away or making silent automatic schedule changes.
class TaskRanker {
  const TaskRanker();

  /// Ranks a list of tasks in descending order of recommendation score.
  List<RankedTask> rankTasks(List<Task> tasks, {required DateTime now}) {
    final ranked = tasks.map((task) => evaluateTask(task, now: now)).toList();
    ranked.sort((a, b) => b.score.compareTo(a.score));
    return ranked;
  }

  /// Calculates a deterministic urgency & focus score for a single task.
  RankedTask evaluateTask(Task task, {required DateTime now}) {
    var score = 0.0;
    final reasons = <String>[];

    final effectiveDate = task.effectiveDate;

    // 1. Overdue handling (Highest priority)
    if (task.isOverdueAt(now)) {
      score += 100.0;
      reasons.add('Overdue commitment');
    } else if (effectiveDate != null) {
      final hoursUntilDue = effectiveDate.difference(now).inMinutes / 60.0;
      if (hoursUntilDue >= 0 && hoursUntilDue <= 2) {
        score += 80.0;
        reasons.add('Due within 2 hours');
      } else if (hoursUntilDue > 2 && hoursUntilDue <= 6) {
        score += 50.0;
        reasons.add('Due today');
      } else if (hoursUntilDue > 6 && hoursUntilDue <= 24) {
        score += 30.0;
        reasons.add('Due within 24 hours');
      }
    }

    // 2. Explicit Priority Weighting
    switch (task.priority) {
      case TaskPriority.high:
        score += 35.0;
        reasons.add('High priority');
        break;
      case TaskPriority.medium:
        score += 15.0;
        break;
      case TaskPriority.low:
        score += 5.0;
        break;
      case TaskPriority.none:
        break;
    }

    // 3. Quick-win duration boost (< 20 mins)
    if (task.durationMinutes != null) {
      final duration = task.durationMinutes!;
      if (duration <= 15) {
        score += 20.0;
        reasons.add('Quick win (${duration}m)');
      } else if (duration <= 30) {
        score += 10.0;
      }
    }

    // Default fallback reason if no specific factors applied
    if (reasons.isEmpty) {
      reasons.add('Active task');
    }

    return RankedTask(
      task: task,
      score: score,
      reasons: reasons,
    );
  }
}
