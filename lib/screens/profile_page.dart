import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:carelink_mobile/utils/secure_auth.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _name = 'Sabrina Aryan';
  String _email = 'SabrinaAry208@gmailcom';

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _email = user.email ?? _email;
      _name = user.displayName ?? (user.email != null ? user.email!.split('@').first : _name);
    }
  }
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: 22.sp),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Profile', style: TextStyle(fontSize: 18.sp)),
        centerTitle: false,
        elevation: 0,
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
                                  final nameController = TextEditingController(text: _name);
                                  final emailController = TextEditingController(text: _email);
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
                                    ),
                                    builder: (ctx) {
                                      return Padding(
                                        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
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
                                              Text('Edit Profile', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
                                              SizedBox(height: 12.h),
                                              TextField(
                                                controller: nameController,
                                                decoration: InputDecoration(labelText: 'Name'),
                                              ),
                                              SizedBox(height: 8.h),
                                              TextField(
                                                controller: emailController,
                                                decoration: InputDecoration(labelText: 'Email'),
                                                keyboardType: TextInputType.emailAddress,
                                              ),
                                              SizedBox(height: 16.h),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  TextButton(
                                                    onPressed: () => Navigator.of(ctx).pop(),
                                                    child: Text('Cancel', style: TextStyle(fontSize: 14.sp)),
                                                  ),
                                                  SizedBox(width: 8.w),
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      setState(() {
                                                        _name = nameController.text.trim();
                                                        _email = emailController.text.trim();
                                                      });
                                                      Navigator.of(ctx).pop();
                                                      if (mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(content: Text('Profile updated')),
                                                        );
                                                      }
                                                    },
                                                    child: Text('Save', style: TextStyle(fontSize: 14.sp)),
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
                                // Handle account settings tap
                              },
                            );
                          case 1:
                            return ListTile(
                              leading: Icon(Icons.notifications),
                              title: Text('Notifications'),
                              onTap: () {
                                // Handle notifications tap
                              },
                            );
                          case 2:
                            return ListTile(
                              leading: Icon(Icons.lock),
                              title: Text('Privacy'),
                              onTap: () {
                                // Handle privacy tap
                              },
                            );
                          case 3:
                            return ListTile(
                              leading: Icon(Icons.security),
                              title: Text('Security'),
                              onTap: () {
                                // Handle security tap
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
                                    content: const Text('Are you sure you want to log out?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(true),
                                        child: const Text('Log Out'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  // Clear stored credentials and sign out
                                  await SecureAuth.clearCredentials();
                                  try {
                                    await FirebaseAuth.instance.signOut();
                                  } catch (_) {}
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Logged out')),
                                    );
                                  }
                                  Navigator.of(context).popUntil((route) => route.isFirst);
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
