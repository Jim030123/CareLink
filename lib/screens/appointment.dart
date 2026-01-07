import 'package:carelink_mobile/components/page_appbar.dart';
import 'package:carelink_mobile/screens/manage_care_reciepient.dart.dart';
import 'package:carelink_mobile/utils/graphql_service.dart';
import 'package:carelink_mobile/utils/day_convert.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

class AddAppointmentPage extends StatefulWidget {
  final String? doctorId;

  const AddAppointmentPage({super.key, this.doctorId});

  @override
  State<AddAppointmentPage> createState() => _AddAppointmentPageState();
}

class _AddAppointmentPageState extends State<AddAppointmentPage> {
  Map<String, String>? _selectedRecipient;
  DateTime? _selectedDate;
  // Selected slots keyed by date string 'yyyy-MM-dd' -> list of hours
  final Map<String, List<int>> _selectedSlots = {};
  // availability slots fetched from server: weekday (1=Mon..7=Sun) -> set of available hours
  final Map<int, Set<int>> _availabilitiesByDay = {};

  static const String _fetchCareRecipientsQuery = r'''
query CareRecipients {
  care_recipient {
    id
    firstName
    lastName
    phone
  }
}
''';

  Future<List<Map<String, String>>> fetchCareRecipients() async {
    try {
      final client = createClient();
      final options = QueryOptions(document: gql(_fetchCareRecipientsQuery));
      final res = await client.query(options);
      if (res.hasException) return [];
      final list =
          (res.data?['care_recipient'] as List<dynamic>?)?.map((e) {
            final first = (e['firstName'] ?? '') as String;
            final last = (e['lastName'] ?? '') as String;
            return {
              'id': e['id']?.toString() ?? '',
              'name': ('$first $last').trim(),
            };
          }).toList() ??
          [];
      return List<Map<String, String>>.from(list);
    } catch (e) {
      debugPrint('fetchCareRecipients exception: $e');
      return [];
    }
  }

