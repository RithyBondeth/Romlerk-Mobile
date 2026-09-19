import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Result of asking the user to prove they own the device.
enum UnlockResult {
  unlocked,

  /// The user dismissed the prompt. Stay locked, offer to try again.
  cancelled,

  /// The device has no passcode, or the prompt cannot be shown at all.
  /// The lock must never become a way to lose access to one's own tasks, so
  /// callers treat this as "cannot lock" rather than "stay locked".
  unavailable,

  /// Too many attempts, or another transient failure.
  failed,
}

/// Face ID, fingerprint, or the device passcode, behind a facade (NFR-15).
abstract class DeviceAuthenticator {
  /// Whether the device has any lock (biometric or passcode) to check.
  Future<bool> isAvailable();

  Future<UnlockResult> authenticate(String reason);
}

class LocalDeviceAuthenticator implements DeviceAuthenticator {
  LocalDeviceAuthenticator({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<UnlockResult> authenticate(String reason) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        // The passcode is always accepted as a fallback, so a failed face or
        // finger read can never lock someone out of their own tasks.
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      return ok ? UnlockResult.unlocked : UnlockResult.cancelled;
    } on LocalAuthException catch (error) {
      return switch (error.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout => UnlockResult.cancelled,
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.uiUnavailable => UnlockResult.unavailable,
        _ => UnlockResult.failed,
      };
    } on PlatformException {
      return UnlockResult.failed;
    } on MissingPluginException {
      return UnlockResult.unavailable;
    }
  }
}
