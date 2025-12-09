import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CareRecipientHomePage extends StatefulWidget {
  const CareRecipientHomePage({super.key});

  @override
  State<CareRecipientHomePage> createState() => _CareRecipientHomePageState();
}

class _CareRecipientHomePageState extends State<CareRecipientHomePage> with SingleTickerProviderStateMixin {
  late DateTime _now;
  Timer? _timer;
  // Help button state
  bool _helpActive = false;
  static const int _helpDurationSeconds = 3;
  DateTime? _helpStart;
  Timer? _helpTicker;
  double _helpProgress = 0.0; // 0.0..1.0
  final ValueNotifier<int> _helpCountdownNotifier = ValueNotifier<int>(_helpDurationSeconds);
  bool _helpDialogVisible = false;

  static const List<String> _monthAbbr = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute$ampm';
  }

  String _formatDate(DateTime dt) {
    return '${dt.day} ${_monthAbbr[dt.month]} ${dt.year}';
  }

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
      });
    });
    // no-op: real-time ticker will drive the progress when HELP is pressed
  }

  @override
  void dispose() {
    _timer?.cancel();
    _helpTicker?.cancel();
    _helpCountdownNotifier.dispose();
    super.dispose();
  }

  void _onHelpPressedDown() {
    if (_helpActive) return;
    setState(() => _helpActive = true);
    // Defer setting the notifier value until after the current frame so
    // that the dialog's ValueListenableBuilder has been built and the
    // framework is not locked when the notifier notifies listeners.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _helpCountdownNotifier.value = _helpDurationSeconds;
    });
    _helpDialogVisible = true;

    // show non-dismissible countdown dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            content: SizedBox(
              height: 120.h,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 60.w,
                    height: 60.w,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: _helpProgress,
                          strokeWidth: 6.w,
                          color: Colors.red.shade400,
                          backgroundColor: Colors.red.shade100,
                        ),
                        ValueListenableBuilder<int>(
                          valueListenable: _helpCountdownNotifier,
                          builder: (context, value, _) => Text(
                            '$value',
                            style: TextStyle(fontSize: 28.sp, fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text('Sending help in', style: TextStyle(fontSize: 14.sp)),
                ],
              ),
            ),
          ),
        );
      },
    );

    // start real-time ticker
    _helpStart = DateTime.now();
    _helpProgress = 0.0;
    _helpTicker?.cancel();
    _helpTicker = Timer.periodic(const Duration(milliseconds: 100), (t) {
      final now = DateTime.now();
      final elapsedMs = now.difference(_helpStart!).inMilliseconds;
      final totalMs = _helpDurationSeconds * 1000;
      final progress = elapsedMs / totalMs;
      if (progress >= 1.0) {
        _helpProgress = 1.0;
        _helpCountdownNotifier.value = 0;
        t.cancel();
        _helpTicker = null;
        _helpDialogVisible = false;
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          SystemSound.play(SystemSoundType.alert);
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _helpActive = false);
          });
        }
      } else {
        _helpProgress = progress.clamp(0.0, 1.0);
        final remaining = (_helpDurationSeconds - (progress * _helpDurationSeconds)).ceil();
        _helpCountdownNotifier.value = remaining.clamp(0, _helpDurationSeconds);
      }
      // ensure UI updates for progress
      if (mounted) setState(() {});
    });
  }

  void _onHelpReleased() {
    if (!_helpActive) return;
    _helpTicker?.cancel();
    _helpTicker = null;
    _helpStart = null;
    _helpProgress = 0.0;
    _helpCountdownNotifier.value = _helpDurationSeconds;
    if (_helpDialogVisible) {
      _helpDialogVisible = false;
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
    if (mounted) setState(() => _helpActive = false);
  }

  Widget _buildTile({
    required IconData icon,
    required String label,
    int? badge,
    bool showDot = false,
    VoidCallback? onTap,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // per-tile hover notifier to toggle border appearance on desktop/web
            (() {
              final hover = ValueNotifier<bool>(false);
              return MouseRegion(
                onEnter: (_) => hover.value = true,
                onExit: (_) => hover.value = false,
                child: ValueListenableBuilder<bool>(
                  valueListenable: hover,
                  builder: (context, isHover, _) {
                    return Container(
                      width: constraints.maxWidth,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16.w),
                        border: Border.all(
                          color: isHover ? Colors.orange : Colors.grey.shade300,
                          width: isHover ? 1.6.w : 1.w,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x11000000),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.w),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16.w),
                          splashColor: Colors.grey.withOpacity(0.18),
                          highlightColor: Colors.grey.withOpacity(0.08),
                          onTap: onTap ?? () {},
                          onHover: (hovering) => hover.value = hovering,
                          onHighlightChanged: (active) => hover.value = active,
                          child: Padding(
                            padding: EdgeInsets.all(14.w),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 48.w,
                                  height: 48.w,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFAF4EE),
                                    borderRadius: BorderRadius.circular(12.w),
                                  ),
                                  child: Icon(icon, size: 26.w, color: Colors.black87),
                                ),
                                SizedBox(height: 10.h),
                                Text(
                                  label,
                                  style: TextStyle(fontSize: 14.sp, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            })(),
            if (badge != null && badge > 0)
              Positioned(
                right: -6.w,
                top: -6.w,
                child: Container(
                  padding: EdgeInsets.all(6.w),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    badge > 99 ? '99+' : badge.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            else if (showDot)
              Positioned(
                right: -6.w,
                top: -6.w,
                child: Container(
                  width: 12.w,
                  height: 12.w,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.2),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeString = _formatTime(_now);
    final dateString = _formatDate(_now);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // logo + title
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44.w,
                            height: 44.w,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1E8),
                              borderRadius: BorderRadius.circular(10.w),
                            ),
                            child: Icon(
                              Icons.health_and_safety_outlined,
                              color: Colors.orange,
                              size: 28.w,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'CareLink',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Spacer(),

                  // time & date
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        timeString,
                        style: TextStyle(
                          fontSize: 26.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        dateString,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              SizedBox(height: 16.h),

              // Next Task card
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.w),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x11000000),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Next Task',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.black54,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            '1:00 PM',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.medication,
                              color: Colors.black87,
                              size: 20.w,
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              'Take 2\nParacetamol',
                              textAlign: TextAlign.right,
                              style: TextStyle(fontSize: 13.sp),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 18.h),

              // Grid tiles
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12.w,
                mainAxisSpacing: 12.h,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.15,
                children: [
                  _buildTile(
                    icon: Icons.description_outlined,
                    label: 'Medical Report',
                    badge: 12,
                  ),
                  _buildTile(
                    icon: Icons.medication,
                    label: 'Medicine',
                    showDot: false,
                  ),
                  _buildTile(
                    icon: Icons.person_outline,
                    label: 'Caregiver',
                    badge: 12,
                  ),
                  _buildTile(
                    icon: Icons.smart_toy,
                    label: 'AI Chatbot',
                    badge: 12,
                  ),
                ],
              ),

              SizedBox(height: 22.h),

              // HELP button
              SizedBox(
                width: double.infinity,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (_) => _onHelpPressedDown(),
                  onPointerUp: (_) => _onHelpReleased(),
                  onPointerCancel: (_) => _onHelpReleased(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    decoration: BoxDecoration(
                      color: _helpActive ? Colors.red.shade600 : Colors.white,
                      border: Border.all(color: Colors.red.shade400, width: 2.w),
                      borderRadius: BorderRadius.circular(12.w),
                    ),
                    child: Center(
                      child: Text(
                        'HELP!',
                        style: TextStyle(
                          color: _helpActive ? Colors.white : Colors.red.shade600,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
