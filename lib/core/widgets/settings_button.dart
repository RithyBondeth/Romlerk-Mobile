import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../features/settings/settings_page.dart';
import '../design/app_theme.dart';
import '../design/design_tokens.dart';

/// Settings, parked in the corner of every page header.
///
/// It used to float over the scroll view, which meant it sat on top of whatever
/// happened to scroll under it. Living in the header instead gives it a fixed
/// place and lets the content own the whole page.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;

    return IconButton(
      icon: const Icon(LucideIcons.settings, size: 19),
      tooltip: 'Settings',
      color: semantics.muted,
      style: IconButton.styleFrom(
        backgroundColor: semantics.raised,
        shape: RoundedRectangleBorder(
          borderRadius: Corners.pill,
          side: BorderSide(color: semantics.hairline),
        ),
        minimumSize: const Size(42, 42),
      ),
      onPressed: () => SettingsPage.open(context),
    );
  }
}
