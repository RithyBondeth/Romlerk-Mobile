// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Khmer Central Khmer (`km`).
class AppLocalizationsKm extends AppLocalizations {
  AppLocalizationsKm([String locale = 'km']) : super(locale);

  @override
  String get appTitle => 'រំលឹក';

  @override
  String get today => 'ថ្ងៃនេះ';

  @override
  String get upcoming => 'ខាងមុខ';

  @override
  String get inbox => 'ប្រអប់សារ';

  @override
  String get search => 'ស្វែងរក';

  @override
  String get settings => 'ការកំណត់';

  @override
  String get overdue => 'ហួសកំណត់';

  @override
  String get doneToday => 'រួចរាល់ថ្ងៃនេះ';

  @override
  String get markComplete => 'សញ្ញាជោគជ័យ';

  @override
  String get reopenTask => 'បើកភារកិច្ចឡើងវិញ';

  @override
  String get planMyDay => 'រៀបចំផែនការថ្ងៃនេះ';

  @override
  String get whatShouldIDoNow => 'តើខ្ញុំគួរធ្វើអ្វីបន្ត?';

  @override
  String get suggestedFocus => 'ចំណុចសំខាន់ដែលគួរធ្វើ';

  @override
  String get deleteTask => 'លុបភារកិច្ច';

  @override
  String get exportCalendar => 'នាំចេញជាឯកសារ .ics';

  @override
  String get eraseAllData => 'លុបទិន្នន័យទាំងអស់';

  @override
  String get continueAction => 'បន្ត';

  @override
  String get saveTask => 'រក្សាទុក';

  @override
  String get cancel => 'បោះបង់';

  @override
  String formatExactAt(String date, String time) {
    return '$date ម៉ោង $time';
  }

  @override
  String formatTomorrowAt(String time) {
    return 'ស្អែក $time';
  }

  @override
  String formatYesterdayAt(String time) {
    return 'ម្សិលមិញ $time';
  }

  @override
  String formatWeekdayAt(String weekday, String time) {
    return '$weekday $time';
  }

  @override
  String formatLastWeekdayAt(String weekday, String time) {
    return '$weekdayមុន $time';
  }

  @override
  String formatDateAt(String date, String time) {
    return '$date $time';
  }

  @override
  String formatTodayHeading(String date) {
    return 'ថ្ងៃនេះ · $date';
  }

  @override
  String formatTomorrowHeading(String date) {
    return 'ស្អែក · $date';
  }

  @override
  String overdueMinutes(int count) {
    return 'ហួសកំណត់ $count នាទី';
  }

  @override
  String overdueHours(int count) {
    return 'ហួសកំណត់ $count ម៉ោង';
  }

