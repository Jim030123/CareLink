import 'package:carelink_mobile/components/page_appbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ManageCaregiver extends StatefulWidget {
  const ManageCaregiver({super.key});

  @override
  State<ManageCaregiver> createState() => _ManageCaregiverState();
}

class _ManageCaregiverState extends State<ManageCaregiver> {
  late List<Map<String, String>> caregivers;

  @override
  void initState() {
    super.initState();
    caregivers = [
      {
        'name': 'Ng Ying Qi',
        'relationship': 'Sister',
        'contact': '(555) 123-4567',
      },
      {
        'name': 'John Doe',
        'relationship': 'Brother',
        'contact': '(123) 456-7890',
      },
      {
        'name': 'Mary Tan',
        'relationship': 'Daughter',
        'contact': '(555) 987-6543',
      },
      {
        'name': 'Liam Wong',
        'relationship': 'Son',
        'contact': '(555) 222-3333',
      },
    ];
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
                  // insert into state list
                  Navigator.of(ctx).pop();
                  setState(() {
                    caregivers.add({'name': name, 'relationship': rel, 'contact': contact});
                  });
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

              // Render caregivers as a responsive grid. The first item is
              // an "Add New" card that opens a simple add dialog.
              GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: caregivers.length + 1,
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

                  final c = caregivers[idx - 1];
                  return call_secondaryCaregiverCard(
                    context: context,
                    name: c['name']!,
                    relationship: c['relationship']!,
                    contact: c['contact'],
                    onEdit: () {
                      // TODO: open edit dialog or navigation
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

/// Reusable secondary caregiver card widget builder.
Widget call_secondaryCaregiverCard({
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
