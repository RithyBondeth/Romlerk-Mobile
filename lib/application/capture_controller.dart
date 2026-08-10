import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../domain/drafts/task_draft.dart';
import '../local_ai/capabilities.dart';
import '../local_ai/local_ai.dart';
import '../local_ai/local_ai_error.dart';
import 'providers.dart';

enum CaptureStage {
  /// Waiting for input.
  idle,

  /// A parse is running. The input stays editable.
  parsing,

  /// Drafts are ready for review.
  reviewing,

  /// The parse failed. [CaptureState.input] still holds the original text.
  failed,
}

@immutable
class CaptureState {
  const CaptureState({
    this.stage = CaptureStage.idle,
    this.input = '',
    this.drafts = const <TaskDraft>[],
    this.error,
    this.degradedFrom,
    this.provider = AiProvider.deterministic,
    this.requestId,
  });

  final CaptureStage stage;

  /// Always the user's original text. Never cleared on failure — the BRD is
  /// explicit that the user must not have to retype.
  final String input;

  final List<TaskDraft> drafts;
  final LocalAiErrorCode? error;

  /// Set when the generative path was unavailable and rules ran instead, so
  /// the UI can say so once rather than presenting an error.
  final String? degradedFrom;

  final AiProvider provider;
  final String? requestId;

  bool get isParsing => stage == CaptureStage.parsing;
  bool get canSubmit => input.trim().isNotEmpty && !isParsing;

  /// Every draft must be free of ambiguity before a bulk save is allowed.
  bool get allDraftsResolved =>
      drafts.isNotEmpty && drafts.every((draft) => !draft.hasAmbiguities);

  CaptureState copyWith({
    CaptureStage? stage,
    String? input,
    List<TaskDraft>? drafts,
    LocalAiErrorCode? error,
    String? degradedFrom,
    AiProvider? provider,
    String? requestId,
    bool clearError = false,
    bool clearDegraded = false,
  }) {
    return CaptureState(
      stage: stage ?? this.stage,
      input: input ?? this.input,
      drafts: drafts ?? this.drafts,
      error: clearError ? null : (error ?? this.error),
      degradedFrom: clearDegraded ? null : (degradedFrom ?? this.degradedFrom),
      provider: provider ?? this.provider,
      requestId: requestId ?? this.requestId,
    );
  }
}

/// Owns the capture input lifecycle: text, parse, cancellation, and draft
/// state. Deliberately owns no vendor types and performs no database writes —
/// committing a draft is [TaskService]'s job.
class CaptureController extends StateNotifier<CaptureState> {
  CaptureController(this._ref, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid(),
      super(const CaptureState());

  final Ref _ref;
  final Uuid _uuid;

  void updateInput(String value) {
    state = state.copyWith(
      input: value,
      stage: state.stage == CaptureStage.failed
          ? CaptureStage.idle
          : state.stage,
      clearError: true,
    );
  }

  Future<void> parse() async {
    final text = state.input.trim();
    if (text.isEmpty || state.isParsing) return;

    final requestId = _uuid.v4();
    state = state.copyWith(
      stage: CaptureStage.parsing,
      requestId: requestId,
      clearError: true,
      clearDegraded: true,
    );

    final localAi = _ref.read(localAiProvider);
    final now = _ref.read(clockProvider)();
    final scheduler = _ref.read(reminderSchedulerProvider);
    final knownTags = await _ref
        .read(taskRepositoryProvider)
        .fetchTags();

    try {
      final result = await localAi.parseTasks(
        TaskParseRequest(
          requestId: requestId,
          text: text,
          referenceNow: now,
          timezone: scheduler.localTimezone,
          locale: _ref.read(localeProvider),
          knownTags: knownTags.map((tag) => tag.name).toList(),
        ),
      );

      // A newer request started while this one was in flight.
      if (!mounted || state.requestId != requestId) return;

      if (result.drafts.isEmpty) {
        // Nothing structured could be found, but the text is still a perfectly
        // good task title — offer it rather than an error.
        state = state.copyWith(
          stage: CaptureStage.reviewing,
          drafts: <TaskDraft>[TaskDraft(id: _uuid.v4(), title: text)],
          provider: result.provider,
          degradedFrom: result.degradedFrom,
        );
        return;
      }

      state = state.copyWith(
        stage: CaptureStage.reviewing,
        drafts: result.drafts,
        provider: result.provider,
        degradedFrom: result.degradedFrom,
      );
    } on LocalAiException catch (error) {
      if (!mounted || state.requestId != requestId) return;
      state = state.copyWith(
        stage: CaptureStage.failed,
        error: error.code,
        // Input is preserved by not touching it.
      );
    }
  }

  Future<void> cancel() async {
    final requestId = state.requestId;
    if (requestId != null) {
      await _ref.read(localAiProvider).cancel(requestId);
    }
    if (!mounted) return;
    // No partial tasks: cancelling drops the drafts, keeps the text.
    state = state.copyWith(
      stage: CaptureStage.idle,
      drafts: const <TaskDraft>[],
      clearError: true,
    );
  }

  /// Replaces one draft after the user edits it in review.
  void replaceDraft(TaskDraft draft) {
    state = state.copyWith(
      drafts: <TaskDraft>[
        for (final existing in state.drafts)
          if (existing.id == draft.id) draft else existing,
      ],
    );
  }

  /// Removing one draft must not disturb the others (US-02).
  void removeDraft(String draftId) {
    final remaining = state.drafts
        .where((draft) => draft.id != draftId)
        .toList();
    state = state.copyWith(
      drafts: remaining,
      stage: remaining.isEmpty ? CaptureStage.idle : state.stage,
    );
  }

  void reset() => state = const CaptureState();
}

/// Device locale as a BCP-47 tag, injected so parsing is testable.
final localeProvider = Provider<String>((ref) => 'en');

final captureControllerProvider =
    StateNotifierProvider.autoDispose<CaptureController, CaptureState>(
      CaptureController.new,
    );
