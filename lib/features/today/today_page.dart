import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../application/providers.dart';
import '../../core/design/app_theme.dart';
import '../../core/design/design_tokens.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/task_list_sliver.dart';

/// The default surface: what is due now, what slipped, and what is already
/// done today.
///
/// Overdue comes first and is never merged into the day's list, because the
/// most useful thing this screen can do is surface the commitment that is
/// already failing.
class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(todayTasksProvider);
    final now = ref.watch(clockProvider)();

    return view.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _LoadFailure(error: error),
      data: (data) {
        if (data.isEmpty) {
          return CustomScrollView(
            slivers: <Widget>[
              _TodayHeader(now: now, remaining: 0),
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: LucideIcons.sun,
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
            _TodayHeader(now: now, remaining: data.remaining),

            if (data.overdue.isNotEmpty) ...<Widget>[
              SliverToBoxAdapter(
                child: SectionHeader(
                  label: 'Overdue',
                  trailing: '${data.overdue.length}',
                  emphasized: true,
                ),
              ),
              TaskListSliver(tasks: data.overdue, now: now, showDate: true),
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
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        );
      },
    );
  }
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({required this.now, required this.remaining});

  final DateTime now;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.lg,
          Insets.lg,
          Insets.lg,
          Insets.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              DateFormat('EEEE').format(now),
              style: context.texts.headlineMedium,
            ),
            const SizedBox(height: Insets.xs),
            Text(
              remaining == 0
                  ? DateFormat('d MMMM').format(now)
                  : '${DateFormat('d MMMM').format(now)} · $remaining left',
              style: context.texts.bodyMedium?.copyWith(color: semantics.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: LucideIcons.triangleAlert,
      headline: 'Your tasks could not be read',
      body:
          'The local database did not open. Your data has not been changed. '
          'Restarting the app usually clears this.',
    );
  }
}
