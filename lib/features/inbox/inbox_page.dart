import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../application/providers.dart';
import '../../core/design/app_theme.dart';
import '../../core/design/design_tokens.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/task_list_sliver.dart';

/// Everything captured without a date.
///
/// Explicitly framed as a holding area, not a backlog of failures — a thought
/// you captured but have not scheduled yet is a success for this product.
class InboxPage extends ConsumerWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(inboxTasksProvider);
    final now = ref.watch(clockProvider)();

    return tasks.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => const EmptyState(
        icon: LucideIcons.triangleAlert,
        headline: 'Inbox could not be loaded',
        body: 'Your tasks are unchanged. Try restarting the app.',
      ),
      data: (data) {
        if (data.isEmpty) {
          return CustomScrollView(
            slivers: <Widget>[
              const _Header(count: 0),
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: LucideIcons.inbox,
                  headline: 'Inbox is clear',
                  body:
                      'Anything you capture without a date waits here until '
                      'you decide when to do it.',
                ),
              ),
            ],
          );
        }

        return CustomScrollView(
          slivers: <Widget>[
            _Header(count: data.length),
            TaskListSliver(tasks: data, now: now),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.count});

  final int count;

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Inbox', style: context.texts.headlineMedium),
            const SizedBox(height: Insets.xs),
            Text(
              count == 0 ? 'No undated tasks' : '$count without a date',
              style: context.texts.bodyMedium?.copyWith(
                color: context.semantics.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
