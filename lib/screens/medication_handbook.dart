import 'package:carelink_mobile/components/numbering.dart';
import 'package:carelink_mobile/components/status.dart';
import 'package:carelink_mobile/components/page_appbar.dart';
import 'package:carelink_mobile/controllers/medication_controller.dart';
import 'package:carelink_mobile/utils/search_utils.dart';
import 'package:flutter/material.dart';
import 'package:carelink_mobile/components/medication_info_chip.dart';
import 'package:carelink_mobile/components/text_field.dart';
import 'package:carelink_mobile/utils/barcode_scanner.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:carelink_mobile/utils/auth_service.dart';
import 'package:carelink_mobile/utils/user_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:carelink_mobile/components/medication_type.dart';
import 'package:carelink_mobile/screens/medication_schedule.dart';

typedef MedicineChanged = void Function(MedicationType type);

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

  final MedicationType? initial;
  final MedicineChanged? onChanged;

  @override
  State<ShowMedication> createState() => _ShowMedicationState();
}

class _ShowMedicationState extends State<ShowMedication> {
  late MedicationType _selected;
  late List<Map<String, dynamic>> _items;
  late TextEditingController _searchCtrl;
  bool _searching = false;
  String? _userType;
  final MedicationController _controller = MedicationController();
  // MedicationSchedule removed — this page shows medicine list only
  final MedicationHandBookController _smController =
      MedicationHandBookController();

  // No longer filter by caregiverId — display all medications

