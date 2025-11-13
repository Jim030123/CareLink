import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'register_care_reciepient_page.dart';

/// Step: Care Recipient Account — select how many elderly persons the user will manage.
///
/// Callbacks:
/// - onBack: VoidCallback? (defaults to Navigator.pop)
/// - onNext: ValueChanged<int>? receives the selected count
/// - onLogin: VoidCallback? (defaults to pushReplacementNamed('/login'))
class NumberCareReciepientPage extends StatefulWidget {
  const NumberCareReciepientPage({
    super.key,
    this.initialCount = 1,
    this.onBack,
    this.onNext,
    this.onLogin,
    this.caregiverEmail,
  });

  final int initialCount;
  final VoidCallback? onBack;
  final ValueChanged<int>? onNext;
  final VoidCallback? onLogin;
  final String? caregiverEmail;

  @override
  State<NumberCareReciepientPage> createState() =>
      _NumberCareReciepientPageState();
}

class _NumberCareReciepientPageState
    extends State<NumberCareReciepientPage> {
  late int _count;

  @override
  void initState() {
    super.initState();
    _count = widget.initialCount.clamp(1, 99);
  }

  void _increment() {
    setState(() {
      if (_count < 99) _count++;
    });
  }

  void _decrement() {
    setState(() {
      if (_count > 1) _count--;
    });
  }

  String _displayCount() => _count.toString().padLeft(2, '0');

  void _handleNext() {
    if (widget.onNext != null) {
      widget.onNext!(_count);
    } else {
      // default: navigate to the care-recipient detail page

      // Pass both count and caregiverEmail forward so the recipient page can
      // associate records with the caregiver in the backend.
      context.push(
        '/register/caregiver/registerrecipientdetail',
        extra: {
          'count': _count,
          'caregiverEmail': widget.caregiverEmail,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color card = Colors.white;
    final Color accent = const Color(0xFFF4CBA1);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SafeArea(
            child: SingleChildScrollView(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 8.h,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // step indicator and card
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
                                Align(
                                  alignment: Alignment.topCenter,

                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16.w,

                                      vertical: 8.h,
                                    ),

                                    decoration: BoxDecoration(
                                      color: Color(0xFFF4CBA1),

                                      borderRadius: BorderRadius.circular(16.w),
                                    ),

                                    child: Text(
                                      '3',

                                      style: TextStyle(fontSize: 24.sp),
                                    ),
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
                                      'Create Care Reciepient',

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
                                        'How many care recipients would you like to register?',

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

                      SizedBox(height: 40.h),

                      // counter controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // decrement button
                          GestureDetector(
                            onTap: _decrement,
                            child: Container(
                              width: 48.w,
                              height: 48.w,
                              decoration: BoxDecoration(
                                color: card,
                                shape: BoxShape.circle,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 6,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  '-',
                                  style: TextStyle(
                                    fontSize: 20.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          SizedBox(width: 18.w),

                          // display
                          Container(
                            width: 84.w,
                            height: 84.w,
                            decoration: BoxDecoration(
                              color: card,
                              borderRadius: BorderRadius.circular(12.w),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 6,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                _displayCount(),
                                style: TextStyle(
                                  fontSize: 36.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(width: 18.w),

                          // increment button
                          GestureDetector(
                            onTap: _increment,
                            child: Container(
                              width: 48.w,
                              height: 48.w,
                              decoration: BoxDecoration(
                                color: card,
                                shape: BoxShape.circle,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 6,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  '+',
                                  style: TextStyle(
                                    fontSize: 20.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 40.h),

                      // Back / Next buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
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
                              child: Text(
                                'Next',
                                style: TextStyle(fontSize: 14.sp),
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 8.h),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
