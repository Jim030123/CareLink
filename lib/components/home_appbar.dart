import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'auto_marquee_text.dart';

class HomeAppbar extends StatelessWidget implements PreferredSizeWidget {
  final List<bool> isSelected;
  final Function(int) onToggleChanged;
  final String userName;

  const HomeAppbar({
    super.key,
    required this.isSelected,
    required this.onToggleChanged,
    required this.userName,
  });

  @override
  Size get preferredSize => Size.fromHeight(90.h);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: Theme.of(context).appBarTheme.backgroundColor,
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
        child: Row(
          children: [
            // left: avatar + name
            Expanded(
              flex: 5,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20.r,
                    backgroundImage: const NetworkImage(
                      'https://i.pravatar.cc/150?img=3',
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
                            color: Colors.black,
                          ),
                        ),
                        Flexible(
                          child: AutoMarqueeText(
                            text: userName,
                            style: TextStyle(
                              fontSize: 17.sp,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // middle: toggle buttons
            Expanded(
              flex: 3,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ToggleButtons(
                    isSelected: isSelected,
                    onPressed: onToggleChanged,
                    constraints: BoxConstraints(
                      minWidth: 40.w,
                      minHeight: 40.h,
                    ),
                    borderRadius: BorderRadius.circular(8.r),
                    selectedColor: const Color(0xFFFCEEDB),
                    fillColor: Theme.of(context).colorScheme.primary,
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
                  ),
                ],
              ),
            ),

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
      ),
    );
  }
}
