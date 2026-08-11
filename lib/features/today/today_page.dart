import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../application/providers.dart';
import '../../core/design/app_theme.dart';
import '../../core/design/design_tokens.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/progress_ring.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/settings_button.dart';
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
          // Hidden on a day with nothing on it: a ring reading "0 of 0" would
          // be a scolding where the empty state is meant to be a relief.
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
