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
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final creds = await SecureAuth.getCredentials();
      final hasCred = creds['email'] != null && creds['password'] != null;
      final can = await SecureAuth.canAuthenticate();
      setState(() {
        _biometricAvailable = hasCred && can;
      });
    } catch (e) {
      debugPrint('LoginPage: biometric availability check failed: $e');
    }
  }

  void _onLogin() async {
    // Validate form fields first; if invalid, show field errors and stop.
    if (!_formKey.currentState!.validate()) return;

    try {
      await AuthService.instance.signInWithEmail(
        email: _emailController.text,
        password: _passController.text,
      );
      // Save credentials so biometric login becomes available next time.
      try {
        // Replace any previously stored credentials with the new account.
        await SecureAuth.clearCredentials();
        await SecureAuth.saveCredentials(email: _emailController.text.trim(), password: _passController.text);
      } catch (e) {
        debugPrint('LoginPage: failed to replace saved credentials: $e');
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Login successful')));
      // update biometric availability state
      _checkBiometricAvailability();
      // navigate to home via GoRouter
      context.go('/home');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Login failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // initialize responsive helper (adjust design size here if your design uses different base)

    final Color background = const Color(0xFFFAF3EC);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Stack(
          children: [
            // Top-right role pill
            Positioned(
              right: 16.w,
              top: 35.h,
              child: Material(
                color: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.w),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20.w),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Care Recipient selected')),
                    );
                  },
                  child: Container(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person, size: 16.w),
                          SizedBox(width: 6.w),
                          Text(
                            'Care Recipient',
                            style: TextStyle(fontSize: 18.sp),
                            softWrap: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Center content
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 24.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 8.h),
                    // Logo (placeholder icon)
                    SvgPicture.asset(
                      'assets/icons/logo.svg',
                      width: 120.w,
                      height: 120.h,
                    ),

                    // White rounded card with form
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
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Enter email';
                                if (!v.contains('@')) return 'Enter a valid email';
                                return null;
                              },
                            ),
                            SizedBox(height: 12.h),

                            FormTextField(
                              controller: _passController,
                              hint: 'Password',
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
                            SizedBox(height: 10.h),
                            if (_biometricAvailable) ...[
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    // attempt biometric authenticate + sign-in
                                    final uc = await SecureAuth.authenticateAndSignIn(context);
                                    if (uc != null) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed in with biometrics')));
                                        context.go('/home');
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.fingerprint),
                                  label: const Text('Login with biometrics'),
                                ),
                              ),
                              SizedBox(height: 8.h),
                            ],
                            GestureDetector(
                              onTap: () {
                                // navigate to register screen via GoRouter
                                context.go('/register');
                              },
                              child: Text(
                                'No account? Register here',
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
