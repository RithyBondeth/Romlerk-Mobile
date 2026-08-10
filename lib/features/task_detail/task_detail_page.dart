import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../application/providers.dart';
import '../../core/design/app_theme.dart';
import '../../core/design/design_tokens.dart';
import '../../core/widgets/empty_state.dart';
import '../../domain/entities/task.dart';
import '../../domain/enums.dart';

/// Full view of one confirmed task, and the only place it can be edited.
///
/// Edits save on change rather than behind a Save button — the task already
/// exists, so there is no consequence to preview. Actions that *do* have a
/// consequence (delete, changing a reminder) still confirm.
class TaskDetailPage extends ConsumerWidget {
  const TaskDetailPage({required this.taskId, super.key});

  final String taskId;

  static Future<void> open(BuildContext context, String taskId) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TaskDetailPage(taskId: taskId),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(taskDetailProvider(taskId));

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
              tooltip: 'Delete task',
              onPressed: () => _confirmDelete(context, ref),
            ),
        ],
      ),
      body: task.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => const EmptyState(
          icon: LucideIcons.triangleAlert,
          headline: 'This task could not be opened',
          body: 'Nothing has been changed.',
        ),
        data: (data) {
          if (data == null) {
            return const EmptyState(
              icon: LucideIcons.circleSlash,
              headline: 'Task no longer exists',
              body: 'It may have been deleted from another screen.',
            );
          }
          return _Body(task: data);
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this task?'),
        content: const Text(
          'It will be removed from this device, along with its reminder. '
          'This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(taskServiceProvider).deleteTask(taskId);
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.task});

  final Task task;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  late final TextEditingController _notesController = TextEditingController(
    text: widget.task.notes ?? '',
  );

  Task get task => widget.task;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formatting = ref.watch(formattingProvider);
    final now = ref.watch(clockProvider)();
    final service = ref.watch(taskServiceProvider);
    final semantics = context.semantics;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Insets.lg,
        0,
        Insets.lg,
        Insets.xxl,
      ),
      children: <Widget>[
        TextFormField(
          key: ValueKey<String>('title-${task.id}-${task.updatedAt}'),
          initialValue: task.title,
          style: context.texts.headlineSmall,
          maxLines: 3,
          decoration: const InputDecoration(
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          onFieldSubmitted: (value) {
            final trimmed = value.trim();
            if (trimmed.isEmpty || trimmed == task.title) return;
            service.saveTask(task.copyWith(title: trimmed));
          },
        ),

        const SizedBox(height: Insets.lg),

        FilledButton.icon(
          onPressed: () => task.isCompleted
              ? service.reopenTask(task.id)
              : service.completeTask(task.id),
          icon: Icon(
            task.isCompleted ? LucideIcons.rotateCcw : LucideIcons.check,
            size: 18,
          ),
          label: Text(task.isCompleted ? 'Reopen task' : 'Mark complete'),
          style: FilledButton.styleFrom(
            backgroundColor: task.isCompleted
                ? semantics.sunken
                : semantics.completed,
            foregroundColor: task.isCompleted
                ? context.colors.onSurface
                : context.colors.surface,
          ),
        ),

        const SizedBox(height: Insets.xl),

        // Every consequential field is spelled out in full, so what the app
        // will actually do is never left implicit.
        _DetailRow(
          icon: LucideIcons.calendar,
          label: 'Due',
          value: task.dueAt == null
              ? 'Not scheduled'
              : formatting.exact(task.dueAt!, now: now),
          emphasize: task.isOverdueAt(now),
          onTap: () => _editDate(context),
        ),
        if (task.reminder != null)
          _DetailRow(
            icon: task.hasReminderProblem
                ? LucideIcons.bellOff
                : LucideIcons.bell,
            label: 'Reminder',
            value: switch (task.reminder!.state) {
              ReminderState.blocked =>
                'Will not arrive — notifications are turned off',
              ReminderState.failed => 'Could not be scheduled',
              ReminderState.delivered => 'Already delivered',
              ReminderState.cancelled => 'Cancelled',
              _ => formatting.exact(task.reminder!.scheduledAt, now: now),
            },
            emphasize: task.hasReminderProblem,
          ),
        if (task.recurrence != null)
          _DetailRow(
            icon: LucideIcons.repeat,
            label: 'Repeats',
            value: formatting.recurrence(task.recurrence!),
          ),
        _DetailRow(
          icon: LucideIcons.flag,
          label: 'Priority',
          value: formatting.priority(task.priority),
          onTap: () => _editPriority(context),
        ),
        if (task.durationMinutes != null)
          _DetailRow(
            icon: LucideIcons.hourglass,
            label: 'Takes',
            value: formatting.duration(task.durationMinutes!),
          ),
        if (task.tags.isNotEmpty)
          _DetailRow(
            icon: LucideIcons.hash,
            label: 'Tags',
            value: task.tags.map((tag) => tag.name).join(', '),
          ),

        const SizedBox(height: Insets.xl),

        Text(
          'NOTES',
          style: context.texts.labelSmall?.copyWith(
            color: semantics.muted,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: Insets.sm),
        // Notes commit when the field loses focus rather than per keystroke,
        // which would thrash the database while someone is still typing.
        Focus(
          onFocusChange: (hasFocus) {
            if (hasFocus) return;
            final value = _notesController.text.trim();
            if (value == (task.notes ?? '')) return;
            service.saveTask(
              task.copyWith(
                notes: value.isEmpty ? null : value,
                clearNotes: value.isEmpty,
              ),
            );
          },
          child: TextField(
            controller: _notesController,
            maxLines: null,
            minLines: 3,
            decoration: const InputDecoration(hintText: 'Supporting details…'),
          ),
        ),

        const SizedBox(height: Insets.xl),

        Text(
          'Created ${formatting.exact(task.createdAt, now: now)}',
          style: context.texts.bodySmall?.copyWith(color: semantics.muted),
        ),
        if (task.completedAt != null)
          Text(
            'Completed ${formatting.exact(task.completedAt!, now: now)}',
            style: context.texts.bodySmall?.copyWith(color: semantics.muted),
          ),
      ],
    );
  }

  Future<void> _editDate(BuildContext context) async {
    final now = ref.read(clockProvider)();
    final initial = task.dueAt ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    final resolved = DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? initial.hour,
      time?.minute ?? initial.minute,
    );

    final service = ref.read(taskServiceProvider);
    final existing = task.reminder;
    final outcome = await service.saveTask(
      task.copyWith(
        dueAt: resolved,
        // Move the reminder with the date; re-arm it so the scheduler books
        // the new time.
        reminder: existing?.copyWith(
          scheduledAt: resolved,
          state: ReminderState.pending,
          clearPlatformId: true,
          clearFailureCode: true,
        ),
      ),
    );

    if (!context.mounted || outcome.reminderWarning == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(outcome.reminderWarning!)));
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
    await ref
        .read(taskServiceProvider)
        .saveTask(task.copyWith(priority: selected));
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
      borderRadius: Corners.card,
      child: Container(
        constraints: const BoxConstraints(minHeight: Insets.minTapTarget),
        padding: const EdgeInsets.symmetric(vertical: Insets.md),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 17, color: color ?? semantics.muted),
            const SizedBox(width: Insets.md),
            SizedBox(
              width: 84,
              child: Text(
                label,
                style: context.texts.bodySmall?.copyWith(
                  color: semantics.muted,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: context.texts.bodyMedium?.copyWith(color: color),
              ),
            ),
            if (onTap != null)
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: semantics.hairline,
              ),
          ],
        ),
      ),
    );
  }
}
