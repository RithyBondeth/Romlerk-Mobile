import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../core/design/app_theme.dart';
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
      // The OS setting wins; there is no in-app theme switch to get out of
      // sync with it.
      themeMode: ThemeMode.system,
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
