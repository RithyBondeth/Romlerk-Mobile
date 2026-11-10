import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/design/app_theme.dart';
import '../../core/design/design_tokens.dart';
import '../../core/widgets/illustrated_content.dart';
import '../../core/widgets/group_card.dart';
import '../../domain/entities/task.dart';
import '../../l10n/l10n.dart';
import '../../application/providers.dart';
import '../../domain/repositories/task_repository.dart';
import '../../domain/enums.dart';

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
  late final Set<String> _selectedTaskIds = widget.tasks
      .map((t) => t.id)
      .toSet();

  bool _loaded = false;
  bool _saving = false;
  bool _loadFailed = false;
  List<Task> _tasks = [];
  late final DateTime _date;
  @override
  void initState() {
    super.initState();
    final now = ref.read(clockProvider)();
    _date = DateTime(now.year, now.month, now.day);
    _load();
  }

  Future<void> _load() async {
    try {
      final saved = await ref.read(dailyPlanStoreProvider).read(_date);
      final all = await ref
          .read(taskRepositoryProvider)
          .fetchTasks(
            const TaskQuery(
              statuses: {TaskStatus.active, TaskStatus.completed},
            ),
          );
      if (!mounted) return;
      setState(() {
        _tasks = all
            .where(
              (t) =>
                  !t.isCompleted ||
                  (saved?.occurrences.containsKey(t.id) ?? false),
            )
            .toList();
        _selectedTaskIds.clear();
        _selectedTaskIds.addAll(saved?.ids ?? widget.tasks.map((t) => t.id));
        _selectedTaskIds.removeWhere((id) => !_tasks.any((t) => t.id == id));
        _loaded = true;
      });
    } on Object {
      if (mounted) setState(() => _loadFailed = true);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.editFailed)));
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(dailyPlanStoreProvider)
          .save(_date, _tasks.where((t) => _selectedTaskIds.contains(t.id)));
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final message = context.l10n.planSaved(
        context.l10n.taskCount(_selectedTaskIds.length),
      );
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.editFailed)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int get _totalPlannedMinutes {
    var minutes = 0;
    for (final task in _tasks) {
      if (_selectedTaskIds.contains(task.id)) {
        minutes += task.durationMinutes ?? 15; // 15m default estimate
      }
    }
    return minutes;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final totalHours = (_totalPlannedMinutes / 60.0).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.planMyDay),
        leading: IconButton(
          icon: const Icon(LucideIcons.x),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: !_loaded
          ? Center(
              child: _loadFailed
                  ? TextButton(
                      onPressed: _load,
                      child: Text(context.l10n.autosaveRetry),
                    )
                  : const CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(Insets.gutter),
              children: <Widget>[
                GroupCard(
                  padding: const EdgeInsets.all(Insets.lg),
                  child: IllustratedContent(
                    illustration: 'meditating',
                    artSize: 80,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.plannedTime, style: context.texts.bodySmall),
                        Text(
                          l10n.plannedSummary(
                            totalHours,
                            l10n.taskCount(_selectedTaskIds.length),
                          ),
                          style: context.texts.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Insets.lg),
                Text(
                  l10n.planSelectTasks,
                  style: context.texts.titleMedium?.copyWith(
                    color: context.colors.onSurface,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: Insets.sm),
                for (final task in _tasks)
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
                    subtitle: Text(
                      ref
                          .read(formattingProvider)
                          .duration(task.durationMinutes ?? 15),
                    ),
                    activeColor: context.colors.primary,
                  ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Insets.gutter),
          child: FilledButton.icon(
            onPressed: _loaded && !_saving ? _save : null,
            icon: const Icon(LucideIcons.check, size: 18),
            label: Text(l10n.planConfirm),
          ),
        ),
      ),
    );
  }
}
