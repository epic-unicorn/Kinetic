import 'package:local_auth/local_auth.dart';

/// Device lock (biometrics or PIN) before showing a recovery phrase.
class VaultBiometrics {
  VaultBiometrics._();

  static final LocalAuthentication _auth = LocalAuthentication();

  /// `true` if the OS lock succeeded, `false` if the user cancelled or it
  /// failed, `null` if this device has no lock to prompt.
  static Future<bool?> authenticate({required String reason}) async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return null;
      return _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (_) {
      return null;
    }
  }
}
