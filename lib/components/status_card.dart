import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// A small card that shows statuses such as Active / Inactive.
class StatusCard extends StatelessWidget {
    const StatusCard({Key? key}) : super(key: key);

    @override
    Widget build(BuildContext context) {
        return Align(
            alignment: Alignment.centerRight,
            child: Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: const [
                        BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                        ),
                    ],
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Text(
                            'Status',
                            style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                            ),
                        ),
                        SizedBox(height: 12.h),
                        const _StatusRow(
                            label: 'Active',
                            color: Color(0xFFF8D8D8),
                        ),
                        SizedBox(height: 8.h),
                        const _StatusRow(
                            label: 'Inactive',
                            color: Color(0xFFF7EAD3),
                        ),
                    ],
                ),
            ),
        );
    }
}

class _StatusRow extends StatelessWidget {
    final String label;
    final Color color;

    const _StatusRow({Key? key, required this.label, required this.color})
            : super(key: key);

    @override
    Widget build(BuildContext context) {
        return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
                Container(
                    width: 12.w,
                    height: 12.w,
                    decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3.r),
                        border: Border.all(color: Colors.black12, width: 0.5),
                    ),
                ),
                SizedBox(width: 8.w),
                Text(
                    label,
                    style: TextStyle(
                        fontSize: 12.sp,
                    ),
                ),
            ],
        );
    }
}
