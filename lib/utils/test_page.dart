import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'dart:async';
import 'dart:math' as math;


const String getMedicationsByCaregiverQuery = r'''
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

const String upsertMedicationMutation = r'''
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

const String deleteMedicationMutation = r'''
mutation DeleteMedication($id: String!) {
  delete_medication_by_pk(id: $id)
}
''';

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  final TextEditingController _idCtrl = TextEditingController(text: 'CG-003');
  @override
  void initState() {
    super.initState();
    // Auto-run the medications query for the hardcoded caregiver id
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runMedQuery();
      _startMedSubscription(_idCtrl.text.trim());
    });

    // Resubscribe when caregiver id changes (debounced)
    _idCtrl.addListener(() {
      _idChangeTimer?.cancel();
      _idChangeTimer = Timer(const Duration(milliseconds: 400), () {
        final id = _idCtrl.text.trim();
        if (id.isEmpty) return;
        _runMedQuery();
        _startMedSubscription(id);
      });
    });

    // Start a safe polling fallback: query every 15 seconds while this page is active.
    // This ensures UI updates even when subscription messages are not delivered.
  }

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _medications = [];
  StreamSubscription<QueryResult>? _medSub;
  Timer? _idChangeTimer;

  // Broadcast stream controller to drive UI updates like a real-time stream
  final StreamController<List<Map<String, dynamic>>> _medStreamCtrl = StreamController<List<Map<String, dynamic>>>.broadcast();

  @override
  void dispose() {
    _idCtrl.dispose();
    _medSub?.cancel();
    _idChangeTimer?.cancel();
    _medStreamCtrl.close();
    super.dispose();
  }

  void _emitMedications() {
    try {
      _medStreamCtrl.add(List<Map<String, dynamic>>.from(_medications));
    } catch (e) {
      debugPrint('emitMedications error: $e');
    }
  }

  Future<void> _runMedQuery() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _medications = [];
    });

    final client = GraphQLProvider.of(context).value;
    final caregiverId = _idCtrl.text.trim();
    if (caregiverId.isEmpty) {
      setState(() {
        _error = 'Please enter a caregiver id to query.';
        _isLoading = false;
      });
      return;
    }

    try {
      final result = await client.query(
        QueryOptions(
          document: gql(getMedicationsByCaregiverQuery),
          variables: {'caregiverId': caregiverId},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (result.hasException) {
        setState(() {
          _error = result.exception.toString();
        });
        debugPrint('GraphQL medications exception: ${result.exception.toString()}');
        return;
      }

      final meds = (result.data?['medications_by_caregiver'] as List<dynamic>?) ?? [];
      setState(() {
        _medications = meds.map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>)).toList();
      });
      _emitMedications();
    } catch (e, st) {
      setState(() {
        _error = e.toString();
      });
      debugPrint('Med query threw error: $e');
      debugPrint(st.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startMedSubscription(String caregiverId, [int attempt = 0]) {
    if (caregiverId.isEmpty || !mounted) return;
    try {
      _medSub?.cancel();
      final client = GraphQLProvider.of(context).value;
      debugPrint('med sub: starting for caregiverId=$caregiverId attempt=$attempt');
      final stream = client.subscribe(SubscriptionOptions(document: gql(medicationUpdatedSub), variables: {'caregiverId': caregiverId}));
      _medSub = stream.listen((QueryResult result) {
        if (result.hasException) {
          debugPrint('med sub exception: ${result.exception}');
          return;
        }
        debugPrint('med sub raw payload: ${result.data}');

        final payload = result.data;
        debugPrint('med sub result.data keys: ${payload?.keys}');

        // Handle multiple server payload shapes. Prefer the envelope shape:
        // { medicationUpdated: { eventType, deletedId, medication: { ... } } }
        // but also accept older/alternative shapes like { eventType, deletedId }
        // or a bare object { id, name, ... } or minimal { id }.
        Map<String, dynamic>? data;
        String? eventType;
        String? deletedId;

        if (payload != null) {
          final top = Map<String, dynamic>.from(payload as Map);

          // Envelope form: medicationUpdated -> { eventType, deletedId, medication }
          if (top['medicationUpdated'] is Map) {
            final env = Map<String, dynamic>.from(top['medicationUpdated'] as Map);
            eventType = env['eventType']?.toString() ?? env['event']?.toString();
            deletedId = env['deletedId']?.toString() ?? env['deleted_id']?.toString();
            if (env['medication'] is Map) {
              data = Map<String, dynamic>.from(env['medication'] as Map);
            } else if (env['deletedId'] != null) {
              data = {'id': env['deletedId']};
            }
          } else {
            // Non-envelope: try to interpret top directly
            // Could be an envelope without wrapper, an event-like object, or the medication itself
            if (top.containsKey('eventType') || top.containsKey('deletedId') || top.containsKey('deleted_id')) {
              eventType = top['eventType']?.toString() ?? top['event']?.toString();
              deletedId = top['deletedId']?.toString() ?? top['deleted_id']?.toString();
              // if medication sub-object present
              if (top['medication'] is Map) data = Map<String, dynamic>.from(top['medication'] as Map);
              else if (top.containsKey('id')) data = top;
            } else if (top.containsKey('id')) {
              // assume this is the medication object itself
              data = top;
            }
          }
        }

        if (data == null) {
          debugPrint('med sub: unhandled payload shape, ignoring. payload=$payload');
          return;
        }

        final id = (data['id'] ?? data['deletedId'] ?? data['deleted_id'])?.toString();
        if (id == null || id.isEmpty) {
          debugPrint('med sub: payload missing id/deletedId, payload=$payload');
          return;
        }
        final d = data; // non-null alias for analyzer

        // Determine deletion state
        bool isDeleted = false;

        if (eventType != null && eventType.toString().toUpperCase().contains('DELET')) {
          isDeleted = true;
          if (deletedId == null) deletedId = id;
        }

        // Fallback heuristics
        if (!isDeleted) {
          if (d['deleted'] == true) isDeleted = true;
          if ((d['status'] as String?)?.toLowerCase() == 'deleted') isDeleted = true;
          if ((d.keys.length == 1) && d.containsKey('id')) {
            // server sent only id -> treat as delete
            isDeleted = true;
            deletedId = id;
          }
        }

        setState(() {
          if (isDeleted) {
            final remId = deletedId ?? id;
            _medications.removeWhere((e) => e['id']?.toString() == remId);
          } else {
              final med = {
                'id': id,
                'name': d['name'] ?? '',
                'dosageAmount': d['dosageAmount'],
                'dosageUnit': d['dosageUnit'],
                'quantity': d['quantity'],
                'type': d['type'],
                'status': d['status'],
              };
            final idx = _medications.indexWhere((e) => e['id']?.toString() == id);
            if (idx >= 0) {
              _medications[idx] = med;
            } else {
              _medications.insert(0, med);
            }
          }
        });
        _emitMedications();

        if (isDeleted && mounted) {
          final disp = (data['name'] ?? id).toString();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Medication deleted: $disp'), duration: const Duration(seconds: 2)));
          });
        }
      }, onError: (e) {
        debugPrint('med subscription error: $e');
        if (!mounted) return;
        final next = attempt + 1;
        final seconds = math.min(60, math.pow(2, next).toInt());
        debugPrint('med sub: scheduling retry #$next in ${seconds}s');
        Future.delayed(Duration(seconds: seconds), () {
          if (mounted) _startMedSubscription(caregiverId, next);
        });
      }, onDone: () {
        debugPrint('med subscription done (onDone called)');
        if (!mounted) return;
        final next = attempt + 1;
        final seconds = math.min(60, math.pow(2, next).toInt());
        debugPrint('med sub: onDone scheduling retry #$next in ${seconds}s');
        Future.delayed(Duration(seconds: seconds), () {
          if (mounted) _startMedSubscription(caregiverId, next);
        });
      });
    } catch (e, st) {
      debugPrint('startMedSubscription failed: $e\n$st');
    }
  }

  Future<Map<String, dynamic>?> _upsertMedication(Map<String, dynamic> input) async {
    try {
      final client = GraphQLProvider.of(context).value;
      final isCreate = input['id'] == null || input['id'].toString().isEmpty;
      String? tempId;
      Map<String, dynamic>? previous;
      if (isCreate) {
        tempId = 'tmp-${DateTime.now().millisecondsSinceEpoch}';
        final optimistic = {
          'id': tempId,
          'name': input['name'] ?? '',
          'dosageAmount': input['dosageAmount'],
          'dosageUnit': input['dosageUnit'],
          'quantity': input['quantity'],
          'type': input['type'],
          'status': input['status'] ?? 'active',
        };
        setState(() => _medications.insert(0, optimistic));
        _emitMedications();
      } else {
        final idx = _medications.indexWhere((e) => e['id']?.toString() == input['id']?.toString());
        if (idx >= 0) {
          previous = Map<String, dynamic>.from(_medications[idx]);
          final optimistic = {
            'id': input['id'],
            'name': input['name'] ?? previous['name'],
            'dosageAmount': input['dosageAmount'] ?? previous['dosageAmount'],
            'dosageUnit': input['dosageUnit'] ?? previous['dosageUnit'],
            'quantity': input['quantity'] ?? previous['quantity'],
            'type': input['type'] ?? previous['type'],
            'status': input['status'] ?? previous['status'],
          };
          setState(() => _medications[idx] = optimistic);
          _emitMedications();
        }
      }

      final res = await client.mutate(MutationOptions(document: gql(upsertMedicationMutation), variables: {'object': input}));
      if (res.hasException) {
        debugPrint('upsert medication error: ${res.exception}');
        setState(() {
          if (isCreate && tempId != null) _medications.removeWhere((e) => e['id'] == tempId);
          if (!isCreate && previous != null) {
            final idx = _medications.indexWhere((e) => e['id']?.toString() == previous!['id']?.toString());
            if (idx >= 0) _medications[idx] = previous;
          }
        });
        _emitMedications();
        return null;
      }

      final data = res.data?['insert_medication_one'] as Map<String, dynamic>?;
      if (data == null) return null;
      setState(() {
        final mapped = {
          'id': data['id'],
          'name': data['name'],
          'dosageAmount': data['dosageAmount'],
          'dosageUnit': data['dosageUnit'],
          'quantity': data['quantity'],
          'type': data['type'],
          'status': data['status'],
        };
        final tidx = tempId == null ? -1 : _medications.indexWhere((e) => e['id'] == tempId);
        if (tidx >= 0) _medications[tidx] = mapped;
        else {
          final idx = _medications.indexWhere((e) => e['id']?.toString() == mapped['id']?.toString());
          if (idx >= 0) _medications[idx] = mapped;
          else _medications.insert(0, mapped);
        }
      });
      _emitMedications();
      return data;
    } catch (e, st) {
      debugPrint('upsert exception: $e\n$st');
      return null;
    }
  }

  Future<bool> _deleteMedicationById(String id) async {
    if (id.isEmpty) return false;
    final client = GraphQLProvider.of(context).value;
    try {
      final res = await client.mutate(MutationOptions(document: gql(deleteMedicationMutation), variables: {'id': id}));
      if (res.hasException) {
        debugPrint('delete error: ${res.exception}');
        return false;
      }

      debugPrint('delete result.data: ${res.data}');

      final deleted = res.data?['delete_medication_by_pk'];
      if (deleted == null || deleted == false) {
        debugPrint('delete reported false/null from server for id=$id');
        return false;
      }

      // Remove from local list if still present
      setState(() => _medications.removeWhere((e) => e['id']?.toString() == id));
      _emitMedications();

      // Refetch authoritative list to ensure client and server are in sync
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _runMedQuery();
      });

      return true;
    } catch (e, st) {
      debugPrint('delete exception: $e\n$st');
      return false;
    }
  }

  Future<void> _showEditMedSheet(Map<String, dynamic> m) async {
    final nameCtrl = TextEditingController(text: m['name']?.toString() ?? '');
    final dosageAmountCtrl = TextEditingController(text: m['dosageAmount']?.toString() ?? '');
    final dosageUnitCtrl = TextEditingController(text: m['dosageUnit']?.toString() ?? '');
    final qtyCtrl = TextEditingController(text: m['quantity']?.toString() ?? '');
    final typeCtrl = TextEditingController(text: m['type']?.toString() ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                Row(children: [
                  Expanded(child: TextField(controller: dosageAmountCtrl, decoration: const InputDecoration(labelText: 'Dosage Amount'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: dosageUnitCtrl, decoration: const InputDecoration(labelText: 'Dosage Unit'))),
                ]),
                TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number),
                TextField(controller: typeCtrl, decoration: const InputDecoration(labelText: 'Type')),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () async {
                    final input = {
                      'id': m['id'],
                      'name': nameCtrl.text.trim(),
                      'dosageAmount': double.tryParse(dosageAmountCtrl.text.trim()),
                      'dosageUnit': dosageUnitCtrl.text.trim(),
                      'quantity': int.tryParse(qtyCtrl.text.trim()) ?? 0,
                      'type': typeCtrl.text.trim(),
                      'status': m['status'] ?? 'active',
                    };
                    await _upsertMedication(input);
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Save'),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _medicationCard(Map<String, dynamic> m) {
    final name = (m['name'] as String?) ?? 'No name';
    final dosageAmount = (m['dosageAmount']?.toString() ?? '');
    final dosageUnit = (m['dosageUnit'] ?? '');
    final dose = (('$dosageAmount$dosageUnit')).trim();
    final qty = (m['quantity']?.toString() ?? '');
    final type = (m['type'] as String?) ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: const Color(0xFFF7EAD3),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.medical_services, size: 20, color: Colors.black54),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  if (dose.isNotEmpty) Text('Dose: $dose', style: const TextStyle(fontSize: 13)),
                  if (qty.isNotEmpty) Text('$qty Left', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(type, style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    Text((m['status'] as String?) ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') {
                      await _showEditMedSheet(m);
                    } else if (v == 'delete') {
                      final should = await showDialog<bool>(
                        context: context,
                        builder: (dctx) => AlertDialog(
                          title: const Text('Delete medication'),
                          content: Text('Delete "${m['name'] ?? ''}"?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.of(dctx).pop(true), child: const Text('Delete')),
                          ],
                        ),
                      );
                      if (should == true) {
                        final id = (m['id']?.toString() ?? '');
                        // optimistic remove
                        final backup = Map<String, dynamic>.from(m);
                        setState(() => _medications.removeWhere((e) => e['id']?.toString() == id));
                        _emitMedications();
                        final ok = await _deleteMedicationById(id);
                        if (!ok) {
                          // rollback
                          setState(() => _medications.insert(0, backup));
                          _emitMedications();
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete')));
                        }
                      }
                    }
                  },
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medications (test)')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _idCtrl,
                decoration: const InputDecoration(labelText: 'Caregiver ID', hintText: 'Enter caregiver id'),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _runMedQuery,
                    child: _isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Show Medications'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              if (_error != null) Expanded(child: SingleChildScrollView(child: Text('Error:\n\n$_error', style: const TextStyle(color: Colors.red)))),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _medStreamCtrl.stream,
                  initialData: _medications,
                  builder: (context, snap) {
                    final meds = snap.data ?? [];
                    if (meds.isEmpty && _error == null) {
                      return const Padding(padding: EdgeInsets.only(top: 8.0), child: Text('No medications loaded (run a query)'));
                    }
                    if (_error != null) {
                      return SingleChildScrollView(child: Text('Error:\n\n$_error', style: const TextStyle(color: Colors.red)));
                    }
                    return ListView.separated(
                      itemCount: meds.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        final m = meds[i];
                        return _medicationCard(m);
                      },
                    );
                  },
                ),
              ),
            ]
          ),
        ),
      ),
    );
  }
}