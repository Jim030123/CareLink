import 'dart:io';
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:carelink_mobile/utils/account_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
// HTTP/backend calls removed — no direct server POST from this screen
import 'package:carelink_mobile/components/text_field.dart';

// If you want to enable file picking, add `file_picker` to pubspec and
// uncomment the import below and the code in _pickFile().
// import 'package:file_picker/file_picker.dart';

class RegisterDoctorPage extends StatefulWidget {
  const RegisterDoctorPage({super.key, this.onBack, this.onNext, this.onLogin});

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
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  // Detail information fields
  final TextEditingController _hospitalName = TextEditingController();
  final TextEditingController _specialist = TextEditingController();
  final TextEditingController _registrationNumber = TextEditingController();
  final TextEditingController _bio = TextEditingController();

  String? _pickedFileName;
  File? _pickedFile;
  // Upload progress state
  final ValueNotifier<double> _uploadProgress = ValueNotifier<double>(0.0);
  bool _uploadDialogOpen = false;
  bool _isUploading = false;
  StreamSubscription<TaskSnapshot>? _uploadSub;
  // Stored upload link after a successful upload
  String? _uploadedDownloadUrl;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _hospitalName.dispose();
    _specialist.dispose();
    _registrationNumber.dispose();
    _bio.dispose();
    _uploadSub?.cancel();
    _uploadProgress.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    const int maxBytes = 10 * 1024 * 1024; // 10 MB
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.single;
      // file.size is in bytes
      if (file.size > maxBytes) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selected file is too large. Maximum size is 10 MB.'),
          ),
        );
        return;
      }

      final path = file.path;
      if (path != null) {
        setState(() {
          _pickedFile = File(path);
          _pickedFileName = file.name;
        });
      } else {
        // If no path available, inform the user.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not access selected file. Please try another file.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleNext() async {
    try {
      // Validate form first
      if (!_formKey.currentState!.validate()) return;

      // Require a picked file
      if (_pickedFile == null && _pickedFileName == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please upload your license/document (.PDF)'),
          ),
        );
        return;
      }

      if (_isUploading) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload already in progress')),
        );
        return;
      }

      final data = {
        'firstName': _firstName.text.trim(),
        'lastName': _lastName.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'password': _password.text,
        'fileName': _pickedFileName,
        // Detail information
        'hospitalName': _hospitalName.text.trim(),
        'specialist': _specialist.text.trim(),
        'registrationNumber': _registrationNumber.text.trim(),
        'bio': _bio.text.trim(),
      };

      // Check email existence on server before proceeding (moved to util)
      final emailValue = data['email'] as String;
      final existsOrNull = await checkEmailExists(context, emailValue);
      if (existsOrNull == null) {
        // An error occurred during the check; user has been notified.
        return;
      }
      if (existsOrNull) {
        // Email already exists; checkEmailExists already showed a snackbar.
        return;
      }

      _isUploading = true;
      Map<String, dynamic>? out;
      try {
        out = await _uploadFileToStorageOnly(data);
      } finally {
        _isUploading = false;
      }

      if (out == null) {
        // Upload failed; user already shown an error snackbar by upload method
        return;
      }

      // Save returned link into state (upload method already set it, but ensure)
      final result = out;
      final downloadUrl = result['downloadUrl'] as String?;
      if (mounted && downloadUrl != null) {
        setState(() {
          _uploadedDownloadUrl = downloadUrl;
        });
      }

      // Show the uploaded link to the user in a dialog
      if (downloadUrl != null && mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Uploaded file URL'),
            content: SelectableText(downloadUrl),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }

      // Invoke onNext with the data including downloadUrl if provided
      // Create Firebase Auth account (or convert anonymous) using the
      // provided email/password before calling onNext.
      try {
        final auth = FirebaseAuth.instance;
        final email = _email.text.trim();
        final password = _password.text;

        final currentUser = auth.currentUser;

        if (currentUser == null) {
          // No signed-in user: try to create a new account, or sign in if
          // the email is already registered.
          try {
            await auth.createUserWithEmailAndPassword(email: email, password: password);
            debugPrint('Created Firebase user for $email');
          } on FirebaseAuthException catch (ae) {
            if (ae.code == 'email-already-in-use') {
              // Try to sign in instead
              try {
                await auth.signInWithEmailAndPassword(email: email, password: password);
                debugPrint('Signed in existing user $email');
              } on FirebaseAuthException catch (se) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Auth failed: ${se.message}')),
                );
                return;
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Auth failed: ${ae.message}')),
              );
              return;
            }
          }
        } else if (currentUser.isAnonymous) {
          // Convert anonymous account to email/password
          final credential = EmailAuthProvider.credential(email: email, password: password);
          try {
            await currentUser.linkWithCredential(credential);
            debugPrint('Linked anonymous account to $email');
          } on FirebaseAuthException catch (le) {
            if (le.code == 'credential-already-in-use' || le.code == 'email-already-in-use') {
              // Email already used by a different account; sign in with that account
              try {
                await auth.signInWithEmailAndPassword(email: email, password: password);
              } on FirebaseAuthException catch (se) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Auth link/sign-in failed: ${se.message}')),
                );
                return;
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Account linking failed: ${le.message}')),
              );
              return;
            }
          }
        } else {
          // Already signed in with a non-anonymous account; if it's different
          // from the entered email we won't replace it here.
          debugPrint('User already signed in: uid=${currentUser.uid}, email=${currentUser.email}');
        }
      } catch (e) {
        debugPrint('Unexpected auth error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create/sign-in user: $e')),
        );
        return;
      }

      if (widget.onNext != null) {
        widget.onNext!(out);
      }
    } catch (e, st) {
      // Log and show a helpful message so we can see the stack trace in logs
      debugPrint('Error in _handleNext: $e\n$st');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unexpected error: $e')));
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _uploadFileToStorageOnly(
    Map<String, dynamic> data,
  ) async {
    if (_pickedFile == null) return null;

    final scaffold = ScaffoldMessenger.of(context);

    try {
      final String fileName = _pickedFileName ?? 'document.pdf';
      final String path =
          'doctor_documents/${DateTime.now().millisecondsSinceEpoch}_$fileName';

      // Ensure Firebase is initialized
      if (Firebase.apps.isEmpty) {
        scaffold.hideCurrentSnackBar();
        scaffold.showSnackBar(
          const SnackBar(content: Text('Firebase not initialized')),
        );
        debugPrint(
          'Firebase.apps is empty - initialize Firebase before upload',
        );
        return null;
      }

      final storage = FirebaseStorage.instanceFor(
        bucket: 'gs://carelink-ed263.firebasestorage.app',
      );
      final ref = storage.ref().child(path);
      var currentUser = FirebaseAuth.instance.currentUser;
      debugPrint('Current Firebase user uid=${currentUser?.uid}');

      // If there's no authenticated user, sign in anonymously so uploads
      // that require auth can succeed without forcing a full login flow.
      if (currentUser == null) {
        scaffold.showSnackBar(
          const SnackBar(content: Text('Signing in anonymously for upload...')),
        );
        try {
          final cred = await FirebaseAuth.instance.signInAnonymously();
          currentUser = cred.user;
          debugPrint('Signed in anonymously, uid=${currentUser?.uid}');
          scaffold.hideCurrentSnackBar();
        } catch (e, st) {
          debugPrint('Anonymous sign-in failed: $e\n$st');
          scaffold.hideCurrentSnackBar();
          scaffold.showSnackBar(
            SnackBar(content: Text('Anonymous sign-in failed: $e')),
          );
          return null;
        }
      }
      debugPrint('Uploading to bucket=${ref.bucket}, path=${ref.fullPath}');

      final metadata = SettableMetadata(
        customMetadata: {
          'firstName': data['firstName'] ?? '',
          'lastName': data['lastName'] ?? '',
          'email': data['email'] ?? '',
        },
      );

      final uploadTask = ref.putFile(_pickedFile!, metadata);

      // Show progress in a modal dialog with a progress bar. Use a
      // ValueNotifier so the dialog's UI can update as progress changes.
      _uploadProgress.value = 0.0;
      _uploadDialogOpen = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Uploading file'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<double>(
                  valueListenable: _uploadProgress,
                  builder: (context, value, child) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LinearProgressIndicator(value: value),
                        SizedBox(height: 8.h),
                        Text('${(value * 100).toStringAsFixed(0)}%'),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      );

      // Listen to snapshot events and update the notifier instead of snackbars
      _uploadSub = uploadTask.snapshotEvents.listen((snapshot) {
        final bytesTransferred = snapshot.bytesTransferred.toDouble();
        final total = snapshot.totalBytes.toDouble();
        final progress = total > 0 ? (bytesTransferred / total) : 0.0;
        _uploadProgress.value = progress.clamp(0.0, 1.0);
      });

      // Await completion and capture snapshot to check for success
      TaskSnapshot snapshot;
      try {
        snapshot = await uploadTask;
      } on FirebaseException catch (fe, st) {
        await _uploadSub?.cancel();
        debugPrint(
          'FirebaseException during upload: code=${fe.code}, message=${fe.message}\n$st',
        );
        if (_uploadDialogOpen && mounted) {
          _uploadDialogOpen = false;
          Navigator.of(context, rootNavigator: true).pop();
        }
        scaffold.showSnackBar(
          SnackBar(
            content: Text('Firebase upload error: ${fe.code}: ${fe.message}'),
          ),
        );
        return null;
      } catch (e, st) {
        await _uploadSub?.cancel();
        debugPrint('Unexpected error during upload: $e\n$st');
        if (_uploadDialogOpen && mounted) {
          _uploadDialogOpen = false;
          Navigator.of(context, rootNavigator: true).pop();
        }
        scaffold.showSnackBar(SnackBar(content: Text('Upload error: $e')));
        return null;
      }

      if (snapshot.state != TaskState.success) {
        debugPrint('Upload completed but snapshot state=${snapshot.state}');
        if (_uploadDialogOpen && mounted) {
          _uploadDialogOpen = false;
          Navigator.of(context, rootNavigator: true).pop();
        }
        await _uploadSub?.cancel();
        scaffold.showSnackBar(
          SnackBar(
            content: Text(
              'Upload did not complete successfully: ${snapshot.state}',
            ),
          ),
        );
        return null;
      }

      final downloadUrl = await ref.getDownloadURL();

      // Close progress dialog
      if (_uploadDialogOpen && mounted) {
        _uploadDialogOpen = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
      await _uploadSub?.cancel();
      _uploadProgress.value = 1.0;
      scaffold.showSnackBar(const SnackBar(content: Text('Upload successful')));

      final out = Map<String, dynamic>.from(data);
      out['downloadUrl'] = downloadUrl;
      out['storagePath'] = path;

      // Save link into local state for later display when Next is handled
      if (mounted) {
        setState(() {
          _uploadedDownloadUrl = downloadUrl;
        });
      }

      // Return metadata including download URL for caller to act on
      return out;
    } catch (e) {
      scaffold.hideCurrentSnackBar();
      scaffold.showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      return null;
    }
  }

  /// POST the download URL (and some metadata) to your backend so you can
  /// store it in your database. Replace `endpoint` with your API URL.

  @override
  Widget build(BuildContext context) {
    // ScreenUtil is configured at app root (ScreenUtilInit in main.dart)
    final Color bg = const Color(0xFFFAF3EC);
    final Color card = Colors.white;
    final Color accent = const Color(0xFFF4CBA1);

    return Scaffold(
      backgroundColor: bg,

      body: LayoutBuilder(
        builder: (context, constraints) => SafeArea(
          child: SingleChildScrollView(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.w),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              SvgPicture.asset(
                                'assets/icons/logo.svg',
                                width: 60.w,
                                height: 60.h,
                              ),
                              Expanded(
                                child: Center(
                                  child: Container(
                                    margin: EdgeInsets.only(right: 60.w),
                                    child: Text(
                                      'Register',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 25.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16.h),
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16.w,
                                  vertical: 8.h,
                                ),

                                decoration: BoxDecoration(
                                  color: Color(0xFFF4CBA1),

                                  borderRadius: BorderRadius.circular(16.w),
                                ),

                                child: Text(
                                  '2',
                                  style: TextStyle(fontSize: 24.sp),
                                ),
                              ),
                              SizedBox(width: 8.w),

                              Expanded(
                                child: Container(
                                  alignment: Alignment.topLeft,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16.w,

                                    vertical: 8.h,
                                  ),

                                  child: Text(
                                    'Create Doctor Account',
                                    textAlign: TextAlign.center,
                                    softWrap: true,
                                    style: TextStyle(
                                      fontSize: 24.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16.h),

                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: constraints.maxWidth,
                              padding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 8.h,
                              ),

                              decoration: BoxDecoration(
                                color: Color(0xFFFFF8F0),
                                borderRadius: BorderRadius.circular(16.w),
                              ),

                              child: Row(
                                mainAxisSize: MainAxisSize.min,

                                children: [
                                  Icon(
                                    Icons.lightbulb_outline,
                                    size: 24.sp,
                                    color: Colors.orange,
                                  ),

                                  SizedBox(width: 8.w),

                                  Flexible(
                                    // 防止长文字溢出
                                    child: Text(
                                      'Allows us to customize the care experience based on the doctor\'s specialty, preferences, and responsibilities.',
                                      // help me generate
                                      textAlign: TextAlign.justify,
                                      softWrap: true,
                                      style: TextStyle(fontSize: 15.sp),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),

                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [

                             Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Personal Information',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),

                            SizedBox(height: 12.h),
                            FormTextField(
                              controller: _firstName,
                              label: 'First Name',
                            ),
                            SizedBox(height: 10.h),
                            FormTextField(
                              controller: _lastName,
                              label: 'Last Name',
                            ),
                            SizedBox(height: 10.h),
                            // Phone field requested by user
                            FormTextField(
                              controller: _phone,
                              label: 'Phone',
                              keyboardType: TextInputType.phone,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Enter phone number';
                                // basic length check
                                if (v.trim().length < 7) return 'Enter a valid phone number';
                                return null;
                              },
                            ),
                            SizedBox(height: 10.h),

                            // Upload area
                            SizedBox(height: 10.h),
                            FormTextField(
                              controller: _email,
                              label: 'Email',
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Enter email';
                                }
                                if (!v.contains('@')) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 10.h),
                            FormTextField(
                              controller: _password,
                              label: 'Password',
                              obscureText: true,
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Enter password';
                                }
                                if (v.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 10.h),
                            FormTextField(
                              controller: _confirm,
                              label: 'Confirm Password',
                              obscureText: true,
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Confirm password';
                                }
                                if (v != _password.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),

                            SizedBox(height: 12.h),

                             Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Details Information',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),

                              SizedBox(height: 8.h),
                              FormTextField(
                                controller: _hospitalName,
                                label: 'Hospital Name',
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Enter hospital name';
                                  return null;
                                },
                              ),
                              SizedBox(height: 10.h),
                              FormTextField(
                                controller: _specialist,
                                label: 'Specialist',
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Enter specialist';
                                  return null;
                                },
                              ),
                              SizedBox(height: 10.h),
                              FormTextField(
                                controller: _registrationNumber,
                                label: 'Registration Number',
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Enter registration number';
                                  return null;
                                },
                              ),
                              SizedBox(height: 10.h),
                              TextFormField(
                                controller: _bio,
                                keyboardType: TextInputType.multiline,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  labelText: 'Bio',
                                  contentPadding:
                                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.w),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.w),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                ),
                                validator: (v) => null,
                              ),
                              SizedBox(height: 12.h),

                            // Upload area
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Upload Doctor License/Document',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(height: 8.h),
                            GestureDetector(
                              onTap: _pickFile,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 14.h,
                                ),
                                decoration: BoxDecoration(
                                  color: bg,
                                  borderRadius: BorderRadius.circular(10.w),
                                  border: Border.all(color: Colors.black12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.folder,
                                      color: Colors.black54,
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      child: Text(
                                        _pickedFileName ??
                                            'Please upload your file (.PDF)',
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          // if the cleared sentinel is set, show red
                                          color:
                                              _pickedFileName ==
                                                  'Clear uploaded file'
                                              ? Colors.red
                                              : Colors.black54,
                                        ),
                                      ),
                                    ),
                                    // Show a small Clear button only when a real file is selected
                                    if (_pickedFile != null)
                                      Padding(
                                        padding: EdgeInsets.only(right: 8.w),
                                        child: TextButton(
                                          onPressed: () {
                                            setState(() {
                                              // clear the actual picked file and show a
                                              // cleared message. The Clear button
                                              // itself is only visible while a real
                                              // file is selected.
                                              _pickedFile = null;
                                              _pickedFileName = null;
                                            });
                                          },
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8.w,
                                              vertical: 4.h,
                                            ),
                                            minimumSize: Size(0, 0),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          child: Text(
                                            'Clear',
                                            style: TextStyle(fontSize: 12.sp),
                                          ),
                                        ),
                                      ),
                                    Icon(
                                      Icons.upload_file,
                                      color: Colors.black54,
                                      size: 18.w,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 18.h),
                    if (_uploadedDownloadUrl != null)
                      Container(
                        padding: EdgeInsets.all(12.w),
                        margin: EdgeInsets.only(bottom: 12.h),
                        decoration: BoxDecoration(
                          color: Color(0xFFF8FFF8),
                          borderRadius: BorderRadius.circular(12.w),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                _uploadedDownloadUrl!,
                                style: TextStyle(fontSize: 12.sp, color: Colors.blue),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            IconButton(
                              onPressed: () {
                                final link = _uploadedDownloadUrl;
                                if (link != null) {
                                  Clipboard.setData(ClipboardData(text: link));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Link copied to clipboard')),
                                  );
                                }
                              },
                              icon: Icon(Icons.copy, size: 18.w),
                            ),
                          ],
                        ),
                      ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                widget.onBack ??
                                () => Navigator.of(context).maybePop(),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20.w),
                              ),
                              side: const BorderSide(color: Colors.black12),
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                            ),
                            child: Text(
                              'Back',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.black,
                              ),
                            ),
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20.w),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Next',
                              style: TextStyle(fontSize: 14.sp),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 16.h),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
