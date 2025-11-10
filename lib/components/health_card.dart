import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Reusable health card widget.
/// Uses an [Ink] with [InkWell] so the ripple is visible above the background
/// and correctly clipped to the rounded corners.
class HealthCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color? iconColor;
  final VoidCallback? onTap;

  const HealthCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    this.color = Colors.white,
    this.iconColor,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(12.r);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Material(
          elevation: 2,
          color: Colors.transparent,
          borderRadius: borderRadius,
          child: Ink(
            decoration: BoxDecoration(color: color, borderRadius: borderRadius),
            child: InkWell(
              borderRadius: borderRadius,
              splashColor: Colors.black12,
              onTap: onTap,
              child: Container(
                height: 100.h,
                padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 12.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            value,
                            style: TextStyle(
                              fontSize: 35.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Icon(icon, color: iconColor ?? Colors.red, size: 50.sp),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
