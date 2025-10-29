import 'package:carelink_mobile/components/home_ai_summary.dart';
import 'package:carelink_mobile/components/home_appbar.dart';
import 'package:carelink_mobile/components/home_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:table_calendar/table_calendar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<bool> _isSelected = [true, false];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HomeAppbar(
        isSelected: _isSelected,
        userName: 'This is a veryname that will scroll automatically',
        onToggleChanged: (index) {
          setState(() {
            for (var i = 0; i < _isSelected.length; i++) {
              _isSelected[i] = i == index;
            }
          });
        },
      ),

      body: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w),
        child: Column(
          children: [
            if (_isSelected[0])
              SizedBox(
                height: 200.h, // 固定高度，响应屏幕尺寸
                child: HomeCalendar(),
              )
            else if (_isSelected[1])
              SizedBox(
                height: 200.h, // 也可以给其他组件固定高度
                child: HomeAiSummary(),
              ),

            SizedBox(height: 10.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  'Services',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.start,
                ),
              ],
            ),

            // Fixed colors so text is visible (white background -> black text)
            //calendar
          ],
        ),
      ),
    );
  }
}
