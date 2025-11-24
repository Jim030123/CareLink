import 'package:carelink_mobile/components/status.dart';
import 'package:carelink_mobile/components/page_appbar.dart';
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
  late List<Map<String, dynamic>> _items;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial ?? MedicineType.tablet;
    _items = _generateItems();
  }

  List<Map<String, dynamic>> _generateItems() {
    final base = [
      {
        'name': 'Aspirin',
        'dose': '500mg',
        'left': '25',
        'color': const Color(0xFFF7EAD3),
        'asset': 'assets/icons/capsule.png',
        'type': 'capsule'
      },
      {
        'name': 'Paracetamol',
        'dose': '500mg',
        'left': '18',
        'color': const Color(0xFFF8D8D8),
        'asset': 'assets/icons/capsule.png',
        'type': 'capsule'
      },
      {
        'name': 'Calcium',
        'dose': '500mg',
        'left': '25',
        'color': const Color(0xFFF7EAD3),
        'asset': 'assets/icons/capsule.png',
        'type': 'capsule'
      },
      {
        'name': 'Ibuprofen',
        'dose': '200mg',
        'left': '12',
        'color': const Color(0xFFF8D8D8),
        'asset': 'assets/icons/capsule.png',
        'type': 'capsule'
      },
      {
        'name': 'Amoxicillin',
        'dose': '250mg',
        'left': '10',
        'color': const Color(0xFFF7EAD3),
        'asset': 'assets/icons/capsule.png',
        'type': 'capsule'
      },
      {
        'name': 'Metformin',
        'dose': '500mg',
        'left': '40',
        'color': const Color(0xFFF8D8D8),
        'asset': 'assets/icons/capsule.png',
        'type': 'capsule'
      },
      {
        'name': 'Simvastatin',
        'dose': '20mg',
        'left': '30',
        'color': const Color(0xFFF7EAD3),
        'asset': 'assets/icons/capsule.png',
        'type': 'capsule'
      },
      {
        'name': 'Omeprazole',
        'dose': '20mg',
        'left': '15',
        'color': const Color(0xFFF8D8D8),
        'asset': 'assets/icons/capsule.png',
        'type': 'capsule'
      },
      {
        'name': 'Losartan',
        'dose': '50mg',
        'left': '22',
        'color': const Color(0xFFF7EAD3),
        'asset': 'assets/icons/capsule.png',
        'type': 'capsule'
      },
      {
        'name': 'Lisinopril',
        'dose': '10mg',
        'left': '28',
        'color': const Color(0xFFF8D8D8),
        'asset': 'assets/icons/capsule.png',
        'type': 'capsule'
      },
      {
        'name': 'Atorvastatin',
        'dose': '10mg',
        'left': '35',
        'color': const Color(0xFFF7EAD3),
        'asset': 'assets/icons/capsule.png',
        'type': 'capsule'
      },
      {
        'name': 'Cetirizine',
        'dose': '10mg',
        'left': '20',
        'color': const Color(0xFFF8D8D8),
        'asset': 'assets/icons/capsule.png',
        'type': 'capsule'
      },
      {
        'name': 'Loratadine',
        'dose': '10mg',
        'left': '24',
        'color': const Color(0xFFF7EAD3),
        'asset': 'assets/icons/capsule.png',
        'type': 'capsule'
      },
      {
        'name': 'Prednisone',
        'dose': '5mg',
        'left': '8',
        'color': const Color(0xFFF8D8D8),
        'asset': 'assets/icons/capsule.png',
        'type': 'capsule'
      },
      {
        'name': 'Diazepam',
        'dose': '2mg',
        'left': '14',
        'color': const Color(0xFFF7EAD3),
        'asset': 'assets/icons/capsule.png',
        'type': 'capsule'
      },
      {
        'name': 'Warfarin',
        'dose': '3mg',
        'left': '7',
        'color': const Color(0xFFF8D8D8),
        'asset': 'assets/icons/capsule.png',
        'type': 'capsule'
      },
      {
        'name': 'Ranitidine',
        'dose': '150mg',
        'left': '11',
        'color': const Color(0xFFF7EAD3),
        'asset': 'assets/icons/capsule.png',
        'type': 'capsule'
      },
      {
        'name': 'Furosemide',
        'dose': '40mg',
        'left': '19',
        'color': const Color(0xFFF8D8D8),
        'asset': 'assets/icons/capsule.png',
        'type': 'capsule'
      },
      {
        'name': 'Insulin',
        'dose': '10 units',
        'left': '60',
        'color': const Color(0xFFF7EAD3),
        'asset': 'assets/icons/capsule.png',
        'type': 'injection'
      },
      {
        'name': 'Vitamin D',
        'dose': '1000IU',
        'left': '45',
        'color': const Color(0xFFF8D8D8),
        'asset': 'assets/icons/capsule.png',
        'type': 'capsule'
      },
    ];

    return base;
  }

  void _select(MedicineType t) {
    setState(() {
      _selected = t;
    });
    widget.onChanged?.call(t);
  }

  // 现在没用到，可以之后接 list
  Widget _buildPile() {
    final filtered = _items.where((it) => it['type'] == _selected.toString().split('.').last).toList();

    if (filtered.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 24.h),
        child: Center(
          child: Text(
            'No medications for selected type',
            style: TextStyle(fontSize: 14.sp, color: Colors.black54),
          ),
        ),
      );
    }

    return Column(
      children: filtered.map((it) {
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
                  decoration: const BoxDecoration(
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

  /// ✅ 去掉 Expanded，避免在不确定的宽度下出 flex 错
  Widget statusRow({required String label, required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 8.w,
          height: 8.h,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            // 下面阴影
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 1,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        SizedBox(width: 12.w),
        Text(
          label,
          style: TextStyle(fontSize: 16.sp, color: Colors.black87),
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
                  : const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
            ),
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
                  ? const [
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
      appBar: const PageAppBar(
        title: 'Medicine Reminder',
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

                    /// Type of Medication 卡片
                    Container(
                      padding: EdgeInsets.all(16.w),
                      width: constraints.maxWidth,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
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
                    SizedBox(height: 12.h),

                    /// ✅ Status 卡片靠右，内部内容靠左

                    _buildPile(),

                    // 这里以后可以接 _buildPile() 或别的内容
                    // SizedBox(height: 16.h),
                    // _buildPile(),
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
                  Status_Card(),
                  SizedBox(height: 10.h),

                  Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      _buildSegmentedControl(),
                      SizedBox(width: 12.w),
                      Expanded(
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
                                softWrap: true,
                                style: TextStyle(fontSize: 11.sp),
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
}
