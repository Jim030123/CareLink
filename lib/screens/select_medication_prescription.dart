import 'package:carelink_mobile/components/medication_type.dart';
import 'package:carelink_mobile/components/page_appbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:carelink_mobile/controllers/medication_controller.dart';
import 'package:carelink_mobile/utils/search_utils.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:carelink_mobile/components/medication_info_chip.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:carelink_mobile/components/text_field.dart';
import 'package:flutter/foundation.dart';

class SelectMedicationPrescription extends StatefulWidget {
  final MedicationType? initial;
  const SelectMedicationPrescription({super.key, this.initial});

  @override
  State<SelectMedicationPrescription> createState() =>
      _SelectMedicationPrescriptionState();
}

class MedicationModal extends StatefulWidget {
  final Map<String, dynamic> item;
  final int globalIndex;

  const MedicationModal({
    required this.item,
    required this.globalIndex,
    super.key,
  });

  @override
  State<MedicationModal> createState() => _MedicationModalState();
}

class _MedicationModalState extends State<MedicationModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _dosageCtrl;
  late final TextEditingController _frequencyNoteCtrl;
  late final TextEditingController _startCtrl;
  late final TextEditingController _endCtrl;
  final List<TimeOfDay> _takeTime = [];

  @override
  void initState() {
    super.initState();
    _dosageCtrl = TextEditingController();
    _frequencyNoteCtrl = TextEditingController();
    _startCtrl = TextEditingController();
    _endCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _dosageCtrl.dispose();
    _frequencyNoteCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  String _formatTimeOfDay(TimeOfDay t) => t.format(context);

  Future<void> _pickDate(TextEditingController ctrl, bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      ctrl.text = picked.toIso8601String().split('T').first;
      setState(() {});
    }
  }

  Future<void> _pickTime() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: now,
    );
    if (picked != null) {
      final exists = _takeTime.any((t) => t.format(context) == picked.format(context));
      if (!exists) setState(() => _takeTime.add(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final name = it['name'] as String? ?? '';
    final asset = (it['asset'] as String?) ?? '';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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

              // Header card
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFF4EE), Color(0xFFFFE0CC)],
                        ),
                        border: Border.all(color: Colors.orange.withOpacity(0.25), width: 2),
                        boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.25), blurRadius: 14)],
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(14.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(8.w),
                                    decoration: const BoxDecoration(shape: BoxShape.circle),
                                    child: Builder(builder: (_) {
                                      if (asset.startsWith('http')) {
                                        return Image.network(asset, width: 32.w, height: 32.w, fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) => Image.asset('assets/icons/capsule.png', width: 32.w, height: 32.w));
                                      }
                                      return Image.asset(asset.isNotEmpty ? asset : 'assets/icons/capsule.png', width: 32.w, height: 32.w, fit: BoxFit.contain);
                                    }),
                                  ),
                                  SizedBox(height: 6.h),
                                  Text(name, textAlign: TextAlign.center, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700)),
                                  SizedBox(height: 2.h),
                                  Text('Brand: ${it['brand'] ?? '-'}', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.sp, color: Colors.black54)),
                                  SizedBox(height: 2.h),
                                  Text('SKU: ${it['sku'] ?? '-'}', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.sp, color: Colors.black54)),
                                ],
                              ),
                            ),
                            SizedBox(height: 12.h),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 12.h),

              // Form
              Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FormTextField(
                      controller: _dosageCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      label: 'Dosage Amount (${it['standardUnit'] ?? '-'})',
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Please enter dosage';
                        if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(v.trim())) return 'Dosage must be a numeric value';
                        return null;
                      },
                    ),
                    SizedBox(height: 8.h),

                    Row(
                      children: [
                        Expanded(child: Text('Times', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600))),
                        ElevatedButton.icon(onPressed: _pickTime, icon: const Icon(Icons.add), label: const Text('Add Time')),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    if (_takeTime.isEmpty) Padding(padding: EdgeInsets.symmetric(vertical: 8.h), child: const Text('No times selected', style: TextStyle(color: Colors.black54))),
                    Wrap(spacing: 8.w, children: _takeTime.asMap().entries.map((e) {
                      final idx = e.key; final t = e.value;
                      return InputChip(label: Text(_formatTimeOfDay(t)), onDeleted: () => setState(() => _takeTime.removeAt(idx)));
                    }).toList()),

                    SizedBox(height: 12.h),
                    FormTextField(controller: _startCtrl, label: 'Start Date', readOnly: true, onTap: () => _pickDate(_startCtrl, true)),
                    SizedBox(height: 8.h),
                    FormTextField(controller: _endCtrl, label: 'End Date', readOnly: true, onTap: () => _pickDate(_endCtrl, false)),
                    SizedBox(height: 8.h),
                    FormTextField(controller: _frequencyNoteCtrl, label: 'Frequency Note'),
                    SizedBox(height: 12.h),

                    Row(children: [
                      Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))),
                      SizedBox(width: 8.w),
                      Expanded(child: ElevatedButton(onPressed: _onSave, child: const Text('Save'))),
                    ]),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
            ],
          ),
        ),
      ),
    );
  }

  void _onSave() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_takeTime.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one time')));
      return;
    }

    if (_startCtrl.text.isNotEmpty && _endCtrl.text.isNotEmpty) {
      final sd = DateTime.tryParse(_startCtrl.text);
      final ed = DateTime.tryParse(_endCtrl.text);
      if (sd != null && ed != null && sd.isAfter(ed)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Start date must be before end date')));
        return;
      }
    }

    final result = {
      'medication': widget.item,
      'medicationId': widget.item['id']?.toString(),
      'dosageAmount': _dosageCtrl.text.trim(),
      'unit': widget.item['standardUnit'],
      'takeTime': _takeTime.map((t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}').toList(),
      'startDate': _startCtrl.text.trim(),
      'endDate': _endCtrl.text.trim(),
      'frequencyNote': _frequencyNoteCtrl.text.trim(),
      'localIndex': widget.globalIndex,
    };

    Navigator.of(context).pop(result);
  }
}

