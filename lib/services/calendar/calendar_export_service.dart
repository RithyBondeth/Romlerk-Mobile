import 'dart:convert';
import '../../domain/entities/task.dart';

/// Calendar preview detail shown to the user before confirming calendar export (FR-20).
class CalendarEventPreview {
  const CalendarEventPreview({
    required this.taskId,
    required this.title,
    this.notes,
    required this.startAt,
    required this.endAt,
  });

  final String taskId;
  final String title;
  final String? notes;
  final DateTime startAt;
  final DateTime endAt;

  factory CalendarEventPreview.fromTask(
    Task task, {
    Duration defaultDuration = const Duration(minutes: 30),
  }) {
    final start = task.startAt ?? task.dueAt;
    if (start == null) {
      throw const FormatException('Calendar events need a date');
    }
    final duration = task.durationMinutes != null
        ? Duration(minutes: task.durationMinutes!)
        : defaultDuration;
    final end = start.add(duration);

    return CalendarEventPreview(
      taskId: task.id,
      title: task.title,
      notes: task.notes,
      startAt: start,
      endAt: end,
    );
  }
}

/// Service for exporting tasks to standard calendar formats and system calendar integrations.
class CalendarExportService {
  const CalendarExportService();

  /// Builds an iCalendar (ICS) standard event string for portable calendar export.
  String buildIcs(Task task, {DateTime? exportedAt}) {
    final preview = CalendarEventPreview.fromTask(task);
    final now = exportedAt ?? DateTime.now();

    final buffer = StringBuffer()
      ..writeln('BEGIN:VCALENDAR')
      ..writeln('VERSION:2.0')
      ..writeln('PRODID:-//Romlerk//Local Task App//EN')
      ..writeln('BEGIN:VEVENT')
      ..writeln('UID:${_escapeIcs(task.id)}@romlerk.local')
      ..writeln('DTSTAMP:${_formatIcsDate(now)}')
      ..writeln('DTSTART:${_formatIcsDate(preview.startAt)}')
      ..writeln('DTEND:${_formatIcsDate(preview.endAt)}')
      ..writeln('SUMMARY:${_escapeIcs(preview.title)}');

    if (preview.notes != null && preview.notes!.isNotEmpty) {
      buffer.writeln('DESCRIPTION:${_escapeIcs(preview.notes!)}');
    }

    buffer
      ..writeln('END:VEVENT')
      ..writeln('END:VCALENDAR');

    // RFC 5545: CRLF and folded content lines at 75 UTF-8 octets.
    final lines = buffer
        .toString()
        .split('\n')
        .where((line) => line.isNotEmpty)
        .map(_fold)
        .join('\r\n');
    return '$lines\r\n';
  }

  static String _fold(String line) {
    final result = StringBuffer();
    var bytes = 0;
    for (final rune in line.runes) {
      final char = String.fromCharCode(rune);
      final length = utf8.encode(char).length;
      if (bytes + length > 75) {
        result.write('\r\n ');
        bytes = 1;
      }
      result.write(char);
      bytes += length;
    }
    return result.toString();
  }

  static String _formatIcsDate(DateTime dt) {
    final utc = dt.toUtc();
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${utc.year}${pad(utc.month)}${pad(utc.day)}T${pad(utc.hour)}${pad(utc.minute)}${pad(utc.second)}Z';
  }

  static String _escapeIcs(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll(';', '\\;')
        .replaceAll(',', '\\,')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\n', '\\n');
  }
}
