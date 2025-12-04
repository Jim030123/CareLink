import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CareRecipientHomePage extends StatelessWidget {
  const CareRecipientHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Care Recipient Home')),
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome, care recipient!', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('This is a minimal care recipient home placeholder.'),
          ],
        ),
      ),
    );
  }
}