class _SelectMedicationPrescriptionState
    extends State<SelectMedicationPrescription> {
  late MedicationType _selected;
  late List<Map<String, dynamic>> _items;
  late List<Map<String, dynamic>> _prescriptions;
  late TextEditingController _searchCtrl;
  bool _searching = false;
  final MedicationController _controller = MedicationController();
  // MedicationSchedule removed — this page shows medicine list only
  final MedicationHandBookController _smController =
      MedicationHandBookController();

  @override
  void initState() {
    super.initState();
    _selected = widget.initial ?? MedicationType.capsule;
    _items = <Map<String, dynamic>>[];
    _prescriptions = <Map<String, dynamic>>[];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchMedications();
    });
    _searchCtrl = TextEditingController();

    _searchCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
      return mapped;
    } catch (e, st) {
      debugPrint('fetchMedications failed: $e\n$st');
      return <Map<String, dynamic>>[];
    }
  }

  Widget _buildPile([List<Map<String, dynamic>>? items]) {
    final source = items ?? _items;
    final selectedKey = _selected.toString().split('.').last;

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

    Widget buildCard(Map<String, dynamic> it) {
      final asset = (it['asset'] as String?) ?? '';
      final bg = (it['color'] as Color?) ?? const Color(0xFFF7EAD3);
      final borderColor = Colors.orange.shade100;
      final gradientColors = const [Color(0xFFFFF4EE), Color(0xFFFFE0CC)];

      return Padding(
        padding: EdgeInsets.only(bottom: 12.h),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final globalIndex = _items.indexWhere(
                (e) => e['id']?.toString() == it['id']?.toString(),
              );

              final created = await showModalBottomSheet<Map<String, dynamic>?>(
                useSafeArea: true,
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (ctx) => MedicationModal(
                  item: it,
                  globalIndex: globalIndex,
                ),
              );

              if (created != null) {
                // Store into local prescriptions list and return to caller
                if (mounted) {
                  setState(() => _prescriptions.add(created));
                }
                Navigator.of(context).pop(created);
              }
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
        ...filtered.map((it) => buildCard(it)),
      ],
    );
  }

  // Adapter wrapper for the project's shared `infoChip` component.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageAppBar(
        title: 'Add Medicine Prescription',
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

                    // Medication list (selectable) — mirrors Medication Handbook
                    _buildPile(),
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
