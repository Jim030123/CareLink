import 'package:carelink_mobile/components/status.dart';
import 'package:carelink_mobile/components/page_appbar.dart';
import 'package:flutter/material.dart';
import 'package:carelink_mobile/components/text_field.dart';
import 'package:carelink_mobile/utils/barcode_scanner.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:carelink_mobile/controllers/medication_controller.dart';
import 'package:carelink_mobile/controllers/show_medication_controller.dart';
import 'package:carelink_mobile/utils/auth_service.dart';
import 'package:carelink_mobile/utils/user_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:table_calendar/table_calendar.dart';

enum MedicineType { capsule, tablet, injection, cream }

typedef MedicineChanged = void Function(MedicineType type);

/// GraphQL subscription：实时监听护理员的用药变更
const String medicationUpdatedSub = r'''
subscription OnMedicationUpdated {
  medicationUpdated {
    eventType
    timestamp
    deletedId
    medication {
      id
      name
      description
      packageQuantity
      standardUnit
      picture
      form
      packageUnit
      brand
      sku
      strength
    }
  }
}
''';

class ShowMedication extends StatefulWidget {
  const ShowMedication({super.key, this.initial, this.onChanged});

  final MedicineType? initial;
  final MedicineChanged? onChanged;

  @override
  State<ShowMedication> createState() => _ShowMedicationState();
}

class _ShowMedicationState extends State<ShowMedication> {
  late MedicineType _selected;
  int _selectedSegment = 1; // 0=Schedule,1=Medicine
  late List<Map<String, dynamic>> _items;
  final MedicationController _controller = MedicationController();
  late DateTime _selectedScheduleDate;
  late List<Map<String, dynamic>> _schedules;
  final ShowMedicationController _smController = ShowMedicationController();

  // No longer filter by caregiverId — display all medications

