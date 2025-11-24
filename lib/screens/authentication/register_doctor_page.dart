import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// If you want to enable file picking, add `file_picker` to pubspec and
// uncomment the import below and the code in _pickFile().
// import 'package:file_picker/file_picker.dart';

/// A single-step registration page for creating a Doctor account.
///
/// Callers can pass callbacks:
/// - onBack: VoidCallback when Back pressed
/// - onNext: ValueChanged<Map<String, dynamic>> receives form values when Next pressed and validation passes
/// - onLogin: VoidCallback when the Login button is tapped
class RegisterDoctorPage extends StatefulWidget {
  const RegisterDoctorPage({
    super.key,
    this.onBack,
    this.onNext,
    this.onLogin,
  });

  final VoidCallback? onBack;
  final ValueChanged<Map<String, dynamic>>? onNext;
  final VoidCallback? onLogin;

  @override
  State<RegisterDoctorPage> createState() => _RegisterDoctorPageState();
}

class _RegisterDoctorPageState extends State<RegisterDoctorPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  String? _pickedFileName;
  File? _pickedFile;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    // Uncomment and use FilePicker if added to your pubspec.yaml:
    // final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    // if (result != null && result.files.isNotEmpty) {
    //   final path = result.files.single.path;
    //   if (path != null) setState(() { _pickedFile = File(path); _pickedFileName = result.files.single.name; });
    // }

    // Fallback: show instructions when file_picker not available.
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('To enable file picking, add `file_picker` package and uncomment the code in register_page_2.dart'),
      duration: Duration(seconds: 3),
    ));
  }

  void _handleNext() {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedFile == null && _pickedFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload your license/document (.PDF)')));
      return;
    }

    final data = {
      'firstName': _firstName.text.trim(),
      'lastName': _lastName.text.trim(),
      'email': _email.text.trim(),
      'password': _password.text,
      'fileName': _pickedFileName,
      // don't include file contents by default; caller can access via onNext if you change API
    };

    if (widget.onNext != null) {
      widget.onNext!(data);
    } else {
      // default behavior for demo: show the collected values
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Form validated — implement onNext to proceed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // ScreenUtil is configured at app root (ScreenUtilInit in main.dart)
    final Color bg = const Color(0xFFFAF3EC);
    final Color card = Colors.white;
    final Color accent = const Color(0xFFF4CBA1);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text('Create Doctor Account', style: TextStyle(fontSize: 18.sp, color: Colors.black)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(12.w),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Create Doctor Account', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
                    SizedBox(height: 8.h),
                    Text(
                      'Allows us to customize the care experience based on the caregiver\'s relationship, preferences, and responsibilities.',
                      style: TextStyle(fontSize: 12.sp, color: Colors.black54),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 14.h),

              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(16.w),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildTextField(controller: _firstName, hint: 'First Name'),
                      SizedBox(height: 10.h),
                      _buildTextField(controller: _lastName, hint: 'Last Name'),
                      SizedBox(height: 10.h),
                      _buildTextField(controller: _email, hint: 'Email', keyboardType: TextInputType.emailAddress, validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter email';
                        if (!v.contains('@')) return 'Enter a valid email';
                        return null;
                      }),
                      SizedBox(height: 10.h),
                      _buildTextField(controller: _password, hint: 'Password', obscureText: true, validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter password';
                        if (v.length < 6) return 'Password must be at least 6 characters';
                        return null;
                      }),
                      SizedBox(height: 10.h),
                      _buildTextField(controller: _confirm, hint: 'Confirm Password', obscureText: true, validator: (v) {
                        if (v == null || v.isEmpty) return 'Confirm password';
                        if (v != _password.text) return 'Passwords do not match';
                        return null;
                      }),

                      SizedBox(height: 12.h),

                      // Upload area
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Upload Doctor License/Document', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600)),
                      ),
                      SizedBox(height: 8.h),
                      GestureDetector(
                        onTap: _pickFile,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(10.w),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.folder, color: Colors.black54),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Text(
                                  _pickedFileName ?? 'Please upload your file (.PDF)',
                                  style: TextStyle(fontSize: 12.sp, color: Colors.black54),
                                ),
                              ),
                              Icon(Icons.upload_file, color: Colors.black54, size: 18.w),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 18.h),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.w)),
                        side: const BorderSide(color: Colors.black12),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                      ),
                      child: Text('Back', style: TextStyle(fontSize: 14.sp, color: Colors.black)),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _handleNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.w)),
                        elevation: 0,
                      ),
                      child: Text('Next', style: TextStyle(fontSize: 14.sp)),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16.h),

              Center(
                child: ElevatedButton(
                  onPressed: widget.onLogin ?? () {
                    Navigator.of(context).pushReplacementNamed('/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: card,
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(horizontal: 36.w, vertical: 12.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.w)),
                    elevation: 0,
                  ),
                  child: Text('Login', style: TextStyle(fontSize: 14.sp)),
                ),
              ),

              SizedBox(height: 8.h),
              Center(child: Text('Already have account? Login here', style: TextStyle(fontSize: 12.sp, color: Colors.black54))),
            ],
          ),
        ),
      ),
    );
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
        focusedBorder: border.copyWith(borderSide: const BorderSide(color: Colors.deepOrange)),
      ),
      validator: validator ?? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
    );
  }
}
