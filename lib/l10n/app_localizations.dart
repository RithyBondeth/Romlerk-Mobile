import 'package:flutter/widgets.dart';

/// Localized static UI string dictionary for Romlerk (English & Khmer).
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
  ];

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en', 'US'),
    Locale('km', 'KH'),
  ];

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ?? AppLocalizations(const Locale('en'));
  }

  bool get isKhmer => locale.languageCode == 'km';

  // Navigation & Headers
  String get appTitle => isKhmer ? 'រំលឹក' : 'Romlerk';
  String get today => isKhmer ? 'ថ្ងៃនេះ' : 'Today';
  String get upcoming => isKhmer ? 'ខាងមុខ' : 'Upcoming';
  String get inbox => isKhmer ? 'ប្រអប់សារ' : 'Inbox';
  String get search => isKhmer ? 'ស្វែងរក' : 'Search';
  String get settings => isKhmer ? 'ការកំណត់' : 'Settings';
  String get overdue => isKhmer ? 'ហួសកំណត់' : 'Overdue';
  String get doneToday => isKhmer ? 'រួចរាល់ថ្ងៃនេះ' : 'Done today';

  // Actions & Buttons
  String get markComplete => isKhmer ? 'សញ្ញាជោគជ័យ' : 'Mark complete';
  String get reopenTask => isKhmer ? 'បើកភារកិច្ចឡើងវិញ' : 'Reopen task';
  String get planMyDay => isKhmer ? 'រៀបចំផែនការថ្ងៃនេះ' : 'Plan My Day';
  String get whatShouldIDoNow => isKhmer ? 'តើខ្ញុំគួរធ្វើអ្វីបន្ត?' : 'What should I do now?';
  String get suggestedFocus => isKhmer ? 'ចំណុចសំខាន់ដែលគួរធ្វើ' : 'Suggested Focus';
  String get deleteTask => isKhmer ? 'លុបភារកិច្ច' : 'Delete task';
  String get exportCalendar => isKhmer ? 'នាំចេញជាឯកសារ .ics' : 'Export as .ics file';
  String get eraseAllData => isKhmer ? 'លុបទិន្នន័យទាំងអស់' : 'Erase all data';
  String get voiceCapture => isKhmer ? 'កត់ត្រាជាសំឡេង' : 'Voice capture';
  String get listeningPrompt => isKhmer ? 'កំពុងស្តាប់... សូមនិយាយភារកិច្ចរបស់អ្នក។' : 'Listening… speak your task commitment.';
  String get continueAction => isKhmer ? 'បន្ត' : 'Continue';
  String get saveTask => isKhmer ? 'រក្សាទុក' : 'Save task';
  String get cancel => isKhmer ? 'បោះបង់' : 'Cancel';
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => <String>['en', 'km'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
