import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Small footer component showing the app logo, version and copyright/trademark.
class AppFooter extends StatelessWidget {
  final String version;
  final String copyrightText;
  final double logoSize;

  const AppFooter({
    Key? key,
    this.version = 'Alpha Testing V3.12',
    this.copyrightText = '© 2025 CareLink™ — All rights reserved',
    this.logoSize = 72,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/icons/logo.svg',
            width: logoSize.w,
            height: logoSize.w,
          ),
          SizedBox(height: 8.h),
          Text(
            version,
            style: TextStyle(fontSize: 12.sp, color: Colors.black54),
          ),
          SizedBox(height: 4.h),
          Text(
            copyrightText,
            style: TextStyle(fontSize: 11.sp, color: Colors.black45),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
