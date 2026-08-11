import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../core/design/app_theme.dart';
import '../data/local/settings_store.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/shell/home_shell.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'Romlerk',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Follows the OS by default. An explicit choice overrides it, because a
      // phone left on system dark is not the same statement as "I want this
      // app dark" — plenty of people want one and not the other.
      //
      // While the settings read is in flight this falls back to system rather
      // than to light, so a user who has chosen dark does not get a white
      // flash on every cold start.
      themeMode: switch (settings.valueOrNull?.themePreference) {
        ThemePreference.light => ThemeMode.light,
        ThemePreference.dark => ThemeMode.dark,
        ThemePreference.system || null => ThemeMode.system,
      },
      home: settings.when(
        // A blank page rather than a spinner: the settings read is a local
        // query, and a flash of progress indicator on every cold start would
        // cost more than it explains.
        loading: () => const _Booting(),
        // A settings read that fails must not lock anyone out of their tasks.
        // The app works without knowing whether onboarding was seen.
        error: (_, _) => const HomeShell(),
        data: (value) =>
            value.onboardingComplete ? const HomeShell() : const OnboardingPage(),
      ),
    );
  }
}

class _Booting extends StatelessWidget {
  const _Booting();

  @override
  Widget build(BuildContext context) => const Scaffold();
}
