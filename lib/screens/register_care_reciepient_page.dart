// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:flutter_svg/svg.dart';

// /// Step: Care Recipient Account — select how many elderly persons the user will manage.
// ///
// /// Callbacks:
// /// - onBack: VoidCallback? (defaults to Navigator.pop)
// /// - onNext: ValueChanged<int>? receives the selected count
// /// - onLogin: VoidCallback? (defaults to pushReplacementNamed('/login'))
// class RegisterCareReciepientPage extends StatefulWidget {
//   const RegisterCareReciepientPage({super.key});

//   @override
//   State<RegisterCareReciepientPage> createState() =>
//       _RegisterCareReciepientPageState();
// }

// class _RegisterCareReciepientPageState
//     extends State<RegisterCareReciepientPage> {
//   @override
//   Widget build(BuildContext context) {
//     final Color card = Colors.white;
//     final Color accent = const Color(0xFFF4CBA1);

//     return Scaffold(
//       body: LayoutBuilder(
//         builder: (context, constraints) {
//           return SafeArea(
//             child: SingleChildScrollView(
//               child: Center(
//                 child: Padding(
//                   padding: EdgeInsets.symmetric(
//                     horizontal: 16.w,
//                     vertical: 8.h,
//                   ),
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       // step indicator and card
//                       Container(
//                         padding: EdgeInsets.all(16.w),

//                         decoration: BoxDecoration(
//                           color: Colors.white,

//                           borderRadius: BorderRadius.circular(16.w),

//                           boxShadow: const [
//                             BoxShadow(
//                               color: Colors.black12,

//                               blurRadius: 8,

//                               offset: Offset(0, 4),
//                             ),
//                           ],
//                         ),

//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.center,

//                           children: [
//                             Row(
//                               children: [
//                                 SvgPicture.asset(
//                                   'assets/icons/logo.svg',

//                                   width: 60.w,

//                                   height: 60.h,
//                                 ),

//                                 Expanded(
//                                   child: Center(
//                                     child: Container(
//                                       margin: EdgeInsets.only(right: 60.w),

//                                       child: Text(
//                                         'Register',

//                                         textAlign: TextAlign.center,

//                                         style: TextStyle(
//                                           fontSize: 25.sp,

//                                           fontWeight: FontWeight.bold,
//                                         ),
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),

//                             SizedBox(height: 16.h),

//                             Row(
//                               children: [
//                                 Align(
//                                   alignment: Alignment.topCenter,

//                                   child: Container(
//                                     padding: EdgeInsets.symmetric(
//                                       horizontal: 16.w,

//                                       vertical: 8.h,
//                                     ),

//                                     decoration: BoxDecoration(
//                                       color: Color(0xFFF4CBA1),

//                                       borderRadius: BorderRadius.circular(16.w),
//                                     ),

//                                     child: Text(
//                                       '4',

//                                       style: TextStyle(fontSize: 24.sp),
//                                     ),
//                                   ),
//                                 ),

//                                 SizedBox(width: 8.w),

//                                 Expanded(
//                                   child: Container(
//                                     alignment: Alignment.topLeft,

//                                     padding: EdgeInsets.symmetric(
//                                       horizontal: 16.w,

//                                       vertical: 8.h,
//                                     ),

//                                     child: Text(
//                                       'Care Reciepient Detail',

//                                       textAlign: TextAlign.center,

//                                       softWrap: true,

//                                       style: TextStyle(
//                                         fontSize: 24.sp,

//                                         fontWeight: FontWeight.bold,
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),

//                             SizedBox(height: 16.h),

//                             Align(
//                               alignment: Alignment.centerLeft,

//                               child: Container(
//                                 width: constraints.maxWidth,

//                                 padding: EdgeInsets.symmetric(
//                                   horizontal: 16.w,

//                                   vertical: 8.h,
//                                 ),

//                                 decoration: BoxDecoration(
//                                   color: Color(0xFFFFF8F0),

//                                   borderRadius: BorderRadius.circular(16.w),
//                                 ),

//                                 child: Row(
//                                   mainAxisSize: MainAxisSize.min,

//                                   children: [
//                                     Icon(
//                                       Icons.lightbulb_outline,

//                                       size: 24.sp,

//                                       color: Colors.orange,
//                                     ),

//                                     SizedBox(width: 8.w),

//                                     Flexible(
//                                       // 防止长文字溢出
//                                       child: Text(
//                                         'Fill Care Reciepient Detail',

//                                         textAlign: TextAlign.justify,

//                                         softWrap: true,

//                                         style: TextStyle(fontSize: 15.sp),
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),

//                       SizedBox(height: 40.h),

//                       // counter controls


//            Container(

//             padding: EdgeInsets.all(16.w),

//             decoration: BoxDecoration(

//              color: card,

//              borderRadius: BorderRadius.circular(16.w),

//              boxShadow: const [

//               BoxShadow(

//                color: Colors.black12,

//                blurRadius: 8,

//                offset: Offset(0, 4),

//               ),

//              ],

//             ),

//             child: Form(

//              key: _formKey,

//              child: Column(

//               children: [

//                _buildTextField(

//                 controller: _firstName,

//                 hint: 'First Name',

//                ),

//                SizedBox(height: 10.h),

//                _buildTextField(

//                 controller: _lastName,

//                 hint: 'Last Name',

//                ),

//                SizedBox(height: 10.h),

//                _buildTextField(

//                 controller: _email,

//                 hint: 'Email',

//                 keyboardType: TextInputType.emailAddress,

//                 validator: (v) {

//                  if (v == null || v.trim().isEmpty)

//                   return 'Enter email';

//                  if (!v.contains('@'))

//                   return 'Enter a valid email';

//                  return null;

//                 },

//                ),

//                SizedBox(height: 10.h),

//                _buildTextField(

//                 controller: _password,

//                 hint: 'Password',

//                 obscureText: true,

//                 validator: (v) {

//                  if (v == null || v.isEmpty)

//                   return 'Enter password';

//                  if (v.length < 6)

//                   return 'Password must be at least 6 characters';

//                  return null;

//                 },

//                ),

//                SizedBox(height: 10.h),

//                _buildTextField(

//                 controller: _confirm,

//                 hint: 'Confirm Password',

//                 obscureText: true,

//                 validator: (v) {

//                  if (v == null || v.isEmpty)

//                   return 'Confirm password';

//                  if (v != _password.text) {

//                   return 'Passwords do not match';

//                  }

//                  return null;

//                 },

//                ),

//               ],

//              ),

//             ),

//            ),



//                       SizedBox(height: 40.h),

//                       // Back / Next buttons
//                       Row(
//                         children: [
//                           Expanded(
//                             child: ElevatedButton(
//                               onPressed: () => Navigator.of(context).maybePop(),
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: Colors.white,
//                               ),

//                               child: Text(
//                                 'Back',
//                                 style: TextStyle(
//                                   fontSize: 14.sp,
//                                   color: Colors.black,
//                                 ),
//                               ),
//                             ),
//                           ),
//                           SizedBox(width: 12.w),
//                         ],
//                       ),

//                       SizedBox(height: 8.h),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }
