import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Retrieves the FCM token and registers the device with your backend.
///
/// Call this function immediately after a successful login, when you have
/// a valid `accessToken` (Bearer JWT).
///
/// - `backendBaseUrl`: e.g. "https://api.example.com" (no trailing slash)
/// - `accessToken`: Bearer JWT for authenticated requests
/// - `deviceName` / `deviceId`: optional; if omitted the function will try
///   to auto-fill them using `device_info_plus`.
Future<void> registerDeviceFcmTokenAfterLogin({
  required String backendBaseUrl,
  required String accessToken,
  String? deviceName,
  String? deviceId,
  bool autoFillDeviceInfo = true,
}) async {
  // Ensure Firebase Messaging is ready and (on iOS) request permissions
  try {
    if (Platform.isIOS) {
      final settings = await FirebaseMessaging.instance.requestPermission();
      print('iOS notification permission status: $settings');
    }
  } catch (e) {
    // Non-fatal; proceed to try getToken()
    print('Warning: error requesting notification permissions: $e');
  }

  // Get FCM token
  String? fcmToken;
  try {
    fcmToken = await FirebaseMessaging.instance.getToken();
    print('FCM token obtained: $fcmToken');

    // Log future token refreshes so you can debug token rotation
    // Use a lightweight handler that posts the new token to backend without
    // reattaching additional listeners.
    FirebaseMessaging.instance.onTokenRefresh.listen((String? newToken) async {
      print('FCM token refreshed: $newToken');
      if (newToken == null || newToken.trim().isEmpty) return;

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          print('No signed-in user; skipping refreshed token backend registration.');
          return;
        }
        final idToken = await user.getIdToken();
        if (idToken == null || idToken.isEmpty) return;

        // Derive backend base if not provided via dotenv
        final backendBase = dotenv.env['HTTP_URL'] ?? backendBaseUrl;
        final base = backendBase.replaceAll(RegExp(r'/graphql\/?\s*\$'), '');

        final payload = {
          'fcmToken': newToken,
          'platform': Platform.isIOS ? 'ios' : Platform.isAndroid ? 'android' : Platform.operatingSystem,
          if (deviceName != null) 'deviceName': deviceName,
          if (deviceId != null) 'deviceId': deviceId,
        };

        await _postDeviceRegistration(base, idToken, payload);
      } catch (e) {
        print('Error handling refreshed FCM token: $e');
      }
    });
  } catch (e) {
    print('Error obtaining FCM token: $e');
    return;
  }

  if (fcmToken == null || fcmToken.trim().isEmpty) {
    print('FCM token is null/empty; skipping device registration.');
    return;
  }

  // Determine platform string expected by backend
  String platform;
  if (Platform.isIOS) {
    platform = 'ios';
  } else if (Platform.isAndroid) {
    platform = 'android';
  } else {
    platform = Platform.operatingSystem; // fallback
  }

  // Attempt to auto-fill device info if requested
  if (autoFillDeviceInfo && (deviceName == null || deviceId == null)) {
    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        deviceName ??= '${info.manufacturer ?? ''} ${info.model ?? ''}'.trim();
        // Use the available Android identifier
        deviceId ??= info.id;
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        deviceName ??= info.name;
        deviceId ??= info.identifierForVendor;
      }
    } catch (e) {
      print('Warning: could not auto-fill device info: $e');
    }
  }

  final payload = {
    'fcmToken': fcmToken,
    'platform': platform,
    if (deviceName != null) 'deviceName': deviceName,
    if (deviceId != null) 'deviceId': deviceId,
  };

  final uri = Uri.parse('$backendBaseUrl/user/device/register');

  try {
    print('Registering device with payload: $payload');
    final resp = await _postDeviceRegistration(backendBaseUrl, accessToken, payload);

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      print('Device registered successfully (${resp.statusCode}).');
    } else {
      print('Failed to register device. Status: ${resp.statusCode}. Body: ${resp.body}');
    }
  } catch (e) {
    print('Error sending device registration request: $e');
  }
}

/// Helper to POST device registration to backend. Returns the http.Response or
/// throws on network errors.
Future<http.Response> _postDeviceRegistration(String backendBaseUrl, String accessToken, Map payload) async {
  final uri = Uri.parse('$backendBaseUrl/user/device/register');
  final resp = await http.post(
    uri,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    },
    body: jsonEncode(payload),
  );
  if (resp.statusCode >= 200 && resp.statusCode < 300) {
    print('Device registered successfully (${resp.statusCode}).');
  } else {
    print('Failed to register device. Status: ${resp.statusCode}. Body: ${resp.body}');
  }
  return resp;
}
