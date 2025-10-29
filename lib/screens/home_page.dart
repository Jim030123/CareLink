import 'package:carelink_mobile/components/home_appbar.dart';
import 'package:carelink_mobile/components/home_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:table_calendar/table_calendar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<bool> _isSelected = [true, false];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HomeAppbar(
        isSelected: _isSelected,
        userName: 'This is a very long name that will scroll automatically',
        onToggleChanged: (index) {
          setState(() {
            for (var i = 0; i < _isSelected.length; i++) {
              _isSelected[i] = i == index;
            }
          });
        },
      ),

      body: Column(
        children: [
          // HomeCalendar(
          //   events: {
          //     DateTime.now(): ['Event 1', 'Event 2'],
          //     DateTime.now().add(const Duration(days: 1)): ['Event 3'],
          //   },
          //   onDaySelected: (day) {
          //     // Handle day selection
          //     print('Selected day: $day');
          //   },
          // ),
          SizedBox(
            child: TableCalendar(
              calendarFormat: CalendarFormat.week, // this want let user choose
              firstDay: DateTime.utc(2010, 10, 16),
              lastDay: DateTime.utc(2030, 3, 14),
              selectedDayPredicate: (day) => isSameDay(day, DateTime.now().add(const Duration(days: 2))),
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

          SizedBox(height: 10.h,),

          Center(
            child: Text(
              _isSelected[0] ? 'Calendar Icon' : 'Assistant Icon',
              style: TextStyle(fontSize: 20.sp),
            ),
          ),

          // Fixed colors so text is visible (white background -> black text)
          //calendar
        ],
      ),
    );
  }
}
