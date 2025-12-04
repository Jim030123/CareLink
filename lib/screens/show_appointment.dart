import 'package:carelink_mobile/components/page_appbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class Appointment {
  final DateTime date;
  final String title;
  final String time;
  final String leftLabel;
  final String centerLabel;
  final String rightLabel;

  Appointment({
    required this.date,
    required this.title,
    required this.time,
    required this.leftLabel,
    required this.centerLabel,
    required this.rightLabel,
  });
}

class ShowAppointmentPage extends StatefulWidget {
  const ShowAppointmentPage({super.key});

  @override
  State<ShowAppointmentPage> createState() => _ShowAppointmentPageState();
}

class _ShowAppointmentPageState extends State<ShowAppointmentPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late List<Appointment> _appointments;
  bool _showInlineSearch = false;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';
  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    // sample appointments; in real app this would come from backend
    _appointments = [

        Appointment(
        date: DateTime.now().subtract(Duration(days: 2)),
        title: 'Medication Review',
        time: '09:30 AM',
        leftLabel: 'Dr Lim',
        centerLabel: 'Medication Review',
        rightLabel: 'John Doe',
      ),
      Appointment(
        date: DateTime.now().subtract(Duration(days: 10)),
        title: 'Follow-up Appointment',
        time: '11:02 PM',
        leftLabel: 'Dr Ng',
        centerLabel: 'Follow-up Appointment',
        rightLabel: 'Ng Ying Qi',
      ),
      Appointment(
        date: DateTime.now().add(Duration(days: 2)),
        title: 'Medication Review',
        time: '09:30 AM',
        leftLabel: 'Dr Lim',
        centerLabel: 'Medication Review',
        rightLabel: 'John Doe',
      ),

       Appointment(
        date: DateTime.now().add(Duration(days: 2)),
        title: 'Medication Review',
        time: '09:30 AM',
        leftLabel: 'Dr Lim',
        centerLabel: 'Medication Review',
        rightLabel: 'John Doe',
      ),
    ];
  }
  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageAppBar(
        title: 'Show Appointment',
        showBack: true,
        showSearch: true,
        onSearch: _toggleInlineSearch,
      ),

      body: LayoutBuilder(
        builder: (context, constraints) {
          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  children: [
                    // Inline search field (appears when search icon pressed)
                    if (_showInlineSearch)
                      Padding(
                        padding: EdgeInsets.only(bottom: 12.h),
                        child: TextField(
                          controller: _searchCtrl,
                          focusNode: _searchFocus,
                          decoration: InputDecoration(
                            hintText: 'Search appointments (title, doctor, name)',
                            prefixIcon: Icon(Icons.search),
                            suffixIcon: IconButton(
                              icon: Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  _showInlineSearch = false;
                                  _searchQuery = '';
                                  _searchCtrl.clear();
                                });
                              },
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                          ),
                          onChanged: (v) => setState(() {
                            _searchQuery = v.trim();
                            if (_searchQuery.isNotEmpty) _selectedDay = null;
                          }),
                          onSubmitted: (v) => setState(() {
                            _searchQuery = v.trim();
                            if (_searchQuery.isNotEmpty) _selectedDay = null;
                          }),
                        ),
                      ),
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
                        firstDay: DateTime.now().subtract(Duration(days: 365)),
                        lastDay: DateTime.now().add(Duration(days: 365)),
                        focusedDay: _focusedDay,
                        calendarStyle: CalendarStyle(
                          // Don't separately highlight today; only use the selected
                          // decoration so previous days are cleared when a new
                          // day is selected.
                          todayDecoration: BoxDecoration(),
                          todayTextStyle: TextStyle(color: Colors.black87),
                          selectedDecoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            shape: BoxShape.circle,
                          ),
                          selectedTextStyle: TextStyle(color: Colors.black),
                        ),
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, date, events) {
                            if (_searchQuery.isEmpty) return const SizedBox.shrink();
                            final q = _searchQuery.toLowerCase();
                            final hasMatch = _appointments.any((a) =>
                                isSameDay(a.date, date) &&
                                (a.title.toLowerCase().contains(q) ||
                                    a.leftLabel.toLowerCase().contains(q) ||
                                    a.centerLabel.toLowerCase().contains(q) ||
                                    a.rightLabel.toLowerCase().contains(q)));
                            if (!hasMatch) return const SizedBox.shrink();

                            return Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                margin: EdgeInsets.only(bottom: 6.h),
                                width: 8.w,
                                height: 8.w,
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            );
                          },
                        ),
                        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                        onDaySelected: (selectedDay, focusedDay) {
                          // while inline search is active, prevent selecting a day
                          if (_showInlineSearch || _searchQuery.isNotEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Exit search to select a date')),
                            );
                            return;
                          }

                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                          });

                          final formatted = DateFormat('EEE, dd MMM yyyy').format(selectedDay);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Selected date: $formatted')),
                          );
                        },
                        onPageChanged: (focusedDay) {
                          // update focused day when user navigates calendar pages
                          _focusedDay = focusedDay;
                        },
                      ),
                    ),
                    SizedBox(height: 12.h),
                    // Appointments: if inline search query is present, show
                    // matches across all appointments grouped into Upcoming
                    // and Past. Otherwise show appointments for the selected day.
                    Builder(builder: (context) {
                      if (_searchQuery.isNotEmpty) {
                        final q = _searchQuery.toLowerCase();
                        final matches = _appointments.where((a) {
                          return a.title.toLowerCase().contains(q) ||
                              a.leftLabel.toLowerCase().contains(q) ||
                              a.centerLabel.toLowerCase().contains(q) ||
                              a.rightLabel.toLowerCase().contains(q);
                        }).toList();

                        if (matches.isEmpty) {
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.h),
                            child: Card(
                              child: Padding(
                                padding: EdgeInsets.all(12.w),
                                child: Text('No appointments match "$_searchQuery"'),
                              ),
                            ),
                          );
                        }

                        final today = DateTime.now();
                        final upcoming = matches.where((a) => !a.date.isBefore(DateTime(today.year, today.month, today.day))).toList();
                        final past = matches.where((a) => a.date.isBefore(DateTime(today.year, today.month, today.day))).toList();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (upcoming.isNotEmpty) ...[
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.h),
                                child: Text('Upcoming (${upcoming.length})', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
                              ),
                              ...upcoming.map((a) {
                                final day = a.date.day.toString().padLeft(2, '0');
                                final monthYear = '${a.date.year.toString()}.${a.date.month.toString().padLeft(2, '0')}';
                                final weekday = DateFormat('EEE').format(a.date);
                                return _buildAppointmentCard(
                                  day: day,
                                  monthYear: monthYear,
                                  weekday: weekday,
                                  title: a.title,
                                  time: a.time,
                                  leftLabel: a.leftLabel,
                                  centerLabel: a.centerLabel,
                                  rightLabel: a.rightLabel,
                                );
                              }),
                            ],
                            if (past.isNotEmpty) ...[
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.h),
                                child: Text('Past (${past.length})', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
                              ),
                              ...past.map((a) {
                                final day = a.date.day.toString().padLeft(2, '0');
                                final monthYear = '${a.date.year.toString()}.${a.date.month.toString().padLeft(2, '0')}';
                                final weekday = DateFormat('EEE').format(a.date);
                                return _buildAppointmentCard(
                                  day: day,
                                  monthYear: monthYear,
                                  weekday: weekday,
                                  title: a.title,
                                  time: a.time,
                                  leftLabel: a.leftLabel,
                                  centerLabel: a.centerLabel,
                                  rightLabel: a.rightLabel,
                                );
                              }),
                            ],
                          ],
                        );
                      }

                      // No inline query: show only selected day's appointments
                      final selected = _selectedDay ?? _focusedDay;
                      final todays = _appointments.where((a) => isSameDay(a.date, selected)).toList();
                      if (todays.isEmpty) {
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          child: Card(
                            child: Padding(
                              padding: EdgeInsets.all(12.w),
                              child: Text('No appointments on ${DateFormat('EEE, dd MMM yyyy').format(selected)}'),
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: todays.map((a) {
                          final day = a.date.day.toString().padLeft(2, '0');
                          final monthYear = '${a.date.year.toString()}.${a.date.month.toString().padLeft(2, '0')}';
                          final weekday = DateFormat('EEE').format(a.date);
                          return _buildAppointmentCard(
                            day: day,
                            monthYear: monthYear,
                            weekday: weekday,
                            title: a.title,
                            time: a.time,
                            leftLabel: a.leftLabel,
                            centerLabel: a.centerLabel,
                            rightLabel: a.rightLabel,
                          );
                        }).toList(),
                      );
                    }),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }


  void _toggleInlineSearch() {
    setState(() {
      _showInlineSearch = !_showInlineSearch;
      if (_showInlineSearch) {
        // when entering search mode, clear selected day so calendar appears inactive
        _selectedDay = null;
      } else {
        _searchQuery = '';
        _searchCtrl.clear();
      }
    });

    if (_showInlineSearch) {
      // focus after frame so keyboard opens
      WidgetsBinding.instance.addPostFrameCallback((_) => _searchFocus.requestFocus());
    }
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
