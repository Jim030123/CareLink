import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

class NotFoundPage extends StatelessWidget {
  final String? location;
  const NotFoundPage({super.key, this.location});

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: Padding(
        padding: EdgeInsets.all(20.w),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // the lottie animation from assets
              Lottie.asset(
                'assets/animations/not_found.json',
                width: 200.w,
                height: 200.w,
                repeat: true,
                animate: true,
              ),
              SizedBox(height: 16.h),
              Text(
                'We couldn\'t find the page',
                style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.h),
              Text(
                location ?? '',
                style: TextStyle(fontSize: 14.sp, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20.h),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Go to Login'),
                  ),
                  SizedBox(width: 12.w),
                  ElevatedButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('Go Home'),
                  ),
                ],
              ),
            ],
          ),
        ),

      ),
    );
  }
}