  @override
  void initState() {
    super.initState();
    _selected = widget.initial ?? MedicationType.capsule;
    _items = <Map<String, dynamic>>[];

    // load current user type to control role-specific UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchMedications();
      _loadUserType();
    });
    _searchCtrl = TextEditingController();

    _searchCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadUserType() async {
    try {
      final me = await fetchCurrentUser();
      if (!mounted) return;
      setState(() {
        _userType = me?['userType'] as String?;
      });
    } catch (e) {
      debugPrint('Failed to load user type: $e');
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
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

  Future<List<Map<String, dynamic>>> fetchMedications() async {
    if (!mounted) return <Map<String, dynamic>>[];
    try {
      final client = GraphQLProvider.of(context).value;
      final mapped = await _smController.fetchMappedMedications(
        client,
        _controller,
      );

      if (!mounted) return <Map<String, dynamic>>[];

      setState(() => _items = mapped);
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
          await fetchMedications();
        } catch (_) {}
      }
    } catch (e, st) {
      debugPrint('deleteMed exception: $e\n$st');
      if (messenger.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  void _select(MedicationType t) {
    setState(() {
      _selected = t;
    });
    widget.onChanged?.call(t);
  }

  /// 把原来的 pile 包成一个 widget，方便外面用 Subscription 包裹
  Widget _buildPile([List<Map<String, dynamic>>? items]) {
    final source = items ?? _items;
    final selectedKey = _selected.toString().split('.').last;

    // Delegate filtering and search to shared util.
    final filtered = filterMedications(
      source,
      _searchCtrl.text,
      selectedType: selectedKey,
      searching: _searching,
    );

    if (filtered.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 24.h),
        child: Center(
          child: Text(
            _searching
                ? 'No medications found'
                : 'No medications for selected type',
            style: TextStyle(fontSize: 14.sp, color: Colors.black54),
          ),
        ),
      );
    }

    // Render all filtered items as a single list (no separate insufficient/sufficient sections)
    Widget buildCard(Map<String, dynamic> it, {Color? overrideColor}) {
      final asset = (it['asset'] as String?) ?? '';
      final bool isInsufficient = overrideColor != null;
      final bg =
          overrideColor ?? (it['color'] as Color?) ?? const Color(0xFFF7EAD3);
      final borderColor = isInsufficient
          ? Colors.redAccent.withOpacity(0.9)
          : Colors.orange.shade100;
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
                          // crossAxisAlignment: CrossAxisAlignment.start,
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
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12.r),
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFFFF4EE),
                                          Color(0xFFFFE0CC),
                                        ],
                                      ),
                                      border: Border.all(
                                        color: Colors.orange.withOpacity(0.25),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.orange.withOpacity(
                                            0.25,
                                          ),
                                          blurRadius: 14,
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(14.w),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          /// 药名
                                          Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                /// Image
                                                Container(
                                                  padding: EdgeInsets.all(8.w),
                                                  decoration:
                                                      const BoxDecoration(
                                                        shape: BoxShape.circle,
                                                      ),
                                                  child: Builder(
                                                    builder: (_) {
                                                      if (asset.startsWith(
                                                        'http',
                                                      )) {
                                                        return Image.network(
                                                          asset,
                                                          width: 32.w,
                                                          height: 32.w,
                                                          fit: BoxFit.contain,
                                                          errorBuilder:
                                                              (
                                                                _,
                                                                __,
                                                                ___,
                                                              ) => Image.asset(
                                                                'assets/icons/capsule.png',
                                                                width: 32.w,
                                                                height: 32.w,
                                                              ),
                                                        );
                                                      }
                                                      return Image.asset(
                                                        asset.isNotEmpty
                                                            ? asset
                                                            : 'assets/icons/capsule.png',
                                                        width: 32.w,
                                                        height: 32.w,
                                                        fit: BoxFit.contain,
                                                      );
                                                    },
                                                  ),
                                                ),

                                                SizedBox(height: 6.h),

                                                /// Name
                                                Text(
                                                  it['name'] ?? '',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 18.sp,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),

                                                SizedBox(height: 2.h),

                                                /// Brand
                                                Text(
                                                  'Brand: ${it['brand'] ?? '-'}',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 12.sp,
                                                    color: Colors.black54,
                                                  ),
                                                ),

                                                SizedBox(height: 2.h),

                                                /// Brand
                                                Text(
                                                  'SKU: ${it['sku'] ?? '-'}',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 12.sp,
                                                    color: Colors.black54,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          SizedBox(height: 12.h),

                                          /// ====== 格子 + Icon ======
                                          Center(
                                            child: Wrap(
                                              spacing: 10.w,
                                              runSpacing: 10.h,
                                              children: [
                                                _infoChip(
                                                  icon: Icons.medication,
                                                  label: 'Strength',
                                                  value:
                                                      '${it['strength']} / ${it['standardUnit'] ?? '-'}',
                                                  color: Colors.purple,
                                                ),

                                                _infoChip(
                                                  icon: Icons.inventory_2,
                                                  label: 'Package Size',
                                                  value:
                                                      '${it['packageQuantity']} ${it['standardUnit']} / ${it['packageUnit'] ?? '-'}',
                                                  color: Colors.teal,
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(height: 14.h),

                                          Divider(
                                            height: 1.h,
                                            thickness: 2.h,
                                            color: Colors.grey[300],
                                          ),
                                          SizedBox(height: 14.h),

                                          /// ====== Description ======
                                          if ((it['description'] as String?)
                                                  ?.isNotEmpty ??
                                              false) ...[
                                            SizedBox(height: 14.h),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.info_outline,
                                                  size: 16.sp,
                                                  color: Colors.black54,
                                                ),
                                                SizedBox(width: 6.w),
                                                Text(
                                                  'Description',
                                                  style: TextStyle(
                                                    fontSize: 14.sp,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 6.h),
                                            Text(
                                              it['description'],
                                              style: TextStyle(
                                                fontSize: 13.sp,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ],

                                          /// ====== More Detail ======
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton.icon(
                                              icon: const Icon(
                                                Icons.open_in_new,
                                                size: 16,
                                              ),
                                              label: const Text('More Detail'),
                                              onPressed: () async {
                                                final url =
                                                    'https://www.drugs.com/${it['name'].toString().toLowerCase()}.html';
                                                try {
                                                  await launchUrl(
                                                    Uri.parse(url),
                                                    mode: LaunchMode
                                                        .externalApplication,
                                                  );
                                                } catch (e) {
                                                  debugPrint(
                                                    'Could not launch $url',
                                                  );
                                                }
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12.h),

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
                                          title: const Text('Delete medication'),
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
                gradient: LinearGradient(colors: gradientColors),

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
                        'Brand: ${it['brand']}',
                        style: TextStyle(fontSize: 13.sp),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '${it['packageQuantity']} ${it['standardUnit']} / ${it['packageUnit']}',
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8.h),
          child: Text(
            'Medications (${filtered.length})',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
          ),
        ),
        ...filtered.asMap().entries.map((entry) {
          final it = entry.value;
          return buildCard(it);
        }),
      ],
    );
  }

  // Schedule UI and logic live in `medication_schedule.dart` but this
  // page no longer shows the schedule segment — it displays medicines only.

  Future<void> _showAddMedicineSheet() async {
    final nameCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final dosageUnitCtrl = TextEditingController();
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
        return AddMedicineSheet(
          nameCtrl: nameCtrl,
          descriptionCtrl: descriptionCtrl,
          packageQuantityCtrl: qtyCtrl,
          standardUnitCtrl: dosageUnitCtrl,
          packageUnitCtrl: packageUnitCtrl,
          brandCtrl: brandCtrl,
          skuCtrl: skuCtrl,
          strengthCtrl: strengthCtrl,
          statusCtrl: statusCtrl,
          initialType: selectedType, // 可选初始值
          upsertMedication: _upsertMedication, // 函数注入
        );
      },
    );

    // 父组件：收到返回结果后更新 _items
    if (createdItem != null) {
      final newItem = _smController.mapMedicationToItem(createdItem);
      final newId = newItem['id']?.toString();
      final exists =
          newId != null && _items.any((e) => e['id']?.toString() == newId);
      if (!exists) {
        setState(() => _items.add(newItem));
      } else {
        // If the controller already updated `_items` (via upsert), keep it in sync
        setState(() {
          final idx = _items.indexWhere((e) => e['id']?.toString() == newId);
          if (idx >= 0) _items[idx] = newItem;
        });
      }
    }
  }

  Future<void> _showEditMedicineSheet(int index) async {
    if (index < 0 || index >= _items.length) return;
    final item = _items[index];

    final nameCtrl = TextEditingController(text: item['name'] as String? ?? '');
    final descriptionCtrl = TextEditingController(
      text: item['description'] as String? ?? '',
    );
    final qtyCtrl = TextEditingController(
      text: (item['packageQuantity'] ?? '').toString(),
    );

    final dosageUnitCtrl = TextEditingController(
      text: item['standardUnit'] as String? ?? '',
    );

    final packageUnitCtrl = TextEditingController(
      text: item['packageUnit'] as String? ?? '',
    );
    final brandCtrl = TextEditingController(
      text: item['brand'] as String? ?? '',
    );
    final skuCtrl = TextEditingController(text: item['sku'] as String? ?? '');
    final strengthCtrl = TextEditingController(
      text: item['strength'] as String? ?? '',
    );

    final statusCtrl = TextEditingController(
      text: item['status'] as String? ?? 'active',
    );

    final initialType =
        (item['form'] ?? item['type'] ?? _selected.toString().split('.').last)
            ?.toString();

    final createdItem = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return AddMedicineSheet(
          nameCtrl: nameCtrl,
          descriptionCtrl: descriptionCtrl,
          packageQuantityCtrl: qtyCtrl,
          standardUnitCtrl: dosageUnitCtrl,
          packageUnitCtrl: packageUnitCtrl,
          brandCtrl: brandCtrl,
          skuCtrl: skuCtrl,
          strengthCtrl: strengthCtrl,
          statusCtrl: statusCtrl,
          initialType: initialType,
          existingId: item['id']?.toString(),
          upsertMedication: _upsertMedication,
        );
      },
    );

    if (createdItem != null) {
      final newItem = _smController.mapMedicationToItem(createdItem);
      final newId = newItem['id']?.toString();
      setState(() {
        final idx = _items.indexWhere((e) => e['id']?.toString() == newId);
        if (idx >= 0) {
          _items[idx] = newItem;
        } else {
          _items.insert(index.clamp(0, _items.length), newItem);
        }
      });
    }
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

  // Adapter wrapper for the project's shared `infoChip` component.
  // The existing UI code calls `_infoChip(...)` so provide a small
  // private wrapper that normalizes value to String and delegates
  // to the shared `infoChip` widget exported from
  // `components/medication_info_chip.dart`.
  Widget _infoChip({
    required IconData icon,
    required String label,
    required Object? value,
    Color? color,
  }) {
    return infoChip(
      icon: icon,
      label: label,
      value: value == null ? '-' : value.toString(),
      color: color,
    );
  }

  // Use shared `buildOption` from `components/medicine_type.dart`.
  // Local implementation removed to avoid duplication.

  // segmented control removed — page shows medicine list only

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

  // segments removed — always show medicine list with subscription
  Widget _buildSegmentContent() {
    return _buildMedicineWithSubscription(enabled: true);
  }

  @override
  Widget build(BuildContext context) {
    // no segment on this page; always show medicine list

    return Scaffold(
      appBar: PageAppBar(
        title: 'Medication Handbook',
        showBack: true,
        showSearch: true,
        onSearch: () {
          setState(() {
            _searching = !_searching;
            if (!_searching) _searchCtrl.clear();
          });
        },
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
                    Column(
                      children: [
                        // Search input shown when toggled from AppBar
                        if (_searching)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 8.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12.r),
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
                                Expanded(
                                  child: TextField(
                                    controller: _searchCtrl,
                                    decoration: InputDecoration(
                                      hintText:
                                          'Search name, brand, SKU, description',
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                                if (_searchCtrl.text.isNotEmpty)
                                  IconButton(
                                    icon: Icon(Icons.clear, size: 20.w),
                                    onPressed: () => _searchCtrl.clear(),
                                  ),
                                IconButton(
                                  icon: Icon(Icons.close, size: 20.w),
                                  onPressed: () {
                                    setState(() {
                                      _searching = false;
                                      _searchCtrl.clear();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),

                        // hide type selector while searching — show when not searching
                        if (!_searching) ...[
                          SizedBox(height: 12.h),

                          Container(
                            padding: EdgeInsets.all(16.w),
                            width: constraints.maxWidth,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFF4EE), Color(0xFFFFE0CC)],
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
                                        type: MedicationType.capsule,
                                        assetName: 'assets/icons/capsule.png',
                                        label: 'Capsule',
                                        selected: _selected,
                                        onSelect: (t) =>
                                            setState(() => _selected = t),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: buildOption(
                                        type: MedicationType.tablet,
                                        assetName: 'assets/icons/tablet.png',
                                        label: 'Tablet',
                                        selected: _selected,
                                        onSelect: (t) =>
                                            setState(() => _selected = t),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: buildOption(
                                        type: MedicationType.injection,
                                        assetName: 'assets/icons/injection.png',
                                        label: 'Injection',
                                        selected: _selected,
                                        onSelect: (t) =>
                                            setState(() => _selected = t),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: buildOption(
                                        type: MedicationType.cream,
                                        assetName: 'assets/icons/cream.png',
                                        label: 'Cream',
                                        selected: _selected,
                                        onSelect: (t) =>
                                            setState(() => _selected = t),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
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

                  // Only show Add button for non-Care Recipient users
                  if (_userType != 'Care Recipient')
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: _showAddMedicineSheet,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add, size: 18.w),
                                SizedBox(width: 6.w),
                                Flexible(
                                  child: Text(
                                    'Add Medication',
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
                    )
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class AddMedicineSheet extends StatefulWidget {
  final TextEditingController nameCtrl;
  final TextEditingController descriptionCtrl;
  final TextEditingController packageQuantityCtrl;
  final TextEditingController standardUnitCtrl;
  final TextEditingController packageUnitCtrl;
  final TextEditingController brandCtrl;
  final TextEditingController skuCtrl;
  final TextEditingController strengthCtrl;
  final TextEditingController statusCtrl;
  final String? initialType;
  final String? existingId;
  final Future<Map<String, dynamic>?> Function(Map<String, dynamic>)
  upsertMedication;

  const AddMedicineSheet({super.key,
    required this.nameCtrl,
    required this.descriptionCtrl,
    required this.packageQuantityCtrl,
    required this.standardUnitCtrl,
    required this.packageUnitCtrl,
    required this.brandCtrl,
    required this.skuCtrl,
    required this.strengthCtrl,
    required this.statusCtrl,
    required this.upsertMedication,
    this.initialType,
    this.existingId,
  });

  @override
  State<AddMedicineSheet> createState() => _AddMedicineSheetState();
}

class _AddMedicineSheetState extends State<AddMedicineSheet> {
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
      widget.packageQuantityCtrl.text = '30';
      widget.strengthCtrl.text = '500';
      widget.standardUnitCtrl.text = 'mg';
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
                'Medication',
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
                    SizedBox(height: 12.h),
                    FormTextField(
                      controller: widget.descriptionCtrl,
                      label: 'Description',
                      keyboardType: TextInputType.multiline,
                    ),
                    SizedBox(height: 12.h),
                    FormTextField(
                      controller: widget.packageQuantityCtrl,
                      label: 'Quantity',
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 12.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.w),
                      child: DropdownButtonFormField<String>(
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
                    ),
                    SizedBox(height: 12.h),

                    FormTextField(
                      controller: widget.standardUnitCtrl,
                      label: 'Standard Unit (e.g. pill)',
                    ),
                    SizedBox(height: 20.h),
                    FormTextField(
                      controller: widget.packageUnitCtrl,
                      label: 'Package Unit',
                    ),
                    SizedBox(height: 12.h),
                    FormTextField(controller: widget.brandCtrl, label: 'Brand'),
                    SizedBox(height: 12.h),
                    FormTextField(
                      controller: widget.strengthCtrl,
                      label: 'Strength',
                    ),
                    SizedBox(height: 12.h),
                    Row(
                      children: [
                        Expanded(
                          child: FormTextField(
                            controller: widget.skuCtrl,
                            label: 'SKU (scanable)',
                          ),
                        ),
                        SizedBox(width: 12.w),
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
                    SizedBox(height: 12.h),

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

                                final qtyText = widget.packageQuantityCtrl.text
                                    .trim();

                                final typeForDb = selectedType.isNotEmpty
                                    ? '${selectedType[0].toUpperCase()}${selectedType.substring(1)}'
                                    : selectedType;

                                final id =
                                    widget.existingId ??
                                    await fetchGeneratedCode(
                                      GraphQLProvider.of(context).value,
                                      messenger: ScaffoldMessenger.of(context),
                                      id: 5,
                                    );

                                final input = {
                                  'id': id,
                                  'name': widget.nameCtrl.text.trim(),
                                  'description': widget.descriptionCtrl.text
                                      .trim(),
                                  'packageQuantity': qtyText.isNotEmpty
                                      ? qtyText
                                      : '0',
                                  'standardUnit': widget.standardUnitCtrl.text
                                      .trim(),
                                  // 'picture' removed from form per requirement
                                  'packageUnit': widget.packageUnitCtrl.text
                                      .trim(),
                                  'brand': widget.brandCtrl.text.trim(),
                                  'sku': widget.skuCtrl.text.trim(),
                                  'strength':
                                      widget.strengthCtrl.text.trim().isNotEmpty
                                      ? widget.strengthCtrl.text.trim()
                                      : null,

                                  // store with capitalized first letter in DB
                                  'form': typeForDb,

                                  // doctorId intentionally omitted (not needed in UI/backend upsert)
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
