import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class HomeService {
  final String title;
  final String subtitle;
  final IconData icon;
  final MaterialColor color;
  final VoidCallback? onTap;

  HomeService({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });
}

Widget buildServiceCard(HomeService s) {
    return GestureDetector(
      onTap: s.onTap,
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.orange.withOpacity(0.25),width: 2),
          gradient: const LinearGradient(
            colors: [Colors.white, Colors.white70],
          ),
          borderRadius: BorderRadius.circular(12.w),
          boxShadow: [
            BoxShadow(color: Colors.orange.withOpacity(0.25), blurRadius: 2),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [s.color.shade900, s.color.shade100],
              ).createShader(bounds),
              blendMode: BlendMode.srcIn,
              child: Icon(s.icon, size: 50.w, color: Colors.white),
            ),
            SizedBox(height: 10.h),
            Container(
              width: 120.w,
              child: Text(
                s.title,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 6.h),

            Text(
              s.subtitle,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
