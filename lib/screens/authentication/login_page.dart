import 'package:carelink_mobile/components/text_field.dart';
import 'package:carelink_mobile/utils/auth_service.dart';
import 'package:carelink_mobile/utils/secure_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  /// 统一弹 SnackBar，内部自己做 mounted 检查
  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final creds = await SecureAuth.getCredentials();
      final hasCred = creds['email'] != null && creds['password'] != null;
      final can = await SecureAuth.canAuthenticate();
      if (!mounted) return;
      setState(() {
        _biometricAvailable = hasCred && can;
      });
    } catch (e) {
      debugPrint('LoginPage: biometric availability check failed: $e');
    }
  }

  Future<void> _onLogin() async {
    // Validate form fields first; if invalid, show field errors and stop.
    if (!_formKey.currentState!.validate()) return;

    try {
      await AuthService.instance.signInWithEmail(
        email: _emailController.text,
        password: _passController.text,
      );

      // Save credentials so biometric login becomes available next time.
      try {
        await SecureAuth.clearCredentials();
        await SecureAuth.saveCredentials(
          email: _emailController.text.trim(),
          password: _passController.text,
        );
      } catch (e) {
        debugPrint('LoginPage: failed to replace saved credentials: $e');
      }

      _showSnack('Login successful');

      await _checkBiometricAvailability();

      if (!mounted) return;
      // navigate to home via GoRouter
      context.go('/home');
    } catch (e) {
      _showSnack('Login failed: $e');
    }
  }

  Future<void> _onBiometricLogin() async {
    final result = await SecureAuth.authenticateAndSignIn();

    if (!mounted) return;

    if (!result.isSuccess) {
      _showSnack(result.message ?? 'Biometric authentication failed');
      return;
    }

    _showSnack('Signed in with biometrics');
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final Color background = const Color(0xFFFAF3EC);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Stack(
          children: [
            // Top-right role pill

            // Center content
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 24.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 8.h),
                    SvgPicture.asset(
                      'assets/icons/logo.svg',
                      width: 120.w,
                      height: 120.h,
                    ),

                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20.w),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FormTextField(
                              controller: _emailController,
                              hint: 'Email',
                              label: 'Email',
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Enter email';
                                }
                                if (!v.contains('@')) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 12.h),
                            FormTextField(
                              controller: _passController,
                              hint: 'Password',
                              label: 'Password',
                              obscureText: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Enter password';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 18.h),

                            if (_biometricAvailable) ...[
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _onBiometricLogin,
                                  icon: const Icon(Icons.fingerprint),
                                  label: const Text('Login with biometrics'),
                                ),
                              ),
                              SizedBox(height: 10.h),

                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _onLogin,
                                  child: Text(
                                    'Login',
                                    style: TextStyle(fontSize: 16.sp),
                                  ),
                                ),
                              ),
                            ],
                            SizedBox(height: 10.h),
                            // 分割线
                            Divider(color: Colors.grey, thickness: 1),

                            TextButton(
                              onPressed: () => context.go('/register'),
                              child: Text(
                                'Don\'t have an account? Register here',
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
