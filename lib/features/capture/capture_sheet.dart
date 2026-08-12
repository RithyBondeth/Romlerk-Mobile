import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../application/capture_controller.dart';
import '../../application/providers.dart';
import '../../core/design/app_theme.dart';
import '../../core/design/design_tokens.dart';
import '../../core/motion/motion_prefs.dart';
import '../../core/widgets/capability_notice.dart';
import '../../core/widgets/group_card.dart';
import '../../local_ai/local_ai_error.dart';
import 'widgets/draft_card.dart';

/// Quick capture: the fastest path from a thought to a saved commitment.
///
/// One surface handles typing, parsing, and reviewing, because every extra
/// screen between the thought and the save is exactly the interruption the
/// product exists to remove. Nothing is written until the user confirms.
class CaptureSheet extends ConsumerStatefulWidget {
  const CaptureSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      sheetAnimationStyle: AnimationStyle(
        duration: Motion.sheet,
        curve: Motion.decelerate,
        reverseDuration: Motion.page,
        reverseCurve: Motion.accelerate,
      ),
      builder: (_) => const CaptureSheet(),
    );
  }

  @override
  ConsumerState<CaptureSheet> createState() => _CaptureSheetState();
}

class _CaptureSheetState extends ConsumerState<CaptureSheet> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  final DraggableScrollableController _sheet =
      DraggableScrollableController();

  static const double _typingSize = 0.55;
  static const double _reviewSize = 0.9;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(captureControllerProvider).input,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _sheet.dispose();
    super.dispose();
  }

  void _resizeFor(CaptureState state) {
    if (!_sheet.isAttached) return;
    final target = state.drafts.isEmpty ? _typingSize : _reviewSize;
    if ((_sheet.size - target).abs() < 0.01) return;
    if (_sheet.size > target) return;
    _sheet.animateTo(
      target,
      duration: context.motion(Motion.sheet),
      curve: Motion.decelerate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(captureControllerProvider);
    final controller = ref.read(captureControllerProvider.notifier);
    final capabilities = ref.watch(capabilitiesProvider);

    ref.listen(captureControllerProvider, (previous, next) {
      if (previous?.drafts.isEmpty == next.drafts.isEmpty) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resizeFor(next);
      });
    });

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        controller: _sheet,
        initialChildSize: _typingSize,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Column(
            children: <Widget>[
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    Insets.gutter,
                    0,
                    Insets.gutter,
                    Insets.lg,
                  ),
                  children: <Widget>[
                    GroupCard(
                      padding: const EdgeInsets.fromLTRB(
                        Insets.lg,
                        Insets.md,
                        Insets.lg,
                        Insets.lg,
                      ),
                      child: _InputField(
                        controller: _controller,
                        focusNode: _focusNode,
                        enabled: !state.isParsing,
                        onChanged: controller.updateInput,
                        onSubmitted: (_) => controller.parse(),
                      ),
                    ),
                    const SizedBox(height: Insets.md),

                    capabilities.when(
                      data: (value) => CapabilityNotice(
                        capabilities: value,
                        onRetry: () => ref.invalidate(capabilitiesProvider),
                      ),
                      loading: () => const SizedBox(height: Insets.xs),
                      error: (_, _) => const SizedBox(height: Insets.xs),
                    ),

                    if (state.error != null) ...<Widget>[
                      const SizedBox(height: Insets.md),
                      _FailureNotice(
                        code: state.error!,
                        onRetry: controller.parse,
                      ),
                    ],

                    if (state.degradedFrom != null &&
                        state.drafts.isNotEmpty) ...<Widget>[
                      const SizedBox(height: Insets.md),
                      _DegradedNotice(reason: state.degradedFrom!),
                    ],

                    if (state.drafts.isNotEmpty) ...<Widget>[
                      const SizedBox(height: Insets.xl),
                      Row(
                        children: <Widget>[
                          Icon(
                            LucideIcons.listChecks,
                            size: 16,
                            color: context.colors.primary,
                          ),
                          const SizedBox(width: Insets.sm),
                          Expanded(
                            child: Text(
                              state.drafts.length == 1
                                  ? 'Check this before saving'
                                  : '${state.drafts.length} tasks found',
                              style: context.texts.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Insets.md),
                      for (final draft in state.drafts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Insets.md),
                          child: DraftCard(
                            key: ValueKey<String>(draft.id),
                            draft: draft,
                            onChanged: controller.replaceDraft,
                            onRemove: state.drafts.length > 1
                                ? () => controller.removeDraft(draft.id)
                                : null,
                          ),
                        ),
                    ],

                    if (state.drafts.isEmpty && state.error == null) ...<Widget>[
                      const SizedBox(height: Insets.lg),
                      _Examples(
                        onPick: (example) {
                          _controller.text = example;
                          controller
                            ..updateInput(example)
                            ..parse();
                        },
                      ),
                    ],
                  ],
                ),
              ),
              _ActionBar(
                state: state,
                onParse: controller.parse,
                onCancel: () async {
                  await controller.cancel();
                },
                onSave: _save,
              ),
              SizedBox(height: MediaQuery.paddingOf(context).bottom),
            ],
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    final state = ref.read(captureControllerProvider);
    final service = ref.read(taskServiceProvider);
    final now = ref.read(clockProvider)();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final warnings = <String>[];
    for (final draft in state.drafts) {
      final outcome = await service.commitDraft(draft, now: now);
      if (outcome.reminderWarning != null) {
        warnings.add(outcome.reminderWarning!);
      }
    }

    ref.read(captureControllerProvider.notifier).reset();
    if (!mounted) return;

    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          warnings.isNotEmpty
              ? warnings.first
              : state.drafts.length == 1
              ? 'Task saved'
              : '${state.drafts.length} tasks saved',
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      autofocus: true,
      maxLines: 4,
      minLines: 2,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
      style: context.texts.bodyLarge?.copyWith(fontSize: 18, height: 1.4),
      decoration: const InputDecoration(
        hintText: 'Call David tomorrow at 9…',
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        contentPadding: EdgeInsets.zero,
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}

