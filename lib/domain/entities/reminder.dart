import '../enums.dart';

/// A single scheduled local notification for a task.
///
/// [platformId] is the integer handle the OS notification scheduler knows this
/// reminder by. Per the BRD it is a *reference*, not authority — the app
/// reconciles it on resume rather than trusting it.
class Reminder {
  const Reminder({
    required this.id,
    required this.taskId,
    required this.scheduledAt,
    required this.timezone,
    required this.state,
    this.platformId,
    this.failureCode,
  });

  final String id;
  final String taskId;

  /// Absolute local time the reminder should fire.
  final DateTime scheduledAt;

  /// IANA timezone name captured when the reminder was created, so a device
  /// timezone change can be detected and explained instead of silently moving
  /// the reminder.
  final String timezone;

  final ReminderState state;
  final int? platformId;

  /// Stable error code from the error taxonomy, when [state] is failed.
  final String? failureCode;

  bool get isActive => state.isActive;

  Reminder copyWith({
    DateTime? scheduledAt,
    String? timezone,
    ReminderState? state,
    int? platformId,
    String? failureCode,
    bool clearFailureCode = false,
    bool clearPlatformId = false,
  }) {
    return Reminder(
      id: id,
      taskId: taskId,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      timezone: timezone ?? this.timezone,
      state: state ?? this.state,
      platformId: clearPlatformId ? null : (platformId ?? this.platformId),
      failureCode: clearFailureCode ? null : (failureCode ?? this.failureCode),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'scheduledAt': scheduledAt.toIso8601String(),
    'timezone': timezone,
    'state': state.wire,
  };
}
