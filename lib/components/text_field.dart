import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class FormTextField extends StatefulWidget {
  const FormTextField({
    super.key,
    required this.controller,
    this.hint,
    this.label,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.readOnly = false,
    this.onTap,
  });

  final TextEditingController controller;
  final String? hint;
  final String? label;
  final bool? obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  State<FormTextField> createState() => _FormTextFieldState();
}

class _FormTextFieldState extends State<FormTextField> {
  @override
  Widget build(BuildContext context) {
    return _buildTextField(
      controller: widget.controller,
      hint: widget.hint ?? '',
      label: widget.label,
      obscureText: widget.obscureText ?? false,
      keyboardType: widget.keyboardType,
        validator: widget.validator,
        readOnly: widget.readOnly,
        onTap: widget.onTap,
    );
  }
}

Widget _buildTextField({
  required TextEditingController controller,
  required String hint,
  String? label,
  bool obscureText = false,
  TextInputType keyboardType = TextInputType.text,
  String? Function(String?)? validator,
  bool readOnly = false,
  VoidCallback? onTap,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8.w),

    borderSide: BorderSide(color: Colors.grey.shade300),
  );

  return TextFormField(
    controller: controller,
    obscureText: obscureText,
    keyboardType: keyboardType,
    readOnly: readOnly,
    onTap: onTap,
    decoration: InputDecoration(
      hintText: hint,
      labelText: label,
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      border: border,
      enabledBorder: border,

    ),

    validator:
        validator ?? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
  );
}
