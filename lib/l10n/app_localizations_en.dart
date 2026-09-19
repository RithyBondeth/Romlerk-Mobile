// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Romlerk';

  @override
  String get today => 'Today';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get inbox => 'Inbox';

  @override
  String get search => 'Search';

  @override
  String get settings => 'Settings';

  @override
  String get overdue => 'Overdue';

  @override
  String get doneToday => 'Done today';

  @override
  String get markComplete => 'Mark complete';

  @override
  String get reopenTask => 'Reopen task';

  @override
  String get planMyDay => 'Plan My Day';

  @override
  String get whatShouldIDoNow => 'What should I do now?';

  @override
  String get suggestedFocus => 'Suggested Focus';

  @override
  String get deleteTask => 'Delete task';

  @override
  String get exportCalendar => 'Export as .ics file';

  @override
  String get eraseAllData => 'Erase all data';

  @override
  String get continueAction => 'Continue';

  @override
  String get saveTask => 'Save task';

  @override
  String get cancel => 'Cancel';

  @override
  String formatExactAt(String date, String time) {
    return '$date at $time';
  }

  @override
  String formatTomorrowAt(String time) {
    return 'Tomorrow, $time';
  }

  @override
  String formatYesterdayAt(String time) {
    return 'Yesterday, $time';
  }

  @override
  String formatWeekdayAt(String weekday, String time) {
    return '$weekday, $time';
  }

  @override
  String formatLastWeekdayAt(String weekday, String time) {
    return 'Last $weekday, $time';
  }

  @override
  String formatDateAt(String date, String time) {
    return '$date, $time';
  }

  @override
  String formatTodayHeading(String date) {
    return 'Today · $date';
  }

  @override
  String formatTomorrowHeading(String date) {
    return 'Tomorrow · $date';
  }

  @override
  String overdueMinutes(int count) {
    return '$count min overdue';
  }

  @override
  String overdueHours(int count) {
    return '$count h overdue';
  }

  @override
  String overdueDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days overdue',
      one: '1 day overdue',
    );
    return '$_temp0';
  }

  @override
  String overdueWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks overdue',
      one: '1 week overdue',
    );
    return '$_temp0';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String durationHours(int hours) {
    return '$hours h';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get priorityNone => 'No priority';

  @override
  String get priorityLow => 'Low';

  @override
  String get priorityMedium => 'Medium';

  @override
  String get priorityHigh => 'High';

  @override
  String get recurEveryDay => 'Every day';

  @override
  String recurEveryNDays(int count) {
    return 'Every $count days';
  }

  @override
  String get recurEveryWeek => 'Every week';

  @override
  String recurEveryNWeeks(int count) {
    return 'Every $count weeks';
  }

  @override
  String get recurEveryMonth => 'Every month';

  @override
  String recurEveryNMonths(int count) {
    return 'Every $count months';
  }

  @override
  String get recurEveryYear => 'Every year';

  @override
  String recurEveryNYears(int count) {
    return 'Every $count years';
  }

  @override
  String get recurEveryWeekday => 'Every weekday';

  @override
  String recurWeeklyOn(String days) {
    return 'Every week on $days';
  }

  @override
  String recurEveryNWeeksOn(int count, String days) {
    return 'Every $count weeks on $days';
  }

  @override
  String recurTimes(String rule, int count) {
    return '$rule, $count times';
  }

  @override
  String recurUntil(String rule, String date) {
    return '$rule, until $date';
  }

  @override
  String get loadFailedBody =>
      'Your tasks are unchanged. Try restarting the app.';

  @override
  String get upcomingLoadFailed => 'Upcoming could not be loaded';

  @override
  String get upcomingEmptyTitle => 'Nothing scheduled ahead';

  @override
  String get upcomingEmptyBody =>
      'Tasks with a date after today will be grouped here by day.';

  @override
  String get nothingScheduled => 'Nothing scheduled';

  @override
  String taskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks',
      one: '1 task',
    );
    return '$_temp0';
  }

  @override
  String dayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String upcomingSubtitle(String tasks, String days) {
    return '$tasks across $days';
  }

  @override
  String get todayEmptyTitle => 'Nothing due today';

  @override
  String get todayEmptyBody =>
      'Anything you capture with a date for today will show up here.';

  @override
  String todayRemaining(String date, int count) {
    return '$date · $count left';
  }

  @override
  String get todayLoadFailedTitle => 'Your tasks could not be read';

  @override
  String get todayLoadFailedBody =>
      'The local database did not open. Your data has not been changed. Restarting the app usually clears this.';

  @override
  String get rankOverdue => 'Overdue commitment';

  @override
  String get rankDueSoon => 'Due within 2 hours';

  @override
  String get rankDueToday => 'Due today';

  @override
  String get rankDueWithinDay => 'Due within 24 hours';

  @override
  String get rankHighPriority => 'High priority';

  @override
  String rankQuickWin(int minutes) {
    return 'Quick win ($minutes min)';
  }

  @override
  String get rankActive => 'Active task';

  @override
  String get reminderNotSet => 'Reminder not set';

  @override
  String get a11yCompleted => 'completed';

  @override
  String a11yDue(String when) {
    return 'due $when';
  }

  @override
  String a11yPriority(String priority) {
    return '$priority priority';
  }

  @override
  String get completedLabel => 'Completed';

  @override
  String ringProgress(int completed, int total) {
    return '$completed of $total tasks complete';
  }

  @override
  String get capReady => 'Enhanced on-device understanding is ready.';

  @override
  String get capBaseline => 'Quick date parsing is available on this device.';

  @override
  String get capManual =>
      'Type the details and they will be saved exactly as entered.';

  @override
  String get capCheckAgain => 'Check again';

  @override
  String get capDisabled =>
      'On-device AI is turned off in system settings. Date parsing still works here.';

  @override
  String get capNotReady =>
      'The on-device model is still getting ready. Date parsing is being used in the meantime.';

  @override
  String get capBusy =>
      'The on-device model is busy. Date parsing is being used for now.';

  @override
  String get capFallback => 'Date parsing is being used for now.';

  @override
  String get plannedTime => 'Planned time';

  @override
  String plannedSummary(String hours, String tasks) {
    return '$hours h · $tasks';
  }

  @override
  String get planSelectTasks => 'Select tasks for today';

  @override
  String planSaved(String tasks) {
    return 'Plan saved with $tasks.';
  }

  @override
  String get planConfirm => 'Confirm today\'s plan';

  @override
  String get inboxLoadFailed => 'Inbox could not be loaded';

  @override
  String get inboxEmptyTitle => 'Inbox is clear';

  @override
  String get inboxEmptyBody =>
      'Anything you capture without a date waits here until you decide when to do it.';

  @override
  String get inboxSubtitleEmpty => 'No undated tasks';

  @override
  String inboxSubtitle(int count) {
    return '$count without a date';
  }

  @override
  String get notes => 'Notes';

  @override
  String get captureBarHint => 'What needs doing?';

  @override
  String get captureBarLabel => 'Capture a new task';

  @override
  String get errModelUnavailable =>
      'Enhanced understanding is not supported on this device.';

  @override
  String get errModelDisabled =>
      'On-device AI is turned off in system settings.';

  @override
  String get errModelNotReady => 'The on-device model is still getting ready.';

  @override
  String get errBusy => 'The on-device model is busy right now.';

  @override
  String get errBackground => 'On-device AI only runs while the app is open.';

  @override
  String get errLanguage =>
      'This language is not supported for enhanced understanding.';

  @override
  String get errOutputInvalid =>
      'The result could not be read, so it wasn\'t used.';

  @override
  String get errTimeout => 'That took too long.';

  @override
  String get errCancelled => 'Cancelled.';

  @override
  String get errInputTooLong =>
      'That is longer than the model can read at once.';

  @override
  String get errUnknown => 'Something went wrong.';

  @override
  String get voiceNoSpeech => 'Didn’t catch that. Try again, or type it.';

  @override
  String get voicePermissionDenied =>
      'Microphone access is off. You can allow it in Settings.';

  @override
  String get voiceLanguageUnsupported =>
      'On-device voice isn’t available for this language yet. Typing works the same.';

  @override
  String get voiceBusy => 'The microphone is busy. Try again in a moment.';

  @override
  String get voiceUnavailable =>
      'On-device voice isn’t available on this phone. Typing works the same.';

  @override
  String get voiceFailed => 'Voice stopped unexpectedly. Your text is safe.';

  @override
  String get voiceListening => 'Listening…';

  @override
  String get voiceFinishing => 'Finishing…';

  @override
  String get voiceDone => 'Done';

  @override
  String get voiceSpeakTask => 'Speak a task';

  @override
  String get voicePrivacyTitle => 'Voice stays on this phone';

  @override
  String get voicePrivacyBody =>
      'Romlerk uses your phone’s built-in speech recognition in on-device mode. Your words become text here; audio is never uploaded or saved.\n\nYou’ll see the text before anything is saved, and can edit it.';

  @override
  String get voicePrivacyPermissionNote =>
      'Next, your phone will ask to allow the microphone.';

  @override
  String get notNow => 'Not now';

  @override
  String get captureCheckBeforeSaving => 'Check this before saving';

  @override
  String captureTasksFound(int count) {
    return '$count tasks found';
  }

  @override
  String get taskSaved => 'Task saved';

  @override
  String tasksSaved(int count) {
    return '$count tasks saved';
  }

  @override
  String get captureHint => 'Call David tomorrow at 9…';

  @override
  String get captureTextKept => 'Your text is still here.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get captureReadWithRules => 'Read with built-in date parsing.';

  @override
  String get captureTry => 'Try';

  @override
  String get captureExample1 => 'Call David tomorrow at 9am';

  @override
  String get captureExample2 => 'Buy milk and email Ana tonight';

  @override
  String get captureExample3 => 'Standup every weekday at 9:15am';

  @override
  String get captureExample4 => 'Renew passport on 3 March !!';

  @override
  String get captureReading => 'Reading…';

  @override
  String get captureResolveFirst => 'Resolve the highlighted question first.';

  @override
  String saveTasks(int count) {
    return 'Save $count tasks';
  }

  @override
  String get reminderBlocked =>
      'Saved, but no reminder will arrive — notifications are turned off.';

  @override
  String get reminderFailed =>
      'Saved, but the reminder could not be scheduled.';

  @override
  String get draftRemove => 'Remove this task';

  @override
  String get draftAddDate => 'Add a date';

  @override
  String draftEstimate(String duration) {
    return '$duration (estimate)';
  }

  @override
  String draftRemindsYou(String when) {
    return 'Reminds you $when';
  }

  @override
  String get draftReminderOff => 'Off';

  @override
  String get draftNoReminder => 'No reminder';

  @override
  String get draftRemindMe => 'Remind me';

  @override
  String get priority => 'Priority';

  @override
  String warnTimeAssumed(String time) {
    return 'No time was given, so $time was used.';
  }

  @override
  String warnTimeApproximate(String phrase, String time) {
    return '“$phrase” was read as $time.';
  }

  @override
  String warnRolledToTomorrow(String time) {
    return '$time has already passed today, so this was set for tomorrow.';
  }

  @override
  String get warnTimeInPast =>
      'That time is in the past. No reminder will be scheduled.';

  @override
  String warnDstShift(String time) {
    return 'The clocks change that day, so $time was used.';
  }

  @override
  String get warnRecurrenceWithoutDate =>
      'A repeating task needs a first date before it can repeat.';

  @override
  String askMeridiem(String first, String second) {
    return 'Did you mean $first or $second?';
  }

  @override
  String askVagueTime(String phrase) {
    return '“$phrase” doesn’t say when. Pick a time.';
  }

  @override
  String get altThisEvening => 'This evening';

  @override
  String get altTomorrowMorning => 'Tomorrow morning';

  @override
  String get altNextWeek => 'Next week';

  @override
  String get searchEverything => 'Everything on this device';

  @override
  String searchMatches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count matches',
      one: '1 match',
    );
    return '$_temp0';
  }

  @override
  String searchOpenCount(int count) {
    return '$count open';
  }

  @override
  String searchDoneCount(int count) {
    return '$count done';
  }

  @override
  String get searchHint => 'Search titles and notes';

  @override
  String get searchClear => 'Clear search';

  @override
  String get viewAll => 'All';

  @override
  String get viewOpen => 'Open';

  @override
  String get viewDone => 'Done';

  @override
  String get filterHighPriority => 'High priority';

  @override
  String get filterNoDate => 'No date';

  @override
  String get searchFailed => 'Search failed';

  @override
  String get searchNoMatches => 'No matches';

  @override
  String get searchNothingDone => 'Nothing done yet';

  @override
  String get searchYourTasks => 'Search your tasks';

  @override
  String searchNoMatchesBody(String query) {
    return 'Nothing here matches “$query”. Filters may also be narrowing the results.';
  }

  @override
  String get searchNothingDoneBody =>
      'Tasks you complete are kept here, so you can reopen one if it comes back.';

  @override
  String get searchOfflineBody =>
      'Everything is stored on this device, so search works offline.';

  @override
  String get detailOpenFailed => 'This task could not be opened';

  @override
  String get detailNothingChanged => 'Nothing has been changed.';

  @override
  String get detailGone => 'Task no longer exists';

  @override
  String get detailGoneBody => 'It may have been deleted from another screen.';

  @override
  String get deleteTaskQuestion => 'Delete this task?';

  @override
  String get deleteTaskBody =>
      'It will be removed from this device, along with its reminder. This cannot be undone.';

  @override
  String get keep => 'Keep';

  @override
  String get delete => 'Delete';

  @override
  String get detailDue => 'Due';

  @override
  String get detailNotScheduled => 'Not scheduled';

  @override
  String get detailReminder => 'Reminder';

  @override
  String get detailReminderBlocked =>
      'Will not arrive — notifications are turned off';

  @override
  String get detailReminderFailed => 'Could not be scheduled';

  @override
  String get detailReminderDelivered => 'Already delivered';

  @override
  String get detailReminderCancelled => 'Cancelled';

  @override
  String get detailRepeats => 'Repeats';

  @override
  String get detailTakes => 'Takes';

  @override
  String get detailTags => 'Tags';

  @override
  String get detailCalendar => 'Calendar event';

  @override
  String detailCompletedAt(String when) {
    return 'Completed $when';
  }

  @override
  String get detailNotes => 'Notes';

  @override
  String get detailNotesHint => 'Supporting details…';

  @override
  String detailCreatedAt(String when) {
    return 'Created $when';
  }

  @override
  String get detailIcsCopied => 'Calendar event (.ics) copied to clipboard';

  @override
  String get lockNeedsPasscode =>
      'Set a passcode on your phone first, then try again.';

  @override
  String get lockConfirmOn => 'Confirm it’s you to turn on App Lock';

  @override
  String get lockConfirmOff => 'Confirm it’s you to turn off App Lock';

  @override
  String get sectionAppearance => 'Appearance';

  @override
  String get sectionPrivacy => 'Privacy';

  @override
  String get sectionDevice => 'On this device';

  @override
  String get sectionCapture => 'Capture';

  @override
  String get sectionData => 'Your data';

  @override
  String get privacyHeadline => 'Your tasks stay on this device';

  @override
  String get privacyBody =>
      'Task text, notes, and reminders are stored in a database on this phone and processed on device. There is no account, no server, and no cloud AI. The only copy that can leave the phone is your own encrypted phone backup, which you control below.';

  @override
  String get diagnosticsTitle => 'Share anonymous diagnostics';

  @override
  String get diagnosticsBody =>
      'Error codes and timings only. Never task text, titles, notes, or tags. Can be turned off at any time.';

  @override
  String get backupTitle => 'Include tasks in phone backup';

  @override
  String get backupPending => 'Takes effect the next time Romlerk starts.';

  @override
  String get backupBodyIos =>
      'Lets iCloud Backup restore your tasks on a new iPhone. Off keeps them only on this phone.';

  @override
  String get backupBodyAndroid =>
      'Lets your encrypted Google backup restore your tasks on a new phone. Off keeps them only on this phone.';

  @override
  String get redactTitle => 'Hide task text in notifications';

  @override
  String get redactBody =>
      'Shows a generic reminder instead of the task title on the lock screen and home screen widget.';

  @override
  String get appLockTitle => 'App Lock';

  @override
  String get appLockBody =>
      'Ask for Face ID, fingerprint, or your phone passcode when opening Romlerk.';

  @override
  String capabilityTier(String tier, String provider) {
    return 'Capability tier $tier · $provider';
  }

  @override
  String get capabilityCheckFailed =>
      'Capability could not be checked. Date parsing still works.';

  @override
  String get introAgain => 'Show the intro again';

  @override
  String get introAgainBody => 'Replays the three welcome screens.';

  @override
  String get defaultTime => 'Default time';

  @override
  String get defaultTimeBody =>
      'Used when a task has a date but no time of day.';

  @override
  String get alwaysReview => 'Always review before saving';

  @override
  String get alwaysReviewBody =>
      'Off lets unambiguous captures save in one step. Anything the app is unsure about is still shown first.';

  @override
  String get exportJson => 'Export as JSON';

  @override
  String get exportJsonBody => 'A complete, portable copy of every task.';

  @override
  String get exportCsv => 'Export as CSV';

  @override
  String get exportCsvBody => 'Opens in a spreadsheet.';

  @override
  String get eraseAllBody =>
      'Deletes every task, tag, and scheduled reminder from this device.';

  @override
  String get exportNothing => 'There is nothing to export yet.';

  @override
  String get exportSubject => 'Romlerk tasks';

  @override
  String get exportFailed =>
      'The export could not be created. Nothing changed.';

  @override
  String get eraseQuestion => 'Erase everything?';

  @override
  String eraseBody(String tasks) {
    return 'This permanently deletes $tasks, all tags, and every scheduled reminder from this device. It cannot be undone. Earlier phone backups may still hold a copy until your phone replaces them.';
  }

  @override
  String get erase => 'Erase';

  @override
  String get eraseDone => 'All data erased from this device.';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get onboardPrivateTitle => 'Everything stays on this phone';

  @override
  String get onboardPrivateBody =>
      'No account, no server, no cloud AI. Your tasks, notes, and reminders are stored in a database on this device and processed here.';

  @override
  String get onboardSpeakTitle => 'Write it the way you would say it';

  @override
  String get onboardSpeakBody =>
      '“Call David tomorrow at 9” becomes a task with a date and a reminder. There is no form to fill in.';

  @override
  String get onboardReviewTitle => 'Nothing is saved until you say so';

  @override
  String get onboardReviewBody =>
      'You always see what will be created, with dates spelled out in full. Anything the app is unsure about asks you first.';

  @override
  String get skip => 'Skip';

  @override
  String get next => 'Next';

  @override
  String get getStarted => 'Get started';

  @override
  String get noteNewTitle => 'New note';

  @override
  String get notesLoadFailed => 'Notes could not be loaded';

  @override
  String get notesLoadFailedBody =>
      'Your notes are unchanged. Try restarting the app.';

  @override
  String get notesEmptyTitle => 'No notes yet';

  @override
  String get notesEmptyBody => 'Tap the + button to create a note.';

  @override
  String get deleteNoteQuestion => 'Delete this note?';

  @override
  String get cannotBeUndone => 'This cannot be undone.';

  @override
  String get deleteNote => 'Delete note';

  @override
  String get noteTitleHint => 'Title';

  @override
  String get noteBodyHint => 'Start writing…';

  @override
  String get lockUnlockReason => 'Unlock Romlerk to see your tasks';

  @override
  String get lockTurnedOffNoPasscode =>
      'App Lock was turned off because this phone has no passcode.';

  @override
  String get lockTitle => 'Romlerk is locked';

  @override
  String get lockBody => 'Your tasks are hidden until you unlock.';

  @override
  String get unlock => 'Unlock';

  @override
  String get notificationRedactedTitle => 'Reminder';

  @override
  String get notificationRedactedBody =>
      'You have a task due. Open Romlerk to see it.';

  @override
  String get notificationComplete => 'Complete';

  @override
  String get notificationSnooze => 'Snooze 15 min';

  @override
  String get notificationChannelName => 'Task reminders';

  @override
  String get notificationChannelDescription =>
      'Reminders for tasks you scheduled in Romlerk.';
}
