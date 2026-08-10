/// Runtime capability model.
///
/// The BRD is emphatic that experience is chosen by *runtime state*, never by
/// device marketing names (NFR-12), and that `capabilities()` returns
/// feature-level state with reason codes rather than a boolean.
library;

enum AiProvider {
  appleFoundationModels('appleFoundationModels', 'Apple on-device model'),
  mlKitGenAi('mlKitGenAI', 'Android on-device model'),
  deterministic('deterministic', 'Built-in date parsing'),
  none('none', 'Manual entry');

  const AiProvider(this.wire, this.label);

  final String wire;
  final String label;

  static AiProvider fromWire(String? value) => AiProvider.values.firstWhere(
    (provider) => provider.wire == value,
    orElse: () => AiProvider.deterministic,
  );
}

enum AiAvailability {
  available('available'),
  notEligible('notEligible'),
  disabled('disabled'),
  modelNotReady('modelNotReady'),
  busy('busy'),
  unknown('unknown');

  const AiAvailability(this.wire);

  final String wire;

  /// True when the state is expected to resolve itself — worth offering a
  /// retry rather than presenting the device as unsupported.
  bool get isRecoverable =>
      this == disabled || this == modelNotReady || this == busy;

  static AiAvailability fromWire(String? value) =>
      AiAvailability.values.firstWhere(
        (availability) => availability.wire == value,
        orElse: () => AiAvailability.unknown,
      );
}

/// Individual capabilities a provider may or may not offer. Having a generative
/// model does not imply speech, and vice versa.
enum AiFeature {
  structuredText('structuredText'),
  speech('speech'),
  durationEstimate('durationEstimate'),
  planning('planning');

  const AiFeature(this.wire);

  final String wire;

  static AiFeature? fromWire(String value) {
    for (final feature in AiFeature.values) {
      if (feature.wire == value) return feature;
    }
    return null;
  }
}

/// Constraints that must shape product behaviour, e.g. ML Kit GenAI being
/// foreground-only on Android.
class AiConstraints {
  const AiConstraints({
    this.foregroundOnly = false,
    this.quotaPossible = false,
    this.maxInputCharacters = 1000,
  });

  final bool foregroundOnly;
  final bool quotaPossible;
  final int maxInputCharacters;

  static AiConstraints fromMap(Map<Object?, Object?> map) => AiConstraints(
    foregroundOnly: map['foregroundOnly'] == true,
    quotaPossible: map['quotaPossible'] == true,
    maxInputCharacters:
        (map['maxInputCharacters'] as num?)?.toInt() ?? 1000,
  );
}

/// The four experience tiers from BRD section 14.
enum CapabilityTier {
  /// Structured generation available and ready.
  fullLocalAi('A'),

  /// Eligible but disabled, downloading, initializing, or busy.
  eligibleNotReady('B'),

  /// No generative model, but deterministic parsing works.
  baselineParsing('C'),

  /// Manual core only.
  manualCore('D');

  const CapabilityTier(this.code);

  final String code;
}

class LocalAiCapabilities {
  const LocalAiCapabilities({
    required this.provider,
    required this.availability,
    this.features = const <AiFeature>{},
    this.baseModel,
    this.languages = const <String>{},
    this.constraints = const AiConstraints(),
    this.deterministicParserAvailable = true,
    this.reason,
  });

  /// The state used when the platform bridge is absent or throws: the app
  /// still works, just without generative understanding.
  const LocalAiCapabilities.deterministicOnly({String? reason})
    : this(
        provider: AiProvider.deterministic,
        availability: AiAvailability.notEligible,
        features: const <AiFeature>{AiFeature.structuredText},
        reason: reason,
      );

  final AiProvider provider;
  final AiAvailability availability;
  final Set<AiFeature> features;

  /// Vendor-reported model version where exposed. Diagnostics only — never a
  /// user identifier.
  final String? baseModel;

  /// Locales the runtime actually supports, as BCP-47 tags.
  final Set<String> languages;

  final AiConstraints constraints;

  /// Whether the built-in rules parser can run. Effectively always true; kept
  /// explicit so tier D is representable.
  final bool deterministicParserAvailable;

  /// Machine-readable reason code from the error taxonomy, when the provider
  /// is not available.
  final String? reason;

  bool get generativeReady =>
      availability == AiAvailability.available &&
      features.contains(AiFeature.structuredText);

  CapabilityTier get tier {
    if (generativeReady) return CapabilityTier.fullLocalAi;
    if (provider != AiProvider.deterministic &&
        provider != AiProvider.none &&
        availability.isRecoverable) {
      return CapabilityTier.eligibleNotReady;
    }
    if (deterministicParserAvailable) return CapabilityTier.baselineParsing;
    return CapabilityTier.manualCore;
  }

  bool supportsLanguage(String languageTag) {
    if (languages.isEmpty) return true;
    final normalized = languageTag.toLowerCase();
    return languages.any(
      (tag) =>
          normalized == tag.toLowerCase() ||
          normalized.split('-').first == tag.toLowerCase().split('-').first,
    );
  }

  static LocalAiCapabilities fromMap(Map<Object?, Object?> map) {
    final rawFeatures = (map['features'] as List<Object?>? ?? const <Object?>[])
        .map((value) => AiFeature.fromWire(value.toString()))
        .whereType<AiFeature>()
        .toSet();
    return LocalAiCapabilities(
      provider: AiProvider.fromWire(map['provider'] as String?),
      availability: AiAvailability.fromWire(map['availability'] as String?),
      features: rawFeatures,
      baseModel: map['baseModel'] as String?,
      languages: (map['languages'] as List<Object?>? ?? const <Object?>[])
          .map((value) => value.toString())
          .toSet(),
      constraints: AiConstraints.fromMap(
        (map['constraints'] as Map<Object?, Object?>?) ??
            const <Object?, Object?>{},
      ),
      reason: map['reason'] as String?,
    );
  }
}
