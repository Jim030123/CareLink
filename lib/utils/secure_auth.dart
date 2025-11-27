import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SecureAuth {
  SecureAuth._();

  static final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static final LocalAuthentication _localAuth = LocalAuthentication();

  static const _keyEmail = 'user_email';
  static const _keyPassword = 'user_password';

  /// Save credentials securely on device. Prefer storing tokens when possible.
  static Future<void> saveCredentials({required String email, required String password}) async {
    try {
      await _storage.write(key: _keyEmail, value: email);
      await _storage.write(key: _keyPassword, value: password);
    } catch (e, st) {
      debugPrint('SecureAuth.saveCredentials error: $e');
      debugPrint(st.toString());
      rethrow;
    }
  }

  /// Retrieve stored credentials (may return nulls if not stored).
  static Future<Map<String?, String?>> getCredentials() async {
    try {
      final email = await _storage.read(key: _keyEmail);
      final password = await _storage.read(key: _keyPassword);
      return {'email': email, 'password': password};
    } on MissingPluginException catch (e, st) {
      debugPrint('SecureAuth.getCredentials MissingPluginException: $e');
      debugPrint(st.toString());
      return {'email': null, 'password': null};
    } catch (e, st) {
      debugPrint('SecureAuth.getCredentials error: $e');
      debugPrint(st.toString());
      return {'email': null, 'password': null};
    }
  }

  /// Clear stored credentials.
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

  /// Check if biometric auth is available on the device.
  static Future<bool> canAuthenticate() async {
    try {
      final can = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      debugPrint('SecureAuth.canAuthenticate: can=$can supported=$supported');
      return can || supported;
    } on MissingPluginException catch (e, st) {
      debugPrint('SecureAuth.canAuthenticate MissingPluginException: $e');
      debugPrint(st.toString());
      return false;
    } catch (e, st) {
      debugPrint('SecureAuth.canAuthenticate error: $e');
      debugPrint(st.toString());
      return false;
    }
  }

  /// Perform local biometric authentication (fingerprint/face). Returns true if user authenticated.
  static Future<bool> authenticate() async {
    try {
      // Use a minimal call for broad compatibility across local_auth versions.
      final ok = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to continue',
      );
      debugPrint('SecureAuth.authenticate result: $ok');
      return ok;
    } on PlatformException catch (e, st) {
      debugPrint('SecureAuth.authenticate PlatformException: ${e.code} ${e.message}');
      debugPrint(st.toString());
      return false;
    } on MissingPluginException catch (e, st) {
      debugPrint('SecureAuth.authenticate MissingPluginException: $e');
      debugPrint(st.toString());
      return false;
    } catch (e, st) {
      debugPrint('SecureAuth.authenticate error: $e');
      debugPrint(st.toString());
      return false;
    }
  }

  /// Authenticate with biometrics and then sign in using stored credentials (if present).
  /// Returns `UserCredential` on success, or null on failure.
  static Future<UserCredential?> authenticateAndSignIn(BuildContext context) async {
    try {
      final available = await canAuthenticate();
      if (!available) {
        final msg = 'Biometric authentication not available on this device';
        debugPrint('SecureAuth.authenticateAndSignIn: $msg');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        return null;
      }

      final ok = await authenticate();
      if (!ok) {
        debugPrint('SecureAuth.authenticateAndSignIn: user failed biometric auth');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Biometric authentication failed')));
        return null;
      }

      final creds = await getCredentials();
      final email = creds['email'];
      final password = creds['password'];
      if (email == null || password == null) {
        final msg = 'No stored credentials';
        debugPrint('SecureAuth.authenticateAndSignIn: $msg');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        return null;
      }

      try {
        final uc = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
        debugPrint('SecureAuth.authenticateAndSignIn: Firebase sign-in success for $email');
        return uc;
      } catch (e, st) {
        debugPrint('SecureAuth.authenticateAndSignIn: Firebase sign-in failed: $e');
        debugPrint(st.toString());
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sign-in failed: ${e.toString()}')));
        return null;
      }
    } on MissingPluginException catch (e, st) {
      debugPrint('SecureAuth.authenticateAndSignIn MissingPluginException: $e');
      debugPrint(st.toString());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Platform missing plugin: ${e.toString()}')));
      return null;
    } on PlatformException catch (e, st) {
      debugPrint('SecureAuth.authenticateAndSignIn PlatformException: ${e.code} ${e.message}');
      debugPrint(st.toString());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Platform error: ${e.message ?? e.code}')));
      return null;
    } catch (e, st) {
      debugPrint('SecureAuth.authenticateAndSignIn error: $e');
      debugPrint(st.toString());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Authentication failed: ${e.toString()}')));
      return null;
    }
  }
}
