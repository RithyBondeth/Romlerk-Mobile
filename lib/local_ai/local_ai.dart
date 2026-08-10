import '../domain/drafts/task_draft.dart';
import 'capabilities.dart';

/// Everything a parse needs in order to be reproducible.
///
/// [referenceNow] and [timezone] are supplied by the app rather than read
/// inside the parser, so the same input always resolves to the same output in
/// tests and so relative dates are anchored explicitly (FR-06).
class TaskParseRequest {
  const TaskParseRequest({
    required this.requestId,
    required this.text,
    required this.referenceNow,
    required this.timezone,
    required this.locale,
    this.knownTags = const <String>[],
    this.allowMultipleTasks = true,
  });

  final String requestId;
  final String text;
  final DateTime referenceNow;

  /// IANA timezone name of the device at request time.
  final String timezone;

  /// BCP-47 locale tag.
  final String locale;

  /// Existing tag names, so extraction can prefer matching them over inventing
  /// near-duplicates.
  final List<String> knownTags;

  final bool allowMultipleTasks;
}

/// Coarse latency buckets. The audit log never stores an exact duration,
/// because exact timings combined with a timestamp are a fingerprint.
enum LatencyBucket {
  underOneSecond('<1s'),
  oneToThree('1-3s'),
  threeToSeven('3-7s'),
  overSeven('>7s');

  const LatencyBucket(this.label);

  final String label;

  static LatencyBucket of(Duration duration) {
    final ms = duration.inMilliseconds;
    if (ms < 1000) return LatencyBucket.underOneSecond;
    if (ms < 3000) return LatencyBucket.oneToThree;
    if (ms < 7000) return LatencyBucket.threeToSeven;
    return LatencyBucket.overSeven;
  }
}

class TaskParseResult {
  const TaskParseResult({
    required this.requestId,
    required this.drafts,
    required this.provider,
    required this.tier,
    required this.latency,
    this.schemaVersion = currentSchemaVersion,
    this.degradedFrom,
  });

  /// Incremented only alongside a backward-compatibility plan (FR-28).
  static const int currentSchemaVersion = 1;

  final String requestId;
  final List<TaskDraft> drafts;
  final AiProvider provider;
  final CapabilityTier tier;
  final Duration latency;
  final int schemaVersion;

  /// Set when a generative attempt failed and the deterministic parser
  /// produced this result instead. The UI uses it to explain the downgrade
  /// once, without framing the device as broken.
  final String? degradedFrom;

  bool get isEmpty => drafts.isEmpty;
  bool get wasDegraded => degradedFrom != null;
  LatencyBucket get latencyBucket => LatencyBucket.of(latency);
}

class DurationSuggestion {
  const DurationSuggestion({required this.minutes, required this.isEstimate});

  final int minutes;
  final bool isEstimate;
}

/// The single contract the rest of the app depends on (NFR-15).
///
/// Implementations: the deterministic rules parser, a platform bridge to
/// Apple Foundation Models / ML Kit GenAI, and the router that picks between
/// them at runtime.
abstract interface class LocalAi {
  /// Current runtime state. Re-queried on resume, never cached across the
  /// app lifecycle.
  Future<LocalAiCapabilities> capabilities();

  /// Turns free text into reviewable drafts. Throws [LocalAiException] on
  /// failure; never returns partially valid output.
  Future<TaskParseResult> parseTasks(TaskParseRequest request);

  /// Optional, labelled-as-estimate duration suggestion (FR-17).
  Future<DurationSuggestion?> estimateDuration(String title, {String? notes});

  /// Cancels an in-flight request. Must be safe to call for an unknown id.
  Future<void> cancel(String requestId);
}
