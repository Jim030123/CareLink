import 'package:carelink_mobile/components/page_appbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:carelink_mobile/utils/user_service.dart';
import 'package:carelink_mobile/utils/graphql_service.dart';
import 'package:carelink_mobile/utils/auth_service.dart';
import 'package:carelink_mobile/utils/secure_auth.dart';
import 'package:carelink_mobile/utils/day_convert.dart';
import 'package:carelink_mobile/components/available_time_editor.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _name = 'Sabrina Aryan';
  String _email = 'SabrinaAry208@gmailcom';
  // Notification settings state
  bool _pushNotifications = true;
  bool _emailNotifications = true;

  // Role state
  bool _isDoctor = false;

  late FlutterLocalNotificationsPlugin _localNotifications;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _email = user.email ?? _email;
      _name =
          user.displayName ??
          (user.email != null ? user.email!.split('@').first : _name);
    }
    // Attempt to load backend profile (may contain canonical email/displayName)
    _loadProfileFromBackend();
    _localNotifications = FlutterLocalNotificationsPlugin();
    _initLocalNotifications();
    _loadNotificationSettings();
    // load role, then attempt to restore availabilities from server for this user
    _loadUserRole().whenComplete(
      () => _restoreAvailabilitiesFromServerIfNeeded(),
    );
  }

  Future<void> _loadProfileFromBackend() async {
    try {
      final fbUser = FirebaseAuth.instance.currentUser;
      if (fbUser == null) return;
      final backendUser = await fetchUserByUid(fbUser.uid);
      if (backendUser == null) return;
      final beEmail = backendUser['email']?.toString();
      final beName = backendUser['displayName']?.toString();
      if (mounted) {
        setState(() {
          if (beEmail != null && beEmail.isNotEmpty) _email = beEmail;
          if (beName != null && beName.isNotEmpty)
            _name = beName;
        });
      }
    } catch (_) {}
  }

  Future<void> _restoreAvailabilitiesFromServerIfNeeded() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final dbId = await fetchUserIdByUid(user.uid);
      if (dbId == null) return;

      GraphQLClient? client;
      try {
        client = GraphQLProvider.of(context).value;
      } catch (_) {
        client = null;
      }
      if (client == null) {
        final token = await AuthService.instance.getIdToken();
        if (token != null) client = createClient(idToken: token);
      }
      if (client == null) return;

      const q = r'''
query GetActiveAvailabilities($doctorId: String!) {
  doctor_weekly_availabilities_by_doctor(doctorId: $doctorId) {
    availabilityId
    doctorId
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
          variables: {'doctorId': dbId},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (res.hasException) {
        debugPrint('restoreAvailabilities: query error: ${res.exception}');
        return;
      }

      debugPrint('restoreAvailabilities: data=${res.data}');

      // The query requests `doctor_weekly_availabilities_by_doctor` — read that field.
      final rows =
          (res.data?['doctor_weekly_availabilities_by_doctor']
              as List<dynamic>?) ??
          [];
      // Normalize server rows: store numeric day strings '1'..'7' so
      // local merging/fallback logic can handle them reliably.
      // Use DayConvert.toInt to normalize day values

      String _formatHour(dynamic h) {
        if (h == null) return '00:00';
        final hi = int.tryParse(h.toString()) ?? 0;
        return hi.toString().padLeft(2, '0') + ':00';
      }

      final mapped = rows
          .map((r) {
            final day = DayConvert.toInt(r['dayOfWeek']);
            if (day == null) {
              debugPrint(
                'restoreAvailabilities: skipping row with null/invalid dayOfWeek: ${r}',
              );
              return null;
            }
            return {
              'dayOfWeek': day.toString(),
              'enabled': r['isActive'] == true,
              'start': _formatHour(r['startHour']),
              'end': _formatHour(r['endHour']),
            };
          })
          .where((e) => e != null)
          .map((e) => e as Map<String, dynamic>)
          .toList();

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('available_times', jsonEncode(mapped));
        debugPrint(
          'restoreAvailabilities: saved ${mapped.length} rows to prefs',
        );
      } catch (e) {
        debugPrint('restoreAvailabilities: prefs save failed: $e');
      }
    } catch (e, st) {
      debugPrint('restoreAvailabilities exception: $e\n$st');
    }
  }

  Future<void> _loadUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rolePref = prefs.getString('role');
      if (rolePref != null) {
        setState(() => _isDoctor = rolePref.toLowerCase() == 'doctor');
        debugPrint('loadUserRole: rolePref=$rolePref => isDoctor=$_isDoctor');
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final idToken = await user.getIdTokenResult();
          final claims = idToken.claims;
          if (claims != null && claims['role'] != null) {
            setState(
              () => _isDoctor =
                  claims['role'].toString().toLowerCase() == 'doctor',
            );
            debugPrint(
              'loadUserRole: claims.role=${claims['role']} => isDoctor=$_isDoctor',
            );
            return;
          }
        } catch (_) {}

        final displayName = user.displayName ?? '';
        if (displayName.toLowerCase().contains('dr') ||
            (user.email ?? '').toLowerCase().contains('doctor')) {
          setState(() => _isDoctor = true);
          debugPrint(
            'loadUserRole: inferred from displayName/email => isDoctor=$_isDoctor',
          );
        }
      }
    } catch (_) {}
    debugPrint('loadUserRole: finished, isDoctor=$_isDoctor');
  }

  // Available times persistence helpers
  Future<List<Map<String, dynamic>>> _readAvailableTimes() async {
    // Day values use numeric representation: Monday=1 .. Sunday=7
    const defaults = [
      {'dayOfWeek': '1', 'enabled': true, 'start': '08:00', 'end': '17:00'},
      {'dayOfWeek': '2', 'enabled': true, 'start': '08:00', 'end': '17:00'},
      {'dayOfWeek': '3', 'enabled': true, 'start': '08:00', 'end': '17:00'},
      {'dayOfWeek': '4', 'enabled': true, 'start': '08:00', 'end': '17:00'},
      {'dayOfWeek': '5', 'enabled': true, 'start': '08:00', 'end': '17:00'},
      {'dayOfWeek': '6', 'enabled': true, 'start': '08:00', 'end': '17:00'},
      {'dayOfWeek': '7', 'enabled': true, 'start': '08:00', 'end': '17:00'},
    ];

    // Use DayConvert.toInt to normalize day values

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('available_times');
      if (raw == null || raw.isEmpty) return defaults;
      final parsed = jsonDecode(raw) as List<dynamic>;
      final parsedList = parsed
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      // Build a map keyed by numeric day string '1'..'7'
      final Map<String, Map<String, dynamic>> dayMap = {};
      for (var e in parsedList) {
        final dn = DayConvert.toInt(e['dayOfWeek']);
        if (dn == null) continue;
        final key = dn.toString();
        dayMap[key] = {
          'dayOfWeek': key,
          'enabled': e['enabled'] == true,
          'start': (e['start'] ?? '08:00').toString(),
          'end': (e['end'] ?? '17:00').toString(),
        };
      }

      final result = <Map<String, dynamic>>[];
      for (var i = 1; i <= 7; i++) {
        final k = i.toString();
        if (dayMap.containsKey(k))
          result.add(dayMap[k]!);
        else
          result.add({
            'dayOfWeek': k,
            'enabled': false,
            'start': '08:00',
            'end': '17:00',
          });
      }
      return result;
    } catch (_) {
      return defaults;
    }
  }

  @override
  Future<void> _saveAvailableTimes(List<Map<String, dynamic>> times) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('available_times', jsonEncode(times));
      // After saving locally, attempt to upload to GraphQL backend if possible
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && mounted) {
          // Resolve DB-side id for this user
          final dbId = await fetchUserIdByUid(user.uid);
          final messenger = ScaffoldMessenger.of(context);
          debugPrint(
            'availabilityUpload: current firebase uid=${user.uid}, resolved dbId=$dbId',
          );
          if (dbId == null) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text(
                  'Saved locally: unable to determine doctor id for upload',
                ),
              ),
            );
          } else {
            GraphQLClient? client;
            try {
              client = GraphQLProvider.of(context).value;
            } catch (_) {
              client = null;
            }

            if (client == null) {
              final token = await AuthService.instance.getIdToken();
              debugPrint(
                'availabilityUpload: fetched idToken present=${token != null}',
              );
              if (token != null) {
                client = createClient(idToken: token);
              }
            }

            if (client == null) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('No GraphQL client available for upload'),
                ),
              );
            } else {
              debugPrint(
                'availabilityUpload: attempting upload for dbId=$dbId with times=${jsonEncode(times)}',
              );
              final ok = await uploadAvailabilityWithClient(
                client: client,
                doctorId: dbId,
                times: times,
              );
              if (mounted) {
                if (ok) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Availability uploaded')),
                  );
                } else {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Failed to upload availability (saved locally)',
                      ),
                    ),
                  );
                }
              }
            }
          }
        }
      } catch (_) {}
    } catch (_) {}
  }

  Future<void> _initLocalNotifications() async {
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings();
      await _localNotifications.initialize(
        const InitializationSettings(android: android, iOS: ios),
      );
    } catch (_) {}
  }

  Future<void> _loadNotificationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _pushNotifications =
            prefs.getBool('push_notifications') ?? _pushNotifications;
        _emailNotifications =
            prefs.getBool('email_notifications') ?? _emailNotifications;
      });
    } catch (_) {}
  }

  Future<void> _setPushNotifications(bool v) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('push_notifications', v);
      if (mounted) setState(() => _pushNotifications = v);
    } catch (_) {}
  }

  Future<void> _setEmailNotifications(bool v) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('email_notifications', v);
      if (mounted) setState(() => _emailNotifications = v);
    } catch (_) {}
  }

  bool _isAllowed(dynamic t) {
    try {
      TimeOfDay tod;
      if (t is TimeOfDay) {
        tod = t;
      } else if (t is String) {
        tod = _parseTime(t);
      } else {
        return false;
      }
      return tod.hour >= 0 &&
          tod.hour <= 23 &&
          tod.minute >= 0 &&
          tod.minute <= 59;
    } catch (_) {
      return false;
    }
  }

  String _format(TimeOfDay t) =>
      t.hour.toString().padLeft(2, '0') +
      ':' +
      t.minute.toString().padLeft(2, '0');

  TimeOfDay _parseTime(String v) {
    final parts = v.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return TimeOfDay(hour: h, minute: m);
  }

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  void _showFeatureSheet(BuildContext context, String title, Widget content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                title,
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12.h),
              content,
            ],
          ),
        ),
      ),
    );
  }

  /// Uploads a list of availability entries to Hasura (or other GraphQL server)
  /// using a provided [GraphQLClient]. Each local `times` entry should contain
  /// keys: `dayOfWeek`, `start`, `end`, `enabled`.

  Future<bool> uploadAvailabilityWithClient({
    required GraphQLClient client,
    required String doctorId,
    required List<Map<String, dynamic>> times,
  }) async {
    final uuid = const Uuid();

    /// ---------- helpers ----------
    // Use DayConvert.safeString to produce a numeric day string with fallback

    int? _hourFloor(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      if (s.contains(':')) {
        final h = int.tryParse(s.split(':').first) ?? 0;
        return h.clamp(0, 23);
      }
      final p = int.tryParse(s);
      return p == null ? null : p.clamp(0, 23);
    }

    /// ---------- build raw objects (SAFE) ----------
    final List<Map<String, dynamic>> rawObjects = [];

    for (int i = 0; i < times.length; i++) {
      final t = times[i];

      rawObjects.add({
        'availabilityId': uuid.v4(),
        'doctorId': doctorId,
        'dayOfWeek': DayConvert.safeString(t['dayOfWeek'], i),
        'startHour': t['start'],
        'endHour': t['end'],
        'isActive': t['enabled'] == true,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });
    }

    /// ---------- normalize ----------
    final normalized = rawObjects.map((o) {
      final dayInt = int.tryParse(o['dayOfWeek'].toString());
      final sHour = _hourFloor(o['startHour']);
      final eHour = _hourFloor(o['endHour']);

      return {
        'availabilityId': o['availabilityId'],
        'doctorId': o['doctorId'],
        'dayOfWeek': dayInt,
        'startHour': sHour,
        'endHour': eHour,
        'isActive': o['isActive'],
        'createdAt': o['createdAt'],
      };
    }).toList();

    /// ---------- dedupe active ----------
    final List<Map<String, dynamic>> finalObjects = [];
    final Map<String, Map<String, dynamic>> latestActive = {};

    for (final o in normalized) {
      final key =
          '${o['doctorId']}|${o['dayOfWeek']}|${o['startHour']}|${o['endHour']}';

      if (o['isActive'] == true &&
          o['dayOfWeek'] != null &&
          o['startHour'] != null &&
          o['endHour'] != null) {
        if (!latestActive.containsKey(key)) {
          latestActive[key] = o;
        } else {
          final a =
              DateTime.tryParse(o['createdAt']) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final b =
              DateTime.tryParse(latestActive[key]!['createdAt']) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          if (a.isAfter(b)) latestActive[key] = o;
        }
      } else {
        finalObjects.add(o);
      }
    }

    finalObjects.addAll(latestActive.values);

    /// ---------- stringify for GraphQL ----------
    final uploadObjects = finalObjects.map((o) {
      return {
        'availabilityId': o['availabilityId'],
        'doctorId': o['doctorId'],
        'dayOfWeek': o['dayOfWeek']?.toString(),
        'startHour': o['startHour']?.toString(),
        'endHour': o['endHour']?.toString(),
        'isActive': o['isActive'],
        'createdAt': o['createdAt'],
      };
    }).toList();

    debugPrint(
      'uploadAvailability: uploadObjects=${jsonEncode(uploadObjects)}',
    );

    /// ---------- GraphQL ----------
    const deactivateMutation = r'''
