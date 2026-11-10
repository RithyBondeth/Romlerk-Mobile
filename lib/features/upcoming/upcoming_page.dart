import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../application/providers.dart';
import '../../core/design/app_theme.dart';
import '../../core/design/design_tokens.dart';
import '../../core/widgets/illustrated_content.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/task_list_loading.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/settings_button.dart';
import '../../core/widgets/task_list_sliver.dart';
import '../../l10n/l10n.dart';

/// Future workload, grouped by day.
///
/// Days with nothing in them are omitted rather than rendered empty: the point
/// of this screen is to see the shape of the week, not to browse a calendar.
class UpcomingPage extends ConsumerStatefulWidget {
  const UpcomingPage({super.key});

  @override
  ConsumerState<UpcomingPage> createState() => _UpcomingPageState();
}

class _UpcomingPageState extends ConsumerState<UpcomingPage> {
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final days = ref.watch(upcomingTasksProvider);
    final now = ref.watch(clockProvider)();
    final formatting = ref.watch(formattingProvider);

    return days.when(
      loading: () => const TaskListLoading(),
      error: (error, _) => EmptyState(
        icon: LucideIcons.triangleAlert,
        tone: context.semantics.overdue,
        headline: context.l10n.upcomingLoadFailed,
        body: context.l10n.loadFailedBody,
      ),
      data: (data) {
        if (data.isEmpty) {
          return CustomScrollView(
            slivers: <Widget>[
              const _Header(days: 0, tasks: 0),
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: LucideIcons.calendarDays,
                  illustration: 'strolling',
                  headline: context.l10n.upcomingEmptyTitle,
                  body: context.l10n.upcomingEmptyBody,
                ),
              ),
            ],
          );
        }

        final total = data.fold<int>(0, (sum, day) => sum + day.tasks.length);

        return CustomScrollView(
          slivers: <Widget>[
            _Header(days: data.length, tasks: total),
            SliverToBoxAdapter(
              child: IllustratedBanner(
                illustration: 'strolling',
                title: context.l10n.upcomingIllustrationTitle,
              ),
            ),
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(
                  Insets.gutter,
                  Insets.sm,
                  Insets.gutter,
                  Insets.xs,
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: Insets.sm),
                      child: ChoiceChip(
                        label: Text(context.l10n.viewAll),
                        selected:
                            _selectedDay == null ||
                            !data.any((d) => d.day == _selectedDay),
                        onSelected: (_) => setState(() => _selectedDay = null),
                      ),
                    ),
                    for (final day in data)
                      Padding(
                        padding: const EdgeInsets.only(right: Insets.sm),
                        child: ChoiceChip(
                          label: Text(formatting.dayHeading(day.day, now: now)),
                          selected: _selectedDay == day.day,
                          onSelected: (selected) => setState(
                            () => _selectedDay = selected ? day.day : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            for (final group in data.where(
              (d) =>
                  _selectedDay == null ||
                  !data.any((d) => d.day == _selectedDay) ||
                  d.day == _selectedDay,
            )) ...<Widget>[
              SliverToBoxAdapter(
                child: SectionHeader(
                  label: formatting.dayHeading(group.day, now: now),
                  trailing: '${group.tasks.length}',
                ),
              ),
              TaskListSliver(tasks: group.tasks, now: now, showDate: false),
            ],
            const SliverToBoxAdapter(
              child: SizedBox(height: Insets.bottomClearance),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.days, required this.tasks});

  final int days;
  final int tasks;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SliverPageHeader(
      title: l10n.upcoming,
      subtitle: tasks == 0
          ? l10n.nothingScheduled
          : l10n.upcomingSubtitle(l10n.taskCount(tasks), l10n.dayCount(days)),
      trailing: const SettingsButton(),
    );
  }
}
