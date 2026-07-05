import 'dart:async';
import 'dart:convert';

import 'package:carelink_mobile/utils/greeting_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:carelink_mobile/utils/user_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:carelink_mobile/components/home_service.dart';
import 'package:carelink_mobile/components/next_task_card.dart';
import 'package:lottie/lottie.dart';
// removed unused import: care_recipient emergency screen not referenced here

// Private model for carousel tasks
class _TaskItem {
  final String id;
  final String time;
  final String title;
  final String upcomingTitle;
  final String? subtitle;
  final String? dosage;
  final String? frequencyNote;
  final IconData icon;
  final String rightInfo;
  bool completed = false;
  bool pending = false;

  _TaskItem({
    required this.id,
    required this.time,
    required this.title,
    String? upcomingTitle,
    this.subtitle,
    this.frequencyNote,
    this.dosage,
    required this.icon,
    required this.rightInfo,
  }) : upcomingTitle = upcomingTitle ?? 'Upcoming Medication';
}

class CareRecipientHomePage extends StatefulWidget {
  const CareRecipientHomePage({super.key});

  @override
  State<CareRecipientHomePage> createState() => _CareRecipientHomePageState();
}

class _CareRecipientHomePageState extends State<CareRecipientHomePage>
    with SingleTickerProviderStateMixin {
  bool _avatarPressed = false;
  String? _displayName;

  late DateTime _now;
  Timer? _timer;
  Timer? _clockTimer;
  Timer? _tasksTimer;
  bool _isLoadingTasks = false;
  // Help button state
  bool _helpActive = false;
  static const int _helpDurationSeconds = 3;
  DateTime? _helpStart;
  Timer? _helpTicker;
  double _helpProgress = 0.0; // 0.0..1.0
  final ValueNotifier<int> _helpCountdownNotifier = ValueNotifier<int>(
    _helpDurationSeconds,
  );
  bool _helpDialogVisible = false;

  // Carousel indicator state
  int _currentCarouselIndex = 0;

  // Stateful list of upcoming tasks shown in the carousel (populated from GraphQL)
  final List<_TaskItem> _tasks = [];

  // GraphQL query to fetch upcoming tasks for current user
  // NOTE: Adjust this query to match your server's reminders field signature.
  // Some GraphQL schemas accept filter input (e.g. `where`), others accept
  // plain arguments. The server previously returned a validation error for
  // `where`, so try passing `userId` and `status` directly.
  static const String _upcomingTasksQuery = r'''
  query Reminders($userId: ID, $status: String) {
  reminders(userId: $userId, status: $status) {
    id
    scheduledAt
    status
    medication { id name description strength }
    medicationPrescription { id medicationId dosageAmount startDate endDate status frequencyNote}
  }
}
  ''';

  // Load upcoming tasks from GraphQL, map into _TaskItem list
  Future<void> _loadTasks() async {
    if (_isLoadingTasks) return;
    _isLoadingTasks = true;
    try {
      final client = GraphQLProvider.of(context).value;

      // Try to resolve server-side user id from current Firebase uid.
      String? backendUserId;
      try {
        if (_clientId != null && _clientId!.isNotEmpty) {
          backendUserId = await fetchUserIdByUid(_clientId!);
        }
      } catch (e) {
        debugPrint('loadTasks: fetchUserIdByUid failed: $e');
      }

      final variables = {
        'userId': backendUserId ?? _clientId ?? 'CR-071',
        'status': 'sent',
      };

      final result = await client.query(
        QueryOptions(
          document: gql(_upcomingTasksQuery),
          variables: variables,
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );
      if (result.hasException) {
        debugPrint('loadTasks: GraphQL exception: ${result.exception}');
        return;
      }
      final List<dynamic>? items = result.data?['reminders'] as List<dynamic>?;
      if (items == null) return;
      final List<_TaskItem> loaded = items.map((raw) {
        final Map<String, dynamic> map = Map<String, dynamic>.from(raw as Map);
        // Map GraphQL fields to TaskItem fields, prefer medication details
        final String scheduledAt = map['scheduledAt']?.toString() ?? '';
        final String status = map['status']?.toString() ?? '';

        final dynamic medRaw = map['medication'];

        final dynamic medPreRaw = map['medicationPrescription'];

        final Map<String, dynamic>? med = medRaw is Map
            ? Map<String, dynamic>.from(medRaw)
            : null;
        final String medName = med?['name']?.toString() ?? '';
        final String medDesc = med?['description']?.toString() ?? '';
        final String medStrength = med?['strength']?.toString() ?? '';

        // medicationPrescription may be an object or a list — handle both
        Map<String, dynamic>? medPre;
        if (medPreRaw is Map) {
          medPre = Map<String, dynamic>.from(medPreRaw);
        } else if (medPreRaw is List && medPreRaw.isNotEmpty) {
          medPre = Map<String, dynamic>.from(medPreRaw.first as Map);
        } else if (medPreRaw is String && medPreRaw.isNotEmpty) {
          try {
            medPre = Map<String, dynamic>.from(json.decode(medPreRaw) as Map);
          } catch (_) {
            medPre = null;
          }
        } else {
          medPre = null;
        }
        // Safely build dosage string from prescription and medication unit.
        final String dosageVal = medPre?['dosageAmount']?.toString() ?? '';

        final String unitVal = medPre?['standardUnit']?.toString() ?? med?['standardUnit']?.toString() ?? 'Capsule';
        final String medPreDosageAmount =
          dosageVal.isNotEmpty ? '$dosageVal $unitVal' : '1 $unitVal';
        // Build a short frequency/note string from prescription dates or status
        String medFrequencyNote = medPre?['FrequencyNote']?.toString() ?? '';

        if (medPre != null) {
          // Prefer an explicit frequencyNote field if server provides it
          final String fromField = medPre['frequencyNote']?.toString() ?? '';
          if (fromField.isNotEmpty) {
            medFrequencyNote = fromField;
          } else {
            final String start = medPre['startDate']?.toString() ?? '';
            final String end = medPre['endDate']?.toString() ?? '';
            final String preStatus = medPre['status']?.toString() ?? '';
            if (start.isNotEmpty || end.isNotEmpty) {
              if (start.isNotEmpty && end.isNotEmpty) {
                medFrequencyNote = 'Active: ${start.split('T').first} → ${end.split('T').first}';
              } else if (start.isNotEmpty) {
                medFrequencyNote = 'Starts: ${start.split('T').first}';
              } else {
                medFrequencyNote = 'Ends: ${end.split('T').first}';
              }
            } else if (preStatus.isNotEmpty) {
              medFrequencyNote = 'Status: $preStatus';
            }
          }
        }
        // If still empty, try to extract from reminder payload if present
        if (medFrequencyNote.isEmpty && map['payload'] != null) {
          try {
            final dynamic p = map['payload'];
            if (p is Map && p['frequencyNote'] != null) {
              medFrequencyNote = p['frequencyNote'].toString();
            } else if (p is String && p.isNotEmpty) {
              final parsed = json.decode(p);
              if (parsed is Map && parsed['frequencyNote'] != null) {
                medFrequencyNote = parsed['frequencyNote'].toString();
              }
            }
          } catch (_) {}
        }
        final String medPreStartDate = medPre?['startDate']?.toString() ?? '';
        final String medPreEndDate = medPre?['endDate']?.toString() ?? '';
        final String medPreStatus = medPre?['status']?.toString() ?? '';

        // Format scheduled time/date for display.
        // Support ISO strings with timezone and numeric epoch timestamps.
        DateTime parsed;
        final DateTime? tryIso = DateTime.tryParse(scheduledAt);
        if (tryIso != null) {
          parsed = tryIso.toLocal();
        } else {
          // try parse as integer epoch (seconds or milliseconds)
          DateTime? fromEpoch;
          try {
            final n = int.parse(scheduledAt);
            // if length > 10 assume milliseconds
            if (n.abs().toString().length > 10) {
              fromEpoch = DateTime.fromMillisecondsSinceEpoch(
                n,
                isUtc: true,
              ).toLocal();
            } else {
              fromEpoch = DateTime.fromMillisecondsSinceEpoch(
                n * 1000,
                isUtc: true,
              ).toLocal();
            }
          } catch (_) {
            fromEpoch = null;
          }
          parsed = fromEpoch ?? DateTime.now();
        }

        final String timeStr = _formatTime(parsed);
        // include timezone offset (e.g. +08:00) so users know the zone
        final off = parsed.timeZoneOffset;
        final String tzSign = off.isNegative ? '-' : '+';
        final String tzHours = off.inHours.abs().toString().padLeft(2, '0');
        final String tzMinutes = (off.inMinutes.abs() % 60).toString().padLeft(
          2,
          '0',
        );
        final String tzOffset = 'GMT$tzSign$tzHours:$tzMinutes';
        final String dateStr = '${_formatDate(parsed)} ($tzOffset)';

        // Build a concise subtitle from strength and description
        final List<String> subtitleParts = [];
        if (medStrength.isNotEmpty) subtitleParts.add(medStrength);
        if (medDesc.isNotEmpty) subtitleParts.add(medDesc);
        final String? subtitle = subtitleParts.isNotEmpty
            ? subtitleParts.join(' • ')
            : null;

        final String titleText = medName.isNotEmpty
            ? medName
            : (status.isNotEmpty ? status : 'Reminder');

        return _TaskItem(
          id: map['id']?.toString() ?? UniqueKey().toString(),
          upcomingTitle: 'Medication Reminder',
          time: timeStr,
          title: titleText,
          subtitle: subtitle,
          frequencyNote: medFrequencyNote.isNotEmpty ? medFrequencyNote : null,
          dosage: medPreDosageAmount,
          icon: Icons.medication,
          rightInfo: dateStr,
        );
      }).toList();
      if (mounted) {
        setState(() {
          _tasks.clear();
          _tasks.addAll(loaded);
          _currentCarouselIndex = 0;
        });
      }
    } catch (e) {
      debugPrint('loadTasks failed: $e');
    } finally {
      _isLoadingTasks = false;
    }
  }

  // Pending timers per task id so we can cancel countdowns
  final Map<String, Timer> _pendingTimers = {};

  // Mark a task done: after 5s turn it green then remove it.
  void _markDoneAt(int index) {
    if (index < 0 || index >= _tasks.length) return;
    final task = _tasks[index];
    if (task.completed) return;

    // mark as pending immediately (shows countdown/pending UI)
    setState(() => task.pending = true);

    // Start 5 second delay, then mark as completed briefly and remove
    final timer = Timer(const Duration(seconds: 5), () async {
      // remove timer ref
      _pendingTimers.remove(task.id);
      if (!mounted) return;
      setState(() {
        task.pending = false;
        task.completed = true;
      });

      // show green state for 5 seconds then remove
      // Call backend to mark reminder as completed (fire GraphQL mutation)
      try {
        final client = GraphQLProvider.of(context).value;
        const String markCompletedMutation = r'''
        mutation MarkReminderCompleted($id: ID!) {
          mark_reminder_completed(id: $id) {
            id
            status
            firedAt
          }
        }
        ''';
        final res = await client.mutate(MutationOptions(
          document: gql(markCompletedMutation),
          variables: {'id': task.id},
          fetchPolicy: FetchPolicy.networkOnly,
        ));
        if (res.hasException) {
          debugPrint('markReminderCompleted mutation failed: ${res.exception}');
        }
      } catch (e) {
        debugPrint('markReminderCompleted error: $e');
      }

      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;
      setState(() {
        // remove the task
        _tasks.removeWhere((t) => t.id == task.id);
        // adjust current index if needed
        if (_currentCarouselIndex >= _tasks.length) {
          _currentCarouselIndex = _tasks.isEmpty ? 0 : _tasks.length - 1;
        }
      });
    });

    // store timer so it can be cancelled by user
    _pendingTimers[task.id] = timer;
  }

  // Cancel a pending countdown for the task at [index]
  void _cancelPendingAt(int index) {
    if (index < 0 || index >= _tasks.length) return;
    final task = _tasks[index];
    final timer = _pendingTimers.remove(task.id);
    if (timer != null && timer.isActive) timer.cancel();
    if (mounted) setState(() => task.pending = false);
  }

  static const List<String> _monthAbbr = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  //help me fetchCurrentUser from user_service.dart
  String _username = ''; // populated from backend
  String? _clientId;
  final bool _isCalling = false;
  String? _caregiverClientId;
  // TODO: replace with configured/assigned caregiver id from backend

  Future<void> _loadCurrentUser() async {
    try {
      final user = await fetchCurrentUser();
      if (!mounted) return;
      if (user != null) {
        // Prefer displayName, fall back to email or uid
        final name = (user['displayName'] as String?)?.trim();
        final id = (user['id'] as String?)?.trim();
        final email = (user['email'] as String?)?.trim();
        final uid = (user['uid'] as String?)?.trim();

        final chosenId = uid ?? id ?? '';
        setState(() {
          _username = name?.isNotEmpty == true
              ? name!
              : (email?.isNotEmpty == true ? email! : (user['uid'] ?? ''));
          _clientId = uid ?? user['uid'] as String?;
          _caregiverClientId = chosenId.isNotEmpty ? chosenId : null;
        });
        // initialize emergency calling helper for this client
      }
    } catch (e) {
      debugPrint('Error loading current user: $e');
    }
  }

  // Use the signaling server reachable by the mobile device on your LAN.
  // Prefer configuration via environment variable `RTC_URL`.
  // Example fallback: ws://10.180.12.100:25101
  // NOTE: on Android emulators use 10.0.2.2 to reach host machine's localhost.
  final String? _signalingUrl = dotenv.env['RTC_URL'];

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute$ampm';
  }

  String _formatDate(DateTime dt) {
    return '${dt.day} ${_monthAbbr[dt.month]} ${dt.year}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage('assets/images/home.jpg'), context);
    });

    _now = DateTime.now();
    _clockTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });

    // Fetch displayName once; recompute greeting on each rebuild using _now.
    fetchCurrentUser().then((user) {
      debugPrint('caregiver_home_page: fetchCurrentUser returned: $user');
      final name = user?['displayName'] as String?;
      debugPrint('caregiver_home_page: raw displayName = "$name"');
      if (!mounted) return;
      if ((name ?? '').trim().isNotEmpty) {
        setState(() => _displayName = name!.trim());
      } else {
        debugPrint('caregiver_home_page: displayName empty or missing');
      }
    });

    // Load current user and then load upcoming tasks from GraphQL
    _loadCurrentUser().then((_) async {
      await _loadTasks();
      _tasksTimer?.cancel();
      _tasksTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (!mounted) return;
        _loadTasks();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clockTimer?.cancel();
    _tasksTimer?.cancel();
    _helpTicker?.cancel();
    // cancel any pending task timers
    for (final t in _pendingTimers.values) {
      if (t.isActive) t.cancel();
    }
    _helpCountdownNotifier.dispose();
    super.dispose();
  }

  void _onHelpPressedDown() {
    if (_helpActive) return;
    setState(() => _helpActive = true);
    // Defer setting the notifier value until after the current frame so
    // that the dialog's ValueListenableBuilder has been built and the
    // framework is not locked when the notifier notifies listeners.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _helpCountdownNotifier.value = _helpDurationSeconds;
    });
    _helpDialogVisible = true;

    // show non-dismissible countdown dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            content: SizedBox(
              height: 120.h,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 60.w,
                    height: 60.w,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: _helpProgress,
                          strokeWidth: 6.w,
                          color: Colors.red.shade400,
                          backgroundColor: Colors.red.shade100,
                        ),
                        ValueListenableBuilder<int>(
                          valueListenable: _helpCountdownNotifier,
                          builder: (context, value, _) => Text(
                            '$value',
                            style: TextStyle(
                              fontSize: 28.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text('Sending help in', style: TextStyle(fontSize: 14.sp)),
                ],
              ),
            ),
          ),
        );
      },
    );

    // start real-time ticker
    _helpStart = DateTime.now();
    _helpProgress = 0.0;
    _helpTicker?.cancel();
    _helpTicker = Timer.periodic(const Duration(milliseconds: 100), (t) {
      final now = DateTime.now();
      final elapsedMs = now.difference(_helpStart!).inMilliseconds;
      final totalMs = _helpDurationSeconds * 1000;
      final progress = elapsedMs / totalMs;
      if (progress >= 1.0) {
        _helpProgress = 1.0;
        _helpCountdownNotifier.value = 0;
        t.cancel();
        _helpTicker = null;
        _helpDialogVisible = false;
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          SystemSound.play(SystemSoundType.alert);
          // navigate to the care recipient emergency call route
          Future.delayed(const Duration(milliseconds: 200), () {
            if (!mounted) return;
            try {
              context.push('/carerecipientemergencycall');
            } catch (e) {
              debugPrint('Navigation to emergency route failed: $e');
            }
          });

          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _helpActive = false);
          });
        }
      } else {
        _helpProgress = progress.clamp(0.0, 1.0);
        final remaining =
            (_helpDurationSeconds - (progress * _helpDurationSeconds)).ceil();
        _helpCountdownNotifier.value = remaining.clamp(0, _helpDurationSeconds);
      }
      // ensure UI updates for progress
      if (mounted) setState(() {});
    });
  }

  void _onHelpReleased() {
    if (!_helpActive) return;
    _helpTicker?.cancel();
    _helpTicker = null;
    _helpStart = null;
    _helpProgress = 0.0;
    _helpCountdownNotifier.value = _helpDurationSeconds;
    if (_helpDialogVisible) {
      _helpDialogVisible = false;
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
    if (mounted) setState(() => _helpActive = false);
  }

  Widget _buildTile({
    required IconData icon,
    required String label,
    int? badge,
    bool showDot = false,
    VoidCallback? onTap,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // per-tile hover notifier to toggle border appearance on desktop/web
            (() {
              final hover = ValueNotifier<bool>(false);
              return ValueListenableBuilder<bool>(
                valueListenable: hover,
                builder: (context, isHover, _) {
                  return Container(
                    width: constraints.maxWidth,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16.w),
                      border: Border.all(
                        color: isHover ? Colors.orange : Colors.grey.shade300,
                        width: isHover ? 1.6.w : 1.w,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x11000000),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.w),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16.w),
                        splashColor: Colors.grey.withOpacity(0.18),
                        highlightColor: Colors.grey.withOpacity(0.08),
                        onTap: onTap ?? () {},
                        onHover: (hovering) => hover.value = hovering,
                        onHighlightChanged: (active) => hover.value = active,
                        child: Padding(
                          padding: EdgeInsets.all(14.w),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 48.w,
                                height: 48.w,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAF4EE),
                                  borderRadius: BorderRadius.circular(12.w),
                                ),
                                child: Icon(
                                  icon,
                                  size: 26.w,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 10.h),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            })(),
            if (badge != null && badge > 0)
              Text('waitting to solve')
            // Positioned(
            //   right: -6.w,
            //   top: -6.w,
            //   child: Container(
            //     padding: EdgeInsets.all(6.w),
            //     decoration: BoxDecoration(
            //       color: Colors.redAccent,
            //       shape: BoxShape.circle,
            //       border: Border.all(color: Colors.white, width: 1.5),
            //     ),
            //     child: Text(
            //       badge > 99 ? '99+' : badge.toString(),
            //       style: TextStyle(
            //         color: Colors.white,
            //         fontSize: 10.sp,
            //         fontWeight: FontWeight.bold,
            //       ),
            //     ),
            //   ),
            // )
            else if (showDot)
              Positioned(
                right: -6.w,
                top: -6.w,
                child: Container(
                  width: 12.w,
                  height: 12.w,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.2),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeString = _formatTime(_now);
    final dateString = _formatDate(_now);

    // carousel items are built from the stateful `_tasks` list below

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AnimatedScale(
                    scale: _avatarPressed ? 0.9 : 1.0,
                    duration: const Duration(milliseconds: 120),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(40),
                      onTapDown: (_) => setState(() => _avatarPressed = true),
                      onTapCancel: () => setState(() => _avatarPressed = false),
                      onTapUp: (_) => setState(() => _avatarPressed = false),
                      onTap: () => context.push('/profile'),
                      child: CircleAvatar(
                        radius: 20.r,
                        backgroundImage: const NetworkImage(
                          'https://i.pravatar.cc/150?img=3',
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    formatGreeting(_now, displayName: _displayName),
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatTime(_now),
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatDate(_now),
                        style: TextStyle(fontSize: 12.sp),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              Text(
                "Upcoming Reminder",
                style: TextStyle(
                  fontSize: 25.sp,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      offset: Offset(2.0, 2.0),
                      blurRadius: 10.0,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),

              // Next Task cards as a carousel with indicators
              SizedBox(
                height: 290.h,
                child: Column(
                  children: [
                    if (_tasks.isNotEmpty) ...[
                      CarouselSlider(
                        options: CarouselOptions(
                          height: 270.h,
                          enlargeCenterPage: true,
                          viewportFraction: 0.92,
                          enableInfiniteScroll: false,
                          autoPlay: false,
                          onPageChanged: (index, reason) {
                            if (mounted) {
                              setState(() => _currentCarouselIndex = index);
                            }
                          },
                        ),
                        items: _tasks.asMap().entries.map((entry) {
                          final i = entry.key;
                          final t = entry.value;
                          return NextTaskCard(
                            upcomingTitle: t.upcomingTitle,
                            time: t.time,
                            title: t.title,
                            subtitle: t.subtitle ?? '',
                            frequencyNote: t.frequencyNote,
                            dosage: t.dosage ?? '',
                            icon: t.icon,
                            rightInfo: t.rightInfo,
                            completed: t.completed,
                            pending: t.pending,
                            onMarkDone: () => _markDoneAt(i),
                            onCancel: () => _cancelPendingAt(i),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_tasks.length, (i) {
                          final active = i == _currentCarouselIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: EdgeInsets.symmetric(horizontal: 4.w),
                            width: active ? 18.w : 8.w,
                            height: 8.h,
                            decoration: BoxDecoration(
                              color: active
                                  ? Colors.red.shade400
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(4.w),
                            ),
                          );
                        }),
                      ),
                    ] else ...[
                      Container(
                        height: 290.h,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFFFF4EE), Color(0xFFFFE0CC)],
                          ),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.25),
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.25),
                              blurRadius: 14,
                            ),
                          ],
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 88.w,
                                height: 88.w,
                                child: Lottie.asset(
                                  'assets/animations/thumb_up.json',
                                  width: 200.w,
                                  height: 200.w,
                                  repeat: true,
                                  animate: true,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Flexible(
                                child: Text(
                                  'No Upcoming Reminders Found',
                                  style: TextStyle(
                                    fontSize: 20.sp,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(height: 8.h),

              Text(
                'Services',
                style: TextStyle(
                  fontSize: 25.sp,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      offset: Offset(2.0, 2.0),
                      blurRadius: 10.0,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8.h),

              // Grid tiles
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12.w,
                mainAxisSpacing: 12.h,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.15,
                children: [
                  buildServiceCard(
                    HomeService(
                      title: 'Medical Report',
                      subtitle: '',
                      icon: Icons.description_outlined,
                      color: Colors.teal,
                      onTap: () => context.push('/medicalreportviewer'),
                    ),
                  ),
                  buildServiceCard(
                    HomeService(
                      title: 'Medication',
                      subtitle: '',
                      icon: Icons.medication,
                      color: Colors.blue,
                      onTap: () => context.push('/medication'),
                    ),
                  ),
                  buildServiceCard(
                    HomeService(
                      title: 'Caregiver',
                      subtitle: '',
                      icon: Icons.person_outline,
                      color: Colors.purple,
                      onTap: () => context.push('/managecaregiver'),
                    ),
                  ),
                  buildServiceCard(
                    HomeService(
                      title: 'Appointment',
                      subtitle: '',
                      icon: Icons.event,
                      color: Colors.indigo,
                      onTap: () => context.push('/showappointment'),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 22.h),

              // HELP button
              SizedBox(
                width: double.infinity,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (_) => _onHelpPressedDown(),
                  onPointerUp: (_) => _onHelpReleased(),
                  onPointerCancel: (_) => _onHelpReleased(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    decoration: BoxDecoration(
                      color: _helpActive ? Colors.red.shade600 : Colors.white,
                      border: Border.all(
                        color: Colors.red.shade400,
                        width: 2.w,
                      ),
                      borderRadius: BorderRadius.circular(12.w),
                    ),
                    child: Center(
                      child: Text(
                        'HELP!',
                        style: TextStyle(
                          color: _helpActive
                              ? Colors.white
                              : Colors.red.shade600,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
