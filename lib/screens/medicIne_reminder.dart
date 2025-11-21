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
  int _selectedSegment = 1;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial ?? MedicineType.tablet;
  }

  void _select(MedicineType t) {
    setState(() => _selected = t);
    widget.onChanged?.call(t);
  }

  String _labelFor(MedicineType t) {
    switch (t) {
      case MedicineType.capsule:
        return 'Capsule';
      case MedicineType.tablet:
        return 'Tablet';
      case MedicineType.injection:
        return 'Injection';
      case MedicineType.cream:
        return 'Cream';
    }
  }

  String _assetFor(MedicineType t) {
    switch (t) {
      case MedicineType.capsule:
        return 'assets/icons/capsule.png';
      case MedicineType.tablet:
        return 'assets/icons/tablet.png';
      case MedicineType.injection:
        return 'assets/icons/injection.png';
      case MedicineType.cream:
        return 'assets/icons/cream.png';
    }
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Image.asset(assetName, width: 28.w, height: 28.w),
          ),
          SizedBox(height: 8.h),
          Text(label,
              style: TextStyle(
                  fontSize: 12.sp,
                  color: isSelected ? Colors.black87 : Colors.black54)),
        ],
      ),
    );
  }

  final List<Map<String, dynamic>> _items = [
    {'name': 'Aspirin', 'dose': '500mg', 'left': '25', 'asset': 'assets/icons/capsule.png', 'color': const Color(0xFFF7EAD3)},
    {'name': 'Paracetamol', 'dose': '500mg', 'left': '18', 'asset': 'assets/icons/capsule.png', 'color': const Color(0xFFF8D8D8)},
    {'name': 'Calcium', 'dose': '500mg', 'left': '25', 'asset': 'assets/icons/capsule.png', 'color': const Color(0xFFF7EAD3)},
    {'name': 'Ibuprofen', 'dose': '200mg', 'left': '12', 'asset': 'assets/icons/capsule.png', 'color': const Color(0xFFF8D8D8)},
    {'name': 'Amoxicillin', 'dose': '250mg', 'left': '10', 'asset': 'assets/icons/capsule.png', 'color': const Color(0xFFF7EAD3)},
    {'name': 'Metformin', 'dose': '500mg', 'left': '40', 'asset': 'assets/icons/capsule.png', 'color': const Color(0xFFF8D8D8)},
    {'name': 'Simvastatin', 'dose': '20mg', 'left': '30', 'asset': 'assets/icons/capsule.png', 'color': const Color(0xFFF7EAD3)},
    {'name': 'Omeprazole', 'dose': '20mg', 'left': '15', 'asset': 'assets/icons/capsule.png', 'color': const Color(0xFFF8D8D8)},
    {'name': 'Losartan', 'dose': '50mg', 'left': '22', 'asset': 'assets/icons/capsule.png', 'color': const Color(0xFFF7EAD3)},
    {'name': 'Lisinopril', 'dose': '10mg', 'left': '28', 'asset': 'assets/icons/capsule.png', 'color': const Color(0xFFF8D8D8)},
  ];

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
                      const BoxShadow(
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
        child: Row(
          children: [
            seg('Schedule', 0),
            seg('Medicine', 1),
            seg('History', 2),
          ],
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
      body: CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _TypeHeaderDelegate(
              maxExtent: 180.h,
              minExtent: 88.h,
              builder: (context, progress) {
                return Container(
                  padding: EdgeInsets.all(12.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (progress < 1.0) ...[
                        Opacity(
                          opacity: (1 - progress),
                          child: const Text(
                            'Type of Medication',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        SizedBox(
                          height: (1 - progress) * 80.h,
                          child: Row(
                            children: MedicineType.values.map((t) {
                              return Expanded(
                                child: _buildOption(
                                  type: t,
                                  assetName: _assetFor(t),
                                  label: _labelFor(t),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                      Opacity(
                        opacity: progress,
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8.w),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Image.asset(_assetFor(_selected), width: 24.w, height: 24.w),
                            ),
                            SizedBox(width: 12.w),
                            Text(_labelFor(_selected),
                                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          /// 🔥 这里用 SliverList 替代 Column，解决溢出问题!
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final it = _items[index];
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                  child: Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: it['color'],
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        const BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
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
                          child: Image.asset(it['asset'], width: 20.w, height: 20.w),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(it['name'],
                              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Dose: ${it['dose']}', style: TextStyle(fontSize: 13.sp)),
                            SizedBox(height: 4.h),
                            Text('${it['left']} Left',
                                style: TextStyle(fontSize: 12.sp, color: Colors.black54)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: _items.length,
            ),
          ),
        ],
      ),

      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusCard(),
              SizedBox(height: 10.h),
              Row(
                children: [
                  _buildSegmentedControl(),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      child: Text('Add Medication', style: TextStyle(fontSize: 11.sp)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double _maxExtent;
  final double _minExtent;
  final Widget Function(BuildContext, double progress) builder;

  _TypeHeaderDelegate({
    required double maxExtent,
    required double minExtent,
    required this.builder,
  })  : _maxExtent = maxExtent,
        _minExtent = minExtent;

  @override
  double get maxExtent => _maxExtent;

  @override
  double get minExtent => _minExtent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final range = maxExtent - minExtent;
    final progress = (shrinkOffset / range).clamp(0.0, 1.0);
    return builder(context, progress);
  }

  @override
  bool shouldRebuild(_TypeHeaderDelegate oldDelegate) =>
      oldDelegate.maxExtent != maxExtent || oldDelegate.minExtent != minExtent;
}