mutation DeactivateDoctorAvailabilities($doctorId: String!) {
  deactivate_doctor_availabilities(doctorId: $doctorId) {
    affected_rows
  }
}
''';

    const insertMutation = r'''
mutation InsertAvailability(
  $objects: [doctor_weekly_availability_insert_input!]!
) {
  insert_doctor_weekly_availability(objects: $objects) {
    affected_rows
  }
}
''';

    try {
      final deactRes = await client.mutate(
        MutationOptions(
          document: gql(deactivateMutation),
          variables: {'doctorId': doctorId},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (deactRes.hasException) {
        debugPrint('deactivate error: ${deactRes.exception}');
        return false;
      }

      final res = await client.mutate(
        MutationOptions(
          document: gql(insertMutation),
          variables: {'objects': uploadObjects},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (res.hasException) {
        debugPrint('insert error: ${res.exception}');
        return false;
      }

      debugPrint('uploadAvailability success');
      return true;
    } catch (e, st) {
      debugPrint('uploadAvailability exception: $e\n$st');
      return false;
    }
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageAppBar(title: 'Profile', showBack: true, showSearch: false),
      body: LayoutBuilder(
        builder: (context, constraints) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12.r),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8.r,
                          offset: Offset(0, 2.h),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 40.r,
                              backgroundColor: Colors.grey.shade200,
                              child: Text(
                                _name
                                    .split(' ')
                                    .map((s) => s.isNotEmpty ? s[0] : '')
                                    .take(2)
                                    .join(),
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: -2.h,
                              right: -2.w,
                              child: GestureDetector(
                                onTap: () {
                                  // open image picker
                                },
                                child: Container(
                                  padding: EdgeInsets.all(6.w),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.black12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 4.r,
                                        offset: Offset(0, 2.h),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.camera_alt,
                                    size: 18.sp,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(width: 20.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _name,
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 6.h),
                              Text(
                                _email,
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  color: Colors.black54,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              ElevatedButton(
                                onPressed: () {
                                  final nameController = TextEditingController(
                                    text: _name,
                                  );
                                  final emailController = TextEditingController(
                                    text: _email,
                                  );
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(16.r),
                                      ),
                                    ),
                                    builder: (ctx) {
                                      return Padding(
                                        padding: EdgeInsets.only(
                                          bottom: MediaQuery.of(
                                            ctx,
                                          ).viewInsets.bottom,
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 16.w,
                                            vertical: 12.h,
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Center(
                                                child: Container(
                                                  width: 36.w,
                                                  height: 4.h,
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[300],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          2.r,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(height: 12.h),
                                              Text(
                                                'Edit Profile',
                                                style: TextStyle(
                                                  fontSize: 16.sp,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              SizedBox(height: 12.h),
                                              TextField(
                                                controller: nameController,
                                                decoration: InputDecoration(
                                                  labelText: 'Name',
                                                ),
                                              ),
                                              SizedBox(height: 8.h),
                                              TextField(
                                                controller: emailController,
                                                decoration: InputDecoration(
                                                  labelText: 'Email',
                                                ),
                                                keyboardType:
                                                    TextInputType.emailAddress,
                                              ),
                                              SizedBox(height: 16.h),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(ctx).pop(),
                                                    child: Text(
                                                      'Cancel',
                                                      style: TextStyle(
                                                        fontSize: 14.sp,
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(width: 8.w),
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      setState(() {
                                                        _name = nameController
                                                            .text
                                                            .trim();
                                                        _email = emailController
                                                            .text
                                                            .trim();
                                                      });
                                                      Navigator.of(ctx).pop();
                                                      if (mounted) {
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          const SnackBar(
                                                            content: Text(
                                                              'Profile updated',
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    },
                                                    child: Text(
                                                      'Save',
                                                      style: TextStyle(
                                                        fontSize: 14.sp,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 8.h),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 24.w,
                                    vertical: 10.h,
                                  ),
                                ),
                                child: Text(
                                  'Edit Profile',
                                  style: TextStyle(fontSize: 12.sp),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),

                  SizedBox(height: 20.h),
                  // Use shrinkWrap ListView so it can live inside a SingleChildScrollView
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4.r,
                          offset: Offset(0, 2.h),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _isDoctor ? 6 : 5,
                      itemBuilder: (ctx, index) {
                        switch (index) {
                          case 0:
                            return ListTile(
                              leading: Icon(Icons.person),
                              title: Text('Account Settings'),
                              onTap: () {
                                _showFeatureSheet(
                                  context,
                                  'Account Settings',
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: Icon(Icons.edit),
                                        title: Text('Change Display Name'),
                                        onTap: () {
                                          Navigator.of(context).pop();
                                          final controller =
                                              TextEditingController(
                                                text: _name,
                                              );
                                          showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.vertical(
                                                    top: Radius.circular(16.r),
                                                  ),
                                            ),
                                            builder: (ctx) => Padding(
                                              padding: EdgeInsets.only(
                                                bottom: MediaQuery.of(
                                                  ctx,
                                                ).viewInsets.bottom,
                                              ),
                                              child: Padding(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 16.w,
                                                  vertical: 12.h,
                                                ),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      'Change Display Name',
                                                      style: TextStyle(
                                                        fontSize: 16.sp,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    SizedBox(height: 12.h),
                                                    TextField(
                                                      controller: controller,
                                                      decoration:
                                                          InputDecoration(
                                                            labelText: 'Name',
                                                          ),
                                                    ),
                                                    SizedBox(height: 12.h),
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.end,
                                                      children: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                ctx,
                                                              ).pop(),
                                                          child: Text('Cancel'),
                                                        ),
                                                        ElevatedButton(
                                                          onPressed: () {
                                                            setState(() {
                                                              _name = controller
                                                                  .text
                                                                  .trim();
                                                            });
                                                            Navigator.of(
                                                              ctx,
                                                            ).pop();
                                                          },
                                                          child: Text('Save'),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      ListTile(
                                        leading: Icon(Icons.link),
                                        title: Text('Manage Linked Accounts'),
                                        onTap: () {
                                          Navigator.of(context).pop();
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Manage Linked Accounts',
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          case 1:
                            return ListTile(
                              leading: Icon(Icons.notifications),
                              title: Text('Notifications'),
                              onTap: () {
                                _showFeatureSheet(
                                  context,
                                  'Notifications',
                                  StatefulBuilder(
                                    builder: (c, setStateLocal) {
                                      bool push = _pushNotifications;
                                      bool email = _emailNotifications;
                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SwitchListTile(
                                            title: Text('Push Notifications'),
                                            value: push,
                                            onChanged: (v) async {
                                              setStateLocal(() => push = v);
                                              await _setPushNotifications(v);
                                            },
                                          ),
                                          SwitchListTile(
                                            title: Text('Email Notifications'),
                                            value: email,
                                            onChanged: (v) async {
                                              setStateLocal(() => email = v);
                                              await _setEmailNotifications(v);
                                            },
                                          ),
                                          SizedBox(height: 8.h),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(context).pop(),
                                                child: Text('Close'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                );
                              },
                            );
                          case 2:
                            return ListTile(
                              leading: Icon(Icons.lock),
                              title: Text('Privacy'),
                              onTap: () {
                                _showFeatureSheet(
                                  context,
                                  'Privacy',
                                  StatefulBuilder(
                                    builder: (c, setState) {
                                      bool showProfile = false;
                                      bool analytics = true;
                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SwitchListTile(
                                            title: Text(
                                              'Show profile to others',
                                            ),
                                            value: showProfile,
                                            onChanged: (v) =>
                                                setState(() => showProfile = v),
                                          ),
                                          SwitchListTile(
                                            title: Text('Allow analytics'),
                                            value: analytics,
                                            onChanged: (v) =>
                                                setState(() => analytics = v),
                                          ),
                                          SizedBox(height: 8.h),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(c).pop(),
                                                child: Text('Close'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                );
                              },
                            );
                          case 3:
                            return ListTile(
                              leading: Icon(Icons.phone_android),
                              title: Text('Device'),
                              onTap: () {
                                _showFeatureSheet(
                                  context,
                                  'Device',
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: Icon(Icons.qr_code),
                                        title: Text('Scan QR Code'),
                                        onTap: () {
                                          // Navigate to your QR scanner route (ensure '/qrscanner' exists in your router)
                                          context.push('/authScanner');
                                        },
                                      ),
                                      SizedBox(height: 8.h),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(),
                                            child: Text('Close'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          case 4:
                            if (_isDoctor) {
                              return ListTile(
                                leading: Icon(Icons.access_time),
                                title: Text('Available Time'),
                                onTap: () async {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(16.r),
                                      ),
                                    ),
                                    builder: (ctx) {
                                      return Padding(
                                        padding: EdgeInsets.only(
                                          bottom: MediaQuery.of(
                                            ctx,
                                          ).viewInsets.bottom,
                                        ),
                                        child: FutureBuilder<List<Map<String, dynamic>>>(
                                          future: _readAvailableTimes(),
                                          builder: (fctx, snap) {
                                            if (!snap.hasData) {
                                              return SizedBox(
                                                height: 200.h,
                                                child: Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                ),
                                              );
                                            }
                                            final times =
                                                snap.data!; // local ref
                                            List<String?> errors =
                                                List<String?>.filled(
                                                  times.length,
                                                  null,
                                                );
                                            return Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 16.w,
                                                vertical: 12.h,
                                              ),
                                              child: StatefulBuilder(
                                                builder: (c, setStateLocal) {
                                                  return Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Center(
                                                        child: Container(
                                                          width: 36.w,
                                                          height: 4.h,
                                                          decoration: BoxDecoration(
                                                            color: Colors
                                                                .grey[300],
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  2.r,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(height: 12.h),
                                                      Text(
                                                        'Available Time',
                                                        style: TextStyle(
                                                          fontSize: 16.sp,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      SizedBox(height: 12.h),
                                                      ...List.generate(times.length, (
                                                        i,
                                                      ) {
                                                        final item = times[i];

                                                        // default times map — keys are numeric day strings '1'..'7'
                                                        const Map<
                                                          String,
                                                          Map<String, String>
                                                        >
                                                        _defaults = {
                                                          '1': {
                                                            'start': '08:00',
                                                            'end': '17:00',
                                                          },
                                                          '2': {
                                                            'start': '08:00',
                                                            'end': '17:00',
                                                          },
                                                          '3': {
                                                            'start': '08:00',
                                                            'end': '17:00',
                                                          },
                                                          '4': {
                                                            'start': '08:00',
                                                            'end': '17:00',
                                                          },
                                                          '5': {
                                                            'start': '08:00',
                                                            'end': '17:00',
                                                          },
                                                          '6': {
                                                            'start': '08:00',
                                                            'end': '17:00',
                                                          },
                                                          '7': {
                                                            'start': '08:00',
                                                            'end': '17:00',
                                                          },
                                                        };

                                                        // Resolve numeric day and human name
                                                        final rawDay =
                                                            (item['dayOfWeek'] ??
                                                                    '')
                                                                .toString();
                                                        int? dayNum =
                                                            int.tryParse(
                                                              rawDay,
                                                            );
                                                        if (dayNum == null) {
                                                          final lower = rawDay
                                                              .toLowerCase();
                                                          switch (lower) {
                                                            case 'monday':
                                                            case 'mon':
                                                              dayNum = 1;
                                                              break;
                                                            case 'tuesday':
                                                            case 'tue':
                                                              dayNum = 2;
                                                              break;
                                                            case 'wednesday':
                                                            case 'wed':
                                                              dayNum = 3;
                                                              break;
                                                            case 'thursday':
                                                            case 'thu':
                                                              dayNum = 4;
                                                              break;
                                                            case 'friday':
                                                            case 'fri':
                                                              dayNum = 5;
                                                              break;
                                                            case 'saturday':
                                                            case 'sat':
                                                              dayNum = 6;
                                                              break;
                                                            case 'sunday':
                                                            case 'sun':
                                                              dayNum = 7;
                                                              break;
                                                            default:
                                                              dayNum = null;
                                                          }
                                                        }

                                                        const names = [
                                                          'Monday',
                                                          'Tuesday',
                                                          'Wednesday',
                                                          'Thursday',
                                                          'Friday',
                                                          'Saturday',
                                                          'Sunday',
                                                        ];
                                                        // Show only the weekday name (for translation purposes)
                                                        final dayLabel =
                                                            dayNum != null &&
                                                                dayNum >= 1 &&
                                                                dayNum <= 7
                                                            ? names[dayNum - 1]
                                                            : (rawDay.isNotEmpty
                                                                  ? rawDay
                                                                  : 'Day');

                                                        final def =
                                                            _defaults[dayNum !=
                                                                        null &&
                                                                    dayNum >=
                                                                        1 &&
                                                                    dayNum <= 7
                                                                ? dayNum
                                                                      .toString()
                                                                : '1'] ??
                                                            {
                                                              'start': '08:00',
                                                              'end': '17:00',
                                                            };

                                                        // When the day is disabled, display the default times instead of stored times
                                                        final displayStart =
                                                            item['enabled'] ==
                                                                true
                                                            ? (item['start'] ??
                                                                      '00:00')
                                                                  .toString()
                                                            : def['start']!;
                                                        final displayEnd =
                                                            item['enabled'] ==
                                                                true
                                                            ? (item['end'] ??
                                                                      '00:00')
                                                                  .toString()
                                                            : def['end']!;

                                                        final startParts =
                                                            displayStart.split(
                                                              ':',
                                                            );
                                                        final endParts =
                                                            displayEnd.split(
                                                              ':',
                                                            );
                                                        final startTod = TimeOfDay(
                                                          hour:
                                                              int.tryParse(
                                                                startParts[0],
                                                              ) ??
                                                              0,
                                                          minute:
                                                              int.tryParse(
                                                                startParts.length >
                                                                        1
                                                                    ? startParts[1]
                                                                    : '0',
                                                              ) ??
                                                              0,
                                                        );
                                                        final endTod = TimeOfDay(
                                                          hour:
                                                              int.tryParse(
                                                                endParts[0],
                                                              ) ??
                                                              0,
                                                          minute:
                                                              int.tryParse(
                                                                endParts.length >
                                                                        1
                                                                    ? endParts[1]
                                                                    : '0',
                                                              ) ??
                                                              0,
                                                        );
                                                        return Column(
                                                          children: [
                                                            Padding(
                                                              padding:
                                                                  EdgeInsets.symmetric(
                                                                    vertical:
                                                                        8.h,
                                                                  ),
                                                              child: Row(
                                                                children: [
                                                                  // Day label on the left
                                                                  Expanded(
                                                                    child: Text(
                                                                      dayLabel,
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            14.sp,
                                                                        fontWeight:
                                                                            FontWeight.w500,
                                                                      ),
                                                                    ),
                                                                  ),

                                                                  // Time pickers in middle (disabled when day is off)
                                                                  AbsorbPointer(
                                                                    absorbing:
                                                                        item['enabled'] !=
                                                                        true,
                                                                    child: Row(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .min,
                                                                      children: [
                                                                        TextButton(
                                                                          style:
                                                                              item['enabled'] ==
                                                                                  true
                                                                              ? null
                                                                              : TextButton.styleFrom(
                                                                                  foregroundColor: Colors.grey,
                                                                                ),
                                                                          onPressed:
                                                                              item['enabled'] ==
                                                                                  true
                                                                              ? () async {
                                                                                  final picked = await showTimePicker(
                                                                                    context: ctx,
                                                                                    initialTime: startTod,
                                                                                  );
                                                                                  if (picked !=
                                                                                      null) {
                                                                                    if (!_isAllowed(
                                                                                      picked,
                                                                                    )) {
                                                                                      setStateLocal(
                                                                                        () => errors[i] = 'Time must be between 00:00 and 23:59',
                                                                                      );
                                                                                    } else {
                                                                                      setStateLocal(
                                                                                        () {
                                                                                          item['start'] = _format(
                                                                                            picked,
                                                                                          );
                                                                                          final currentEnd = _parseTime(
                                                                                            item['end'] ??
                                                                                                '00:00',
                                                                                          );
                                                                                          if (_toMinutes(
                                                                                                _parseTime(
                                                                                                  item['start'] ??
                                                                                                      '00:00',
                                                                                                ),
                                                                                              ) <
                                                                                              _toMinutes(
                                                                                                currentEnd,
                                                                                              )) {
                                                                                            errors[i] = null;
                                                                                          }
                                                                                        },
                                                                                      );
                                                                                    }
                                                                                  }
                                                                                }
                                                                              : null,
                                                                          child: Text(
                                                                            TimeOfDay(
                                                                              hour: startTod.hour,
                                                                              minute: startTod.minute,
                                                                            ).format(
                                                                              ctx,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                        Text(
                                                                          ' - ',
                                                                          style: TextStyle(
                                                                            color:
                                                                                item['enabled'] ==
                                                                                    true
                                                                                ? null
                                                                                : Colors.grey,
                                                                          ),
                                                                        ),
                                                                        TextButton(
                                                                          style:
                                                                              item['enabled'] ==
                                                                                  true
                                                                              ? null
                                                                              : TextButton.styleFrom(
                                                                                  foregroundColor: Colors.grey,
                                                                                ),
                                                                          onPressed:
                                                                              item['enabled'] ==
                                                                                  true
                                                                              ? () async {
                                                                                  final picked = await showTimePicker(
                                                                                    context: ctx,
                                                                                    initialTime: endTod,
                                                                                  );
                                                                                  if (picked !=
                                                                                      null) {
                                                                                    if (!_isAllowed(
                                                                                      picked,
                                                                                    )) {
                                                                                      setStateLocal(
                                                                                        () => errors[i] = 'Time must be between 00:00 and 23:59',
                                                                                      );
                                                                                    } else {
                                                                                      final currentStart = _parseTime(
                                                                                        item['start'] ??
                                                                                            '00:00',
                                                                                      );
                                                                                      if (_toMinutes(
                                                                                            currentStart,
                                                                                          ) >=
                                                                                          _toMinutes(
                                                                                            picked,
                                                                                          )) {
                                                                                        setStateLocal(
                                                                                          () => errors[i] = '${item['day']}: end must be after start',
                                                                                        );
                                                                                      } else {
                                                                                        setStateLocal(
                                                                                          () {
                                                                                            item['end'] = _format(
                                                                                              picked,
                                                                                            );
                                                                                            errors[i] = null;
                                                                                          },
                                                                                        );
                                                                                      }
                                                                                    }
                                                                                  }
                                                                                }
                                                                              : null,
                                                                          child: Text(
                                                                            TimeOfDay(
                                                                              hour: endTod.hour,
                                                                              minute: endTod.minute,
                                                                            ).format(
                                                                              ctx,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),

                                                                  // Switch at the end
                                                                  SizedBox(
                                                                    width: 8.w,
                                                                  ),
                                                                  Switch(
                                                                    value:
                                                                        item['enabled'] ==
                                                                        true,
                                                                    onChanged: (v) => setStateLocal(() {
                                                                      item['enabled'] =
                                                                          v;
                                                                      errors[i] =
                                                                          null;
                                                                      if (v ==
                                                                          true) {
                                                                        final s =
                                                                            (item['start'] ??
                                                                                    '00:00')
                                                                                .toString();
                                                                        final e =
                                                                            (item['end'] ??
                                                                                    '00:00')
                                                                                .toString();
                                                                        final startMin = _toMinutes(
                                                                          _parseTime(
                                                                            s,
                                                                          ),
                                                                        );
                                                                        final endMin = _toMinutes(
                                                                          _parseTime(
                                                                            e,
                                                                          ),
                                                                        );
                                                                        if ((s ==
                                                                                    '00:00' &&
                                                                                e ==
                                                                                    '00:00') ||
                                                                            startMin >=
                                                                                endMin) {
                                                                          item['start'] =
                                                                              '09:00';
                                                                          item['end'] =
                                                                              '17:00';
                                                                        }
                                                                      }
                                                                    }),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                            if (errors[i] !=
                                                                null) ...[
                                                              Padding(
                                                                padding:
                                                                    EdgeInsets.only(
                                                                      left:
                                                                          16.w,
                                                                      right:
                                                                          16.w,
                                                                      bottom:
                                                                          8.h,
                                                                    ),
                                                                child: Text(
                                                                  errors[i]!,
                                                                  style: TextStyle(
                                                                    color: Colors
                                                                        .red,
                                                                    fontSize:
                                                                        12.sp,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                            Divider(
                                                              height: 1.h,
                                                            ),
                                                          ],
                                                        );
                                                      }),
                                                      SizedBox(height: 8.h),
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .end,
                                                        children: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.of(
                                                                  ctx,
                                                                ).pop(),
                                                            child: Text(
                                                              'Close',
                                                            ),
                                                          ),
                                                          SizedBox(width: 8.w),
                                                          ElevatedButton(
                                                            onPressed: (() {
                                                              // compute whether current in-sheet values are valid
                                                              for (
                                                                var i = 0;
                                                                i <
                                                                    times
                                                                        .length;
                                                                i++
                                                              ) {
                                                                final item =
                                                                    times[i];
                                                                if (item['enabled'] ==
                                                                    true) {
                                                                  final start =
                                                                      _parseTime(
                                                                        item['start'] ??
                                                                            '00:00',
                                                                      );
                                                                  final end = _parseTime(
                                                                    item['end'] ??
                                                                        '00:00',
                                                                  );
                                                                  if (!_isAllowed(
                                                                        start,
                                                                      ) ||
                                                                      !_isAllowed(
                                                                        end,
                                                                      ))
                                                                    return null;
                                                                  if (_toMinutes(
                                                                        start,
                                                                      ) >=
                                                                      _toMinutes(
                                                                        end,
                                                                      ))
                                                                    return null;
                                                                }
                                                              }
                                                              // all good -> return the save handler
                                                              return () async {
                                                                // validate per-day and show inline messages
                                                                var hasError =
                                                                    false;
                                                                for (
                                                                  var i = 0;
                                                                  i <
                                                                      times
                                                                          .length;
                                                                  i++
                                                                ) {
                                                                  final item =
                                                                      times[i];
                                                                  errors[i] =
                                                                      null;
                                                                  if (item['enabled'] ==
                                                                      true) {
                                                                    final start =
                                                                        _parseTime(
                                                                          item['start'] ??
                                                                              '00:00',
                                                                        );
                                                                    final end = _parseTime(
                                                                      item['end'] ??
                                                                          '00:00',
                                                                    );
                                                                    if (!_isAllowed(
                                                                          start,
                                                                        ) ||
                                                                        !_isAllowed(
                                                                          end,
                                                                        )) {
                                                                      errors[i] =
                                                                          'Times must be within 00:00-23:59';
                                                                      hasError =
                                                                          true;
                                                                      continue;
                                                                    }
                                                                    if (_toMinutes(
                                                                          start,
                                                                        ) >=
                                                                        _toMinutes(
                                                                          end,
                                                                        )) {
                                                                      errors[i] =
                                                                          'End time must be after start time';
                                                                      hasError =
                                                                          true;
                                                                    }
                                                                  }
                                                                }
                                                                setStateLocal(
                                                                  () {},
                                                                );
                                                                if (hasError)
                                                                  return;
                                                                await _saveAvailableTimes(
                                                                  times,
                                                                );
                                                                if (mounted) {
                                                                  ScaffoldMessenger.of(
                                                                    context,
                                                                  ).showSnackBar(
                                                                    const SnackBar(
                                                                      content: Text(
                                                                        'Available times saved',
                                                                      ),
                                                                    ),
                                                                  );
                                                                }
                                                                Navigator.of(
                                                                  ctx,
                                                                ).pop();
                                                              };
                                                            })(),
                                                            child: Text('Save'),
                                                          ),
                                                        ],
                                                      ),
                                                      SizedBox(height: 8.h),
                                                    ],
                                                  );
                                                },
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            }
                            // fallthrough to logout for non-doctors (index 4 when not a doctor)
                            return ListTile(
                              leading: Icon(Icons.logout, color: Colors.red),
                              title: Text(
                                'Log Out',
                                style: TextStyle(color: Colors.red),
                              ),
                              onTap: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Confirm Log Out'),
                                    content: const Text(
                                      'Are you sure you want to log out?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(true),
                                        child: const Text('Log Out'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  // Capture ScaffoldMessenger before async gap
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );

                                  // Clear stored credentials and sign out
                                  await SecureAuth.clearCredentials();
                                  try {
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    await prefs.remove('available_times');
                                  } catch (_) {}
                                  try {
                                    await FirebaseAuth.instance.signOut();
                                  } catch (_) {}

                                  // Show snackbar using captured messenger if still mounted
                                  if (messenger.mounted) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Logged out'),
                                      ),
                                    );
                                  }

                                  // Navigate to the login page after logout if this State is still mounted
                                  if (!mounted) return;
                                  context.go('/login');
                                }
                              },
                            );
                          case 5:
                            // logout for doctors (index 5)
                            return ListTile(
                              leading: Icon(Icons.logout, color: Colors.red),
                              title: Text(
                                'Log Out',
                                style: TextStyle(color: Colors.red),
                              ),
                              onTap: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Confirm Log Out'),
                                    content: const Text(
                                      'Are you sure you want to log out?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(true),
                                        child: const Text('Log Out'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  // Capture ScaffoldMessenger before async gap
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );

                                  // Clear stored credentials and sign out
                                  await SecureAuth.clearCredentials();
                                  try {
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    await prefs.remove('available_times');
                                  } catch (_) {}
                                  try {
                                    await FirebaseAuth.instance.signOut();
                                  } catch (_) {}

                                  // Show snackbar using captured messenger if still mounted
                                  if (messenger.mounted) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Logged out'),
                                      ),
                                    );
                                  }

                                  // Navigate to the login page after logout if this State is still mounted
                                  if (!mounted) return;
                                  context.go('/login');
                                }
                              },
                            );
                        }
                      },
                      separatorBuilder: (ctx, idx) => Divider(
                        height: 1.h,
                        thickness: 1,
                        color: Colors.grey.shade300,
                        indent: 16.w,
                        endIndent: 16.w,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
