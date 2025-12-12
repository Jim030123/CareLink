import 'package:carelink_mobile/components/text_field.dart';
import 'package:carelink_mobile/controllers/login_controller.dart';
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
  final LoginController _controller = LoginController();

  @override
  void initState() {
    super.initState();
    _controller.init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
                        key: _controller.formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FormTextField(
                              controller: _controller.emailController,

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
                              controller: _controller.passController,

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
                            // Biometric button listens to controller's ValueNotifier
                            ValueListenableBuilder<bool>(
                              valueListenable: _controller.biometricAvailable,
                              builder: (context, available, child) {
                                if (!available) return const SizedBox.shrink();
                                return Column(
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () async {
                                          final ok = await _controller.biometricSignIn(context);
                                          if (ok && mounted) context.go('/home');
                                        },
                                        icon: const Icon(Icons.fingerprint),
                                        label: const Text('Login with biometrics', style: TextStyle(fontSize: 16)),
                                      ),
                                    ),
                                    SizedBox(height: 10.h),
                                  ],
                                );
                              },
                            ),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () async {
                                  final ok = await _controller.signIn(context);
                                  if (ok && mounted) context.go('/home');
                                },
                                child: Text(
                                  'Login',
                                  style: TextStyle(fontSize: 16.sp),
                                ),
                              ),
                            ),
                            SizedBox(height: 10.h),
                            // 分割线
                            Divider(color: Colors.grey, thickness: 1),

                            TextButton(
                              onPressed: () => context.go('/register'),
                              child: Text(
                                'Don\'t have an account? Register here',
                                style: TextStyle(
                                  fontSize: 12.sp,
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
