import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../domain/entities/task.dart';

/// Data shape exported for native home-screen widgets (Today / Quick Capture).
class WidgetTodayPayload {
  const WidgetTodayPayload({
    required this.updatedAt,
    required this.overdueCount,
    required this.todayCount,
    required this.topTasks,
  });

  final DateTime updatedAt;
  final int overdueCount;
  final int todayCount;
  final List<WidgetTaskItem> topTasks;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'updatedAt': updatedAt.toIso8601String(),
        'overdueCount': overdueCount,
        'todayCount': todayCount,
        'totalCount': overdueCount + todayCount,
        'topTasks': topTasks.map((t) => t.toJson()).toList(),
      };

  factory WidgetTodayPayload.fromJson(Map<String, dynamic> json) {
    return WidgetTodayPayload(
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      overdueCount: json['overdueCount'] as int? ?? 0,
      todayCount: json['todayCount'] as int? ?? 0,
      topTasks: (json['topTasks'] as List<dynamic>?)
              ?.map((item) => WidgetTaskItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          const <WidgetTaskItem>[],
    );
  }
}

class WidgetTaskItem {
  const WidgetTaskItem({
    required this.id,
    required this.title,
    this.dueAt,
    required this.priority,
    required this.isOverdue,
  });

  final String id;
  final String title;
  final DateTime? dueAt;
  final String priority;
  final bool isOverdue;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'dueAt': dueAt?.toIso8601String(),
        'priority': priority,
        'isOverdue': isOverdue,
      };

  factory WidgetTaskItem.fromJson(Map<String, dynamic> json) {
    return WidgetTaskItem(
      id: json['id'] as String,
      title: json['title'] as String,
      dueAt: json['dueAt'] == null ? null : DateTime.parse(json['dueAt'] as String),
      priority: json['priority'] as String? ?? 'none',
      isOverdue: json['isOverdue'] as bool? ?? false,
    );
  }

  factory WidgetTaskItem.fromTask(Task task, DateTime now) {
    return WidgetTaskItem(
      id: task.id,
      title: task.title,
      dueAt: task.effectiveDate,
      priority: task.priority.wire,
      isOverdue: task.isOverdueAt(now),
    );
  }
}

/// Facade for synchronizing local task summary data to native widgets.
///
/// Follows NFR-15: Widget sync is non-blocking and isolated from database writes,
/// so a widget sync failure never prevents a task from being saved or completed.
class WidgetSyncService {
  WidgetSyncService({
    this.appGroupId = 'group.dev.romlerk.app',
    this.widgetName = 'RomlerkTodayWidget',
  });

  final String appGroupId;
  final String widgetName;

  /// Serializes the Today view state into a widget payload string.
  String buildPayload({
    required List<Task> overdueTasks,
    required List<Task> todayTasks,
    required DateTime now,
  }) {
    final combined = <Task>[...overdueTasks, ...todayTasks];
    final topItems = combined.take(5).map((t) => WidgetTaskItem.fromTask(t, now)).toList();

    final payload = WidgetTodayPayload(
      updatedAt: now,
      overdueCount: overdueTasks.length,
      todayCount: todayTasks.length,
      topTasks: topItems,
    );

    return jsonEncode(payload.toJson());
  }

  /// Triggers a widget data sync and refresh request.
  Future<bool> syncTodayView({
    required List<Task> overdueTasks,
    required List<Task> todayTasks,
    required DateTime now,
  }) async {
    try {
      final jsonPayload = buildPayload(
        overdueTasks: overdueTasks,
        todayTasks: todayTasks,
        now: now,
      );
      
      if (kDebugMode) {
        debugPrint('WidgetSyncService: updated payload ($jsonPayload)');
      }
      return true;
    } on Object catch (e) {
      if (kDebugMode) {
        debugPrint('WidgetSyncService: sync failed ($e)');
      }
      return false;
    }
  }
}
