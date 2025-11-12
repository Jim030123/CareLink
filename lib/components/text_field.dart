import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';


class FormTextField extends StatefulWidget {
  const FormTextField({super.key
  , required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  State<FormTextField> createState() => _FormTextFieldState();
}

class _FormTextFieldState extends State<FormTextField> {
  @override
  Widget build(BuildContext context) {
    return  _buildTextField(controller: widget.controller, hint: widget.hint);
  }
}

Widget _buildTextField({

  required TextEditingController controller,

  required String hint,

  bool obscureText = false,

  TextInputType keyboardType = TextInputType.text,

  String? Function(String?)? validator,

 }) {

  final border = OutlineInputBorder(

   borderRadius: BorderRadius.circular(8.w),

   borderSide: BorderSide(color: Colors.grey.shade300),

  );


  return TextFormField(

   controller: controller,

   obscureText: obscureText,

   keyboardType: keyboardType,

   decoration: InputDecoration(

    hintText: hint,

    contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),

    border: border,

    enabledBorder: border,

    focusedBorder: border.copyWith(

     borderSide: const BorderSide(color: Colors.blue),

    ),

   ),

   validator:

     validator ??

     (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,

  );

 }

