import 'package:carelink_mobile/components/status.dart';
import 'package:carelink_mobile/components/page_appbar.dart';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:carelink_mobile/utils/auth_service.dart';
import 'package:carelink_mobile/utils/user_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:table_calendar/table_calendar.dart';

enum MedicineType { capsule, tablet, injection, cream }

typedef MedicineChanged = void Function(MedicineType type);

/// GraphQL subscription：实时监听护理员的用药变更
const String medicationUpdatedSub = r'''
subscription OnMedicationUpdated($caregiverId: String!) {
  medicationUpdated(caregiverId: $caregiverId) {
    eventType
    caregiverId
    timestamp
    deletedId
    medication {
      id
      name
      description
      quantity
      dosageAmount
      dosageUnit
      frequency
      picture
      careRecipientId
      doctorId
      caregiverId
      status
      type
      deleted
    }
  }
}
''';

class TypeofMedicine extends StatefulWidget {
  const TypeofMedicine({super.key, this.initial, this.onChanged});

  final MedicineType? initial;
  final MedicineChanged? onChanged;

  @override
  State<TypeofMedicine> createState() => _TypeofMedicineState();
}

class _TypeofMedicineState extends State<TypeofMedicine> {
  late MedicineType _selected;
  int _selectedSegment = 1; // 0=Schedule,1=Medicine
  late List<Map<String, dynamic>> _items;
  late DateTime _selectedScheduleDate;
  late List<Map<String, dynamic>> _schedules;

  // 当前登录用户对应的 caregiverId（从 user_service 查出来）
  String? _caregiverId;

  // 上一次处理过的订阅事件 key → 用来防止同一条事件被重复 apply
  String? _lastMedEventKey;

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

  /// 把后端的 Medication object 映射成本地 _items 里的结构
  Map<String, dynamic> _mapMedicationToItem(Map<String, dynamic> m) {
    final name = m['name'] ?? '';
    final dosageAmount = m['dosageAmount']?.toString() ?? '';
    final dosageUnit = m['dosageUnit'] ?? '';
    final qty = m['quantity']?.toString() ?? '';
    final type = m['type'] ?? '';

    return {
      'id': m['id'],
      'name': name,
      'dose': '$dosageAmount$dosageUnit',
      'left': qty,
      'color': const Color(0xFFF7EAD3),
      'asset': 'assets/icons/$type.png',
      'type': type,
    };
  }

  /// 去重包装：只有“新事件”才调用 _applyMedUpdate
  void _handleMedUpdate(Map<String, dynamic> payload) {
    try {
      final String? rawEventType =
          payload['eventType']?.toString() ?? payload['event']?.toString();
      final String eventType = (rawEventType ?? '').toUpperCase();
      final String? timestamp = payload['timestamp']?.toString();

      final medRaw = payload['medication'];
      final String? medId = medRaw is Map ? (medRaw['id']?.toString()) : null;

      final String? deletedId =
          payload['deletedId']?.toString() ??
          payload['deleted_id']?.toString() ??
          payload['id']?.toString();

      final String key =
          '${eventType}_${timestamp ?? ''}_${deletedId ?? medId ?? ''}';

      if (key.isNotEmpty && _lastMedEventKey == key) {
        debugPrint('⚠️ duplicate med event ignored, key=$key');
        return;
      }

      _lastMedEventKey = key;
      _applyMedUpdate(payload);
    } catch (e) {
      debugPrint('handleMedUpdate failed: $e');
      _applyMedUpdate(payload);
    }
  }

