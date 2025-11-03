import 'package:flutter/material.dart';

class ScrollAnimatedAppBar extends StatefulWidget {
  const ScrollAnimatedAppBar({super.key});

  @override
  State<ScrollAnimatedAppBar> createState() => _ScrollAnimatedAppBarState();
}

class _ScrollAnimatedAppBarState extends State<ScrollAnimatedAppBar> {
  double offset = 0.0;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: (scroll) {
          setState(() {
            offset = scroll.metrics.pixels;
          });
          return true;
        },
        child: Stack(
          children: [
            // 背景 + 内容
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    height: 300,
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage('https://picsum.photos/800/400'),
                        fit: BoxFit.cover,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      "透明 Header",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => ListTile(
                      title: Text("内容项目 #$index"),
                    ),
                    childCount: 40,
                  ),
                ),
              ],
            ),

            // 动画 AppBar
            _buildAnimatedAppBar(context, topPadding),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedAppBar(BuildContext context, double topPadding) {
    // 动画区间
    double showStart = 100; // 开始出现的滚动距离
    double showEnd = 250;   // 完全显示的滚动距离

    // 滚动比例 (0~1)
    double t = (offset - showStart) / (showEnd - showStart);
    t = t.clamp(0.0, 1.0);

    // 计算动画属性
    double opacity = t; // 透明度
    double translateY = (1 - t) * -30; // 向下滑动距离

    return Transform.translate(
      offset: Offset(0, translateY),
      child: Container(
        height: kToolbarHeight + topPadding,
        padding: EdgeInsets.only(top: topPadding),
        color: Colors.white.withOpacity(opacity * 0.85), // 半透明背景
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () {},
              icon: Icon(Icons.arrow_back,
                  color: Color.lerp(Colors.white, Colors.black, t)),
            ),
            Opacity(
              opacity: t,
              child: const Text(
                "AppBar 2 标题",
                style: TextStyle(fontSize: 18, color: Colors.black),
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: Icon(Icons.more_vert,
                  color: Color.lerp(Colors.white, Colors.black, t)),
            ),
          ],
        ),
      ),
    );
  }
}
