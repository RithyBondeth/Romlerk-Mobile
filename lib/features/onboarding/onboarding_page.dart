import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../core/design/app_theme.dart';
import '../../core/design/design_tokens.dart';
import '../../core/widgets/illustration.dart';
import '../../data/local/settings_store.dart';
import '../../l10n/l10n.dart';

/// First run, seen once.
///
/// Three claims, in the order that matters: where the data lives, how you put
/// something in, and what the app will not do behind your back. Nothing here
/// asks for a permission or an account — the point is to set expectations, and
/// the app is fully usable the moment it ends.
///
/// The copy follows the BRD's rule against overclaiming: "processed on this
/// device", never "never touches the internet", because the OS may still fetch
/// model or configuration data of its own.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _controller = PageController();
  int _index = 0;

  static const int _chapterCount = 3;

  static List<_Chapter> _chapters(AppLocalizations l10n) => <_Chapter>[
    _Chapter(
      illustration: 'meditating',
      headline: l10n.onboardPrivateTitle,
      body: l10n.onboardPrivateBody,
    ),
    _Chapter(
      illustration: 'coffee',
      headline: l10n.onboardSpeakTitle,
      body: l10n.onboardSpeakBody,
    ),
    _Chapter(
      illustration: 'jumping',
      headline: l10n.onboardReviewTitle,
      body: l10n.onboardReviewBody,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _index == _chapterCount - 1;

  void _next() {
    HapticFeedback.selectionClick();
    if (_isLast) {
      _finish();
      return;
    }
    _controller.nextPage(duration: Motion.normal, curve: Motion.easing);
  }

  /// Skipping is a complete answer, so it finishes rather than fast-forwarding
  /// to the last page and asking again.
  Future<void> _finish() async {
    final store = ref.read(settingsStoreProvider);
    final current = ref.read(settingsProvider).valueOrNull ?? const AppSettings();
    await store.write(current.copyWith(onboardingComplete: true));
  }

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: Insets.sm),
                child: AnimatedOpacity(
                  duration: Motion.fast,
                  opacity: _isLast ? 0 : 1,
                  child: TextButton(
                    onPressed: _isLast ? null : _finish,
                    style: TextButton.styleFrom(
                      foregroundColor: semantics.muted,
                    ),
                    child: Text(context.l10n.skip),
                  ),
                ),
              ),
            ),

            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _chapterCount,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) => _ChapterView(
                  chapter: _chapters(context.l10n)[index],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.xl,
                Insets.lg,
                Insets.xl,
                Insets.xl,
              ),
              child: Column(
                children: <Widget>[
                  _Dots(count: _chapterCount, active: _index),
                  const SizedBox(height: Insets.xl),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _next,
                      child: Text(
                        _isLast ? context.l10n.getStarted : context.l10n.next,
                      ),
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

class _Chapter {
  const _Chapter({
    required this.illustration,
    required this.headline,
    required this.body,
  });

  final String illustration;
  final String headline;
  final String body;
}

class _ChapterView extends StatelessWidget {
  const _ChapterView({required this.chapter});

  final _Chapter chapter;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Illustration(
            name: chapter.illustration,
            height: 210,
            tint: context.colors.onSurface,
          ),
          const SizedBox(height: Insets.xxl),
          Text(
            chapter.headline,
            textAlign: TextAlign.center,
            style: context.texts.headlineMedium,
          ),
          const SizedBox(height: Insets.md),
          Text(
            chapter.body,
            textAlign: TextAlign.center,
            style: context.texts.bodyLarge?.copyWith(color: semantics.muted),
          ),
        ],
      ),
    );
  }
}

/// The active dot stretches into a pill rather than just changing colour, so
/// position is readable without relying on the accent alone.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: Motion.normal,
            curve: Motion.easing,
            margin: const EdgeInsets.symmetric(horizontal: Insets.xs),
            height: 6,
            width: i == active ? 24 : 6,
            decoration: BoxDecoration(
              color: i == active ? context.colors.primary : semantics.hairline,
              borderRadius: Corners.pill,
            ),
          ),
      ],
    );
  }
}
