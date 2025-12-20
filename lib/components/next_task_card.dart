import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class NextTaskCard extends StatelessWidget {
  final String time;
  final String upcomingTitle;
  final String title;
  final String? subtitle;
  final IconData icon;
  final String rightInfo;
  final VoidCallback? onMarkDone;
  final VoidCallback? onCancel;
  final double? progress;
  final bool completed;
  final bool pending;

  const NextTaskCard({
    super.key,
    required this.time,
    required this.upcomingTitle,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.rightInfo,
    this.onMarkDone,
    this.progress,
    this.completed = false,
    this.pending = false,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: completed
              ? [Colors.green.shade300, Colors.green.shade600]
              : pending
              ? [Colors.orange.shade100, Colors.yellow.shade300]
              : [Colors.orange.shade300, Colors.yellow.shade600],
        ),
        borderRadius: BorderRadius.circular(14.w),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [
          BoxShadow(color: Colors.yellow, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// HEADER: title + time badge
          Row(
            children: [
              Expanded(
                child: Text(
                  upcomingTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(width: 8.w),
              _timeBadge(),
            ],
          ),

          SizedBox(height: 6.h),

          /// MAIN ROW
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// ICON
              Container(
                width: 54.w,
                height: 54.w,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.w),
                ),
                child: Icon(
                  icon,
                  color: completed
                      ? Colors.green.shade600
                      : (pending
                            ? Colors.orange.shade100
                            : Colors.orange.shade300),
                  size: 28.w,
                ),
              ),

              SizedBox(width: 12.w),

              /// TEXT
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _titleText(),
                    if (subtitle?.isNotEmpty ?? false) _subtitleText(),
                    if (progress != null) _progressBar(),
                  ],
                ),
              ),
            ],
          ),
          Spacer(),

          // right-side info (e.g. date) shown above buttons
          if (rightInfo.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                rightInfo,
                style: TextStyle(fontSize: 12.sp, color: Colors.black54),
              ),
            ),

          SizedBox(height: 6.h),

          /// BUTTON BELOW ROW ✅
          Align(
            alignment: Alignment.centerRight,
            child: pending
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: onCancel,
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                      SizedBox(width: 6.w),
                      TextButton(
                        onPressed: null,
                        child: Text(
                          'Pending...',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.orange.shade300,
                          ),
                        ),
                      ),
                    ],
                  )
                : TextButton(
                    onPressed: completed ? null : onMarkDone,
                    child: Text(
                      completed ? 'Done' : 'Mark Done',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: completed ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _timeBadge() => Container(
    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(6.w),
    ),
    child: Text(time, style: TextStyle(fontSize: 12.sp)),
  );

  Widget _titleText() => Text(
    title,
    maxLines: 5,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
  );

  Widget _subtitleText() => Padding(
    padding: EdgeInsets.only(top: 4.h),
    child: Text(
      subtitle!,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 13.sp, color: Colors.black54),
    ),
  );

  Widget _progressBar() => Padding(
    padding: EdgeInsets.only(top: 6.h),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(6.w),
      child: LinearProgressIndicator(
        minHeight: 6.h,
        value: progress,
        backgroundColor: Colors.grey.shade200,
        valueColor: AlwaysStoppedAnimation(
          completed ? Colors.green : Colors.orange,
        ),
      ),
    ),
  );
}
