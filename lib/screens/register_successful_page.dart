import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Shows a success screen after registration: pending verification message and Login button.
class RegisterSuccessfulPage extends StatelessWidget {
  const RegisterSuccessfulPage({super.key, this.onLogin});

  final VoidCallback? onLogin;

  @override
  Widget build(BuildContext context) {
    final Color background = const Color(0xFFFAF3EC);
    final Color card = Colors.white;
    final Color accent = const Color(0xFFF4CBA1);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Top rounded card area
              Container(
                width: double.infinity,
                margin: EdgeInsets.only(top: 12.h, left: 12.w, right: 12.w),
                padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 18.w),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(20.w),
                ),
                child: Column(
                  children: [
                    // Logo / icon
                    Icon(Icons.check_circle, size: 96.w, color: Colors.green.shade600),
                    SizedBox(height: 18.h),
                    Text(
                      'Account Created Successfully',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      'Pending Verification',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14.sp, color: Colors.black54),
                    ),
                    SizedBox(height: 18.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.w),
                      child: Text(
                        'Your account is currently under review and will be verified within 48 hours.\n\nYou will receive an email notification once your account has been approved and activated.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13.sp, color: Colors.black54, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 28.h),

              // Login button
              Center(
                child: ElevatedButton(
                  onPressed: onLogin ?? () => Navigator.of(context).pushReplacementNamed('/login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(horizontal: 44.w, vertical: 12.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.w)),
                    elevation: 4,
                  ),
                  child: Text('Login', style: TextStyle(fontSize: 14.sp)),
                ),
              ),

              SizedBox(height: 12.h),
              Center(child: Text('Already have account?\nLogin here', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.sp, color: Colors.black54))),
            ],
          ),
        ),
      ),
    );
  }
}
