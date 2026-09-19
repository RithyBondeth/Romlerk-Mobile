import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_km.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('km'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Romlerk'**
  String get appTitle;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @inbox.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get inbox;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @overdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdue;

  /// No description provided for @doneToday.
  ///
  /// In en, this message translates to:
  /// **'Done today'**
  String get doneToday;

  /// No description provided for @markComplete.
  ///
  /// In en, this message translates to:
  /// **'Mark complete'**
  String get markComplete;

  /// No description provided for @reopenTask.
  ///
  /// In en, this message translates to:
  /// **'Reopen task'**
  String get reopenTask;

  /// No description provided for @planMyDay.
  ///
  /// In en, this message translates to:
  /// **'Plan My Day'**
  String get planMyDay;

  /// No description provided for @whatShouldIDoNow.
  ///
  /// In en, this message translates to:
  /// **'What should I do now?'**
  String get whatShouldIDoNow;

  /// No description provided for @suggestedFocus.
  ///
  /// In en, this message translates to:
  /// **'Suggested Focus'**
  String get suggestedFocus;

  /// No description provided for @deleteTask.
  ///
  /// In en, this message translates to:
  /// **'Delete task'**
  String get deleteTask;

  /// No description provided for @exportCalendar.
  ///
  /// In en, this message translates to:
  /// **'Export as .ics file'**
  String get exportCalendar;

  /// No description provided for @eraseAllData.
  ///
  /// In en, this message translates to:
  /// **'Erase all data'**
  String get eraseAllData;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @saveTask.
  ///
  /// In en, this message translates to:
  /// **'Save task'**
  String get saveTask;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @formatExactAt.
  ///
  /// In en, this message translates to:
  /// **'{date} at {time}'**
  String formatExactAt(String date, String time);

  /// No description provided for @formatTomorrowAt.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow, {time}'**
  String formatTomorrowAt(String time);

  /// No description provided for @formatYesterdayAt.
  ///
  /// In en, this message translates to:
  /// **'Yesterday, {time}'**
  String formatYesterdayAt(String time);

  /// No description provided for @formatWeekdayAt.
  ///
  /// In en, this message translates to:
  /// **'{weekday}, {time}'**
  String formatWeekdayAt(String weekday, String time);

  /// No description provided for @formatLastWeekdayAt.
  ///
  /// In en, this message translates to:
  /// **'Last {weekday}, {time}'**
  String formatLastWeekdayAt(String weekday, String time);

  /// No description provided for @formatDateAt.
  ///
  /// In en, this message translates to:
  /// **'{date}, {time}'**
  String formatDateAt(String date, String time);

  /// No description provided for @formatTodayHeading.
  ///
  /// In en, this message translates to:
  /// **'Today · {date}'**
  String formatTodayHeading(String date);

  /// No description provided for @formatTomorrowHeading.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow · {date}'**
  String formatTomorrowHeading(String date);

  /// No description provided for @overdueMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min overdue'**
  String overdueMinutes(int count);

  /// No description provided for @overdueHours.
  ///
  /// In en, this message translates to:
  /// **'{count} h overdue'**
  String overdueHours(int count);

  /// No description provided for @overdueDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day overdue} other{{count} days overdue}}'**
  String overdueDays(int count);

  /// No description provided for @overdueWeeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 week overdue} other{{count} weeks overdue}}'**
  String overdueWeeks(int count);

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String durationMinutes(int minutes);

  /// No description provided for @durationHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String durationHours(int hours);

  /// No description provided for @durationHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String durationHoursMinutes(int hours, int minutes);

  /// No description provided for @priorityNone.
  ///
  /// In en, this message translates to:
  /// **'No priority'**
  String get priorityNone;

  /// No description provided for @priorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get priorityLow;

  /// No description provided for @priorityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get priorityMedium;

  /// No description provided for @priorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get priorityHigh;

  /// No description provided for @recurEveryDay.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get recurEveryDay;

  /// No description provided for @recurEveryNDays.
  ///
  /// In en, this message translates to:
  /// **'Every {count} days'**
  String recurEveryNDays(int count);

  /// No description provided for @recurEveryWeek.
  ///
  /// In en, this message translates to:
  /// **'Every week'**
  String get recurEveryWeek;

  /// No description provided for @recurEveryNWeeks.
  ///
  /// In en, this message translates to:
  /// **'Every {count} weeks'**
  String recurEveryNWeeks(int count);

  /// No description provided for @recurEveryMonth.
  ///
  /// In en, this message translates to:
  /// **'Every month'**
  String get recurEveryMonth;

  /// No description provided for @recurEveryNMonths.
  ///
  /// In en, this message translates to:
  /// **'Every {count} months'**
  String recurEveryNMonths(int count);

  /// No description provided for @recurEveryYear.
  ///
  /// In en, this message translates to:
  /// **'Every year'**
  String get recurEveryYear;

  /// No description provided for @recurEveryNYears.
  ///
  /// In en, this message translates to:
  /// **'Every {count} years'**
  String recurEveryNYears(int count);

  /// No description provided for @recurEveryWeekday.
  ///
  /// In en, this message translates to:
  /// **'Every weekday'**
  String get recurEveryWeekday;

  /// No description provided for @recurWeeklyOn.
  ///
  /// In en, this message translates to:
  /// **'Every week on {days}'**
  String recurWeeklyOn(String days);

  /// No description provided for @recurEveryNWeeksOn.
  ///
  /// In en, this message translates to:
  /// **'Every {count} weeks on {days}'**
  String recurEveryNWeeksOn(int count, String days);

  /// No description provided for @recurTimes.
  ///
  /// In en, this message translates to:
  /// **'{rule}, {count} times'**
  String recurTimes(String rule, int count);

  /// No description provided for @recurUntil.
  ///
  /// In en, this message translates to:
  /// **'{rule}, until {date}'**
  String recurUntil(String rule, String date);

  /// No description provided for @loadFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Your tasks are unchanged. Try restarting the app.'**
  String get loadFailedBody;

  /// No description provided for @upcomingLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upcoming could not be loaded'**
  String get upcomingLoadFailed;

  /// No description provided for @upcomingEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled ahead'**
  String get upcomingEmptyTitle;

  /// No description provided for @upcomingEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Tasks with a date after today will be grouped here by day.'**
  String get upcomingEmptyBody;

  /// No description provided for @nothingScheduled.
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled'**
  String get nothingScheduled;

  /// No description provided for @taskCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 task} other{{count} tasks}}'**
  String taskCount(int count);

  /// No description provided for @dayCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String dayCount(int count);

  /// No description provided for @upcomingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{tasks} across {days}'**
  String upcomingSubtitle(String tasks, String days);

  /// No description provided for @todayEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing due today'**
  String get todayEmptyTitle;

  /// No description provided for @todayEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Anything you capture with a date for today will show up here.'**
  String get todayEmptyBody;

  /// No description provided for @todayRemaining.
  ///
  /// In en, this message translates to:
  /// **'{date} · {count} left'**
  String todayRemaining(String date, int count);

  /// No description provided for @todayLoadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Your tasks could not be read'**
  String get todayLoadFailedTitle;

  /// No description provided for @todayLoadFailedBody.
  ///
  /// In en, this message translates to:
  /// **'The local database did not open. Your data has not been changed. Restarting the app usually clears this.'**
  String get todayLoadFailedBody;

  /// No description provided for @rankOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue commitment'**
  String get rankOverdue;

  /// No description provided for @rankDueSoon.
  ///
  /// In en, this message translates to:
  /// **'Due within 2 hours'**
  String get rankDueSoon;

  /// No description provided for @rankDueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get rankDueToday;

  /// No description provided for @rankDueWithinDay.
  ///
  /// In en, this message translates to:
  /// **'Due within 24 hours'**
  String get rankDueWithinDay;

  /// No description provided for @rankHighPriority.
  ///
  /// In en, this message translates to:
  /// **'High priority'**
  String get rankHighPriority;

  /// No description provided for @rankQuickWin.
  ///
  /// In en, this message translates to:
  /// **'Quick win ({minutes} min)'**
  String rankQuickWin(int minutes);

  /// No description provided for @rankActive.
  ///
  /// In en, this message translates to:
  /// **'Active task'**
  String get rankActive;

  /// No description provided for @reminderNotSet.
  ///
  /// In en, this message translates to:
  /// **'Reminder not set'**
  String get reminderNotSet;

  /// No description provided for @a11yCompleted.
  ///
  /// In en, this message translates to:
  /// **'completed'**
  String get a11yCompleted;

  /// No description provided for @a11yDue.
  ///
  /// In en, this message translates to:
  /// **'due {when}'**
  String a11yDue(String when);

  /// No description provided for @a11yPriority.
  ///
  /// In en, this message translates to:
  /// **'{priority} priority'**
  String a11yPriority(String priority);

  /// No description provided for @completedLabel.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completedLabel;

  /// No description provided for @ringProgress.
  ///
  /// In en, this message translates to:
  /// **'{completed} of {total} tasks complete'**
  String ringProgress(int completed, int total);

  /// No description provided for @capReady.
  ///
  /// In en, this message translates to:
  /// **'Enhanced on-device understanding is ready.'**
  String get capReady;

  /// No description provided for @capBaseline.
  ///
  /// In en, this message translates to:
  /// **'Quick date parsing is available on this device.'**
  String get capBaseline;

  /// No description provided for @capManual.
  ///
  /// In en, this message translates to:
  /// **'Type the details and they will be saved exactly as entered.'**
  String get capManual;

  /// No description provided for @capCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get capCheckAgain;

  /// No description provided for @capDisabled.
  ///
  /// In en, this message translates to:
  /// **'On-device AI is turned off in system settings. Date parsing still works here.'**
  String get capDisabled;

  /// No description provided for @capNotReady.
  ///
  /// In en, this message translates to:
  /// **'The on-device model is still getting ready. Date parsing is being used in the meantime.'**
  String get capNotReady;

  /// No description provided for @capBusy.
  ///
  /// In en, this message translates to:
  /// **'The on-device model is busy. Date parsing is being used for now.'**
  String get capBusy;

  /// No description provided for @capFallback.
  ///
  /// In en, this message translates to:
  /// **'Date parsing is being used for now.'**
  String get capFallback;

  /// No description provided for @plannedTime.
  ///
  /// In en, this message translates to:
  /// **'Planned time'**
  String get plannedTime;

  /// No description provided for @plannedSummary.
  ///
  /// In en, this message translates to:
  /// **'{hours} h · {tasks}'**
  String plannedSummary(String hours, String tasks);

  /// No description provided for @planSelectTasks.
  ///
  /// In en, this message translates to:
  /// **'Select tasks for today'**
  String get planSelectTasks;

  /// No description provided for @planSaved.
  ///
  /// In en, this message translates to:
  /// **'Plan saved with {tasks}.'**
  String planSaved(String tasks);

  /// No description provided for @planConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm today\'s plan'**
  String get planConfirm;

  /// No description provided for @inboxLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Inbox could not be loaded'**
  String get inboxLoadFailed;

  /// No description provided for @inboxEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Inbox is clear'**
  String get inboxEmptyTitle;

  /// No description provided for @inboxEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Anything you capture without a date waits here until you decide when to do it.'**
  String get inboxEmptyBody;

  /// No description provided for @inboxSubtitleEmpty.
  ///
  /// In en, this message translates to:
  /// **'No undated tasks'**
  String get inboxSubtitleEmpty;

  /// No description provided for @inboxSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count} without a date'**
  String inboxSubtitle(int count);

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @captureBarHint.
  ///
  /// In en, this message translates to:
  /// **'What needs doing?'**
  String get captureBarHint;

  /// No description provided for @captureBarLabel.
  ///
  /// In en, this message translates to:
  /// **'Capture a new task'**
  String get captureBarLabel;

  /// No description provided for @errModelUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Enhanced understanding is not supported on this device.'**
  String get errModelUnavailable;

  /// No description provided for @errModelDisabled.
  ///
  /// In en, this message translates to:
  /// **'On-device AI is turned off in system settings.'**
  String get errModelDisabled;

  /// No description provided for @errModelNotReady.
  ///
  /// In en, this message translates to:
  /// **'The on-device model is still getting ready.'**
  String get errModelNotReady;

  /// No description provided for @errBusy.
  ///
  /// In en, this message translates to:
  /// **'The on-device model is busy right now.'**
  String get errBusy;

  /// No description provided for @errBackground.
  ///
  /// In en, this message translates to:
  /// **'On-device AI only runs while the app is open.'**
  String get errBackground;

  /// No description provided for @errLanguage.
  ///
  /// In en, this message translates to:
  /// **'This language is not supported for enhanced understanding.'**
  String get errLanguage;

  /// No description provided for @errOutputInvalid.
  ///
  /// In en, this message translates to:
  /// **'The result could not be read, so it wasn\'t used.'**
  String get errOutputInvalid;

  /// No description provided for @errTimeout.
  ///
  /// In en, this message translates to:
  /// **'That took too long.'**
  String get errTimeout;

  /// No description provided for @errCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled.'**
  String get errCancelled;

  /// No description provided for @errInputTooLong.
  ///
  /// In en, this message translates to:
  /// **'That is longer than the model can read at once.'**
  String get errInputTooLong;

  /// No description provided for @errUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get errUnknown;

  /// No description provided for @voiceNoSpeech.
  ///
  /// In en, this message translates to:
  /// **'Didn’t catch that. Try again, or type it.'**
  String get voiceNoSpeech;

  /// No description provided for @voicePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is off. You can allow it in Settings.'**
  String get voicePermissionDenied;

  /// No description provided for @voiceLanguageUnsupported.
  ///
  /// In en, this message translates to:
  /// **'On-device voice isn’t available for this language yet. Typing works the same.'**
  String get voiceLanguageUnsupported;

  /// No description provided for @voiceBusy.
  ///
  /// In en, this message translates to:
  /// **'The microphone is busy. Try again in a moment.'**
  String get voiceBusy;

  /// No description provided for @voiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'On-device voice isn’t available on this phone. Typing works the same.'**
  String get voiceUnavailable;

  /// No description provided for @voiceFailed.
  ///
  /// In en, this message translates to:
  /// **'Voice stopped unexpectedly. Your text is safe.'**
  String get voiceFailed;

  /// No description provided for @voiceListening.
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get voiceListening;

  /// No description provided for @voiceFinishing.
  ///
  /// In en, this message translates to:
  /// **'Finishing…'**
  String get voiceFinishing;

  /// No description provided for @voiceDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get voiceDone;

  /// No description provided for @voiceSpeakTask.
  ///
  /// In en, this message translates to:
  /// **'Speak a task'**
  String get voiceSpeakTask;

  /// No description provided for @voicePrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice stays on this phone'**
  String get voicePrivacyTitle;

  /// No description provided for @voicePrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'Romlerk uses your phone’s built-in speech recognition in on-device mode. Your words become text here; audio is never uploaded or saved.\n\nYou’ll see the text before anything is saved, and can edit it.'**
  String get voicePrivacyBody;

  /// No description provided for @voicePrivacyPermissionNote.
  ///
  /// In en, this message translates to:
  /// **'Next, your phone will ask to allow the microphone.'**
  String get voicePrivacyPermissionNote;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @captureCheckBeforeSaving.
  ///
  /// In en, this message translates to:
  /// **'Check this before saving'**
  String get captureCheckBeforeSaving;

  /// No description provided for @captureTasksFound.
  ///
  /// In en, this message translates to:
  /// **'{count} tasks found'**
  String captureTasksFound(int count);

  /// No description provided for @taskSaved.
  ///
  /// In en, this message translates to:
  /// **'Task saved'**
  String get taskSaved;

  /// No description provided for @tasksSaved.
  ///
  /// In en, this message translates to:
  /// **'{count} tasks saved'**
  String tasksSaved(int count);

  /// No description provided for @captureHint.
  ///
  /// In en, this message translates to:
  /// **'Call David tomorrow at 9…'**
  String get captureHint;

  /// No description provided for @captureTextKept.
  ///
  /// In en, this message translates to:
  /// **'Your text is still here.'**
  String get captureTextKept;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @captureReadWithRules.
  ///
  /// In en, this message translates to:
  /// **'Read with built-in date parsing.'**
  String get captureReadWithRules;

  /// No description provided for @captureTry.
  ///
  /// In en, this message translates to:
  /// **'Try'**
  String get captureTry;

  /// No description provided for @captureExample1.
  ///
  /// In en, this message translates to:
  /// **'Call David tomorrow at 9am'**
  String get captureExample1;

  /// No description provided for @captureExample2.
  ///
  /// In en, this message translates to:
  /// **'Buy milk and email Ana tonight'**
  String get captureExample2;

  /// No description provided for @captureExample3.
  ///
  /// In en, this message translates to:
  /// **'Standup every weekday at 9:15am'**
  String get captureExample3;

  /// No description provided for @captureExample4.
  ///
  /// In en, this message translates to:
  /// **'Renew passport on 3 March !!'**
  String get captureExample4;

  /// No description provided for @captureReading.
  ///
  /// In en, this message translates to:
  /// **'Reading…'**
  String get captureReading;

  /// No description provided for @captureResolveFirst.
  ///
  /// In en, this message translates to:
  /// **'Resolve the highlighted question first.'**
  String get captureResolveFirst;

  /// No description provided for @saveTasks.
  ///
  /// In en, this message translates to:
  /// **'Save {count} tasks'**
  String saveTasks(int count);

  /// No description provided for @reminderBlocked.
  ///
  /// In en, this message translates to:
  /// **'Saved, but no reminder will arrive — notifications are turned off.'**
  String get reminderBlocked;

  /// No description provided for @reminderFailed.
  ///
  /// In en, this message translates to:
  /// **'Saved, but the reminder could not be scheduled.'**
  String get reminderFailed;

  /// No description provided for @draftRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove this task'**
  String get draftRemove;

  /// No description provided for @draftAddDate.
  ///
  /// In en, this message translates to:
  /// **'Add a date'**
  String get draftAddDate;

  /// No description provided for @draftEstimate.
  ///
  /// In en, this message translates to:
  /// **'{duration} (estimate)'**
  String draftEstimate(String duration);

  /// No description provided for @draftRemindsYou.
  ///
  /// In en, this message translates to:
  /// **'Reminds you {when}'**
  String draftRemindsYou(String when);

  /// No description provided for @draftReminderOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get draftReminderOff;

  /// No description provided for @draftNoReminder.
  ///
  /// In en, this message translates to:
  /// **'No reminder'**
  String get draftNoReminder;

  /// No description provided for @draftRemindMe.
  ///
  /// In en, this message translates to:
  /// **'Remind me'**
  String get draftRemindMe;

  /// No description provided for @priority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priority;

  /// No description provided for @warnTimeAssumed.
  ///
  /// In en, this message translates to:
  /// **'No time was given, so {time} was used.'**
  String warnTimeAssumed(String time);

  /// No description provided for @warnTimeApproximate.
  ///
  /// In en, this message translates to:
  /// **'“{phrase}” was read as {time}.'**
  String warnTimeApproximate(String phrase, String time);

  /// No description provided for @warnRolledToTomorrow.
  ///
  /// In en, this message translates to:
  /// **'{time} has already passed today, so this was set for tomorrow.'**
  String warnRolledToTomorrow(String time);

  /// No description provided for @warnTimeInPast.
  ///
  /// In en, this message translates to:
  /// **'That time is in the past. No reminder will be scheduled.'**
  String get warnTimeInPast;

  /// No description provided for @warnDstShift.
  ///
  /// In en, this message translates to:
  /// **'The clocks change that day, so {time} was used.'**
  String warnDstShift(String time);

  /// No description provided for @warnRecurrenceWithoutDate.
  ///
  /// In en, this message translates to:
  /// **'A repeating task needs a first date before it can repeat.'**
  String get warnRecurrenceWithoutDate;

  /// No description provided for @askMeridiem.
  ///
  /// In en, this message translates to:
  /// **'Did you mean {first} or {second}?'**
  String askMeridiem(String first, String second);

  /// No description provided for @askVagueTime.
  ///
  /// In en, this message translates to:
  /// **'“{phrase}” doesn’t say when. Pick a time.'**
  String askVagueTime(String phrase);

  /// No description provided for @altThisEvening.
  ///
  /// In en, this message translates to:
  /// **'This evening'**
  String get altThisEvening;

  /// No description provided for @altTomorrowMorning.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow morning'**
  String get altTomorrowMorning;

  /// No description provided for @altNextWeek.
  ///
  /// In en, this message translates to:
  /// **'Next week'**
  String get altNextWeek;

  /// No description provided for @searchEverything.
  ///
  /// In en, this message translates to:
  /// **'Everything on this device'**
  String get searchEverything;

  /// No description provided for @searchMatches.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 match} other{{count} matches}}'**
  String searchMatches(int count);

  /// No description provided for @searchOpenCount.
  ///
  /// In en, this message translates to:
  /// **'{count} open'**
  String searchOpenCount(int count);

  /// No description provided for @searchDoneCount.
  ///
  /// In en, this message translates to:
  /// **'{count} done'**
  String searchDoneCount(int count);

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search titles and notes'**
  String get searchHint;

  /// No description provided for @searchClear.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get searchClear;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get viewAll;

  /// No description provided for @viewOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get viewOpen;

  /// No description provided for @viewDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get viewDone;

  /// No description provided for @filterHighPriority.
  ///
  /// In en, this message translates to:
  /// **'High priority'**
  String get filterHighPriority;

  /// No description provided for @filterNoDate.
  ///
  /// In en, this message translates to:
  /// **'No date'**
  String get filterNoDate;

  /// No description provided for @searchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed'**
  String get searchFailed;

  /// No description provided for @searchNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get searchNoMatches;

  /// No description provided for @searchNothingDone.
  ///
  /// In en, this message translates to:
  /// **'Nothing done yet'**
  String get searchNothingDone;

  /// No description provided for @searchYourTasks.
  ///
  /// In en, this message translates to:
  /// **'Search your tasks'**
  String get searchYourTasks;

  /// No description provided for @searchNoMatchesBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing here matches “{query}”. Filters may also be narrowing the results.'**
  String searchNoMatchesBody(String query);

  /// No description provided for @searchNothingDoneBody.
  ///
  /// In en, this message translates to:
  /// **'Tasks you complete are kept here, so you can reopen one if it comes back.'**
  String get searchNothingDoneBody;

  /// No description provided for @searchOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'Everything is stored on this device, so search works offline.'**
  String get searchOfflineBody;

  /// No description provided for @detailOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'This task could not be opened'**
  String get detailOpenFailed;

  /// No description provided for @detailNothingChanged.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been changed.'**
  String get detailNothingChanged;

  /// No description provided for @detailGone.
  ///
  /// In en, this message translates to:
  /// **'Task no longer exists'**
  String get detailGone;

  /// No description provided for @detailGoneBody.
  ///
  /// In en, this message translates to:
  /// **'It may have been deleted from another screen.'**
  String get detailGoneBody;

  /// No description provided for @deleteTaskQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete this task?'**
  String get deleteTaskQuestion;

  /// No description provided for @deleteTaskBody.
  ///
  /// In en, this message translates to:
  /// **'It will be removed from this device, along with its reminder. This cannot be undone.'**
  String get deleteTaskBody;

  /// No description provided for @keep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get keep;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @detailDue.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get detailDue;

  /// No description provided for @detailNotScheduled.
  ///
  /// In en, this message translates to:
  /// **'Not scheduled'**
  String get detailNotScheduled;

  /// No description provided for @detailReminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get detailReminder;

  /// No description provided for @detailReminderBlocked.
  ///
  /// In en, this message translates to:
  /// **'Will not arrive — notifications are turned off'**
  String get detailReminderBlocked;

  /// No description provided for @detailReminderFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not be scheduled'**
  String get detailReminderFailed;

  /// No description provided for @detailReminderDelivered.
  ///
  /// In en, this message translates to:
  /// **'Already delivered'**
  String get detailReminderDelivered;

  /// No description provided for @detailReminderCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get detailReminderCancelled;

  /// No description provided for @detailRepeats.
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get detailRepeats;

  /// No description provided for @detailTakes.
  ///
  /// In en, this message translates to:
  /// **'Takes'**
  String get detailTakes;

  /// No description provided for @detailTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get detailTags;

  /// No description provided for @detailCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar event'**
  String get detailCalendar;

  /// No description provided for @detailCompletedAt.
  ///
  /// In en, this message translates to:
  /// **'Completed {when}'**
  String detailCompletedAt(String when);

  /// No description provided for @detailNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get detailNotes;

  /// No description provided for @detailNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Supporting details…'**
  String get detailNotesHint;

  /// No description provided for @detailCreatedAt.
  ///
  /// In en, this message translates to:
  /// **'Created {when}'**
  String detailCreatedAt(String when);

  /// No description provided for @detailIcsCopied.
  ///
  /// In en, this message translates to:
  /// **'Calendar event (.ics) copied to clipboard'**
  String get detailIcsCopied;

  /// No description provided for @lockNeedsPasscode.
  ///
  /// In en, this message translates to:
  /// **'Set a passcode on your phone first, then try again.'**
  String get lockNeedsPasscode;

  /// No description provided for @lockConfirmOn.
  ///
  /// In en, this message translates to:
  /// **'Confirm it’s you to turn on App Lock'**
  String get lockConfirmOn;

  /// No description provided for @lockConfirmOff.
  ///
  /// In en, this message translates to:
  /// **'Confirm it’s you to turn off App Lock'**
  String get lockConfirmOff;

  /// No description provided for @sectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get sectionAppearance;

  /// No description provided for @sectionPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get sectionPrivacy;

  /// No description provided for @sectionDevice.
  ///
  /// In en, this message translates to:
  /// **'On this device'**
  String get sectionDevice;

  /// No description provided for @sectionCapture.
  ///
  /// In en, this message translates to:
  /// **'Capture'**
  String get sectionCapture;

  /// No description provided for @sectionData.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get sectionData;

  /// No description provided for @privacyHeadline.
  ///
  /// In en, this message translates to:
  /// **'Your tasks stay on this device'**
  String get privacyHeadline;

  /// No description provided for @privacyBody.
  ///
  /// In en, this message translates to:
  /// **'Task text, notes, and reminders are stored in a database on this phone and processed on device. There is no account, no server, and no cloud AI. The only copy that can leave the phone is your own encrypted phone backup, which you control below.'**
  String get privacyBody;

  /// No description provided for @diagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Share anonymous diagnostics'**
  String get diagnosticsTitle;

  /// No description provided for @diagnosticsBody.
  ///
  /// In en, this message translates to:
  /// **'Error codes and timings only. Never task text, titles, notes, or tags. Can be turned off at any time.'**
  String get diagnosticsBody;

  /// No description provided for @backupTitle.
  ///
  /// In en, this message translates to:
  /// **'Include tasks in phone backup'**
  String get backupTitle;

  /// No description provided for @backupPending.
  ///
  /// In en, this message translates to:
  /// **'Takes effect the next time Romlerk starts.'**
  String get backupPending;

  /// No description provided for @backupBodyIos.
  ///
  /// In en, this message translates to:
  /// **'Lets iCloud Backup restore your tasks on a new iPhone. Off keeps them only on this phone.'**
  String get backupBodyIos;

  /// No description provided for @backupBodyAndroid.
  ///
  /// In en, this message translates to:
  /// **'Lets your encrypted Google backup restore your tasks on a new phone. Off keeps them only on this phone.'**
  String get backupBodyAndroid;

  /// No description provided for @redactTitle.
  ///
  /// In en, this message translates to:
  /// **'Hide task text in notifications'**
  String get redactTitle;

  /// No description provided for @redactBody.
  ///
  /// In en, this message translates to:
  /// **'Shows a generic reminder instead of the task title on the lock screen and home screen widget.'**
  String get redactBody;

  /// No description provided for @appLockTitle.
  ///
  /// In en, this message translates to:
  /// **'App Lock'**
  String get appLockTitle;

  /// No description provided for @appLockBody.
  ///
  /// In en, this message translates to:
  /// **'Ask for Face ID, fingerprint, or your phone passcode when opening Romlerk.'**
  String get appLockBody;

  /// No description provided for @capabilityTier.
  ///
  /// In en, this message translates to:
  /// **'Capability tier {tier} · {provider}'**
  String capabilityTier(String tier, String provider);

  /// No description provided for @capabilityCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Capability could not be checked. Date parsing still works.'**
  String get capabilityCheckFailed;

  /// No description provided for @introAgain.
  ///
  /// In en, this message translates to:
  /// **'Show the intro again'**
  String get introAgain;

  /// No description provided for @introAgainBody.
  ///
  /// In en, this message translates to:
  /// **'Replays the three welcome screens.'**
  String get introAgainBody;

  /// No description provided for @defaultTime.
  ///
  /// In en, this message translates to:
  /// **'Default time'**
  String get defaultTime;

  /// No description provided for @defaultTimeBody.
  ///
  /// In en, this message translates to:
  /// **'Used when a task has a date but no time of day.'**
  String get defaultTimeBody;

  /// No description provided for @alwaysReview.
  ///
  /// In en, this message translates to:
  /// **'Always review before saving'**
  String get alwaysReview;

  /// No description provided for @alwaysReviewBody.
  ///
  /// In en, this message translates to:
  /// **'Off lets unambiguous captures save in one step. Anything the app is unsure about is still shown first.'**
  String get alwaysReviewBody;

  /// No description provided for @exportJson.
  ///
  /// In en, this message translates to:
  /// **'Export as JSON'**
  String get exportJson;

  /// No description provided for @exportJsonBody.
  ///
  /// In en, this message translates to:
  /// **'A complete, portable copy of every task.'**
  String get exportJsonBody;

  /// No description provided for @exportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export as CSV'**
  String get exportCsv;

  /// No description provided for @exportCsvBody.
  ///
  /// In en, this message translates to:
  /// **'Opens in a spreadsheet.'**
  String get exportCsvBody;

  /// No description provided for @eraseAllBody.
  ///
  /// In en, this message translates to:
  /// **'Deletes every task, tag, and scheduled reminder from this device.'**
  String get eraseAllBody;

  /// No description provided for @exportNothing.
  ///
  /// In en, this message translates to:
  /// **'There is nothing to export yet.'**
  String get exportNothing;

  /// No description provided for @exportSubject.
  ///
  /// In en, this message translates to:
  /// **'Romlerk tasks'**
  String get exportSubject;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'The export could not be created. Nothing changed.'**
  String get exportFailed;

  /// No description provided for @eraseQuestion.
  ///
  /// In en, this message translates to:
  /// **'Erase everything?'**
  String get eraseQuestion;

  /// No description provided for @eraseBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes {tasks}, all tags, and every scheduled reminder from this device. It cannot be undone. Earlier phone backups may still hold a copy until your phone replaces them.'**
  String eraseBody(String tasks);

  /// No description provided for @erase.
  ///
  /// In en, this message translates to:
  /// **'Erase'**
  String get erase;

  /// No description provided for @eraseDone.
  ///
  /// In en, this message translates to:
  /// **'All data erased from this device.'**
  String get eraseDone;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @onboardPrivateTitle.
  ///
  /// In en, this message translates to:
  /// **'Everything stays on this phone'**
  String get onboardPrivateTitle;

  /// No description provided for @onboardPrivateBody.
  ///
  /// In en, this message translates to:
  /// **'No account, no server, no cloud AI. Your tasks, notes, and reminders are stored in a database on this device and processed here.'**
  String get onboardPrivateBody;

  /// No description provided for @onboardSpeakTitle.
  ///
  /// In en, this message translates to:
  /// **'Write it the way you would say it'**
  String get onboardSpeakTitle;

  /// No description provided for @onboardSpeakBody.
  ///
  /// In en, this message translates to:
  /// **'“Call David tomorrow at 9” becomes a task with a date and a reminder. There is no form to fill in.'**
  String get onboardSpeakBody;

  /// No description provided for @onboardReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing is saved until you say so'**
  String get onboardReviewTitle;

  /// No description provided for @onboardReviewBody.
  ///
  /// In en, this message translates to:
  /// **'You always see what will be created, with dates spelled out in full. Anything the app is unsure about asks you first.'**
  String get onboardReviewBody;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// No description provided for @noteNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get noteNewTitle;

  /// No description provided for @notesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Notes could not be loaded'**
  String get notesLoadFailed;

  /// No description provided for @notesLoadFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Your notes are unchanged. Try restarting the app.'**
  String get notesLoadFailedBody;

  /// No description provided for @notesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No notes yet'**
  String get notesEmptyTitle;

  /// No description provided for @notesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Tap the + button to create a note.'**
  String get notesEmptyBody;

  /// No description provided for @deleteNoteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete this note?'**
  String get deleteNoteQuestion;

  /// No description provided for @cannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get cannotBeUndone;

  /// No description provided for @deleteNote.
  ///
  /// In en, this message translates to:
  /// **'Delete note'**
  String get deleteNote;

  /// No description provided for @noteTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get noteTitleHint;

  /// No description provided for @noteBodyHint.
  ///
  /// In en, this message translates to:
  /// **'Start writing…'**
  String get noteBodyHint;

  /// No description provided for @lockUnlockReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock Romlerk to see your tasks'**
  String get lockUnlockReason;

  /// No description provided for @lockTurnedOffNoPasscode.
  ///
  /// In en, this message translates to:
  /// **'App Lock was turned off because this phone has no passcode.'**
  String get lockTurnedOffNoPasscode;

  /// No description provided for @lockTitle.
  ///
  /// In en, this message translates to:
  /// **'Romlerk is locked'**
  String get lockTitle;

  /// No description provided for @lockBody.
  ///
  /// In en, this message translates to:
  /// **'Your tasks are hidden until you unlock.'**
  String get lockBody;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @notificationRedactedTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get notificationRedactedTitle;

  /// No description provided for @notificationRedactedBody.
  ///
  /// In en, this message translates to:
  /// **'You have a task due. Open Romlerk to see it.'**
  String get notificationRedactedBody;

  /// No description provided for @notificationComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get notificationComplete;

  /// No description provided for @notificationSnooze.
  ///
  /// In en, this message translates to:
  /// **'Snooze 15 min'**
  String get notificationSnooze;

  /// No description provided for @notificationChannelName.
  ///
  /// In en, this message translates to:
  /// **'Task reminders'**
  String get notificationChannelName;

  /// No description provided for @notificationChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Reminders for tasks you scheduled in Romlerk.'**
  String get notificationChannelDescription;

  /// No description provided for @filterNext7Days.
  ///
  /// In en, this message translates to:
  /// **'Next 7 days'**
  String get filterNext7Days;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'km'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'km':
      return AppLocalizationsKm();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
