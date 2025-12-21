import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

class HomeCalendar extends StatefulWidget {
  const HomeCalendar({super.key});

  @override
  State<HomeCalendar> createState() => _HomeCalendarState();
}

class _HomeCalendarState extends State<HomeCalendar> {
  final Map<DateTime, List<String>> _events = {
    DateTime.utc(2025, 10, 5): ['a'],
    DateTime.utc(2025, 10, 11): ['a'],
    DateTime.utc(2025, 10, 17): ['a', 'b'],
    DateTime.utc(2025, 10, 21): ['a'],
    DateTime.utc(2025, 10, 28): ['a'],
  };

  List<String> _getEventsForDay(DateTime day) {
    final key = DateTime.utc(day.year, day.month, day.day);
    return _events[key] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Container(
        margin: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          gradient:  LinearGradient(
            colors: [Color(0xFFFFF4EE), Color(0xFFFFE0CC)],
          ),
          border: Border.all(color: Colors.orange.withOpacity(0.25), width: 2),
          boxShadow: [
            BoxShadow(color: Colors.orange.withOpacity(0.25), blurRadius: 14),
          ],
        ),
        width: double.infinity,

        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TableCalendar(
              // 设置为 week view
              calendarFormat: CalendarFormat.week,
              availableCalendarFormats: const {CalendarFormat.week: 'Week'},
              startingDayOfWeek: StartingDayOfWeek.sunday,
              firstDay: DateTime.utc(2010, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              // 聚焦到今天
              focusedDay: DateTime.now(), //

              eventLoader: _getEventsForDay,
              // 调整行高/样式使周视图更紧凑
              daysOfWeekHeight: 24.h,
              rowHeight: 56.h,
              headerVisible: true,
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
                leftChevronIcon: Icon(Icons.chevron_left, size: 20.sp),
                rightChevronIcon: Icon(Icons.chevron_right, size: 20.sp),
              ),

              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  return Center(
                    child: Text(
                      '${day.day}',
                      style: TextStyle(fontSize: 14.sp, color: Colors.black),
                    ),
                  );
                },
                // 在每个单元格右下角绘制 marker（小方块或数字徽章）
                markerBuilder: (context, date, events) {
                  if (events.isEmpty) return const SizedBox.shrink();
                  if (events.length == 1) {
                    return Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        margin: EdgeInsets.only(bottom: 6.h, right: 6.w),
                        width: 10.w,
                        height: 10.h,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.circular(2.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 1,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    return Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        margin: EdgeInsets.only(bottom: 4.h, right: 4.w),
                        padding: EdgeInsets.symmetric(
                          horizontal: 4.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 1,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          '${events.length}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.sp,
                            height: 1,
                          ),
                        ),
                      ),
                    );
                  }
                },
              ),
            ),

            SizedBox(height: 5.h), // 👈 pushes the next container to the bottom

            Align(
              alignment: Alignment.bottomRight,
              child: TextButton(
                onPressed: () {
                  context.push('/showappointment');
                },
                child: Text('Show Appointment'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
