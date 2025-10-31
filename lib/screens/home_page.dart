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
      // appBar: HomeAppbar(userName: 'This is a very long name that will scroll automatically'),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 172, 151, 93),
        //size
        toolbarHeight: 50.h,
        title: HomeAppbar(
          userName: 'This is a very long name that will scroll automatically',
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280.h,

            floating: true,
            pinned: false,
            snap: false,
            title: Text(
              'Calendar',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    offset: Offset(2.0, 2.0), // 阴影位移 (x, y)
                    blurRadius: 10.0, // 模糊程度
                    color: Colors.black54, // 阴影颜色
                  ),
                ],
              ),
            ),
            flexibleSpace: ClipRRect(
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(24.r),
              ),
              child: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,

                background:
                    // Make the background image semi-transparent
                    Stack(
                      fit: StackFit.expand,
                      children: [
                        // 背景图片放在最底层
                        Image.asset(
                          'assets/images/home.jpg',
                          fit: BoxFit.cover,
                        ),
                        // 半透明遮罩，调整颜色/透明度以获得需要的视觉效果
                        Container(color: Colors.black.withOpacity(0.25)),

                        Positioned(
                          left: 16.w,
                          right: 16.w,
                          bottom: 16.h,
                          child: SizedBox(height: 210.h, child: HomeCalendar()),
                        ),
                      ],
                    ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(24.r),
              ),
              child: SizedBox(
                height: 280.h,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset('assets/images/home.jpg', fit: BoxFit.cover),
                    Container(color: Colors.black.withOpacity(0.25)),
                    Positioned(
                      left: 16.w,
                      right: 16.w,
                      bottom: 16.h,
                      child: SizedBox(height: 210.h, child: HomeCalendar()),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Add your widgets here
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

          SliverFillRemaining(),
        ],
      ),

      //      HomeAppbar(
      //       isSelected: _isSelected,
      //       userName: 'This is a veryname that will scroll automatically',
      //       onToggleChanged: (index) {
      //         setState(() {
      //           for (var i = 0; i < _isSelected.length; i++) {
      //             _isSelected[i] = i == index;
      //           }
      //         });
      //       },
      //     ),

      //  SafeArea(
      //     child: SingleChildScrollView(
      //       child: Container(
      //         padding: EdgeInsets.symmetric(horizontal: 10.w),
      //         child: Column(
      //           children: [
      //             if (_isSelected[0])
      //               SizedBox(
      //                 height: 210.h, // 固定高度，响应屏幕尺寸
      //                 child: HomeCalendar(),
      //               )
      //             else if (_isSelected[1])
      //               SizedBox(
      //                 height: 210.h, // 也可以给其他组件固定高度
      //                 child: HomeAiSummary(),
      //               ),

      //             SizedBox(height: 10.h),
      //             Align(
      //               alignment: Alignment.topLeft,
      //               child: Text(
      //                 'Services',
      //                 style: TextStyle(
      //                   fontSize: 25.sp,
      //                   shadows: [
      //                     Shadow(
      //                       offset: Offset(2.0, 2.0), // 阴影位移 (x, y)
      //                       blurRadius: 10.0, // 模糊程度
      //                       color: Colors.black54, // 阴影颜色
      //                     ),
      //                   ],
      //                   fontWeight: FontWeight.bold,
      //                 ),
      //                 textAlign: TextAlign.start,
      //               ),
      //             ),

      //             SizedBox(
      //               height: 200.h,
      //               child: GridView.count(
      //                 crossAxisCount: 2,
      //                 children: List.generate(6, (index) {
      //                   return Container(
      //                     margin: const EdgeInsets.all(8),
      //                     color: Colors.blueAccent,
      //                     child: Center(
      //                       child: Text(
      //                         'Item $index',
      //                         style: const TextStyle(color: Colors.white),
      //                       ),
      //                     ),
      //                   );
      //                 }),
      //               ),
      //             ),

      //           ],
      //         ),
      //       ),
      //     ),
      //   ),
    );
  }
}
