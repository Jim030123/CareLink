import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

Widget _serviceCard({
  required String service,
  required IconData icon,
  final Color? iconColor,
}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12.r),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.3),
          spreadRadius: 1,
          blurRadius: 5,
          offset: Offset(0, 3),
        ),
      ],
    ),
    padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 8.w),
    child: LayoutBuilder(
      builder: (context, constraints) {
        // scale icon and text according to available height
        final maxH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 160.h;
        final iconSize = min(64.sp, maxH * 0.38);
        final textStyle = TextStyle(
          fontSize: max(12.sp, maxH * 0.08),
          fontWeight: FontWeight.w600,
        );
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor ?? Colors.red, size: iconSize),
            SizedBox(height: 8.h),
            Flexible(
              child: Text(
                service,
                textAlign: TextAlign.center,
                style: textStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    ),
  );
}
