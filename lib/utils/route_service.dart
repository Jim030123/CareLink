import 'package:carelink_mobile/screens/home_page.dart';
import 'package:carelink_mobile/screens/authentication/login_page.dart';
import 'package:carelink_mobile/screens/manage_care_reciepient.dart.dart';
import 'package:carelink_mobile/screens/manage_caregiver.dart';
import 'package:carelink_mobile/screens/medicIne_reminder.dart';
import 'package:carelink_mobile/screens/authentication/register_care_recipient_page.dart';
import 'package:carelink_mobile/screens/authentication/register_care_recipient_page.dart';
import 'package:carelink_mobile/screens/authentication/register_complete.dart';
import 'package:carelink_mobile/screens/authentication/register_number_care_recipient_page.dart';
import 'package:carelink_mobile/screens/authentication/register_page.dart';
import 'package:carelink_mobile/screens/show_appointment.dart';
import 'package:carelink_mobile/utils/test_page.dart';
import 'package:go_router/go_router.dart';

import '../screens/authentication/register_caregiver_page.dart';
import '../screens/authentication/register_doctor_page.dart';

/// Central app router exported for use by `main.dart`.
final GoRouter appRouter = GoRouter(
  initialLocation: '/home',
  routes: <GoRoute>[
    // Todo: after login that will save the state
    GoRoute(path: '/', builder: (context, state) => const LoginPage()),
    // GoRoute(
    //   path: '/',
    //   builder: (context, state) => const RegisterCareRecipientPage(count: 2),
    // ),
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const CareRecipientHomePage(),
    ),
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
          return RegisterCareRecipientPage(count: count);
        }
        return RegisterCareRecipientPage(count: extra as int);
      },
    ),
    GoRoute(
      path: '/register/caregiver/numberofcarerecipient',
      builder: (context, state) => const NumberCareRecipientPage(),
    ),

    GoRoute(
      path: '/register/registercomplete',
      builder: (context, state) => const RegisterCompletePage(),
    ),

    GoRoute(
      path: '/register/doctor',
      builder: (context, state) => const RegisterDoctorPage(),
    ),

    GoRoute(
      path: '/home',
      builder: (context, state) => const CareRecipientHomePage(),
    ),
    GoRoute(
      path: '/showappointment',
      builder: (context, state) => const ShowAppointmentPage(),
    ),

    GoRoute(
      path: '/managecaregiver',
      builder: (context, state) => const ManageCaregiver(),
    ),
    GoRoute(
      path: '/managecarerecipient',
      builder: (context, state) => const ManageCareRecipient(),
    ),

    GoRoute(path: '/test',
    builder: (context, state) => const TestPage(),),

    GoRoute(path: '/medication', builder: (context, state) => const TypeofMedicine()),
  ],
);
