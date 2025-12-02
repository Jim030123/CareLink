import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math';

import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Initializes notification plugin, channels and timezone.
/// Call once (e.g. app start) before showing notifications.
Future<void> initializeNotifications({
  AndroidNotificationChannel? defaultChannel,
  AndroidNotificationChannel? highPriorityChannel,
  void Function(NotificationResponse)? onDidReceiveNotificationResponse,
}) async {
  // Timezone setup
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.local);

  // Request runtime notification permission where required (Android 13+/iOS)
  try {
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      final result = await Permission.notification.request();
      if (result.isPermanentlyDenied) {
        await openAppSettings();
      }
    }
  } catch (e) {
    debugPrint('Notification permission request failed: $e');
  }

  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
    requestSoundPermission: true,
    requestBadgePermission: true,
    requestAlertPermission: true,
  );

  const InitializationSettings initSettings = InitializationSettings(
    android: androidInit,
    iOS: iosInit,
    macOS: null,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
  );

  // Create suggested channels if Android implementation available
  final androidImpl = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  if (androidImpl != null) {
    final AndroidNotificationChannel defaultCh = defaultChannel ??
        const AndroidNotificationChannel(
          'default_channel_id',
          'Default',
          description: 'General notifications',
          importance: Importance.defaultImportance,
        );

    final AndroidNotificationChannel highCh = highPriorityChannel ??
        const AndroidNotificationChannel(
          'high_channel_id',
          'High Priority',
          description: 'High priority notifications (heads-up)',
          importance: Importance.max,
        );

    try {
      await androidImpl.createNotificationChannel(defaultCh);
      await androidImpl.createNotificationChannel(highCh);

      final enabled = await androidImpl.areNotificationsEnabled();
      if (enabled == false) {
        // Let caller decide; open settings as a fallback here.
        await openAppSettings();
      }
    } catch (e) {
      debugPrint('Failed creating Android channels or checking settings: $e');
    }
  }

  // On iOS ask explicitly too
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(alert: true, badge: true, sound: true);
}

/// Shows a high-priority (heads-up) notification.
///
/// Parameters:
/// - [id]: notification id
/// - [title]: notification title
/// - [body]: notification body
/// - [payload]: optional payload
/// - [fullScreen]: if true, request a full-screen intent (Android only)
Future<void> showHighPriorityNotification({
  required int id,
  required String title,
  String? body,
  String? payload,
  bool fullScreen = false,
  String channelId = 'high_channel_id',
}) async {
  // Permission check
  try {
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      final result = await Permission.notification.request();
      if (!result.isGranted) {
        if (result.isPermanentlyDenied) await openAppSettings();
        return;
      }
    }
  } catch (e) {
    debugPrint('Permission check failed: $e');
  }

  final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    channelId,
    'High Priority',
    channelDescription: 'High priority notifications (heads-up)',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    fullScreenIntent: fullScreen,
  );

  final NotificationDetails platformDetails = NotificationDetails(
    android: androidDetails,
    iOS: DarwinNotificationDetails(),
  );

  await flutterLocalNotificationsPlugin.show(
    id,
    title,
    body,
    platformDetails,
    payload: payload,
  );
}

/// Simple convenience to schedule a high priority notification after [seconds].
Future<void> scheduleHighPriorityInSeconds({
  required int id,
  required String title,
  String? body,
  String? payload,
  required int seconds,
  bool fullScreen = false,
  String channelId = 'high_channel_id',
}) async {
  await Future.delayed(Duration(seconds: seconds));
  await showHighPriorityNotification(
    id: id,
    title: title,
    body: body,
    payload: payload,
    fullScreen: fullScreen,
    channelId: channelId,
  );
}

/// Schedule a notification at a specific [target] DateTime (local timezone).
/// Uses zoned scheduling so it's more reliable across timezones.
Future<void> scheduleAt({
  required int id,
  required String title,
  String? body,
  String? payload,
  required DateTime target,
  bool fullScreen = false,
  String channelId = 'high_channel_id',
}) async {
  // Ensure timezone package was initialized by initializeNotifications()
  // Simple scheduling: compute seconds until target (use UTC to avoid timezone mismatches)
  final seconds = target.toUtc().difference(DateTime.now().toUtc()).inSeconds;
  if (seconds <= 0) {
    await showHighPriorityNotification(
      id: id,
      title: title,
      body: body,
      payload: payload,
      fullScreen: fullScreen,
      channelId: channelId,
    );
  } else {
    await scheduleHighPriorityInSeconds(
      id: id,
      title: title,
      body: body,
      payload: payload,
      seconds: seconds,
      fullScreen: fullScreen,
      channelId: channelId,
    );
  }
}

Future<void> cancelNotification(int id) async {
  await flutterLocalNotificationsPlugin.cancel(id);
}

Future<void> cancelAllNotifications() async {
  await flutterLocalNotificationsPlugin.cancelAll();
}

Future<void> openNotificationSettings() async {
  await openAppSettings();
}

/// Generate a reasonably-unique integer id for notifications.
///
/// This uses the current timestamp (milliseconds) plus a small random
/// component and returns a value that's safe for Android/iOS notification ids.
int generateNotificationId() {
  final int tsPart = DateTime.now().millisecondsSinceEpoch.remainder(1000000);
  final int randPart = Random().nextInt(1000);
  return tsPart * 1000 + randPart; // Max ~999,999,999
}
