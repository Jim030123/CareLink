import 'package:carelink_mobile/components/numbering.dart';
import 'package:carelink_mobile/components/page_appbar.dart';
import 'package:carelink_mobile/components/text_field.dart';
import 'package:carelink_mobile/utils/user_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

class ManageCaregiver extends StatefulWidget {
  const ManageCaregiver({super.key});

  @override
  State<ManageCaregiver> createState() => _ManageCaregiverState();
}

// Return the id only if it matches the CG-XXX-X pattern.
String? _formatCaregiverId(String? id) {
  if (id == null || id.isEmpty) return null;
  return null;
}

class _ManageCaregiverState extends State<ManageCaregiver> {
  List<Map<String, String>> secondCaregivers = [];
  bool _loading = true;
  String? _loginPrefix;
  // Selected care-recipient IDs for the add-caregiver sheet
  final ValueNotifier<Set<String>> _selectedRecipients = ValueNotifier(
    <String>{},
  );
  // Items shown as possible care recipients (id/name pairs). Populated from loaded caregivers by default.
  List<Map<String, String>> items = [];

  static const String _getCaregiverByIdQuery = r"""
query GetSecondaryByCaregiver($caregiverId: String) {
  secondary_caregivers_by_caregiver(caregiverId: $caregiverId) {
    id
    caregiverId
    careRecipientId
    relationship
    permissionLevel
    status
    name
    createdAt
    caregiver {
      id
      firstName
      lastName
      email
      phone
    }
    careRecipients {
      id
      firstName
      lastName
      email
      phone
    }
  }
}
""";

  static const String _getRecipientsByCaregiverQuery = r"""
query Care_recipients_by_caregiver($caregiverId: String!) {
  care_recipients_by_caregiver(caregiverId: $caregiverId) {
    id
    firstName
    lastName
    dateOfBirth
    gender
    email
    phone
    caregiverId
  }
}
""";

  static const String _insertSecondaryMutation = r'''
mutation InsertSecondary($object: SecondaryCaregiverInput!) {
  insert_secondary_caregiver(object: $object) {
    id
    caregiverId
    careRecipientId
    relationship
    permissionLevel
    status
    name
    createdAt
  }
}
''';

  static const String _updateSecondaryMutation = r'''
mutation UpdateSecondary($pk_columns: SecondaryCaregiverPkColumnsInput!, $_set: SecondaryCaregiverInput) {
  update_secondary_caregiver(pk_columns: $pk_columns, _set: $_set) {
    id
    caregiverId
    careRecipientId
    relationship
    permissionLevel
    status
    name
    createdAt
  }
}
''';

  static const String _deleteSecondaryMutation = r'''
mutation DeleteSecondary($pk_columns: SecondaryCaregiverPkColumnsInput!) {
  delete_secondary_caregiver(pk_columns: $pk_columns)
}
''';


  late TextEditingController nameCtrl;
  late TextEditingController relCtrl;
  late TextEditingController phoneCtrl;
  late TextEditingController emailCtrl;
  late TextEditingController permCtrl;
  late TextEditingController careRecipientCtrl;
  late TextEditingController statusCtrl;



