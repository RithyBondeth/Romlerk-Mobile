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

/// Offline search and filtering across everything stored locally (FR-09).
final searchQueryProvider = StateProvider.autoDispose<TaskQuery>(
  (ref) => const TaskQuery(
    statuses: <TaskStatus>{TaskStatus.active, TaskStatus.completed},
  ),
);

final searchResultsProvider = StreamProvider.autoDispose<List<Task>>((ref) {
  final query = ref.watch(searchQueryProvider);
  return ref.watch(taskRepositoryProvider).watchTasks(query);
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
    final results = ref.watch(searchResultsProvider);
    final now = ref.watch(clockProvider)();
    final tags = ref.watch(tagsProvider).valueOrNull ?? const <dynamic>[];
    final hasQuery = (query.text ?? '').isNotEmpty;

    final resultCount = results.valueOrNull?.length;

    return CustomScrollView(
      slivers: <Widget>[
        SliverPageHeader(
          title: 'Search',
          subtitle: resultCount == null
              ? 'Everything on this device'
              : '$resultCount ${resultCount == 1 ? 'match' : 'matches'}',
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
                hintText: 'Search titles and notes',
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
                        tooltip: 'Clear search',
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
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
            child: Row(
              children: <Widget>[
                _FilterChip(
                  label: 'Open only',
                  selected: !query.statuses.contains(TaskStatus.completed),
                  onSelected: (selected) {
                    final notifier = ref.read(searchQueryProvider.notifier);
                    notifier.state = notifier.state.copyWith(
                      statuses: selected
                          ? const <TaskStatus>{TaskStatus.active}
                          : const <TaskStatus>{
                              TaskStatus.active,
                              TaskStatus.completed,
                            },
                    );
                  },
                ),
                const SizedBox(width: Insets.sm),
                _FilterChip(
                  label: 'High priority',
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
                  label: 'No date',
                  selected: query.onlyUnscheduled,
                  onSelected: (selected) {
                    final notifier = ref.read(searchQueryProvider.notifier);
                    notifier.state = notifier.state.copyWith(
                      onlyUnscheduled: selected,
                    );
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
              headline: 'Search failed',
              body: 'Your tasks are unchanged. Try restarting the app.',
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
                  headline: hasQuery ? 'No matches' : 'Search your tasks',
                  body: hasQuery
                      ? 'Nothing here matches “${query.text}”. '
                            'Filters may also be narrowing the results.'
                      : 'Everything is stored on this device, so search works '
                            'offline.',
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
