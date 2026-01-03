import 'package:carelink_mobile/components/status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:table_calendar/table_calendar.dart';

class MedicationSchedule extends StatefulWidget {
  const MedicationSchedule({super.key});

  @override
  MedicationScheduleState createState() => MedicationScheduleState();
}

class MedicationScheduleState extends State<MedicationSchedule> {
  DateTime _selectedScheduleDate = DateTime.now();
  final List<Map<String, dynamic>> _schedules = <Map<String, dynamic>>[];

  Widget _buildCalendar() {
    return Container(
      padding: EdgeInsets.all(16.w),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Schedule',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8.h),
          TableCalendar(
            firstDay: DateTime.now().subtract(const Duration(days: 365)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _selectedScheduleDate,
            selectedDayPredicate: (day) => isSameDay(day, _selectedScheduleDate),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedScheduleDate = selectedDay;
              });
            },
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            calendarStyle: const CalendarStyle(outsideDaysVisible: false),
          ),
          SizedBox(height: 8.h),
          Text(
            'Selected: ${_selectedScheduleDate.toLocal().toString().split(' ').first}',
            style: TextStyle(fontSize: 14.sp, color: Colors.black54),
          ),
          SizedBox(height: 12.h),
          const StatusCard(),
        ],
      ),
    );
  }

  Widget _buildSchedule() {
    final daySchedules = _schedules.where((s) {
      final d = s['date'] as DateTime;
      return d.year == _selectedScheduleDate.year &&
          d.month == _selectedScheduleDate.month &&
          d.day == _selectedScheduleDate.day;
    }).toList();

    if (daySchedules.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 24.h),
        child: Center(
          child: Text(
            'No scheduled medications for selected date',
            style: TextStyle(fontSize: 14.sp, color: Colors.black54),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8.h),
          child: Text(
            'Upcoming',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
          ),
        ),
        ...daySchedules.map((s) {
          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: s['color'] as Color? ?? const Color(0xFFF7EAD3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.medical_services, size: 20.w, color: Colors.white),
                  SizedBox(width: 12.w),
                  Expanded(child: Text(s['name'] as String)),
                  Text(
                    '${s['time'] ?? ''}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> showAddScheduleSheet() async {
    final nameCtrl = TextEditingController();
    TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 0);

    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setModalState) {
            DateTime localDate = _selectedScheduleDate;
            TimeOfDay localTime = selectedTime;

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx2).viewInsets.bottom),
              child: SingleChildScrollView(
                child: Container(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40.w,
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Text('Add Schedule', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
                      SizedBox(height: 12.h),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Medication name'),
                        autofocus: true,
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(child: Text('Date: ${localDate.toLocal().toString().split(' ').first}')),
                          TextButton(
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: ctx2,
                                initialDate: localDate,
                                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (d != null) setModalState(() => localDate = d);
                            },
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(child: Text('Time: ${localTime.format(ctx2)}')),
                          TextButton(
                            onPressed: () async {
                              final t = await showTimePicker(context: ctx2, initialTime: localTime);
                              if (t != null) setModalState(() => localTime = t);
                            },
                            child: const Text('Pick'),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      ElevatedButton(
                        onPressed: () {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;
                          final entry = {
                            'name': name,
                            'date': localDate,
                            'time': localTime.format(ctx2),
                            'color': const Color(0xFFB3E5FC),
                          };
                          Navigator.of(ctx2).pop(entry);
                        },
                        child: const Text('Save'),
                      ),
                      SizedBox(height: 12.h),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      setState(() => _schedules.add(result));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCalendar(),
        SizedBox(height: 12.h),
        _buildSchedule(),
      ],
    );
  }
}
