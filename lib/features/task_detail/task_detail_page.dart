import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../application/providers.dart';
import '../../application/task_service.dart';
import '../../application/editing/autosave_controller.dart';
import '../../core/widgets/autosave_status.dart';
import '../../domain/entities/reminder.dart';
import 'task_edit_dialogs.dart';
import '../../core/design/app_theme.dart';
import '../../core/design/design_tokens.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/group_card.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/tag.dart';
import '../../domain/enums.dart';
import '../../core/format/messages.dart';
import '../../l10n/l10n.dart';

/// Full view of one confirmed task, and the only place it can be edited.
///
/// Edits save on change rather than behind a Save button — the task already
/// exists. Metadata editors apply explicitly; deletion asks for confirmation.
class TaskDetailPage extends ConsumerStatefulWidget {
  const TaskDetailPage({required this.taskId, super.key});

  final String taskId;

  static Future<void> open(BuildContext context, String taskId) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => TaskDetailPage(taskId: taskId)),
    );
  }

  @override
  ConsumerState<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends ConsumerState<TaskDetailPage> {
  final _bodyKey = GlobalKey<_BodyState>();

  @override
  Widget build(BuildContext context) {
    final task = ref.watch(taskDetailProvider(widget.taskId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: <Widget>[
          if (task.valueOrNull != null)
            IconButton(
              icon: const Icon(LucideIcons.trash2, size: 19),
              tooltip: context.l10n.deleteTask,
              onPressed: () => _confirmDelete(context, ref),
            ),
        ],
      ),
      body: task.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: LucideIcons.triangleAlert,
          tone: context.semantics.overdue,
          headline: context.l10n.detailOpenFailed,
          body: context.l10n.detailNothingChanged,
        ),
        data: (data) {
          if (data == null) {
            return EmptyState(
              icon: LucideIcons.circleSlash,
              headline: context.l10n.detailGone,
              body: context.l10n.detailGoneBody,
            );
          }
          return _Body(key: _bodyKey, task: data);
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteTaskQuestion),
        content: Text(context.l10n.deleteTaskBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.keep),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await _bodyKey.currentState?._autosave.stop();
      await ref.read(taskServiceProvider).deleteTask(widget.taskId);
      if (context.mounted) Navigator.of(context).pop();
    } on Object {
      _bodyKey.currentState?._autosave.resume();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.editFailed)));
      }
    }
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.task, super.key});

  final Task task;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> with WidgetsBindingObserver {
  late final TextEditingController _notesController = TextEditingController(
    text: widget.task.notes ?? '',
  );

  late final _titleController = TextEditingController(text: widget.task.title);
  late final TaskService _service;
  late final AutosaveController _autosave;
  bool _allowPop = false;
  bool _leaving = false;
  Task get task => widget.task;

  @override
  void initState() {
    super.initState();
    _service = ref.read(taskServiceProvider);
    _autosave = AutosaveController(_saveText)..addListener(_updated);
    WidgetsBinding.instance.addObserver(this);
  }

  void _updated() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant _Body oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_autosave.dirty && !_autosave.saving) {
      if (_titleController.text != task.title) {
        _titleController.text = task.title;
      }
      if (_notesController.text != (task.notes ?? '')) {
        _notesController.text = task.notes ?? '';
      }
    }
  }

  Future<void> _saveText() async {
    final title = _titleController.text.trim();
    final notes = _notesController.text;
    if (title.isEmpty || title.length > 500) {
      throw const FormatException('Invalid title');
    }
    await _service.editTask(
      task.id,
      (latest) => latest.copyWith(
        title: title,
        notes: notes.isEmpty ? null : notes,
        clearNotes: notes.isEmpty,
      ),
      requestPermission: false,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_autosave.flush());
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    final saved = await _autosave.flush();
    _leaving = false;
    if (!mounted || !saved) return;
    setState(() => _allowPop = true);
    Navigator.pop(context);
  }

  Future<void> _apply(Task Function(Task) edit) async {
    if (!await _autosave.flush() || !mounted) return;
    try {
      final outcome = await _service.editTask(task.id, (latest) {
        final changed = edit(latest);
        if (changed.startAt != null &&
            changed.dueAt != null &&
            changed.startAt!.isAfter(changed.dueAt!)) {
          throw const FormatException('Start must precede due');
        }
        if (changed.recurrence != null && changed.effectiveDate == null) {
          throw const FormatException('Recurrence needs a date');
        }
        return changed;
      });
      if (mounted && outcome.reminderIssue != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(outcome.reminderIssue!.describe(context.l10n)),
          ),
        );
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.editFailed)));
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosave.removeListener(_updated);
    _autosave.dispose();
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formatting = ref.watch(formattingProvider);
    final now = ref.watch(clockProvider)();
    final service = ref.watch(taskServiceProvider);
    final semantics = context.semantics;

    final l10n = context.l10n;
    final rows = <Widget>[
      // Every consequential field is spelled out in full, so what the app
      // will actually do is never left implicit.
      _DetailRow(
        icon: LucideIcons.calendar,
        label: l10n.detailDue,
        value: task.dueAt == null
            ? l10n.detailNotScheduled
            : formatting.exact(task.dueAt!, now: now),
        emphasize: task.isOverdueAt(now),
        onTap: () => _editDate(context),
      ),
      _DetailRow(
        icon: LucideIcons.calendarClock,
        label: l10n.editStart,
        value: task.startAt == null
            ? l10n.editNotSet
            : formatting.exact(task.startAt!, now: now),
        onTap: () => _editStart(context),
      ),
      _DetailRow(
        icon: task.hasReminderProblem ? LucideIcons.bellOff : LucideIcons.bell,
        label: l10n.detailReminder,
        value: task.reminder == null
            ? l10n.editNotSet
            : switch (task.reminder!.state) {
                ReminderState.blocked => l10n.detailReminderBlocked,
                ReminderState.failed => l10n.detailReminderFailed,
                ReminderState.delivered => l10n.detailReminderDelivered,
                ReminderState.cancelled => l10n.detailReminderCancelled,
                _ => formatting.exact(task.reminder!.scheduledAt, now: now),
              },
        emphasize: task.hasReminderProblem,
        onTap: () => _editReminder(context),
      ),
      _DetailRow(
        icon: LucideIcons.repeat,
        label: l10n.detailRepeats,
        value: task.recurrence == null
            ? l10n.editNotSet
            : formatting.recurrence(task.recurrence!),
        onTap: () => _editRecurrence(context),
      ),
      _DetailRow(
        icon: LucideIcons.flag,
        label: l10n.priority,
        value: formatting.priority(task.priority),
        onTap: () => _editPriority(context),
      ),
      _DetailRow(
        icon: LucideIcons.hourglass,
        label: l10n.detailTakes,
        value: task.durationMinutes == null
            ? l10n.editNotSet
            : formatting.duration(task.durationMinutes!),
        onTap: () => _editDuration(context),
      ),
      _DetailRow(
        icon: LucideIcons.hash,
        label: l10n.detailTags,
        value: task.tags.isEmpty
            ? l10n.editNotSet
            : task.tags.map((tag) => tag.name).join(', '),
        onTap: () => _editTags(context),
      ),
      if (task.dueAt != null)
        _DetailRow(
          icon: LucideIcons.calendarPlus,
          label: l10n.detailCalendar,
          value: l10n.exportCalendar,
          onTap: () => _exportToCalendar(context),
        ),
    ];

    return PopScope(
      canPop: _allowPop || (!_autosave.dirty && !_autosave.saving),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          Insets.gutter,
          0,
          Insets.gutter,
          Insets.xxl,
        ),
        children: <Widget>[
          AutosaveStatus(controller: _autosave),
          if (task.isCompleted) ...<Widget>[
            _CompletedBadge(
              label: task.completedAt == null
                  ? l10n.completedLabel
                  : l10n.detailCompletedAt(
                      formatting.exact(task.completedAt!, now: now),
                    ),
            ),
            const SizedBox(height: Insets.md),
          ],

          TextFormField(
            key: const ValueKey('task-title'),
            controller: _titleController,
            maxLength: 500,
            style: context.texts.headlineSmall?.copyWith(
              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
              decorationColor: semantics.muted,
            ),
            maxLines: 3,
            decoration: InputDecoration(
              errorText: _titleController.text.trim().isEmpty
                  ? l10n.editTitleRequired
                  : null,
              isDense: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (_) => _autosave.changed(),
            onFieldSubmitted: (_) => _autosave.flush(),
          ),

          const SizedBox(height: Insets.lg),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                if (!await _autosave.flush()) return;
                HapticFeedback.selectionClick();
                try {
                  final outcome = task.isCompleted
                      ? await service.reopenTask(task.id)
                      : await service.completeTask(task.id);
                  if (context.mounted && outcome.reminderIssue != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          outcome.reminderIssue!.describe(context.l10n),
                        ),
                      ),
                    );
                  }
                } on Object {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.l10n.editFailed)),
                    );
                  }
                }
              },
              icon: Icon(
                task.isCompleted ? LucideIcons.rotateCcw : LucideIcons.check,
                size: 18,
              ),
              label: Text(
                task.isCompleted ? l10n.reopenTask : l10n.markComplete,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: task.isCompleted
                    ? semantics.sunken
                    : semantics.completed,
                foregroundColor: task.isCompleted
                    ? context.colors.onSurface
                    : (semantics.isDark
                          ? const Color(0xFF0F2413)
                          : Colors.white),
              ),
            ),
          ),

          const SizedBox(height: Insets.xl),

          GroupCard(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.lg,
              vertical: Insets.xs,
            ),
            child: Column(
              children: <Widget>[
                for (var i = 0; i < rows.length; i++) ...<Widget>[
                  if (i > 0) Divider(color: semantics.hairline, height: 1),
                  rows[i],
                ],
              ],
            ),
          ),

          const SizedBox(height: Insets.xl),

          Text(
            l10n.detailNotes.toUpperCase(),
            style: context.texts.labelSmall?.copyWith(
              color: semantics.muted,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Insets.sm),
          TextField(
            key: const ValueKey('task-notes'),
            controller: _notesController,
            maxLines: null,
            minLines: 3,
            onChanged: (_) => _autosave.changed(),
            decoration: InputDecoration(
              hintText: l10n.detailNotesHint,
              fillColor: semantics.raised,
            ),
          ),

          const SizedBox(height: Insets.xl),

          Text(
            l10n.detailCreatedAt(formatting.exact(task.createdAt, now: now)),
            style: context.texts.bodySmall?.copyWith(color: semantics.muted),
          ),
        ],
      ),
    );
  }

  Future<void> _editDate(BuildContext context) async {
    final result = await editTaskDate(
      context,
      context.l10n.detailDue,
      task.dueAt,
    );
    if (result == null || !context.mounted) return;
    await _apply(
      (latest) => latest.copyWith(
        dueAt: result.value,
        clearDueAt: result.value == null,
      ),
    );
  }

  Future<void> _editStart(BuildContext context) async {
    final result = await editTaskDate(
      context,
      context.l10n.editStart,
      task.startAt,
    );
    if (result == null || !context.mounted) return;
    await _apply(
      (latest) => latest.copyWith(
        startAt: result.value,
        clearStartAt: result.value == null,
      ),
    );
  }

  Future<void> _editReminder(BuildContext context) async {
    final result = await editTaskDate(
      context,
      context.l10n.detailReminder,
      task.reminder?.scheduledAt,
      futureOnly: true,
    );
    if (result == null || !context.mounted) return;
    await _apply(
      (latest) => latest.copyWith(
        clearReminder: result.value == null,
        reminder: result.value == null
            ? null
            : Reminder(
                id: latest.reminder?.id ?? const Uuid().v4(),
                taskId: latest.id,
                scheduledAt: result.value!,
                timezone: ref.read(reminderSchedulerProvider).localTimezone,
                state: latest.isCompleted
                    ? ReminderState.cancelled
                    : ReminderState.pending,
              ),
      ),
    );
  }

  Future<void> _editRecurrence(BuildContext context) async {
    if (task.effectiveDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.editRepeatNeedsDate)));
      return;
    }
    final result = await editTaskRecurrence(context, task.recurrence);
    if (result == null || !context.mounted) return;
    await _apply(
      (latest) => latest.copyWith(
        recurrence: result.value,
        clearRecurrence: result.value == null,
        occurrenceIndex: 0,
      ),
    );
  }

  Future<void> _editDuration(BuildContext context) async {
    final result = await editTaskText(
      context,
      label: context.l10n.detailTakes,
      initial: task.durationMinutes?.toString() ?? '',
      hint: context.l10n.editDurationHint,
      number: true,
    );
    if (result == null || !context.mounted) return;
    final value = result.trim().isEmpty ? null : int.tryParse(result.trim());
    if (result.trim().isNotEmpty &&
        (value == null || value < 1 || value > 10080)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.editDurationHint)));
      return;
    }
    await _apply(
      (latest) =>
          latest.copyWith(durationMinutes: value, clearDuration: value == null),
    );
  }

  Future<void> _editTags(BuildContext context) async {
    final result = await editTaskText(
      context,
      label: context.l10n.detailTags,
      initial: task.tags.map((t) => t.name).join(', '),
      hint: context.l10n.editTagsHint,
    );
    if (result == null || !context.mounted) return;
    final names = result
        .split(',')
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toSet();
    if (names.any((n) => n.length > 60) || names.length > 50) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.editTagsHint)));
      return;
    }
    if (!await _autosave.flush() || !context.mounted) return;
    try {
      final repo = ref.read(taskRepositoryProvider);
      final tags = <Tag>[];
      final seen = <String>{};
      for (final name in names) {
        if (seen.add(Tag.normalize(name))) {
          tags.add(await repo.ensureTag(name));
        }
      }
      await _apply((latest) => latest.copyWith(tags: tags));
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.editFailed)));
      }
    }
  }

  Future<void> _editPriority(BuildContext context) async {
    final formatting = ref.read(formattingProvider);
    final selected = await showModalBottomSheet<TaskPriority>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final priority in TaskPriority.values)
              ListTile(
                title: Text(formatting.priority(priority)),
                trailing: priority == task.priority
                    ? const Icon(LucideIcons.check, size: 18)
                    : null,
                onTap: () => Navigator.of(context).pop(priority),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await _apply((latest) => latest.copyWith(priority: selected));
  }

  Future<void> _exportToCalendar(BuildContext context) async {
    final exporter = ref.read(calendarExportServiceProvider);
    final ics = exporter.buildIcs(task);
    await Clipboard.setData(ClipboardData(text: ics));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.detailIcsCopied)));
  }
}

