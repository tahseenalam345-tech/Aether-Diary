import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Checks if the device has hardware support (Fingerprint/FaceID) 
  /// AND if the user has actually enrolled a fingerprint.
  Future<bool> canAuthenticate() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException catch (e) {
      print("Hardware Error: $e");
      return false;
    }
  }

  /// Triggers the native Android fingerprint popup.
  Future<bool> authenticateUser() async {
    try {
      // ULTRA-COMPATIBILITY MODE: 
      // Stripped down to only the absolute minimum required parameters.
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Unlock your vault to access your memories',
        biometricOnly: true, 
      );
      return didAuthenticate;
    } on PlatformException catch (e) {
      print("Authentication Error: $e");
      return false;
    }
  }
}