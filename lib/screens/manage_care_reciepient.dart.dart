// ignore_for_file: unused_field

import 'package:carelink_mobile/components/page_appbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'dart:convert';

class ManageCareRecipient extends StatefulWidget {
  const ManageCareRecipient({super.key});

  @override
  State<ManageCareRecipient> createState() => _ManageCareRecipientState();
}

class _ManageCareRecipientState extends State<ManageCareRecipient> {
  // Query/test state (similar to TestPage)
  final TextEditingController _idCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _recipients = [];
  Map<String, String>? _caregiverInfo;

  @override
  void initState() {
    super.initState();
    // prefill caregiver id and fetch results for CG-005 on load
    _idCtrl.text = 'CG-005';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runQuery();
    });
  }

  Future<void> _runQuery() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _recipients = [];
      _caregiverInfo = null;
    });

    final client = GraphQLProvider.of(context).value;
    final caregiverId = _idCtrl.text.trim();
    if (caregiverId.isEmpty) {
      setState(() {
        _error = 'Please enter a caregiver id to query.';
        _isLoading = false;
      });
      return;
    }
const String getCaregiverWithRecipientsQuery = r'''
query GetCaregiverWithRecipients($id: String!) {
  caregiver_by_pk(id: $id) {
    id
    firstName
    lastName
    name
    email
    phone
    caregiverType
    careRecipients {
      id
      firstName
      lastName
      dateOfBirth
      gender
      email
      phone
      caregiverId
      type
    }
  }
}
''';
    try {
      final result = await client.query(QueryOptions(
        document: gql(getCaregiverWithRecipientsQuery),
        variables: {'id': caregiverId},
        fetchPolicy: FetchPolicy.networkOnly,
      ));

      if (result.hasException) {
        setState(() {
          _error = result.exception.toString();
        });
        debugPrint('GraphQL exception: ${result.exception.toString()}');
        return;
      }

      final data = result.data?['caregiver_by_pk'] as Map<String, dynamic>?;
      try {
        final pretty = const JsonEncoder.withIndent('  ').convert(result.data);
        debugPrint('GraphQL result:\n$pretty');
      } catch (_) {
        debugPrint('GraphQL result: ${result.data}');
      }

      final recs = (data?['careRecipients'] as List<dynamic>?) ?? [];
      setState(() {
        _recipients = recs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _caregiverInfo = data != null
            ? {
                'id': data['id']?.toString() ?? '',
                'name': (data['name'] ?? '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}').toString(),
                'email': data['email']?.toString() ?? '',
                'phone': data['phone']?.toString() ?? '',
                'caregiverType': data['caregiverType']?.toString() ?? '',
              }
            : null;
      });
    } catch (e, st) {
      setState(() {
        _error = e.toString();
      });
      debugPrint('Query threw error: $e');
      debugPrint(st.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showAddCaregiverSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16.r))),
      builder: (ctx) {
        final nameCtrl = TextEditingController();
        final relCtrl = TextEditingController();
        final contactCtrl = TextEditingController();
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16.h,
            left: 16.w,
            right: 16.w,
            top: 16.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add Secondary Caregiver', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600)),
              SizedBox(height: 12.h),
              TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'Name')),
              SizedBox(height: 8.h),
              TextField(controller: relCtrl, decoration: InputDecoration(labelText: 'Relationship')),
              SizedBox(height: 8.h),
              TextField(controller: contactCtrl, decoration: InputDecoration(labelText: 'Contact')),
              SizedBox(height: 12.h),
              ElevatedButton(
                  onPressed: () {
                  final name = nameCtrl.text.trim();
                  final rel = relCtrl.text.trim();
                  final contact = contactCtrl.text.trim();
                  if (name.isEmpty || rel.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Please enter name and relationship')));
                    return;
                  }
                  // This page no longer stores a local caregivers list. Persisting
                  // should be done via GraphQL mutation; for now just close and
                  // show confirmation.
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Add request submitted (not persisted). Contact: $contact')));
                },
                child: Text('Save'),
              ),
              SizedBox(height: 8.h),
            ],
          ),
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    // caregivers list is stored in state; used for grid rendering
    return Scaffold(
      appBar: PageAppBar(title: 'Caregiver Management', showSearch: true),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            children: [
              // --- Query section (enter caregiver id and fetch recipients)


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

              // Render recipients (from GraphQL) as cards when available;
              // otherwise fall back to local caregivers list. The first card
              // remains an Add New action.
              GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                // Always show at least the Add New card (index 0). If recipients
                // are present, render them after the Add card.
                itemCount: (_recipients.isNotEmpty ? _recipients.length + 1 : 1),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: MediaQuery.of(context).size.width > 700 ? 3 : 2,
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
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(8.r),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                              child: Icon(Icons.add, size: 28.sp, color: Colors.black87),
                            ),
                            SizedBox(height: 8.h),
                            Text('Add', style: TextStyle(fontSize: 14.sp)),
                            Text('New', style: TextStyle(fontSize: 14.sp)),
                          ],
                        ),
                      ),
                    );
                  }

                  if (_recipients.isNotEmpty) {
                    final r = _recipients[idx - 1];
                    final name = '${r['firstName'] ?? ''} ${r['lastName'] ?? ''}'.trim();
                    final contact = (r['email'] as String?) ?? (r['phone'] as String?) ?? '';
                    final relationship = (r['type'] as String?) ?? '';
                    return callSecondaryCaregiverCard(
                      context: context,
                      name: name.isEmpty ? 'No name' : name,
                      relationship: relationship,
                      contact: contact,
                      onEdit: () {
                      },
                    );
                  }
                  // If no recipients (shouldn't reach here because itemCount
                  // would be 1 and idx==0 handled above), return a placeholder.
                  return Container();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable secondary caregiver card widget builder.
Widget callSecondaryCaregiverCard({
  required BuildContext context,
  required String name,
  String? contact,
  String? relationship,
  VoidCallback? onEdit,
  VoidCallback? onTap,
}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10.r),
      boxShadow: [
        BoxShadow(
          color: Colors.black12,
          blurRadius: 10,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.r),
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
                    name.split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join(),
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(name, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
                SizedBox(height: 6.h),
                if (relationship != null)
                  Text(relationship, style: TextStyle(fontSize: 14.sp, color: Colors.black54)),
                SizedBox(height: 6.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(icon: Icon(Icons.edit, size: 18.sp), onPressed: onEdit),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