/// Completion is stated at the top rather than inferred from a struck-through
/// title, so opening a finished task never looks like a bug.
class _CompletedBadge extends StatelessWidget {
  const _CompletedBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.sm - 2,
        ),
        decoration: BoxDecoration(
          color: semantics.completedSoft,
          borderRadius: Corners.pill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(LucideIcons.check, size: 14, color: semantics.completed),
            const SizedBox(width: Insets.sm - 2),
            Text(
              label,
              style: context.texts.labelSmall?.copyWith(
                color: semantics.completed,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.emphasize = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    final color = emphasize ? semantics.overdue : null;

    return InkWell(
      onTap: onTap,
      borderRadius: Corners.chip,
      child: Container(
        constraints: const BoxConstraints(minHeight: Insets.minTapTarget + 8),
        padding: const EdgeInsets.symmetric(vertical: Insets.sm + 2),
        child: Row(
          children: <Widget>[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: emphasize ? semantics.overdueSoft : semantics.sunken,
                borderRadius: Corners.chip,
              ),
              child: Icon(icon, size: 15, color: color ?? semantics.muted),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    label,
                    style: context.texts.labelSmall?.copyWith(
                      color: semantics.muted,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: context.texts.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(LucideIcons.chevronRight, size: 16, color: semantics.muted),
          ],
        ),
      ),
    );
  }
}
