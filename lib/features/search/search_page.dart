import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../application/providers.dart';
import '../../core/design/app_theme.dart';
import '../../core/design/design_tokens.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/settings_button.dart';
import '../../core/widgets/task_list_sliver.dart';
import '../../domain/entities/task.dart';
import '../../domain/enums.dart';
import '../../domain/repositories/task_repository.dart';
import '../../l10n/l10n.dart';

/// Which slice of the task set Search shows. With no text typed, these are
/// the All Tasks and Completed views of FR-08.
enum TaskStatusView {
  all(<TaskStatus>{TaskStatus.active, TaskStatus.completed}),
  open(<TaskStatus>{TaskStatus.active}),
  completed(<TaskStatus>{TaskStatus.completed});

  const TaskStatusView(this.statuses);

  final Set<TaskStatus> statuses;

  static TaskStatusView of(TaskQuery query) {
    final hasActive = query.statuses.contains(TaskStatus.active);
    final hasCompleted = query.statuses.contains(TaskStatus.completed);
    if (hasActive && !hasCompleted) return open;
    if (hasCompleted && !hasActive) return completed;
    return all;
  }
}

/// Offline search and filtering across everything stored locally (FR-09).
final searchQueryProvider = StateProvider.autoDispose<TaskQuery>(
  (ref) => const TaskQuery(
    statuses: <TaskStatus>{TaskStatus.active, TaskStatus.completed},
  ),
);

/// Filter by when a task is due (FR-09). One at a time: the windows overlap,
/// and "Today" plus "Overdue" together would read as "or" to some people
/// and "and" to others.
enum DueWindow {
  overdue,
  today,
  next7Days;

  /// [query] narrowed to this window, or null when the combination can
  /// match nothing (overdue while viewing only completed tasks: a finished
  /// task is never overdue).
  TaskQuery? apply(TaskQuery query, DateTime now) {
    final startOfToday = DateTime(now.year, now.month, now.day);
    final dated = query.copyWith(onlyUnscheduled: false);
    switch (this) {
      case DueWindow.overdue:
        if (!query.statuses.contains(TaskStatus.active)) return null;
        return dated.copyWith(
          statuses: const <TaskStatus>{TaskStatus.active},
          dueBefore: now,
          clearDueAfter: true,
        );
      case DueWindow.today:
        return dated.copyWith(
          dueAfter: startOfToday,
          dueBefore: DateTime(now.year, now.month, now.day + 1),
        );
      case DueWindow.next7Days:
        return dated.copyWith(
          dueAfter: startOfToday,
          dueBefore: DateTime(now.year, now.month, now.day + 7),
        );
    }
  }
}

final dueWindowProvider = StateProvider.autoDispose<DueWindow?>((ref) => null);

