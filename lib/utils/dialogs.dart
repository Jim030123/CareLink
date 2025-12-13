import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:go_router/go_router.dart';

/// Shows a non-dismissible dialog with a Lottie animation (default
/// `assets/animations/unlock.json`), waits for [duration], then closes
/// the dialog and routes to [route] if provided.
///
/// Example:
/// ```dart
/// await showUnlockSuccessDialog(context, route: '/home');
/// ```
Future<void> showUnlockSuccessDialog(
  BuildContext context, {
  String animationAsset = 'assets/animations/unlock.json',
  Duration duration = const Duration(seconds: 4),
  String? route,
}) async {
  // Use root navigator to ensure dialog is above any nested navigators.
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 180,
                  child: Center(
                    child: Lottie.asset(
                      animationAsset,
                      width: 160,
                      height: 160,
                      fit: BoxFit.contain,
                      repeat: true,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Unlocked',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  // Wait the requested duration then pop and navigate.
  await Future.delayed(duration);

  // Close dialog if still open.
  try {
    Navigator.of(context, rootNavigator: true).pop();
  } catch (_) {}

  if (route != null) {
    // Prefer GoRouter navigation; fall back to Navigator if it fails.
    try {
      context.push(route);
    } catch (_) {
      Navigator.of(context).pushNamed(route);
    }
  }
}
