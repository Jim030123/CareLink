import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

class CareRecipientForm extends StatefulWidget {
  const CareRecipientForm({
    super.key,
    required this.controllers,
    required this.formKey,
    required this.index,
    required this.count,
    this.onPrevious,
    this.onNextOrSave,
  });

  final Map<String, TextEditingController> controllers;
  final GlobalKey<FormState> formKey;
  final int index;
  final int count;
  final VoidCallback? onPrevious;
  final VoidCallback? onNextOrSave;

  @override
  State<CareRecipientForm> createState() => _CareRecipientFormState();
}

class _CareRecipientFormState extends State<CareRecipientForm> {
  // `selectedUid` is a unique value used as Dropdown's value to avoid
  // Flutter's assertion when multiple items share the same server `id`.
  // The parent's controller `widget.controllers['type']` stores the original
  // server `id` (possibly duplicated). We map between `uid` and `id` below.
  String? selectedUid;
  String? selectedGender;
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? error;

  // Cache fetched types globally so we only load them once per app run.
  // Each entry includes: {'uid': unique internal uid, 'id': server id, 'label': label}
  static List<Map<String, dynamic>>? _cachedItems;

  final String fetchQuery = r'''
    query {
      care_recipient_type {
        id
        careRecipientType
      }
    }
  ''';

  @override
  void initState() {
    super.initState();
  }

