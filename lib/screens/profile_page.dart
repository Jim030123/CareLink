import 'package:carelink_mobile/components/page_appbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:carelink_mobile/utils/secure_auth.dart';

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
    _localNotifications = FlutterLocalNotificationsPlugin();
    _initLocalNotifications();
    _loadNotificationSettings();
  }

  void _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      InitializationSettings(android: androidInit, iOS: iosInit),
    );
  }

  Future<void> _loadNotificationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _pushNotifications = prefs.getBool('pushNotifications') ?? true;
        _emailNotifications = prefs.getBool('emailNotifications') ?? true;
      });
    } catch (_) {}
  }

  Future<void> _setPushNotifications(bool value) async {
    setState(() => _pushNotifications = value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pushNotifications', value);
    } catch (_) {}
    if (value) {
      _showTestNotification();
    } else {
      try {
        await _localNotifications.cancelAll();
      } catch (_) {}
    }
  }

  Future<void> _setEmailNotifications(bool value) async {
    setState(() => _emailNotifications = value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('emailNotifications', value);
    } catch (_) {}
  }

  Future<void> _showTestNotification() async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'test_channel',
        'Test Notifications',
        channelDescription: 'Channel for test notifications',
        importance: Importance.max,
        priority: Priority.high,
      );
      const iosDetails = DarwinNotificationDetails();
      const platformDetails = NotificationDetails(android: androidDetails, iOS: iosDetails);
      await _localNotifications.show(
        0,
        'Notifications Enabled',
        'This is a test notification. Push notifications are enabled.',
        platformDetails,
      );
    } catch (_) {}
  }

  void _showFeatureSheet(BuildContext ctx, String title, Widget content) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(16.r),
        ),
      ),
      builder: (c) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(c).viewInsets.bottom,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 12.h,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 12.h),
                content,
                SizedBox(height: 12.h),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageAppBar(
        title: 'Profile',
        showBack: true,
        showSearch: false,
      ),
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
                      itemCount: 5,
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
                                          final controller = TextEditingController(text: _name);
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
                                                    Text('Change Display Name', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
                                                    SizedBox(height: 12.h),
                                                    TextField(controller: controller, decoration: InputDecoration(labelText: 'Name')),
                                                    SizedBox(height: 12.h),
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.end,
                                                      children: [
                                                        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Cancel')),
                                                        ElevatedButton(
                                                          onPressed: () {
                                                            setState(() { _name = controller.text.trim(); });
                                                            Navigator.of(ctx).pop();
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
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Manage Linked Accounts')));
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
                                  StatefulBuilder(builder: (c, setStateLocal) {
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
                                        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Close')),
                                        ]),
                                      ],
                                    );
                                  }),
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
                                  StatefulBuilder(builder: (c, setState) {
                                    bool showProfile = false;
                                    bool analytics = true;
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SwitchListTile(
                                          title: Text('Show profile to others'),
                                          value: showProfile,
                                          onChanged: (v) => setState(() => showProfile = v),
                                        ),
                                        SwitchListTile(
                                          title: Text('Allow analytics'),
                                          value: analytics,
                                          onChanged: (v) => setState(() => analytics = v),
                                        ),
                                        SizedBox(height: 8.h),
                                        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                          TextButton(onPressed: () => Navigator.of(c).pop(), child: Text('Close')),
                                        ]),
                                      ],
                                    );
                                  }),
                                );
                              },
                            );
                          case 3:
                            return ListTile(
                              leading: Icon(Icons.security),
                              title: Text('Security'),
                              onTap: () {
                                _showFeatureSheet(
                                  context,
                                  'Security',
                                  StatefulBuilder(builder: (c, setState) {
                                    bool twoFA = false;
                                    bool appLock = false;
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SwitchListTile(
                                          title: Text('Two-factor authentication'),
                                          value: twoFA,
                                          onChanged: (v) => setState(() => twoFA = v),
                                        ),
                                        SwitchListTile(
                                          title: Text('App Lock'),
                                          value: appLock,
                                          onChanged: (v) => setState(() => appLock = v),
                                        ),
                                        SizedBox(height: 8.h),
                                        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                          TextButton(onPressed: () => Navigator.of(c).pop(), child: Text('Close')),
                                        ]),
                                      ],
                                    );
                                  }),
                                );
                              },
                            );
                          default:
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
