import 'package:flutter_test/flutter_test.dart';
import 'package:romlerk_mobile/domain/drafts/task_draft.dart';
import 'package:romlerk_mobile/local_ai/capabilities.dart';
import 'package:romlerk_mobile/local_ai/capability_router.dart';
import 'package:romlerk_mobile/local_ai/local_ai.dart';
import 'package:romlerk_mobile/local_ai/local_ai_error.dart';

/// A generative provider whose behaviour the test dictates.
class _FakeGenerative implements LocalAi {
  _FakeGenerative({required this.reported, this.onParse});

  LocalAiCapabilities reported;

  /// Runs in place of a real model. Throw to simulate a vendor failure.
  Future<TaskParseResult> Function(TaskParseRequest request)? onParse;

  int parseCalls = 0;
  int cancelCalls = 0;

  @override
  Future<LocalAiCapabilities> capabilities() async => reported;

  @override
  Future<TaskParseResult> parseTasks(TaskParseRequest request) async {
    parseCalls++;
    final handler = onParse;
    if (handler == null) {
      throw const LocalAiException(LocalAiErrorCode.modelUnavailable);
    }
    return handler(request);
  }

  @override
  Future<DurationSuggestion?> estimateDuration(
    String title, {
    String? notes,
  }) async => null;

  @override
  Future<void> cancel(String requestId) async => cancelCalls++;
}

void main() {
  final now = DateTime(2026, 8, 10, 14, 30);

  TaskParseRequest request({String text = 'Call David tomorrow at 9am'}) {
    return TaskParseRequest(
      requestId: 'req-1',
      text: text,
      referenceNow: now,
      timezone: 'Europe/Copenhagen',
      locale: 'en',
    );
  }

  const readyCapabilities = LocalAiCapabilities(
    provider: AiProvider.appleFoundationModels,
    availability: AiAvailability.available,
    features: <AiFeature>{AiFeature.structuredText},
  );

  group('tier selection', () {
    test('an available generative provider is tier A', () async {
      const capabilities = readyCapabilities;
      expect(capabilities.tier, CapabilityTier.fullLocalAi);
    });

    test('an eligible but not-ready provider is tier B', () async {
      const capabilities = LocalAiCapabilities(
        provider: AiProvider.mlKitGenAi,
        availability: AiAvailability.modelNotReady,
      );
      expect(capabilities.tier, CapabilityTier.eligibleNotReady);
    });

    test('no generative provider falls to tier C', () async {
      const capabilities = LocalAiCapabilities.deterministicOnly();
      expect(capabilities.tier, CapabilityTier.baselineParsing);
    });
  });

  group('routing', () {
    test('uses the generative path when it is ready', () async {
      final generative = _FakeGenerative(
        reported: readyCapabilities,
        onParse: (req) async => TaskParseResult(
          requestId: req.requestId,
          drafts: <TaskDraft>[
            const TaskDraft(id: 'd1', title: 'From the model'),
          ],
          provider: AiProvider.appleFoundationModels,
          tier: CapabilityTier.fullLocalAi,
          latency: const Duration(milliseconds: 400),
        ),
      );
      final router = CapabilityRouter(generative: generative);

      final result = await router.parseTasks(request());

      expect(result.drafts.single.title, 'From the model');
      expect(result.wasDegraded, isFalse);
      expect(generative.parseCalls, 1);
    });

    test('falls back to rules without calling an unavailable model', () async {
      final generative = _FakeGenerative(
        reported: const LocalAiCapabilities.deterministicOnly(),
      );
      final router = CapabilityRouter(generative: generative);

      final result = await router.parseTasks(request());

      expect(generative.parseCalls, 0);
      expect(result.provider, AiProvider.deterministic);
      expect(result.degradedFrom, LocalAiErrorCode.modelUnavailable.wire);
      // Crucially, the user still gets a usable draft.
      expect(result.drafts.single.title, 'Call David');
      expect(result.drafts.single.dueAt, DateTime(2026, 8, 11, 9));
    });

    test('a generative failure degrades instead of surfacing an error',
        () async {
      final generative = _FakeGenerative(
        reported: readyCapabilities,
        onParse: (_) async =>
            throw const LocalAiException(LocalAiErrorCode.busyOrQuota),
      );
      final router = CapabilityRouter(generative: generative);

      final result = await router.parseTasks(request());

      expect(result.degradedFrom, LocalAiErrorCode.busyOrQuota.wire);
      expect(result.drafts, isNotEmpty);
    });

    test('an empty generative result also degrades to rules', () async {
      final generative = _FakeGenerative(
        reported: readyCapabilities,
        onParse: (req) async => TaskParseResult(
          requestId: req.requestId,
          drafts: const <TaskDraft>[],
          provider: AiProvider.appleFoundationModels,
          tier: CapabilityTier.fullLocalAi,
          latency: Duration.zero,
        ),
      );
      final router = CapabilityRouter(generative: generative);

      final result = await router.parseTasks(request());
      expect(result.drafts, isNotEmpty);
      expect(result.degradedFrom, LocalAiErrorCode.outputInvalid.wire);
    });

    test('never runs a foreground-only model in the background', () async {
      final generative = _FakeGenerative(
        reported: const LocalAiCapabilities(
          provider: AiProvider.mlKitGenAi,
          availability: AiAvailability.available,
          features: <AiFeature>{AiFeature.structuredText},
          constraints: AiConstraints(foregroundOnly: true),
        ),
      );
      final router = CapabilityRouter(
        generative: generative,
        isForeground: false,
      );

      final result = await router.parseTasks(request());

      expect(generative.parseCalls, 0);
      expect(result.degradedFrom, LocalAiErrorCode.backgroundBlocked.wire);
    });

    test('routes an unsupported language to rules', () async {
      final generative = _FakeGenerative(
        reported: const LocalAiCapabilities(
          provider: AiProvider.appleFoundationModels,
          availability: AiAvailability.available,
          features: <AiFeature>{AiFeature.structuredText},
          languages: <String>{'ja'},
        ),
      );
      final router = CapabilityRouter(generative: generative);

      final result = await router.parseTasks(request());

      expect(generative.parseCalls, 0);
      expect(result.degradedFrom, LocalAiErrorCode.unsupportedLanguage.wire);
    });
  });

  group('audit', () {
    test('records outcome shape and no user content', () async {
      final entries = <Map<String, Object?>>[];
      final router = CapabilityRouter(
        generative: _FakeGenerative(
          reported: const LocalAiCapabilities.deterministicOnly(),
        ),
        auditSink:
            ({
              required schemaVersion,
              required provider,
              required tier,
              required latencyBucket,
              required outcome,
              required draftCount,
              errorCode,
            }) async {
              entries.add(<String, Object?>{
                'provider': provider.wire,
                'tier': tier.code,
                'latency': latencyBucket.label,
                'outcome': outcome,
                'draftCount': draftCount,
                'errorCode': errorCode,
              });
            },
      );

      await router.parseTasks(request(text: 'Pay the dentist bill tomorrow'));

      final entry = entries.single;
      expect(entry['outcome'], 'degraded');
      expect(entry['draftCount'], 1);
      // The recorded fields cannot contain task text by construction.
      expect(entry.values.join(' '), isNot(contains('dentist')));
    });
  });
}