  bool _fetched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_fetched) {
      _fetched = true;
      if (_cachedItems != null) {
        // use cached items instead of refetching
        setState(() {
          items = _cachedItems!;
          loading = false;
        });

        // restore selection from parent controller if present
        final parentId = widget.controllers['type']?.text;
        if (parentId != null && parentId.isNotEmpty) {
          final match = items.firstWhere(
            (it) => (it['id'] as String?) == parentId,
            orElse: () => {},
          );
          if (match.isNotEmpty) {
            selectedUid = match['uid'] as String?;
          }
        }
      } else {
        _fetchTypes();
      }
    }

    // selection (type) will be restored after fetch in _fetchTypes();
    if (selectedGender == null) {
      final g = widget.controllers['gender']?.text;
      if (g != null && g.isNotEmpty) selectedGender = g;
    }
  }

  Future<void> _fetchTypes() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final client = GraphQLProvider.of(context).value;
      final result = await client.query(
        QueryOptions(
          document: gql(fetchQuery),
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (result.hasException) {
        setState(() {
          error = result.exception.toString();
          loading = false;
        });
        return;
      }

      final raw = result.data?['care_recipient_type'] as List<dynamic>?;
      final list =
          raw
              ?.map(
                (e) => {
                  'id': e['id']?.toString(),
                  'label': e['careRecipientType']?.toString() ?? '',
                },
              )
              .toList() ??
          <Map<String, dynamic>>[];

      // Create a unique uid for each entry (keep duplicates) so each
      // DropdownMenuItem has a unique value while keeping the original
      // server id available.
      final List<Map<String, dynamic>> withUid = [];
      for (var i = 0; i < list.length; i++) {
        final it = list[i];
        final id = it['id'] as String?;
        final label = it['label'] as String? ?? '';
        final uid = '${id ?? 'null'}##$i';
        withUid.add({'uid': uid, 'id': id, 'label': label});
      }

      setState(() {
        items = withUid;
        loading = false;
      });

      // cache the items so other instances reuse them
      _cachedItems = withUid;

      // If parent already has a selected id in controllers, find the
      // first matching uid and restore selectedUid so Dropdown shows it.
      final parentId = widget.controllers['type']?.text;
      if (parentId != null && parentId.isNotEmpty) {
        final match = items.firstWhere(
          (it) => (it['id'] as String?) == parentId,
          orElse: () => {},
        );
        if (match.isNotEmpty) {
          setState(() {
            selectedUid = match['uid'] as String?;
          });
        }
      }
      debugPrint(
        'Fetched care recipient types: ${items.map((e) => e['label']).toList()}',
      );
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
      debugPrint('Failed to fetch care recipient types: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.w),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      padding: EdgeInsets.all(16.w),
      width: double.infinity,
      child: Form(
        key: widget.formKey,
        child: Column(
          children: [
            Text(
              'Recipient ${widget.index + 1}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.h),
            TextFormField(
              controller: widget.controllers['first'],
              decoration: const InputDecoration(labelText: 'First Name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter first name' : null,
            ),
            SizedBox(height: 8.h),
            TextFormField(
              controller: widget.controllers['last'],
              decoration: const InputDecoration(labelText: 'Last Name'),
            ),
            SizedBox(height: 8.h),

            // DOB using date selector
            TextFormField(
              controller: widget.controllers['dob'],
              decoration: const InputDecoration(
                labelText: 'Date of Birth',
                suffixIcon: Icon(Icons.calendar_today),
              ),
              readOnly: true, // 不让键盘输入，只能点选
              onTap: () async {
                FocusScope.of(context).requestFocus(FocusNode()); // 防止键盘弹出

                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime(2000), // 默认打开的日期
                  firstDate: DateTime(1900), // 最早可以选1900年
                  lastDate: DateTime.now(), // 生日不能超过今天
                );

                if (picked != null) {
                  // 统一成 PostgreSQL 推荐格式 YYYY-MM-DD
                  final formatted =
                      "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";

                  setState(() {
                    widget.controllers['dob']?.text = formatted;
                  });
                }
              },
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Please select date of birth';
                }
                return null;
              },
            ),

            SizedBox(height: 8.h),

            TextFormField(
              controller: widget.controllers['email'],
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter email';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            SizedBox(height: 8.h),
            TextFormField(
              controller: widget.controllers['phone'],
              decoration: const InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 8.h),
            // Dropdown for gender (persisted into widget.controllers['gender'])
            DropdownButtonFormField<String?>(
              value: selectedGender,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'female', child: Text('Female')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              hint: const Text('Select gender'),
              onChanged: (value) {
                setState(() {
                  selectedGender = value;
                });
                try {
                  widget.controllers['gender']?.text = value ?? '';
                } catch (_) {}
                debugPrint(
                  'Selected gender: $value (recipient ${widget.index})',
                );
              },
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please select gender';
                return null;
              },
              decoration: const InputDecoration(labelText: 'Gender'),
            ),
            SizedBox(height: 8.h),

            DropdownButtonFormField<String?>(
              // Dropdown uses `selectedUid` (unique per menu item) to avoid
              // assertion when multiple items share the same server id.
              value: selectedUid,
              isExpanded: true,
              menuMaxHeight: 300,
              items: loading
                  ? [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Loading...'),
                      ),
                    ]
                  : error != null
                  ? [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Error', overflow: TextOverflow.ellipsis),
                      ),
                    ]
                  : items
                        .map(
                          (it) => DropdownMenuItem<String?>(
                            value: it['uid'] as String?,
                            child: Text(
                              /*  */
                              it['label'] as String? ?? '',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        )
                        .toList(),
              onChanged: (value) {
                setState(() {
                  selectedUid = value;
                });
                // map uid back to server id and write into parent's controller
                try {
                  final match = items.firstWhere(
                    (it) => it['uid'] == value,
                    orElse: () => {},
                  );
                  final id = (match.isNotEmpty) ? match['id'] as String? : null;
                  widget.controllers['type']?.text = id ?? '';
                } catch (e) {
                  widget.controllers['type']?.text = '';
                }
                debugPrint('Selected care recipient type (uid): $value');
              },
              hint: const Text('Select type'),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Please select care recipient type';
                }
                return null;
              },
              decoration: const InputDecoration(
                labelText: 'Care Recipient Type',
              ),
            ),

            SizedBox(height: 12.h),
            Row(
              children: [
                if (widget.index > 0)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: widget.onPrevious,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                      ),
                      child: const Text('Previous'),
                    ),
                  ),
                if (widget.index > 0) SizedBox(width: 8.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final valid =
                          widget.formKey.currentState?.validate() ?? false;
                      if (!valid) return;

                      // Ensure selectedUid/selectedGender are written back into
                      // the parent's controllers before saving.
                      try {
                        if ((widget.controllers['type']?.text ?? '').isEmpty &&
                            selectedUid != null) {
                          final match = items.firstWhere(
                            (it) => it['uid'] == selectedUid,
                            orElse: () => {},
                          );
                          if (match.isNotEmpty) {
                            widget.controllers['type']?.text =
                                match['id'] as String? ?? '';
                          }
                        }
                        if ((widget.controllers['gender']?.text ?? '')
                                .isEmpty &&
                            selectedGender != null) {
                          widget.controllers['gender']?.text =
                              selectedGender ?? '';
                        }

                        final current = {
                          'first':
                              widget.controllers['first']?.text.trim() ?? '',
                          'last': widget.controllers['last']?.text.trim() ?? '',
                          'email':
                              widget.controllers['email']?.text.trim() ?? '',
                          'phone':
                              widget.controllers['phone']?.text.trim() ?? '',
                          'type': widget.controllers['type']?.text.trim() ?? '',
                          'gender':
                              widget.controllers['gender']?.text.trim() ?? '',
                        };
                        debugPrint(
                          'Saving recipient (index ${widget.index}): $current',
                        );
                      } catch (e) {
                        debugPrint('Failed to print recipient debug: $e');
                      }

                      widget.onNextOrSave?.call();
                    },
                    child: Text(
                      widget.index < widget.count - 1 ? 'Next' : 'Save',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
