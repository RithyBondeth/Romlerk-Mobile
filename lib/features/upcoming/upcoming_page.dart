import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../application/providers.dart';
import '../../core/design/app_theme.dart';
import '../../core/design/design_tokens.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/task_list_sliver.dart';

/// Future workload, grouped by day.
///
/// Days with nothing in them are omitted rather than rendered empty: the point
/// of this screen is to see the shape of the week, not to browse a calendar.
class UpcomingPage extends ConsumerWidget {
  const UpcomingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(upcomingTasksProvider);
    final now = ref.watch(clockProvider)();
    final formatting = ref.watch(formattingProvider);

    return days.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => const EmptyState(
        icon: LucideIcons.triangleAlert,
        headline: 'Upcoming could not be loaded',
        body: 'Your tasks are unchanged. Try restarting the app.',
      ),
      data: (data) {
        if (data.isEmpty) {
          return CustomScrollView(
            slivers: <Widget>[
              const _Header(),
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: LucideIcons.calendarDays,
                  headline: 'Nothing scheduled ahead',
                  body:
                      'Tasks with a date after today will be grouped here by '
                      'day.',
                ),
              ),
            ],
          );
        }

        return CustomScrollView(
          slivers: <Widget>[
            const _Header(),
            for (final group in data) ...<Widget>[
              SliverToBoxAdapter(
                child: SectionHeader(
                  label: formatting.dayHeading(group.day, now: now),
                  trailing: '${group.tasks.length}',
                ),
              ),
              TaskListSliver(
                tasks: group.tasks,
                now: now,
                showDate: false,
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.lg,
          Insets.lg,
          Insets.lg,
          Insets.sm,
        ),
        child: Text('Upcoming', style: context.texts.headlineMedium),
      ),
    );
  }
}
