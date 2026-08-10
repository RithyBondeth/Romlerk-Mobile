import 'dart:async';

import 'capabilities.dart';
import 'deterministic/deterministic_parser.dart';
import 'local_ai.dart';
import 'local_ai_error.dart';

/// Records a content-free outcome for a parse attempt.
typedef ParseAuditSink =
    Future<void> Function({
      required int schemaVersion,
      required AiProvider provider,
      required CapabilityTier tier,
      required LatencyBucket latencyBucket,
      required String outcome,
      required int draftCount,
      String? errorCode,
    });

/// Chooses which parser runs, per request, from live runtime state.
///
/// This is where "capability, not device labels" is enforced. Every parse
/// re-checks availability, and a generative failure degrades to the
/// deterministic parser rather than surfacing an error — the user's input is
/// never lost and never has to be retyped.
class CapabilityRouter implements LocalAi {
  CapabilityRouter({
    required LocalAi generative,
    DeterministicTaskParser? deterministic,
    ParseAuditSink? auditSink,
    bool isForeground = true,
  }) : _generative = generative,
       _deterministic = deterministic ?? DeterministicTaskParser(),
       _auditSink = auditSink,
       _isForeground = isForeground;

  final LocalAi _generative;
  final DeterministicTaskParser _deterministic;
  final ParseAuditSink? _auditSink;

  /// Some providers (ML Kit GenAI) refuse to run in the background, and the
  /// BRD forbids background generative work outright.
  bool _isForeground;

  LocalAiCapabilities? _cached;

  set isForeground(bool value) => _isForeground = value;

  /// Last known capabilities without hitting the platform. Null before the
  /// first probe.
  LocalAiCapabilities? get lastKnownCapabilities => _cached;

  @override
  Future<LocalAiCapabilities> capabilities() async {
    final probed = await _generative.capabilities();
    _cached = probed;
    return probed;
  }

  /// Re-probes after a lifecycle change, since the model can become ready,
  /// be disabled, or finish downloading while the app is backgrounded.
  Future<LocalAiCapabilities> refresh() => capabilities();

  @override
  Future<TaskParseResult> parseTasks(TaskParseRequest request) async {
    final capabilities = _cached ?? await this.capabilities();

    final blockedReason = _generativeBlockedReason(capabilities, request);
    if (blockedReason != null) {
      return _runDeterministic(
        request,
        capabilities: capabilities,
        degradedFrom: blockedReason.wire,
      );
    }

    try {
      final result = await _generative.parseTasks(request);
      // An empty generative result is not a success — fall through to rules
      // rather than showing the user nothing.
      if (result.isEmpty) {
        return _runDeterministic(
          request,
          capabilities: capabilities,
          degradedFrom: LocalAiErrorCode.outputInvalid.wire,
        );
      }
      await _audit(
        provider: result.provider,
        tier: CapabilityTier.fullLocalAi,
        latencyBucket: result.latencyBucket,
        outcome: 'ok',
        draftCount: result.drafts.length,
      );
      return result;
    } on LocalAiException catch (error) {
      return _runDeterministic(
        request,
        capabilities: capabilities,
        degradedFrom: error.code.wire,
      );
    }
  }

  /// Why the generative path cannot run for this request, or null if it can.
  LocalAiErrorCode? _generativeBlockedReason(
    LocalAiCapabilities capabilities,
    TaskParseRequest request,
  ) {
    if (!capabilities.generativeReady) {
      return switch (capabilities.availability) {
        AiAvailability.disabled => LocalAiErrorCode.modelDisabled,
        AiAvailability.modelNotReady => LocalAiErrorCode.modelNotReady,
        AiAvailability.busy => LocalAiErrorCode.busyOrQuota,
        _ => LocalAiErrorCode.modelUnavailable,
      };
    }
    if (capabilities.constraints.foregroundOnly && !_isForeground) {
      return LocalAiErrorCode.backgroundBlocked;
    }
    if (!capabilities.supportsLanguage(request.locale)) {
      return LocalAiErrorCode.unsupportedLanguage;
    }
    if (request.text.length > capabilities.constraints.maxInputCharacters) {
      return LocalAiErrorCode.inputTooLong;
    }
    return null;
  }

  Future<TaskParseResult> _runDeterministic(
    TaskParseRequest request, {
    required LocalAiCapabilities capabilities,
    String? degradedFrom,
  }) async {
    final result = await _deterministic.parseTasks(request);
    await _audit(
      provider: AiProvider.deterministic,
      tier: capabilities.tier,
      latencyBucket: result.latencyBucket,
      outcome: degradedFrom == null ? 'ok' : 'degraded',
      draftCount: result.drafts.length,
      errorCode: degradedFrom,
    );
    return TaskParseResult(
      requestId: result.requestId,
      drafts: result.drafts,
      provider: AiProvider.deterministic,
      tier: capabilities.tier,
      latency: result.latency,
      degradedFrom: degradedFrom,
    );
  }

  @override
  Future<DurationSuggestion?> estimateDuration(
    String title, {
    String? notes,
  }) async {
    final capabilities = _cached ?? await this.capabilities();
    if (capabilities.generativeReady &&
        capabilities.features.contains(AiFeature.durationEstimate)) {
      final suggestion = await _generative.estimateDuration(
        title,
        notes: notes,
      );
      if (suggestion != null) return suggestion;
    }
    return _deterministic.estimateDuration(title, notes: notes);
  }

  @override
  Future<void> cancel(String requestId) async {
    await _generative.cancel(requestId);
    await _deterministic.cancel(requestId);
  }

  Future<void> _audit({
    required AiProvider provider,
    required CapabilityTier tier,
    required LatencyBucket latencyBucket,
    required String outcome,
    required int draftCount,
    String? errorCode,
  }) async {
    final sink = _auditSink;
    if (sink == null) return;
    // Never awaited on the critical path in a way that can fail capture.
    try {
      await sink(
        schemaVersion: TaskParseResult.currentSchemaVersion,
        provider: provider,
        tier: tier,
        latencyBucket: latencyBucket,
        outcome: outcome,
        draftCount: draftCount,
        errorCode: errorCode,
      );
    } on Object {
      // Diagnostics must never break capture.
    }
  }
}
