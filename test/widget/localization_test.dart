import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:romlerk_mobile/l10n/app_localizations.dart';

void main() {
  group('AppLocalizations (UI Localization)', () {
    test('provides English UI strings', () {
      final l10n = AppLocalizations(const Locale('en', 'US'));
      expect(l10n.appTitle, equals('Romlerk'));
      expect(l10n.today, equals('Today'));
      expect(l10n.settings, equals('Settings'));
      expect(l10n.markComplete, equals('Mark complete'));
      expect(l10n.planMyDay, equals('Plan My Day'));
    });

    test('provides Khmer UI strings', () {
      final l10n = AppLocalizations(const Locale('km', 'KH'));
      expect(l10n.appTitle, equals('រំលឹក'));
      expect(l10n.today, equals('ថ្ងៃនេះ'));
      expect(l10n.settings, equals('ការកំណត់'));
      expect(l10n.markComplete, equals('សញ្ញាជោគជ័យ'));
      expect(l10n.planMyDay, equals('រៀបចំផែនការថ្ងៃនេះ'));
    });
  });
}
