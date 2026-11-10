import 'package:flutter/services.dart';

/// Native entry points only enqueue text. Parsing and saving still happen in
/// the foreground capture sheet, behind onboarding and the app lock.
class SystemCaptureService {
  SystemCaptureService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('dev.romlerk/capture');
  final MethodChannel _channel;
  void listen(Future<void> Function() available) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'available') await available();
    });
  }

  Future<NativeCaptureRequest?> peek() async {
    try {
      final value = await _channel.invokeMapMethod<String, dynamic>('peek');
      return value == null
          ? null
          : NativeCaptureRequest(
              value['id'] as String,
              value['text'] as String,
            );
    } on MissingPluginException {
      return null;
    }
  }

  Future<void> acknowledge(String id) =>
      _channel.invokeMethod<void>('acknowledge', id);

  Future<void> clear() async {
    try {
      await _channel.invokeMethod<void>('clear');
    } on MissingPluginException {
      /* No native inbox on this platform. */
    }
  }

  void dispose() => _channel.setMethodCallHandler(null);
}

class NativeCaptureRequest {
  const NativeCaptureRequest(this.id, this.text);
  final String id;
  final String text;
}
