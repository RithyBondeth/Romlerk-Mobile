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

  Future<String?> take() async {
    try {
      return await _channel.invokeMethod<String>('take');
    } on MissingPluginException {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      await _channel.invokeMethod<void>('clear');
    } on MissingPluginException {
      /* No native inbox on this platform. */
    }
  }

  void dispose() => _channel.setMethodCallHandler(null);
}
