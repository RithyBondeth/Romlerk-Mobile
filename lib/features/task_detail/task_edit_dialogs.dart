import 'package:flutter/material.dart';
import '../../domain/entities/recurrence_rule.dart';
import '../../domain/enums.dart';
import '../../l10n/l10n.dart';

class DateEdit {
  const DateEdit(this.value);
  final DateTime? value;
}

Future<DateEdit?> editTaskDate(
  BuildContext context,
  String label,
  DateTime? initial, {
  bool futureOnly = false,
}) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(label),
            onTap: () => Navigator.pop(context, 'pick'),
          ),
          if (initial != null)
            ListTile(
              title: Text(context.l10n.editClear),
              onTap: () => Navigator.pop(context, 'clear'),
            ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return null;
  if (choice == 'clear') return const DateEdit(null);
  final now = DateTime.now();
  final start = initial ?? now.add(const Duration(hours: 1));
  final date = await showDatePicker(
    context: context,
    initialDate: start,
    firstDate: DateTime(1900),
    lastDate: DateTime(2200),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(start),
  );
  if (time == null || !context.mounted) return null;
  final resolved = DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  );
  if (futureOnly && !resolved.isAfter(DateTime.now())) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.editReminderFuture)));
    return null;
  }
  return DateEdit(resolved);
}

Future<String?> editTaskText(
  BuildContext context, {
  required String label,
  required String initial,
  required String hint,
  int? maxLength,
  bool number = false,
}) async {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextEditDialog(
      label: label,
      initial: initial,
      hint: hint,
      maxLength: maxLength,
      number: number,
    ),
  );
}

class _TextEditDialog extends StatefulWidget {
  const _TextEditDialog({
    required this.label,
    required this.initial,
    required this.hint,
    required this.number,
    this.maxLength,
  });
  final String label, initial, hint;
  final bool number;
  final int? maxLength;
  @override
  State<_TextEditDialog> createState() => _TextEditDialogState();
}

class _TextEditDialogState extends State<_TextEditDialog> {
  late final controller = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.label),
    content: TextField(
      controller: controller,
      autofocus: true,
      maxLength: widget.maxLength,
      keyboardType: widget.number ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(hintText: widget.hint),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, controller.text),
        child: Text(context.l10n.editApply),
      ),
    ],
  );
}

class RecurrenceEdit {
  const RecurrenceEdit(this.value);
  final RecurrenceRule? value;
}

Future<RecurrenceEdit?> editTaskRecurrence(
  BuildContext context,
  RecurrenceRule? initial,
) => showDialog<RecurrenceEdit>(
  context: context,
  builder: (context) => _RecurrenceDialog(initial: initial),
);

class _RecurrenceDialog extends StatefulWidget {
  const _RecurrenceDialog({this.initial});
  final RecurrenceRule? initial;
  @override
  State<_RecurrenceDialog> createState() => _RecurrenceDialogState();
}

class _RecurrenceDialogState extends State<_RecurrenceDialog> {
  late RecurrenceFrequency frequency =
      widget.initial?.frequency ?? RecurrenceFrequency.daily;
  late final interval = TextEditingController(
    text: '${widget.initial?.interval ?? 1}',
  );
  late final count = TextEditingController(
    text: widget.initial?.count?.toString() ?? '',
  );
  late final weekdays = {...?widget.initial?.byWeekday};
  late DateTime? until = widget.initial?.until;
  bool invalid = false;
  @override
  void dispose() {
    interval.dispose();
    count.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.detailRepeats),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<RecurrenceFrequency>(
              initialValue: frequency,
              items: [
                for (final f in RecurrenceFrequency.values)
                  DropdownMenuItem(
                    value: f,
                    child: Text(switch (f) {
                      RecurrenceFrequency.daily => l.recurEveryDay,
                      RecurrenceFrequency.weekly => l.recurEveryWeek,
                      RecurrenceFrequency.monthly => l.recurEveryMonth,
                      RecurrenceFrequency.yearly => l.recurEveryYear,
                    }),
                  ),
              ],
              onChanged: (f) => setState(() => frequency = f!),
            ),
            TextField(
              controller: interval,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l.editRepeatInterval),
            ),
            if (frequency == RecurrenceFrequency.weekly)
              Wrap(
                children: [
                  for (var day = 1; day <= 7; day++)
                    FilterChip(
                      label: Text(
                        MaterialLocalizations.of(context).narrowWeekdays[day %
                            7],
                      ),
                      selected: weekdays.contains(day),
                      onSelected: (selected) => setState(() {
                        selected ? weekdays.add(day) : weekdays.remove(day);
                      }),
                    ),
                ],
              ),
            TextField(
              controller: count,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l.editRepeatCount),
            ),
            ListTile(
              title: Text(l.editRepeatUntil),
              subtitle: Text(
                until == null
                    ? l.editNotSet
                    : MaterialLocalizations.of(
                        context,
                      ).formatMediumDate(until!),
              ),
              trailing: until == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => until = null),
                    ),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: until ?? DateTime.now(),
                  firstDate: DateTime(1900),
                  lastDate: DateTime(2200),
                );
                if (date != null && mounted) {
                  setState(
                    () => until = DateTime(
                      date.year,
                      date.month,
                      date.day,
                      23,
                      59,
                      59,
                    ),
                  );
                }
              },
            ),
            if (invalid)
              Text(
                l.editRepeatInvalid,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, const RecurrenceEdit(null)),
          child: Text(l.editClear),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () {
            final n = int.tryParse(interval.text);
            final c = count.text.trim().isEmpty
                ? null
                : int.tryParse(count.text);
            if (n == null ||
                n < 1 ||
                n > 365 ||
                (count.text.trim().isNotEmpty &&
                    (c == null || c < 1 || c > 100000))) {
              setState(() => invalid = true);
              return;
            }
            Navigator.pop(
              context,
              RecurrenceEdit(
                RecurrenceRule(
                  frequency: frequency,
                  interval: n,
                  byWeekday: frequency == RecurrenceFrequency.weekly
                      ? (weekdays.toList()..sort())
                      : [],
                  count: c,
                  until: until,
                ),
              ),
            );
          },
          child: Text(l.editApply),
        ),
      ],
    );
  }
}
