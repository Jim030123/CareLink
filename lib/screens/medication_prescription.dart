import 'package:carelink_mobile/components/numbering.dart';
import 'package:carelink_mobile/components/page_appbar.dart';
import 'package:carelink_mobile/utils/graphql_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:carelink_mobile/components/medication_type.dart';
import 'package:carelink_mobile/screens/manage_care_reciepient.dart.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:carelink_mobile/utils/user_service.dart';
import 'package:carelink_mobile/screens/medication_handbook.dart';
import 'package:carelink_mobile/screens/select_medication_prescription.dart';
import 'package:go_router/go_router.dart';

class MedicationPrescription extends StatefulWidget {
  const MedicationPrescription({super.key});

  @override
  State<MedicationPrescription> createState() => _MedicationPrescriptionState();
}

class _MedicationPrescriptionState extends State<MedicationPrescription> {
  final MedicationType _selected = MedicationType.capsule;
  Map<String, String>? _selectedRecipient;
  String? _selectedDoctor;
  final List<Map<String, dynamic>> _prescriptions = [];

  int _segmentIndex = 0; // 0 = Add, 1 = View

  final Set<String> _selectedMedications = {};
  final bool _noneMedicationSelected = false;
  String? _selectedMedicationSingle;

  static const String _fetchCareRecipientsQuery = r'''
query CareRecipients {
  care_recipient {
    id
    firstName
    lastName
    phone
  }
}
''';

  static const String _fetchPrescriptionsQuery = r'''
query Prescriptions($careRecipientId: ID!) {
  medication_prescriptions_by_careRecipient(
    careRecipientId: $careRecipientId
  ) {
    id
    dosageAmount
    takeTime
    status

    medication {
      id
      name
      standardUnit
      form
    }

    careRecipient {
      id
      firstName
      lastName
    }

    doctor {
      id
      firstName
      lastName
    }
  }
}

''';

  Future<List<Map<String, dynamic>>> fetchPrescriptions(
    String careRecipientId,
  ) async {
    debugPrint(careRecipientId);
    try {
      final client = createClient();
      final options = QueryOptions(
        document: gql(_fetchPrescriptionsQuery),
        variables: {'careRecipientId': careRecipientId},
        fetchPolicy: FetchPolicy.networkOnly,
      );
      final res = await client.query(options);
      if (res.hasException) {
        debugPrint('fetchPrescriptions error: ${res.exception}');
        return [];
      }
      final list =
          (res.data?['medication_prescriptions_by_careRecipient']
                  as List<dynamic>?)
              ?.map(
                (e) => {
                  'id': e['id']?.toString(),
                  'medicationId': e['medicationId']?.toString(),
                  'dosageAmount': e['dosageAmount'],
                  'startDate': e['startDate'],
                  'endDate': e['endDate'],
                  'frequencyNote': e['frequencyNote'],
                  'status': e['status'],
                  'takeTime': e['takeTime'],
                  'medication': e['medication'],
                  'standardUnit': e['medication']?['standardUnit'] ?? '-',
                },
              )
              .toList() ??
          [];

      debugPrint(list.toString());
      return List<Map<String, dynamic>>.from(list);
    } catch (e, st) {
      debugPrint('fetchPrescriptions exception: $e\n$st');
      return [];
    }
  }

  Future<List<Map<String, String>>> fetchCareRecipients() async {
    try {
      final client = createClient();
      final options = QueryOptions(document: gql(_fetchCareRecipientsQuery));
      final res = await client.query(options);
      if (res.hasException) {
        debugPrint('fetchCareRecipients error: ${res.exception}');
        return [];
      }
      final list =
          (res.data?['care_recipient'] as List<dynamic>?)?.map((e) {
            final first = (e['firstName'] ?? '') as String;
            final last = (e['lastName'] ?? '') as String;
            return {
              'id': e['id']?.toString() ?? '',
              'name': ('$first $last').trim(),
            };
          }).toList() ??
          [];
      return List<Map<String, String>>.from(list);
    } catch (e, st) {
      debugPrint('fetchCareRecipients exception: $e\n$st');
      return [];
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return '-';
    try {
      final dt = DateTime.parse(date.toString());
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return date.toString();
    }
  }

  String _formatDateFriendly(dynamic date) {
    if (date == null) return '';
    try {
      final dt = DateTime.parse(date.toString());
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day.toString().padLeft(2, '0')}, ${dt.year}';
    } catch (e) {
      return date.toString();
    }
  }

