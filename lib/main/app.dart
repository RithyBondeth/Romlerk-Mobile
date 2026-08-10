import 'package:flutter/material.dart';

import '../core/design/app_theme.dart';
import '../features/shell/home_shell.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Romlerk',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // The OS setting wins; there is no in-app theme switch to get out of
      // sync with it.
      themeMode: ThemeMode.system,
      home: const HomeShell(),
    );
  }
}
