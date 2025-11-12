import 'package:carelink_mobile/utils/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';

/// Create Primary Caregiver Account step
/// Exposes callbacks:
/// - onBack: VoidCallback
/// - onNext: ValueChanged<Map<String, dynamic>> with collected form data
/// - onLogin: VoidCallback
class RegisterCaregiverPage extends StatefulWidget {
  const RegisterCaregiverPage({
    super.key,
    this.onBack,
    this.onNext,
    this.onLogin,
  });

  final VoidCallback? onBack;
  final ValueChanged<Map<String, dynamic>>? onNext;
  final VoidCallback? onLogin;

  @override
  State<RegisterCaregiverPage> createState() => _RegisterCaregiverPageState();
}

class _RegisterCaregiverPageState extends State<RegisterCaregiverPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _handleNext() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'firstName': _firstName.text.trim(),
      'lastName': _lastName.text.trim(),
      'email': _email.text.trim(),
      'password': _password.text,
    };

    if (widget.onNext != null) {
      widget.onNext!(data);
      return;
    }

    // Attempt to create the account. Recent firebase_auth versions removed
    // fetchSignInMethodsForEmail to avoid email enumeration; instead we try
    // to create the user and handle the 'email-already-in-use' error.
    // try {
    //   await AuthService.instance.signUpWithEmail(
    //     email: data['email']!,
    //     password: data['password']!,
    //   );

      // On success, navigate to next registration step
      context.push('/register/caregiver/numberofcarerecipient');
    // } on FirebaseAuthException catch (e) {
    //   if (e.code == 'email-already-in-use') {
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       const SnackBar(
    //         content: Text(
    //           'You already created an account before, please sign in',
    //         ),
    //       ),
    //     );
    //   } else {
    //     ScaffoldMessenger.of(
    //       context,
    //     ).showSnackBar(SnackBar(content: Text('Register failed: $e')));
    //   }
    // } catch (e) {
    //   ScaffoldMessenger.of(
    //     context,
    //   ).showSnackBar(SnackBar(content: Text('Register failed: $e')));
    // }
  }

  @override
  Widget build(BuildContext context) {
    final Color card = Colors.white;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SafeArea(
            child: SingleChildScrollView(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 8.h,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16.w),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                SvgPicture.asset(
                                  'assets/icons/logo.svg',
                                  width: 60.w,
                                  height: 60.h,
                                ),
                                Expanded(
                                  child: Center(
                                    child: Container(
                                      margin: EdgeInsets.only(right: 60.w),
                                      child: Text(
                                        'Register',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 25.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16.h),
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16.w,
                                    vertical: 8.h,
                                  ),

                                  decoration: BoxDecoration(
                                    color: Color(0xFFF4CBA1),

                                    borderRadius: BorderRadius.circular(16.w),
                                  ),

                                  child: Text(
                                    '2',
                                    style: TextStyle(fontSize: 24.sp),
                                  ),
                                ),
                                SizedBox(width: 8.w),

                                Expanded(
                                  child: Container(
                                    alignment: Alignment.topLeft,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16.w,

                                      vertical: 8.h,
                                    ),

                                    child: Text(
                                      'Create Primary Caregiver',
                                      textAlign: TextAlign.center,
                                      softWrap: true,
                                      style: TextStyle(
                                        fontSize: 24.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16.h),

                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                width: constraints.maxWidth,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16.w,
                                  vertical: 8.h,
                                ),

                                decoration: BoxDecoration(
                                  color: Color(0xFFFFF8F0),
                                  borderRadius: BorderRadius.circular(16.w),
                                ),

                                child: Row(
                                  mainAxisSize: MainAxisSize.min,

                                  children: [
                                    Icon(
                                      Icons.lightbulb_outline,
                                      size: 24.sp,
                                      color: Colors.orange,
                                    ),

                                    SizedBox(width: 8.w),

                                    Flexible(
                                      // 防止长文字溢出
                                      child: Text(
                                        'Allows us to customize the care experience based on the caregiver\'s relationship, preferences, and responsibilities.',
                                        textAlign: TextAlign.justify,
                                        softWrap: true,
                                        style: TextStyle(fontSize: 15.sp),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 14.h),

                      Container(
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(16.w),
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
                            children: [
                              _buildTextField(
                                controller: _firstName,
                                hint: 'First Name',
                              ),
                              SizedBox(height: 10.h),
                              _buildTextField(
                                controller: _lastName,
                                hint: 'Last Name',
                              ),
                              SizedBox(height: 10.h),
                              _buildTextField(
                                controller: _email,
                                hint: 'Email',
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty)
                                    return 'Enter email';
                                  if (!v.contains('@'))
                                    return 'Enter a valid email';
                                  return null;
                                },
                              ),
                              SizedBox(height: 10.h),
                              _buildTextField(
                                controller: _password,
                                hint: 'Password',
                                obscureText: true,
                                validator: (v) {
                                  if (v == null || v.isEmpty)
                                    return 'Enter password';
                                  if (v.length < 6)
                                    return 'Password must be at least 6 characters';
                                  return null;
                                },
                              ),
                              SizedBox(height: 10.h),
                              _buildTextField(
                                controller: _confirm,
                                hint: 'Confirm Password',
                                obscureText: true,
                                validator: (v) {
                                  if (v == null || v.isEmpty)
                                    return 'Confirm password';
                                  if (v != _password.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 18.h),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  widget.onBack ??
                                  () => Navigator.of(context).maybePop(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                              ),
                              child: Text(
                                'Back',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: Colors.black,
                                ),
                              ), // navigate back
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _handleNext,

                              child: Text(
                                'Next',
                                style: TextStyle(fontSize: 14.sp),
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 16.h),

                      Center(
                        child: Text(
                          'Already have account? Login here',
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.w),
      borderSide: BorderSide(color: Colors.grey.shade300),
    );

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: Colors.blue),
        ),
      ),
      validator:
          validator ??
          (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
    );
  }
}