  String _buildDateRangeText(Map<String, dynamic> p) {
    final s = p['startDate'];
    final e = p['endDate'];
    final sText = _formatDateFriendly(s);
    final eText = _formatDateFriendly(e);

    if ((s == null || s.toString().isEmpty) &&
        (e == null || e.toString().isEmpty)) {
      return 'No dates specified';
    }
    if (s == null || s.toString().isEmpty) return 'Until $eText';
    if (e == null || e.toString().isEmpty) return 'From $sText';
    if (sText == eText) return sText;
    return '$sText → $eText';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PageAppBar(
        title: 'Medication Prescription',
        showBack: true,
        showSearch: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Care recipient card
                    Text(
                      'Care Recipient',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    GestureDetector(
                      onTap: () => _showRecipientSelector(context),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFF4EE), Color(0xFFFFE0CC)],
                          ),
                          border: Border.all(
                            color: Colors.orange.shade300,
                            width: 2.w,
                          ),
                          borderRadius: BorderRadius.circular(10.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 26.r,

                              child: Text(
                                _selectedRecipient == null
                                    ? '?'
                                    : _selectedRecipient!['name']!
                                          .split(' ')
                                          .map((s) => s.isNotEmpty ? s[0] : '')
                                          .take(2)
                                          .join(),
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedRecipient == null
                                        ? 'No care recipient selected'
                                        : _selectedRecipient!['name']!,
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 6.h),
                                  Text(
                                    _selectedRecipient == null
                                        ? 'Tap to select'
                                        : (_selectedRecipient!['id'] ?? ''),
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Doctor selector (disabled until recipient selected)
                    SizedBox(height: 20.h),

                    // Medication selection list
                    Text(
                      'Medication',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8.h),

                    // Show saved prescriptions if any, otherwise show placeholder
                    if (_prescriptions.isEmpty)
                      _buildNoMedicationPrescription()
                    else
                      Column(
                        children: _prescriptions.map((p) {
                          final med = p['medication'] as Map<String, dynamic>?;
                          final name = med != null
                              ? (med['name'] ?? '-')
                              : (p['medicationId'] ?? '-');
                          final times =
                              (p['takeTime'] as List<dynamic>?)
                                  ?.cast<String>() ??
                              [];
                          final dosageAmount = p['dosageAmount'] ?? '-';
                          final standardUnit = med?['standardUnit'] ?? '-';
                          final medMap = med;
                          final form =
                              ((medMap?['form'] ?? medMap?['type']) ?? '')
                                  .toString()
                                  .toLowerCase();
                          String defaultAsset;
                          if (form.contains('capsule')) {
                            defaultAsset = 'assets/icons/capsule.png';
                          } else if (form.contains('tablet')) {
                            defaultAsset = 'assets/icons/tablet.png';
                          } else if (form.contains('injection') ||
                              form.contains('inject')) {
                            defaultAsset = 'assets/icons/injection.png';
                          } else if (form.contains('cream') ||
                              form.contains('ointment')) {
                            defaultAsset = 'assets/icons/cream.png';
                          } else {
                            defaultAsset = 'assets/icons/capsule.png';
                          }

                          final medAsset =
                              (medMap?['asset'] ?? medMap?['picture'] ?? '')
                                  ?.toString() ??
                              '';
                          final displayAsset = medAsset.isNotEmpty
                              ? medAsset
                              : defaultAsset;

                          return Card(
                            margin: EdgeInsets.only(bottom: 8.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            elevation: 2,
                            child: Padding(
                              padding: EdgeInsets.all(12.w),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(8.w),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Builder(
                                      builder: (context) {
                                        if (displayAsset.startsWith('http')) {
                                          return Image.network(
                                            displayAsset,
                                            width: 20.w,
                                            height: 20.w,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) =>
                                                Image.asset(
                                                  defaultAsset,
                                                  width: 20.w,
                                                  height: 20.w,
                                                ),
                                          );
                                        }
                                        return Image.asset(
                                          displayAsset,
                                          width: 20.w,
                                          height: 20.w,
                                          fit: BoxFit.contain,
                                        );
                                      },
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name.toString(),
                                          style: TextStyle(
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        SizedBox(height: 6.h),
                                        Text(
                                          'Frequency Note: ${p['frequencyNote'] ?? '-'}',
                                          style: TextStyle(
                                            fontSize: 13.sp,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        SizedBox(height: 6.h),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Dose: $dosageAmount $standardUnit / time',
                                                style: TextStyle(
                                                  fontSize: 13.sp,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 8.h),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.calendar_today,
                                              size: 14.w,
                                              color: Colors.black45,
                                            ),
                                            SizedBox(width: 8.w),
                                            Expanded(
                                              child: Text(
                                                _buildDateRangeText(p),
                                                style: TextStyle(
                                                  fontSize: 13.sp,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 8.h),
                                        if (times.isNotEmpty)
                                          Wrap(
                                            spacing: 6.w,
                                            children: times
                                                .map(
                                                  (t) => Chip(label: Text(t)),
                                                )
                                                .toList(),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete,
                                          color: Colors.redAccent,
                                        ),
                                        onPressed: () => setState(
                                          () => _prescriptions.remove(p),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                    SizedBox(height: 12.h),

                    // Row: single-select dropdown on left, assign button on right
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_selectedRecipient != null &&
                            (_prescriptions.isNotEmpty ||
                                _selectedMedications.isNotEmpty ||
                                _noneMedicationSelected ||
                                _selectedMedicationSingle != null))
                          TextButton(
                            style: ButtonStyle(
                              backgroundColor: MaterialStateProperty.all(
                                Colors.transparent,
                              ),
                              foregroundColor: MaterialStateProperty.all(
                                Theme.of(context).colorScheme.primary,
                              ),
                              side: MaterialStateProperty.all(
                                BorderSide(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            onPressed: () async {
                              debugPrint(
                                'Assign Medication clicked. Prescriptions: $_prescriptions',
                              );

                              final client = createClient();

                              const String insertMutation = r'''
                              mutation InsertMedication($object: medication_prescription_insert_input!) {
                                insert_medication_prescription_one(object: $object) {
                                  id
                                }
                              }
                              ''';

                              final messenger = ScaffoldMessenger.of(context);

                              try {
                                int success = 0;
                                for (final p in _prescriptions) {
                                  // Resolve backend doctor id if not provided
                                  String? doctorBackendId =
                                      p['doctor'] as String?;
                                  if (doctorBackendId == null) {
                                    final candidate =
                                        FirebaseAuth.instance.currentUser?.uid;
                                    if (candidate != null) {
                                      try {
                                        doctorBackendId =
                                            await fetchUserIdByUid(
                                              candidate.toString(),
                                            );
                                        debugPrint(doctorBackendId);
                                      } catch (e) {
                                        debugPrint(
                                          'Failed to resolve doctor backend id for $candidate: $e',
                                        );
                                      }
                                    }
                                  }

                                  final obj = {
                                    'id': p['id'],
                                    'careRecipientId':
                                        p['careRecipientId'] ??
                                        p['care_recipient_id'],
                                    'medicationId':
                                        p['medicationId'] ??
                                        p['medication_id'] ??
                                        (p['medication'] != null
                                            ? p['medication']['id']
                                            : null),
                                    'doctorId': doctorBackendId,

                                    // backend doctor id field expected by some schemas
                                    'dosageAmount': p['dosageAmount'] ?? '',
                                    'startDate':
                                        p['startDate'] ?? p['start_date'],
                                    'endDate': p['endDate'] ?? p['end_date'],
                                    'frequencyNote':
                                        p['note'] ??
                                        p['frequencyNote'] ??
                                        p['frequency_note'] ??
                                        '',
                                    'takeTime': p['takeTime'] ?? '',
                                    'status': p['status'] ?? 'active',
                                  };

                                  final options = MutationOptions(
                                    document: gql(insertMutation),
                                    variables: {'object': obj},
                                  );

                                  final res = await client.mutate(options);
                                  if (res.hasException) {
                                    debugPrint(
                                      'Insert failed for ${p['id']}: ${res.exception}',
                                    );
                                  } else {
                                    success += 1;
                                  }
                                }

                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Assigned $success prescriptions',
                                    ),
                                  ),
                                );
                              } catch (e, st) {
                                debugPrint('Assign mutation failed: $e\n$st');
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Failed to assign prescriptions',
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Text('Assign'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          return SafeArea(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 10.h),

                  // Segmented control: Add / View
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    child: CupertinoSegmentedControl<int>(
                      children: {
                        0: Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 8.h,
                            horizontal: 12.w,
                          ),
                          child: Text('Add', style: TextStyle(fontSize: 12.sp)),
                        ),
                        1: Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 8.h,
                            horizontal: 12.w,
                          ),
                          child: Text(
                            'View',
                            style: TextStyle(fontSize: 12.sp),
                          ),
                        ),
                      },
                      groupValue: _segmentIndex,
                      onValueChanged: (v) => setState(() => _segmentIndex = v),
                    ),
                  ),

                  SizedBox(height: 10.h),

                  Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () async {
                            if (_segmentIndex == 0) {
                              // Add flow (existing behaviour)
                              final result = await context
                                  .push<Map<String, dynamic>>(
                                    '/selectMedicationPrescription',
                                  );
                              final messenger = ScaffoldMessenger.of(context);
                              final client = createClient();

                              final generatedCode = await fetchGeneratedCode(
                                client,
                                messenger: messenger,
                                id: 6,
                              );
                              debugPrint('Generated Code = $generatedCode');
                              if (result != null) {
                                String? doctorBackendId;
                                if (_selectedDoctor != null) {
                                  // _selectedDoctor may be a firebase uid; resolve to backend id
                                  doctorBackendId = await fetchUserIdByUid(
                                    _selectedDoctor!,
                                  );
                                }

                                final mapped = {
                                  'id': generatedCode,
                                  'medicationId':
                                      result['medicationId'] ??
                                      (result['medication'] != null
                                          ? result['medication']['id']
                                          : null),
                                  'doctorId': _selectedDoctor,
                                  // backend doctor id expected by backend field 'doctor'
                                  'doctor': doctorBackendId,
                                  'dosageAmount': result['dosageAmount'] ?? '',
                                  'startDate': result['startDate'],
                                  'endDate': result['endDate'],
                                  'status': result['status'] ?? 'active',
                                  'frequencyNote': result['frequencyNote'],
                                  'careRecipientId': _selectedRecipient?['id'],
                                  'takeTime':
                                      (result['takeTime'] as List<dynamic>?)
                                          ?.cast<String>() ??
                                      [],
                                  'medication': result['medication'],
                                  'standardUnit': result['standardUnit'] ?? '-',
                                };
                                setState(() => _prescriptions.add(mapped));
                              }
                            } else {
                              // View flow: fetch previous prescriptions for selected recipient
                              final messenger = ScaffoldMessenger.of(context);
                              if (_selectedRecipient == null) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please select a care recipient to view prescriptions.',
                                    ),
                                  ),
                                );
                                return;
                              }

                              // show loading indicator while fetching
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );

                              final prescriptions = await fetchPrescriptions(
                                _selectedRecipient!['id']!,
                              );

                              Navigator.of(context).pop(); // remove loading

                              _showViewPrescriptions(context, prescriptions);
                            }
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _segmentIndex == 0
                                    ? Icons.add
                                    : Icons.visibility,
                                size: 18.w,
                              ),
                              SizedBox(width: 6.w),
                              Flexible(
                                child: Text(
                                  _segmentIndex == 0
                                      ? 'Add Medication Prescription'
                                      : 'View Medication Prescriptions',
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: TextStyle(fontSize: 11.sp),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMedicationPrescription() {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF4EE), Color(0xFFFFE0CC)],
        ),
        border: Border.all(color: Colors.orange.shade300, width: 2.w),

        borderRadius: BorderRadius.circular(12.w),
        boxShadow: [
          BoxShadow(color: Colors.orange.withOpacity(0.25), blurRadius: 14),
        ],
      ),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.orange.shade900, Colors.orange.shade100],
            ).createShader(bounds),
            blendMode: BlendMode.srcIn,
            child: Icon(Icons.medication, size: 72.w, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildNoMedicationPrescription() {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF4EE), Color(0xFFFFE0CC)],
        ),
        border: Border.all(color: Colors.orange.shade300, width: 2.w),

        borderRadius: BorderRadius.circular(12.w),
        boxShadow: [
          BoxShadow(color: Colors.orange.withOpacity(0.25), blurRadius: 14),
        ],
      ),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.orange.shade900, Colors.orange.shade100],
            ).createShader(bounds),
            blendMode: BlendMode.srcIn,
            child: Icon(Icons.medication, size: 72.w, color: Colors.white),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'No Medication Prescription',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showViewPrescriptions(
    BuildContext context, [
    List<Map<String, dynamic>>? prescriptions,
  ]) {
    final list = prescriptions ?? _prescriptions;

    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      useSafeArea: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            top: 12.h,
            left: 12.w,
            right: 12.w,
            bottom: 24.h,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  'Medication Prescription',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8.h),

