import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class HomeAiSummary extends StatefulWidget {
  const HomeAiSummary({super.key});

  @override
  State<HomeAiSummary> createState() => _HomeAiSummaryState();
}

class _HomeAiSummaryState extends State<HomeAiSummary> {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.smart_toy,
              size: 24.sp,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: 5.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Summary - ${DateTime.now().toLocal().toString().split(' ')[0]}',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5.h),
                  Container(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 12.h,
                      ),
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Scrollbar(
                        child: SingleChildScrollView(
                          child: Text(
                            'Tan Mei Hua with all vitals are stable with no alerts. Medication taken on time and sleep was sufficient, low fall risk, 15-minute outdoor walk is recommended tomorrow.',
                            style: TextStyle(fontSize: 15.sp),
                            textAlign: TextAlign.justify,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
