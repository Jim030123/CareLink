import 'package:carelink_mobile/components/numbering.dart';
import 'package:carelink_mobile/components/page_appbar.dart';
import 'package:carelink_mobile/utils/graphql_service.dart';
import 'package:carelink_mobile/utils/user_service.dart';
import 'package:carelink_mobile/utils/auth_service.dart';
import 'package:carelink_mobile/utils/day_convert.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:uuid/uuid.dart';

class AddAppointmentPage extends StatefulWidget {
  final String? doctorId;
  const AddAppointmentPage({super.key, this.doctorId});

  @override
  State<AddAppointmentPage> createState() => _AddAppointmentPageState();
}

class _AddAppointmentPageState extends State<AddAppointmentPage> {
  Map<String, String>? _selectedRecipient;
  DateTime? _selectedDate;
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _purposeCtrl = TextEditingController();
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

  @override
  void dispose() {
    _titleCtrl.dispose();
    _purposeCtrl.dispose();
    super.dispose();
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
          for (var h = start; h < end; h++) {
            slots.add(h);
          }
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
              for (var h = start; h < end; h++) {
                slots.add(h);
              }
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

  // Merge a sorted list of integer hours into continuous ranges.
  // Returns list of maps with 'start' and 'end' (end is exclusive).
  List<Map<String, int>> _mergeContinuousHours(List<int> hours) {
    if (hours.isEmpty) return [];
    final sorted = List<int>.from(hours)..sort();
    final ranges = <Map<String, int>>[];
    int rangeStart = sorted.first;
    int prev = sorted.first;
    for (var i = 1; i < sorted.length; i++) {
      final h = sorted[i];
      if (h == prev + 1) {
        prev = h;
        continue;
      }
      ranges.add({'start': rangeStart, 'end': prev + 1});
      rangeStart = h;
      prev = h;
    }
    ranges.add({'start': rangeStart, 'end': prev + 1});
    return ranges;
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

    // Resolve doctorId first so we can fetch that doctor's weekly availabilities
    String? doctorIdLocal = widget.doctorId;
    if (doctorIdLocal == null) {
      final uid = AuthService.instance.currentUser?.uid;
      if (uid != null) {
        final fetched = await fetchUserIdByUid(uid);
        if (fetched != null && fetched.isNotEmpty) doctorIdLocal = fetched;
      }
    }

    // If we have a doctorId, fetch their weekly availabilities so
    // `_hoursForWeekday` can use them as a source of truth.
    if (doctorIdLocal != null && doctorIdLocal.isNotEmpty) {
      await _fetchDoctorAvailabilities(doctorIdLocal);
    }

    // Now compute available hours (prefers local prefs -> server availabilities)
    var hours = await _hoursForWeekday(weekday);

    // Fetch appointments for this date to determine blocked hours (by doctor)
    Set<int> blockedHours = <int>{};
    try {

      final clientForAppts = createClient();
      const apptsQuery = r'''
        query AppointmentsByDateHours($date: String!, $doctorId: ID) {
  appointments_by_date_hours(date: $date, doctorId: $doctorId) {
    hour
    appointments {
      appointmentId
      appointmentStart
      appointmentEnd
      title
      status
      purpose
    }
  }
}

      ''';
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final apRes = await clientForAppts.query(QueryOptions(
        document: gql(apptsQuery),
        variables: {'date': dateKey, 'doctorId': doctorIdLocal},
        fetchPolicy: FetchPolicy.networkOnly,
      ));
      if (!apRes.hasException) {
        final buckets = (apRes.data?['appointments_by_date_hours'] as List<dynamic>?) ?? [];
        debugPrint('[appointments_by_date_hours] buckets: ${buckets.length}');
        for (final b in buckets) {
          try {
            final rawHour = b['hour'];
            int? h;
            if (rawHour is int) {
              h = rawHour;
            } else if (rawHour is String) h = int.tryParse(rawHour);
            final apps = (b['appointments'] as List<dynamic>?) ?? [];
            debugPrint('[appointments_by_date_hours] hour=$rawHour parsed=$h apps=${apps.length}');
            // Only consider appointments with status 'pending' or 'approved' as blocking
            var hasBlocking = false;
            for (final a in apps) {
              try {
                final st = (a['status'] ?? '').toString().toLowerCase();
                if (st == 'pending' || st == 'approved') {
                  hasBlocking = true;
                  break;
                }
              } catch (_) {}
            }
            if (h != null && hasBlocking) blockedHours.add(h);
          } catch (e) {
            debugPrint('Error parsing bucket: $e');
          }
        }
        debugPrint('[appointments_by_date_hours] blockedHours=$blockedHours');
      } else {
        debugPrint('appointments_by_date_hours error: ${apRes.exception}');
      }
    } catch (e) {
      debugPrint('Failed to fetch appointments_by_date_hours: $e');
    }

    // Filter out hours already occupied by appointments with status 'pending' or 'complete'
    // try {
    //   final crId = _selectedRecipient?['id'];
    //   if (crId != null && crId.isNotEmpty) {
    //     final occupied = await _occupiedHoursForDate(crId, date);
    //     if (occupied.isNotEmpty) {
    //       hours = hours.where((h) => !occupied.contains(h)).toList();
    //     }
    //   }
    // } catch (e) {
    //   debugPrint('Failed to filter occupied hours: $e');
    // }

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
                        final isBlocked = blockedHours.contains(h);
                        return ChoiceChip(

                          label: Text(
                            label,
                            style: TextStyle(
                              color: isBlocked ? Colors.black38 : null,
                            ),
                          ),
                          selected: isSelected,
                         onSelected: isBlocked
      ? null        // ❌ 被 block → 不能点
      : (v) {       // ✅ 没被 block → 可以点
          setStateSB(() {
            if (v) {
              selectedSet.add(h);
            } else {
              selectedSet.remove(h);
            }
          });
        },
                          backgroundColor: isBlocked ? Colors.grey.shade200 : null,
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

  // Fetch appointments for given careRecipient and date and return occupied hours
    Future<void> _performSave() async {
    debugPrint('[_performSave] start');
    debugPrint('[_performSave] _selectedRecipient=$_selectedRecipient');
    debugPrint('[_performSave] _selectedSlots=$_selectedSlots');

    if (_selectedRecipient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a care recipient')),
      );
      return;
    }
    if (_selectedSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select at least one date and time slot')),
      );
      return;
    }

    final objects = <Map<String, dynamic>>[];
    // Determine doctorId: prefer widget.doctorId, else use current account's roleId (backend id)
    String? doctorId = widget.doctorId;
    if (doctorId == null) {
      try {
        final uid = AuthService.instance.currentUser?.uid;
        if (uid != null) {
          final fetched = await fetchUserIdByUid(uid);
          if (fetched != null && fetched.isNotEmpty) doctorId = fetched;
        }
      } catch (_) {}
    }
    debugPrint('[_performSave] resolved doctorId=$doctorId');

    // Determine caregiverId from selected care recipient (if available)
    String? caregiverId;
    try {
      final clientForQuery = createClient();
      final crId = _selectedRecipient?['id'];
      if (crId != null && crId.isNotEmpty) {
        const crQuery = r'''
          query GetCareRecipient($id: String!) {
            care_recipient_by_pk(id: $id) { caregiverId }
          }
        ''';
        final qres = await clientForQuery.query(QueryOptions(document: gql(crQuery), variables: {'id': crId}, fetchPolicy: FetchPolicy.networkOnly));
        if (!qres.hasException) {
          caregiverId = qres.data?['care_recipient_by_pk']?['caregiverId'] as String?;
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch caregiverId for careRecipient: $e');
    }
    debugPrint('[_performSave] resolved caregiverId=$caregiverId');

    // Fetch a generated appointment number to reuse across all timeslots
    String? appointmentNumber;
   try {


  final messenger = ScaffoldMessenger.of(context);

  appointmentNumber = await fetchGeneratedCode(
     GraphQLProvider.of(context).value,
    messenger: messenger,
    id: 10,
  );

  if (appointmentNumber == null) {
    debugPrint('[_performSave] failed to generate appointment number');
    return;
  }

  debugPrint('[_performSave] fetched appointmentNumber=$appointmentNumber');
} catch (e, st) {
  debugPrint('[_performSave] exception fetching generated code: $e');
  debugPrint(st.toString());
}


    _selectedSlots.forEach((dateLabel, hours) {
      final ranges = _mergeContinuousHours(hours);
      for (final r in ranges) {
        final startHour = r['start']!;
        final endHour = r['end']!; // exclusive
        try {
          final parts = dateLabel.split('-');
          final y = int.parse(parts[0]);
          final m = int.parse(parts[1]);
          final d = int.parse(parts[2]);
          final start = DateTime(y, m, d, startHour, 0).toUtc().toIso8601String();
          final end = DateTime(y, m, d, endHour, 0).toUtc().toIso8601String();
          final obj = {
            'appointmentId': Uuid().v4(),
            'careRecipientId': _selectedRecipient!['id'],
            'caregiverId': caregiverId,
            'doctorId': doctorId,
            'appointmentNumber': appointmentNumber,
            'appointmentStart': start,
            'appointmentEnd': end,
            'title': _titleCtrl.text.trim(),
            'purpose': _purposeCtrl.text.trim(),
            'status': 'pending',
          };
          debugPrint('[_performSave] adding appointment object: $obj');
          objects.add(obj);
        } catch (_) {}
      }
    });

    if (objects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No valid appointment objects to save')));
      return;
    }

    const mutation = r'''
      mutation InsertAppointments($objects: [appointment_insert_input!]!) {
        insert_appointment(objects: $objects) { appointmentId }
      }
    ''';

    final client = createClient();
    try {
      final res = await client.mutate(
        MutationOptions(
          document: gql(mutation),
          variables: {'objects': objects},
        ),
      );
      if (res.hasException) {
        debugPrint('Insert appointments failed: ${res.exception}');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save appointment')));
        return;
      }

      debugPrint('[_performSave] insert result: ${res.data}');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Appointment saved')));
      Navigator.of(context).pop({
        'careRecipient': _selectedRecipient,
        'slots': _selectedSlots,
        'selectedDates': _selectedSlots.keys.toList(),
        'title': _titleCtrl.text.trim(),
        'purpose': _purposeCtrl.text.trim(),
        'inserted': res.data,
      });
    } catch (e, st) {
      debugPrint('Error inserting appointments: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save appointment')));
    }
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

                        // Title input
                        Text(
                          'Title',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: _titleCtrl,
                          decoration: InputDecoration(
                            hintText: 'Enter appointment title',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                          ),
                        ),
                        SizedBox(height: 12.h),

                        // Purpose / notes input
                        Text(
                          'Purpose',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: _purposeCtrl,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Describe the purpose or notes',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                          ),
                        ),

                        SizedBox(height: 12.h),

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
                            padding: EdgeInsets.all(12.w),
                            decoration: BoxDecoration(
                              color: Colors.white70,
                              borderRadius: BorderRadius.circular(12.w),
                              border: Border.all(
                                color: Colors.orange.shade300,
                                width: 2.w,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.access_time, color: Colors.black54),
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
                          ),
                        ),

                        SizedBox(height: 12.h),
                        Container(
                          constraints: BoxConstraints(minHeight: 200.h),
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
                              if (_selectedSlots.isNotEmpty) ...[
                                SizedBox(height: 8.h),
                                Column(
                                  children: _selectedSlots.entries.map((entry) {
                                    final dateLabel = entry.key; // yyyy-MM-dd
                                    final hours = entry.value;
                                    return Padding(
                                      padding: EdgeInsets.only(bottom: 8.h),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Date column (separated from time)
                                          SizedBox(
                                            width: 110.w,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Chip(
                                                  backgroundColor:
                                                      Colors.orange.shade50,
                                                  label: Text(
                                                    dateLabel,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(width: 8.w),
                                          // Time ranges column
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: _mergeContinuousHours(hours).map((
                                                r,
                                              ) {
                                                final start = r['start']!;
                                                final end =
                                                    r['end']!; // exclusive
                                                final label =
                                                    '${start.toString().padLeft(2, '0')}:00 - ${end.toString().padLeft(2, '0')}:00';
                                                return Padding(
                                                  padding: EdgeInsets.only(
                                                    bottom: 6.h,
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Chip(
                                                        label: Text(label),
                                                        onDeleted: () => setState(
                                                          () {
                                                            final list =
                                                                _selectedSlots[entry
                                                                    .key];
                                                            if (list != null) {
                                                              list.removeWhere(
                                                                (hour) =>
                                                                    hour >=
                                                                        start &&
                                                                    hour < end,
                                                              );
                                                              if (list.isEmpty) {
                                                                _selectedSlots
                                                                    .remove(
                                                                      entry.key,
                                                                    );
                                                              }
                                                            }
                                                          },
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
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
                          onPressed: _performSave,
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