  /// 把 subscription 收到的 payload 应用到 _items
  void _applyMedUpdate(Map<String, dynamic> payload) {
    try {
      debugPrint('applyMedUpdate payload: $payload');

      final String? eventType = payload['eventType']?.toString();
      final String? deletedId =
          payload['deletedId']?.toString() ?? payload['deleted_id']?.toString();
      final medRaw = payload['medication'];
      final Map<String, dynamic>? med = medRaw is Map
          ? Map<String, dynamic>.from(medRaw)
          : null;

      final String? altEvent = payload['event']?.toString();
      final String? altType = payload['type']?.toString();
      final String resolvedEventType = (eventType ?? altEvent ?? altType ?? '')
          .toUpperCase();

      final bool medMarkedDeleted =
          med != null &&
          (med['deleted'] == true ||
              (med['status'] as String?)?.toLowerCase() == 'deleted');

      final bool payloadIsOnlyId =
          (payload.keys.length == 1 && payload.containsKey('id')) ||
          (payload['id'] is String &&
              med == null &&
              deletedId == null &&
              resolvedEventType.isEmpty &&
              !medMarkedDeleted);

      final String? idCandidate =
          deletedId ?? med?['id']?.toString() ?? payload['id']?.toString();
      debugPrint(
        'applyMedUpdate: resolvedEventType=$resolvedEventType, medMarkedDeleted=$medMarkedDeleted, payloadIsOnlyId=$payloadIsOnlyId, idCandidate=$idCandidate',
      );

      setState(() {
        if ((resolvedEventType == 'CREATED' || resolvedEventType == 'CREATE') &&
            med != null) {
          final mapped = _mapMedicationToItem(med);
          final idx = _items.indexWhere(
            (e) => e['id']?.toString() == mapped['id']?.toString(),
          );
          if (idx >= 0) {
            _items[idx] = mapped;
          } else {
            _items.insert(0, mapped);
          }
        } else if ((resolvedEventType == 'UPDATED' ||
                resolvedEventType == 'UPDATE') &&
            med != null) {
          final mapped = _mapMedicationToItem(med);
          final idx = _items.indexWhere(
            (e) => e['id']?.toString() == mapped['id']?.toString(),
          );
          if (idx >= 0) {
            _items[idx] = mapped;
          } else {
            _items.insert(0, mapped);
          }
        } else if (resolvedEventType.contains('DELET') ||
            medMarkedDeleted ||
            payloadIsOnlyId) {
          final String? idToRemove =
              deletedId ?? med?['id']?.toString() ?? payload['id']?.toString();
          if (idToRemove != null) {
            _items.removeWhere((m) => m['id']?.toString() == idToRemove);
          }
        } else {
          // 没有明确的 eventType，但有 medication → 当作 upsert
          if (med != null) {
            final mapped = _mapMedicationToItem(med);
            final idx = _items.indexWhere(
              (e) => e['id']?.toString() == mapped['id']?.toString(),
            );
            if (idx >= 0) {
              _items[idx] = mapped;
            } else {
              _items.insert(0, mapped);
            }
          }
        }
      });
    } catch (e) {
      debugPrint('applyMedUpdate failed: $e');
    }
  }

