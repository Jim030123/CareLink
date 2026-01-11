import 'package:carelink_mobile/components/page_appbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:carelink_mobile/utils/graphql_service.dart';
import 'package:carelink_mobile/utils/user_service.dart';
import 'package:carelink_mobile/utils/auth_service.dart';
import 'package:intl/intl.dart' as intl;

class Appointment {
  final DateTime date;
  final String title;
  final String time;
  final String leftLabel;
  final String centerLabel;
  final String rightLabel;
  final String status;
  final String doctorId;
  final String careRecipientId;
  final String caregiverId;

  Appointment({
    required this.date,
    required this.title,
    required this.time,
    required this.leftLabel,
    required this.centerLabel,
    required this.rightLabel,
    this.status = '',
    this.doctorId = '',
    this.careRecipientId = '',
    this.caregiverId = '',
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
  bool _isLoadingAppointments = false;
  String? _storedRole;
  bool _showInlineSearch = false;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';
  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    // debug: start with a few hardcoded appointments so the UI shows data
    final today = DateTime.now();
    _appointments = [
      Appointment(
        date: DateTime(today.year, today.month, today.day),
        title: 'Medication Review',
        time: '09:30 AM',
        leftLabel: 'Dr Lim',
        centerLabel: 'Medication Review',
        rightLabel: 'John Doe',
        doctorId: 'DOC-001',
        careRecipientId: 'CR-071',
        caregiverId: 'CG-001',
      ),
      Appointment(
        date: DateTime(today.year, today.month, today.day),
        title: 'Follow-up',
        time: '11:00 AM',
        leftLabel: 'Dr Ng',
        centerLabel: 'Follow-up',
        rightLabel: 'Alice Tan',
        doctorId: 'DOC-002',
        careRecipientId: 'CR-072',
        caregiverId: 'CG-002',
      ),
      Appointment(
        date: DateTime(today.year, today.month, today.day + 2),
        title: 'Consultation',
        time: '02:00 PM',
        leftLabel: 'Dr Lee',
        centerLabel: 'Consultation',
        rightLabel: 'Bob Lim',
        doctorId: 'DOC-003',
        careRecipientId: 'CR-073',
        caregiverId: 'CG-003',
      ),
    ];
    _loadStoredRole();
  }
  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadStoredRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final r = prefs.getString('role');
      setState(() {
        _storedRole = r;
      });
      // after loading role, fetch appointments for the currently selected day
      // NOTE: when debugging with hardcoded appointments we don't want the
      // backend fetch to immediately overwrite them. Comment out to keep
      // the hardcoded data visible.
      await _retrieveAppointments(date: _selectedDay);
    } catch (_) {}
  }

  Future<void> _retrieveAppointments({DateTime? date, bool all = false}) async {
    try {
      setState(() {
        _isLoadingAppointments = true;
      });
      final role = (_storedRole ?? '').toLowerCase();

      // resolve backend id for current user (if signed in)
      String? backendId;
      final uid = AuthService.instance.currentUser?.uid;
      if (uid != null) {
        backendId = await fetchUserIdByUid(uid);
      }

      final client = createClient(idToken: await AuthService.instance.getIdToken());

      QueryResult res;
      List<dynamic> rows = [];

      // If a specific date was requested, prefer role-specific endpoints
      if (date != null) {
        final dateStr = intl.DateFormat('yyyy-MM-dd').format(date);
        QueryResult localRes;
        List<dynamic> dateRows = [];

        if (backendId != null && role == 'doctor') {
          // server supports filtering appointments_by_date by doctorId
          const q = r'''
            query AppointmentsByDate($date: String!, $doctorId: ID) {
              appointments_by_date(date: $date, doctorId: $doctorId) {
                appointmentId
                appointmentStart
                appointmentEnd
                title
                purpose
                status
                doctorId
                careRecipientId
                caregiverId
                doctor { firstName lastName }
                careRecipient { firstName lastName }
                caregiver { firstName lastName }
              }
            }
          ''';
          localRes = await client.query(QueryOptions(document: gql(q), variables: {'date': dateStr, 'doctorId': backendId}, fetchPolicy: FetchPolicy.networkOnly));
          debugPrint('[_retrieveAppointments] AppointmentsByDate (doctor) vars={date: $dateStr, doctorId: $backendId} hasException=${localRes.hasException}');
          debugPrint('[_retrieveAppointments] AppointmentsByDate (doctor) data=${localRes.data} exception=${localRes.exception}');
          dateRows = (localRes.data?['appointments_by_date'] as List<dynamic>?) ?? [];
        } else if (backendId != null && role.contains('recipient')) {
          // server provides appointments_by_careRecipient(careRecipientId)
          const q = r'''
              query AppointmentsByCareRecipient($careRecipientId: ID!, $date: String) {
                appointments_by_careRecipient(careRecipientId: $careRecipientId, date: $date) {
                appointmentId
                appointmentStart
                appointmentEnd
                title
                purpose
                status
                doctorId
                careRecipientId
                caregiverId
                doctor { firstName lastName }
                careRecipient { firstName lastName }
                caregiver { firstName lastName }
              }
            }
          ''';
          localRes = await client.query(QueryOptions(document: gql(q), variables: {'careRecipientId': backendId, 'date': dateStr}, fetchPolicy: FetchPolicy.networkOnly));
          debugPrint('[_retrieveAppointments] AppointmentsByCareRecipient vars={careRecipientId: $backendId, date: $dateStr} hasException=${localRes.hasException}');
          debugPrint('[_retrieveAppointments] AppointmentsByCareRecipient data=${localRes.data} exception=${localRes.exception}');
          dateRows = (localRes.data?['appointments_by_careRecipient'] as List<dynamic>?) ?? [];
        } else if (backendId != null && role.contains('caregiver')) {
          // server provides appointments_by_caregiver(caregiverId)
          const q = r'''
              query AppointmentsByCaregiver($caregiverId: ID!, $date: String) {
                appointments_by_caregiver(caregiverId: $caregiverId, date: $date) {
                appointmentId
                appointmentStart
                appointmentEnd
                title
                purpose
                status
                doctorId
                careRecipientId
                caregiverId
                doctor { firstName lastName }
                careRecipient { firstName lastName }
                caregiver { firstName lastName }
              }
            }
          ''';
          localRes = await client.query(QueryOptions(document: gql(q), variables: {'caregiverId': backendId, 'date': dateStr}, fetchPolicy: FetchPolicy.networkOnly));
          debugPrint('[_retrieveAppointments] AppointmentsByCaregiver vars={caregiverId: $backendId, date: $dateStr} hasException=${localRes.hasException}');
          debugPrint('[_retrieveAppointments] AppointmentsByCaregiver data=${localRes.data} exception=${localRes.exception}');
          dateRows = (localRes.data?['appointments_by_caregiver'] as List<dynamic>?) ?? [];
        } else {
          // fallback: fetch all appointments for that date
          const q = r'''
            query AppointmentsByDate($date: String!) {
              appointments_by_date(date: $date) {
                appointmentId
                appointmentStart
                appointmentEnd
                title
                purpose
                status
                doctorId
                careRecipientId
                caregiverId
                doctor { firstName lastName }
                careRecipient { firstName lastName }
                caregiver { firstName lastName }
              }
            }
          ''';
          localRes = await client.query(QueryOptions(document: gql(q), variables: {'date': dateStr}, fetchPolicy: FetchPolicy.networkOnly));
          debugPrint('[_retrieveAppointments] AppointmentsByDate (fallback) vars={date: $dateStr} hasException=${localRes.hasException}');
          debugPrint('[_retrieveAppointments] AppointmentsByDate (fallback) data=${localRes.data} exception=${localRes.exception}');
          dateRows = (localRes.data?['appointments_by_date'] as List<dynamic>?) ?? [];
        }

        // Map rows but only include those matching the requested date (for role-specific queries)
        final List<Appointment> fetched = [];
        DateTime? parseServerDate(dynamic v) {
          if (v == null) return null;
          final str = v.toString();
          if (RegExp(r'^\d+$').hasMatch(str)) {
            try {
              var n = int.parse(str);
              if (str.length == 10) n = n * 1000;
              return DateTime.fromMillisecondsSinceEpoch(n).toLocal();
            } catch (_) {
              return null;
            }
          }
          try {
            return DateTime.parse(str).toLocal();
          } catch (_) {
            return null;
          }
        }

        for (final r in dateRows) {
          try {
            final s = r['appointmentStart'];
            final dt = parseServerDate(s);
            if (dt == null) continue;
            final dateOnly = DateTime(dt.year, dt.month, dt.day);
            if (!isSameDay(dateOnly, date)) continue;

            final e = r['appointmentEnd'];
            final dtEnd = parseServerDate(e);
            final timeStr = (dtEnd != null)
              ? '${intl.DateFormat('hh:mm a').format(dt)} - ${intl.DateFormat('hh:mm a').format(dtEnd)}'
              : (intl.DateFormat('hh:mm a').format(dt));

            final title = r['title']?.toString() ?? '';
            final doctorId = r['doctorId']?.toString() ?? '';
            final careRecipientId = r['careRecipientId']?.toString() ?? '';
            final caregiverId = r['caregiverId']?.toString() ?? '';

            final Map<String, dynamic>? doctorObj = (r['doctor'] is Map) ? Map<String, dynamic>.from(r['doctor']) : null;
            final Map<String, dynamic>? crObj = (r['careRecipient'] is Map) ? Map<String, dynamic>.from(r['careRecipient']) : null;
            final Map<String, dynamic>? cgObj = (r['caregiver'] is Map) ? Map<String, dynamic>.from(r['caregiver']) : null;

            String fullNameFromMap(Map<String, dynamic>? m) {
              if (m == null) return '';
              final f = (m['firstName'] ?? m['firstname'] ?? '').toString();
              final l = (m['lastName'] ?? m['lastname'] ?? '').toString();
              final combined = ('$f $l').trim();
              return combined.isEmpty ? '' : combined;
            }

            final docName = fullNameFromMap(doctorObj);
            final crName = fullNameFromMap(crObj);
            final cgName = fullNameFromMap(cgObj);

            String left = '';
            String right = '';

            if (role == 'doctor') {
              left = docName.isNotEmpty ? docName : (doctorId.isNotEmpty ? doctorId : '');
              right = crName.isNotEmpty ? crName : (careRecipientId.isNotEmpty ? careRecipientId : '');
            } else if (role.contains('recipient')) {
              left = crName.isNotEmpty ? crName : (careRecipientId.isNotEmpty ? careRecipientId : '');
              right = docName.isNotEmpty ? docName : (doctorId.isNotEmpty ? doctorId : '');
            } else if (role.contains('caregiver')) {
              left = cgName.isNotEmpty ? cgName : (caregiverId.isNotEmpty ? caregiverId : '');
              right = crName.isNotEmpty ? crName : (careRecipientId.isNotEmpty ? careRecipientId : '');
            } else {
              left = docName.isNotEmpty ? docName : (doctorId.isNotEmpty ? doctorId : '');
              right = crName.isNotEmpty ? crName : (careRecipientId.isNotEmpty ? careRecipientId : '');
            }

            fetched.add(Appointment(
              date: dateOnly,
              title: title,
              time: timeStr,
              leftLabel: left,
              centerLabel: title,
              rightLabel: right,
              status: r['status']?.toString() ?? '',
              doctorId: doctorId,
              careRecipientId: careRecipientId,
              caregiverId: caregiverId,
            ));
          } catch (_) {}
        }

        setState(() {
          _appointments = fetched;
          _isLoadingAppointments = false;
        });
        debugPrint('[_retrieveAppointments] date fetch -> loaded ${_appointments.length} appointments');
        for (var i = 0; i < _appointments.length && i < 5; i++) {
          final a = _appointments[i];
          debugPrint('  appt[$i] date=${a.date.toIso8601String()} time="${a.time}" title="${a.title}" left="${a.leftLabel}" right="${a.rightLabel}"');
        }

        return;
      }

      if (all) {
        const q = r'''
          query AllAppointments {
            appointments {
              appointmentId
              appointmentStart
              appointmentEnd
              title
              purpose
              status
              doctorId
              careRecipientId
              caregiverId
              doctor { firstName lastName }
              careRecipient { firstName lastName }
              caregiver { firstName lastName }
            }
          }
        ''';
        res = await client.query(QueryOptions(document: gql(q), fetchPolicy: FetchPolicy.networkOnly));
        debugPrint('[_retrieveAppointments] AllAppointments (forced) hasException=${res.hasException}');
        debugPrint('[_retrieveAppointments] AllAppointments (forced) data=${res.data} exception=${res.exception}');
        rows = (res.data?['appointments'] as List<dynamic>?) ?? [];
      } else if (role == 'doctor' && backendId != null) {
        const q = r'''
          query AppointmentsByDoctor($doctorId: ID!) {
            appointments_by_doctor(doctorId: $doctorId) {
              appointmentId
              appointmentStart
              appointmentEnd
              title
              purpose
              status
              doctorId
              careRecipientId
              caregiverId
              doctor { firstName lastName }
              careRecipient { firstName lastName }
              caregiver { firstName lastName }
            }
          }
        ''';
        res = await client.query(QueryOptions(document: gql(q), variables: {'doctorId': backendId}, fetchPolicy: FetchPolicy.networkOnly));
        debugPrint('[_retrieveAppointments] AppointmentsByDoctor vars={doctorId: $backendId} hasException=${res.hasException}');
        debugPrint('[_retrieveAppointments] AppointmentsByDoctor data=${res.data} exception=${res.exception}');
        rows = (res.data?['appointments_by_doctor'] as List<dynamic>?) ?? [];
      } else if (role.contains('recipient') && backendId != null) {
        const q = r'''
          query AppointmentsByCareRecipient($careRecipientId: ID!) {
            appointments_by_careRecipient(careRecipientId: $careRecipientId) {
              appointmentId
              appointmentStart
              appointmentEnd
              title
              purpose
              status
              doctorId
              careRecipientId
              caregiverId
              doctor { firstName lastName }
              careRecipient { firstName lastName }
              caregiver { firstName lastName }
            }
          }
        ''';
        res = await client.query(QueryOptions(document: gql(q), variables: {'careRecipientId': backendId}, fetchPolicy: FetchPolicy.networkOnly));
        debugPrint('[_retrieveAppointments] AppointmentsByCareRecipient vars={careRecipientId: $backendId} hasException=${res.hasException}');
        debugPrint('[_retrieveAppointments] AppointmentsByCareRecipient data=${res.data} exception=${res.exception}');
        rows = (res.data?['appointments_by_careRecipient'] as List<dynamic>?) ?? [];
      } else if (role.contains('caregiver') && backendId != null) {
        const q = r'''
          query AppointmentsByCaregiver($caregiverId: ID!) {
            appointments_by_caregiver(caregiverId: $caregiverId) {
              appointmentId
              appointmentStart
              appointmentEnd
              title
              purpose
              status
              doctorId
              careRecipientId
              caregiverId
              doctor { firstName lastName }
              careRecipient { firstName lastName }
              caregiver { firstName lastName }
            }
          }
        ''';
        res = await client.query(QueryOptions(document: gql(q), variables: {'caregiverId': backendId}, fetchPolicy: FetchPolicy.networkOnly));
        debugPrint('[_retrieveAppointments] AppointmentsByCaregiver vars={caregiverId: $backendId} hasException=${res.hasException}');
        debugPrint('[_retrieveAppointments] AppointmentsByCaregiver data=${res.data} exception=${res.exception}');
        rows = (res.data?['appointments_by_caregiver'] as List<dynamic>?) ?? [];
      } else {
        const q = r'''
          query AllAppointments {
            appointments {
              appointmentId
              appointmentStart
              appointmentEnd
              title
              purpose
              status
              doctorId
              careRecipientId
              caregiverId
              doctor { firstName lastName }
              careRecipient { firstName lastName }
              caregiver { firstName lastName }
            }
          }
        ''';
        res = await client.query(QueryOptions(document: gql(q), fetchPolicy: FetchPolicy.networkOnly));
        debugPrint('[_retrieveAppointments] AllAppointments hasException=${res.hasException}');
        debugPrint('[_retrieveAppointments] AllAppointments data=${res.data} exception=${res.exception}');
        rows = (res.data?['appointments'] as List<dynamic>?) ?? [];
      }

      final List<Appointment> fetched = [];
      for (final r in rows) {
        try {
          final s = r['appointmentStart'];
          DateTime? dt;
          DateTime? parseServerDate(dynamic v) {
            if (v == null) return null;
            final str = v.toString();
            if (RegExp(r'^\d+$').hasMatch(str)) {
              try {
                var n = int.parse(str);
                if (str.length == 10) n = n * 1000;
                return DateTime.fromMillisecondsSinceEpoch(n).toLocal();
              } catch (_) {
                return null;
              }
            }
            try {
              return DateTime.parse(str).toLocal();
            } catch (_) {
              return null;
            }
          }
            dt = parseServerDate(s);
            // format time as "start - end" when end time available
            final e = r['appointmentEnd'];
            final dtEnd = parseServerDate(e);
            final timeStr = (dt != null && dtEnd != null)
              ? '${intl.DateFormat('hh:mm a').format(dt)} - ${intl.DateFormat('hh:mm a').format(dtEnd)}'
              : (dt != null ? intl.DateFormat('hh:mm a').format(dt) : '');
          final title = r['title']?.toString() ?? '';

          // IDs (fallback)
          final doctorId = r['doctorId']?.toString() ?? '';
          final careRecipientId = r['careRecipientId']?.toString() ?? '';
          final caregiverId = r['caregiverId']?.toString() ?? '';

          // Nested objects provided by backend (if resolver joined them)
          final Map<String, dynamic>? doctorObj = (r['doctor'] is Map) ? Map<String, dynamic>.from(r['doctor']) : null;
          final Map<String, dynamic>? crObj = (r['careRecipient'] is Map) ? Map<String, dynamic>.from(r['careRecipient']) : null;
          final Map<String, dynamic>? cgObj = (r['caregiver'] is Map) ? Map<String, dynamic>.from(r['caregiver']) : null;

          String fullNameFromMap(Map<String, dynamic>? m) {
            if (m == null) return '';
            final f = (m['firstName'] ?? m['firstname'] ?? '').toString();
            final l = (m['lastName'] ?? m['lastname'] ?? '').toString();
            final combined = ('$f $l').trim();
            return combined.isEmpty ? '' : combined;
          }

          final docName = fullNameFromMap(doctorObj);
          final crName = fullNameFromMap(crObj);
          final cgName = fullNameFromMap(cgObj);

          String left = '';
          String right = '';

          if (role == 'doctor') {
            left = docName.isNotEmpty ? docName : (doctorId.isNotEmpty ? doctorId : '');
            right = crName.isNotEmpty ? crName : (careRecipientId.isNotEmpty ? careRecipientId : '');
          } else if (role.contains('recipient')) {
            left = crName.isNotEmpty ? crName : (careRecipientId.isNotEmpty ? careRecipientId : '');
            right = docName.isNotEmpty ? docName : (doctorId.isNotEmpty ? doctorId : '');
          } else if (role.contains('caregiver')) {
            left = cgName.isNotEmpty ? cgName : (caregiverId.isNotEmpty ? caregiverId : '');
            right = crName.isNotEmpty ? crName : (careRecipientId.isNotEmpty ? careRecipientId : '');
          } else {
            // default: show doctor name if available, else id
            left = docName.isNotEmpty ? docName : (doctorId.isNotEmpty ? doctorId : '');
            right = crName.isNotEmpty ? crName : (careRecipientId.isNotEmpty ? careRecipientId : '');
          }

          // normalize date to local date-only so isSameDay() matches selected day
          final dateOnly = dt != null ? DateTime(dt.year, dt.month, dt.day) : DateTime.now();
          fetched.add(Appointment(
            date: dateOnly,
            title: title,
            time: timeStr,
            leftLabel: left,
            centerLabel: title,
            rightLabel: right,
            status: r['status']?.toString() ?? '',
            doctorId: doctorId,
            careRecipientId: careRecipientId,
            caregiverId: caregiverId,
          ));
        } catch (_) {}
      }

      debugPrint('[_retrieveAppointments] general fetch -> mapped ${fetched.length} rows');
      for (var i = 0; i < fetched.length && i < 5; i++) {
        final a = fetched[i];
        debugPrint('  mapped[$i] date=${a.date.toIso8601String()} time="${a.time}" title="${a.title}" left="${a.leftLabel}" right="${a.rightLabel}"');
      }
      setState(() {
        _appointments = fetched;
        _isLoadingAppointments = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingAppointments = false;
      });
      debugPrint('Failed to retrieve appointments: $e');
    }
  }

  Map<String, String> _labelsForAppointment(Appointment a) {
    final role = (_storedRole ?? '').toLowerCase();
    String left = a.leftLabel;
    String center = a.centerLabel;
    String right = a.rightLabel;

    if (role == 'doctor') {
      left = a.leftLabel.isNotEmpty ? a.leftLabel : a.doctorId;
    } else if (role.contains('recipient')) {
      left = a.leftLabel.isNotEmpty ? a.leftLabel : a.careRecipientId;
    } else if (role.contains('caregiver')) {
      left = a.leftLabel.isNotEmpty ? a.leftLabel : a.caregiverId;
    }

    return {'left': left, 'center': center, 'right': right};
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
                            color: Colors.white,
                            border: Border.all(color: Colors.orange.shade300, width: 1.w),
                            shape: BoxShape.circle,
                          ),
                          selectedTextStyle: TextStyle(color: Colors.black),
                        ),
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, date, events) {
                            if (_searchQuery.isEmpty) return const SizedBox.shrink();
                            final q = _searchQuery.toLowerCase();
                            final hasMatch = _appointments.any((a) =>
                              // only mark days that have confirmed appointments matching the query
                              isSameDay(a.date, date) &&
                              (a.status.toLowerCase() == 'confirmed') &&
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
                        onDaySelected: (selectedDay, focusedDay) async {
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

                          // fetch appointments for selected date
                          await _retrieveAppointments(date: selectedDay);

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
                          // search should only show confirmed appointments
                          if (a.status.toLowerCase() != 'confirmed') return false;
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
                                        final labels = _labelsForAppointment(a);
                                        return _buildAppointmentCard(
                                          day: day,
                                          monthYear: monthYear,
                                          weekday: weekday,
                                          title: a.title,
                                          time: a.time,
                                          leftLabel: labels['left']!,
                                          centerLabel: labels['center']!,
                                          rightLabel: labels['right']!,
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
                                final labels = _labelsForAppointment(a);
                                return _buildAppointmentCard(
                                  day: day,
                                  monthYear: monthYear,
                                  weekday: weekday,
                                  title: a.title,
                                  time: a.time,
                                  leftLabel: labels['left']!,
                                  centerLabel: labels['center']!,
                                  rightLabel: labels['right']!,
                                );
                              }),
                            ],
                          ],
                        );
                      }

                      // No inline query: show only selected day's appointments
                      final selected = _selectedDay ?? _focusedDay;
                      final todays = _appointments.where((a) => isSameDay(a.date, selected)).toList();
                      if (_isLoadingAppointments) {
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

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
                          final labels = _labelsForAppointment(a);
                          return _buildAppointmentCard(
                            day: day,
                            monthYear: monthYear,
                            weekday: weekday,
                            title: a.title,
                            time: a.time,
                            leftLabel: labels['left']!,
                            centerLabel: labels['center']!,
                            rightLabel: labels['right']!,
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


  Future<void> _toggleInlineSearch() async {
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
      // when entering search mode, fetch role-filtered appointments
      // so search only shows results the current role can see
      await _retrieveAppointments();
    } else {
      // leaving search mode: restore appointments for the selected day
      await _retrieveAppointments(date: _selectedDay);
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
