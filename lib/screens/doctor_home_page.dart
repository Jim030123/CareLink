import 'dart:async';
import 'dart:ffi';

import 'package:carelink_mobile/components/ai_chat_box.dart';
import 'package:carelink_mobile/components/home_calendar.dart';
import 'package:carelink_mobile/components/home_service.dart';
import 'package:carelink_mobile/utils/greeting_service.dart';
import 'package:carelink_mobile/utils/secure_auth.dart';
import 'package:carelink_mobile/utils/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:carelink_mobile/components/app_footer.dart';

class DoctorHomePage extends StatefulWidget {
  const DoctorHomePage({super.key});

  @override
  State<DoctorHomePage> createState() => _DoctorHomePageState();
}

class _DoctorHomePageState extends State<DoctorHomePage> {
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

  final String _username = '';
  late DateTime _now;
  late Timer _clockTimer;
  late final List<HomeService> services;
  bool _avatarPressed = false;
  String? _displayName;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();

    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });

    services = [
      HomeService(
        title: 'Medication Handbook',
        subtitle: 'Learn about medications',
        icon: Icons.book,
        color: Colors.blue,
        onTap: () => context.push('/medication'),
      ),
      HomeService(
        title: 'Prescription',
        subtitle: 'Manage prescriptions',
        icon: Icons.medical_information,
        color: Colors.green,
        onTap: () => context.push('/prescription'),
      ),
      HomeService(
        title: 'Appointment',
        subtitle: 'Manage appointments',
        icon: Icons.event,
        color: Colors.yellow,
        onTap: () => context.push('/addAppointment'),
      ),
    ];

    fetchCurrentUser().then((user) {
      debugPrint('doctor_home_page: fetchCurrentUser returned: $user');
      final name = user?['displayName'] as String?;
      debugPrint('caregiver_home_page: raw displayName = "$name"');
      if (!mounted) return;
      if ((name ?? '').trim().isNotEmpty) {
        setState(() => _displayName = name!.trim());
      } else {
        debugPrint('doctor_home_page: displayName empty or missing');
      }
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  String _formatDate(DateTime dt) {
    return '${dt.day} ${_monthAbbr[dt.month]} ${dt.year}';
  }

  bool appointment = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// ================= HEADER =================
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // tappable avatar with press animation + ripple
                      Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTapDown: (_) =>
                              setState(() => _avatarPressed = true),
                          onTapCancel: () =>
                              setState(() => _avatarPressed = false),
                          onTapUp: (_) =>
                              setState(() => _avatarPressed = false),
                          onTap: () {
                            setState(() => _avatarPressed = false);
                            context.push('/profile');
                          },
                          child: Padding(
                            padding: EdgeInsets.all(4.r),
                            child: CircleAvatar(
                              radius: 20.r,
                              child: Text(
                                (_displayName ?? '')
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
                              fontSize: 26.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _formatDate(_now),
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(width: 8.w),
                    ],
                  ),



                  SizedBox(height: 20.h),
                  HomeCalendar(),
                  SizedBox(height: 20.h),

                  appointment
                      ? _buildUpcomingAppointment()
                      : _buildNoAppointment(),

                  SizedBox(height: 20.h),
                  Text(
                    'Services',
                    style: TextStyle(
                      fontSize: 25.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 20.h),

                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12.w,
                    mainAxisSpacing: 12.h,
                    childAspectRatio: 1.15,
                    children: services.map(buildServiceCard).toList(),
                  ),

                  /// ================= UPCOMING FEATURES =================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Upcoming Features',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextButton(
                        onPressed: null,
                        child: const Text('Coming in V 2.0'),
                      ),
                    ],
                  ),

                  SizedBox(height: 16.h),

                  SizedBox(
                    height: 128.h,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildFeatureCard(
                          'Teleappointment',
                          'Video consults',
                          Icons.video_call_outlined,
                          Colors.purple,
                        ),
                        _buildFeatureCard(
                          'Analytics',
                          'Patient trends',
                          Icons.insights_outlined,
                          Colors.teal,
                        ),
                        _buildFeatureCard(
                          'Notes',
                          'Patient notes',
                          Icons.note_alt_outlined,
                          Colors.indigo,
                        ),
                        _buildFeatureCard(
                          'Inventory',
                          'Medication stock',
                          Icons.inventory_2_outlined,
                          Colors.orange,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16.h),

                  const AppFooter(),
                ],
              ),
            ),

            // Right-edge vertical AI button stack (centered vertically)
            Positioned.fill(
              child: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: EdgeInsets.only(right: 32.w, bottom: 64.h),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildAiFab(
                        icon: Icons.auto_awesome,
                        label: 'AI Chat',
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => DraggableScrollableSheet(
                              expand: false,
                              initialChildSize: 0.7,
                              minChildSize: 0.3,
                              maxChildSize: 0.95,
                              builder: (_, controller) => Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(16.w),
                                  ),
                                ),
                                child: AIChatBox(),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingAppointment() {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF4EE), Color(0xFFFFE0CC)],
        ),
        border: Border.all(color: Colors.orange.shade300, width: 2.w),
        borderRadius: BorderRadius.circular(12.w),
        boxShadow: [
          BoxShadow(color: Colors.orange.withOpacity(0.25), blurRadius: 14.r),
        ],
      ),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.orange.shade700, Colors.orange.shade300],
            ).createShader(bounds),
            blendMode: BlendMode.srcIn,
            child: Icon(Icons.calendar_month, size: 72.w, color: Colors.white),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Upcoming Appointment',
                  style: TextStyle(color: Colors.black54),
                ),
                const Text(
                  '12 Dec 2025',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text('Patient: John Doe'),
                const Text(
                  'City Clinic — Room 3',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
          Column(
            children: [
              const Text('2:30 PM'),
              ElevatedButton(onPressed: () {}, child: const Text('View')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoAppointment() {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF4EE), Color(0xFFFFE0CC)],
        ),
        border: Border.all(color: Colors.orange.shade300, width: 2.w),

        borderRadius: BorderRadius.circular(12.w),
        boxShadow: [
          BoxShadow(color: Colors.orange.withOpacity(0.25), blurRadius: 14),
        ],
      ),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.orange.shade900, Colors.orange.shade100],
            ).createShader(bounds),
            blendMode: BlendMode.srcIn,
            child: Icon(Icons.calendar_month, size: 72.w, color: Colors.white),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'No Upcoming Appointments',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 220.w,
      margin: EdgeInsets.only(right: 12.w),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.w),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28.w),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
          const Text('Soon'),
        ],
      ),
    );
  }

  Widget _buildAiFab({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28.w),
        child: Container(
          width: 52.w,
          height: 52.w,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF5B21B6), Color(0xFF9B51E0)],
              ).createShader(bounds),
              blendMode: BlendMode.srcIn,
              child: Icon(icon, size: 24.w, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    await SecureAuth.clearCredentials();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    context.go('/login');
  }
}
