import 'dart:async';

import 'package:flutter/services.dart';

import 'voice_capture_service.dart';

/// [VoiceCaptureService] over the `dev.romlerk/voice` channel.
///
/// Both native adapters use on-device recognition only (iOS
/// `requiresOnDeviceRecognition`, Android's on-device recognizer) and report
/// `unsupported` rather than falling back to a server. See
/// `docs/native_voice_contract.md`.
class PlatformVoiceCaptureService implements VoiceCaptureService {
  PlatformVoiceCaptureService({
    required this.locale,
    MethodChannel? channel,
    this.silenceTimeout = const Duration(milliseconds: 2500),
    this.maxDuration = const Duration(seconds: 60),
  }) : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_onNativeCall);
  }

  static const String channelName = 'dev.romlerk/voice';

  /// BCP-47 tag of the language to recognise, e.g. `en-US` or `km-KH`.
  final String locale;

  /// Android's recognizer ends on silence by itself; iOS's on-device one
  /// keeps listening until told to stop, so both get the same pause rule.
  final Duration silenceTimeout;

  /// Hard cap, so a forgotten session never keeps the microphone open.
  final Duration maxDuration;

  final MethodChannel _channel;
  final StreamController<VoiceCaptureState> _states =
      StreamController<VoiceCaptureState>.broadcast();

  VoiceCaptureState _state = VoiceCaptureState.idle;
  Timer? _silenceTimer;
  Timer? _maxTimer;

  @override
  Stream<VoiceCaptureState> get stateStream => _states.stream;

  @override
  VoiceCaptureState get state => _state;

  @override
  Future<VoiceAvailability> availability() async {
    try {
      final raw = await _channel.invokeMethod<Object?>(
        'availability',
        <String, Object?>{'locale': locale},
      );
      final status = raw is Map ? raw['status'] : null;
      return VoiceAvailability.values.firstWhere(
        (value) => value.name == status,
        // Anything unrecognised is treated as unsupported: showing a
        // microphone that then fails is worse than showing none.
        orElse: () => VoiceAvailability.unsupported,
      );
    } on MissingPluginException {
      // Desktop, web, and tests: no native adapter, so no voice.
      return VoiceAvailability.unsupported;
    } on PlatformException {
      return VoiceAvailability.unsupported;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> start() async {
    if (_state.isActive) return;
    _emit(
      const VoiceCaptureState(status: VoiceCaptureStatus.listening),
    );
    try {
      await _channel.invokeMethod<void>(
        'start',
        <String, Object?>{'locale': locale},
      );
      _maxTimer = Timer(maxDuration, stop);
    } on PlatformException catch (error) {
      _end(VoiceErrorCode.fromWire(error.code));
    } on MissingPluginException {
      _end(VoiceErrorCode.unavailable);
    }
  }

  @override
  Future<void> stop() async {
    if (_state.status != VoiceCaptureStatus.listening) return;
    _cancelTimers();
    _emit(_state.copyWith(status: VoiceCaptureStatus.processing));
    try {
      await _channel.invokeMethod<void>('stop');
    } on PlatformException {
      _end(null);
    } on MissingPluginException {
      _end(null);
    }
  }

  @override
  Future<void> cancel() async {
    if (!_state.isActive) return;
    _cancelTimers();
    // Idle first, so any event the recognizer was already sending is ignored.
    _emit(VoiceCaptureState.idle);
    try {
      await _channel.invokeMethod<void>('cancel');
    } on PlatformException {
      // Nothing to recover: the session is already discarded on this side.
    } on MissingPluginException {
      // Same.
    }
  }

  @override
  void dispose() {
    if (_state.isActive) {
      unawaited(
        _channel.invokeMethod<void>('cancel').catchError((Object _) {}),
      );
    }
    _cancelTimers();
    _channel.setMethodCallHandler(null);
    _states.close();
  }

  Future<Object?> _onNativeCall(MethodCall call) async {
    // Events from a session that was already cancelled or finished.
    if (!_state.isActive) return null;
    final arguments = call.arguments is Map
        ? call.arguments as Map<Object?, Object?>
        : const <Object?, Object?>{};

    switch (call.method) {
      case 'onTranscript':
        final text = arguments['text'];
        if (text is! String) return null;
        _emit(_state.copyWith(transcript: text.trim()));
        if (_state.status == VoiceCaptureStatus.listening &&
            text.trim().isNotEmpty) {
          _silenceTimer?.cancel();
          _silenceTimer = Timer(silenceTimeout, stop);
        }
      case 'onEnded':
        final code = arguments['error'];
        _end(code is String ? VoiceErrorCode.fromWire(code) : null);
    }
    return null;
  }

  void _end(VoiceErrorCode? error) {
    _cancelTimers();
    // A transcript that arrived before an error is still the user's words,
    // so it is kept; the error only matters when there is nothing to show.
    if (error != null && _state.transcript.isEmpty) {
      _emit(
        VoiceCaptureState(status: VoiceCaptureStatus.error, error: error),
      );
    } else {
      _emit(
        VoiceCaptureState(
          status: VoiceCaptureStatus.idle,
          transcript: _state.transcript,
        ),
      );
    }
  }

  void _cancelTimers() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _maxTimer?.cancel();
    _maxTimer = null;
  }

  void _emit(VoiceCaptureState next) {
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }
}