  @override
  void initState() {
    super.initState();
    // fetch doctor availabilities if doctorId provided
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.doctorId != null) _fetchDoctorAvailabilities(widget.doctorId!);
    });
  }

  Future<void> _fetchDoctorAvailabilities(String doctorId) async {
    try {
      final client = createClient();
      const q = r'''
        query GetAvailabilities($doctorId: String!) {
          doctor_weekly_availabilities_by_doctor(doctorId: $doctorId) {
            dayOfWeek
            startHour
            endHour
            isActive
          }
        }
        ''';
      final res = await client.query(
        QueryOptions(
          document: gql(q),
          variables: {'doctorId': doctorId},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );
      if (res.hasException) {
        debugPrint('fetchDoctorAvailabilities error: ${res.exception}');
        return;
      }
      final rows =
          (res.data?['doctor_weekly_availabilities_by_doctor']
              as List<dynamic>?) ??
          [];
      final Map<int, Set<int>> byDay = {};
      for (var r in rows) {
        try {
          if (r['isActive'] != true) continue;
          final d = r['dayOfWeek'];
          final s = r['startHour'];
          final e = r['endHour'];
          final day = DayConvert.toInt(d);
          final sH = s is int ? s : int.tryParse(s?.toString() ?? '0');
          final eH = e is int ? e : int.tryParse(e?.toString() ?? '0');
          if (day == null || sH == null || eH == null) continue;
          final start = sH.clamp(0, 23);
          final end = eH.clamp(0, 24);
          final slots = <int>{};
          for (var h = start; h < end; h++) slots.add(h);
          byDay.putIfAbsent(day, () => <int>{});
          byDay[day]!.addAll(slots);
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _availabilitiesByDay.clear();
          _availabilitiesByDay.addAll(byDay);
        });
      }
    } catch (e) {
      debugPrint('fetchDoctorAvailabilities exception: $e');
    }
  }

  // Compute available hour slots for a given weekday (1=Mon..7=Sun).
  // Preference order: local SharedPreferences `available_times` ->
  // server-fetched `_availabilitiesByDay` -> default 08..16 slots.
  Future<List<int>> _hoursForWeekday(int weekday) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('available_times');
      if (raw != null && raw.isNotEmpty) {
        final parsed = jsonDecode(raw) as List<dynamic>;
        for (var e in parsed) {
          try {
            final map = Map<String, dynamic>.from(e as Map);
            final dn = DayConvert.toInt(map['dayOfWeek']);
            if (dn != null && dn == weekday) {
              final enabled = map['enabled'] == true;
              if (!enabled) return <int>[];
              final startStr = (map['start'] ?? '08:00').toString();
              final endStr = (map['end'] ?? '17:00').toString();
              final s = int.tryParse(startStr.split(':').first) ?? 8;
              final en = int.tryParse(endStr.split(':').first) ?? 17;
              final start = s.clamp(0, 23);
              final end = en.clamp(0, 24);
              final slots = <int>[];
              for (var h = start; h < end; h++) slots.add(h);
              return slots;
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    // Fall back to server-provided availabilities
    if (_availabilitiesByDay.containsKey(weekday) &&
        _availabilitiesByDay[weekday]!.isNotEmpty) {
      return _availabilitiesByDay[weekday]!.toList()..sort();
    }

    // No default fallback: if neither local prefs nor server provide
    // availability for this weekday, return an empty list to indicate
    // the day has no available slots.
    return <int>[];
  }

  void _showRecipientSelector(BuildContext context) async {
    final careRecipient = await fetchCareRecipients();
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            top: 12.h,
            left: 12.w,
            right: 12.w,
            bottom: 24.h,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                
                Text(
                  'Select Care Recipient',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8.h),
                ...careRecipient.map(
                  (s) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.shade300,
                      foregroundColor: Colors.white,
                      child: Text(
                        s['name']!
                            .split(' ')
                            .map((p) => p.isNotEmpty ? p[0] : '')
                            .take(2)
                            .join(),
                      ),
                    ),
                    title: Text(s['name'] ?? 'Name'),
                    subtitle: Text(s['id'] ?? ''),
                    onTap: () {
                      setState(() {
                        _selectedRecipient = {
                          'id': s['id']!,
                          'name': s['name']!,
                        };
                      });
                      Navigator.of(ctx).pop();
                    },
                  ),
                ),
                SizedBox(height: 8.h),

              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickDateTime(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(Duration(days: 365)),
      lastDate: DateTime.now().add(Duration(days: 365 * 5)),
    );
    if (date == null) return;

    final weekday = date.weekday; // 1=Mon .. 7=Sun
    final hours = await _hoursForWeekday(weekday);

    final selected = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
      ),
      builder: (ctx) {
        // `hours` is captured from outer scope (computed above).
        final key =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final selectedSet = <int>{...(_selectedSlots[key] ?? <int>[])};
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return Padding(
              padding: EdgeInsets.only(
                top: 12.h,
                left: 12.w,
                right: 12.w,
                bottom: 24.h,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Select Time Slots',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  if (hours.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      child: Center(
                        child: Text(
                          'No available slots for this date',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: hours.map((h) {
                        final label = '${h.toString().padLeft(2, '0')}:00';
                        final isSelected = selectedSet.contains(h);
                        return ChoiceChip(
                          label: Text(label),
                          selected: isSelected,
                          onSelected: (v) {
                            setStateSB(() {
                              if (v)
                                selectedSet.add(h);
                              else
                                selectedSet.remove(h);
                            });
                          },
                        );
                      }).toList(),
                    ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text('Cancel'),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              (hours.isNotEmpty && selectedSet.isNotEmpty)
                              ? () => Navigator.of(
                                  ctx,
                                ).pop(selectedSet.toList()..sort())
                              : null,
                          child: Text('Confirm'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (selected == null || selected.isEmpty) return;
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    setState(() {
      final existing = _selectedSlots[key] ?? <int>[];
      final newSet = {...existing, ...selected};
      _selectedSlots[key] = (newSet.toList()..sort());
      _selectedDate = date;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageAppBar(
        title: 'Add Appointment',
        showBack: true,
        showSearch: false,
        onSearch: () {},
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 8.h),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 8.h),
                        // Care recipient selector
                        Text(
                          'Care Recipient',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        GestureDetector(
                          onTap: () => _showRecipientSelector(context),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(12.w),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFF4EE), Color(0xFFFFE0CC)],
                              ),
                              border: Border.all(
                                color: Colors.orange.shade300,
                                width: 2.w,
                              ),
                              borderRadius: BorderRadius.circular(10.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 26.r,

                                  child: Text(
                                    _selectedRecipient == null
                                        ? '?'
                                        : _selectedRecipient!['name']!
                                              .split(' ')
                                              .map(
                                                (s) => s.isNotEmpty ? s[0] : '',
                                              )
                                              .take(2)
                                              .join(),
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedRecipient == null
                                            ? 'No care recipient selected'
                                            : _selectedRecipient!['name']!,
                                        style: TextStyle(
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(height: 6.h),
                                      Text(
                                        _selectedRecipient == null
                                            ? 'Tap to select'
                                            : (_selectedRecipient!['id'] ?? ''),
                                        style: TextStyle(
                                          fontSize: 13.sp,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: 16.h),

                        Text(
                          'Date & Time',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        GestureDetector(
                          onTap: _selectedRecipient == null
                              ? null
                              : () => _pickDateTime(context),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(12.w),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFF4EE), Color(0xFFFFE0CC)],
                              ),
                              border: Border.all(
                                color: Colors.orange.shade300,
                                width: 2.w,
                              ),

                              borderRadius: BorderRadius.circular(12.w),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.25),
                                  blurRadius: 14,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      color: Colors.black54,
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      child: Text(
                                        _selectedSlots.isEmpty
                                            ? (_selectedRecipient == null
                                                  ? 'Select care recipient first'
                                                  : 'Tap to select date & time')
                                            : 'Selected slots',
                                        style: TextStyle(
                                          fontSize: 15.sp,
                                          color: _selectedSlots.isEmpty
                                              ? Colors.black54
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    if (_selectedSlots.isNotEmpty)
                                      IconButton(
                                        icon: Icon(
                                          Icons.clear,
                                          color: Colors.redAccent,
                                        ),
                                        onPressed: () => setState(() {
                                          _selectedSlots.clear();
                                        }),
                                      ),
                                  ],
                                ),
                                if (_selectedSlots.isNotEmpty) ...[
                                  SizedBox(height: 8.h),
                                  Column(
                                    children: _selectedSlots.entries.map((
                                      entry,
                                    ) {
                                      final dateLabel = entry.key; // yyyy-MM-dd
                                      final hours = entry.value;
                                      return Padding(
                                        padding: EdgeInsets.only(bottom: 8.h),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    dateLabel,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  SizedBox(height: 6.h),
                                                  Wrap(
                                                    spacing: 8.w,
                                                    runSpacing: 8.h,
                                                    children: hours.map((h) {
                                                      final label =
                                                          '${h.toString().padLeft(2, '0')}:00';
                                                      return Chip(
                                                        label: Text(label),
                                                        onDeleted: () => setState(
                                                          () {
                                                            final list =
                                                                _selectedSlots[entry
                                                                    .key];
                                                            list?.remove(h);
                                                            if (list == null ||
                                                                list.isEmpty)
                                                              _selectedSlots
                                                                  .remove(
                                                                    entry.key,
                                                                  );
                                                          },
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.delete_outline,
                                                color: Colors.redAccent,
                                              ),
                                              onPressed: () => setState(
                                                () => _selectedSlots.remove(
                                                  entry.key,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: 12.h),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          return SafeArea(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 10.h),

                  Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (_selectedRecipient == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Please select a care recipient',
                                  ),
                                ),
                              );
                              return;
                            }
                            if (_selectedSlots.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Please select at least one date and time slot',
                                  ),
                                ),
                              );
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Appointment saved')),
                            );
                            Navigator.of(context).pop({
                              'careRecipient': _selectedRecipient,
                              'slots': _selectedSlots,
                            });
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.save, size: 18.w),
                              SizedBox(width: 6.w),
                              Flexible(
                                child: Text(
                                  'Save Appointment',
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: TextStyle(fontSize: 11.sp),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
