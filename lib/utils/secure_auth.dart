import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:carelink_mobile/utils/fcm.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const _keyRole = 'user_role';

  /// Save credentials securely
  static Future<void> saveCredentials({
    required String email,
    required String password,
    String? role,
  }) async {
    try {
      await _storage.write(key: _keyEmail, value: email);
      await _storage.write(key: _keyPassword, value: password);
      if (role != null) {
        await _storage.write(key: _keyRole, value: role);
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('role', role);
        } catch (_) {}
      }
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
      final role = await _storage.read(key: _keyRole);
      return {'email': email, 'password': password, 'role': role};
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
      await _storage.delete(key: _keyRole);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('role');
      } catch (_) {}
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

      debugPrint('SecureAuth: loaded credentials - emailPresent=${email != null}, passwordPresent=${password != null}, storedRole=${creds["role"]}');

      if (email == null || password == null) {
        return SecureAuthResult(
          SecureAuthStatus.noStoredCredentials,
          message: 'No stored credentials',
        );
      }

      try {
        final uc = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
        debugPrint('SecureAuth: signInWithEmailAndPassword returned UserCredential: $uc');
        debugPrint('SecureAuth: uc.user = ${uc.user}');
        debugPrint('SecureAuth: FirebaseAuth.instance.currentUser = ${FirebaseAuth.instance.currentUser?.uid}');


        try {
          final user = FirebaseAuth.instance.currentUser;
          debugPrint('SecureAuth: resolved user = $user');
          if (user != null) {
            // try to persist role from custom token claims or guess from displayName
            try {
              final idToken = await user.getIdTokenResult();
              final claims = idToken.claims;
              if (claims != null && claims['role'] != null) {
                final roleVal = claims['role'].toString();
                debugPrint('SecureAuth: persisting role from token claims: $roleVal');
                try {
                  await _storage.write(key: _keyRole, value: roleVal);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('role', roleVal);
                  debugPrint('SecureAuth: role persisted to secure storage and SharedPreferences');
                } catch (e) {
                  debugPrint('SecureAuth: failed to persist role: $e');
                }
              } else {
                final displayName = user.displayName ?? '';
                if (displayName.toLowerCase().contains('dr') || (user.email ?? '').toLowerCase().contains('doctor')) {
                  debugPrint('SecureAuth: inferring role=doctor from displayName/email');
                  try {
                    await _storage.write(key: _keyRole, value: 'doctor');
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('role', 'doctor');
                    debugPrint('SecureAuth: inferred role persisted');
                  } catch (e) {
                    debugPrint('SecureAuth: failed to persist inferred role: $e');
                  }
                }
              }
            } catch (_) {}
            final fcmToken = await FirebaseMessaging.instance.getToken();
            debugPrint('SecureAuth: FCM token = $fcmToken');

            if (fcmToken == null || fcmToken.trim().isEmpty) {
              debugPrint('No FCM token available; skipping device registration.');
            } else {
              String platform;
              if (kIsWeb) {
                platform = 'web';
              } else if (Platform.isAndroid) {
                platform = 'android';
              } else if (Platform.isIOS) {
                platform = 'ios';
              } else {
                platform = Platform.operatingSystem;
              }

              final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
              Map<String, dynamic> deviceData = {};
              try {
                if (kIsWeb) {
                  final info = await deviceInfo.webBrowserInfo;
                  deviceData = {
                    'userAgent': info.userAgent,
                    'vendor': info.vendor,
                    'appName': info.appName,
                    'appVersion': info.appVersion,
                    'platform': info.platform,
                  };
                } else if (Platform.isAndroid) {
                  final info = await deviceInfo.androidInfo;
                  deviceData = {
                    'brand': info.brand,
                    'device': info.device,
                    'model': info.model,
                    'id': info.id,
                    // 'androidId': info.androidId,
                    'version_sdkInt': info.version.sdkInt,
                  };
                } else if (Platform.isIOS) {
                  final info = await deviceInfo.iosInfo;
                  deviceData = {
                    'name': info.name,
                    'systemName': info.systemName,
                    'systemVersion': info.systemVersion,
                    'model': info.model,
                    'utsname': {
                      'machine': info.utsname.machine,
                      'release': info.utsname.release,
                    }
                  };
                } else {
                  deviceData = {'os': Platform.operatingSystem};
                }
              } catch (e, st) {
                debugPrint('SecureAuth device info error: $e');
                debugPrint(st.toString());
              }

              debugPrint('Device info at login: $deviceData');

              final deviceName = (deviceData['model'] ?? deviceData['device'] ?? (Platform.isAndroid ? 'Android Device' : Platform.isIOS ? 'iOS Device' : 'Unknown Device')).toString();
              final deviceIdFromInfo = deviceData['androidId'] ?? deviceData['id'] ?? user.uid;

              final payload = {
                'fcmToken': fcmToken,
                'userId': user.uid,
                'platform': platform,
                'deviceName': deviceName,
                'deviceId': deviceIdFromInfo,
                'deviceInfo': deviceData,
              };

              debugPrint('SecureAuth: device registration payload = $payload');

              await postDeviceRegistration(payload);
            }
          }
        } catch (e, st) {
          debugPrint('SecureAuth post sign-in device registration error: $e');
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
