import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SecondaryCaregiverSheet extends StatefulWidget {
  final Map<String, String>? initialData;
  final List<Map<String, String>> items;
  final void Function(Map<String, String> savedEntry) onSaved;
  final VoidCallback? onDeleted;

  const SecondaryCaregiverSheet({
    super.key,
    this.initialData,
    required this.items,
    required this.onSaved,
    this.onDeleted,
  });

  @override
  State<SecondaryCaregiverSheet> createState() =>
      _SecondaryCaregiverSheetState();
}

class _SecondaryCaregiverSheetState extends State<SecondaryCaregiverSheet> {
  // ================= Controllers =================
  final sheetNameCtrl = TextEditingController();
  final sheetRelCtrl = TextEditingController();
  final sheetPhoneNumberCtrl = TextEditingController();
  final sheetEmailCtrl = TextEditingController();
  final sheetPermCtrl = TextEditingController();
  final sheetCareRecipientCtrl = TextEditingController();
  final sheetStatusCtrl = TextEditingController();

  final ValueNotifier<Set<String>> _selectedRecipients =
      ValueNotifier(<String>{});

  bool _initialized = false;

  // ================= Init Once =================
  void _initOnce() {
    if (_initialized) return;

    final data = widget.initialData;
    if (data != null) {
      sheetNameCtrl.text = data['name'] ?? '';
      sheetRelCtrl.text = data['relationship'] ?? '';
      sheetPhoneNumberCtrl.text = data['contact'] ?? '';
      sheetEmailCtrl.text = data['email'] ?? '';
      sheetPermCtrl.text = data['permission'] ?? '';
      sheetCareRecipientCtrl.text = data['careRecipientId'] ?? '';
      sheetStatusCtrl.text = data['status'] ?? '';

      _selectedRecipients.value = (data['careRecipientId'] ?? '')
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
    }

    _initialized = true;
  }

  @override
  void dispose() {
    sheetNameCtrl.dispose();
    sheetRelCtrl.dispose();
    sheetPhoneNumberCtrl.dispose();
    sheetEmailCtrl.dispose();
    sheetPermCtrl.dispose();
    sheetCareRecipientCtrl.dispose();
    sheetStatusCtrl.dispose();
    _selectedRecipients.dispose();
    super.dispose();
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    _initOnce();

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16.w,
          right: 16.w,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.initialData == null
                  ? 'Add Secondary Caregiver'
                  : 'Edit Secondary Caregiver',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12.h),

            _textField(sheetNameCtrl, 'Name'),
            _textField(sheetPhoneNumberCtrl, 'Phone Number'),
            _textField(sheetEmailCtrl, 'Email'),

            _dropdown(
              label: 'Relationship',
              controller: sheetRelCtrl,
              items: const [
                'Sister',
                'Brother',
                'Daughter',
                'Son',
                'Parent',
                'Spouse',
                'Friend',
                'Other',
              ],
            ),

            _dropdown(
              label: 'Permission Level',
              controller: sheetPermCtrl,
              items: const ['Full', 'Alert Only', 'View'],
            ),

            SizedBox(height: 12.h),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Assign Care Recipient',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500),
              ),
            ),
            SizedBox(height: 8.h),

            ValueListenableBuilder<Set<String>>(
              valueListenable: _selectedRecipients,
              builder: (_, selected, __) {
                return Wrap(
                  spacing: 8,
                  children: widget.items.map((m) {
                    final id = m['id'] ?? '';
                    final name = m['name'] ?? id;
                    final isSelected = selected.contains(id);

                    return ChoiceChip(
                      label: Text(name),
                      selected: isSelected,
                      selectedColor: const Color(0xFFFFECB3),
                      onSelected: (sel) {
                        final newSet = Set<String>.from(selected);
                        sel ? newSet.add(id) : newSet.remove(id);
                        _selectedRecipients.value = newSet;
                        sheetCareRecipientCtrl.text = newSet.join(',');
                        sheetStatusCtrl.text = widget.items
                            .where((x) => newSet.contains(x['id']))
                            .map((x) => x['name'])
                            .whereType<String>()
                            .join(', ');
                      },
                    );
                  }).toList(),
                );
              },
            ),

            SizedBox(height: 16.h),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.initialData != null && widget.onDeleted != null)
                  OutlinedButton(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete caregiver'),
                          content: const Text(
                            'Are you sure you want to delete this caregiver?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        widget.onDeleted?.call();
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Delete'),
                  ),
                ElevatedButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ],
            ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }

  // ================= Save =================
  void _save() {
    if (sheetNameCtrl.text.trim().isEmpty ||
        sheetRelCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name & relationship required')),
      );
      return;
    }

    final entry = {
      'id': widget.initialData?['id'] ??
          'local-${DateTime.now().millisecondsSinceEpoch}',
      'name': sheetNameCtrl.text.trim(),
      'relationship': sheetRelCtrl.text.trim(),
      'contact': sheetPhoneNumberCtrl.text.trim(),
      'email': sheetEmailCtrl.text.trim(),
      'permission': sheetPermCtrl.text.trim(),
      'careRecipientId': sheetCareRecipientCtrl.text.trim(),
      'status': sheetStatusCtrl.text.trim(),
    };

    widget.onSaved(entry);
    Navigator.pop(context);
  }

  // ================= Widgets =================
  Widget _textField(TextEditingController ctrl, String label) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required TextEditingController controller,
    required List<String> items,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: DropdownButtonFormField<String>(
        value: items.contains(controller.text) ? controller.text : null,
        decoration: InputDecoration(labelText: label),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (v) => controller.text = v ?? '',
      ),
    );
  }
}
