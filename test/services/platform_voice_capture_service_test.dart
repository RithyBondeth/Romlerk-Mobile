import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romlerk_mobile/services/voice/platform_voice_capture_service.dart';
import 'package:romlerk_mobile/services/voice/voice_capture_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(PlatformVoiceCaptureService.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> calls;
  late PlatformVoiceCaptureService service;

  void answer(Object? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return handler(call);
    });
  }

  /// Simulates the native side calling into Dart.
  Future<void> nativeSends(String method, [Map<String, Object?>? args]) {
    final completer = messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
      (_) {},
    );
    return completer;
  }

  setUp(() {
    calls = <MethodCall>[];
    answer((_) => null);
    service = PlatformVoiceCaptureService(
      locale: 'en-US',
      silenceTimeout: const Duration(milliseconds: 40),
    );
  });

  tearDown(() {
    service.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });

  group('availability', () {
    test('reads the native status and passes the locale', () async {
      answer((_) => <String, Object?>{'status': 'permissionNeeded'});
      expect(await service.availability(), VoiceAvailability.permissionNeeded);
      expect(calls.single.arguments, <String, Object?>{'locale': 'en-US'});
    });

    test('an unknown status hides voice rather than risking it', () async {
      answer((_) => <String, Object?>{'status': 'somethingNew'});
      expect(await service.availability(), VoiceAvailability.unsupported);
    });

    test('no native adapter means unsupported, not an error', () async {
      messenger.setMockMethodCallHandler(channel, null);
      expect(await service.availability(), VoiceAvailability.unsupported);
    });

    test('only the unsupported states hide the microphone', () {
      expect(VoiceAvailability.available.canOffer, isTrue);
      expect(VoiceAvailability.permissionNeeded.canOffer, isTrue);
      expect(VoiceAvailability.permissionDenied.canOffer, isTrue);
      expect(VoiceAvailability.unsupported.canOffer, isFalse);
      expect(VoiceAvailability.languageUnsupported.canOffer, isFalse);
    });
  });

  group('session', () {
    test('partial transcripts replace each other, then the session ends',
        () async {
      await service.start();
      expect(service.state.status, VoiceCaptureStatus.listening);

      await nativeSends('onTranscript', <String, Object?>{
        'text': 'Call David',
        'isFinal': false,
      });
      await nativeSends('onTranscript', <String, Object?>{
        'text': 'Call David tomorrow at 9',
        'isFinal': true,
      });
      expect(service.state.transcript, 'Call David tomorrow at 9');

      await nativeSends('onEnded', <String, Object?>{});
      expect(service.state.status, VoiceCaptureStatus.idle);
      expect(service.state.transcript, 'Call David tomorrow at 9');
    });

    test('a pause after speech stops recording', () async {
      await service.start();
      await nativeSends('onTranscript', <String, Object?>{
        'text': 'Buy milk',
        'isFinal': false,
      });
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(calls.map((call) => call.method), contains('stop'));
      expect(service.state.status, VoiceCaptureStatus.processing);
    });

    test('an error with no words is reported', () async {
      await service.start();
      await nativeSends('onEnded', <String, Object?>{'error': 'NO_SPEECH'});
      expect(service.state.status, VoiceCaptureStatus.error);
      expect(service.state.error, VoiceErrorCode.noSpeech);
    });

    test('an error after words keeps the words', () async {
      await service.start();
      await nativeSends('onTranscript', <String, Object?>{
        'text': 'Pay rent',
        'isFinal': false,
      });
      await nativeSends('onEnded', <String, Object?>{
        'error': 'RECOGNITION_FAILED',
      });
      expect(service.state.status, VoiceCaptureStatus.idle);
      expect(service.state.transcript, 'Pay rent');
    });

    test('a start the platform refuses becomes an error state', () async {
      answer((call) {
        if (call.method == 'start') {
          throw PlatformException(code: 'LANGUAGE_UNSUPPORTED');
        }
        return null;
      });
      await service.start();
      expect(service.state.status, VoiceCaptureStatus.error);
      expect(service.state.error, VoiceErrorCode.languageUnsupported);
    });

    test('after cancel, late native events are ignored', () async {
      await service.start();
      await service.cancel();
      expect(calls.map((call) => call.method), contains('cancel'));

      await nativeSends('onTranscript', <String, Object?>{
        'text': 'should not appear',
        'isFinal': false,
      });
      expect(service.state.status, VoiceCaptureStatus.idle);
      expect(service.state.transcript, isEmpty);
    });
  });
}
