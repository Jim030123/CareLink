import 'package:carelink_mobile/screens/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
// import 'package:flutter/rendering.dart';



void main() {
  //  debugPaintSizeEnabled = true;

   initializeDateFormatting().then((_) => runApp(MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        return ScreenUtilInit(
          designSize: orientation == Orientation.portrait
              ? const Size(412, 912)
              : const Size(912, 412),
          minTextAdapt: true,
          builder: (context, child) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              home: child,
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
                ),
              );
          },
          child: HomePage(),
        );
      },
    );
  }
}
