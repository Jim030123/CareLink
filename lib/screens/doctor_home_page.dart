import 'package:carelink_mobile/components/ai_chat_box.dart';
import 'package:carelink_mobile/models/home_service.dart';
import 'package:carelink_mobile/utils/secure_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';

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

  String _username = '';

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  String _formatDate(DateTime dt) {
    return '${dt.day} ${_monthAbbr[dt.month]} ${dt.year}';
  }
 late final List<Service> services;
  late DateTime _now;
  late Timer _clockTimer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();

    // Update clock every 30 seconds to keep UI reasonably fresh.
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
      });
    });

     services = [
      Service(
        title: 'Heart Rate',
        icon: Icons.favorite_outline_outlined,
        color: Colors.yellow.shade600,
        onTap: () {},
      ),

      Service(
        title: 'Blood Pressure',
        icon: Icons.local_hospital,
        color: Colors.red.shade400,
        onTap: () {},
      ),

      Service(
        title: 'Medication',
        icon: Icons.medication, // fallback: Icons.local_pharmacy
        color: Colors.blue.shade600,
        onTap: () {},
      ),

      Service(
        title: 'Remote Monitor',
        icon: Icons.devices,
        color: Colors.green.shade600,
        onTap: () {},
      ),

      Service(
        title: 'Manage Caregiver',
        icon: Icons.group,
        color: Colors.purple.shade600,
        onTap: () {
          context.push('/managecaregiver');
        },
      ),

      Service(
        title: 'Manage Care Recipient',
        icon: Icons.people,
        color: Colors.orange.shade600,
        onTap: () {
          context.push('/managecarerecipient');
        },
      ),

      // keep a couple extra examples if you want more cards
      Service(
        title: 'Medication',
        icon: Icons.medication,
        color: Colors.indigo,
        onTap: () => context.push('/medication'),
      ),
      Service(
        title: 'Activity',
        icon: Icons.directions_run,
        color: Colors.teal,
        onTap: () =>context.push('/caregiveremergencycall'),

      ),
    ];
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeString = _formatTime(_now);
    final dateString = _formatDate(_now);
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // logo + title
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SvgPicture.asset(
                            'assets/icons/logo.svg',
                            width: 64.w,
                            height: 64.h,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'Hi, ${_username.isNotEmpty ? _username : 'there'}',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Spacer(),

                  // time, date and logout button
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                timeString,
                                style: TextStyle(
                                  fontSize: 26.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                dateString,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(width: 8.w),
                          // Logout button with same logic as profile page
                          IconButton(
                            onPressed: () async {
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
                                final messenger = ScaffoldMessenger.of(context);

                                // Clear stored credentials and sign out
                                await SecureAuth.clearCredentials();
                                try {
                                  await FirebaseAuth.instance.signOut();
                                } catch (_) {}

                                // Show snackbar using captured messenger if still mounted
                                if (messenger.mounted) {
                                  messenger.showSnackBar(
                                    const SnackBar(content: Text('Logged out')),
                                  );
                                }

                                // Navigate to the login page after logout if this State is still mounted
                                if (!mounted) return;
                                context.go('/login');
                              }
                            },
                            icon: Icon(
                              Icons.logout,
                              color: Colors.red.shade600,
                              size: 24.w,
                            ),
                            tooltip: 'Log out',
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              SizedBox(height: 16.h),

              // Upcoming appointment card
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFF4EE), Color(0xFFFFE0CC)],
                  ),
                  border: Border.all(
                    color: const Color(0xFFFFD1B3),
                    width: 1.0,
                  ),
                  borderRadius: BorderRadius.circular(12.w),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x11000000),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Left: appointment details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Upcoming Appointment',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.black54,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          // Placeholder appointment time/date — replace with real data
                          Text(
                            '12 Dec 2025',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'Patient: John Doe',
                            style: TextStyle(fontSize: 13.sp),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Location: City Clinic — Room 3',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Right: icon + action
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: Colors.black87,
                              size: 20.w,
                            ),
                            SizedBox(width: 8.w),
                            Text('2:30 PM', style: TextStyle(fontSize: 13.sp)),
                          ],
                        ),
                        SizedBox(height: 10.h),
                        ElevatedButton(
                          onPressed: () {
                            // TODO: navigate to appointment details
                            // Example: context.go('/appointments/123');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 8.h,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.w),
                            ),
                          ),
                          child: Text(
                            'View',
                            style: TextStyle(fontSize: 12.sp),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 18.h),

              Container(
                child: Row(
                  children: [
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
                  ],
                ),
              ),

              SizedBox(height: 18.h),

              // Grid tiles
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12.w,
                mainAxisSpacing: 12.h,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.15,
                children: [
                  // Appointments module
                  GestureDetector(
                    onTap: () {
                      // Navigate to appointments list
                      context.go('/appointments');
                    },
                    child: Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.w),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x11000000),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8.w),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(8.w),
                                ),
                                child: Icon(
                                  Icons.calendar_month,
                                  color: Colors.orange.shade800,
                                  size: 20.w,
                                ),
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Text(
                                  'Appointments',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'View upcoming appointments',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Medication module
                  GestureDetector(
                    onTap: () {
                      // Navigate to medication screen
                      context.go('/medication');
                    },
                    child: Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.w),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x11000000),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8.w),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(8.w),
                                ),
                                child: Icon(
                                  Icons.event_available,
                                  color: Colors.blue.shade800,
                                  size: 20.w,
                                ),
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Text(
                                  'Medication',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'Manage patient bookings',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),



                ],
              ),

              SizedBox(height: 22.h),

              // HELP button
            ],
          ),
        ),
      ),
    );
  }
}
