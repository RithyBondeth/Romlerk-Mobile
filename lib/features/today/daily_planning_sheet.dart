import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/design/app_theme.dart';
import '../../core/design/design_tokens.dart';
import '../../core/widgets/group_card.dart';
import '../../domain/entities/task.dart';

/// Interactive Daily Planning Flow (FR-19 / Journey D).
///
/// Builds a realistic daily plan from active tasks and duration estimates
/// without taking control away from the user.
class DailyPlanningSheet extends ConsumerStatefulWidget {
  const DailyPlanningSheet({required this.tasks, super.key});

  final List<Task> tasks;

  static Future<void> show(BuildContext context, List<Task> tasks) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DailyPlanningSheet(tasks: tasks),
    );
  }

  @override
  ConsumerState<DailyPlanningSheet> createState() => _DailyPlanningSheetState();
}

class _DailyPlanningSheetState extends ConsumerState<DailyPlanningSheet> {
  late final Set<String> _selectedTaskIds = widget.tasks.map((t) => t.id).toSet();

  int get _totalPlannedMinutes {
    var minutes = 0;
    for (final task in widget.tasks) {
      if (_selectedTaskIds.contains(task.id)) {
        minutes += task.durationMinutes ?? 15; // 15m default estimate
      }
    }
    return minutes;
  }

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    final totalHours = (_totalPlannedMinutes / 60.0).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan My Day'),
        leading: IconButton(
          icon: const Icon(LucideIcons.x),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Insets.gutter),
        children: <Widget>[
          GroupCard(
            padding: const EdgeInsets.all(Insets.lg),
            child: Row(
              children: <Widget>[
                Container(
                  width: 38,
                  height: 34,
                  decoration: BoxDecoration(
                    color: semantics.accentSoft,
                    borderRadius: Corners.chip,
                  ),
                  child: Icon(LucideIcons.clock, size: 18, color: context.colors.primary),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Planned Time', style: context.texts.labelSmall?.copyWith(color: semantics.muted)),
                      Text('$totalHours hrs (${_selectedTaskIds.length} tasks)', style: context.texts.titleMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.lg),
          Text(
            'SELECT TASKS FOR TODAY',
            style: context.texts.labelSmall?.copyWith(
              color: semantics.muted,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Insets.sm),
          for (final task in widget.tasks)
            CheckboxListTile(
              value: _selectedTaskIds.contains(task.id),
              onChanged: (selected) {
                setState(() {
                  if (selected == true) {
                    _selectedTaskIds.add(task.id);
                  } else {
                    _selectedTaskIds.remove(task.id);
                  }
                });
              },
              title: Text(task.title),
              subtitle: Text('${task.durationMinutes ?? 15} mins'),
              activeColor: context.colors.primary,
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Insets.gutter),
          child: FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Daily plan saved with ${_selectedTaskIds.length} tasks!'),
                ),
              );
            },
            icon: const Icon(LucideIcons.check, size: 18),
            label: const Text('Confirm Today\'s Plan'),
          ),
        ),
      ),
    );
  }
}
