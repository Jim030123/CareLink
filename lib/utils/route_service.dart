import 'package:carelink_mobile/screens/home_page.dart';
import 'package:carelink_mobile/screens/login_page.dart';
import 'package:carelink_mobile/screens/register_page.dart';
import 'package:carelink_mobile/utils/test_page.dart';
import 'package:go_router/go_router.dart';

import '../screens/register_caregiver_page.dart';
import '../screens/register_doctor_page.dart';


/// Central app router exported for use by `main.dart`.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: <GoRoute>[
    GoRoute(
      path: '/',
      builder: (context, state) => const TestPage(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/register/caregiver',
      builder: (context, state) => const RegisterCaregiverPage(),
    ),
    GoRoute(
      path: '/register/doctor',
      builder: (context, state) => const RegisterDoctorPage(),
    ),
  ],
);

