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
  // local schedule entries (for quick local UI testing)
  late List<Map<String, dynamic>> _schedules;
  // GraphQL subscription
  // No realtime subscription or stream controller — using simple CRUD refresh

  @override
  void initState() {
    super.initState();
    _selected = widget.initial ?? MedicineType.capsule;
    // start with an empty list; _fetchMedications will populate it
    _items = <Map<String, dynamic>>[];
    _selectedScheduleDate = DateTime.now();
    _schedules = <Map<String, dynamic>>[];
    // run after first frame so Inherited widgets (GraphQLProvider) are available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchMedications();
    });
  }

  @override
  void dispose() {
    // no subscriptions to cancel
    super.dispose();
  }

  // Realtime subscriptions removed to simplify to non-realtime CRUD

  Future<Map<String, dynamic>?> _upsertMedication(Map<String, dynamic> input) async {
    try {
      final client = GraphQLProvider.of(context).value;
      const String mutation = r'''
        mutation UpsertMedication($object: medication_insert_input!) {
          insert_medication_one(object: $object, on_conflict: {constraint: medication_pkey, update_columns: [name, description, quantity, dosageAmount, dosageUnit, frequency, picture, careRecipientId, type, doctorId, caregiverId, status]}) {
            id
            name
            quantity
            dosageAmount
            dosageUnit
            frequency
            picture
            careRecipientId
            type
            doctorId
            caregiverId
            status
          }
        }
      ''';

      // Optimistic UI: insert/update locally before server responds
      final isCreate = input['id'] == null || input['id'].toString().isEmpty;
      Map<String, dynamic>? previous;
      String? tempId;

      if (isCreate) {
        tempId = 'temp-${DateTime.now().millisecondsSinceEpoch}';
        final name = input['name'] ?? '';
        final dosageAmount = (input['dosageAmount'] ?? '').toString();
        final dosageUnit = input['dosageUnit'] ?? '';
        final qty = (input['quantity'] ?? '').toString();
        final type = input['type'] ?? '';
        final optimistic = {
          'id': tempId,
          'name': name,
          'dose': '$dosageAmount$dosageUnit',
          'left': qty,
          'color': const Color(0xFFF7EAD3),
          'asset': 'assets/icons/$type.png',
          'type': type,
        };
        setState(() {
          _items.insert(0, optimistic);
        });
      } else {
        // update: keep previous for rollback
        final idx = _items.indexWhere((e) => e['id']?.toString() == input['id']?.toString());
        if (idx >= 0) {
          previous = Map<String, dynamic>.from(_items[idx]);
          final name = input['name'] ?? previous['name'] ?? '';
          final dosageAmount = (input['dosageAmount'] ?? previous['dosageAmount'] ?? '').toString();
          final dosageUnit = input['dosageUnit'] ?? previous['dosageUnit'] ?? '';
          final qty = (input['quantity'] ?? previous['quantity'] ?? '').toString();
          final type = input['type'] ?? previous['type'] ?? '';
          final optimistic = {
            'id': input['id'],
            'name': name,
            'dose': '$dosageAmount$dosageUnit',
            'left': qty,
            'color': const Color(0xFFF7EAD3),
            'asset': 'assets/icons/$type.png',
            'type': type,
          };
          setState(() {
            _items[idx] = optimistic;
          });
        }
      }

      final res = await client.mutate(MutationOptions(document: gql(mutation), variables: {'object': input}));
      if (res.hasException) {
        debugPrint('upsertMed error: ${res.exception}');
        // rollback optimistic update
        setState(() {
          if (isCreate && tempId != null) {
            _items.removeWhere((e) => e['id'] == tempId);
          } else if (previous != null) {
            final idx = _items.indexWhere((e) => e['id']?.toString() == previous?['id']?.toString());
            if (idx >= 0) _items[idx] = previous;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: ${res.exception.toString()}')));
        return null;
      }

      final data = res.data?['insert_medication_one'] as Map<String, dynamic>?;

      if (data == null) {
        // unexpected response: rollback
        setState(() {
          if (isCreate && tempId != null) {
            _items.removeWhere((e) => e['id'] == tempId);
          } else if (previous != null) {
            final idx = _items.indexWhere((e) => e['id']?.toString() == previous?['id']?.toString());
            if (idx >= 0) _items[idx] = previous;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save: empty server response')));
        return null;
      }

      // Replace temp id with real id if created
      if (isCreate && tempId != null) {
        setState(() {
          final idx = _items.indexWhere((e) => e['id'] == tempId);
          if (idx >= 0) {
            _items[idx] = {
              'id': data['id'],
              'name': data['name'] ?? _items[idx]['name'],
              'dose': ((data['dosageAmount']?.toString() ?? '') + (data['dosageUnit'] ?? '')).trim(),
              'left': (data['quantity']?.toString() ?? '0'),
              'color': const Color(0xFFF7EAD3),
              'asset': 'assets/icons/${data['type'] ?? _items[idx]['type']}.png',
              'type': data['type'] ?? _items[idx]['type'],
            };
          }
        });
      }

      return data;
    } catch (e, st) {
      debugPrint('upsertMed exception: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
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

      // Retrieve current user by uid and extract caregiver id
      final uid = AuthService.instance.currentUser?.uid;
      if (uid == null) {
        debugPrint('meds query skipped: no current uid');
        return <Map<String, dynamic>>[];
      }

        final user = await fetchUserByUid(uid);
        debugPrint('fetchMedications: fetched user: $user');
        // Prefer `id` (database primary key) if backend uses that as the
        // caregiver identifier; otherwise fall back to caregiverId fields.
        final caregiverId = user == null
          ? null
          : (user['id'] ?? user['caregiverId'] ?? user['caregiver_id'] ?? user['caregiverid'])?.toString();

      if (caregiverId == null || caregiverId.isEmpty) {
        debugPrint('meds query skipped: no caregiverId found on user');
        return <Map<String, dynamic>>[];
      }

      final result = await client.query(
        QueryOptions(
          document: gql(query),
          variables: {
            'caregiverId': caregiverId,
          },
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (result.hasException) {
        debugPrint('meds query error: ${result.exception}');
        return <Map<String, dynamic>>[];
      }

      final List<dynamic>? meds =
          result.data?['medications_by_caregiver'] as List<dynamic>?;
      if (meds == null || meds.isEmpty) {
        return <Map<String, dynamic>>[];
      }

      // map server objects to local item structure
      final mapped = meds.map((m) {
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
      }).toList();

      final mappedList = mapped.cast<Map<String, dynamic>>();
      setState(() {
        _items = mappedList;
      });
      debugPrint('fetchMedications: loaded ${mappedList.length} meds');
      return mappedList;
    } catch (e, st) {
      debugPrint('fetchMedications failed: $e\n$st');
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _deleteMedicine(String id, int localIndex) async {
    if (id.toString().isEmpty) {
      setState(() {
        if (localIndex >= 0 && localIndex < _items.length) _items.removeAt(localIndex);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted item')));
      return;
    }

    // Optimistic delete: remove locally first and allow undo via Snackbar
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

    // show snackbar with undo option
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(
      content: const Text('Deleted item'),
      action: SnackBarAction(label: 'Undo', onPressed: () {
        // reinstate locally (server-side delete already requested)
        if (removed != null) {
          setState(() {
            _items.insert(localIndex.clamp(0, _items.length), removed!);
          });
        }
      }),
      duration: const Duration(seconds: 4),
    ));

    try {
      final res = await client.mutate(MutationOptions(document: gql(mutation), variables: {'id': id.toString()}));
      if (res.hasException) {
        debugPrint('deleteMed error: ${res.exception}');
        // on failure, reinsert locally
        if (removed != null) {
          setState(() {
            _items.insert(localIndex.clamp(0, _items.length), removed!);
          });
        }
        messenger.showSnackBar(SnackBar(content: Text('Failed to delete: ${res.exception.toString()}')));
        return;
      }

      // Accept several server shapes for delete response
      final dyn = res.data?['delete_medication_by_pk'];
      debugPrint('deleteMed response raw: $dyn');
      final bool success = dyn == true || (dyn is String && dyn.isNotEmpty) || dyn == null;
      if (!success) {
        if (removed != null) {
          setState(() {
            _items.insert(localIndex.clamp(0, _items.length), removed!);
          });
        }
        messenger.showSnackBar(const SnackBar(content: Text('Delete failed on server')));
        return;
      }

      // Server delete succeeded; subscription (if active) will notify other clients.
      // As a more robust fallback (in case server doesn't emit a delete subscription
      // event or other clients don't receive it), refresh the medications list so
      // local UI stays in sync.
      try {
        await _fetchMedications();
      } catch (e, st) {
        debugPrint('post-delete refetch failed: $e\n$st');
      }

      return;
    } catch (e, st) {
      debugPrint('deleteMed exception: $e\n$st');
      if (removed != null) {
        setState(() {
          _items.insert(localIndex.clamp(0, _items.length), removed!);
        });
      }
      messenger.showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      return;
    }
  }

  void _select(MedicineType t) {
    setState(() {
      _selected = t;
    });
    widget.onChanged?.call(t);
  }

  // Render pile view. Accepts optional `items` snapshot for reactive updates
  Widget _buildPile([List<Map<String, dynamic>>? items]) {
    final source = items ?? _items;
    final selectedKey = _selected.toString().split('.').last;
    final filtered = source.where((it) => (it['type'] ?? '') == selectedKey).toList();

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
            final globalIndex = _items.indexWhere((e) => e['id']?.toString() == it['id']?.toString());
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
          }).toList(),

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
            final globalIndex = _items.indexWhere((e) => e['id']?.toString() == it['id']?.toString());
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
          }).toList(),
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
            calendarStyle: CalendarStyle(outsideDaysVisible: false),
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

  // Placeholder: Schedule view (upcoming scheduled meds)
  Widget _buildSchedule() {
    // Show schedules for the currently selected date
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
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  void _showAddScheduleSheet() {
    final nameCtrl = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay(hour: 8, minute: 0);

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
                  'Add Schedule',
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
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Date: ${_selectedScheduleDate.toLocal().toString().split(' ').first}',
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: _selectedScheduleDate,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (d != null) {
                          setState(() => _selectedScheduleDate = d);
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
                      child: Text('Time: ${selectedTime.format(context)}'),
                    ),
                    TextButton(
                      onPressed: () async {
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: selectedTime,
                        );
                        if (t != null) {
                          selectedTime = t;
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
                      'date': _selectedScheduleDate,
                      'time': selectedTime.format(context),
                      'color': const Color(0xFFB3E5FC),
                    };
                    setState(() {
                      _schedules.add(entry);
                    });
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Save'),
                ),
                SizedBox(height: 12.h),
              ],
            ),
          ),
        );
      },
    );
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
    final doctorCtrl = TextEditingController();
    final uid = AuthService.instance.currentUser?.uid;
    String? caregiverIdVal;
    if (uid != null) {
      final user = await fetchUserByUid(uid);
      caregiverIdVal = user == null
          ? null
          : (user['caregiverId'] ?? user['caregiver_id'] ?? user['caregiverid'] ?? user['id'])?.toString();
    }

    final caregiverCtrl = TextEditingController(text: caregiverIdVal ?? '');
    final statusCtrl = TextEditingController(text: 'active');

    String selectedType = _selected.toString().split('.').last;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                padding: EdgeInsets.all(16.w),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Add Medicine',
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
                        controller: descriptionCtrl,
                        decoration: const InputDecoration(labelText: 'Description'),
                        maxLines: 2,
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: qtyCtrl,
                              decoration: const InputDecoration(labelText: 'Quantity'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: TextField(
                              controller: dosageAmountCtrl,
                              decoration: const InputDecoration(labelText: 'Dosage Amount'),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      TextField(
                        controller: dosageUnitCtrl,
                        decoration: const InputDecoration(labelText: 'Dosage Unit (e.g. mg)'),
                      ),
                      SizedBox(height: 8.h),
                      TextField(
                        controller: frequencyCtrl,
                        decoration: const InputDecoration(labelText: 'Frequency (e.g. once a day)'),
                      ),
                      SizedBox(height: 8.h),
                      TextField(
                        controller: pictureCtrl,
                        decoration: const InputDecoration(labelText: 'Picture URL / asset'),
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: careRecipientCtrl,
                              decoration: const InputDecoration(labelText: 'Care Recipient ID'),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: TextField(
                              controller: doctorCtrl,
                              decoration: const InputDecoration(labelText: 'Doctor ID'),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: caregiverCtrl,
                              decoration: const InputDecoration(labelText: 'Caregiver ID'),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: TextField(
                              controller: statusCtrl,
                              decoration: const InputDecoration(labelText: 'Status'),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      // type selector
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        items: ['capsule', 'tablet', 'injection', 'cream']
                            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (v) => setModalState(() => selectedType = v ?? selectedType),
                        decoration: const InputDecoration(labelText: 'Type'),
                      ),
                      SizedBox(height: 12.h),
                      ElevatedButton(
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;

                          final qty = qtyCtrl.text.trim();
                          final dosageAmount = double.tryParse(dosageAmountCtrl.text.trim());
                          final dosageUnit = dosageUnitCtrl.text.trim();

                          final input = {
                            'name': name,
                            'description': descriptionCtrl.text.trim(),
                            'quantity': qty.isNotEmpty ? int.tryParse(qty) ?? 0 : 0,
                            'dosageAmount': dosageAmount,
                            'dosageUnit': dosageUnit,
                            'frequency': frequencyCtrl.text.trim(),
                            'picture': pictureCtrl.text.trim(),
                            'careRecipientId': careRecipientCtrl.text.trim(),
                            'type': selectedType,
                            'doctorId': doctorCtrl.text.trim(),
                            'caregiverId': caregiverCtrl.text.trim(),
                            'status': statusCtrl.text.trim(),
                          };

                          final created = await _upsertMedication(input);
                          if (created != null) {
                            final med = {
                              'id': created['id'],
                              'name': created['name'] ?? name,
                              'dose': ((created['dosageAmount']?.toString() ?? '') + (created['dosageUnit'] ?? '')).trim(),
                              'left': (created['quantity']?.toString() ?? '0'),
                              'color': const Color(0xFFF7EAD3),
                              'asset': 'assets/icons/${created['type'] ?? selectedType}.png',
                              'type': created['type'] ?? selectedType,
                            };
                            setState(() {
                              _items.add(med);
                            });
                          }
                          Navigator.of(ctx).pop();
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

  // (History removed) - history UI was intentionally removed per request

  Widget _buildSegmentContent() {
    switch (_selectedSegment) {
      case 0:
        return _buildSchedule();
      case 1:
        return _buildPile();
      default:
        return _buildSchedule();
    }
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
          child: Row(children: [seg('Schedule', 0), seg('Medicine', 1)]),
        ),
      ),
    );
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

                    /// Type of Medication 卡片（Schedule 时改为日历）
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

                    /// ✅ Status 卡片靠右，内部内容靠左
                    _buildSegmentContent(),

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
                          onPressed: () {
                            final bool isSchedule = _selectedSegment == 0;
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
