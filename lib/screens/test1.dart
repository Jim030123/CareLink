import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class TestPage2 extends StatefulWidget {
  const TestPage2({super.key});

  @override
  State<TestPage2> createState() => _TestPage2State();
}

class _TestPage2State extends State<TestPage2> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: TableCalendar(
  firstDay: DateTime.utc(2024, 1, 1),
  lastDay: DateTime.utc(2026, 12, 31),
  focusedDay: DateTime.now(),

  calendarFormat: CalendarFormat.month,

  // 👇 核心：disable 每个星期一
  enabledDayPredicate: (day) {
    // weekday: 1 = Monday
    return day.weekday != DateTime.thursday;
  },

  onDaySelected: (selectedDay, focusedDay) {
    // 只有 enabled 的日期才会触发
    debugPrint('Selected: $selectedDay');
  },

  calendarStyle: CalendarStyle(
    // disable 的日期样式：使用 theme 的 disabledColor，去掉删除线
    disabledTextStyle: TextStyle(
      color: Colors.red,
    ),
  ),
)
));
  }
}