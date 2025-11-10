import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Step: Care Recipient Account — select how many elderly persons the user will manage.
///
/// Callbacks:
/// - onBack: VoidCallback? (defaults to Navigator.pop)
/// - onNext: ValueChanged<int>? receives the selected count
/// - onLogin: VoidCallback? (defaults to pushReplacementNamed('/login'))
class RegisterCareReciepientPage extends StatefulWidget {
  const RegisterCareReciepientPage({
    super.key,
    this.initialCount = 1,
    this.onBack,
    this.onNext,
    this.onLogin,
  });

  final int initialCount;
  final VoidCallback? onBack;
  final ValueChanged<int>? onNext;
  final VoidCallback? onLogin;

  @override
  State<RegisterCareReciepientPage> createState() => _RegisterCareReciepientPageState();
}

class _RegisterCareReciepientPageState extends State<RegisterCareReciepientPage> {
  late int _count;

  @override
  void initState() {
    super.initState();
    _count = widget.initialCount.clamp(0, 99);
  }

  void _increment() {
    setState(() {
      if (_count < 99) _count++;
    });
  }

  void _decrement() {
    setState(() {
      if (_count > 0) _count--;
    });
  }

  String _displayCount() => _count.toString().padLeft(2, '0');

  void _handleNext() {
    if (widget.onNext != null) {
      widget.onNext!(_count);
    } else {
      // default: show simple message
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Selected count: $_count')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color bg = const Color(0xFFFAF3EC);
    final Color card = Colors.white;
    final Color accent = const Color(0xFFF4CBA1);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text('Register', style: TextStyle(fontSize: 18.sp, color: Colors.black)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          child: Column(
            children: [
              // step indicator and card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16.w)),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: Icon(Icons.local_hospital, color: Colors.deepOrange, size: 28.w),
                    ),
                    SizedBox(height: 8.h),
                    CircleAvatar(
                      radius: 16.w,
                      backgroundColor: accent,
                      child: Text('2', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
                    ),
                    SizedBox(height: 8.h),
                    Text('Care Recipient Account', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
                    SizedBox(height: 6.h),
                    Text('Enter how much Elderly Person need to handle', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.sp, color: Colors.black54)),
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
                      decoration: BoxDecoration(color: card, shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0,4))]),
                      child: Center(child: Text('-', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold))),
                    ),
                  ),

                  SizedBox(width: 18.w),

                  // display
                  Container(
                    width: 84.w,
                    height: 84.w,
                    decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12.w), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0,4))]),
                    child: Center(child: Text(_displayCount(), style: TextStyle(fontSize: 36.sp, fontWeight: FontWeight.w700))),
                  ),

                  SizedBox(width: 18.w),

                  // increment button
                  GestureDetector(
                    onTap: _increment,
                    child: Container(
                      width: 48.w,
                      height: 48.w,
                      decoration: BoxDecoration(color: card, shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0,4))]),
                      child: Center(child: Text('+', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold))),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 40.h),

              // Back / Next buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: card,
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

              SizedBox(height: 18.h),

              Center(
                child: ElevatedButton(
                  onPressed: widget.onLogin ?? () => Navigator.of(context).pushReplacementNamed('/login'),
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
}