  Future<Map<String, dynamic>?> _upsertMedication(
    Map<String, dynamic> input,
  ) async {
    try {
      final client = GraphQLProvider.of(context).value;
      final messenger = ScaffoldMessenger.of(context);
      const String mutation = r'''
        mutation UpsertMedication($object: medication_insert_input!) {
          insert_medication_one(object: $object, on_conflict: {constraint: medication_pkey, update_columns: [name, description, quantity, dosageAmount, dosageUnit, frequency, picture, careRecipientId, type, caregiverId, status]}) {
            id
            name
            quantity
            dosageAmount
            dosageUnit
            frequency
            picture
            careRecipientId
            type
            caregiverId
            status
          }
        }
      ''';

      final isCreate = input['id'] == null || input['id'].toString().isEmpty;
      Map<String, dynamic>? previous;
      String? tempId;

      if (isCreate) {
        tempId = 'temp-${DateTime.now().millisecondsSinceEpoch}';
        final optimisticMed = _mapMedicationToItem({
          'id': tempId,
          'name': input['name'] ?? '',
          'dosageAmount': input['dosageAmount'],
          'dosageUnit': input['dosageUnit'],
          'quantity': input['quantity'],
          'type': input['type'],
        });
        setState(() {
          _items.insert(0, optimisticMed);
        });
      } else {
        final idx = _items.indexWhere(
          (e) => e['id']?.toString() == input['id']?.toString(),
        );
        if (idx >= 0) {
          previous = Map<String, dynamic>.from(_items[idx]);
          final optimisticMed = _mapMedicationToItem({
            'id': input['id'],
            'name': input['name'] ?? previous['name'],
            'dosageAmount': input['dosageAmount'] ?? previous['dosageAmount'],
            'dosageUnit': input['dosageUnit'] ?? previous['dosageUnit'],
            'quantity': input['quantity'] ?? previous['quantity'],
            'type': input['type'] ?? previous['type'],
          });
          setState(() {
            _items[idx] = optimisticMed;
          });
        }
      }

      final res = await client.mutate(
        MutationOptions(document: gql(mutation), variables: {'object': input}),
      );

      if (!mounted) return null;

      if (res.hasException) {
        debugPrint('upsertMed error: ${res.exception}');
        if (mounted) {
          setState(() {
            if (isCreate && tempId != null) {
              _items.removeWhere((e) => e['id'] == tempId);
            } else if (previous != null) {
              final idx = _items.indexWhere(
                (e) => e['id']?.toString() == previous?['id']?.toString(),
              );
              if (idx >= 0) _items[idx] = previous;
            }
          });
        }
        if (messenger.mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text('Failed to save: ${res.exception}')),
          );
        }
        return null;
      }

      final data = res.data?['insert_medication_one'] as Map<String, dynamic>?;

