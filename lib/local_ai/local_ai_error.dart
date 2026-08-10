/// Stable error taxonomy from BRD section 16.
///
/// Native adapters translate vendor errors into these codes, so the Dart side
/// never branches on a platform-specific message. Every code carries the
/// user-facing behaviour the BRD specifies for it.
enum LocalAiErrorCode {
  modelUnavailable(
    'MODEL_UNAVAILABLE',
    'Enhanced understanding is not supported on this device.',
    retryable: false,
  ),
  modelDisabled(
    'MODEL_DISABLED',
    'On-device AI is turned off in system settings.',
    retryable: true,
    offersSettings: true,
  ),
  modelNotReady(
    'MODEL_NOT_READY',
    'The on-device model is still getting ready.',
    retryable: true,
  ),
  busyOrQuota(
    'BUSY_OR_QUOTA',
    'The on-device model is busy right now.',
    retryable: true,
  ),
  backgroundBlocked(
    'BACKGROUND_BLOCKED',
    'On-device AI only runs while the app is open.',
    retryable: true,
  ),
  unsupportedLanguage(
    'UNSUPPORTED_LANGUAGE',
    'This language is not supported for enhanced understanding.',
    retryable: false,
  ),
  outputInvalid(
    'OUTPUT_INVALID',
    "The result could not be read, so it wasn't used.",
    retryable: true,
  ),
  parseTimeout('PARSE_TIMEOUT', 'That took too long.', retryable: true),
  cancelled('CANCELLED', 'Cancelled.', retryable: true),
  inputTooLong(
    'INPUT_TOO_LONG',
    'That is longer than the model can read at once.',
    retryable: false,
  ),
  unknown('UNKNOWN', 'Something went wrong.', retryable: true);

  const LocalAiErrorCode(
    this.wire,
    this.message, {
    required this.retryable,
    this.offersSettings = false,
  });

  final String wire;

  /// Short, non-blaming explanation shown to the user.
  final String message;

  /// Whether a user-initiated retry is worth offering. Never used to drive an
  /// automatic retry loop (NFR-13).
  final bool retryable;

  /// Whether an "Open settings" action is meaningful for this code.
  final bool offersSettings;

  static LocalAiErrorCode fromWire(String? value) =>
      LocalAiErrorCode.values.firstWhere(
        (code) => code.wire == value,
        orElse: () => LocalAiErrorCode.unknown,
      );
}

/// A parse failure that the capture UI knows how to present.
///
/// Carrying the original input means the user never has to retype after a
/// failure, which the BRD calls out repeatedly.
class LocalAiException implements Exception {
  const LocalAiException(this.code, {this.details, this.retainedInput});

  final LocalAiErrorCode code;

  /// Technical detail for local diagnostics. Never contains user task text.
  final String? details;

  /// The input that was being parsed, so the UI can restore it.
  final String? retainedInput;

  String get message => code.message;

  @override
  String toString() => 'LocalAiException(${code.wire})';
}
