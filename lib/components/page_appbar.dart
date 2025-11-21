import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Reusable page app bar used across pages.
///
/// Usage:
/// `appBar: PageAppBar(title: 'Medicine Reminder', showBack: true, showSearch: true)`
class PageAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBack;
  final bool showSearch;
  final VoidCallback? onSearch;
  final Widget? logo; // optional custom logo widget
  final double height;

  const PageAppBar({
    Key? key,
    required this.title,
    this.showBack = false,
    this.showSearch = false,
    this.onSearch,
    this.logo,
    this.height = 68,
  }) : super(key: key);

  @override
  Size get preferredSize => Size.fromHeight(height.h + ScreenUtil().statusBarHeight);

  @override
  Widget build(BuildContext context) {


    final search = showSearch
        ? IconButton(
            icon: Icon(Icons.search, size: 22.w, color: Colors.black87),
            onPressed: onSearch ?? () {},
          )
        : SizedBox(width: 48.w);

    final logoWidget = logo ??
        Padding(
          padding: EdgeInsets.only(right: 6.w),
          child: SvgPicture.asset(
            'assets/icons/logo.svg',
            width: 32.w,
            height: 32.h,
          ),
        );

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          height: height.h,
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: Row(
            children: [


              // logo
              logoWidget,

              // Title centered; allow wrapping to two lines
              Expanded(
                child: Center(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // trailing action
              search,
            ],
          ),
        ),
      ),
    );
  }
}
