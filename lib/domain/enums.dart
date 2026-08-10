/// Shared domain enumerations.
///
/// Every enum stores a stable string [wire] value. Persistence and export use
/// the wire value, never the Dart index, so reordering cases can never
/// silently rewrite stored data.
library;

enum TaskStatus {
  active('active'),
  completed('completed');

  const TaskStatus(this.wire);

  final String wire;

  static TaskStatus fromWire(String value) => TaskStatus.values.firstWhere(
    (status) => status.wire == value,
    orElse: () => TaskStatus.active,
  );
}

enum TaskPriority {
  none('none', 0),
  low('low', 1),
  medium('medium', 2),
  high('high', 3);

  const TaskPriority(this.wire, this.rank);

  final String wire;

  /// Higher means more urgent. Used for deterministic list ordering.
  final int rank;

  static TaskPriority fromWire(String value) =>
      TaskPriority.values.firstWhere(
        (priority) => priority.wire == value,
        orElse: () => TaskPriority.none,
      );
}

enum RecurrenceFrequency {
  daily('daily'),
  weekly('weekly'),
  monthly('monthly'),
  yearly('yearly');

  const RecurrenceFrequency(this.wire);

  final String wire;

  static RecurrenceFrequency fromWire(String value) =>
      RecurrenceFrequency.values.firstWhere(
        (frequency) => frequency.wire == value,
        orElse: () => RecurrenceFrequency.daily,
      );
}

/// Lifecycle of a single scheduled reminder.
///
/// A reminder is recorded in the database before the platform schedule is
/// attempted, so [ReminderState.failed] and [ReminderState.blocked] are normal
/// persisted states rather than error conditions (BRD "failure atomicity").
enum ReminderState {
  /// Persisted, platform scheduling not attempted yet.
  pending('pending'),

  /// Accepted by the OS notification scheduler.
  scheduled('scheduled'),

  /// The OS rejected the schedule request.
  failed('failed'),

  /// Notification permission is not granted, so nothing was scheduled.
  blocked('blocked'),

  /// Deliberately cancelled (task completed, deleted, or reminder cleared).
  cancelled('cancelled'),

  /// Delivery time has passed.
  delivered('delivered');

  const ReminderState(this.wire);

  final String wire;

  bool get isActive => this == pending || this == scheduled;

  /// The user should be told about these, since no reminder will arrive.
  bool get needsAttention => this == failed || this == blocked;

  static ReminderState fromWire(String value) =>
      ReminderState.values.firstWhere(
        (state) => state.wire == value,
        orElse: () => ReminderState.pending,
      );
}
