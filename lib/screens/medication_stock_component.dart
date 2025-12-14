 import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';



  final List<Map<String, dynamic>> insufficient = [];
    final List<Map<String, dynamic>> sufficient = [];

Widget buildCompactStatus(List<Map<String, dynamic>> items) {
    final total = items.length;
    final insufficient = items.where((it) {
      final leftVal = (it['packageQuantity'] ?? '').toString();
      final leftNum = int.tryParse(leftVal) ?? 0;
      return leftNum < 10;
    }).length;

    final color = insufficient > 0 ? Colors.redAccent : Colors.green;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12.w),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            insufficient > 0 ? Icons.error_outline : Icons.check_circle_outline,
            size: 14.w,
            color: Colors.white,
          ),
          SizedBox(width: 6.w),
          Text(
            insufficient > 0
                ? '$insufficient Insufficient'
                : 'Sufficient Medication',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