  @override
  void initState() {
    super.initState();

    nameCtrl = TextEditingController();
    relCtrl = TextEditingController();
    phoneCtrl = TextEditingController();
    emailCtrl = TextEditingController();
    permCtrl = TextEditingController();
    careRecipientCtrl = TextEditingController();
    statusCtrl = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCaregivers('CG-003');
      _loadRecipients('CG-003');
    });
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    relCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    permCtrl.dispose();
    careRecipientCtrl.dispose();
    statusCtrl.dispose();
    _selectedRecipients.dispose();
    super.dispose();
  }



  // Open the add-sheet with mock values populated into text fields
  void _addMockData() {
    setState(() {
      // ensure ChoiceChip items exist so chips render and selections work
      items = [
        {'id': 'CR-001', 'name': 'Alice Tan'},
        {'id': 'CR-002', 'name': 'Bob Lim'},
        {'id': 'CR-003', 'name': 'Cheng Wei'},
      ];
      // clear any previously selected recipients
      _selectedRecipients.value = <String>{};
    });

    // open the sheet with initial values filled into the text fields
    _showAddCaregiverSheet(
      initialData: {
        'name': 'Mock Name',
        'relationship': 'Friend',
        'phoneNumber': '+60123456789',
        'permission': 'Full',
        'careRecipientIds': 'CR-001,CR-003',
        'status': 'Alice Tan, Cheng Wei',
        'email': 'mock@example.com',
      },
    );
  }

  Future<void> _loadRecipients(String caregiverId) async {
    try {
      final client = GraphQLProvider.of(context).value;
      final result = await client.query(
        QueryOptions(
          document: gql(_getRecipientsByCaregiverQuery),
          variables: {'caregiverId': caregiverId},
        ),
      );

      if (result.hasException) {
        debugPrint('GetRecipients exception: ${result.exception}');
        return;
      }

      final data =
          result.data?['care_recipients_by_caregiver'] as List<dynamic>?;
      if (data == null) {
        setState(() {
          items = [];
        });
        return;
      }

      final List<Map<String, String>> recips = data.map((item) {
        final m = item as Map<String, dynamic>;
        final name =
            ((m['firstName'] as String?) ?? '') +
            ' ' +
            ((m['lastName'] as String?) ?? '');
        return {'id': (m['id'] as String?) ?? '', 'name': name.trim()};
      }).toList();

      setState(() {
        items = recips;
        // clear any previously selected recipients
        _selectedRecipients.value = <String>{};
      });
    } catch (e) {
      debugPrint('Exception in _loadRecipients: $e');
    }
  }

  /// Load secondary caregivers for a given caregiver id and populate `caregivers`.
  Future<void> _loadCaregivers(String caregiverId) async {
    setState(() {
      _loading = true;
    });

    try {
      final client = GraphQLProvider.of(context).value;
      final result = await client.query(
        QueryOptions(
          document: gql(_getCaregiverByIdQuery),
          variables: {'caregiverId': caregiverId},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (result.hasException) {
        debugPrint('GetCaregivers exception: ${result.exception}');
        setState(() {
          secondCaregivers = [];
          _loading = false;
        });
        return;
      }

      final data =
          result.data?['secondary_caregivers_by_caregiver'] as List<dynamic>?;

      if (data == null || data.isEmpty) {
        setState(() {
          secondCaregivers = [];
          _loading = false;
        });
        return;
      }

      final List<Map<String, String>> list = data.map((item) {
        final m = item as Map<String, dynamic>;

        final caregiver = m['caregiver'] as Map<String, dynamic>?;

        final name =
            (m['name'] as String?) ??
            [
              caregiver?['firstName'],
              caregiver?['lastName'],
            ].whereType<String>().join(' ');

        final contact =
            caregiver?['phone'] as String? ??
            caregiver?['email'] as String? ??
            '';

        return {
          'id': (m['id'] as String?) ?? '',
          'email': (m['email'] as String?) ?? '',

          'caregiverId': (m['caregiverId'] as String?) ?? '',

          'name': name.trim(),
          'relationship': (m['relationship'] as String?) ?? '',
          'contact': contact,
          'permission': (m['permissionLevel'] as String?) ?? '',
        };
      }).toList();

      setState(() {
        secondCaregivers = list;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('Exception in _loadCaregivers: $e\n$st');
      setState(() {
        secondCaregivers = [];
        _loading = false;
      });
    }
  }

  void _showAddCaregiverSheet({Map<String, String>? initialData}) {
    showModalBottomSheet(
      context: context,

      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (ctx) {
        final nameCtrl = TextEditingController();
        final relCtrl = TextEditingController();
        final phoneNumberCtrl = TextEditingController();
        final permCtrl = TextEditingController();
        final careRecipientCtrl = TextEditingController();
        final emailCtrl = TextEditingController();
        final statusCtrl = TextEditingController();
        // If initialData provided, populate controllers and selected recipients
        if (initialData != null) {
          nameCtrl.text = initialData['name'] ?? '';
          relCtrl.text = initialData['relationship'] ?? '';
          // Accept either 'phone' or 'contact' from initialData (keys were inconsistent)
          phoneNumberCtrl.text = initialData['phone'] ?? initialData['contact'] ?? '';

          emailCtrl.text = initialData['email'] ?? '';
          permCtrl.text = initialData['permission'] ?? '';
          careRecipientCtrl.text = initialData['careRecipientIds'] ?? '';
          statusCtrl.text = initialData['status'] ?? '';

          final sel = (initialData['careRecipientIds'] ?? '')
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toSet();
          _selectedRecipients.value = sel;
        }
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16.h,
              left: 16.w,
              right: 16.w,
              top: 16.h,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),

                SizedBox(height: 12.h),

                Text(
                  'Add Secondary Caregiver',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 12.h),
                FormTextField(
                  controller: nameCtrl,
                  label: 'Name',
                  keyboardType: TextInputType.text,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter name'
                      : null,
                ),
                SizedBox(height: 8.h),

                FormTextField(
                  controller: phoneNumberCtrl,
                  label: 'Phone Number',
                  keyboardType: TextInputType.phone,
                  validator: (v) => null,
                ),
                SizedBox(height: 8.h),

                FormTextField(
                  controller: emailCtrl,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => null,
                ),
                SizedBox(height: 8.h),

                Padding(
                  padding: EdgeInsets.all(8.h),
                  child: DropdownButtonFormField<String>(
                    // only use controller value if it matches one of the options
                    value: (['Sister', 'Brother', 'Daughter', 'Son', 'Parent', 'Spouse', 'Friend', 'Other']
                            .contains(relCtrl.text))
                        ? relCtrl.text
                        : null,
                    decoration: InputDecoration(labelText: 'Relationship'),
                    items: [
                      'Sister',
                      'Brother',
                      'Daughter',
                      'Son',
                      'Parent',
                      'Spouse',
                      'Friend',
                      'Other',
                    ].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (v) {
                      relCtrl.text = v ?? '';
                    },
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Please select relationship'
                        : null,
                  ),
                ),

                Padding(
                  padding: EdgeInsets.all(8.h),
                  child: DropdownButtonFormField<String>(
                    // only use controller value if it matches one of the options
                    value: (['Full', 'Alert Only', 'View'].contains(permCtrl.text))
                        ? permCtrl.text
                        : null,
                    decoration: InputDecoration(labelText: 'Permission Level'),
                    items: ['Full', 'Alert Only', 'View']
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (v) {
                      permCtrl.text = v ?? '';
                    },
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Please select permission level'
                        : null,
                  ),
                ),

                SizedBox(height: 8.h),

                Align(
                  alignment: Alignment.topLeft,

                  child: Text(
                    'Assign the Care Recipient',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                SizedBox(height: 8.h),

                ValueListenableBuilder<Set<String>>(
                  valueListenable: _selectedRecipients,
                  builder: (context, selectedIds, _) {
                    return Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: items.map<Widget>((m) {
                        final id = m['id']?.toString() ?? '';
                        final name = (m['name']?.toString().isNotEmpty == true)
                            ? m['name']!.toString()
                            : id;

                        final bool isSelected = selectedIds.contains(id);

                        return Align(
                          alignment: AlignmentGeometry.centerLeft,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: Colors.orange.withOpacity(0.25),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                  : const [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 6,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                            ),
                            child: ChoiceChip(
                              label: Text(name),
                              selected: isSelected,
                              backgroundColor: Colors.white,
                              selectedColor: const Color(0xFFFFECB3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected
                                      ? Colors.orange
                                      : Colors.grey.shade300,
                                  width: isSelected ? 1.6 : 1,
                                ),
                              ),
                              elevation: 0,
                              onSelected: (sel) {
                                final newSet = Set<String>.from(selectedIds);
                                if (sel) {
                                  newSet.add(id);
                                } else {
                                  newSet.remove(id);
                                }
                                _selectedRecipients.value = newSet;
                                careRecipientCtrl.text = newSet.join(',');
                                final names = items
                                    .where((x) => newSet.contains(x['id']))
                                    .map((x) => x['name'] ?? '')
                                    .where((s) => s.isNotEmpty)
                                    .toList();
                                statusCtrl.text = names.join(', ');
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                SizedBox(height: 12.h),

                // Button inside bottom sheet to fill mock values into the form
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // ensure recipient items exist for chips
                      setState(() {
                        items = [
                          {'id': 'CR-001', 'name': 'Alice Tan'},
                          {'id': 'CR-002', 'name': 'Bob Lim'},
                          {'id': 'CR-003', 'name': 'Cheng Wei'},
                        ];
                      });

                      // fill controllers and select chips
                      nameCtrl.text = 'Mock Name';
                      relCtrl.text = 'Friend';
                      phoneNumberCtrl.text = '+60123456789';
                      permCtrl.text = 'Full';
                      careRecipientCtrl.text = 'CR-001,CR-003';
                      statusCtrl.text = 'Alice Tan, Cheng Wei';
                      _selectedRecipients.value = {'CR-001', 'CR-003'};
                    },
                    icon: Icon(Icons.auto_fix_high, size: 14.sp),
                    label: Text('Fill Mock Data'),
                  ),
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Delete button (only enabled when editing an existing entry)
                    OutlinedButton(
                      onPressed:
                          (initialData != null &&
                              (initialData['id']?.isNotEmpty == true))
                          ? () async {
                              final idToDelete = initialData!['id'];
                              final confirmed = await showDialog<bool>(
                                context: ctx,
                                builder: (dctx) => AlertDialog(
                                  title: Text('Delete secondary caregiver'),
                                  content: Text(
                                    'Are you sure you want to delete this entry?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(dctx).pop(false),
                                      child: Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(dctx).pop(true),
                                      child: Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed != true) return;

                              try {
                                final client = GraphQLProvider.of(ctx).value;
                                final pk = {'id': idToDelete};
                                final res = await client.mutate(
                                  MutationOptions(
                                    document: gql(_deleteSecondaryMutation),
                                    variables: {'pk_columns': pk},
                                  ),
                                );
                                if (res.exception != null) {
                                  debugPrint(
                                    'Delete (sheet) error: ${res.exception}',
                                  );
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Delete failed: ${res.exception.toString()}',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                // remove locally and close sheet
                                setState(() {
                                  secondCaregivers.removeWhere(
                                    (e) => e['id'] == idToDelete,
                                  );
                                });
                                Navigator.of(ctx).pop();
                              } catch (e) {
                                debugPrint('Exception deleting from sheet: $e');
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text('Unexpected error: $e'),
                                  ),
                                );
                              }
                            }
                          : null,
                      child: Text('Delete'),
                    ),

                    ElevatedButton(
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        final rel = relCtrl.text.trim();
                        final phoneNumber = phoneNumberCtrl.text.trim();
                        final permission = permCtrl.text.trim();
                        final email = emailCtrl.text.trim();

                        // Obtain GraphQL client and messenger from the sheet context
                        final client = GraphQLProvider.of(ctx).value;
                        final messenger = ScaffoldMessenger.of(ctx);

                        // Get current user id from backend helper
                        final currentUser = await fetchCurrentUser();
                        final caregiverId = currentUser?['id'] as String?;

                        if (name.isEmpty || rel.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Please enter name and relationship',
                              ),
                            ),
                          );
                          return;
                        }

                        // Build payload for GraphQL insert (careRecipient as array)
                        final careRecipientList = careRecipientCtrl.text
                            .split(',')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList();

                        // Only generate a new id when inserting (not when editing)
                        String? roleId;
                        final bool isEdit =
                            initialData != null &&
                            (initialData['id']?.isNotEmpty == true);
                        if (!isEdit) {
                          roleId = await fetchGeneratedCode(
                            client,
                            messenger: messenger,
                            id: 9,
                          );
                        }

                        // debug: print the values we're about to save
                        debugPrint(
                          'Saving secondary caregiver: '
                          'roleId=${roleId}, caregiverId=${caregiverId}, '
                          'careRecipientIds=${careRecipientCtrl.text}, name=${name}, '
                          'rel=${rel}, phone=${phoneNumber}, permission=${permission}, '
                          'selectedRecipients=${_selectedRecipients.value}',
                        );
                        if (!isEdit) {
                          roleId = await fetchGeneratedCode(
                            client,
                            messenger: messenger,
                            id: 9,
                          );
                        }
                        final generatedId =
                            roleId?.toString() ??
                            (initialData?['id'] ??
                                'local-${DateTime.now().millisecondsSinceEpoch}');
                        final object = {
                          // server schema requires `id: String!`
                          'id': generatedId,
                          'caregiverId': caregiverId ?? null,
                          'careRecipientId': careRecipientList,
                          'relationship': rel,
                          'permissionLevel': permission,
                          'status': statusCtrl.text,
                          'name': name,
                          'email': email,
                          // include phone so it is persisted to backend
                          'phone': phoneNumber,
                          'createdAt': DateTime.now().toIso8601String(),
                        };

                        try {
                          final bool isEdit =
                              initialData != null &&
                              (initialData['id']?.isNotEmpty == true);
                          QueryResult mutRes;

                          if (isEdit) {
                            // update existing
                            final pk = {'id': initialData!['id']};
                            mutRes = await client.mutate(
                              MutationOptions(
                                document: gql(_updateSecondaryMutation),
                                variables: {'pk_columns': pk, '_set': object},
                              ),
                            );
                          } else {
                            // insert new
                            mutRes = await client.mutate(
                              MutationOptions(
                                document: gql(_insertSecondaryMutation),
                                variables: {'object': object},
                              ),
                            );
                          }

                          if (mutRes.exception != null) {
                            debugPrint(
                              'Save secondary caregiver error: ${mutRes.exception}',
                            );
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Failed to save: ${mutRes.exception.toString()}',
                                ),
                              ),
                            );
                            return;
                          }

                          final row = isEdit
                              ? (mutRes.data?['update_secondary_caregiver']
                                    as Map<String, dynamic>?)
                              : (mutRes.data?['insert_secondary_caregiver']
                                    as Map<String, dynamic>?);

                          // Close sheet and update local state from returned row when available
                          Navigator.of(ctx).pop();
                          setState(() {
                            final savedId = row != null
                                ? (row['id'] as String? ?? generatedId)
                                : generatedId;
                            final entry = {
                              'id': savedId,
                              'caregiverId': row != null
                                  ? (row['caregiverId'] as String? ??
                                        caregiverId?.toString() ??
                                        '')
                                  : (caregiverId?.toString() ?? ''),
                              'careRecipientId': row != null
                                  ? ((row['careRecipientId'] as List<dynamic>?)
                                            ?.join(',') ??
                                        careRecipientCtrl.text)
                                  : careRecipientCtrl.text,
                              'name': row != null
                                  ? (row['name'] as String? ?? name)
                                  : name,
                              'relationship': row != null
                                  ? (row['relationship'] as String? ?? rel)
                                  : rel,
                              'contact': phoneNumber,
                              'permission': row != null
                                  ? (row['permissionLevel'] as String? ??
                                        permission)
                                  : permission,
                              'status': row != null
                                  ? (row['status'] as String? ?? 'active')
                                  : 'active',
                            };

                            final idx = secondCaregivers.indexWhere(
                              (e) => e['id'] == savedId,
                            );
                            if (idx >= 0) {
                              secondCaregivers[idx] = Map<String, String>.from(
                                entry.map(
                                  (k, v) => MapEntry(k, v?.toString() ?? ''),
                                ),
                              );
                            } else {
                              secondCaregivers.add(
                                Map<String, String>.from(
                                  entry.map(
                                    (k, v) => MapEntry(k, v?.toString() ?? ''),
                                  ),
                                ),
                              );
                            }

                            debugPrint(
                              'secondCaregivers length after save=${secondCaregivers.length}',
                            );
                          });
                        } catch (e, st) {
                          debugPrint(
                            'Exception saving secondary caregiver: $e\n$st',
                          );
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Unexpected error: $e')),
                          );
                          return;
                        }
                      },
                      child: Text('Save'),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // caregivers list is stored in state; used for grid rendering
    // If a login prefix is set (e.g., 'CG-004'), only show caregivers matching that prefix.
    final visible = secondCaregivers
        .where((c) => c['caregiverId'] == 'CG-003')
        .toList();
    return Scaffold(
      appBar: PageAppBar(title: 'Caregiver Management', showSearch: true),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            children: [
              Text(
                'Secondary Caregiver',
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

              SizedBox(height: 16.h),
              // Quick test button to add mock data

              // Render caregivers as a responsive grid. The first item is
              // an "Add New" card that opens a simple add dialog. Show
              // a loading indicator while fetching from GraphQL.
              _loading
                  ? SizedBox(
                      height: 180.h,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : visible.isEmpty
                  ? SizedBox(
                      height: 180.h,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'No caregivers found',
                            style: TextStyle(
                              fontSize: 16.sp,
                              color: Colors.black54,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          ElevatedButton(
                            onPressed: () {
                              // Implement retry logic here
                            },
                            child: Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: visible.length + 1,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: MediaQuery.of(context).size.width > 700
                            ? 3
                            : 2,
                        mainAxisSpacing: 12.h,
                        crossAxisSpacing: 12.w,
                        childAspectRatio: 0.9,
                      ),
                      itemBuilder: (context, idx) {
                        if (idx == 0) {
                          // Add New card
                          return InkWell(
                            onTap: () => _showAddCaregiverSheet(),
                            borderRadius: BorderRadius.circular(10.r),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.green.shade100,
                                    Colors.green.shade300,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(10.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(8.r),
                                    decoration: BoxDecoration(),
                                    child: Icon(
                                      Icons.add,
                                      size: 28.sp,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  Text(
                                    'Add',
                                    style: TextStyle(fontSize: 14.sp),
                                  ),
                                  Text(
                                    'New',
                                    style: TextStyle(fontSize: 14.sp),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final c = visible[idx - 1];
                        return callSecondaryCaregiverCard(
                          context: context,
                          id: c['id'],
                          name: c['name']!,
                          relationship: c['relationship']!,
                          contact: c['contact'],
                          onEdit: () {
                            debugPrint(
                              'Edit pressed for secondary caregiver id=${c['id']}',
                            );
                            // open sheet populated for editing
                            _showAddCaregiverSheet(
                              initialData: {
                                'id': c['id'] ?? '',
                                'name': c['name'] ?? '',
                                'relationship': c['relationship'] ?? '',
                                'phoneNumber': c['phoneNumber'] ?? '',
                                'email': c['email'] ?? '',
                                'permission': c['permission'] ?? '',
                                'careRecipientIds':
                                    c['careRecipientId'] ??
                                    c['careRecipientIds'] ??
                                    '',
                                'status': c['status'] ?? '',
                              },
                            );
                          },
                          onDelete: () async {
                            final id = c['id'];
                            debugPrint(
                              'Delete pressed for secondary caregiver id=$id',
                            );
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (dctx) => AlertDialog(
                                title: Text('Delete secondary caregiver'),
                                content: Text(
                                  'Are you sure you want to delete this entry?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(dctx).pop(false),
                                    child: Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(dctx).pop(true),
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm != true) return;

                            try {
                              final client = GraphQLProvider.of(context).value;
                              final pk = {'id': id};
                              final res = await client.mutate(
                                MutationOptions(
                                  document: gql(_deleteSecondaryMutation),
                                  variables: {'pk_columns': pk},
                                ),
                              );
                              if (res.exception != null) {
                                debugPrint('Delete error: ${res.exception}');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Delete failed: ${res.exception.toString()}',
                                    ),
                                  ),
                                );
                                return;
                              }

                              setState(() {
                                secondCaregivers.removeWhere(
                                  (e) => e['id'] == id,
                                );
                              });
                            } catch (e) {
                              debugPrint(
                                'Exception deleting secondary caregiver: $e',
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Unexpected error: $e')),
                              );
                            }
                          },
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaregiverSheet extends StatelessWidget {
  const _CaregiverSheet({
    required this.nameCtrl,
    required this.relCtrl,
    required this.phoneCtrl,
    required this.emailCtrl,
    required this.permCtrl,
    required this.careRecipientCtrl,
    required this.statusCtrl,
    required this.items,
    required this.selectedRecipients,
    required this.onSave,
  });

  final TextEditingController nameCtrl;
  final TextEditingController relCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController permCtrl;
  final TextEditingController careRecipientCtrl;
  final TextEditingController statusCtrl;

  final List<Map<String, String>> items;
  final ValueNotifier<Set<String>> selectedRecipients;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16.h,
        left: 16.w,
        right: 16.w,
        top: 16.h,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Secondary Caregiver',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600)),

            FormTextField(controller: nameCtrl, label: 'Name'),
            FormTextField(controller: phoneCtrl, label: 'Phone'),
            FormTextField(controller: emailCtrl, label: 'Email'),

            DropdownButtonFormField<String>(
              value: relCtrl.text.isEmpty ? null : relCtrl.text,
              decoration: InputDecoration(labelText: 'Relationship'),
              items: const [
                'Sister', 'Brother', 'Parent', 'Friend', 'Other'
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => relCtrl.text = v ?? '',
            ),

            DropdownButtonFormField<String>(
              value: permCtrl.text.isEmpty ? null : permCtrl.text,
              decoration: InputDecoration(labelText: 'Permission'),
              items: const ['Full', 'View', 'Alert Only']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => permCtrl.text = v ?? '',
            ),

            SizedBox(height: 12.h),

            ValueListenableBuilder<Set<String>>(
              valueListenable: selectedRecipients,
              builder: (_, selected, __) {
                return Wrap(
                  spacing: 8,
                  children: items.map((m) {
                    final id = m['id']!;
                    final selectedNow = selected.contains(id);
                    return ChoiceChip(
                      label: Text(m['name'] ?? id),
                      selected: selectedNow,
                      onSelected: (v) {
                        final newSet = Set<String>.from(selected);
                        v ? newSet.add(id) : newSet.remove(id);
                        selectedRecipients.value = newSet;
                        careRecipientCtrl.text = newSet.join(',');
                      },
                    );
                  }).toList(),
                );
              },
            ),

            SizedBox(height: 16.h),

            ElevatedButton(
              onPressed: onSave,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable secondary caregiver card widget builder.
Widget callSecondaryCaregiverCard({
  required BuildContext context,
  String? id,
  required String name,
  String? contact,
  String? relationship,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
  VoidCallback? onTap,
}) {
  String? displayId = _formatCaregiverId(id);
  return Container(
    decoration: BoxDecoration(
      border: Border.all(color: Colors.orange.withOpacity(0.25), width: 2),
      gradient: const LinearGradient(
        colors: [Colors.white, Colors.white70],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(12.w),
      boxShadow: [
        BoxShadow(color: Colors.orange.withOpacity(0.25), blurRadius: 2),
      ],
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.r),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Centered avatar + name + relationship to match grid card design
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 28.r,
                    backgroundColor: Colors.grey.shade200,
                    child: Text(
                      name
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
                  SizedBox(height: 8.h),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (displayId != null && displayId.isNotEmpty) ...[
                    SizedBox(height: 6.h),
                    Text(
                      displayId,
                      style: TextStyle(fontSize: 12.sp, color: Colors.black38),
                    ),
                  ],
                  SizedBox(height: 6.h),
                  if (relationship != null)
                    Text(
                      relationship,
                      style: TextStyle(fontSize: 14.sp, color: Colors.black54),
                    ),
                  SizedBox(height: 6.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, size: 18.sp),
                        onPressed: () => onEdit?.call(),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, size: 18.sp),
                        onPressed: () => onDelete?.call(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
