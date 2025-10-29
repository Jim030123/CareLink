// lib/components/home_calendar.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class HomeCalendar extends StatefulWidget {
  final Map<DateTime, List<String>>? events;
  final void Function(DateTime)? onDaySelected;

  const HomeCalendar({
    Key? key,
    this.events,
    this.onDaySelected,
  }) : super(key: key);

  @override
  State<HomeCalendar> createState() => _HomeCalendarState();
}

class _HomeCalendarState extends State<HomeCalendar> {
  late final Map<DateTime, List<String>> _events;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    // Normalize event keys to be date-only (no time component)
    _events = {};
    if (widget.events != null) {
      for (var entry in widget.events!.entries) {
        final key = DateTime(entry.key.year, entry.key.month, entry.key.day);
        _events[key] = entry.value;
      }
    }
  }

  List<String> _getEventsForDay(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return _events[d] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
      _focusedDay = focusedDay;
    });
    if (widget.onDaySelected != null) widget.onDaySelected!(selectedDay);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TableCalendar<String>(
          firstDay: DateTime.utc(2000, 1, 1),
          lastDay: DateTime.utc(2100, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          selectedDayPredicate: (day) {
            if (_selectedDay == null) return false;
            return isSameDay(_selectedDay, day);
          },
          eventLoader: _getEventsForDay,
          startingDayOfWeek: StartingDayOfWeek.monday,
          headerStyle: const HeaderStyle(
            formatButtonVisible: true,
            titleCentered: true,
          ),
          calendarStyle: CalendarStyle(
            markerDecoration: BoxDecoration(
              color: Colors.blueAccent,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: Colors.orangeAccent,
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
          ),
          onDaySelected: _onDaySelected,
          onFormatChanged: (format) {
            setState(() {
              _calendarFormat = format;
            });
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _buildEventList(),
        ),
      ],
    );
  }

  Widget _buildEventList() {
    final events = _selectedDay != null ? _getEventsForDay(_selectedDay!) : [];
    if (events.isEmpty) {
      return const Center(
        child: Text('No events'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: events.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final e = events[index];
        return ListTile(
          title: Text(e),
          leading: const Icon(Icons.event_note),
        );
      },
    );
  }
}