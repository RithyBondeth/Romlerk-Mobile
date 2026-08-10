import 'dart:convert';

import '../../domain/entities/task.dart';

/// Portable export formats for FR-24.
enum ExportFormat {
  json('json', 'application/json'),
  csv('csv', 'text/csv');

  const ExportFormat(this.extension, this.mimeType);

  final String extension;
  final String mimeType;
}

/// Serializes tasks to a user-portable file body.
///
/// Pure string production, no file system access, so it is trivially testable
/// and reusable by whatever share/save mechanism the platform offers.
class TaskExporter {
  const TaskExporter();

  /// Bumped whenever the export shape changes, so an importer can tell which
  /// layout it is reading.
  static const int exportSchemaVersion = 1;

  String buildJson(List<Task> tasks, {required DateTime exportedAt}) {
    final payload = <String, dynamic>{
      'schemaVersion': exportSchemaVersion,
      'application': 'Romlerk',
      'exportedAt': exportedAt.toIso8601String(),
      'taskCount': tasks.length,
      'tasks': tasks.map((task) => task.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  static const List<String> _csvHeaders = <String>[
    'id',
    'title',
    'notes',
    'status',
    'priority',
    'start_at',
    'due_at',
    'duration_minutes',
    'reminder_at',
    'recurrence',
    'tags',
    'created_at',
    'completed_at',
  ];

  String buildCsv(List<Task> tasks) {
    final buffer = StringBuffer()..writeln(_csvHeaders.join(','));
    for (final task in tasks) {
      buffer.writeln(
        <String>[
          task.id,
          task.title,
          task.notes ?? '',
          task.status.wire,
          task.priority.wire,
          task.startAt?.toIso8601String() ?? '',
          task.dueAt?.toIso8601String() ?? '',
          task.durationMinutes?.toString() ?? '',
          task.reminder?.scheduledAt.toIso8601String() ?? '',
          task.recurrence == null
              ? ''
              : '${task.recurrence!.frequency.wire}/'
                    '${task.recurrence!.interval}',
          task.tags.map((tag) => tag.name).join('|'),
          task.createdAt.toIso8601String(),
          task.completedAt?.toIso8601String() ?? '',
        ].map(_csvCell).join(','),
      );
    }
    return buffer.toString();
  }

  String buildFileName(ExportFormat format, DateTime exportedAt) {
    final stamp = exportedAt
        .toIso8601String()
        .substring(0, 19)
        .replaceAll(':', '-');
    return 'romlerk-tasks-$stamp.${format.extension}';
  }

  /// RFC 4180 quoting: wrap when the value contains a delimiter, quote, or
  /// newline, and double any embedded quotes.
  static String _csvCell(String value) {
    if (!value.contains(RegExp(r'[",\n\r]'))) return value;
    return '"${value.replaceAll('"', '""')}"';
  }
}
