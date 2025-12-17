import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:carelink_mobile/utils/fcm.dart';

enum SecureAuthStatus {
  success,
  noBiometric,
  biometricFailed,
  noStoredCredentials,
  signInFailed,
  pluginMissing,
  platformError,
  unknownError,
}

class SecureAuthResult {
  final SecureAuthStatus status;
  final UserCredential? userCredential;
  final String? message;

  const SecureAuthResult(this.status, {this.userCredential, this.message});

  bool get isSuccess => status == SecureAuthStatus.success;
}

class SecureAuth {
  SecureAuth._();

  static final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static final LocalAuthentication _localAuth = LocalAuthentication();

  static const _keyEmail = 'user_email';
  static const _keyPassword = 'user_password';

  /// Save credentials securely
  static Future<void> saveCredentials({
    required String email,
    required String password,
  }) async {
    try {
      await _storage.write(key: _keyEmail, value: email);
      await _storage.write(key: _keyPassword, value: password);
    } catch (e, st) {
      debugPrint('SecureAuth.saveCredentials error: $e');
      debugPrint(st.toString());
      rethrow;
    }
  }

  /// Retrieve stored credentials
  static Future<Map<String?, String?>> getCredentials() async {
    try {
      final email = await _storage.read(key: _keyEmail);
      final password = await _storage.read(key: _keyPassword);
      return {'email': email, 'password': password};
    } catch (e, st) {
      debugPrint('SecureAuth.getCredentials error: $e');
      debugPrint(st.toString());
      return {'email': null, 'password': null};
    }
  }

  /// Clear stored credentials
  static Future<void> clearCredentials() async {
    try {
      await _storage.delete(key: _keyEmail);
      await _storage.delete(key: _keyPassword);
    } catch (e, st) {
      debugPrint('SecureAuth.clearCredentials error: $e');
      debugPrint(st.toString());
      rethrow;
    }
  }

  /// Check if biometric auth is available
  static Future<bool> canAuthenticate() async {
    try {
      final can = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      debugPrint('SecureAuth.canAuthenticate: can=$can supported=$supported');
      return can || supported;
    } catch (e, st) {
      debugPrint('SecureAuth.canAuthenticate error: $e');
      debugPrint(st.toString());
      return false;
    }
  }

  /// Perform biometric authentication
  static Future<bool> authenticate() async {
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to continue',
      );
      debugPrint('SecureAuth.authenticate result: $ok');
      return ok;
    } catch (e, st) {
      debugPrint('SecureAuth.authenticate error: $e');
      debugPrint(st.toString());
      return false;
    }
  }

  /// Main: Authenticate + Sign In
  static Future<SecureAuthResult> authenticateAndSignIn() async {
    try {
      final available = await canAuthenticate();
      if (!available) {
        return SecureAuthResult(
          SecureAuthStatus.noBiometric,
          message: 'Biometric authentication not available on this device',
        );
      }

      final ok = await authenticate();
      if (!ok) {
        return SecureAuthResult(
          SecureAuthStatus.biometricFailed,
          message: 'Biometric authentication failed',
        );
      }

      final creds = await getCredentials();
      final email = creds['email'];
      final password = creds['password'];

      if (email == null || password == null) {
        return SecureAuthResult(
          SecureAuthStatus.noStoredCredentials,
          message: 'No stored credentials',
        );
      }

      try {
        final uc = await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: password);

        // After successful sign-in, register FCM token with backend (fire-and-forget).
        try {
          final idToken = await uc.user?.getIdToken();
          final backendBase = (dotenv.env['HTTP_URL'] ?? 'http://10.180.12.100:25001')
              .replaceAll(RegExp(r'/graphql\/?\s*\$'), '');

          if (idToken != null && idToken.isNotEmpty) {
            // Fire-and-forget call to register FCM token. Intentionally not awaited.
            registerDeviceFcmTokenAfterLogin(
              backendBaseUrl: backendBase,
              accessToken: idToken,
            );
          }
        } catch (e, st) {
          debugPrint('FCM registration post-login failed: $e');
          debugPrint(st.toString());
        }

        return SecureAuthResult(
          SecureAuthStatus.success,
          userCredential: uc,
          message: 'Sign-in successful',
        );
      } catch (e, st) {
        debugPrint('SecureAuth.authenticateAndSignIn sign-in error: $e');
        debugPrint(st.toString());

        return SecureAuthResult(
          SecureAuthStatus.signInFailed,
          message: 'Sign-in failed: ${e.toString()}',
        );
      }
    } on MissingPluginException catch (e, st) {
      debugPrint('SecureAuth.authenticateAndSignIn MissingPluginException: $e');
      debugPrint(st.toString());
      return SecureAuthResult(
        SecureAuthStatus.pluginMissing,
        message: 'Missing plugin: ${e.toString()}',
      );
    } on PlatformException catch (e, st) {
      debugPrint('SecureAuth.authenticateAndSignIn PlatformException: ${e.code} ${e.message}');
      debugPrint(st.toString());
      return SecureAuthResult(
        SecureAuthStatus.platformError,
        message: e.message ?? e.code,
      );
    } catch (e, st) {
      debugPrint('SecureAuth.authenticateAndSignIn error: $e');
      debugPrint(st.toString());
      return SecureAuthResult(
        SecureAuthStatus.unknownError,
        message: 'Authentication failed: ${e.toString()}',
      );
    }
  }
}
