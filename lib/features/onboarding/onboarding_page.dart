import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../application/providers.dart';
import '../../core/design/app_theme.dart';
import '../../core/design/design_tokens.dart';
import '../../core/format/task_formatting.dart';
import '../../core/motion/motion_prefs.dart';
import '../../core/widgets/group_card.dart';
import '../../core/widgets/illustration.dart';
import '../../core/widgets/romlerk_logo.dart';
import '../../data/local/settings_store.dart';
import '../../domain/drafts/task_draft.dart';
import '../../l10n/l10n.dart';
import '../../local_ai/deterministic/deterministic_parser.dart';
import '../../local_ai/local_ai.dart';

/// Uses the same baseline parser as capture, without creating a recovery draft,
/// probing platform models, or touching notification permissions.
final onboardingParserProvider = Provider<LocalAi>(
  (ref) => DeterministicTaskParser(),
);

/// A welcome and a working capture preview. Completion is stored only on exit.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _pages = PageController();
  final _input = TextEditingController();
  int _index = 0;
  int _revision = 0;
  bool _busy = false;
  bool _parsing = false;
  bool _previewFailed = false;
  TaskDraft? _draft;

  @override
  void dispose() {
    _pages.dispose();
    _input.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.selectionClick();
    if (context.prefersReducedMotion) {
      _pages.jumpToPage(index);
    } else {
      _pages.animateToPage(
        index,
        duration: Motion.page,
        curve: Motion.standard,
      );
    }
  }

  void _changed(String _) {
    _revision++;
    setState(() {
      _draft = null;
      _parsing = false;
      _previewFailed = false;
    });
  }

  void _useExample() {
    _input.text = context.l10n.onboardExample;
    _changed(_input.text);
    _preview();
  }

  Future<void> _preview() async {
    final text = _input.text.trim();
    if (text.isEmpty || _parsing || _busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final revision = ++_revision;
    setState(() {
      _parsing = true;
      _previewFailed = false;
      _draft = null;
    });
    try {
      final result = await ref
          .read(onboardingParserProvider)
          .parseTasks(
            TaskParseRequest(
              requestId: 'onboarding-$revision',
              text: text,
              referenceNow: ref.read(clockProvider)(),
              // The baseline parser operates on local wall time, not this zone.
              timezone: 'local',
              locale: Localizations.localeOf(context).toLanguageTag(),
              allowMultipleTasks: false,
            ),
          );
      if (!mounted || revision != _revision) return;
      setState(() {
        _draft = result.drafts.isEmpty ? null : result.drafts.first;
        _previewFailed = result.drafts.isEmpty;
      });
    } on Object {
      if (!mounted || revision != _revision) return;
      setState(() => _previewFailed = true);
    } finally {
      if (mounted && revision == _revision) {
        setState(() => _parsing = false);
      }
    }
  }

  Future<void> _setLanguage(LanguagePreference language) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final store = ref.read(settingsStoreProvider);
      final current = await store.read();
      await store.write(current.copyWith(languagePreference: language));
    } on Object {
      if (mounted) _showSaveError(context.l10n.languageSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _busy = true);
    try {
      final store = ref.read(settingsStoreProvider);
      final current = await store.read();
      await store.write(current.copyWith(onboardingComplete: true));
    } on Object {
      if (mounted) _showSaveError(context.l10n.onboardFinishFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSaveError(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedLanguage = Localizations.localeOf(context).languageCode;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
              child: Row(
                children: [
                  if (_index == 1)
                    IconButton(
                      tooltip: l10n.onboardBack,
                      onPressed: _busy ? null : () => _goTo(0),
                      icon: const Icon(LucideIcons.arrowLeft, size: 20),
                    )
                  else ...[
                    const RomlerkLogo(size: 36),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: Text(
                        l10n.appTitle,
                        style: context.texts.titleMedium,
                      ),
                    ),
                  ],
                  if (_index == 1) const Spacer(),
                  TextButton(
                    onPressed: _busy ? null : _finish,
                    child: Text(l10n.skip),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (value) => setState(() => _index = value),
                children: [
                  _OnboardingContent(
                    children: [
                      const _WelcomeArtwork(),
                      const SizedBox(height: Insets.xxl),
                      Text(
                        l10n.onboardWelcomeTitle,
                        textAlign: TextAlign.center,
                        style: context.texts.headlineLarge,
                      ),
                      const SizedBox(height: Insets.md),
                      Text(
                        l10n.onboardWelcomeBody,
                        textAlign: TextAlign.center,
                        style: context.texts.bodyLarge?.copyWith(
                          color: context.semantics.muted,
                        ),
                      ),
                      const SizedBox(height: Insets.xxl),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.languages,
                            size: 18,
                            color: context.semantics.muted,
                          ),
                          const SizedBox(width: Insets.sm),
                          Text(
                            l10n.languageTitle,
                            style: context.texts.labelLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: Insets.md),
                      Row(
                        children: [
                          for (final (language, label) in [
                            (LanguagePreference.en, l10n.languageEnglish),
                            (LanguagePreference.km, l10n.languageKhmer),
                          ]) ...[
                            if (language == LanguagePreference.km)
                              const SizedBox(width: Insets.md),
                            Expanded(
                              child: _LanguageButton(
                                key: ValueKey(
                                  'onboarding-language-${language.name}',
                                ),
                                label: label,
                                selected: selectedLanguage == language.name,
                                onTap: _busy
                                    ? null
                                    : () => _setLanguage(language),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: Insets.xl),
                      Text(
                        l10n.onboardPrivacyNote,
                        textAlign: TextAlign.center,
                        style: context.texts.bodySmall?.copyWith(
                          color: context.semantics.muted,
                        ),
                      ),
                    ],
                  ),
                  _OnboardingContent(
                    children: [
                      const Illustration(name: 'coffee', height: 112),
                      const SizedBox(height: Insets.lg),
                      Text(
                        l10n.onboardTryTitle,
                        textAlign: TextAlign.center,
                        style: context.texts.headlineMedium,
                      ),
                      const SizedBox(height: Insets.md),
                      Text(
                        l10n.onboardTryBody,
                        textAlign: TextAlign.center,
                        style: context.texts.bodyLarge?.copyWith(
                          color: context.semantics.muted,
                        ),
                      ),
                      const SizedBox(height: Insets.xl),
                      TextField(
                        key: const ValueKey('onboarding-input'),
                        controller: _input,
                        enabled: !_busy,
                        minLines: 2,
                        maxLines: 4,
                        maxLength: DeterministicTaskParser.maxInputCharacters,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: l10n.onboardInputLabel,
                          hintText: l10n.onboardExample,
                          counterText: '',
                        ),
                        onChanged: _changed,
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _busy ? null : _useExample,
                          child: Text(l10n.onboardUseExample),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed:
                              _input.text.trim().isEmpty || _parsing || _busy
                              ? null
                              : _preview,
                          icon: _parsing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(LucideIcons.sparkles, size: 18),
                          label: Text(
                            _parsing
                                ? l10n.captureReading
                                : l10n.onboardPreview,
                          ),
                        ),
                      ),
                      const SizedBox(height: Insets.lg),
                      AnimatedSwitcher(
                        duration: context.motion(Motion.normal),
                        switchInCurve: Motion.decelerate,
                        child: _draft != null
                            ? _DraftPreview(
                                key: ValueKey(_draft!.id),
                                draft: _draft!,
                                now: ref.read(clockProvider)(),
                              )
                            : _previewFailed
                            ? Text(
                                l10n.onboardPreviewFailed,
                                key: const ValueKey('preview-error'),
                                style: context.texts.bodyMedium?.copyWith(
                                  color: context.colors.error,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: Insets.md),
                      Text(
                        l10n.onboardPracticeNote,
                        textAlign: TextAlign.center,
                        style: context.texts.bodySmall?.copyWith(
                          color: context.semantics.muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.xl,
                Insets.md,
                Insets.xl,
                Insets.lg,
              ),
              child: Column(
                children: [
                  Semantics(
                    liveRegion: true,
                    label: l10n.onboardStep(_index + 1, 2),
                    child: ExcludeSemantics(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < 2; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Insets.xs,
                              ),
                              child: AnimatedOpacity(
                                opacity: i == _index ? 1 : 0.22,
                                duration: context.motion(Motion.fast),
                                child: Container(
                                  width: 28,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: context.colors.primary,
                                    borderRadius: Corners.pill,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('onboarding-next'),
                      onPressed: _busy
                          ? null
                          : _index == 0
                          ? () => _goTo(1)
                          : _finish,
                      child: Text(_index == 0 ? l10n.next : l10n.onboardStart),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingContent extends StatelessWidget {
  const _OnboardingContent({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.xl,
        vertical: Insets.lg,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: (constraints.maxHeight - Insets.xxl).clamp(
            0,
            double.infinity,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    ),
  );
}

class _WelcomeArtwork extends StatelessWidget {
  const _WelcomeArtwork();
  @override
  Widget build(BuildContext context) => Container(
    width: 260,
    height: 214,
    decoration: BoxDecoration(
      color: context.semantics.accentSoft,
      borderRadius: Corners.group,
    ),
    padding: const EdgeInsets.all(Insets.xl),
    child: const Illustration(name: 'meditating', height: 168),
  );
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({
    required this.label,
    required this.selected,
    this.onTap,
    super.key,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected
            ? context.semantics.accentSoft
            : context.semantics.raised,
        foregroundColor: selected
            ? context.colors.primary
            : context.colors.onSurface,
        side: BorderSide(
          color: selected ? context.colors.primary : context.semantics.hairline,
        ),
        minimumSize: const Size(48, 52),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          if (selected) const Icon(LucideIcons.check, size: 16),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _DraftPreview extends StatelessWidget {
  const _DraftPreview({required this.draft, required this.now, super.key});
  final TaskDraft draft;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final formatting = TaskFormatting(
      locale: Localizations.localeOf(context).toLanguageTag(),
      strings: l10n,
    );
    final when = draft.dueAt;
    return Semantics(
      liveRegion: true,
      child: GroupCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.onboardUnderstood,
              style: context.texts.labelMedium?.copyWith(
                color: context.colors.primary,
              ),
            ),
            const SizedBox(height: Insets.sm),
            Text(draft.title, style: context.texts.titleLarge),
            const SizedBox(height: Insets.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  draft.hasAmbiguities
                      ? LucideIcons.circleHelp
                      : LucideIcons.calendarDays,
                  size: 18,
                  color: context.semantics.muted,
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    draft.hasAmbiguities
                        ? l10n.onboardClarify
                        : when == null
                        ? l10n.onboardUnscheduled
                        : formatting.exact(when, now: now),
                    style: context.texts.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
