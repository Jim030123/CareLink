import 'package:carelink_mobile/components/text_field.dart';
import 'package:carelink_mobile/utils/auth_service.dart';
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

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  void _onLogin() async {
    try {
      await AuthService.instance.signInWithEmail(
        email: _emailController.text,
        password: _passController.text,
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Login successful')));
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
    final Color accent = const Color(0xFFF4CBA1);
    final OutlineInputBorder fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(6.w),
      borderSide: BorderSide(color: Colors.grey.shade400),
    );

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
                      padding: EdgeInsets.all(20.w),
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
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                hintText: 'Email',
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                                border: fieldBorder,
                                enabledBorder: fieldBorder,
                                focusedBorder: fieldBorder.copyWith(
                                  borderSide: const BorderSide(
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Enter email';
                                }
                                if (!value.contains('@')) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 12.h),

                            TextFormField(
                              controller: _passController,
                              decoration: InputDecoration(
                                hintText: 'Password',
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                                border: fieldBorder,
                                enabledBorder: fieldBorder,
                                focusedBorder: fieldBorder.copyWith(
                                  borderSide: const BorderSide(
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
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
