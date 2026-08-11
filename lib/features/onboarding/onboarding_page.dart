import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../core/design/app_theme.dart';
import '../../core/design/design_tokens.dart';
import '../../core/widgets/illustration.dart';
import '../../data/local/settings_store.dart';

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

  static const List<_Chapter> _chapters = <_Chapter>[
    _Chapter(
      illustration: 'meditating',
      headline: 'Everything stays on this phone',
      body:
          'No account, no server, no cloud AI. Your tasks, notes, and '
          'reminders are stored in a database on this device and processed '
          'here.',
    ),
    _Chapter(
      illustration: 'coffee',
      headline: 'Write it the way you would say it',
      body:
          '“Call David tomorrow at 9” becomes a task with a date and a '
          'reminder. There is no form to fill in.',
    ),
    _Chapter(
      illustration: 'jumping',
      headline: 'Nothing is saved until you say so',
      body:
          'You always see what will be created, with dates spelled out in '
          'full. Anything the app is unsure about asks you first.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _index == _chapters.length - 1;

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
                    child: const Text('Skip'),
                  ),
                ),
              ),
            ),

            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _chapters.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) => _ChapterView(
                  chapter: _chapters[index],
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
                  _Dots(count: _chapters.length, active: _index),
                  const SizedBox(height: Insets.xl),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _next,
                      child: Text(_isLast ? 'Get started' : 'Next'),
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