  @override
  String overdueDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ហួសកំណត់ $count ថ្ងៃ',
    );
    return '$_temp0';
  }

  @override
  String overdueWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ហួសកំណត់ $count សប្ដាហ៍',
    );
    return '$_temp0';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes នាទី';
  }

  @override
  String durationHours(int hours) {
    return '$hours ម៉ោង';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours ម៉ោង $minutes នាទី';
  }

  @override
  String get priorityNone => 'គ្មានអាទិភាព';

  @override
  String get priorityLow => 'ទាប';

  @override
  String get priorityMedium => 'មធ្យម';

  @override
  String get priorityHigh => 'ខ្ពស់';

  @override
  String get recurEveryDay => 'រៀងរាល់ថ្ងៃ';

  @override
  String recurEveryNDays(int count) {
    return 'រៀងរាល់ $count ថ្ងៃម្ដង';
  }

  @override
  String get recurEveryWeek => 'រៀងរាល់សប្ដាហ៍';

  @override
  String recurEveryNWeeks(int count) {
    return 'រៀងរាល់ $count សប្ដាហ៍ម្ដង';
  }

  @override
  String get recurEveryMonth => 'រៀងរាល់ខែ';

  @override
  String recurEveryNMonths(int count) {
    return 'រៀងរាល់ $count ខែម្ដង';
  }

  @override
  String get recurEveryYear => 'រៀងរាល់ឆ្នាំ';

  @override
  String recurEveryNYears(int count) {
    return 'រៀងរាល់ $count ឆ្នាំម្ដង';
  }

  @override
  String get recurEveryWeekday => 'រៀងរាល់ថ្ងៃធ្វើការ';

  @override
  String recurWeeklyOn(String days) {
    return 'រៀងរាល់សប្ដាហ៍ នៅថ្ងៃ $days';
  }

  @override
  String recurEveryNWeeksOn(int count, String days) {
    return 'រៀងរាល់ $count សប្ដាហ៍ម្ដង នៅថ្ងៃ $days';
  }

  @override
  String recurTimes(String rule, int count) {
    return '$rule ចំនួន $count ដង';
  }

  @override
  String recurUntil(String rule, String date) {
    return '$rule រហូតដល់ $date';
  }

  @override
  String get loadFailedBody =>
      'កិច្ចការរបស់អ្នកមិនបានផ្លាស់ប្ដូរទេ។ សូមសាកល្បងបើកកម្មវិធីឡើងវិញ។';

  @override
  String get upcomingLoadFailed => 'មិនអាចផ្ទុកកិច្ចការខាងមុខបានទេ';

  @override
  String get upcomingEmptyTitle => 'មិនទាន់មានអ្វីកំណត់ពេលខាងមុខទេ';

  @override
  String get upcomingEmptyBody =>
      'កិច្ចការដែលមានកាលបរិច្ឆេទក្រោយថ្ងៃនេះ នឹងបង្ហាញនៅទីនេះតាមថ្ងៃ។';

  @override
  String get nothingScheduled => 'មិនមានអ្វីកំណត់ពេលទេ';

  @override
  String taskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count កិច្ចការ',
    );
    return '$_temp0';
  }

  @override
  String dayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ថ្ងៃ',
    );
    return '$_temp0';
  }

  @override
  String upcomingSubtitle(String tasks, String days) {
    return '$tasks ក្នុងរយៈពេល $days';
  }

  @override
  String get todayEmptyTitle => 'ថ្ងៃនេះគ្មានអ្វីត្រូវធ្វើទេ';

  @override
  String get todayEmptyBody =>
      'អ្វីដែលអ្នកកត់ត្រាសម្រាប់ថ្ងៃនេះ នឹងបង្ហាញនៅទីនេះ។';

  @override
  String todayRemaining(String date, int count) {
    return '$date · នៅសល់ $count';
  }

  @override
  String get todayLoadFailedTitle => 'មិនអាចអានកិច្ចការរបស់អ្នកបានទេ';

  @override
  String get todayLoadFailedBody =>
      'មូលដ្ឋានទិន្នន័យក្នុងទូរស័ព្ទមិនអាចបើកបានទេ។ ទិន្នន័យរបស់អ្នកមិនបានផ្លាស់ប្ដូរទេ។ ការបើកកម្មវិធីឡើងវិញជាធម្មតាអាចដោះស្រាយបញ្ហានេះ។';

  @override
  String get rankOverdue => 'ហួសកំណត់';

  @override
  String get rankDueSoon => 'ត្រូវធ្វើក្នុងរយៈពេល ២ ម៉ោង';

  @override
  String get rankDueToday => 'ត្រូវធ្វើថ្ងៃនេះ';

  @override
  String get rankDueWithinDay => 'ត្រូវធ្វើក្នុងរយៈពេល ២៤ ម៉ោង';

  @override
  String get rankHighPriority => 'អាទិភាពខ្ពស់';

  @override
  String rankQuickWin(int minutes) {
    return 'ធ្វើបានលឿន ($minutes នាទី)';
  }

  @override
  String get rankActive => 'កិច្ចការកំពុងបើក';

  @override
  String get reminderNotSet => 'មិនទាន់កំណត់ការរំលឹក';

  @override
  String get a11yCompleted => 'បានបញ្ចប់';

  @override
  String a11yDue(String when) {
    return 'កំណត់ $when';
  }

  @override
  String a11yPriority(String priority) {
    return 'អាទិភាព$priority';
  }

  @override
  String get completedLabel => 'បានបញ្ចប់';

  @override
  String ringProgress(int completed, int total) {
    return 'បានបញ្ចប់ $completed ក្នុងចំណោម $total កិច្ចការ';
  }

  @override
  String get capReady => 'ការយល់ដឹងកម្រិតខ្ពស់នៅលើឧបករណ៍ រួចរាល់ហើយ។';

  @override
  String get capBaseline => 'ឧបករណ៍នេះអាចអានកាលបរិច្ឆេទបានយ៉ាងរហ័ស។';

  @override
  String get capManual =>
      'វាយព័ត៌មានលម្អិត ហើយវានឹងត្រូវរក្សាទុកដូចដែលអ្នកបានបញ្ចូល។';

  @override
  String get capCheckAgain => 'ពិនិត្យម្ដងទៀត';

  @override
  String get capDisabled =>
      'AI នៅលើឧបករណ៍ត្រូវបានបិទក្នុងការកំណត់ប្រព័ន្ធ។ ការអានកាលបរិច្ឆេទនៅតែដំណើរការ។';

  @override
  String get capNotReady =>
      'ម៉ូដែលនៅលើឧបករណ៍កំពុងរៀបចំ។ ការអានកាលបរិច្ឆេទត្រូវបានប្រើជាបណ្ដោះអាសន្ន។';

  @override
  String get capBusy =>
      'ម៉ូដែលនៅលើឧបករណ៍កំពុងរវល់។ ការអានកាលបរិច្ឆេទត្រូវបានប្រើសម្រាប់ពេលនេះ។';

  @override
  String get capFallback => 'ការអានកាលបរិច្ឆេទត្រូវបានប្រើសម្រាប់ពេលនេះ។';

  @override
  String get plannedTime => 'ពេលវេលាដែលបានគ្រោង';

  @override
  String plannedSummary(String hours, String tasks) {
    return '$hours ម៉ោង · $tasks';
  }

  @override
  String get planSelectTasks => 'ជ្រើសរើសកិច្ចការសម្រាប់ថ្ងៃនេះ';

  @override
  String planSaved(String tasks) {
    return 'បានរក្សាទុកផែនការ ជាមួយ $tasks។';
  }

  @override
  String get planConfirm => 'បញ្ជាក់ផែនការថ្ងៃនេះ';

  @override
  String get inboxLoadFailed => 'មិនអាចផ្ទុកប្រអប់ទទួលបានទេ';

  @override
  String get inboxEmptyTitle => 'ប្រអប់ទទួលទទេ';

  @override
  String get inboxEmptyBody =>
      'អ្វីដែលអ្នកកត់ត្រាដោយគ្មានកាលបរិច្ឆេទ នឹងរង់ចាំនៅទីនេះ រហូតដល់អ្នកសម្រេចថាពេលណាត្រូវធ្វើ។';

  @override
  String get inboxSubtitleEmpty => 'គ្មានកិច្ចការដែលគ្មានកាលបរិច្ឆេទ';

  @override
  String inboxSubtitle(int count) {
    return '$count គ្មានកាលបរិច្ឆេទ';
  }

  @override
  String get notes => 'កំណត់ចំណាំ';

  @override
  String get captureBarHint => 'តើត្រូវធ្វើអ្វី?';

  @override
  String get captureBarLabel => 'កត់ត្រាកិច្ចការថ្មី';

  @override
  String get errModelUnavailable => 'ឧបករណ៍នេះមិនគាំទ្រការយល់ដឹងកម្រិតខ្ពស់ទេ។';

  @override
  String get errModelDisabled =>
      'AI នៅលើឧបករណ៍ត្រូវបានបិទក្នុងការកំណត់ប្រព័ន្ធ។';

  @override
  String get errModelNotReady => 'ម៉ូដែលនៅលើឧបករណ៍កំពុងរៀបចំ។';

  @override
  String get errBusy => 'ម៉ូដែលនៅលើឧបករណ៍កំពុងរវល់នៅពេលនេះ។';

  @override
  String get errBackground =>
      'AI នៅលើឧបករណ៍ដំណើរការតែពេលកម្មវិធីកំពុងបើកប៉ុណ្ណោះ។';

  @override
  String get errLanguage =>
      'ភាសានេះមិនទាន់គាំទ្រសម្រាប់ការយល់ដឹងកម្រិតខ្ពស់ទេ។';

  @override
  String get errOutputInvalid => 'លទ្ធផលមិនអាចអានបាន ដូច្នេះមិនត្រូវបានប្រើទេ។';

  @override
  String get errTimeout => 'វាចំណាយពេលយូរពេក។';

  @override
  String get errCancelled => 'បានបោះបង់។';

  @override
  String get errInputTooLong =>
      'អត្ថបទនេះវែងជាងអ្វីដែលម៉ូដែលអាចអានបានក្នុងពេលតែមួយ។';

  @override
  String get errUnknown => 'មានបញ្ហាអ្វីមួយកើតឡើង។';

  @override
  String get voiceNoSpeech => 'មិនបានឮច្បាស់ទេ។ សូមនិយាយម្ដងទៀត ឬវាយបញ្ចូល។';

  @override
  String get voicePermissionDenied =>
      'ការចូលប្រើមីក្រូហ្វូនត្រូវបានបិទ។ អ្នកអាចអនុញ្ញាតវានៅក្នុងការកំណត់។';

  @override
  String get voiceLanguageUnsupported =>
      'សំឡេងនៅលើឧបករណ៍មិនទាន់មានសម្រាប់ភាសានេះទេ។ ការវាយបញ្ចូលដំណើរការដូចគ្នា។';

  @override
  String get voiceBusy => 'មីក្រូហ្វូនកំពុងរវល់។ សូមព្យាយាមម្ដងទៀតបន្តិចក្រោយ។';

  @override
  String get voiceUnavailable =>
      'សំឡេងនៅលើឧបករណ៍មិនមាននៅលើទូរស័ព្ទនេះទេ។ ការវាយបញ្ចូលដំណើរការដូចគ្នា។';

  @override
  String get voiceFailed => 'សំឡេងបានឈប់ដោយមិនរំពឹងទុក។ អត្ថបទរបស់អ្នកនៅដដែល។';

  @override
  String get voiceListening => 'កំពុងស្ដាប់…';

  @override
  String get voiceFinishing => 'កំពុងបញ្ចប់…';

  @override
  String get voiceDone => 'រួចរាល់';

  @override
  String get voiceSpeakTask => 'និយាយកិច្ចការ';

  @override
  String get voicePrivacyTitle => 'សំឡេងនៅតែលើទូរស័ព្ទនេះ';

  @override
  String get voicePrivacyBody =>
      'រំលឹកប្រើការស្គាល់សំឡេងដែលមានស្រាប់ក្នុងទូរស័ព្ទរបស់អ្នក ក្នុងរបៀបនៅលើឧបករណ៍។ ពាក្យរបស់អ្នកក្លាយជាអត្ថបទនៅទីនេះ ហើយសំឡេងមិនដែលត្រូវបានបញ្ជូនចេញ ឬរក្សាទុកឡើយ។\n\nអ្នកនឹងឃើញអត្ថបទ ហើយអាចកែប្រែវា មុនពេលរក្សាទុក។';

  @override
  String get voicePrivacyPermissionNote =>
      'បន្ទាប់មក ទូរស័ព្ទរបស់អ្នកនឹងសុំការអនុញ្ញាតប្រើមីក្រូហ្វូន។';

  @override
  String get notNow => 'ពេលក្រោយ';

  @override
  String get captureCheckBeforeSaving => 'សូមពិនិត្យមុនពេលរក្សាទុក';

  @override
  String captureTasksFound(int count) {
    return 'រកឃើញ $count កិច្ចការ';
  }

  @override
  String get taskSaved => 'បានរក្សាទុកកិច្ចការ';

  @override
  String tasksSaved(int count) {
    return 'បានរក្សាទុក $count កិច្ចការ';
  }

  @override
  String get captureHint => 'ទូរស័ព្ទទៅដាវីតស្អែកម៉ោង ៩…';

  @override
  String get captureTextKept => 'អត្ថបទរបស់អ្នកនៅតែនៅទីនេះ។';

  @override
  String get tryAgain => 'ព្យាយាមម្ដងទៀត';

  @override
  String get captureReadWithRules => 'បានអានដោយការអានកាលបរិច្ឆេទដែលមានស្រាប់។';

  @override
  String get captureTry => 'សាកល្បង';

  @override
  String get captureExample1 => 'ទិញទឹកដោះគោស្អែកម៉ោង ៩ព្រឹក';

  @override
  String get captureExample2 => 'ប្រជុំថ្ងៃសុក្រម៉ោង ២រសៀល';

  @override
  String get captureExample3 => 'បង់ថ្លៃផ្ទះថ្ងៃច័ន្ទ បន្ទាន់';

  @override
  String get captureExample4 => 'រៀងរាល់ថ្ងៃ ធ្វើលំហាត់ប្រាណម៉ោង ៦ព្រឹក';

  @override
  String get captureReading => 'កំពុងអាន…';

  @override
  String get captureResolveFirst => 'សូមឆ្លើយសំណួរដែលបានបន្លិចជាមុនសិន។';

  @override
  String saveTasks(int count) {
    return 'រក្សាទុក $count កិច្ចការ';
  }

  @override
  String get reminderBlocked =>
      'បានរក្សាទុក ប៉ុន្តែនឹងមិនមានការរំលឹកទេ — ការជូនដំណឹងត្រូវបានបិទ។';

  @override
  String get reminderFailed => 'បានរក្សាទុក ប៉ុន្តែមិនអាចកំណត់ការរំលឹកបានទេ។';

  @override
  String get draftRemove => 'ដកកិច្ចការនេះចេញ';

  @override
  String get draftAddDate => 'បន្ថែមកាលបរិច្ឆេទ';

  @override
  String draftEstimate(String duration) {
    return '$duration (ប៉ាន់ស្មាន)';
  }

  @override
  String draftRemindsYou(String when) {
    return 'រំលឹកអ្នក $when';
  }

  @override
  String get draftReminderOff => 'បិទ';

  @override
  String get draftNoReminder => 'គ្មានការរំលឹក';

  @override
  String get draftRemindMe => 'រំលឹកខ្ញុំ';

  @override
  String get priority => 'អាទិភាព';

  @override
  String warnTimeAssumed(String time) {
    return 'មិនបានបញ្ជាក់ម៉ោង ដូច្នេះបានប្រើម៉ោង $time។';
  }

  @override
  String warnTimeApproximate(String phrase, String time) {
    return '“$phrase” ត្រូវបានយល់ថាជាម៉ោង $time។';
  }

  @override
  String warnRolledToTomorrow(String time) {
    return 'ម៉ោង $time បានកន្លងផុតហើយសម្រាប់ថ្ងៃនេះ ដូច្នេះត្រូវបានកំណត់សម្រាប់ថ្ងៃស្អែក។';
  }

  @override
  String get warnTimeInPast => 'ពេលវេលានោះបានកន្លងផុតហើយ។ នឹងមិនមានការរំលឹកទេ។';

  @override
  String warnDstShift(String time) {
    return 'ថ្ងៃនោះមានការប្ដូរម៉ោង ដូច្នេះបានប្រើម៉ោង $time។';
  }

  @override
  String get warnRecurrenceWithoutDate =>
      'កិច្ចការដដែលៗត្រូវការកាលបរិច្ឆេទដំបូង មុនពេលវាអាចធ្វើម្ដងទៀតបាន។';

  @override
  String askMeridiem(String first, String second) {
    return 'តើអ្នកចង់និយាយថា $first ឬ $second?';
  }

  @override
  String askVagueTime(String phrase) {
    return '“$phrase” មិនបានបញ្ជាក់ពេលវេលាទេ។ សូមជ្រើសរើសពេលវេលា។';
  }

  @override
  String get altThisEvening => 'ល្ងាចនេះ';

  @override
  String get altTomorrowMorning => 'ព្រឹកស្អែក';

  @override
  String get altNextWeek => 'សប្ដាហ៍ក្រោយ';

  @override
  String get searchEverything => 'អ្វីៗទាំងអស់នៅលើឧបករណ៍នេះ';

  @override
  String searchMatches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ត្រូវគ្នា $count',
    );
    return '$_temp0';
  }

  @override
  String searchOpenCount(int count) {
    return '$count កំពុងបើក';
  }

  @override
  String searchDoneCount(int count) {
    return '$count រួចរាល់';
  }

  @override
  String get searchHint => 'ស្វែងរកចំណងជើង និងកំណត់ចំណាំ';

  @override
  String get searchClear => 'សម្អាតការស្វែងរក';

  @override
  String get viewAll => 'ទាំងអស់';

  @override
  String get viewOpen => 'កំពុងបើក';

  @override
  String get viewDone => 'រួចរាល់';

  @override
  String get filterHighPriority => 'អាទិភាពខ្ពស់';

  @override
  String get filterNoDate => 'គ្មានកាលបរិច្ឆេទ';

  @override
  String get searchFailed => 'ការស្វែងរកបរាជ័យ';

  @override
  String get searchNoMatches => 'រកមិនឃើញ';

  @override
  String get searchNothingDone => 'មិនទាន់មានអ្វីរួចរាល់ទេ';

  @override
  String get searchYourTasks => 'ស្វែងរកកិច្ចការរបស់អ្នក';

  @override
  String searchNoMatchesBody(String query) {
    return 'គ្មានអ្វីត្រូវគ្នានឹង “$query” ទេ។ តម្រងក៏អាចកំពុងបង្រួមលទ្ធផលផងដែរ។';
  }

  @override
  String get searchNothingDoneBody =>
      'កិច្ចការដែលអ្នកបានបញ្ចប់ត្រូវបានរក្សាទុកនៅទីនេះ ដើម្បីអ្នកអាចបើកវាឡើងវិញ ប្រសិនបើត្រូវការ។';

  @override
  String get searchOfflineBody =>
      'អ្វីៗទាំងអស់ត្រូវបានរក្សាទុកនៅលើឧបករណ៍នេះ ដូច្នេះការស្វែងរកដំណើរការដោយគ្មានអ៊ីនធឺណិត។';

  @override
  String get detailOpenFailed => 'មិនអាចបើកកិច្ចការនេះបានទេ';

  @override
  String get detailNothingChanged => 'គ្មានអ្វីត្រូវបានផ្លាស់ប្ដូរទេ។';

  @override
  String get detailGone => 'កិច្ចការនេះលែងមានទៀតហើយ';

  @override
  String get detailGoneBody => 'វាប្រហែលជាត្រូវបានលុបពីអេក្រង់ផ្សេង។';

  @override
  String get deleteTaskQuestion => 'លុបកិច្ចការនេះ?';

  @override
  String get deleteTaskBody =>
      'វានឹងត្រូវបានលុបចេញពីឧបករណ៍នេះ រួមទាំងការរំលឹករបស់វាផង។ សកម្មភាពនេះមិនអាចត្រឡប់វិញបានទេ។';

  @override
  String get keep => 'រក្សាទុក';

  @override
  String get delete => 'លុប';

  @override
  String get detailDue => 'កំណត់';

  @override
  String get detailNotScheduled => 'មិនទាន់កំណត់ពេល';

  @override
  String get detailReminder => 'ការរំលឹក';

  @override
  String get detailReminderBlocked => 'នឹងមិនមកដល់ទេ — ការជូនដំណឹងត្រូវបានបិទ';

  @override
  String get detailReminderFailed => 'មិនអាចកំណត់ពេលបានទេ';

  @override
  String get detailReminderDelivered => 'បានផ្ញើរួចហើយ';

  @override
  String get detailReminderCancelled => 'បានបោះបង់';

  @override
  String get detailRepeats => 'ធ្វើម្ដងទៀត';

  @override
  String get detailTakes => 'ចំណាយពេល';

  @override
  String get detailTags => 'ស្លាក';

  @override
  String get detailCalendar => 'ព្រឹត្តិការណ៍ប្រតិទិន';

  @override
  String detailCompletedAt(String when) {
    return 'បានបញ្ចប់ $when';
  }

  @override
  String get detailNotes => 'កំណត់ចំណាំ';

  @override
  String get detailNotesHint => 'ព័ត៌មានលម្អិតបន្ថែម…';

  @override
  String detailCreatedAt(String when) {
    return 'បានបង្កើត $when';
  }

  @override
  String get detailIcsCopied =>
      'បានចម្លងព្រឹត្តិការណ៍ប្រតិទិន (.ics) ទៅក្ដារតម្បៀតខ្ទាស់';

  @override
  String get lockNeedsPasscode =>
      'សូមកំណត់លេខសម្ងាត់នៅលើទូរស័ព្ទរបស់អ្នកជាមុនសិន រួចព្យាយាមម្ដងទៀត។';

  @override
  String get lockConfirmOn => 'បញ្ជាក់ថាជាអ្នក ដើម្បីបើកការចាក់សោកម្មវិធី';

  @override
  String get lockConfirmOff => 'បញ្ជាក់ថាជាអ្នក ដើម្បីបិទការចាក់សោកម្មវិធី';

  @override
  String get sectionAppearance => 'រូបរាង';

  @override
  String get sectionPrivacy => 'ឯកជនភាព';

  @override
  String get sectionDevice => 'នៅលើឧបករណ៍នេះ';

  @override
  String get sectionCapture => 'ការកត់ត្រា';

  @override
  String get sectionData => 'ទិន្នន័យរបស់អ្នក';

  @override
  String get privacyHeadline => 'កិច្ចការរបស់អ្នកនៅលើឧបករណ៍នេះ';

  @override
  String get privacyBody =>
      'អត្ថបទកិច្ចការ កំណត់ចំណាំ និងការរំលឹក ត្រូវបានរក្សាទុកក្នុងមូលដ្ឋានទិន្នន័យនៅលើទូរស័ព្ទនេះ ហើយដំណើរការនៅលើឧបករណ៍។ គ្មានគណនី គ្មានម៉ាស៊ីនមេ និងគ្មាន AI លើពពកទេ។ ច្បាប់ចម្លងតែមួយគត់ដែលអាចចេញពីទូរស័ព្ទ គឺការបម្រុងទុកដែលបានអ៊ិនគ្រីបរបស់អ្នកផ្ទាល់ ដែលអ្នកអាចគ្រប់គ្រងខាងក្រោម។';

  @override
  String get diagnosticsTitle => 'ចែករំលែកព័ត៌មានវិនិច្ឆ័យអនាមិក';

  @override
  String get diagnosticsBody =>
      'តែលេខកូដកំហុស និងរយៈពេលប៉ុណ្ណោះ។ មិនដែលមានអត្ថបទកិច្ចការ ចំណងជើង កំណត់ចំណាំ ឬស្លាកទេ។ អាចបិទបានគ្រប់ពេល។';

  @override
  String get backupTitle => 'បញ្ចូលកិច្ចការក្នុងការបម្រុងទុករបស់ទូរស័ព្ទ';

  @override
  String get backupPending => 'នឹងមានប្រសិទ្ធភាពនៅពេលបើករំលឹកលើកក្រោយ។';

  @override
  String get backupBodyIos =>
      'អនុញ្ញាតឱ្យ iCloud Backup ស្ដារកិច្ចការរបស់អ្នកនៅលើ iPhone ថ្មី។ បើបិទ កិច្ចការនឹងនៅតែលើទូរស័ព្ទនេះប៉ុណ្ណោះ។';

  @override
  String get backupBodyAndroid =>
      'អនុញ្ញាតឱ្យការបម្រុងទុក Google ដែលបានអ៊ិនគ្រីប ស្ដារកិច្ចការរបស់អ្នកនៅលើទូរស័ព្ទថ្មី។ បើបិទ កិច្ចការនឹងនៅតែលើទូរស័ព្ទនេះប៉ុណ្ណោះ។';

  @override
  String get redactTitle => 'លាក់អត្ថបទកិច្ចការក្នុងការជូនដំណឹង';

  @override
  String get redactBody =>
      'បង្ហាញការរំលឹកទូទៅ ជំនួសឱ្យចំណងជើងកិច្ចការ នៅលើអេក្រង់ចាក់សោ និងវិដជិតលើអេក្រង់ដើម។';

  @override
  String get appLockTitle => 'ចាក់សោកម្មវិធី';

  @override
  String get appLockBody =>
      'ស្នើ Face ID ស្នាមម្រាមដៃ ឬលេខសម្ងាត់ទូរស័ព្ទ នៅពេលបើករំលឹក។';

  @override
  String capabilityTier(String tier, String provider) {
    return 'កម្រិតសមត្ថភាព $tier · $provider';
  }

  @override
  String get capabilityCheckFailed =>
      'មិនអាចពិនិត្យសមត្ថភាពបានទេ។ ការអានកាលបរិច្ឆេទនៅតែដំណើរការ។';

  @override
  String get introAgain => 'បង្ហាញការណែនាំម្ដងទៀត';

  @override
  String get introAgainBody => 'បង្ហាញអេក្រង់ស្វាគមន៍ទាំងបីឡើងវិញ។';

  @override
  String get defaultTime => 'ម៉ោងលំនាំដើម';

  @override
  String get defaultTimeBody => 'ប្រើនៅពេលកិច្ចការមានកាលបរិច្ឆេទ តែគ្មានម៉ោង។';

  @override
  String get alwaysReview => 'ពិនិត្យជានិច្ចមុនពេលរក្សាទុក';

  @override
  String get alwaysReviewBody =>
      'បើបិទ ការកត់ត្រាដែលច្បាស់លាស់នឹងរក្សាទុកក្នុងមួយជំហាន។ អ្វីដែលកម្មវិធីមិនប្រាកដ នឹងនៅតែបង្ហាញជាមុន។';

  @override
  String get exportJson => 'នាំចេញជា JSON';

  @override
  String get exportJsonBody =>
      'ច្បាប់ចម្លងពេញលេញនៃកិច្ចការទាំងអស់ ដែលអាចយកទៅប្រើកន្លែងផ្សេងបាន។';

  @override
  String get exportCsv => 'នាំចេញជា CSV';

  @override
  String get exportCsvBody => 'បើកក្នុងកម្មវិធីតារាង។';

  @override
  String get eraseAllBody =>
      'លុបកិច្ចការ ស្លាក និងការរំលឹកទាំងអស់ចេញពីឧបករណ៍នេះ។';

  @override
  String get exportNothing => 'មិនទាន់មានអ្វីសម្រាប់នាំចេញទេ។';

  @override
  String get exportSubject => 'កិច្ចការរំលឹក';

  @override
  String get exportFailed =>
      'មិនអាចបង្កើតការនាំចេញបានទេ។ គ្មានអ្វីផ្លាស់ប្ដូរទេ។';

  @override
  String get eraseQuestion => 'លុបអ្វីៗទាំងអស់?';

  @override
  String eraseBody(String tasks) {
    return 'វានឹងលុប $tasks ស្លាកទាំងអស់ និងការរំលឹកទាំងអស់ ចេញពីឧបករណ៍នេះជាអចិន្ត្រៃយ៍។ សកម្មភាពនេះមិនអាចត្រឡប់វិញបានទេ។ ការបម្រុងទុកពីមុនរបស់ទូរស័ព្ទ អាចនៅតែមានច្បាប់ចម្លង រហូតដល់ទូរស័ព្ទជំនួសវា។';
  }

  @override
  String get erase => 'លុប';

  @override
  String get eraseDone => 'ទិន្នន័យទាំងអស់ត្រូវបានលុបចេញពីឧបករណ៍នេះ។';

  @override
  String get themeSystem => 'ប្រព័ន្ធ';

  @override
  String get themeLight => 'ភ្លឺ';

  @override
  String get themeDark => 'ងងឹត';

  @override
  String get onboardPrivateTitle => 'អ្វីៗទាំងអស់នៅលើទូរស័ព្ទនេះ';

  @override
  String get onboardPrivateBody =>
      'គ្មានគណនី គ្មានម៉ាស៊ីនមេ គ្មាន AI លើពពក។ កិច្ចការ កំណត់ចំណាំ និងការរំលឹករបស់អ្នក ត្រូវបានរក្សាទុកក្នុងមូលដ្ឋានទិន្នន័យនៅលើឧបករណ៍នេះ ហើយដំណើរការនៅទីនេះ។';

  @override
  String get onboardSpeakTitle => 'សរសេរដូចដែលអ្នកនិយាយ';

  @override
  String get onboardSpeakBody =>
      '“ទូរស័ព្ទទៅដាវីតស្អែកម៉ោង ៩” ក្លាយជាកិច្ចការដែលមានកាលបរិច្ឆេទ និងការរំលឹក។ មិនចាំបាច់បំពេញទម្រង់ទេ។';

  @override
  String get onboardReviewTitle =>
      'គ្មានអ្វីត្រូវបានរក្សាទុក រហូតដល់អ្នកយល់ព្រម';

  @override
  String get onboardReviewBody =>
      'អ្នកតែងតែឃើញអ្វីដែលនឹងត្រូវបង្កើត ជាមួយកាលបរិច្ឆេទពេញលេញ។ អ្វីដែលកម្មវិធីមិនប្រាកដ នឹងសួរអ្នកជាមុន។';

  @override
  String get skip => 'រំលង';

  @override
  String get next => 'បន្ទាប់';

  @override
  String get getStarted => 'ចាប់ផ្ដើម';

  @override
  String get noteNewTitle => 'កំណត់ចំណាំថ្មី';

  @override
  String get notesLoadFailed => 'មិនអាចផ្ទុកកំណត់ចំណាំបានទេ';

  @override
  String get notesLoadFailedBody =>
      'កំណត់ចំណាំរបស់អ្នកមិនបានផ្លាស់ប្ដូរទេ។ សូមសាកល្បងបើកកម្មវិធីឡើងវិញ។';

  @override
  String get notesEmptyTitle => 'មិនទាន់មានកំណត់ចំណាំទេ';

  @override
  String get notesEmptyBody => 'ចុចប៊ូតុង + ដើម្បីបង្កើតកំណត់ចំណាំ។';

  @override
  String get deleteNoteQuestion => 'លុបកំណត់ចំណាំនេះ?';

  @override
  String get cannotBeUndone => 'សកម្មភាពនេះមិនអាចត្រឡប់វិញបានទេ។';

  @override
  String get deleteNote => 'លុបកំណត់ចំណាំ';

  @override
  String get noteTitleHint => 'ចំណងជើង';

  @override
  String get noteBodyHint => 'ចាប់ផ្ដើមសរសេរ…';

  @override
  String get lockUnlockReason => 'ដោះសោរំលឹក ដើម្បីមើលកិច្ចការរបស់អ្នក';

  @override
  String get lockTurnedOffNoPasscode =>
      'ការចាក់សោកម្មវិធីត្រូវបានបិទ ព្រោះទូរស័ព្ទនេះគ្មានលេខសម្ងាត់។';

  @override
  String get lockTitle => 'រំលឹកត្រូវបានចាក់សោ';

  @override
  String get lockBody => 'កិច្ចការរបស់អ្នកត្រូវបានលាក់ រហូតដល់អ្នកដោះសោ។';

  @override
  String get unlock => 'ដោះសោ';

  @override
  String get notificationRedactedTitle => 'ការរំលឹក';

  @override
  String get notificationRedactedBody =>
      'អ្នកមានកិច្ចការត្រូវធ្វើ។ បើករំលឹកដើម្បីមើល។';

  @override
  String get notificationComplete => 'បញ្ចប់';

  @override
  String get notificationSnooze => 'ពន្យារ ១៥ នាទី';

  @override
  String get notificationChannelName => 'ការរំលឹកកិច្ចការ';

  @override
  String get notificationChannelDescription =>
      'ការរំលឹកសម្រាប់កិច្ចការដែលអ្នកបានកំណត់ពេលក្នុងរំលឹក។';

  @override
  String get filterNext7Days => '៧ ថ្ងៃខាងមុខ';
}