                if (list.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    child: const Text('No prescriptions available.'),
                  )
                else
                  ...list.map((p) {
                    final med = p['medication'] as Map<String, dynamic>?;
                    final name = med != null
                        ? (med['name'] ?? '-')
                        : (p['medicationId'] ?? '-');

                    final times =
                        (p['takeTime'] as List<dynamic>?)?.cast<String>() ?? [];

                    final dosageAmount = p['dosageAmount'] ?? '-';
                    final standardUnit = p['standardUnit'] ?? '-';

                    // Card layout with type-based icon and compact info rows
                    final medMap = p['medication'] as Map<String, dynamic>?;
                    final form = ((medMap?['form'] ?? medMap?['type']) ?? '')
                        .toString()
                        .toLowerCase();
                    String defaultAsset;
                    if (form.contains('capsule')) {
                      defaultAsset = 'assets/icons/capsule.png';
                    } else if (form.contains('tablet')) {
                      defaultAsset = 'assets/icons/tablet.png';
                    } else if (form.contains('injection') ||
                        form.contains('inject')) {
                      defaultAsset = 'assets/icons/injection.png';
                    } else if (form.contains('cream') ||
                        form.contains('ointment')) {
                      defaultAsset = 'assets/icons/cream.png';
                    } else {
                      defaultAsset = 'assets/icons/capsule.png';
                    }

                    // If medication entry contains an explicit asset/picture, prefer it
                    final medAsset =
                        (medMap?['asset'] ?? medMap?['picture'] ?? '')
                            ?.toString() ??
                        '';
                    final displayAsset = medAsset.isNotEmpty
                        ? medAsset
                        : defaultAsset;

                    return Card(
                      color: Colors.white,
                      borderOnForeground: true,
                      shadowColor: Colors.orange.shade300,
                      margin: EdgeInsets.only(bottom: 8.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      elevation: 1,
                      child: Padding(
                        padding: EdgeInsets.all(12.w),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44.w,
                              height: 44.w,
                              padding: EdgeInsets.all(6.w),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Builder(
                                builder: (_) {
                                  if (displayAsset.startsWith('http')) {
                                    return Image.network(
                                      displayAsset,
                                      width: 32.w,
                                      height: 32.w,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Image.asset(
                                        defaultAsset,
                                        width: 32.w,
                                        height: 32.w,
                                      ),
                                    );
                                  }
                                  return Image.asset(
                                    displayAsset,
                                    width: 32.w,
                                    height: 32.w,
                                    fit: BoxFit.contain,
                                  );
                                },
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name.toString(),
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 6.h),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Frequency: ${p['frequencyNote'] ?? '-'}',
                                        ),
                                      ),
                                      Text(
                                        'Dose: $dosageAmount $standardUnit',
                                        style: TextStyle(color: Colors.black54),
                                      ),
                                    ],
                                  ),
                                  if (times.isNotEmpty) ...[
                                    SizedBox(height: 8.h),
                                    Wrap(
                                      spacing: 6.w,
                                      children: times
                                          .map((t) => Chip(label: Text(t)))
                                          .toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                SizedBox(height: 12.h),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRecipientSelector(BuildContext context) async {
    final careRecipient = await fetchCareRecipients();
    debugPrint('care_recipient fetched: $careRecipient');

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            top: 12.h,
            left: 12.w,
            right: 12.w,
            bottom: 24.h,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                Center(
                child: Container(
                  width: 36.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
                Text(
                  'Select Care Recipient',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8.h),
                ...careRecipient.map(
                  (s) => ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        s['name']!
                            .split(' ')
                            .map((p) => p.isNotEmpty ? p[0] : '')
                            .take(2)
                            .join(),
                      ),
                    ),
                    title: Text(s['name'] ?? 'Name'),
                    subtitle: Text(s['id'] ?? ''),

                    onTap: () {
                      setState(() {
                        _selectedRecipient = {
                          'id': s['id']!,
                          'name': s['name']!,
                        };
                        _selectedDoctor = null;
                      });
                      Navigator.of(ctx).pop();
                    },
                  ),
                ),
                SizedBox(height: 8.h),

              ],
            ),
          ),
        );
      },
    );
  }
}
