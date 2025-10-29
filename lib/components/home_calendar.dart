import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:table_calendar/table_calendar.dart';

class HomeCalendar extends StatefulWidget {
  const HomeCalendar({super.key});

  @override
  State<HomeCalendar> createState() => _HomeCalendarState();
}

class _HomeCalendarState extends State<HomeCalendar> {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        width: double.infinity,
        color: Theme.of(context).colorScheme.onSecondary,
        
        child: TableCalendar(
          calendarFormat: CalendarFormat.week, // this want let user choose
          firstDay: DateTime.utc(2010, 10, 16),
          lastDay: DateTime.utc(2030, 3, 14),
          selectedDayPredicate: (day) =>
              isSameDay(day, DateTime.now().add(const Duration(days: 2))),
          focusedDay: DateTime.now(),
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.rectangle,
            ),
            selectedDecoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle, // selected sample
            ),
          ),
        ),
      
      ),
    );
  }
}
