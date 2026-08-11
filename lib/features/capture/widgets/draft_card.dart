import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../application/providers.dart';
import '../../../core/design/app_theme.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/widgets/group_card.dart';
import '../../../domain/drafts/task_draft.dart';
import '../../../domain/enums.dart';

/// An editable proposal for one task.
///
/// This is the screen the BRD's whole "preview before consequence" principle
/// rests on. Three rules shape it:
///  * the resolved date is shown in full, never as the phrase the user typed;
///  * anything the parser assumed is stated plainly;
///  * anything it could not resolve blocks saving until the user chooses.
class DraftCard extends ConsumerWidget {
  const DraftCard({
    required this.draft,
    required this.onChanged,
    this.onRemove,
    super.key,
  });

  final TaskDraft draft;
  final ValueChanged<TaskDraft> onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatting = ref.watch(formattingProvider);
    final now = ref.watch(clockProvider)();
    final semantics = context.semantics;

    return GroupCard(
      accent: draft.hasAmbiguities ? semantics.caution : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: TextFormField(
                  initialValue: draft.title,
                  style: context.texts.titleMedium,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (value) => onChanged(
                    draft.copyWith(title: value).resolving(DraftField.title),
                  ),
                ),
              ),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(LucideIcons.x, size: 17),
                  tooltip: 'Remove this task',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 30,
                    height: 30,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: semantics.sunken,
                    shape: const RoundedRectangleBorder(
                      borderRadius: Corners.pill,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: Insets.md),

          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            children: <Widget>[
              _DateChip(
                draft: draft,
                now: now,
                label: draft.dueAt == null
                    ? 'Add a date'
                    : formatting.exact(draft.dueAt!, now: now),
                onChanged: onChanged,
              ),
              _PriorityChip(draft: draft, onChanged: onChanged),
              if (draft.recurrence != null)
                _StaticChip(
                  icon: LucideIcons.repeat,
                  label: formatting.recurrence(draft.recurrence!),
                  onClear: () =>
                      onChanged(draft.copyWith(clearRecurrence: true)),
                ),
              if (draft.durationMinutes != null)
                _StaticChip(
                  icon: LucideIcons.hourglass,
                  label: draft.durationIsEstimate
                      ? '${formatting.duration(draft.durationMinutes!)} (estimate)'
                      : formatting.duration(draft.durationMinutes!),
                  onClear: () => onChanged(draft.copyWith(clearDuration: true)),
                ),
              for (final tag in draft.tags)
                _StaticChip(
                  icon: LucideIcons.hash,
                  label: tag,
                  onClear: () => onChanged(
                    draft.copyWith(
                      tags: draft.tags.where((it) => it != tag).toList(),
                    ),
                  ),
                ),
            ],
          ),

          // Reminder line, stated separately from the due date because it is
          // the part with a real-world consequence.
          if (draft.reminderAt != null) ...<Widget>[
            const SizedBox(height: Insets.md),
            _ReminderStrip(
              icon: LucideIcons.bell,
              iconColor: context.colors.primary,
              label:
                  'Reminds you ${formatting.exact(draft.reminderAt!, now: now)}',
              actionLabel: 'Off',
              onAction: () => onChanged(draft.copyWith(clearReminderAt: true)),
            ),
          ] else if (draft.dueAt != null) ...<Widget>[
            const SizedBox(height: Insets.md),
            _ReminderStrip(
              icon: LucideIcons.bellOff,
              iconColor: semantics.muted,
              label: 'No reminder',
              actionLabel: 'Remind me',
              onAction: () => onChanged(draft.copyWith(reminderAt: draft.dueAt)),
            ),
          ],

          for (final ambiguity in draft.ambiguities) ...<Widget>[
            const SizedBox(height: Insets.md),
            _AmbiguityPrompt(
              ambiguity: ambiguity,
              onResolve: (choice) {
                var updated = draft;
                if (choice.dateTime != null) {
                  updated = updated.copyWith(
                    dueAt: choice.dateTime,
                    reminderAt: choice.dateTime,
                  );
                }
                onChanged(updated.resolving(ambiguity.field));
              },
            ),
          ],

          for (final warning in draft.warnings) ...<Widget>[
            const SizedBox(height: Insets.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(LucideIcons.info, size: 13, color: semantics.muted),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    warning.message,
                    style: context.texts.bodySmall?.copyWith(
                      color: semantics.muted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The reminder line, set apart from the chips because it is the part of a
/// draft with a real-world consequence: something will make a noise later.
class _ReminderStrip extends StatelessWidget {
  const _ReminderStrip({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;

    return Container(
      padding: const EdgeInsets.fromLTRB(Insets.md, Insets.xs, Insets.xs, Insets.xs),
      decoration: BoxDecoration(
        color: semantics.sunken,
        borderRadius: Corners.chip,
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              label,
              style: context.texts.bodySmall?.copyWith(
                color: context.colors.onSurface,
              ),
            ),
          ),
          _MiniAction(label: actionLabel, onTap: onAction),
        ],
      ),
    );
  }
}

/// An unresolved question, with one-tap answers.
///
/// Rendered as a question rather than a "low confidence" badge, per the BRD's
/// copy guidance: explain *why* the field needs attention.
class _AmbiguityPrompt extends StatelessWidget {
  const _AmbiguityPrompt({required this.ambiguity, required this.onResolve});

  final DraftAmbiguity ambiguity;
  final ValueChanged<DraftAlternative> onResolve;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: semantics.cautionSoft,
        borderRadius: Corners.card,
        border: Border.all(color: semantics.caution.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                LucideIcons.circleHelp,
                size: 15,
                color: semantics.caution,
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  ambiguity.reason,
                  style: context.texts.bodySmall?.copyWith(
                    color: context.colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          if (ambiguity.alternatives.isNotEmpty) ...<Widget>[
            const SizedBox(height: Insets.sm),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: <Widget>[
                for (final alternative in ambiguity.alternatives)
                  ActionChip(
                    label: Text(alternative.label),
                    onPressed: () => onResolve(alternative),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.draft,
    required this.now,
    required this.label,
    required this.onChanged,
  });

  final TaskDraft draft;
  final DateTime now;
  final String label;
  final ValueChanged<TaskDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    final hasDate = draft.dueAt != null;
    return ActionChip(
      avatar: Icon(
        LucideIcons.calendar,
        size: 15,
        color: hasDate ? context.colors.primary : context.semantics.muted,
      ),
      label: Text(label),
      onPressed: () => _pick(context),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final initial = draft.dueAt ?? now;
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

    // Choosing a date explicitly answers any question the parser had about it.
    onChanged(
      draft
          .copyWith(
            dueAt: resolved,
            reminderAt: resolved.isAfter(now) ? resolved : null,
            clearReminderAt: !resolved.isAfter(now),
          )
          .resolving(DraftField.dueAt),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.draft, required this.onChanged});

  final TaskDraft draft;
  final ValueChanged<TaskDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    final color = switch (draft.priority) {
      TaskPriority.high => semantics.overdue,
      TaskPriority.medium => context.colors.primary,
      TaskPriority.low => semantics.muted,
      TaskPriority.none => semantics.muted,
    };

    return PopupMenuButton<TaskPriority>(
      tooltip: 'Priority',
      onSelected: (value) => onChanged(draft.copyWith(priority: value)),
      itemBuilder: (context) => <PopupMenuEntry<TaskPriority>>[
        for (final priority in TaskPriority.values)
          PopupMenuItem<TaskPriority>(
            value: priority,
            child: Text(switch (priority) {
              TaskPriority.none => 'No priority',
              TaskPriority.low => 'Low',
              TaskPriority.medium => 'Medium',
              TaskPriority.high => 'High',
            }),
          ),
      ],
      child: Chip(
        avatar: Icon(LucideIcons.flag, size: 15, color: color),
        label: Text(switch (draft.priority) {
          TaskPriority.none => 'Priority',
          TaskPriority.low => 'Low',
          TaskPriority.medium => 'Medium',
          TaskPriority.high => 'High',
        }),
      ),
    );
  }
}

class _StaticChip extends StatelessWidget {
  const _StaticChip({
    required this.icon,
    required this.label,
    required this.onClear,
  });

  final IconData icon;
  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 15, color: context.semantics.muted),
      label: Text(label),
      onDeleted: onClear,
      deleteIcon: const Icon(LucideIcons.x, size: 14),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
        textStyle: context.texts.labelMedium,
      ),
      child: Text(label),
    );
  }
}
