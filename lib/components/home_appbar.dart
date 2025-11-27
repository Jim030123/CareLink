import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'auto_marquee_text.dart';

class HomeAppbar extends StatelessWidget implements PreferredSizeWidget {
  final String userName;

  const HomeAppbar({super.key, required this.userName});

  @override
  Size get preferredSize => Size.fromHeight(90.h);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          // left: avatar + name
          Expanded(
            flex: 5,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    // navigate to profile page
                    context.push('/profile');
                  },
                  child: CircleAvatar(
                    radius: 20.r,
                    backgroundImage: const NetworkImage(
                      'https://i.pravatar.cc/150?img=3',
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Welcome Back',
                        overflow: TextOverflow.ellipsis,
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
                      // 不再使用 Flexible（会请求无限高度），改为固定高度的 SizedBox
                      AutoMarqueeText(
                        text: userName,
                        style: TextStyle(
                          fontSize: 15.sp,
                          color: Colors.black87,
                          shadows: [
                            Shadow(
                              offset: Offset(2.0, 2.0), // 阴影位移 (x, y)
                              blurRadius: 10.0, // 模糊程度
                              color: Colors.black54, // 阴影颜色
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // middle: toggle buttons

          // right: logo
          Flexible(
            flex: 1,
            child: Align(
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown, // 比 cover 更安全
                child: SvgPicture.asset(
                  'assets/icons/logo.svg',
                  width: 60.w,
                  height: 60.h,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeAppBarToggleButton extends StatefulWidget {
  final List<bool> isSelected;
  final ValueChanged<int> onToggleChanged;

  const HomeAppBarToggleButton({
    super.key,
    required this.isSelected,
    required this.onToggleChanged,
  });

  @override
  State<HomeAppBarToggleButton> createState() => _HomeAppBarStateToggleButton();
}

class _HomeAppBarStateToggleButton extends State<HomeAppBarToggleButton> {
  @override
  Widget build(BuildContext context) {
    return ToggleButtons(
      isSelected: widget.isSelected,
      onPressed: widget.onToggleChanged,
      constraints: BoxConstraints(minWidth: 40.w, minHeight: 40.h),
      borderRadius: BorderRadius.circular(8.r),
      selectedColor: const Color(0xFFFCEEDB),
      fillColor: Colors.green,
      color: Colors.black87,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w),
          child: Icon(Icons.calendar_month, size: 18.sp),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w),
          child: Icon(Icons.assistant, size: 18.sp),
        ),
      ],
    );
  }
}
