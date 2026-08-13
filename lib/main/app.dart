import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../core/design/app_theme.dart';
import '../data/local/settings_store.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/shell/home_shell.dart';
import '../l10n/app_localizations.dart';

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
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      themeMode: switch (settings.valueOrNull?.themePreference) {
        ThemePreference.light => ThemeMode.light,
        ThemePreference.dark => ThemeMode.dark,
        ThemePreference.system || null => ThemeMode.system,
      },
      home: settings.when(
        loading: () => const _Booting(),
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