final searchResultsProvider = StreamProvider.autoDispose<List<Task>>((ref) {
  final query = ref.watch(searchQueryProvider);
  final window = ref.watch(dueWindowProvider);
  final effective = window == null
      ? query
      : window.apply(query, ref.watch(clockProvider)());
  if (effective == null) return Stream<List<Task>>.value(const <Task>[]);
  return ref.watch(taskRepositoryProvider).watchTasks(effective);
});

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Debounced so each keystroke does not fire a query, which keeps typing
  /// responsive while the database works (NFR-04).
  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      final notifier = ref.read(searchQueryProvider.notifier);
      notifier.state = value.trim().isEmpty
          ? notifier.state.copyWith(clearText: true)
          : notifier.state.copyWith(text: value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final window = ref.watch(dueWindowProvider);
    final results = ref.watch(searchResultsProvider);
    final now = ref.watch(clockProvider)();
    final tags = ref.watch(tagsProvider).valueOrNull ?? const <dynamic>[];
    final hasQuery = (query.text ?? '').isNotEmpty;
    final view = TaskStatusView.of(query);
    final narrowed =
        hasQuery ||
        query.priorities.isNotEmpty ||
        query.tagIds.isNotEmpty ||
        query.onlyUnscheduled ||
        window != null;

    final resultCount = results.valueOrNull?.length;
    final l10n = context.l10n;

    return CustomScrollView(
      slivers: <Widget>[
        SliverPageHeader(
          title: l10n.search,
          subtitle: resultCount == null
              ? l10n.searchEverything
              : narrowed
              ? l10n.searchMatches(resultCount)
              : switch (view) {
                  TaskStatusView.all => l10n.taskCount(resultCount),
                  TaskStatusView.open => l10n.searchOpenCount(resultCount),
                  TaskStatusView.completed => l10n.searchDoneCount(resultCount),
                },
          trailing: const SettingsButton(),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.gutter,
              0,
              Insets.gutter,
              Insets.md,
            ),
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              style: context.texts.bodyLarge,
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                filled: true,
                fillColor: context.semantics.raised,
                prefixIcon: Icon(
                  LucideIcons.search,
                  size: 18,
                  color: context.semantics.muted,
                ),
                suffixIcon: hasQuery
                    ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 17),
                        tooltip: l10n.searchClear,
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                        },
                      )
                    : null,
                border: const OutlineInputBorder(
                  borderRadius: Corners.pill,
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: Corners.pill,
                  borderSide: BorderSide(color: context.semantics.hairline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: Corners.pill,
                  borderSide: BorderSide(
                    color: context.colors.primary,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.gutter,
              0,
              Insets.gutter,
              Insets.md,
            ),
            child: SegmentedButton<TaskStatusView>(
              showSelectedIcon: false,
              segments: <ButtonSegment<TaskStatusView>>[
                ButtonSegment<TaskStatusView>(
                  value: TaskStatusView.all,
                  label: Text(l10n.viewAll),
                ),
                ButtonSegment<TaskStatusView>(
                  value: TaskStatusView.open,
                  label: Text(l10n.viewOpen),
                ),
                ButtonSegment<TaskStatusView>(
                  value: TaskStatusView.completed,
                  icon: const Icon(LucideIcons.check, size: 15),
                  label: Text(l10n.viewDone),
                ),
              ],
              selected: <TaskStatusView>{view},
              onSelectionChanged: (selection) {
                final notifier = ref.read(searchQueryProvider.notifier);
                notifier.state = notifier.state.copyWith(
                  statuses: selection.single.statuses,
                );
              },
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
            child: Row(
              children: <Widget>[
                for (final (option, label) in <(DueWindow, String)>[
                  (DueWindow.overdue, l10n.overdue),
                  (DueWindow.today, l10n.today),
                  (DueWindow.next7Days, l10n.filterNext7Days),
                ]) ...<Widget>[
                  _FilterChip(
                    label: label,
                    selected: window == option,
                    onSelected: (selected) {
                      ref.read(dueWindowProvider.notifier).state = selected
                          ? option
                          : null;
                      // A due window and "No date" cannot both hold.
                      if (selected && query.onlyUnscheduled) {
                        final notifier = ref.read(searchQueryProvider.notifier);
                        notifier.state = notifier.state.copyWith(
                          onlyUnscheduled: false,
                        );
                      }
                    },
                  ),
                  const SizedBox(width: Insets.sm),
                ],
                _FilterChip(
                  label: l10n.filterHighPriority,
                  selected: query.priorities.contains(TaskPriority.high),
                  onSelected: (selected) {
                    final notifier = ref.read(searchQueryProvider.notifier);
                    notifier.state = notifier.state.copyWith(
                      priorities: selected
                          ? const <TaskPriority>{TaskPriority.high}
                          : const <TaskPriority>{},
                    );
                  },
                ),
                const SizedBox(width: Insets.sm),
                _FilterChip(
                  label: l10n.filterNoDate,
                  selected: query.onlyUnscheduled,
                  onSelected: (selected) {
                    final notifier = ref.read(searchQueryProvider.notifier);
                    notifier.state = notifier.state.copyWith(
                      onlyUnscheduled: selected,
                    );
                    if (selected) {
                      ref.read(dueWindowProvider.notifier).state = null;
                    }
                  },
                ),
                for (final tag in tags) ...<Widget>[
                  const SizedBox(width: Insets.sm),
                  _FilterChip(
                    label: '#${tag.name}',
                    selected: query.tagIds.contains(tag.id),
                    onSelected: (selected) {
                      final notifier = ref.read(searchQueryProvider.notifier);
                      final next = Set<String>.of(notifier.state.tagIds);
                      selected ? next.add(tag.id) : next.remove(tag.id);
                      notifier.state = notifier.state.copyWith(tagIds: next);
                    },
                  ),
                ],
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: Insets.md)),

        results.when(
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(Insets.xxl),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, _) => SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: LucideIcons.triangleAlert,
              tone: context.semantics.overdue,
              headline: l10n.searchFailed,
              body: l10n.loadFailedBody,
            ),
          ),
          data: (data) {
            if (data.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: hasQuery ? LucideIcons.searchX : LucideIcons.search,
                  // A drawing for the resting state; a plain icon once a query
                  // has come back empty, where the user wants an answer rather
                  // than a picture.
                  illustration: hasQuery ? null : 'reading',
                  headline: hasQuery
                      ? l10n.searchNoMatches
                      : view == TaskStatusView.completed
                      ? l10n.searchNothingDone
                      : l10n.searchYourTasks,
                  body: hasQuery
                      ? l10n.searchNoMatchesBody(query.text!)
                      : view == TaskStatusView.completed
                      ? l10n.searchNothingDoneBody
                      : l10n.searchOfflineBody,
                ),
              );
            }
            return TaskListSliver(tasks: data, now: now);
          },
        ),

        const SliverToBoxAdapter(
          child: SizedBox(height: Insets.bottomClearance),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;

    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      backgroundColor: semantics.raised,
      selectedColor: semantics.accentSoft,
      labelStyle: context.texts.labelMedium?.copyWith(
        color: selected ? context.colors.primary : context.colors.onSurface,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide(
        color: selected
            ? context.colors.primary.withValues(alpha: 0.45)
            : semantics.hairline,
      ),
    );
  }
}
