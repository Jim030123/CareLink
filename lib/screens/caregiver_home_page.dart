import 'package:carelink_mobile/components/app_footer.dart';
import 'package:carelink_mobile/components/home_calendar.dart';
import 'package:carelink_mobile/components/home_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:math';
import 'dart:async';
import 'package:carelink_mobile/components/health_card.dart';
import 'package:carelink_mobile/components/ai_chat_box.dart';
import 'package:go_router/go_router.dart';
import 'package:carelink_mobile/utils/greeting_service.dart';
import 'package:carelink_mobile/utils/user_service.dart';

class CaregiverHomePage extends StatefulWidget {
  const CaregiverHomePage({super.key});

  @override
  State<CaregiverHomePage> createState() => _CaregiverHomePageState();
}

class _CaregiverHomePageState extends State<CaregiverHomePage> {
  late DateTime _now;
  late Timer _clockTimer;
  bool _avatarPressed = false;

  late final List<HomeService> services;
  String? _displayName;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage('assets/images/home.jpg'), context);
    });

    services = [

      HomeService(
        title: 'Medication',
        subtitle: '',
        icon: Icons.medication,
        color: Colors.blue,
        onTap: () => context.push('/medication'),
      ),
      HomeService(
        title: 'Remote Monitor',
        subtitle: '',
        icon: Icons.devices,
        color: Colors.green,
        onTap: () {},
      ),
      HomeService(
        title: 'Manage Caregiver',
        subtitle: '',
        icon: Icons.group,
        color: Colors.purple,
        onTap: () => context.push('/managecaregiver'),
      ),
      HomeService(
        title: 'Manage Care Recipient',
        subtitle: '',
        icon: Icons.people,
        color: Colors.orange,
        onTap: () => context.push('/managecarerecipient'),
      ),
      HomeService(
        title: 'Activity',
        subtitle: '',
        icon: Icons.directions_run,
        color: Colors.teal,
        onTap: () => context.push('/caregiveremergencycall'),
      ),
    ];

    _now = DateTime.now();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// ===== HEADER =====
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
              HomeCalendar(),

              SizedBox(height: 16.h),

              Text(
                'Health Tracking',
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
              Row(
                children: const [
                  Expanded(
                    child: Column(
                      children: [
                        HealthCard(
                          title: 'Heart Rate',
                          value: '149',
                          icon: Icons.favorite_outline_outlined,
                        ),
                        SizedBox(height: 8),
                        HealthCard(
                          title: 'Energy Score',
                          value: '81',
                          icon: Icons.sports_martial_arts_outlined,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        HealthCard(
                          title: 'Blood Oxygen',
                          value: '93',
                          icon: Icons.bloodtype_outlined,
                        ),
                        SizedBox(height: 8),
                        HealthCard(
                          title: 'Sleep Score',
                          value: '73',
                          icon: Icons.bedtime_outlined,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16.h),

              /// ===== SERVICES =====
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

              SizedBox(height: 16.h),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12.w,
                mainAxisSpacing: 12.h,
                childAspectRatio: 1.15,
                children: services.map(buildServiceCard).toList(),
              ),
              SizedBox(height: 16.h),
              AppFooter()
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

}

String _formatTime(DateTime dt) {
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $ampm';
}

String _formatDate(DateTime dt) {
  const months = [
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
  return '${dt.day} ${months[dt.month]} ${dt.year}';
}

Widget _serviceCard({
  required String service,
  required IconData icon,
  Color? iconColor,
}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12.r),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6),
      ],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 42.sp, color: iconColor),
        SizedBox(height: 8.h),
        Text(
          service,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
