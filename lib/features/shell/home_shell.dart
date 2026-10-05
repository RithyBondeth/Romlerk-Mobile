import '../../application/capture_controller.dart';
import '../../services/capture/system_capture_service.dart';
import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../application/providers.dart';
import '../../core/design/app_theme.dart';
import '../../core/design/design_tokens.dart';
import '../../core/motion/pressable.dart';
import '../../core/motion/surface_switcher.dart';
import '../../services/notifications/notification_actions.dart';
import '../capture/capture_sheet.dart';
import '../inbox/inbox_page.dart';
import '../search/search_page.dart';
import '../task_detail/task_detail_page.dart';
import '../today/today_page.dart';
import '../upcoming/upcoming_page.dart';
import '../notes/notes_page.dart';
import '../../l10n/l10n.dart';
import 'floating_navigation_bar.dart';

/// Five persistent destinations and one thumb-reachable capture action.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  late final SystemCaptureService _systemCapture;
  Timer? _captureRetry;
  bool _openingCapture = false;
  int _index = 0;
  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];
  final ReceivePort _actionPort = ReceivePort();

  @override
  void initState() {
    super.initState();
    // Registers the resume observer that re-probes AI capability and repairs
    // reminder state.
    ref.read(lifecycleReconcilerProvider);
    unawaited(_wireNotifications());
    WidgetsBinding.instance.addObserver(this);
    _systemCapture = ref.read(systemCaptureServiceProvider);
    _systemCapture.listen(_drainCapture);
    WidgetsBinding.instance.addPostFrameCallback((_) => _drainCapture());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _drainCapture());
    }
  }

  Future<void> _drainCapture() async {
    if (_openingCapture || !mounted || !ref.read(appUnlockedProvider)) return;
    _openingCapture = true;
    try {
      while (mounted && ref.read(appUnlockedProvider)) {
        if (!mounted) return;
        // Do not consume a request while another editor/dialog is on top.
        if (!(ModalRoute.of(context)?.isCurrent ?? false)) {
          _captureRetry?.cancel();
          _captureRetry = Timer(
            const Duration(milliseconds: 500),
            _drainCapture,
          );
          return;
        }
        final request = await _systemCapture.peek();
        if (request == null || !mounted) return;
        final controller = ref.read(captureControllerProvider.notifier);
        await controller.load();
        if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
        final saved = controller.snapshot;
        if (saved.nativeRequestId == request.id) {
          // Recovery after termination between durable storage and native ack.
          await _systemCapture.acknowledge(request.id);
          return;
        }
        if (saved.input.isNotEmpty || saved.drafts.isNotEmpty) return;
        if (!mounted || !ref.read(appUnlockedProvider)) return;
        controller.recover(
          CaptureState(input: request.text, nativeRequestId: request.id),
        );
        if (!await controller.autosave.flush()) return;
        await _systemCapture.acknowledge(request.id);
        if (!mounted || !ref.read(appUnlockedProvider)) return;
        await CaptureSheet.show(context, initialText: request.text);
        if (controller.snapshot.input.isNotEmpty ||
            controller.snapshot.drafts.isNotEmpty) {
          return;
        }
      }
    } on Object {
      // The normal capture bar remains available on unsupported platforms.
    } finally {
      _openingCapture = false;
    }
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

    // Complete and Snooze are applied in the notification-action isolate
    // (see notificationTapBackground), which signals here when it changes a
    // task so the lists on screen update at once.
    IsolateNameServer.removePortNameMapping(notificationActionPortName);
    IsolateNameServer.registerPortWithName(
      _actionPort.sendPort,
      notificationActionPortName,
    );
    _subscriptions.add(
      _actionPort.listen((_) {
        refreshAfterExternalWrite(ref.read(appDatabaseProvider));
      }),
    );

    // Should a platform ever route an action to the running app instead,
    // it is applied the same way.
    _subscriptions.add(
      scheduler.actionRequests.listen((request) async {
        await applyNotificationAction(
          ref.read(taskServiceProvider),
          taskId: request.taskId,
          actionId: request.actionId,
        );
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
    WidgetsBinding.instance.removeObserver(this);
    _captureRetry?.cancel();
    _systemCapture.listen(() async {});
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    IsolateNameServer.removePortNameMapping(notificationActionPortName);
    _actionPort.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appUnlockedProvider, (_, unlocked) {
      if (unlocked) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _drainCapture());
      }
    });
    final dockInset = MediaQuery.sizeOf(context).width < 360
        ? Insets.sm
        : Insets.lg;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        // Every surface stays mounted, so scroll position and the live
        // queries behind it survive a tab change; only the two taking part
        // in the change are painted.
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
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
        ),
      ),
      // The transparent space around both controls lets the dock float.
      // Scaffold reserves its height so the last row stays reachable.
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: Insets.md),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: EdgeInsets.fromLTRB(dockInset, Insets.sm, dockInset, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _CaptureBar(
                    onTap: () async {
                      if (_openingCapture) return;
                      _openingCapture = true;
                      try {
                        await CaptureSheet.show(context);
                      } finally {
                        _openingCapture = false;
                      }
                      await _drainCapture();
                    },
                  ),
                  const SizedBox(height: Insets.md),
                  MediaQuery.removePadding(
                    context: context,
                    removeBottom: true,
                    child: FloatingNavigationBar(
                      selectedIndex: _index,
                      onDestinationSelected: (index) {
                        if (index == _index) return;
                        final focus = FocusManager.instance.primaryFocus;
                        // Dismiss a text-field keyboard while preserving focus
                        // when the user navigates the dock with a keyboard.
                        final focusedItem = focus?.context
                            ?.findAncestorWidgetOfExactType<
                              FloatingNavigationItem
                            >();
                        if (focusedItem == null) {
                          focus?.unfocus();
                        }
                        HapticFeedback.selectionClick();
                        setState(() => _index = index);
                      },
                      destinations: <FloatingNavigationDestination>[
                        FloatingNavigationDestination(
                          icon: LucideIcons.sun,
                          label: context.l10n.today,
                        ),
                        FloatingNavigationDestination(
                          icon: LucideIcons.calendarDays,
                          label: context.l10n.upcoming,
                        ),
                        FloatingNavigationDestination(
                          icon: LucideIcons.inbox,
                          label: context.l10n.inbox,
                        ),
                        FloatingNavigationDestination(
                          icon: LucideIcons.fileText,
                          label: context.l10n.notes,
                        ),
                        FloatingNavigationDestination(
                          icon: LucideIcons.search,
                          label: context.l10n.search,
                        ),
                      ],
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

/// A labelled primary action that stays within thumb reach on every tab.
class _CaptureBar extends StatelessWidget {
  const _CaptureBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: Corners.card,
        boxShadow: semantics.floatingShadow,
      ),
      child: Semantics(
        button: true,
        label: context.l10n.captureBarLabel,
        // Pressed state is carried by scale as well as by the ripple: this is
        // the one control the user reaches for without looking, so it should
        // answer on the same frame as the finger rather than after the tap
        // resolves.
        child: Pressable(
          scale: 0.985,
          child: Material(
            color: context.colors.primary,
            borderRadius: Corners.card,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onTap();
              },
              borderRadius: Corners.card,
              splashColor: semantics.accentSoft,
              child: Container(
                constraints: const BoxConstraints(minHeight: 56),
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.lg,
                  vertical: Insets.sm,
                ),
                decoration: BoxDecoration(borderRadius: Corners.card),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: context.colors.onPrimary.withValues(alpha: 0.14),
                        borderRadius: Corners.chip,
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
                        context.l10n.captureBarLabel,
                        style: context.texts.bodyMedium?.copyWith(
                          color: context.colors.onPrimary,
                          fontWeight: FontWeight.w500,
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