  @override
  void initState() {
    super.initState();
    _selected = widget.initial ?? MedicineType.capsule;
    _items = <Map<String, dynamic>>[];
    _selectedScheduleDate = DateTime.now();
    _schedules = <Map<String, dynamic>>[];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchMedications();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Mapping and subscription-update logic moved to a controller helper
  /// `ShowMedicationController` to keep UI and logic separated.

  Future<Map<String, dynamic>?> _upsertMedication(
    Map<String, dynamic> input,
  ) async {
    final client = GraphQLProvider.of(context).value;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await _smController.upsertMedicationRemote(
        client,
        _controller,
        input,
        _items,
      );

      if (!mounted) return null;

      final updated = (res['items'] as List).cast<Map<String, dynamic>>();
      final data = res['data'] as Map<String, dynamic>?;
      setState(() => _items = updated);

      if (data == null) {
        if (messenger.mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Failed to save: empty response')),
          );
        }
        return null;
      }

      return data;
    } catch (e, st) {
      debugPrint('upsertMed exception: $e\n$st');
      try {
        if (messenger.mounted) {
          messenger.showSnackBar(SnackBar(content: Text('Failed to save: $e')));
        }
      } catch (_) {}
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchMedications() async {
    if (!mounted) return <Map<String, dynamic>>[];
    try {
      final client = GraphQLProvider.of(context).value;
      final meds = await _controller.fetchMedications(client);

      if (!mounted) return <Map<String, dynamic>>[];

      if (meds.isEmpty) {
        if (mounted) {
          setState(() {
            _items = <Map<String, dynamic>>[];
          });
        }
        return <Map<String, dynamic>>[];
      }

      final mapped = meds
          .map(
            (e) =>
                _smController.mapMedicationToItem(Map<String, dynamic>.from(e)),
          )
          .toList();

      if (mounted) {
        setState(() {
          _items = mapped;
        });
      }
      debugPrint('fetchMedications: loaded ${mapped.length} meds');
      return mapped;
    } catch (e, st) {
      debugPrint('fetchMedications failed: $e\n$st');
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _deleteMedicine(String id, int localIndex) async {
    final client = GraphQLProvider.of(context).value;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await _smController.deleteMedicationRemote(
        client,
        _controller,
        id,
        localIndex,
        _items,
      );

      if (!mounted) return;

      final updated = (res['items'] as List).cast<Map<String, dynamic>>();
      final success = res['success'] as bool? ?? false;
      final removed = res['removed'] as Map<String, dynamic>?;

      setState(() => _items = updated);

      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Deleted item'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                if (removed != null && mounted) {
                  setState(() {
                    _items.insert(localIndex.clamp(0, _items.length), removed);
                  });
                }
              },
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }

      if (!success) {
        if (messenger.mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text('Failed to delete: ${res['error']}')),
          );
        }
      } else {
        // optionally refetch to ensure server-side consistency
        try {
          await _fetchMedications();
        } catch (_) {}
      }
    } catch (e, st) {
      debugPrint('deleteMed exception: $e\n$st');
      if (messenger.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  void _select(MedicineType t) {
    setState(() {
      _selected = t;
    });
    widget.onChanged?.call(t);
  }

  /// 把原来的 pile 包成一个 widget，方便外面用 Subscription 包裹
  Widget _buildPile([List<Map<String, dynamic>>? items]) {
    final source = items ?? _items;
    final selectedKey = _selected.toString().split('.').last;
    final filtered = source
        .where((it) => (it['type'] ?? '') == selectedKey)
        .toList();

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

    final List<Map<String, dynamic>> insufficient = [];
    final List<Map<String, dynamic>> sufficient = [];

    for (final it in filtered) {
      final leftVal = (it['left'] ?? '').toString();
      final leftNum = int.tryParse(leftVal) ?? 0;
      if (leftNum < 10) {
        insufficient.add(it);
      } else {
        sufficient.add(it);
      }
    }

    Widget buildCard(Map<String, dynamic> it, {Color? overrideColor}) {
      final asset = (it['asset'] as String?) ?? '';
      final bool isInsufficient = overrideColor != null;
      final bg = overrideColor ?? (it['color'] as Color?) ?? const Color(0xFFF7EAD3);
      final borderColor = isInsufficient ? Colors.redAccent.withOpacity(0.9) : Colors.orange.shade100;
      final gradientColors = isInsufficient
          ? [bg.withOpacity(0.95), bg.withOpacity(0.85)]
          : const [Color(0xFFFFF4EE), Color(0xFFFFE0CC)];
      return Padding(
        padding: EdgeInsets.only(bottom: 12.h),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              final globalIndex = _items.indexWhere(
                (e) => e['id']?.toString() == it['id']?.toString(),
              );

              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (ctx) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(ctx).viewInsets.bottom,
                    ),
                    child: SingleChildScrollView(
                      child: Container(
                        padding: EdgeInsets.all(16.w),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8.w),

                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                  ),
                                  child: Builder(
                                    builder: (_) {
                                      if (asset.startsWith('http')) {
                                        return Image.network(
                                          asset,
                                          width: 44.w,
                                          height: 44.w,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) =>
                                              Image.asset(
                                                'assets/icons/capsule.png',
                                                width: 44.w,
                                                height: 44.w,
                                              ),
                                        );
                                      }
                                      return Image.asset(
                                        asset.isNotEmpty
                                            ? asset
                                            : 'assets/icons/capsule.png',
                                        width: 44.w,
                                        height: 44.w,
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
                                        it['name'] ?? '',
                                        style: TextStyle(
                                          fontSize: 18.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      SizedBox(height: 6.h),
                                      Text(
                                        'Dose: ${it['dose'] ?? ''}',
                                        style: TextStyle(fontSize: 14.sp),
                                      ),
                                      SizedBox(height: 4.h),
                                      Text(
                                        '${it['left'] ?? ''} Left',
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12.h),
                            if ((it['description'] as String?)?.isNotEmpty ??
                                false) ...[
                              Text(
                                'Description',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 6.h),
                              Text(
                                it['description'] ?? '',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 12.h),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.of(ctx).pop();
                                      if (globalIndex >= 0) {
                                        _showEditMedicineSheet(globalIndex);
                                      }
                                    },
                                    icon: const Icon(Icons.edit),
                                    label: const Text('Edit'),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      final should = await showDialog<bool>(
                                        context: ctx,
                                        builder: (dctx) => AlertDialog(
                                          title: const Text('Delete medicine'),
                                          content: Text(
                                            'Delete "${it['name']}"?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(dctx).pop(false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(dctx).pop(true),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (should == true) {
                                        Navigator.of(ctx).pop();
                                        final id = it['id']?.toString() ?? '';
                                        await _deleteMedicine(id, globalIndex);
                                      }
                                    },
                                    icon: const Icon(Icons.delete),
                                    label: const Text('Delete'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12.h),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
              decoration: BoxDecoration(
                border: Border.all(color: borderColor, width: 2.w),
                gradient: LinearGradient(
                  colors: gradientColors,
                ),

                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
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
                    child: Builder(
                      builder: (context) {
                        if (asset.startsWith('http')) {
                          return Image.network(
                            asset,
                            width: 20.w,
                            height: 20.w,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Image.asset(
                              'assets/icons/capsule.png',
                              width: 20.w,
                              height: 20.w,
                            ),
                          );
                        }
                        return Image.asset(
                          asset.isNotEmpty ? asset : 'assets/icons/capsule.png',
                          width: 20.w,
                          height: 20.w,
                          fit: BoxFit.contain,
                        );
                      },
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
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.black54,
                        ),
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

    final insuffColor = const Color(0xFFFFCDD2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (insufficient.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: Text(
              'Insufficient medicine (${insufficient.length})',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: Colors.redAccent,
              ),
            ),
          ),
          ...insufficient.asMap().entries.map((entry) {
            final idx = entry.key;
            final it = entry.value;
            final globalIndex = _items.indexWhere(
              (e) => e['id']?.toString() == it['id']?.toString(),
            );
            return buildCard(it, overrideColor: insuffColor);
          }),
        ],
        if (sufficient.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: Text(
              'Sufficient medicine (${sufficient.length})',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
            ),
          ),
          ...sufficient.asMap().entries.map((entry) {
            final idx = entry.key;
            final it = entry.value;
            final globalIndex = _items.indexWhere(
              (e) => e['id']?.toString() == it['id']?.toString(),
            );
            return buildCard(it);
          }),
        ],
      ],
    );
  }

  Widget _buildCompactStatus() {
    final total = _items.length;
    final insufficient = _items.where((it) {
      final leftVal = (it['left'] ?? '').toString();
      final leftNum = int.tryParse(leftVal) ?? 0;
      return leftNum < 10;
    }).length;

    final color = insufficient > 0 ? Colors.redAccent : Colors.green;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12.w),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            insufficient > 0 ? Icons.error_outline : Icons.check_circle_outline,
            size: 14.w,
            color: Colors.white,
          ),
          SizedBox(width: 6.w),
          Text(
            '$insufficient/$total',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      padding: EdgeInsets.all(16.w),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Schedule',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8.h),
          TableCalendar(
            firstDay: DateTime.now().subtract(const Duration(days: 365)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _selectedScheduleDate,
            selectedDayPredicate: (day) =>
                isSameDay(day, _selectedScheduleDate),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedScheduleDate = selectedDay;
              });
            },
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            calendarStyle: const CalendarStyle(outsideDaysVisible: false),
          ),
          SizedBox(height: 8.h),
          Text(
            'Selected: ${_selectedScheduleDate.toLocal().toString().split(' ').first}',
            style: TextStyle(fontSize: 14.sp, color: Colors.black54),
          ),
          SizedBox(height: 12.h),
          const StatusCard(),
        ],
      ),
    );
  }

  Widget _buildSchedule() {
    final daySchedules = _schedules.where((s) {
      final d = s['date'] as DateTime;
      return d.year == _selectedScheduleDate.year &&
          d.month == _selectedScheduleDate.month &&
          d.day == _selectedScheduleDate.day;
    }).toList();

    if (daySchedules.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 24.h),
        child: Center(
          child: Text(
            'No scheduled medications for selected date',
            style: TextStyle(fontSize: 14.sp, color: Colors.black54),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8.h),
          child: Text(
            'Upcoming',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
          ),
        ),
        ...daySchedules.map((s) {
          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: s['color'] as Color? ?? const Color(0xFFF7EAD3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.medical_services, size: 20.w, color: Colors.white),
                  SizedBox(width: 12.w),
                  Expanded(child: Text(s['name'] as String)),
                  Text(
                    '${s['time'] ?? ''}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  void _showAddScheduleSheet() async {
    final nameCtrl = TextEditingController();
    TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 0);

    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        // use StatefulBuilder for local state updates inside the sheet
        return StatefulBuilder(
          builder: (ctx2, setModalState) {
            // local copies if you want to mutate without touching parent directly
            DateTime _localDate = _selectedScheduleDate;
            TimeOfDay _localTime = selectedTime;

            // Wrap with SingleChildScrollView to avoid overflow when keyboard opens
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx2).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Container(
                  padding: EdgeInsets.all(16.w),
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
                        'Add Schedule',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Medicine name',
                        ),
                        autofocus: true,
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Date: ${_localDate.toLocal().toString().split(' ').first}',
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: ctx2,
                                initialDate: _localDate,
                                firstDate: DateTime.now().subtract(
                                  const Duration(days: 365),
                                ),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (d != null) {
                                setModalState(() => _localDate = d);
                              }
                            },
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Expanded(
                            child: Text('Time: ${_localTime.format(ctx2)}'),
                          ),
                          TextButton(
                            onPressed: () async {
                              final t = await showTimePicker(
                                context: ctx2,
                                initialTime: _localTime,
                              );
                              if (t != null) {
                                setModalState(() => _localTime = t);
                              }
                            },
                            child: const Text('Pick'),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      ElevatedButton(
                        onPressed: () {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;
                          final entry = {
                            'name': name,
                            'date': _localDate,
                            'time': _localTime.format(ctx2),
                            'color': const Color(0xFFB3E5FC),
                          };
                          // 返回 entry 给调用者（父 widget）
                          Navigator.of(ctx2).pop(entry);
                        },
                        child: const Text('Save'),
                      ),
                      SizedBox(height: 12.h),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    // result is the entry (or null if cancelled)
    if (result != null) {
      setState(() => _schedules.add(result));
    }
  }

  Future<void> _showAddMedicineSheet() async {
    final nameCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final dosageAmountCtrl = TextEditingController();
    final dosageUnitCtrl = TextEditingController();
    final frequencyCtrl = TextEditingController();

    final packageUnitCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    final skuCtrl = TextEditingController();
    final strengthCtrl = TextEditingController();

    final uid = AuthService.instance.currentUser?.uid;
    String? caregiverIdVal;
    if (uid != null) {
      final user = await fetchUserByUid(uid);
      if (!mounted) return;
      caregiverIdVal = user == null
          ? null
          : (user['caregiverId'] ??
                    user['caregiver_id'] ??
                    user['caregiverid'] ??
                    user['id'])
                ?.toString();
    }

    final caregiverCtrl = TextEditingController(text: caregiverIdVal ?? '');
    final statusCtrl = TextEditingController(text: 'active');

    String selectedType = _selected.toString().split('.').last;

    if (!mounted) return;

    // 父组件调用：等待 modal 返回的 createdItem，然后再 setState 加入列表
    final createdItem = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return _AddMedicineSheet(
          nameCtrl: nameCtrl,
          descriptionCtrl: descriptionCtrl,
          qtyCtrl: qtyCtrl,
          dosageAmountCtrl: dosageAmountCtrl,
          dosageUnitCtrl: dosageUnitCtrl,
          frequencyCtrl: frequencyCtrl,
          packageUnitCtrl: packageUnitCtrl,
          brandCtrl: brandCtrl,
          skuCtrl: skuCtrl,
          strengthCtrl: strengthCtrl,
          caregiverCtrl: caregiverCtrl,
          statusCtrl: statusCtrl,
          initialType: selectedType, // 可选初始值
          upsertMedication: _upsertMedication, // 函数注入
        );
      },
    );

    // 父组件：收到返回结果后更新 _items
    if (createdItem != null) {
      setState(
        () => _items.add(_smController.mapMedicationToItem(createdItem)),
      );
    }
  }

  void _showEditMedicineSheet(int index) {
    if (index < 0 || index >= _items.length) return;
    final item = _items[index];
    final nameCtrl = TextEditingController(text: item['name'] as String? ?? '');
    final qtyCtrl = TextEditingController(text: item['left']?.toString() ?? '');
    final doseCtrl = TextEditingController(text: item['dose'] as String? ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: EdgeInsets.all(16.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Edit Medicine',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 12.h),
                FormTextField(controller: nameCtrl, label: 'Medicine name'),
                SizedBox(height: 8.h),
                FormTextField(controller: doseCtrl, label: 'Dose'),
                SizedBox(height: 8.h),
                FormTextField(
                  controller: qtyCtrl,
                  label: 'Quantity',
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 12.h),
                ElevatedButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    final qty = qtyCtrl.text.trim();
                    final dose = doseCtrl.text.trim();
                    if (name.isEmpty) return;
                    setState(() {
                      _items[index] = {
                        ..._items[index],
                        'name': name,
                        'left': qty.isNotEmpty ? qty : '0',
                        'dose': dose,
                      };
                    });
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

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
                        color: Colors.orange.withOpacity(0.25),
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
          child: Row(children: [seg('Schedule', 0), seg('Medicine', 1)]),
        ),
      ),
    );
  }

  /// Medicine segment：条件式订阅。传入 `enabled` 为 false 则不建立订阅，仅渲染本地数据。
  Widget _buildMedicineWithSubscription({bool enabled = true}) {
    if (!enabled) {
      // 订阅被禁用时直接渲染当前本地数据
      return _buildPile();
    }

    return Subscription(
      options: SubscriptionOptions(document: gql(medicationUpdatedSub)),
      builder: (result) {
        if (result.hasException) {
          debugPrint('❌ med sub exception: ${result.exception}');
        }

        if (result.data != null) {
          debugPrint('🔔 med sub DATA RECEIVED: ${result.data}');
          final payload = result.data!['medicationUpdated'];
          if (payload != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final updated = _smController.applyMedUpdateTo(
                _items,
                Map<String, dynamic>.from(payload as Map<String, dynamic>),
              );
              if (mounted) {
                setState(() => _items = updated);
              }
            });
          }
        }

        // 无论是否收到事件，UI 一律从 _items 渲染
        return _buildPile();
      },
    );
  }

  Widget _buildSegmentContent() {
    switch (_selectedSegment) {
      case 0:
        return _buildSchedule();
      case 1:
        // only enable subscription when the Medicine tab is active
        return _buildMedicineWithSubscription(enabled: _selectedSegment == 1);
      default:
        return _buildSchedule();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isSchedule = _selectedSegment == 0;

    return Scaffold(
      appBar: const PageAppBar(
        title: 'Medicine Handbook',
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
                    (_selectedSegment == 0)
                        ? _buildCalendar()
                        : Stack(
                            children: [
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
                                          child: _buildOption(
                                            type: MedicineType.capsule,
                                            assetName:
                                                'assets/icons/capsule.png',
                                            label: 'Capsule',
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _buildOption(
                                            type: MedicineType.tablet,
                                            assetName:
                                                'assets/icons/tablet.png',
                                            label: 'Tablet',
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _buildOption(
                                            type: MedicineType.injection,
                                            assetName:
                                                'assets/icons/injection.png',
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
                              Positioned(
                                top: 12.h,
                                right: 12.w,
                                child: _buildCompactStatus(),
                              ),
                            ],
                          ),
                    SizedBox(height: 12.h),

                    _buildSegmentContent(),
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

                  SizedBox(height: 10.h),
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      _buildSegmentedControl(),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (isSchedule) {
                              _showAddScheduleSheet();
                            } else {
                              _showAddMedicineSheet();
                            }
                          },
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
                              Icon(
                                isSchedule ? Icons.schedule : Icons.add,
                                size: 20.w,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                isSchedule ? 'Add Schedule' : 'Add Medicine',
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

class _AddMedicineSheet extends StatefulWidget {
  final TextEditingController nameCtrl;
  final TextEditingController descriptionCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController dosageAmountCtrl;
  final TextEditingController dosageUnitCtrl;
  final TextEditingController frequencyCtrl;
  final TextEditingController packageUnitCtrl;
  final TextEditingController brandCtrl;
  final TextEditingController skuCtrl;
  final TextEditingController strengthCtrl;
  final TextEditingController caregiverCtrl;
  final TextEditingController statusCtrl;
  final String? initialType;
  final Future<Map<String, dynamic>?> Function(Map<String, dynamic>)
  upsertMedication;

  const _AddMedicineSheet({
    required this.nameCtrl,
    required this.descriptionCtrl,
    required this.qtyCtrl,
    required this.dosageAmountCtrl,
    required this.dosageUnitCtrl,
    required this.frequencyCtrl,
    required this.packageUnitCtrl,
    required this.brandCtrl,
    required this.skuCtrl,
    required this.strengthCtrl,
    required this.caregiverCtrl,
    required this.statusCtrl,
    required this.upsertMedication,
    this.initialType,
  });

  @override
  State<_AddMedicineSheet> createState() => _AddMedicineSheetState();
}

class _AddMedicineSheetState extends State<_AddMedicineSheet> {
  late String selectedType;
  bool _loading = false;
  final _formKey = GlobalKey<FormState>();

  Future<void> _scanSku() async {
    // Use the barcode scanner util (camera-based) with manual fallback.
    final scanned = await BarcodeScanner.scan(context);
    if (scanned != null && scanned.isNotEmpty && mounted) {
      setState(() => widget.skuCtrl.text = scanned);
    }
  }

  @override
  void initState() {
    super.initState();
    selectedType = widget.initialType ?? 'capsule';
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _fillMockData() {
    setState(() {
      widget.nameCtrl.text = 'Paracetamol';
      widget.descriptionCtrl.text = 'Pain reliever for fever and headache.';
      widget.qtyCtrl.text = '30';
      widget.dosageAmountCtrl.text = '500';
      widget.strengthCtrl.text = '500';
      widget.dosageUnitCtrl.text = 'mg';
      widget.frequencyCtrl.text = 'Once a day';
      widget.packageUnitCtrl.text = 'box';
      widget.brandCtrl.text = 'Generic';
      widget.skuCtrl.text = 'PARA-500-30';
      widget.statusCtrl.text = 'Active';

      selectedType = 'capsule';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
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
                'Add Medicine',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12.h),

              // 表单开始
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    FormTextField(
                      controller: widget.nameCtrl,
                      label: 'Medicine name',
                      keyboardType: TextInputType.text,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter name'
                          : null,
                    ),
                    SizedBox(height: 8.h),
                    FormTextField(
                      controller: widget.descriptionCtrl,
                      label: 'Description',
                      keyboardType: TextInputType.multiline,
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Expanded(
                          child: FormTextField(
                            controller: widget.qtyCtrl,
                            label: 'Quantity',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: FormTextField(
                            controller: widget.dosageAmountCtrl,
                            label: 'Dosage Amount',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    FormTextField(
                      controller: widget.dosageUnitCtrl,
                      label: 'Dosage Unit (e.g. mg)',
                    ),
                    SizedBox(height: 8.h),
                    FormTextField(
                      controller: widget.frequencyCtrl,
                      label: 'Frequency (e.g. once a day)',
                    ),
                    SizedBox(height: 8.h),
                    // Care Recipient ID (always shown)

                    // If caregiver ID is already provided (injected), hide the
                    // Caregiver ID field — we still include its value in the
                    // submitted `input`. Otherwise show both fields.
                    SizedBox(height: 8.h),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      items: ['capsule', 'tablet', 'injection', 'cream']
                          .map(
                            (t) => DropdownMenuItem(
                              value: t,
                              child: Text(
                                t.isNotEmpty
                                    ? '${t[0].toUpperCase()}${t.substring(1)}'
                                    : t,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => selectedType = v ?? selectedType),
                      decoration: const InputDecoration(labelText: 'Type'),
                    ),
                    SizedBox(height: 8.h),
                    FormTextField(
                      controller: widget.packageUnitCtrl,
                      label: 'Package Unit',
                    ),
                    SizedBox(height: 8.h),
                    FormTextField(controller: widget.brandCtrl, label: 'Brand'),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Expanded(
                          child: FormTextField(
                            controller: widget.skuCtrl,
                            label: 'SKU (scanable)',
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Material(
                          color: Colors.transparent,
                          child: IconButton(
                            tooltip: 'Scan barcode',
                            icon: Icon(Icons.qr_code_scanner, size: 22.w),
                            onPressed: () async {
                              await _scanSku();
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    FormTextField(
                      controller: widget.strengthCtrl,
                      label: 'Strength',
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _fillMockData,
                            icon: const Icon(Icons.auto_fix_high),
                            label: const Text('Fill mock data'),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading
                            ? null
                            : () async {
                                // 收起键盘
                                FocusScope.of(context).unfocus();
                                if (!_formKey.currentState!.validate()) return;
                                setState(() => _loading = true);

                                final qtyText = widget.qtyCtrl.text.trim();
                                final dosageAmountText = widget
                                    .dosageAmountCtrl
                                    .text
                                    .trim();

                                final typeForDb = selectedType.isNotEmpty
                                    ? '${selectedType[0].toUpperCase()}${selectedType.substring(1)}'
                                    : selectedType;

                                final input = {
                                  'name': widget.nameCtrl.text.trim(),
                                  'description': widget.descriptionCtrl.text
                                      .trim(),
                                  'packageQuantity': qtyText.isNotEmpty
                                      ? int.tryParse(qtyText) ?? 0
                                      : 0,
                                  'standardUnit': widget.dosageUnitCtrl.text
                                      .trim(),
                                  // 'picture' removed from form per requirement
                                  'packageUnit': widget.packageUnitCtrl.text
                                      .trim(),
                                  'brand': widget.brandCtrl.text.trim(),
                                  'sku': widget.skuCtrl.text.trim(),
                                  'strength':
                                      widget.strengthCtrl.text.trim().isNotEmpty
                                      ? widget.strengthCtrl.text.trim()
                                      : (dosageAmountText.isNotEmpty
                                            ? dosageAmountText
                                            : null),

                                  // store with capitalized first letter in DB
                                  'form': typeForDb,
                                  // doctorId intentionally omitted (not needed in UI/backend upsert)
                                  'caregiverId': widget.caregiverCtrl.text
                                      .trim(),
                                };

                                try {
                                  final created = await widget.upsertMedication(
                                    input,
                                  );
                                  // 返回给父组件
                                  Navigator.of(context).pop(created);
                                } catch (e) {
                                  // 错误处理（你也可以显示 SnackBar 或 AlertDialog）
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Save failed: $e')),
                                  );
                                  setState(() => _loading = false);
                                }
                              },
                        child: _loading
                            ? SizedBox(
                                height: 16.h,
                                width: 16.h,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Save'),
                      ),
                    ),
                    SizedBox(height: 12.h),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
