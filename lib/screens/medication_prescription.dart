import 'package:carelink_mobile/components/page_appbar.dart';
import 'package:flutter/material.dart';
import 'package:carelink_mobile/components/medication_type.dart';
import 'package:carelink_mobile/screens/manage_care_reciepient.dart.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MedicationPrescription extends StatefulWidget {
  const MedicationPrescription({super.key});

  @override
  State<MedicationPrescription> createState() => _MedicationPrescriptionState();
}

class _MedicationPrescriptionState extends State<MedicationPrescription> {
  MedicineType _selected = MedicineType.capsule;
  Map<String, String>? _selectedRecipient;
  String? _selectedDoctor;
  final List<Map<String, String>> _medications = [
    {'id': 'm1', 'name': 'Paracetamol', 'dosage': '500mg'},
    {'id': 'm2', 'name': 'Amoxicillin', 'dosage': '250mg'},
    {'id': 'm3', 'name': 'Cetirizine', 'dosage': '10mg'},
  ];
  final Set<String> _selectedMedications = {};
  @override
  Widget build(BuildContext context) {
    return  Scaffold(
       appBar: const PageAppBar(
        title: 'Medicine Prescription',
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
                    Text('Care Recipient', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600)),
                    SizedBox(height: 8.h),
                    GestureDetector(
                      onTap: () => _showRecipientSelector(context),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10.r),
                          boxShadow: [
                            BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 26.r,
                              backgroundColor: Colors.grey.shade200,
                              child: Text(
                                _selectedRecipient == null
                                    ? '?'
                                    : _selectedRecipient!['name']!.split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join(),
                                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedRecipient == null ? 'No care recipient selected' : _selectedRecipient!['name']!,
                                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
                                  ),
                                  SizedBox(height: 6.h),
                                  Text(
                                    _selectedRecipient == null ? 'Tap to select' : (_selectedRecipient!['relation'] ?? ''),
                                    style: TextStyle(fontSize: 13.sp, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Doctor selector (disabled until recipient selected)
                    Text('Doctor', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600)),
                    SizedBox(height: 8.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10.r),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
                      ),
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedDoctor,
                        hint: Text(_selectedRecipient == null ? 'Select a care recipient first' : 'Choose doctor'),
                        onChanged: _selectedRecipient == null
                            ? null
                            : (v) {
                                setState(() {
                                  _selectedDoctor = v;
                                });
                              },
                        items: _selectedRecipient == null
                            ? []
                            : [
                                DropdownMenuItem(value: 'dr_a', child: Text('Dr. Aaron Lee')),
                                DropdownMenuItem(value: 'dr_b', child: Text('Dr. Bella Tan')),
                              ],
                        underline: SizedBox.shrink(),
                      ),
                    ),
                    SizedBox(height: 20.h),

                    // Medication selection list
                    Text('Medications', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600)),
                    SizedBox(height: 8.h),
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10.r),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
                      ),
                      child: Column(
                        children: _medications.map((m) {
                          final id = m['id']!;
                          final selected = _selectedMedications.contains(id);
                          return CheckboxListTile(
                            value: selected,
                            onChanged: _selectedRecipient == null
                                ? null
                                : (v) {
                                    setState(() {
                                      if (v == true) {
                                        _selectedMedications.add(id);
                                      } else {
                                        _selectedMedications.remove(id);
                                      }
                                    });
                                  },
                            title: Text(m['name']! + ' • ' + (m['dosage'] ?? '')),
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        }).toList(),
                      ),
                    ),
                    SizedBox(height: 12.h),

                    ElevatedButton(
                      onPressed: (_selectedRecipient != null && _selectedMedications.isNotEmpty)
                          ? () {
                              final meds = _medications
                                  .where((m) => _selectedMedications.contains(m['id']))
                                  .map((m) => '${m['name']} (${m['dosage']})')
                                  .join(', ');
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text('Assigned to ${_selectedRecipient!['name']}: $meds')));
                            }
                          : null,
                      child: Text('Assign Medication'),
                    ),

                  ],
                ),
              ),
            ),
          );
        },
      ),



    );
  }

  void _showRecipientSelector(BuildContext context) {
    final samples = [
      {'id': 'rcp_1', 'name': 'John Doe', 'relation': 'Self'},
      {'id': 'rcp_2', 'name': 'Mary Lim', 'relation': 'Mother'},
    ];

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12.r))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(top: 12.h, left: 12.w, right: 12.w, bottom: 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Select Care Recipient', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
              SizedBox(height: 8.h),
              ...samples.map((s) => ListTile(
                    leading: CircleAvatar(child: Text(s['name']!.split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join())),
                    title: Text(s['name']!),
                    subtitle: Text(s['relation']!),
                    onTap: () {
                      setState(() {
                        _selectedRecipient = {'id': s['id']!, 'name': s['name']!, 'relation': s['relation']!};
                        _selectedDoctor = null;
                      });
                      Navigator.of(ctx).pop();
                    },
                  )),
              SizedBox(height: 8.h),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ManageCareRecipient()));
                },
                child: Text('Manage care recipients'),
              ),
            ],
          ),
        );
      },
    );
  }
}