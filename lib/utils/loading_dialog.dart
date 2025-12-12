import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Shows a non-dismissible loading dialog with a Lottie animation and message.
///
/// Returns a `VoidCallback` that dismisses the dialog when called.
/// Example:
/// ```dart
/// final dismiss = showLoadingDialog(context, 'Account creation in progress..');
/// await yourAsyncWork();
/// dismiss();
/// ```
VoidCallback showLoadingDialog(BuildContext context, String message) {
  // Use rootNavigator to ensure we pop the dialog even if called from a nested navigator
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animations/loading.json',
                  width: 160,
                  height: 160,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  return () {
    try {
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    } catch (_) {}
  };
}
