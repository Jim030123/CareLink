import 'package:carelink_mobile/screens/appointment.dart';
import 'package:carelink_mobile/screens/authentication/register_caregiver.dart';
import 'package:carelink_mobile/screens/care_recipient_home_page.dart';
import 'package:carelink_mobile/screens/caregiver_home_page.dart';
import 'package:carelink_mobile/screens/confirmation_appointment.dart';
import 'package:carelink_mobile/screens/cr_emergency_call.dart';
import 'package:carelink_mobile/screens/doctor_home_page.dart';
import 'package:carelink_mobile/screens/medication_handbook.dart';
import 'package:carelink_mobile/screens/medication_prescription.dart';
import 'package:carelink_mobile/screens/qr_scanner.dart';
import 'package:carelink_mobile/screens/select_medication_prescription.dart';
import 'package:carelink_mobile/screens/test1.dart';
import 'package:carelink_mobile/utils/home_resolver.dart';
import 'package:carelink_mobile/screens/authentication/login_page.dart';
import 'package:carelink_mobile/screens/manage_care_reciepient.dart';
import 'package:carelink_mobile/screens/manage_caregiver.dart';
import 'package:carelink_mobile/screens/authentication/register_care_recipient_page.dart';
import 'package:carelink_mobile/screens/authentication/register_complete.dart';
import 'package:carelink_mobile/screens/authentication/register_number_care_recipient_page.dart';
import 'package:carelink_mobile/screens/authentication/register_page.dart';
import 'package:carelink_mobile/screens/show_appointment.dart';

import 'package:carelink_mobile/screens/profile_page.dart';
import 'package:carelink_mobile/screens/medical_report_viewer.dart';
import 'package:carelink_mobile/screens/remote_monitor.dart';
import 'package:carelink_mobile/screens/cg_emergency_call.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:carelink_mobile/screens/not_found_page.dart';

import '../screens/authentication/register_doctor_page.dart';

/// Central app router exported for use by `main.dart`.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  errorBuilder: (context, state) =>
      NotFoundPage(location: state.error?.toString()),
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
    GoRoute(path: '/home', builder: (context, state) => const HomeResolver()),
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
      path: '/home/recipient',
      builder: (context, state) => const CareRecipientHomePage(),
    ),
    GoRoute(
      path: '/home/caregiver',
      builder: (context, state) => const CaregiverHomePage(),
    ),

    GoRoute(path: '/home/doctor',
    builder: (context, state) => const DoctorHomePage()
    ),

    GoRoute(
      path: '/showappointment',
      builder: (context, state) => const ShowAppointmentPage(),
    ),

    GoRoute(path: '/profile', builder: (context, state) => const ProfilePage()),

    GoRoute(
      path: '/managecaregiver',
      builder: (context, state) => const ManageCaregiver(),
    ),
    GoRoute(
      path: '/managecarerecipient',
      builder: (context, state) => const ManageCareRecipient(),
    ),

    GoRoute(
      path: '/remotemonitor',
      builder: (context, state) => const RemoteMonitor(

      ),
    ),

    GoRoute(
      path: '/medication',
      builder: (context, state) => const ShowMedication(),
    ),

    GoRoute(
      path: '/prescription',
      builder: (context, state) => const MedicationPrescription(),
    ),

    GoRoute(
      path: '/caregiveremergencycall',
      builder: (context, state) {
        final extra = state.extra;
        if (extra is Map) {
          final careRecipientID = extra['careRecipientID'] as String? ?? 'CG-003';
          final signalingUrl = extra['signalingUrl'] as String? ?? dotenv.env['RTC_URL']!;
          return CGEmergencyCall(careRecipientID: careRecipientID, signalingUrl: signalingUrl);
        }
        return CGEmergencyCall(careRecipientID: 'CG-003', signalingUrl: dotenv.env['RTC_URL']!);
      },
    ),

    GoRoute(
      path: '/carerecipientemergencycall',
      builder: (context, state) {
        final extra = state.extra;
        if (extra is Map) {
          final caregiverId = extra['caregiverId'] as String? ?? 'CG-003';
          final signalingUrl = extra['signalingUrl'] as String? ?? dotenv.env['RTC_URL']!;
          return CREmergencyCall(caregiverId: caregiverId, signalingUrl: signalingUrl);
        }
        return CREmergencyCall(caregiverId: 'CG-003', signalingUrl: dotenv.env['RTC_URL']!);
      },
    ),


    GoRoute(path: '/selectMedicationPrescription',
      builder: (context, state) => const SelectMedicationPrescription(),
    ),

    GoRoute(path: '/medicalreportviewer',
      builder: (context, state) => const MedicalReportViewer(storagePath: 'medical_report/dummy_health_report.pdf',),
    ),

    GoRoute(path: '/remotemonitor',
      builder: (context, state) => const RemoteMonitor(),
    ),

    GoRoute(path: '/addAppointment',
      builder: (context, state) => const AddAppointmentPage(),
    ),
    GoRoute(path: '/test',
      builder: (context, state) => const TestPage2(),
    ),

     GoRoute(path: '/authScanner',
      builder: (context, state) => const QRScannerScreen(),
    ),

    GoRoute(path: '/confirmAppointment',
      builder: (context, state) => const ConfirmationAppointment(),
    ),



  ],
);
