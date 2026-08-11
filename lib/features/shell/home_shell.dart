import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../application/providers.dart';
import '../../core/design/app_theme.dart';
import '../../core/design/design_tokens.dart';
import '../../core/design/paper_texture.dart';
import '../../services/notifications/reminder_scheduler.dart';
import '../capture/capture_sheet.dart';
import '../inbox/inbox_page.dart';
import '../search/search_page.dart';
import '../task_detail/task_detail_page.dart';
import '../today/today_page.dart';
import '../upcoming/upcoming_page.dart';

/// Mockup switch. Temporary — delete this and the [PaperBackground] wrapper
/// below once a treatment is picked (or rejected).
const PaperTexture _mockupTexture = PaperTexture.ruled;

/// The app's frame: four surfaces, one persistent capture affordance.
///
/// Capture sits above the navigation bar as a full-width line rather than a
/// floating button. It is the product's primary action and the thing that has
/// to be reachable without thinking, so it gets the width and the label.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];

  @override
  void initState() {
    super.initState();
    // Registers the resume observer that re-probes AI capability and repairs
    // reminder state.
    ref.read(lifecycleReconcilerProvider);
    unawaited(_wireNotifications());
  }

  Future<void> _wireNotifications() async {
    final scheduler = ref.read(reminderSchedulerProvider);
    await scheduler.initialize();
    await ref.read(taskServiceProvider).reconcileReminders();

    _subscriptions.add(
      scheduler.taskOpenRequests.listen((taskId) {
        if (!mounted) return;
        TaskDetailPage.open(context, taskId);
      }),
    );

    // Notification actions are applied here, in the foreground isolate, where
    // the database is available.
    _subscriptions.add(
      scheduler.actionRequests.listen((request) async {
        final service = ref.read(taskServiceProvider);
        switch (request.actionId) {
          case ReminderScheduler.completeActionId:
            await service.completeTask(request.taskId);
          case ReminderScheduler.snoozeActionId:
            await service.snooze(request.taskId);
        }
      }),
    );

    // A notification that launched the app cold.
    final launchTaskId = await scheduler.launchTaskId();
    if (launchTaskId != null && mounted) {
      TaskDetailPage.open(context, launchTaskId);
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;

    return Scaffold(
      body: PaperBackground(
        texture: _mockupTexture,
        child: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _index,
            children: const <Widget>[
              TodayPage(),
              UpcomingPage(),
              InboxPage(),
              SearchPage(),
            ],
          ),
        ),
      ),
      // Capture and navigation share one raised plinth, so the bottom of the
      // screen reads as a single control surface rather than two stacked bars.
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: semantics.raised,
          border: Border(top: BorderSide(color: semantics.hairline)),
          boxShadow: semantics.floatingShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _CaptureBar(onTap: () => CaptureSheet.show(context)),
            NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (index) {
                if (index == _index) return;
                HapticFeedback.selectionClick();
                setState(() => _index = index);
              },
              destinations: const <NavigationDestination>[
                NavigationDestination(
                  icon: Icon(LucideIcons.sun),
                  label: 'Today',
                ),
                NavigationDestination(
                  icon: Icon(LucideIcons.calendarDays),
                  label: 'Upcoming',
                ),
                NavigationDestination(
                  icon: Icon(LucideIcons.inbox),
                  label: 'Inbox',
                ),
                NavigationDestination(
                  icon: Icon(LucideIcons.search),
                  label: 'Search',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Looks like the first line of an empty page, because that is the mental
/// model: write the thought down and move on.
///
/// It stays a full-width line rather than becoming a floating button. Capture
/// is the product's primary action and the thing that has to be reachable
/// without thinking, so it gets the width and the label; the filled ember disc
/// is what marks it as primary.
class _CaptureBar extends StatelessWidget {
  const _CaptureBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter,
        Insets.md,
        Insets.gutter,
        Insets.sm,
      ),
      child: Semantics(
        button: true,
        label: 'Capture a new task',
        child: Material(
          color: semantics.sunken,
          borderRadius: Corners.pill,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            borderRadius: Corners.pill,
            splashColor: semantics.accentSoft,
            child: Container(
              height: 52,
              padding: const EdgeInsets.fromLTRB(6, 6, Insets.lg, 6),
              decoration: BoxDecoration(
                borderRadius: Corners.pill,
                border: Border.all(color: semantics.hairline),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: context.colors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.plus,
                      size: 19,
                      color: context.colors.onPrimary,
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Text(
                      'What needs doing?',
                      style: context.texts.bodyMedium?.copyWith(
                        color: semantics.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
