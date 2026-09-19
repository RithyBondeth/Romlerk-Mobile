import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

extension L10nContext on BuildContext {
  /// UI strings in the current language. Every user-facing string goes
  /// through here, so Khmer and English stay in step.
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// The supported UI language closest to [locale]: Khmer for any `km`,
/// English otherwise. Mirrors how MaterialApp resolves it, for code that has
/// no BuildContext (formatting in providers, notification text).
Locale resolveAppLocale(Locale locale) =>
    locale.languageCode == 'km' ? const Locale('km') : const Locale('en');
