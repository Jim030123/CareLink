import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

enum MedicineType { capsule, tablet, injection, cream }

typedef MedicineChanged = void Function(MedicineType type);

class TypeofMedicine extends StatefulWidget {
  const TypeofMedicine({super.key, this.initial, this.onChanged});

  final MedicineType? initial;
  final MedicineChanged? onChanged;

  @override
  State<TypeofMedicine> createState() => _TypeofMedicineState();
}

class _TypeofMedicineState extends State<TypeofMedicine> {
  late MedicineType _selected;
  int _selectedStatus = 0; // 0 = Sufficient, 1 = Finished
  int _selectedSegment = 1; // 0=Schedule,1=Medicine,2=History

  @override
  void initState() {
    super.initState();
    _selected = widget.initial ?? MedicineType.tablet;
  }

  void _select(MedicineType t) {
    setState(() {
      _selected = t;
    });
    widget.onChanged?.call(t);
  }

  Widget _buildPile() {
    final items = [
      {
        'name': 'Aspirin',
        'dose': '500mg',
        'left': '25',
        'color': const Color(0xFFF7EAD3),
        'asset': 'assets/icons/capsule.png',
      },
      {
        'name': 'Paracetamol',
        'dose': '500mg',
        'left': '25',
        'color': const Color(0xFFF8D8D8),
        'asset': 'assets/icons/capsule.png',
      },
      {
        'name': 'Calcium',
        'dose': '500mg',
        'left': '25',
        'color': const Color(0xFFF7EAD3),
        'asset': 'assets/icons/capsule.png',
      },
      {
        'name': 'Aspirin',
        'dose': '500mg',
        'left': '25',
        'color': const Color(0xFFF7EAD3),
        'asset': 'assets/icons/capsule.png',
      },
      {
        'name': 'Aspirin',
        'dose': '500mg',
        'left': '25',
        'color': const Color(0xFFF7EAD3),
        'asset': 'assets/icons/capsule.png',
      },
      {
        'name': 'Aspirin',
        'dose': '500mg',
        'left': '25',
        'color': const Color(0xFFF7EAD3),
        'asset': 'assets/icons/capsule.png',
      },
      {
        'name': 'Aspirin',
        'dose': '500mg',
        'left': '25',
        'color': const Color(0xFFF7EAD3),
        'asset': 'assets/icons/capsule.png',
      },
      {
        'name': 'Aspirin',
        'dose': '500mg',
        'left': '25',
        'color': const Color(0xFFF7EAD3),
        'asset': 'assets/icons/capsule.png',
      },
      {
        'name': 'Aspirin',
        'dose': '500mg',
        'left': '25',
        'color': const Color(0xFFF7EAD3),
        'asset': 'assets/icons/capsule.png',
      },
      {
        'name': 'Aspirin',
        'dose': '500mg',
        'left': '25',
        'color': const Color(0xFFF7EAD3),
        'asset': 'assets/icons/capsule.png',
      },
      {
        'name': 'Aspirin',
        'dose': '500mg',
        'left': '25',
        'color': const Color(0xFFF7EAD3),
        'asset': 'assets/icons/capsule.png',
      },
    ];

    return Column(
      children: items.map((it) {
        return Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: it['color'] as Color?,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(
                    it['asset'] as String,
                    width: 20.w,
                    height: 20.w,
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    it['name'] as String,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Dose: ${it['dose']}',
                      style: TextStyle(fontSize: 13.sp),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${it['left']} Left',
                      style: TextStyle(fontSize: 12.sp, color: Colors.black54),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget statusRow({required String label, required Color color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,

      children: [
        // Indicator（带阴影的圆点）
        Container(
          width: 8.w,

          height: 8.h,

          decoration: BoxDecoration(
            shape: BoxShape.circle,

            color: color, // 主色

            boxShadow: [
              BoxShadow(
                color: Colors.black12,

                blurRadius: 1,

                offset: Offset(0, 2),
              ),
            ],
          ),
        ),

        SizedBox(width: 12.w),

        // 文本用 Expanded 避免 Row overflow
        Expanded(
          child: Text(
            label,

            maxLines: 1,

            overflow: TextOverflow.ellipsis,

            style: TextStyle(fontSize: 16.sp, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildOption({
    required MedicineType type,
    required String label,
    required String assetName,
  }) {
    final bool isSelected = _selected == type;
    final bg = isSelected ? const Color(0xFFFFECB3) : Colors.white;
    final border = isSelected
        ? Border.all(color: Colors.orange, width: 1.6)
        : Border.all(color: Colors.grey.shade300, width: 1);

    return GestureDetector(
      onTap: () => _select(type),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: border,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.12),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),

            // replace with the assets/icons/cream.png
            child: Image.asset(assetName, width: 28, height: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Colors.black87 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl() {
    Widget seg(String label, int idx) {
      final bool sel = _selectedSegment == idx;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _selectedSegment = idx),
          child: Container(
            height: 44.h,
            decoration: BoxDecoration(
              color: sel ? const Color(0xFFF7EAD3) : Colors.transparent,
              boxShadow: sel
                  ? [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: sel ? Colors.black87 : Colors.black54,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // fixed-width segmented pill so it can be centered and have equal segments
    return SizedBox(
      width: 260.w,
      height: 44.h,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.w),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24.w),
          child: Row(
            children: [
              seg('Schedule', 0),
              seg('Medicine', 1),
              seg('History', 2),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
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
                          Text(
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
                                child: _buildOption(
                                  type: MedicineType.capsule,
                                  assetName: 'assets/icons/capsule.png',
                                  label: 'Capsule',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildOption(
                                  type: MedicineType.tablet,
                                  assetName: 'assets/icons/tablet.png',
                                  label: 'Tablet',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildOption(
                                  type: MedicineType.injection,
                                  assetName: 'assets/icons/injection.png',
                                  label: 'Injection',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildOption(
                                  type: MedicineType.cream,
                                  assetName: 'assets/icons/cream.png',
                                  label: 'Cream',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12),

                    Container(
                      padding: EdgeInsets.all(16.w),
                      width: constraints.maxWidth,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
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
                          Text(
                            'Dosage',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          // Add dosage input fields or widgets here
                          Container(
                            padding: EdgeInsets.all(16.w),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),

                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                //add this
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    "Status",
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                statusRow(
                                  label: 'Active',
                                  color: Color(0xFFF8D8D8),
                                ),
                                statusRow(
                                  label: 'Inactive',
                                  color: Color(0xFFF7EAD3),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 12.h),
                          _buildPile(),
                        ],
                      ),
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(child: Center(child: _buildSegmentedControl())),
                      SizedBox(width: 12.w),

                      Expanded(
                        child: SizedBox(
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add, size: 20.w),
                                SizedBox(width: 8.w),
                                Text(
                                  'Add Medication',
                                  style: TextStyle(fontSize: 11.sp),
                                ),
                              ],
                            ),
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
}
