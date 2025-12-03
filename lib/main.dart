import 'package:carelink_mobile/utils/route_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';

// 这里假设你已经把我给你的 createClient / createClientNotifier
// 放在了 lib/utils/graphql_service.dart 里
import 'package:carelink_mobile/utils/graphql_service.dart';
import 'package:carelink_mobile/utils/auth_service.dart';

Future<void> main() async {
  // 确保 Widgets 绑定初始化（必须的）
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Hive（graphql_flutter 的缓存用）
  await initHiveForFlutter();

  // 初始化 Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 初始化日期本地化（你 app 里有用到 Intl）
  await initializeDateFormatting();

  // 🔐 创建一个全局复用的 GraphQL Client（带 Auth + Subscriptions）
  //
  // idTokenProvider:
  //   每次需要 token 时，会调用这个函数（异步）
  //   这里我们从 Firebase 当前用户拿 idToken
  final clientNotifier = createClientNotifier(
    idTokenProvider: () async {
      try {
        final user = AuthService.instance.currentUser;
        if (user == null) return null;
        return await user.getIdToken();
      } catch (_) {
        return null;
      }
    },

    // ✅ HTTP 基础地址（Query / Mutation）
    baseUrl: 'http://10.209.91.100:25001/graphql',

    // ✅ WebSocket 地址（Subscription）
    // 使用后端正在监听的路径：/graphql
    websocketUrl: 'ws://10.209.91.100:25001/graphql',

    // 可以显式写上，默认就是 true
    enableSubscriptions: true,
  );

  // Riverpod + GraphQLProvider 一起包住整个 App
  runApp(
    ProviderScope(
      child: GraphQLProvider(
        client: clientNotifier,
        child: const MyApp(),
      ),
    ),
  );
}

// router 是从 lib/utils/route_service.dart 里导出的 appRouter
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color accentColor = Color(0xFFF4CBA1);

    return OrientationBuilder(
      builder: (context, orientation) {
        return ScreenUtilInit(
          designSize: orientation == Orientation.portrait
              ? const Size(412, 912)
              : const Size(912, 412),
          minTextAdapt: true,
          builder: (context, child) {
            return MaterialApp.router(
              debugShowCheckedModeBanner: false,
              routerConfig: appRouter,
              title: 'CareLink',
              theme: ThemeData(
                scaffoldBackgroundColor: const Color(0xFFFFF8F0),
                colorScheme:
                    ColorScheme.fromSeed(seedColor: const Color(0xFFFCEEDB)),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors
                      .transparent, // AppBar 背景透明（你原本的设定，保留）
                ),
                dividerColor: Colors.transparent,
                visualDensity: VisualDensity.adaptivePlatformDensity,
                fontFamily: GoogleFonts.roboto().fontFamily,
                textTheme: GoogleFonts.robotoTextTheme(
                  Theme.of(context).textTheme,
                ),
                // 全局 ElevatedButton 主题
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.w),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            );
          },
          child: const SizedBox.shrink(),
        );
      },
    );
  }
}
