import 'package:carelink_mobile/components/home_appbar.dart';
import 'package:carelink_mobile/components/home_calendar.dart';
import 'package:carelink_mobile/models/home_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:math';
import 'package:carelink_mobile/components/health_card.dart';

class CareRecipientHomePage extends StatefulWidget {
  const CareRecipientHomePage({super.key});

  @override
  State<CareRecipientHomePage> createState() => _CareRecipientHomePageState();
}

class _CareRecipientHomePageState extends State<CareRecipientHomePage> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _appBarOpacity = ValueNotifier(1.0);
  // how many logical pixels to scroll before the appbar becomes fully transparent
  late final double _fadeThreshold = 160.h;

  @override
  void initState() {
    super.initState();
    // precache background image to avoid first-frame decode hitch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage('assets/images/home.jpg'), context);
    });

    _scrollController.addListener(_handleScroll);

    // Initialize services here so the closures can use the State's `context`.
    services = [
      Service(
        title: 'Heart Rate',
        icon: Icons
            .health_and_safety, // 或 Icons.local_pharmacy / Icons.medical_services
        color: Colors.yellow.shade600,
        onTap: () {},
      ),

      Service(
        title: 'Blood Pressure',
        icon: Icons
            .local_hospital, // 或 Icons.local_pharmacy / Icons.medical_services
        color: Colors.yellow.shade600,
        onTap: () {},
      ),

      for (var i = 2; i <= 15; i++)
        Service(
          title: 'Service $i',
          icon: Icons.health_and_safety,
          color: Colors.white,
        ),

      // 其余示例项，按需替换
    ];
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final t = (offset / _fadeThreshold).clamp(0.0, 1.0);
    final newOpacity = (1.0 - t);
    if ((_appBarOpacity.value - newOpacity).abs() > 0.01) {
      _appBarOpacity.value = newOpacity;
    }
  }

  // Initialize services in initState so closures can capture the valid `context`.
  late final List<Service> services;
  @override
  Widget build(BuildContext context) {
    // Prepare slices: first 3 services for the special layout, rest for the grid
    services.take(3).toList();
    final gridServices = services.length > 3
      ? services.skip(3).toList()
      : <Service>[];
    // If for any reason the grid slice is empty, show all services so the
    // page doesn't appear blank while testing.
    final displayServices = gridServices.isNotEmpty ? gridServices : services;

    // Responsive sizing for grid children: compute childAspectRatio from
    // available width and a desired item height based on screen height.
    final screenWidth = MediaQuery.of(context).size.width;
    // total horizontal padding applied around the grid (matching SliverPadding)
    final totalHorizontalPadding = 16.w * 2;
    // spacing between columns (crossAxisSpacing)
    final columnSpacing = 12.w;
    final availableWidth = screenWidth - totalHorizontalPadding - columnSpacing;
    final itemWidth = availableWidth / 2;
    // choose itemHeight as a fraction of screen height but clamp to reasonable bounds
    final rawItemHeight = MediaQuery.of(context).size.height * 0.18;
    final itemHeight = max(120.h, min(220.h, rawItemHeight));
    final childAspectRatio = itemWidth / itemHeight;
    return Scaffold(
      extendBodyBehindAppBar: false,
      // appBar: HomeAppbar(userName: 'This is a very long name that will scroll automatically'),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60.h),
        child: ValueListenableBuilder<double>(
          valueListenable: _appBarOpacity,
          builder: (context, opacity, child) {
            return AppBar(
              backgroundColor: const Color(0xFFBAA387).withOpacity(opacity),
              // size
              toolbarHeight: 50.h,
              title: child,
              elevation: opacity > 0.05 ? 4.0 : 0.0,
            );
          },
          child: HomeAppbar(
            userName: 'This is a very long name that will scroll automatically',
          ),
        ),
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Keep the Scaffold.appBar; make the decorative background a simple sliver
          SliverToBoxAdapter(
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(24.r),
              ),
              child: SizedBox(
                height: 280.h,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 背景圖片放在最底層
                    Image.asset('assets/images/home.jpg', fit: BoxFit.cover),
                    // 半透明遮罩，調整顏色/透明度以獲得需要的視覺效果
                    Container(color: Colors.black.withOpacity(0.25)),
                    Positioned(
                      left: 0,
                      right: 0,
                      // 放在 HomeCalendar 之上：bottom = HomeCalendar.bottom(16.h) + HomeCalendar.height(210.h) + 8.h 間距
                      bottom: 16.h + 210.h + 8.h,
                      child: Center(
                        child: Text(
                          'Appointment Upcoming',
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                offset: Offset(2.0, 2.0),
                                blurRadius: 10.0,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      left: 16.w,
                      right: 16.w,
                      bottom: 16.h,
                      child: SizedBox(height: 210.h, child: HomeCalendar()),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverPersistentHeader(
            pinned: false,
            delegate: _SimpleHeaderDelegate(
              minHeight: 56.h,
              maxHeight: 56.h,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Text(
                      'Health Tracking',
                      style: TextStyle(
                        fontSize: 25.sp,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: Offset(2.0, 2.0),
                            blurRadius: 10.0,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            // TODO: Implement "See All" action
                          },
                          child: Text(
                            'See All >>',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 网格作为 sliver，整个页面统一滚动
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左半屏: replaced with reusable HealthCard widget
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(4.w),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          HealthCard(
                            title: 'Heart Rate',
                            value: '149',
                            icon: Icons.favorite_outline_outlined,

                            color: Colors.white,
                            onTap: () {
                              // preserve existing onTap behavior (empty for now)
                            },
                          ),

                          SizedBox(height: 8.h),

                          HealthCard(
                            title: 'Energy Score',
                            value: '81',
                            icon: Icons.sports_martial_arts_outlined,
                            iconColor: Colors.blue,
                            color: Colors.white,
                            onTap: () {
                              // preserve existing onTap behavior (empty for now)
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 右半屏：两个卡片（Container）
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(4.w),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          HealthCard(
                            title: 'Blood Oxygen',
                            value: '93',
                            icon: Icons.bloodtype_outlined,
                            iconColor: Colors.green,
                            color: Colors.white,
                            onTap: () {
                              // preserve existing onTap behavior (empty for now)
                            },
                          ),

                          SizedBox(height: 8.h),

                          HealthCard(
                            title: 'Sleep Score',
                            value: '73',
                            icon: Icons.bedtime_outlined,
                            iconColor: Colors.purple,
                            color: Colors.white,
                            onTap: () {
                              // preserve existing onTap behavior (empty for now)
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: false,
            delegate: _SimpleHeaderDelegate(
              minHeight: 56.h,
              maxHeight: 56.h,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Text(
                      'Services',
                      style: TextStyle(
                        fontSize: 25.sp,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: Offset(2.0, 2.0),
                            blurRadius: 10.0,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            // TODO: Implement "See All" action
                          },
                          child: Text(
                            'See All >>',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: childAspectRatio,
                mainAxisSpacing: 10.h,
                crossAxisSpacing: 12.w,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final svc = displayServices[index];
                return Padding(
                  padding: EdgeInsets.all(4.w),
                  child: Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(12.r),

                    child: InkWell(
                      borderRadius: BorderRadius.circular(12.r),
                      splashColor: Colors.black12,
                      onTap: svc.onTap ?? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${svc.title} tapped')),
                        );
                      },
                      child: _serviceCard(
                        service: svc.title,
                        icon: svc.icon,
                        iconColor: svc.color,
                      ),
                    ),
                  ),
                );
              }, childCount: displayServices.length),
            ),
          ),

          SliverFillRemaining(
            child: Container(
              color: Colors.grey[200],
              child: Column(
                children: [
                  Expanded(
                    child: Text(
                      'AI Chat Box',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  // Add your AI chat box widget here
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _appBarOpacity.dispose();
    super.dispose();
  }
}

Widget _serviceCard({
  required String service,
  required IconData icon,
  final Color? iconColor,
}) {
  return Container(
    padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 8.w),
    child: LayoutBuilder(builder: (context, constraints) {
      // scale icon and text according to available height
      final maxH = constraints.maxHeight.isFinite ? constraints.maxHeight : 160.h;
      final iconSize = min(64.sp, maxH * 0.38);
      final textStyle = TextStyle(fontSize: max(12.sp, maxH * 0.08), fontWeight: FontWeight.w600);
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor ?? Colors.red, size: iconSize),
          SizedBox(height: 8.h),
          Flexible(
            child: Text(
              service,
              textAlign: TextAlign.center,
              style: textStyle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }),
  );
}

class _SimpleHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _SimpleHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _SimpleHeaderDelegate oldDelegate) {
    return oldDelegate.minHeight != minHeight ||
        oldDelegate.maxHeight != maxHeight ||
        oldDelegate.child != child;
  }
}
