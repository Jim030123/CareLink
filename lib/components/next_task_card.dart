import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class NextTaskCard extends StatelessWidget {
  final String time;
  final String upcomingTitle;
  final String title;
  final String? subtitle;
  final IconData icon;
  final String? dosage;
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
    this.dosage,
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
         border: Border.all(color: Colors.orange.withOpacity(0.4), width: 2),
        gradient: const LinearGradient(
          colors: [Colors.orangeAccent, Colors.white, ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12.w),
        boxShadow: [
          BoxShadow(color: Colors.orange.withOpacity(0.25), blurRadius: 2),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// HEADER: title + time badge
          Row(
            children: [

               Icon(
                  icon,
                  color:Colors.white,
                  size: 28.w,
                ),

                SizedBox(width: 8.w),

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

              /// TEXT
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _titleText(),
                    SizedBox(height: 4.h),

                    if (dosage != null && dosage!.isNotEmpty)


                    if (subtitle?.isNotEmpty ?? false) _subtitleText(),

                    SizedBox(height: 8.h),

                    Text(
                      'Dosage Amount: $dosage',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15.sp, color: Colors.black87, fontWeight: FontWeight.bold),
                    ),

                    SizedBox(height: 12.h),


                    Text(
                      'Note: \n$dosage',

                      style: TextStyle(fontSize: 14.sp, color: Colors.black87),
                    ),





                    if (progress != null) _progressBar(),
                  ],
                ),
              ),
            ],
          ),
          Spacer(),

          // right-side info (e.g. date) shown above buttons
          // if (rightInfo.isNotEmpty)
          //   Align(
          //     alignment: Alignment.centerRight,
          //     child: Text(
          //       rightInfo,
          //       style: TextStyle(fontSize: 14.sp, color: Colors.black54),
          //     ),
          //   ),

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
                : (completed
                    ? Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, color: Colors.white, size: 18.r),
                            SizedBox(width: 6.w),
                            Text(
                              'Done',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    : TextButton(
                        onPressed: onMarkDone,
                        child: Text(
                          'Mark as Done',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.orange,
                          ),
                        ),
                      )),
          ),
        ],
      ),
    );
  }

  Widget _timeBadge() => Container(
    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      border: Border.all(color: Colors.orange, width: 2),
      borderRadius: BorderRadius.circular(6.w),
    ),
    child: Text(time, style: TextStyle(fontSize: 14.sp)),
  );

  Widget _titleText() => Text(
    title,
    maxLines: 5,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold),
  );

  Widget _subtitleText() => Padding(
    padding: EdgeInsets.only(top: 4.h),
    child: Row(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6.w),
              color: Colors.grey.shade100,
          ),

          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            child: Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.sp, color: Colors.black54),
            ),
          ),
        ),
      ],
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
