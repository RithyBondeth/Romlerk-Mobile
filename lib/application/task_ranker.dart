import '../domain/entities/task.dart';
import '../domain/enums.dart';
import '../l10n/app_localizations.dart';

/// Why a task was suggested. Kept as data so the UI can phrase it in the
/// user's language.
enum RankReasonKind {
  overdue,
  dueSoon,
  dueToday,
  dueWithinDay,
  highPriority,
  quickWin,
  active,
}

class RankReason {
  const RankReason(this.kind, {this.minutes});

  final RankReasonKind kind;

  /// The task's duration, for [RankReasonKind.quickWin].
  final int? minutes;

  String describe(AppLocalizations l10n) => switch (kind) {
    RankReasonKind.overdue => l10n.rankOverdue,
    RankReasonKind.dueSoon => l10n.rankDueSoon,
    RankReasonKind.dueToday => l10n.rankDueToday,
    RankReasonKind.dueWithinDay => l10n.rankDueWithinDay,
    RankReasonKind.highPriority => l10n.rankHighPriority,
    RankReasonKind.quickWin => l10n.rankQuickWin(minutes ?? 0),
    RankReasonKind.active => l10n.rankActive,
  };

  @override
  bool operator ==(Object other) =>
      other is RankReason && other.kind == kind && other.minutes == minutes;

  @override
  int get hashCode => Object.hash(kind, minutes);
}

/// Evaluated task recommendation with explanation factors for FR-18.
class RankedTask {
  const RankedTask({
    required this.task,
    required this.score,
    required this.reasons,
  });

  final Task task;
  final double score;
  final List<RankReason> reasons;
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
    final reasons = <RankReason>[];

    final effectiveDate = task.effectiveDate;

    // 1. Overdue handling (Highest priority)
    if (task.isOverdueAt(now)) {
      score += 100.0;
      reasons.add(const RankReason(RankReasonKind.overdue));
    } else if (effectiveDate != null) {
      final hoursUntilDue = effectiveDate.difference(now).inMinutes / 60.0;
      if (hoursUntilDue >= 0 && hoursUntilDue <= 2) {
        score += 80.0;
        reasons.add(const RankReason(RankReasonKind.dueSoon));
      } else if (hoursUntilDue > 2 && hoursUntilDue <= 6) {
        score += 50.0;
        reasons.add(const RankReason(RankReasonKind.dueToday));
      } else if (hoursUntilDue > 6 && hoursUntilDue <= 24) {
        score += 30.0;
        reasons.add(const RankReason(RankReasonKind.dueWithinDay));
      }
    }

    // 2. Explicit Priority Weighting
    switch (task.priority) {
      case TaskPriority.high:
        score += 35.0;
        reasons.add(const RankReason(RankReasonKind.highPriority));
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
        reasons.add(RankReason(RankReasonKind.quickWin, minutes: duration));
      } else if (duration <= 30) {
        score += 10.0;
      }
    }

    // Default fallback reason if no specific factors applied
    if (reasons.isEmpty) {
      reasons.add(const RankReason(RankReasonKind.active));
    }

    return RankedTask(
      task: task,
      score: score,
      reasons: reasons,
    );
  }
}
