import 'dart:async';

/// Status of the voice capture listener (FR-16).
enum VoiceCaptureStatus {
  idle,
  listening,
  processing,
  unavailable,
  error,
}

class VoiceCaptureState {
  const VoiceCaptureState({
    required this.status,
    this.transcript = '',
    this.errorMessage,
  });

  final VoiceCaptureStatus status;
  final String transcript;
  final String? errorMessage;

  VoiceCaptureState copyWith({
    VoiceCaptureStatus? status,
    String? transcript,
    String? errorMessage,
  }) {
    return VoiceCaptureState(
      status: status ?? this.status,
      transcript: transcript ?? this.transcript,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Abstract contract for on-device voice transcription (Journey C / FR-16).
///
/// Follows NFR-15: Speech recognition is isolated behind a service facade so
/// the app can switch native engines or fallback to text capture safely.
abstract class VoiceCaptureService {
  Stream<VoiceCaptureState> get stateStream;

  Future<bool> initialize();

  Future<void> startListening({
    required void Function(String transcript) onResult,
  });

  Future<void> stopListening();

  Future<void> cancel();

  void dispose();
}
