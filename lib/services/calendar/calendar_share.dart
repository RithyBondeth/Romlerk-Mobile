import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/entities/task.dart';
import '../../l10n/l10n.dart';
import 'calendar_export_service.dart';

Future<void> shareCalendarEvent(
  BuildContext context,
  CalendarExportService exporter,
  Task task,
) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final event = CalendarEventPreview.fromTask(task);
    final local = MaterialLocalizations.of(context);
    String date(DateTime d) =>
        '${local.formatMediumDate(d)} · ${local.formatTimeOfDay(TimeOfDay.fromDateTime(d))}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.exportCalendar),
        content: Text(
          '${event.title}\n\n${date(event.startAt)}\n${date(event.endAt)}${event.notes == null ? '' : '\n\n${event.notes}'}\n\n${l.calendarSingleOccurrence}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.calendarShare),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/romlerk-event-${DateTime.now().microsecondsSinceEpoch}.ics',
    );
    await file.writeAsString(exporter.buildIcs(task), flush: true);
    if (!context.mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/calendar')],
        subject: task.title,
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  } on Object {
    messenger.showSnackBar(SnackBar(content: Text(l.calendarShareFailed)));
  }
}
