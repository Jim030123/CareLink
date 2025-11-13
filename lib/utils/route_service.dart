import 'package:carelink_mobile/screens/home_page.dart';
import 'package:carelink_mobile/screens/login_page.dart';
import 'package:carelink_mobile/screens/register_care_reciepient_page.dart';
import 'package:carelink_mobile/screens/register_number_care_reciepient_page.dart';
import 'package:carelink_mobile/screens/register_page.dart';
import 'package:carelink_mobile/utils/test_page.dart';
import 'package:go_router/go_router.dart';

import '../screens/graphql_test_page.dart';
import '../screens/register_caregiver_page.dart';
import '../screens/register_doctor_page.dart';

/// Central app router exported for use by `main.dart`.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: <GoRoute>[
    // Todo: after login that will save the state
    GoRoute(
      path: '/',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),
    GoRoute(path: '/home', builder: (context, state) => const HomePage()),
    GoRoute(
      path: '/register/caregiver',
      builder: (context, state) => const RegisterCaregiverPage(),
    ),

    GoRoute(
      path: '/register/caregiver/registerrecipientdetail',
      builder: (context, state) {
        final extra = state.extra;
        if (extra is Map) {
          final count = extra['count'] as int;
          final caregiverEmail = extra['caregiverEmail'] as String?;
          return RegisterCareReciepientPage(count: count, caregiverEmail: caregiverEmail);
        }
        return RegisterCareReciepientPage(count: extra as int);
      },
    ),
    GoRoute(
      path: '/register/caregiver/numberofcarerecipient',
      builder: (context, state) => NumberCareReciepientPage(caregiverEmail: state.extra as String?),
    ),

    GoRoute(
      path: '/register/doctor',
      builder: (context, state) => const RegisterDoctorPage(),
    ),
  ],
);