      if (data == null) {
        if (mounted) {
          setState(() {
            if (isCreate && tempId != null) {
              _items.removeWhere((e) => e['id'] == tempId);
            } else if (previous != null) {
              final idx = _items.indexWhere(
                (e) => e['id']?.toString() == previous?['id']?.toString(),
              );
              if (idx >= 0) _items[idx] = previous;
            }
          });
        }
        if (messenger.mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Failed to save: empty response')),
          );
        }
        return null;
      }

      if (isCreate && tempId != null) {
        final mapped = _mapMedicationToItem(data);
        if (mounted) {
          setState(() {
            final idx = _items.indexWhere((e) => e['id'] == tempId);
            if (idx >= 0) {
              _items[idx] = mapped;
            } else {
              _items.insert(0, mapped);
            }
          });
        }
      }

      return data;
    } catch (e, st) {
      debugPrint('upsertMed exception: $e\n$st');
      // messenger may not be available if capture failed, so safe-get
      try {
        final messenger = ScaffoldMessenger.of(context);
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
      const String query = r'''
        query GetMedicationsByCaregiver($caregiverId: String!) {
          medications_by_caregiver(caregiverId: $caregiverId) {
            id
            name
            description
            quantity
            dosageAmount
            dosageUnit
            frequency
            picture
            careRecipientId
            doctorId
            caregiverId
            status
            type
          }
        }
      ''';

      final uid = AuthService.instance.currentUser?.uid;
      if (uid == null) {
        debugPrint('meds query skipped: no current uid');
        return <Map<String, dynamic>>[];
      }

      final user = await fetchUserByUid(uid);
      if (!mounted) return <Map<String, dynamic>>[];
      debugPrint('fetchMedications: fetched user: $user');

      final caregiverId = user == null
          ? null
          : (user['id'] ??
                    user['caregiverId'] ??
                    user['caregiver_id'] ??
                    user['caregiverid'])
                ?.toString();

      if (caregiverId == null || caregiverId.isEmpty) {
        debugPrint('meds query skipped: no caregiverId found on user');
        return <Map<String, dynamic>>[];
      }

      // 存起来给 Subscription 用
      if (mounted) {
        setState(() {
          _caregiverId = caregiverId;
          _lastMedEventKey = null; // 每次全量刷新，重置事件 key
        });
      }

      final result = await client.query(
        QueryOptions(
          document: gql(query),
          variables: {'caregiverId': caregiverId},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (!mounted) return <Map<String, dynamic>>[];

      if (result.hasException) {
        debugPrint('meds query error: ${result.exception}');
        return <Map<String, dynamic>>[];
      }

      final List<dynamic>? meds =
          result.data?['medications_by_caregiver'] as List<dynamic>?;
      if (meds == null || meds.isEmpty) {
        if (mounted) {
          setState(() {
            _items = <Map<String, dynamic>>[];
          });
        }
        return <Map<String, dynamic>>[];
      }

      final mapped = meds
          .map((e) => _mapMedicationToItem(Map<String, dynamic>.from(e)))
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
    if (id.toString().isEmpty) {
      setState(() {
        if (localIndex >= 0 && localIndex < _items.length) {
          _items.removeAt(localIndex);
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Deleted item')));
      return;
    }

    Map<String, dynamic>? removed;
    if (localIndex >= 0 && localIndex < _items.length) {
      removed = _items[localIndex];
      setState(() {
        _items.removeAt(localIndex);
      });
    }

    final client = GraphQLProvider.of(context).value;
    const String mutation = r'''
      mutation DeleteMedication($id: String!) {
        delete_medication_by_pk(id: $id)
      }
    ''';

    final messenger = ScaffoldMessenger.of(context);
    if (messenger.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Deleted item'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              if (removed != null) {
                if (mounted) {
                  setState(() {
                    _items.insert(localIndex.clamp(0, _items.length), removed!);
                  });
                }
              }
            },
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }

    try {
      final res = await client.mutate(
        MutationOptions(
          document: gql(mutation),
          variables: {'id': id.toString()},
        ),
      );
      if (res.hasException) {
        debugPrint('deleteMed error: ${res.exception}');
        if (removed != null && mounted) {
          setState(() {
            _items.insert(localIndex.clamp(0, _items.length), removed!);
          });
        }
        if (messenger.mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text('Failed to delete: ${res.exception}')),
          );
        }
        return;
      }

      final dyn = res.data?['delete_medication_by_pk'];
      debugPrint('deleteMed response raw: $dyn');
      final bool success =
          dyn == true || (dyn is String && dyn.isNotEmpty) || dyn == null;
      if (!success) {
        if (removed != null && mounted) {
          setState(() {
            _items.insert(localIndex.clamp(0, _items.length), removed!);
          });
        }
        if (messenger.mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Delete failed on server')),
          );
        }
        return;
      }

      try {
        await _fetchMedications();
      } catch (e, st) {
        debugPrint('post-delete refetch failed: $e\n$st');
      }
    } catch (e, st) {
      debugPrint('deleteMed exception: $e\n$st');
      if (removed != null && mounted) {
        setState(() {
          _items.insert(localIndex.clamp(0, _items.length), removed!);
        });
      }
      if (messenger.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
      return;
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
      final bg =
          overrideColor ?? (it['color'] as Color?) ?? const Color(0xFFF7EAD3);
      final asset = (it['asset'] as String?) ?? '';
      return Padding(
        padding: EdgeInsets.only(bottom: 12.h),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: bg,
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
                    style: TextStyle(fontSize: 12.sp, color: Colors.black54),
                  ),
                ],
              ),
            ],
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
            return Slidable(
              key: Key('insuff-${it['name'] ?? ''}-$idx'),
              endActionPane: ActionPane(
                motion: const ScrollMotion(),
                children: [
                  SizedBox(width: 8.w),
                  SlidableAction(
                    onPressed: (ctx) {
                      _showEditMedicineSheet(globalIndex);
                    },
                    backgroundColor: Colors.blueAccent,
                    alignment: Alignment.center,
                    foregroundColor: Colors.white,
                    icon: Icons.edit,
                    label: 'Edit',
                    padding: EdgeInsets.symmetric(
                      vertical: 12.h,
                      horizontal: 12.w,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  SizedBox(width: 8.w),
                  SlidableAction(
                    onPressed: (ctx) async {
                      final should = await showDialog<bool>(
                        context: context,
                        builder: (dctx) => AlertDialog(
                          title: const Text('Delete medicine'),
                          content: Text('Delete "${it['name']}"?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(dctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(dctx).pop(true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (should == true) {
                        final id = it['id']?.toString() ?? '';
                        await _deleteMedicine(id, globalIndex);
                      }
                    },
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    icon: Icons.delete,
                    label: 'Delete',
                    padding: EdgeInsets.symmetric(
                      vertical: 12.h,
                      horizontal: 12.w,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ],
              ),
              child: buildCard(it, overrideColor: insuffColor),
            );
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
            return Slidable(
              key: Key('suff-${it['name'] ?? ''}-$idx'),
              endActionPane: ActionPane(
                motion: const ScrollMotion(),
                children: [
                  SlidableAction(
                    onPressed: (ctx) {
                      _showEditMedicineSheet(globalIndex);
                    },
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    icon: Icons.edit,
                    label: 'Edit',
                    padding: EdgeInsets.symmetric(
                      vertical: 12.h,
                      horizontal: 12.w,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  SizedBox(width: 8.w),
                  SlidableAction(
                    onPressed: (ctx) async {
                      final should = await showDialog<bool>(
                        context: context,
                        builder: (dctx) => AlertDialog(
                          title: const Text('Delete medicine'),
                          content: Text('Delete "${it['name']}"?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(dctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(dctx).pop(true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (should == true) {
                        final id = it['id']?.toString() ?? '';
                        await _deleteMedicine(id, globalIndex);
                      }
                    },
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    icon: Icons.delete,
                    label: 'Delete',
                    padding: EdgeInsets.symmetric(
                      vertical: 12.h,
                      horizontal: 12.w,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ],
              ),
              child: buildCard(it),
            );
          }),
        ],
      ],
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
    final pictureCtrl = TextEditingController();
    final careRecipientCtrl = TextEditingController();

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
          pictureCtrl: pictureCtrl,
          careRecipientCtrl: careRecipientCtrl,
          caregiverCtrl: caregiverCtrl,
          statusCtrl: statusCtrl,
          initialType: selectedType, // 可选初始值
          upsertMedication: _upsertMedication, // 函数注入
        );
      },
    );

    // 父组件：收到返回结果后更新 _items
    if (createdItem != null) {
      setState(() => _items.add(_mapMedicationToItem(createdItem)));
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
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Medicine name'),
                ),
                SizedBox(height: 8.h),
                TextField(
                  controller: doseCtrl,
                  decoration: const InputDecoration(labelText: 'Dose'),
                ),
                SizedBox(height: 8.h),
                TextField(
                  controller: qtyCtrl,
                  decoration: const InputDecoration(labelText: 'Quantity'),
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

  /// Medicine segment：这里接上 GraphQL Subscription
  Widget _buildMedicineWithSubscription() {
    // 还没拿到 caregiverId 的时候，就先用本地 list（不会 crash）
    if (_caregiverId == null || _caregiverId!.isEmpty) {
      return _buildPile();
    }

    return Subscription(
      key: ValueKey('medSub:$_caregiverId'),
      options: SubscriptionOptions(
        document: gql(medicationUpdatedSub),
        variables: {'caregiverId': _caregiverId},
      ),
      builder: (result) {
        if (result.hasException) {
          debugPrint('❌ med sub exception: ${result.exception}');
        }

        if (result.data != null) {
          debugPrint('🔔 med sub DATA RECEIVED: ${result.data}');
          final payload = result.data!['medicationUpdated'];
          if (payload != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _handleMedUpdate(
                Map<String, dynamic>.from(payload as Map<String, dynamic>),
              );
            });
          }
        }

        // 不管有没事件，UI 一律从 _items 渲染
        return _buildPile();
      },
    );
  }

  Widget _buildSegmentContent() {
    switch (_selectedSegment) {
      case 0:
        return _buildSchedule();
      case 1:
        return _buildMedicineWithSubscription();
      default:
        return _buildSchedule();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isSchedule = _selectedSegment == 0;

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
                    (_selectedSegment == 0)
                        ? _buildCalendar()
                        : Container(
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
                  const StatusCard(),
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
  final TextEditingController pictureCtrl;
  final TextEditingController careRecipientCtrl;
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
    required this.pictureCtrl,
    required this.careRecipientCtrl,
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
  late final ValueNotifier<Set<String>> _selectedRecipients;

  @override
  void initState() {
    super.initState();
    selectedType = widget.initialType ?? 'capsule';
    final initText = widget.careRecipientCtrl.text.trim();
    _selectedRecipients = ValueNotifier<Set<String>>(initText.isNotEmpty
      ? initText
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
      : <String>{});
  }

  @override
  void dispose() {
    _selectedRecipients.dispose();
    super.dispose();
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
                    TextFormField(
                      controller: widget.nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Medicine name',
                      ),
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter name'
                          : null,
                    ),
                    SizedBox(height: 8.h),
                    TextFormField(
                      controller: widget.descriptionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                      maxLines: 2,
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: widget.qtyCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Quantity',
                            ),
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: TextFormField(
                            controller: widget.dosageAmountCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Dosage Amount',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    TextFormField(
                      controller: widget.dosageUnitCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Dosage Unit (e.g. mg)',
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    SizedBox(height: 8.h),
                    TextFormField(
                      controller: widget.frequencyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Frequency (e.g. once a day)',
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    SizedBox(height: 8.h),
                    TextFormField(
                      controller: widget.pictureCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Picture URL / asset',
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    SizedBox(height: 8.h),
                    // Care Recipient ID (always shown)


                    // If caregiver ID is already provided (injected), hide the
                    // Caregiver ID field — we still include its value in the
                    // submitted `input`. Otherwise show both fields.
                    (() {
                      final caregiverProvided = widget.caregiverCtrl.text
                          .trim()
                          .isNotEmpty;
                      if (caregiverProvided) {
                        // When caregiver is known, show a dropdown of care recipients
                        // fetched from backend and store the selected id into
                        // `careRecipientCtrl`. We also set `statusCtrl` text to
                        // the selected recipient name for display/storage.
                        final caregiverId = widget.caregiverCtrl.text.trim();
                        return FutureBuilder<QueryResult>(
                          future: GraphQLProvider.of(context).value.query(
                            QueryOptions(
                              document: gql(r'''
                                query GetCareRecipientsByCaregiver($caregiverId: String!) {
  care_recipients_by_caregiver(caregiverId: $caregiverId) {
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
                              '''),
                              variables: {'caregiverId': 'caregiverId'},
                              fetchPolicy: FetchPolicy.networkOnly,
                            ),
                          ),
                          builder: (ctx, snap) {

                            final result = snap.data;
                            if (result == null || result.hasException) {
                              return Column(
                                children: [
                                  Text(
                                    'Failed to load recipients',
                                    style: TextStyle(color: Colors.redAccent),
                                  ),
                                  SizedBox(height: 8.h),
                                ],
                              );
                            }
                            // The GraphQL query uses the field
                            // `care_recipients_by_caregiver` in the response.
                            // Use that key to extract the returned list. Also
                            // include a couple of fallbacks for other possible
                            // field names so the UI won't silently show an
                            // empty dropdown if the response key differs.
                            final List<dynamic>? list =
                                (result.data?['care_recipients_by_caregiver'] ??
                                        result
                                            .data?['getCareRecipientsByCaregiverId'] ??
                                        result
                                            .data?['getCareRecipientsByCaregiver'])
                                    as List<dynamic>?;
                            final items = (list ?? []).map<Map<String, String>>(
                              (e) {
                                final first =
                                    (e['firstName'] ?? e['firstName'] ?? '')
                                        .toString()
                                        .trim();
                                final last =
                                    (e['lastName'] ?? e['lastName'] ?? '')
                                        .toString()
                                        .trim();
                                final combined = [
                                  first,
                                  last,
                                ].where((s) => s.isNotEmpty).join(' ');
                                return {
                                  'id': e['id']?.toString() ?? '',
                                  'name': combined.isNotEmpty
                                      ? combined
                                      : (e['name']?.toString() ?? ''),
                                };
                              },
                            ).toList();

                            // Use ChoiceChips to display recipients by name.
                            // This is more visible on small screens and matches
                            // the user's request to "show Name" as a chip.
                            if (items.isEmpty) {
                              // Provide 8 mocked recipients for UI testing/dev
                              final mockItems = List<Map<String, String>>.generate(
                                8,
                                (i) => {
                                  'id': 'mock-${i + 1}',
                                  'name': 'Recipient ${i + 1}'
                                },
                              );

                              return Align(
                                alignment: Alignment.topLeft,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(bottom: 8.0),
                                      child: Text('Care Recipient'),
                                    ),

                                      ValueListenableBuilder<Set<String>>(
                                        valueListenable: _selectedRecipients,
                                        builder: (context, selectedIds, _) {
                                          return Wrap(
                                            spacing: 8.0,
                                            runSpacing: 8.0,
                                            children: mockItems.map<Widget>((m) {
                                              final id = m['id']?.toString() ?? '';
                                              final name = (m['name']?.toString().isNotEmpty == true)
                                                  ? m['name']!.toString()
                                                  : id;

                                              final bool isSelected = selectedIds.contains(id);

                                              return Container(
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
                                                      color: isSelected ? Colors.orange : Colors.grey.shade300,
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
                                                    widget.careRecipientCtrl.text = newSet.join(',');
                                                    final names = mockItems
                                                        .where((x) => newSet.contains(x['id']))
                                                        .map((x) => x['name'] ?? '')
                                                        .where((s) => s.isNotEmpty)
                                                        .toList();
                                                    widget.statusCtrl.text = names.join(', ');
                                                  },
                                                ),
                                              );
                                            }).toList(),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              );
                            }



                            return Align(
                              alignment: Alignment.topLeft,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 8.0),
                                    child: Text('Care Recipient'),
                                  ),

                                  // Horizontally scrollable chips; selection is driven
                                  // by a local ValueNotifier to avoid rebuilding the
                                  // whole sheet (which can steal TextField focus).
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

                                          return Container(
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
                                                  color: isSelected ? Colors.orange : Colors.grey.shade300,
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
                                                widget.careRecipientCtrl.text = newSet.join(',');
                                                final names = items
                                                    .where((x) => newSet.contains(x['id']))
                                                    .map((x) => x['name'] ?? '')
                                                    .where((s) => s.isNotEmpty)
                                                    .toList();
                                                widget.statusCtrl.text = names.join(', ');
                                              },
                                            ),
                                          );
                                        }).toList(),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      }

                      return Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: widget.caregiverCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Caregiver ID',
                              ),
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: TextFormField(
                              controller: widget.statusCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Status',
                              ),
                              textInputAction: TextInputAction.done,
                            ),
                          ),
                        ],
                      );
                    })(),
                    SizedBox(height: 8.h),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      items: ['capsule', 'tablet', 'injection', 'cream']
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => selectedType = v ?? selectedType),
                      decoration: const InputDecoration(labelText: 'Type'),
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

                                final input = {
                                  'name': widget.nameCtrl.text.trim(),
                                  'description': widget.descriptionCtrl.text
                                      .trim(),
                                  'quantity': qtyText.isNotEmpty
                                      ? int.tryParse(qtyText) ?? 0
                                      : 0,
                                  'dosageAmount': dosageAmountText.isNotEmpty
                                      ? double.tryParse(dosageAmountText)
                                      : null,
                                  'dosageUnit': widget.dosageUnitCtrl.text
                                      .trim(),
                                  'frequency': widget.frequencyCtrl.text.trim(),
                                  'picture': widget.pictureCtrl.text.trim(),
                                  'careRecipientId': widget
                                      .careRecipientCtrl
                                      .text
                                      .trim(),
                                  'type': selectedType,
                                  // doctorId intentionally omitted (not needed in UI/backend upsert)
                                  'caregiverId': widget.caregiverCtrl.text
                                      .trim(),
                                  'status': widget.statusCtrl.text.trim(),
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
