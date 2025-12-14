import 'package:carelink_mobile/components/page_appbar.dart';
import 'package:flutter/material.dart';
import 'package:carelink_mobile/components/medicine_type.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ShowPrescription extends StatefulWidget {
  const ShowPrescription({super.key});

  @override
  State<ShowPrescription> createState() => _ShowPrescriptionState();
}

class _ShowPrescriptionState extends State<ShowPrescription> {
  MedicineType _selected = MedicineType.capsule;
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
                    SizedBox(height: 8.h),

                         Container(
                           padding: EdgeInsets.all(16.w),
                           width: constraints.maxWidth,
                           decoration: BoxDecoration(
                             gradient: const LinearGradient(
                               colors: [
                                 Color(0xFFFFF4EE),
                                 Color(0xFFFFE0CC),
                               ],
                             ),
                             borderRadius: BorderRadius.circular(12.r),
                             border: Border.all(
                               color: Colors.orange.shade100,
                               width: 2.w,
                             ),

                             boxShadow: [
                               BoxShadow(
                                 color: Colors.black12,
                                 blurRadius: 4,
                                 offset: Offset(0, 2),
                               ),
                             ],
                           ),
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               const Text(
                                 'Type of Medication',
                                 style: TextStyle(
                                   fontSize: 18,
                                   fontWeight: FontWeight.bold,
                                 ),
                               ),
                               SizedBox(height: 8.h),
                               Row(
                                 children: [
                                   Expanded(
                                     child: buildOption(
                                       type: MedicineType.capsule,
                                       assetName:
                                           'assets/icons/capsule.png',
                                       label: 'Capsule',
                                       selected: _selected,
                                       onSelect: (t) => setState(() => _selected = t),
                                     ),
                                   ),
                                   const SizedBox(width: 8),
                                   Expanded(
                                     child: buildOption(
                                       type: MedicineType.tablet,
                                       assetName:
                                           'assets/icons/tablet.png',
                                       label: 'Tablet',
                                       selected: _selected,
                                       onSelect: (t) => setState(() => _selected = t),
                                     ),
                                   ),
                                   const SizedBox(width: 8),
                                   Expanded(
                                     child: buildOption(
                                       type: MedicineType.injection,
                                       assetName:
                                           'assets/icons/injection.png',
                                       label: 'Injection',
                                       selected: _selected,
                                       onSelect: (t) => setState(() => _selected = t),
                                     ),
                                   ),
                                   const SizedBox(width: 8),
                                   Expanded(
                                     child: buildOption(
                                       type: MedicineType.cream,
                                       assetName: 'assets/icons/cream.png',
                                       label: 'Cream',
                                       selected: _selected,
                                       onSelect: (t) => setState(() => _selected = t),
                                     ),
                                   ),
                                 ],
                               ),
                             ],
                           ),
                         ),
                    SizedBox(height: 12.h),


                  ],
                ),
              ),
            ),
          );
        },
      ),



    );
  }
}