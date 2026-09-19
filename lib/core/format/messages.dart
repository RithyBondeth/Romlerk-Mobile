import '../../application/task_service.dart';
import '../../domain/drafts/task_draft.dart';
import '../../l10n/app_localizations.dart';
import '../../local_ai/local_ai_error.dart';
import '../../services/voice/voice_capture_service.dart';
import 'task_formatting.dart';

// User-facing wording for codes produced below the UI. Those layers keep an
// English message for logs and as a fallback; what the user reads comes from
// here, in their language.

extension LocalAiErrorText on LocalAiErrorCode {
  String describe(AppLocalizations l10n) => switch (this) {
    LocalAiErrorCode.modelUnavailable => l10n.errModelUnavailable,
    LocalAiErrorCode.modelDisabled => l10n.errModelDisabled,
    LocalAiErrorCode.modelNotReady => l10n.errModelNotReady,
    LocalAiErrorCode.busyOrQuota => l10n.errBusy,
    LocalAiErrorCode.backgroundBlocked => l10n.errBackground,
    LocalAiErrorCode.unsupportedLanguage => l10n.errLanguage,
    LocalAiErrorCode.outputInvalid => l10n.errOutputInvalid,
    LocalAiErrorCode.parseTimeout => l10n.errTimeout,
    LocalAiErrorCode.cancelled => l10n.errCancelled,
    LocalAiErrorCode.inputTooLong => l10n.errInputTooLong,
    LocalAiErrorCode.unknown => l10n.errUnknown,
  };
}

extension VoiceErrorText on VoiceErrorCode {
  String describe(AppLocalizations l10n) => switch (this) {
    VoiceErrorCode.noSpeech => l10n.voiceNoSpeech,
    VoiceErrorCode.permissionDenied => l10n.voicePermissionDenied,
    VoiceErrorCode.languageUnsupported => l10n.voiceLanguageUnsupported,
    VoiceErrorCode.busy => l10n.voiceBusy,
    VoiceErrorCode.unavailable => l10n.voiceUnavailable,
    VoiceErrorCode.failed => l10n.voiceFailed,
  };
}

extension ReminderIssueText on ReminderIssue {
  String describe(AppLocalizations l10n) => switch (this) {
    ReminderIssue.notificationsOff => l10n.reminderBlocked,
    ReminderIssue.notScheduled => l10n.reminderFailed,
  };
}

extension DraftWarningText on DraftWarning {
  /// Phrased from [code] and the draft's resolved time. Codes this does not
  /// know (from a model, say) fall back to the English [message].
  String describe(
    AppLocalizations l10n,
    TaskFormatting formatting,
    TaskDraft draft,
  ) {
    final due = draft.dueAt;
    final time = due == null ? null : formatting.timeOnly(due);
    return switch (code) {
      'TIME_ASSUMED' when time != null => l10n.warnTimeAssumed(time),
      'TIME_APPROXIMATE' when time != null && sourceSpan != null =>
        l10n.warnTimeApproximate(sourceSpan!, time),
      'ROLLED_TO_TOMORROW' when time != null =>
        l10n.warnRolledToTomorrow(time),
      'TIME_IN_PAST' => l10n.warnTimeInPast,
      'DST_SHIFT' when time != null => l10n.warnDstShift(time),
      'RECURRENCE_WITHOUT_DATE' => l10n.warnRecurrenceWithoutDate,
      _ => message,
    };
  }
}

extension DraftAmbiguityText on DraftAmbiguity {
  String describe(AppLocalizations l10n, TaskFormatting formatting) {
    final times = alternatives
        .map((option) => option.dateTime)
        .whereType<DateTime>()
        .map(formatting.timeOnly)
        .toList();
    return switch (code) {
      DraftAmbiguity.meridiemCode when times.length == 2 =>
        l10n.askMeridiem(times[0], times[1]),
      DraftAmbiguity.vagueTimeCode when sourceSpan != null =>
        l10n.askVagueTime(sourceSpan!),
      _ => reason,
    };
  }
}

extension DraftAlternativeText on DraftAlternative {
  String describe(
    AppLocalizations l10n,
    TaskFormatting formatting,
    DraftAmbiguity question,
  ) {
    if (question.code == DraftAmbiguity.meridiemCode && dateTime != null) {
      return formatting.timeOnly(dateTime!);
    }
    return switch (code) {
      DraftAlternative.thisEveningCode => l10n.altThisEvening,
      DraftAlternative.tomorrowMorningCode => l10n.altTomorrowMorning,
      DraftAlternative.nextWeekCode => l10n.altNextWeek,
      _ => label,
    };
  }
}
