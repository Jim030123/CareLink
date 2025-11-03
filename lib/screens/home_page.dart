import 'package:carelink_mobile/components/home_appbar.dart';
import 'package:carelink_mobile/components/home_calendar.dart';
import 'package:carelink_mobile/models/home_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<bool> _isSelected = [true, false];
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
        icon: Icons.health_and_safety, // 或 Icons.local_pharmacy / Icons.medical_services
        color: Colors.yellow.shade600,
        onTap: () {
         
        },
      ),

       Service(
        title: 'Blood Pressure',
        icon: Icons.local_hospital, // 或 Icons.local_pharmacy / Icons.medical_services
        color: Colors.yellow.shade600,
        onTap: () {
         
        },
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
    final topServices = services.take(3).toList();
    final gridServices = services.length > 3
        ? services.skip(3).toList()
        : <Service>[];
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
                          'Calendar',
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
                            'See All',
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
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, groupIndex) {
                  // Only show the first 3 services in this special 3-tile layout
                  final total = topServices.length;

                  final base = groupIndex * 3;
                  if (base >= total) return null;

          final Service leftService = topServices[base];
          final Service? rightTopService =
            base + 1 < total ? topServices[base + 1] : null;
          final Service? rightBottomService =
            base + 2 < total ? topServices[base + 2] : null;

                  final spacingW = 12.w;
                  final spacingV = 12.h;
                  final smallTileHeight = 120.h; // 可按需调整或改为相对值
                  final bigTileHeight = smallTileHeight * 2 + spacingV;

                  Widget buildTile(Service service, {bool isBig = false}) {
                    final bool useDarkText =
                        service.color.computeLuminance() > 0.5;
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return SizedBox(
                          height: isBig ? bigTileHeight : smallTileHeight,
                          width: double.infinity,
                          child: Card(
                            color: service.color,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(12.r),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          service.title,
                                          textAlign: TextAlign.start,
                                          style: TextStyle(
                                            fontSize: 20.sp,
                                            fontWeight: FontWeight.w600,
                                            color: useDarkText
                                                ? Colors.black87
                                                : Colors.white,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        service.icon,
                                        size: 42.sp,
                                        color: useDarkText
                                            ? Colors.black87
                                            : Colors.white,
                                      ),
                                    ],
                                  ),
                                  // If the tile is big we can leave space for extra content
                                  if (isBig) SizedBox(height: 12.h),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }

                  return Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: SizedBox(
                      height: bigTileHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 左侧大格（占两行高度）
                          Expanded(
                            flex: 1,
                            child: buildTile(leftService, isBig: true),
                          ),
                          SizedBox(width: spacingW),
                          // 右侧上下两个小格
                          Expanded(
                            flex: 1,
                            child: Column(
                              children: [
                                if (rightTopService != null)
                                  buildTile(rightTopService)
                                else
                                  SizedBox(height: smallTileHeight),
                                SizedBox(height: spacingV),
                                if (rightBottomService != null)
                                  buildTile(rightBottomService)
                                else
                                  SizedBox(height: smallTileHeight),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                // groupCount = ceil(total / 3)
                childCount: (topServices.length + 2) ~/ 3,
              ),
            ),
          ),

          SliverPersistentHeader(
            pinned: true,
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
                            'See All',
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
                childAspectRatio: 3 / 2,
                mainAxisSpacing: 10.h,
                crossAxisSpacing: 12.w,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final service = gridServices[index];
                final bool useDarkText = service.color.computeLuminance() > 0.5;
                return Padding(
                  padding: EdgeInsets.all(4.w),
                  child: Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(12.r),
                    color: service.color,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12.r),
                      splashColor: Colors.black12,
                      onTap:
                          service.onTap ??
                          () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Tapped ${service.title}'),
                              ),
                            );
                          },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: 12.h,
                          horizontal: 8.w,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              service.icon,
                              size: 28.sp,
                              color: useDarkText
                                  ? Colors.black87
                                  : Colors.white,
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              service.title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: useDarkText
                                    ? Colors.black87
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }, childCount: gridServices.length),
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
