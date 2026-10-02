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
import '../../l10n/l10n.dart';

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
      error: (error, _) => EmptyState(
        icon: LucideIcons.triangleAlert,
        tone: context.semantics.overdue,
        headline: context.l10n.inboxLoadFailed,
        body: context.l10n.loadFailedBody,
      ),
      data: (data) {
        if (data.isEmpty) {
          return CustomScrollView(
            slivers: <Widget>[
              const _Header(count: 0),
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: LucideIcons.inbox,
                  illustration: 'unboxing',
                  headline: context.l10n.inboxEmptyTitle,
                  body: context.l10n.inboxEmptyBody,
                ),
              ),
            ],
          );
        }

        return CustomScrollView(
          slivers: <Widget>[
            _Header(count: data.length),
            const SliverToBoxAdapter(child: SizedBox(height: Insets.sm)),
            TaskListSliver(tasks: data, now: now),
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
  const _Header({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SliverPageHeader(
      title: context.l10n.inbox,
      subtitle: count == 0
          ? context.l10n.inboxSubtitleEmpty
          : context.l10n.inboxSubtitle(count),
      trailing: const SettingsButton(),
    );
  }
}
