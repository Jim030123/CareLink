
import 'package:carelink_mobile/utils/route_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
// import 'package:flutter/rendering.dart';



Future<void> main() async {
  //  debugPaintSizeEnabled = true;

  WidgetsFlutterBinding.ensureInitialized();
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);

   initializeDateFormatting().then((_) => runApp(MyApp()));
}

// router is provided by `lib/utils/route_service.dart` as `appRouter`

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
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
                colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFCEEDB)),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.transparent, // AppBar 背景透明
                ),
                dividerColor: Colors.transparent,
                visualDensity: VisualDensity.adaptivePlatformDensity,
                fontFamily: GoogleFonts.roboto().fontFamily,
                textTheme: GoogleFonts.robotoTextTheme(
                  Theme.of(context).textTheme,
                ),
                // Set ElevatedButton default style app-wide
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.w)),
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
