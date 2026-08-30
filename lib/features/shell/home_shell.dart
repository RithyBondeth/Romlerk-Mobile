import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../application/providers.dart';
import '../../core/design/app_theme.dart';
import '../../core/design/design_tokens.dart';
import '../../core/motion/motion_prefs.dart';
import '../../core/motion/pressable.dart';
import '../../core/motion/surface_switcher.dart';
import '../../services/notifications/reminder_scheduler.dart';
import '../capture/capture_sheet.dart';
import '../inbox/inbox_page.dart';
import '../search/search_page.dart';
import '../task_detail/task_detail_page.dart';
import '../today/today_page.dart';
import '../upcoming/upcoming_page.dart';
import '../notes/notes_page.dart';

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
      body: SafeArea(
        bottom: false,
        // Every surface stays mounted, so scroll position and the live
        // queries behind it survive a tab change; only the two taking part
        // in the change are painted.
        child: SurfaceSwitcher(
          index: _index,
          children: const <Widget>[
            TodayPage(),
            UpcomingPage(),
            InboxPage(),
            NotesPage(),
            SearchPage(),
          ],
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
                  selectedIcon: _SelectedIcon(LucideIcons.sun),
                  label: 'Today',
                ),
                NavigationDestination(
                  icon: Icon(LucideIcons.calendarDays),
                  selectedIcon: _SelectedIcon(LucideIcons.calendarDays),
                  label: 'Upcoming',
                ),
                NavigationDestination(
                  icon: Icon(LucideIcons.inbox),
                  selectedIcon: _SelectedIcon(LucideIcons.inbox),
                  label: 'Inbox',
                ),
                NavigationDestination(
                  icon: Icon(LucideIcons.fileText),
                  selectedIcon: _SelectedIcon(LucideIcons.fileText),
                  label: 'Notes',
                ),
                NavigationDestination(
                  icon: Icon(LucideIcons.search),
                  selectedIcon: _SelectedIcon(LucideIcons.search),
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
        // Pressed state is carried by scale as well as by the ripple: this is
        // the one control the user reaches for without looking, so it should
        // answer on the same frame as the finger rather than after the tap
        // resolves.
        child: Pressable(
          scale: 0.985,
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
      ),
    );
  }
}

/// The icon shown for the destination the user is on.
///
/// [NavigationBar] builds this widget only when its destination becomes
/// selected, which is what lets a plain `initState` stand in for a selection
/// callback: the pop is a one-shot that plays exactly when selection happens
/// and never at any other time.
class _SelectedIcon extends StatefulWidget {
  const _SelectedIcon(this.icon);

  final IconData icon;

  @override
  State<_SelectedIcon> createState() => _SelectedIconState();
}

class _SelectedIconState extends State<_SelectedIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.fast,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_controller.isDismissed) return;
    // Jumped to the end, not left at rest, under reduced motion. The sequence
    // *starts* at 0.82, so parking the controller at zero would render the
    // selected icon permanently undersized for the one user this branch exists
    // to look after.
    if (context.prefersReducedMotion) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Overshoots to 1.18 and settles, rather than growing to a new resting
  /// size: the icon should acknowledge the tap, not become a bigger icon.
  ///
  /// Static so selecting a tab does not rebuild the sequence.
  static final Animatable<double> _pop = TweenSequence<double>(
    <TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 0.82,
          end: 1.18,
        ).chain(CurveTween(curve: Motion.decelerate)),
        weight: 42,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1.18,
          end: 1,
        ).chain(CurveTween(curve: Motion.settle)),
        weight: 58,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _controller.drive(_pop),
      child: Icon(widget.icon),
    );
  }
}
