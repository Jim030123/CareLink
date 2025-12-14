import 'dart:math';

import 'package:carelink_mobile/utils/user_service.dart';
import 'package:flutter/material.dart';

/// Periods of the day used for greetings.
enum GreetingPeriod {
  morning,
  afternoon,
  evening,
  night,
}

GreetingPeriod _periodFromHour(int hour) {
  if (hour >= 5 && hour <= 11) return GreetingPeriod.morning;
  if (hour >= 12 && hour <= 16) return GreetingPeriod.afternoon;
  if (hour >= 17 && hour <= 20) return GreetingPeriod.evening;
  return GreetingPeriod.night;
}

String _baseGreetingForPeriod(GreetingPeriod p) {
  switch (p) {
    case GreetingPeriod.morning:
      return 'Good morning';
    case GreetingPeriod.afternoon:
      return 'Good afternoon';
    case GreetingPeriod.evening:
      return 'Good evening';
    case GreetingPeriod.night:
      return 'Good night';
  }
}

/// Returns a friendly greeting based on the current local time and the
/// currently-signed-in user's `displayName` (fetched via
/// `fetchCurrentUser()`). If no displayName is available, the greeting
/// will omit the name.
///
/// Example return values:
/// - "Good morning, Alice!"
/// - "Good afternoon!"
Future<String> getGreetingMessage() async {
  final now = DateTime.now();
  try {
    final user = await fetchCurrentUser();
    // Prefer displayName, fallback to email if displayName missing.
    final rawName = user?['displayName'] as String?;
    final rawEmail = user?['email'] as String?;
    final nameCandidate = (rawName ?? '').trim().isNotEmpty ? (rawName ?? '') : (rawEmail ?? '');
    final name = (nameCandidate ?? '').trim();
    final text = formatGreeting(now, displayName: name.isNotEmpty ? name : null);
    return text;
  } catch (e, st) {
    // Log exception to help debugging; fall back to a simple greeting.
    debugPrint('getGreetingMessage: fetchCurrentUser error: $e\n$st');
    final text = formatGreeting(now);
    return text;
  }
}

/// Pure formatter: return greeting text for given time and optional name.
/// This does not perform any network I/O and is safe to call frequently.
String formatGreeting(DateTime now, {String? displayName}) {
  final period = _periodFromHour(now.hour);

  // Templates per period (varied styles). Keep them concise; punctuation may be included.
  final templates = <GreetingPeriod, List<String>>{
    GreetingPeriod.morning: [
      'Good day ☀️',
      'Morning! 🌅',
      'Rise and shine! ✨',
      'Have a great morning ☀️',
      'Have a wonderful morning 🌞',
    ],
    GreetingPeriod.afternoon: [
      'Good day ☀️',
      'Hello 👋',
      'Hi 🙂',
      'Have a nice afternoon ☀️',
    ],
    GreetingPeriod.evening: [
      'Good evening 🌇',
      'Hello 🌆',
      'Have a pleasant evening 🌙',
    ],
    GreetingPeriod.night: [
      'Good night 🌙',
      'Sweet dreams 😴',
      'Sleep well 🌜',
      'Have a good night 🌙',
      'Rest well 🛌',
    ],
  };

  final list = templates[period] ?? [ _baseGreetingForPeriod(period) ];
  final rnd = Random();
  final template = list[rnd.nextInt(list.length)].trim();

  final name = (displayName ?? '').trim();

  // If name provided, insert it before trailing punctuation (if any),
  // otherwise append ", name".
  if (name.isNotEmpty) {
    String punct = '';
    if (template.endsWith('!') || template.endsWith('.') || template.endsWith('?')) {
      punct = template.substring(template.length - 1);
    }
    final base = punct.isEmpty ? template : template.substring(0, template.length - 1).trim();
    return '$base \n$name$punct';
  }

  return template;
}
