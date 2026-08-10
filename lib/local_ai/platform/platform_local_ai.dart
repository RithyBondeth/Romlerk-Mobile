import 'dart:async';

import 'package:flutter/services.dart';

import '../../domain/drafts/task_draft.dart';
import '../capabilities.dart';
import '../local_ai.dart';
import '../local_ai_error.dart';
import 'draft_codec.dart';

/// Dart side of the native bridge to Apple Foundation Models (iOS) and
/// ML Kit GenAI / Gemini Nano via AICore (Android).
///
/// The native adapters are a separate workstream; until they ship, every call
/// here surfaces a typed [LocalAiException] and the capability router falls
/// back to the deterministic parser. That is the intended tier-B/C behaviour,
/// not a stub failure — the app is fully usable without this class.
class PlatformLocalAi implements LocalAi {
  PlatformLocalAi({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'dev.romlerk/local_ai';

  final MethodChannel _channel;

  /// Beyond this a parse is abandoned so capture never appears to hang.
  static const Duration parseTimeout = Duration(seconds: 12);

  @override
  Future<LocalAiCapabilities> capabilities() async {
    try {
      final response = await _channel.invokeMapMethod<Object?, Object?>(
        'capabilities',
      );
      if (response == null) {
        return const LocalAiCapabilities.deterministicOnly(
          reason: 'NO_NATIVE_RESPONSE',
        );
      }
      return LocalAiCapabilities.fromMap(response);
    } on MissingPluginException {
      // No native adapter registered on this build. Expected during the
      // Flutter-only phase.
      return const LocalAiCapabilities.deterministicOnly(
        reason: 'NO_NATIVE_ADAPTER',
      );
    } on PlatformException catch (error) {
      return LocalAiCapabilities.deterministicOnly(reason: error.code);
    }
  }

  @override
  Future<TaskParseResult> parseTasks(TaskParseRequest request) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _channel
          .invokeMapMethod<Object?, Object?>('parseTasks', <String, Object?>{
            'requestId': request.requestId,
            'text': request.text,
            'referenceNow': request.referenceNow.toIso8601String(),
            'timezone': request.timezone,
            'locale': request.locale,
            'knownTags': request.knownTags,
            'allowMultipleTasks': request.allowMultipleTasks,
            'schemaVersion': TaskParseResult.currentSchemaVersion,
          })
          .timeout(parseTimeout);

      stopwatch.stop();

      if (response == null) {
        throw LocalAiException(
          LocalAiErrorCode.outputInvalid,
          details: 'null response',
          retainedInput: request.text,
        );
      }

      // Model output is untrusted: it is decoded and validated here, and any
      // structural problem discards the whole result rather than saving part
      // of it (BRD section 13).
      final drafts = const DraftCodec().decodeDrafts(
        response,
        request: request,
      );

      return TaskParseResult(
        requestId: request.requestId,
        drafts: drafts,
        provider: AiProvider.fromWire(response['provider'] as String?),
        tier: CapabilityTier.fullLocalAi,
        latency: stopwatch.elapsed,
      );
    } on TimeoutException {
      unawaited(cancel(request.requestId));
      throw LocalAiException(
        LocalAiErrorCode.parseTimeout,
        retainedInput: request.text,
      );
    } on MissingPluginException {
      throw LocalAiException(
        LocalAiErrorCode.modelUnavailable,
        details: 'no native adapter',
        retainedInput: request.text,
      );
    } on PlatformException catch (error) {
      throw LocalAiException(
        LocalAiErrorCode.fromWire(error.code),
        details: error.code,
        retainedInput: request.text,
      );
    } on FormatException catch (error) {
      throw LocalAiException(
        LocalAiErrorCode.outputInvalid,
        details: error.message,
        retainedInput: request.text,
      );
    }
  }

  @override
  Future<DurationSuggestion?> estimateDuration(
    String title, {
    String? notes,
  }) async {
    try {
      final response = await _channel
          .invokeMapMethod<Object?, Object?>('estimateDuration', <String, Object?>{
            'title': title,
            'notes': notes,
          })
          .timeout(parseTimeout);
      final minutes = (response?['minutes'] as num?)?.toInt();
      if (minutes == null || minutes <= 0 || minutes > 60 * 24) return null;
      // Anything the model produces is an estimate by definition (FR-17).
      return DurationSuggestion(minutes: minutes, isEstimate: true);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> cancel(String requestId) async {
    try {
      await _channel.invokeMethod<void>('cancel', <String, Object?>{
        'requestId': requestId,
      });
    } on Object {
      // Cancellation is best-effort; a failure here must never surface.
    }
  }
}

/// Drafts produced by a native adapter, kept separate from [PlatformLocalAi]
/// so decoding can be unit-tested against captured payloads.
typedef NativeDraftList = List<TaskDraft>;
