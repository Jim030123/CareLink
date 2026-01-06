import 'package:carelink_mobile/utils/auth_service.dart';
import 'package:carelink_mobile/utils/secure_auth.dart';
import 'package:carelink_mobile/utils/user_service.dart';
import 'package:flutter/material.dart';

/// Controller that holds the logic previously inside the `LoginPage` state.
///
/// - Exposes `formKey`, `emailController`, `passController` and
///   `biometricAvailable` for the UI to bind to.
class LoginController {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passController = TextEditingController();

  /// Notifies the UI when biometric availability changes.
  final ValueNotifier<bool> biometricAvailable = ValueNotifier<bool>(false);

  Future<void> init() async {
    await checkBiometricAvailability();
  }

  Future<void> dispose() async {
    emailController.dispose();
    passController.dispose();
    biometricAvailable.dispose();
  }

  Future<void> checkBiometricAvailability() async {
    try {
      final creds = await SecureAuth.getCredentials();
      final hasCred = creds['email'] != null && creds['password'] != null;
      final can = await SecureAuth.canAuthenticate();
      biometricAvailable.value = hasCred && can;
    } catch (e) {
      // Keep previous value if check fails; log for debugging.
      debugPrint('LoginController: biometric availability check failed: $e');
    }
  }

  /// Performs email/password sign-in. Returns true on success.
  Future<bool> signIn(BuildContext context) async {
    if (!formKey.currentState!.validate()) return false;

    try {
      await AuthService.instance.signInWithEmail(
        email: emailController.text,
        password: passController.text,
      );

      try {
        await SecureAuth.clearCredentials();
          // Attempt to fetch userType from backend and persist it with credentials
          String? userType;
          try {
            userType = await fetchCurrentUserType();
            debugPrint('LoginController: fetched userType=$userType');
          } catch (e) {
            debugPrint('LoginController: failed to fetch userType: $e');
          }

          await SecureAuth.saveCredentials(
            email: emailController.text.trim(),
            password: passController.text,
            role: userType,
          );
      } catch (e) {
        debugPrint('LoginController: failed to replace saved credentials: $e');
      }

      if (!context.mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login successful')),
      );

      await checkBiometricAvailability();

      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e')),
        );
      }
      return false;
    }
  }

  /// Attempts biometric authentication and sign-in. Returns true on success.
  Future<bool> biometricSignIn(BuildContext context) async {
    final result = await SecureAuth.authenticateAndSignIn();

    if (!context.mounted) return false;

    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Biometric authentication failed')),
      );
      return false;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signed in with biometrics')),
    );
    return true;
  }
}
