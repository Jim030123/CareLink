import 'package:carelink_mobile/components/page_appbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:table_calendar/table_calendar.dart';

class ShowAppointmentPage extends StatefulWidget {
  const ShowAppointmentPage({super.key});

  @override
  State<ShowAppointmentPage> createState() => _ShowAppointmentPageState();
}

class _ShowAppointmentPageState extends State<ShowAppointmentPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PageAppBar(
        title: 'Show Appointment',
        showBack: true,
        showSearch: true,
      ),

      body: LayoutBuilder(
        builder: (context, constraints) {
          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 5,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(12.w),
                      child: TableCalendar(
                        calendarFormat: CalendarFormat.month,
                        // hide the two-week option by only exposing Month and Week formats
                        availableCalendarFormats: const {
                          CalendarFormat.month: 'Month',
                          CalendarFormat.week: 'Week',
                        },
                        headerStyle: const HeaderStyle(
                          // Hide the format button (no toggle shown)
                          formatButtonVisible: false,
                          formatButtonShowsNext: false,
                          // Center month/year title between chevrons
                          titleCentered: true,
                          titleTextStyle: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        firstDay: DateTime.now(),
                        lastDay: DateTime.now().add(Duration(days: 365)),
                        focusedDay: DateTime.now(),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    // Example appointment card (matches provided design)
                    _buildAppointmentCard(
                      day: '10',
                      monthYear: '2025.07',
                      weekday: 'Sun',
                      title: 'Appointment',
                      time: '11:02 PM',
                      leftLabel: 'Dr Ng',
                      centerLabel: 'Follow-up Appointment',
                      rightLabel: 'Ng Ying Qi',
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppointmentCard({
    required String day,
    required String monthYear,
    required String weekday,
    required String title,
    required String time,
    required String leftLabel,
    required String centerLabel,
    required String rightLabel,
  }) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.orange.shade100),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left date column
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      monthYear,
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      day,
                      style: TextStyle(
                        fontSize: 25.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(weekday, style: TextStyle(fontSize: 10.sp)),
                    ),

                    // month/year and weekday moved here for compact layout
                  ],
                ),
              ),

              SizedBox(width: 12.w),
              // Center title
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Right time
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // thin dotted-like divider (approximation)
          Container(
            height: 1,
            margin: EdgeInsets.symmetric(vertical: 8.h),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.black12,
                  width: 1,
                  style: BorderStyle.solid,
                ),
              ),
            ),
          ),

          // bottom info row: left, center, right
          Row(
            children: [
              Expanded(
                child: Text(
                  leftLabel,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    centerLabel,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    rightLabel,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
