import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CareReciepientForm extends StatelessWidget {
  /// Reusable single-care-recipient form.
  ///
  /// - [controllers]: map containing 'first','last','phone' controllers
  /// - [formKey]: form key for validation
  /// - [index]: zero-based recipient index (used for labels)
  /// - [count]: total recipients
  /// - [onPrevious]: called when Previous pressed (may be null)
  /// - [onNextOrSave]: called after validation when Next/Save pressed
  const CareReciepientForm({
    super.key,
    required this.controllers,
    required this.formKey,
    required this.index,
    required this.count,
    this.onPrevious,
    this.onNextOrSave,
  });

  final Map<String, TextEditingController> controllers;
  final GlobalKey<FormState> formKey;
  final int index;
  final int count;
  final VoidCallback? onPrevious;
  final VoidCallback? onNextOrSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.w),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      padding: EdgeInsets.all(16.w),
      width: double.infinity,
      child: Form(
        key: formKey,
        child: Column(
          children: [
            Text(
              'Recipient ${index + 1}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.h),
            TextFormField(
              controller: controllers['first'],
              decoration: const InputDecoration(labelText: 'First Name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter first name' : null,
            ),
            SizedBox(height: 8.h),
            TextFormField(
              controller: controllers['last'],
              decoration: const InputDecoration(labelText: 'Last Name'),
            ),
            SizedBox(height: 8.h),
            TextFormField(
              controller: controllers['email'],
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter email';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            SizedBox(height: 8.h),
            TextFormField(
              controller: controllers['phone'],
              decoration: const InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                if (index > 0)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onPrevious,
                      child: const Text('Previous'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                if (index > 0) SizedBox(width: 8.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final valid = formKey.currentState?.validate() ?? false;
                      if (!valid) return;
                      onNextOrSave?.call();
                    },
                    child: Text(index < count - 1 ? 'Next' : 'Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