class _FailureNotice extends StatelessWidget {
  const _FailureNotice({required this.code, required this.onRetry});

  final LocalAiErrorCode code;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    return GroupCard(
      accent: semantics.caution,
      padding: const EdgeInsets.all(Insets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(Insets.xs + 1),
                decoration: BoxDecoration(
                  color: semantics.cautionSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.info, size: 15, color: semantics.caution),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(code.message, style: context.texts.bodyMedium),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Text(
            'Your text is still here.',
            style: context.texts.bodySmall?.copyWith(color: semantics.muted),
          ),
          if (code.retryable) ...<Widget>[
            const SizedBox(height: Insets.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(LucideIcons.rotateCw, size: 15),
                label: const Text('Try again'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DegradedNotice extends StatelessWidget {
  const _DegradedNotice({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    return Row(
      children: <Widget>[
        Icon(LucideIcons.calendarClock, size: 13, color: semantics.muted),
        const SizedBox(width: Insets.xs + 2),
        Expanded(
          child: Text(
            'Read with built-in date parsing.',
            style: context.texts.bodySmall?.copyWith(color: semantics.muted),
          ),
        ),
      ],
    );
  }
}

class _Examples extends StatelessWidget {
  const _Examples({required this.onPick});

  final ValueChanged<String> onPick;

  static const List<String> _examples = <String>[
    'Call David tomorrow at 9am',
    'Buy milk and email Ana tonight',
    'Standup every weekday at 9:15am',
    'Renew passport on 3 March !!',
  ];

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'TRY',
          style: context.texts.labelSmall?.copyWith(
            color: semantics.muted,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: Insets.sm),
        Wrap(
          spacing: Insets.sm,
          runSpacing: Insets.sm,
          children: <Widget>[
            for (final example in _examples)
              ActionChip(
                label: Text(example),
                onPressed: () => onPick(example),
              ),
          ],
        ),
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.state,
    required this.onParse,
    required this.onCancel,
    required this.onSave,
  });

  final CaptureState state;
  final VoidCallback onParse;
  final Future<void> Function() onCancel;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    final hasDrafts = state.drafts.isNotEmpty;
    final blocked = hasDrafts && !state.allDraftsResolved;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter,
        Insets.md,
        Insets.gutter,
        Insets.md,
      ),
      decoration: BoxDecoration(
        color: semantics.raised,
        border: Border(top: BorderSide(color: semantics.hairline)),
        boxShadow: semantics.floatingShadow,
      ),
      child: AnimatedSize(
        duration: context.motion(Motion.normal),
        curve: Motion.standard,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: context.motion(Motion.normal),
          switchInCurve: Motion.decelerate,
          switchOutCurve: Motion.accelerate,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.35),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: switch ((state.isParsing, hasDrafts)) {
            (true, _) => Row(
              key: const ValueKey<String>('parsing'),
              children: <Widget>[
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: Insets.md),
                Text('Reading…', style: context.texts.bodyMedium),
                const Spacer(),
                TextButton(onPressed: onCancel, child: const Text('Cancel')),
              ],
            ),
            (false, true) => Row(
              key: const ValueKey<String>('drafts'),
              children: <Widget>[
                if (blocked)
                  Expanded(
                    child: Text(
                      'Resolve the highlighted question first.',
                      style: context.texts.bodySmall?.copyWith(
                        color: semantics.caution,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                const SizedBox(width: Insets.md),
                FilledButton.icon(
                  onPressed: blocked
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          onSave();
                        },
                  icon: const Icon(LucideIcons.check, size: 17),
                  label: Text(
                    state.drafts.length == 1
                        ? 'Save task'
                        : 'Save ${state.drafts.length} tasks',
                  ),
                ),
              ],
            ),
            (false, false) => Row(
              key: const ValueKey<String>('idle'),
              children: <Widget>[
                IconButton(
                  icon: const Icon(LucideIcons.mic, size: 20),
                  tooltip: 'Voice capture',
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Listening… speak your task commitment.'),
                      ),
                    );
                  },
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: state.canSubmit ? onParse : null,
                  icon: const Icon(LucideIcons.arrowRight, size: 17),
                  label: const Text('Continue'),
                ),
              ],
            ),
          },
        ),
      ),
    );
  }
}
