import 'dart:async';

/// Status of the voice capture listener (FR-16).
enum VoiceCaptureStatus {
  idle,
  listening,

  /// Recording has stopped and the recognizer is producing its final
  /// transcript.
  processing,
  unavailable,
  error,
}

/// Whether voice capture can run right now, checked without prompting.
///
/// Only [available] and the two permission states show a microphone at all:
/// the BRD allows "offline voice" to be offered only where the device proves
/// it can recognise speech on-device, so every other state keeps text capture
/// as the path rather than presenting a button that cannot work.
enum VoiceAvailability {
  available,

  /// Supported, but the user has not been asked yet. Asking happens when
  /// they tap the microphone, never before.
  permissionNeeded,

  /// The user declined. Only the OS settings can change that.
  permissionDenied,

  /// No on-device recognizer. Audio would have to leave the phone, which the
  /// MVP never allows.
  unsupported,

  /// On-device recognition exists, but not for this language.
  languageUnsupported;

  bool get canOffer => this != unsupported && this != languageUnsupported;
}

/// Why a listening session ended without a usable transcript.
///
/// The user-facing wording lives in `core/format/messages.dart`, in the UI
/// language, and deliberately never blames the user.
enum VoiceErrorCode {
  noSpeech('NO_SPEECH'),
  permissionDenied('PERMISSION_DENIED'),
  languageUnsupported('LANGUAGE_UNSUPPORTED'),
  busy('BUSY'),
  unavailable('UNAVAILABLE'),
  failed('RECOGNITION_FAILED');

  const VoiceErrorCode(this.wire);

  final String wire;

  static VoiceErrorCode fromWire(String? wire) => values.firstWhere(
    (code) => code.wire == wire,
    orElse: () => VoiceErrorCode.failed,
  );
}

class VoiceCaptureState {
  const VoiceCaptureState({
    required this.status,
    this.transcript = '',
    this.error,
  });

  static const VoiceCaptureState idle = VoiceCaptureState(
    status: VoiceCaptureStatus.idle,
  );

  final VoiceCaptureStatus status;

  /// Best transcript so far; replaced, not appended, as recognition refines.
  final String transcript;
  final VoiceErrorCode? error;

  bool get isActive =>
      status == VoiceCaptureStatus.listening ||
      status == VoiceCaptureStatus.processing;

  VoiceCaptureState copyWith({
    VoiceCaptureStatus? status,
    String? transcript,
    VoiceErrorCode? error,
    bool clearError = false,
  }) {
    return VoiceCaptureState(
      status: status ?? this.status,
      transcript: transcript ?? this.transcript,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// On-device voice transcription (Journey C / FR-16).
///
/// Follows NFR-15: speech recognition sits behind this facade so the app can
/// switch native engines, and NFR-07: implementations must never send audio
/// off the device.
abstract class VoiceCaptureService {
  Stream<VoiceCaptureState> get stateStream;

  VoiceCaptureState get state;

  /// Checks support and permission without showing any prompt.
  Future<VoiceAvailability> availability();

  /// Shows the OS microphone/speech prompts. Call only after the user has
  /// asked for voice. Returns whether both were granted.
  Future<bool> requestPermission();

  /// Starts listening. Transcript updates arrive on [stateStream].
  Future<void> start();

  /// Stops recording and lets the recognizer finish the transcript.
  Future<void> stop();

  /// Stops and discards the session.
  Future<void> cancel();

  void dispose();
}
