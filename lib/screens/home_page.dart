import 'package:carelink_mobile/components/home_ai_summary.dart';
import 'package:carelink_mobile/components/home_appbar.dart';
import 'package:carelink_mobile/components/home_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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

      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            child: Column(
              children: [
                if (_isSelected[0])
                  SizedBox(
                    height: 210.h, // 固定高度，响应屏幕尺寸
                    child: HomeCalendar(),
                  )
                else if (_isSelected[1])
                  SizedBox(
                    height: 210.h, // 也可以给其他组件固定高度
                    child: HomeAiSummary(),
                  ),

                SizedBox(height: 10.h),
                Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    'Services',
                    style: TextStyle(
                      fontSize: 25.sp,
                      shadows: [
                        Shadow(
                          offset: Offset(2.0, 2.0), // 阴影位移 (x, y)
                          blurRadius: 10.0, // 模糊程度
                          color: Colors.black54, // 阴影颜色
                        ),
                      ],
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.start,
                  ),
                ),

                SizedBox(
                  height: 200.h,
                  child: GridView.count(
                    crossAxisCount: 2,
                    children: List.generate(6, (index) {
                      return Container(
                        margin: const EdgeInsets.all(8),
                        color: Colors.blueAccent,
                        child: Center(
                          child: Text(
                            'Item $index',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

              
              ],
            ),
          ),
        ),
      ),
    );
  }
}
