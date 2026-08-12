import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../application/providers.dart';
import '../../application/task_ranker.dart';
import '../../core/design/app_theme.dart';
import '../../core/design/design_tokens.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/progress_ring.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/settings_button.dart';
import '../../core/widgets/task_list_sliver.dart';
import '../../domain/entities/task.dart';
import 'daily_planning_sheet.dart';

/// The default surface: what is due now, what slipped, and what is already
/// done today.
class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(todayTasksProvider);
    final now = ref.watch(clockProvider)();

    return view.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => const _LoadFailure(),
      data: (data) {
        if (data.isEmpty) {
          return CustomScrollView(
            slivers: <Widget>[
              _TodayHeader(now: now, remaining: 0, completed: 0),
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: LucideIcons.sun,
                  illustration: 'chilling',
                  headline: 'Nothing due today',
                  body:
                      'Anything you capture with a date for today will show '
                      'up here.',
                ),
              ),
            ],
          );
        }

        return CustomScrollView(
          slivers: <Widget>[
            _TodayHeader(
              now: now,
              remaining: data.remaining,
              completed: data.completedToday.length,
            ),

            if (data.overdue.isNotEmpty || data.today.isNotEmpty) ...<Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.gutter,
                    vertical: Insets.xs,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: _FocusSuggestionButton(
                          tasks: <Task>[...data.overdue, ...data.today],
                          now: now,
                        ),
                      ),
                      const SizedBox(width: Insets.sm),
                      IconButton.outlined(
                        tooltip: 'Plan My Day',
                        icon: const Icon(LucideIcons.calendarCheck, size: 18),
                        onPressed: () {
                          DailyPlanningSheet.show(
                            context,
                            <Task>[...data.overdue, ...data.today],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (data.overdue.isNotEmpty) ...<Widget>[
              SliverToBoxAdapter(
                child: SectionHeader(
                  label: 'Overdue',
                  trailing: '${data.overdue.length}',
                  emphasized: true,
                ),
              ),
              TaskListSliver(
                tasks: data.overdue,
                now: now,
                showDate: true,
                accent: context.semantics.overdue,
              ),
            ],

            if (data.today.isNotEmpty) ...<Widget>[
              SliverToBoxAdapter(
                child: SectionHeader(
                  label: 'Today',
                  trailing: '${data.today.length}',
                ),
              ),
              TaskListSliver(tasks: data.today, now: now, showDate: false),
            ],

            if (data.completedToday.isNotEmpty) ...<Widget>[
              SliverToBoxAdapter(
                child: SectionHeader(
                  label: 'Done today',
                  trailing: '${data.completedToday.length}',
                ),
              ),
              TaskListSliver(
                tasks: data.completedToday,
                now: now,
                showDate: false,
              ),
            ],

            // Clearance for the capture bar.
            const SliverToBoxAdapter(
              child: SizedBox(height: Insets.bottomClearance),
            ),
          ],
        );
      },
    );
  }
}

class _FocusSuggestionButton extends ConsumerWidget {
  const _FocusSuggestionButton({required this.tasks, required this.now});

  final List<Task> tasks;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ranker = ref.watch(taskRankerProvider);
    final ranked = ranker.rankTasks(tasks, now: now);
    if (ranked.isEmpty) return const SizedBox.shrink();

    final top = ranked.first;

    return OutlinedButton.icon(
      onPressed: () => _showFocusSheet(context, top, ref),
      icon: const Icon(LucideIcons.sparkles, size: 16),
      label: const Text('What should I do now?'),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.sm,
        ),
      ),
    );
  }

  void _showFocusSheet(BuildContext context, RankedTask ranked, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) {
        final task = ranked.task;
        final semantics = context.semantics;
        return Padding(
          padding: const EdgeInsets.all(Insets.gutter),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    LucideIcons.sparkles,
                    size: 18,
                    color: context.colors.primary,
                  ),
                  const SizedBox(width: Insets.sm),
                  Text('Suggested Focus', style: context.texts.titleMedium),
                ],
              ),
              const SizedBox(height: Insets.md),
              Text(task.title, style: context.texts.headlineSmall),
              const SizedBox(height: Insets.sm),
              Wrap(
                spacing: Insets.xs,
                children: <Widget>[
                  for (final reason in ranked.reasons)
                    Chip(
                      label: Text(reason, style: context.texts.bodySmall),
                      backgroundColor: semantics.raised,
                    ),
                ],
              ),
              const SizedBox(height: Insets.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ref.read(taskServiceProvider).completeTask(task.id);
                  },
                  icon: const Icon(LucideIcons.check, size: 18),
                  label: const Text('Mark Complete'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({
    required this.now,
    required this.remaining,
    required this.completed,
  });

  final DateTime now;
  final int remaining;
  final int completed;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('d MMMM').format(now);

    return SliverPageHeader(
      title: DateFormat('EEEE').format(now),
      subtitle: remaining == 0 ? date : '$date · $remaining left',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (remaining + completed > 0) ...<Widget>[
            ProgressRing(
              completed: completed,
              total: remaining + completed,
              size: 46,
            ),
            const SizedBox(width: Insets.sm),
          ],
          const SettingsButton(),
        ],
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure();

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: LucideIcons.triangleAlert,
      tone: context.semantics.overdue,
      headline: 'Your tasks could not be read',
      body:
          'The local database did not open. Your data has not been changed. '
          'Restarting the app usually clears this.',
    );
  }
}
