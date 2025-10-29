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
        width: double.infinity,
        color: Theme.of(context).colorScheme.onSecondary,
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),

        child: ExpansionTile(
          collapsedBackgroundColor: Theme.of(context).colorScheme.surface,
          title: Row(
            children: [
              Icon(Icons.smart_toy, size: 24.sp, color: Theme.of(context).colorScheme.primary),
              SizedBox(width: 5.w),
              Text(
                'AI Summary - ${DateTime.now().toLocal().toString().split(' ')[0]}',
                style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          
          children: [
            Container( 
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                child: Text(
                  'Tan Mei Hua with all vitals are stable with no alerts Medication taken on time and sleep was sufficient, low fall risk, 15-minute outdoor walk is recommended tomorrow',
                  style: TextStyle(fontSize: 15.sp),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
