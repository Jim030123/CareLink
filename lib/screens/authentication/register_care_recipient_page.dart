import 'package:carelink_mobile/components/numbering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import '../../components/care_recipient_form.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:carelink_mobile/utils/graphql_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:carelink_mobile/utils/caregiver_provider.dart';
import 'package:carelink_mobile/utils/loading_dialog.dart';
import 'dart:math';

class RegisterCareRecipientPage extends ConsumerStatefulWidget {
  final int count;
  final String? caregiverId;

  const RegisterCareRecipientPage({
    super.key,
    required this.count,
    this.caregiverId,
  });

  @override
  ConsumerState<RegisterCareRecipientPage> createState() =>
      _RegisterCareRecipientPageState();
}

class _RegisterCareRecipientPageState
    extends ConsumerState<RegisterCareRecipientPage> {
  late int _count;
  int _activeIndex = 0;

  final List<Map<String, TextEditingController>> _controllers = [];
  final List<GlobalKey<FormState>> _formKeys = [];

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _count = widget.count.clamp(1, 99);
    for (var i = 0; i < _count; i++) {
      _controllers.add({
        'first': TextEditingController(),
        'last': TextEditingController(),
        'email': TextEditingController(),
        'phone': TextEditingController(),
        'dob': TextEditingController(),
        'gender': TextEditingController(),
        'type': TextEditingController(),
      });
      _formKeys.add(GlobalKey<FormState>());
    }
  }

  @override
  void dispose() {
    for (final map in _controllers) {
      for (final c in map.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  String _generatePassword([int length = 10]) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%&*';
    final rnd = Random.secure();
    return List.generate(
      length,
      (_) => chars[rnd.nextInt(chars.length)],
    ).join();
  }

  /// 安全弹 SnackBar：内部自己检查 mounted
  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _onWillPop() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm'),
        content: const Text(
          'Going back will clear all entered data. Do you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    return result == true;
  }

  Widget _buildCounterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_count, (i) {
          final active = i == _activeIndex;
          return GestureDetector(
            onTap: () => setState(() => _activeIndex = i),
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 6.w),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: active ? const Color(0xFFF4CBA1) : Colors.white,
                borderRadius: BorderRadius.circular(12.w),
                border: Border.all(color: Colors.black12),
              ),
              child: Text(
                'Recipient ${i + 1}',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  color: Colors.black87,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color card = Colors.white;
    final Color accent = const Color(0xFFF4CBA1);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            return SafeArea(
              child: SingleChildScrollView(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 8.h,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 顶部卡片
                        Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16.w),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  SvgPicture.asset(
                                    'assets/icons/logo.svg',
                                    width: 60.w,
                                    height: 60.h,
                                  ),
                                  Expanded(
                                    child: Center(
                                      child: Container(
                                        margin: EdgeInsets.only(right: 60.w),
                                        child: Text(
                                          'Register',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 25.sp,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16.h),
                              Row(
                                children: [
                                  Align(
                                    alignment: Alignment.topCenter,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16.w,
                                        vertical: 8.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF4CBA1),
                                        borderRadius: BorderRadius.circular(
                                          16.w,
                                        ),
                                      ),
                                      child: Text(
                                        '4',
                                        style: TextStyle(fontSize: 24.sp),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: Container(
                                      alignment: Alignment.topLeft,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16.w,
                                        vertical: 8.h,
                                      ),
                                      child: Text(
                                        'Care Recipient Detail',
                                        textAlign: TextAlign.center,
                                        softWrap: true,
                                        style: TextStyle(
                                          fontSize: 24.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16.h),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  width: constraints.maxWidth,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16.w,
                                    vertical: 8.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF8F0),
                                    borderRadius: BorderRadius.circular(16.w),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.lightbulb_outline,
                                        size: 24.sp,
                                        color: Colors.orange,
                                      ),
                                      SizedBox(width: 8.w),
                                      Flexible(
                                        child: Text(
                                          'Please fill in the details for each care recipient.',
                                          textAlign: TextAlign.justify,
                                          softWrap: true,
                                          style: TextStyle(fontSize: 15.sp),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 16.h),

                        // counter + form
                        Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: card,
                            borderRadius: BorderRadius.circular(16.w),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // left arrow
                              IconButton(
                                onPressed: _activeIndex > 0
                                    ? () => setState(
                                        () => _activeIndex = _activeIndex - 1,
                                      )
                                    : null,
                                icon: Icon(Icons.chevron_left, size: 28.sp),
                                color: accent,
                                disabledColor: Colors.black12,
                                tooltip: 'Previous recipient',
                              ),

                              // main content
                              Expanded(
                                child: Column(
                                  children: [
                                    _buildCounterRow(),
                                    SizedBox(height: 16.h),
                                    CareRecipientForm(
                                      key: ValueKey(_activeIndex),
                                      controllers: _controllers[_activeIndex],
                                      formKey: _formKeys[_activeIndex],
                                      index: _activeIndex,
                                      count: _count,
                                      onPrevious: _activeIndex > 0
                                          ? () => setState(
                                              () => _activeIndex =
                                                  _activeIndex - 1,
                                            )
                                          : null,
                                      onNextOrSave: () async {
                                        // 还没到最后一个 recipient，直接切换页
                                        if (_activeIndex < _count - 1) {
                                          setState(
                                            () =>
                                                _activeIndex = _activeIndex + 1,
                                          );
                                          return;
                                        }

                                        // 收集表单数据
                                        final recipients = _controllers
                                            .map(
                                              (m) => {
                                                'firstName': m['first']!.text
                                                    .trim(),
                                                'lastName': m['last']!.text
                                                    .trim(),
                                                'email': m['email']!.text
                                                    .trim(),
                                                'phone': m['phone']!.text
                                                    .trim(),
                                                'dateOfBirth':
                                                    m['dob']?.text.trim() ?? '',
                                                'gender': m['gender']!.text
                                                    .trim(),
                                                'type': m['type']!.text.trim(),
                                              },
                                            )
                                            .toList();

                                        debugPrint(
                                          'Recipients to insert: $recipients',
                                        );

                                        final caregiverId =
                                            widget.caregiverId ??
                                            ref.read(currentUserIdProvider) ??
                                            '';

                                        if (caregiverId.isEmpty) {
                                          _showSnack(
                                            'Missing caregiver identifier. Cannot insert recipients.',
                                          );
                                          return;
                                        }

                                        // Capture client and messenger before any awaits
                                        final client = createClient();
                                        final messenger = ScaffoldMessenger.of(
                                          context,
                                        );

                                        // 这里的 generatedCode 没被用到，如果只是 debug 可以保留
                                        final generatedCode =
                                            await fetchGeneratedCode(
                                              client,
                                              messenger: messenger,
                                              id: 2,
                                            );
                                        debugPrint(
                                          'Generated Code = $generatedCode',
                                        );

                                        if (_saving) {
                                          return; // prevent duplicate taps
                                        }

                                        setState(() => _saving = true);
                                        // Show a non-dismissible loading dialog while creating accounts
                                        final dismissLoading = showLoadingDialog(
                                          context,
                                          'Account creation in progress..',
                                        );

                                        try {

                                          const String mutation = r'''
mutation InsertRecipients($objects: [CareRecipientInput!]!) {
  insert_care_recipient(objects: $objects) {
    id
    firstName
    lastName
    email
    caregiverId
    type
  }
}
''';

                                          final List<Map<String, dynamic>>
                                          recipientsList = [];

                                          for (
                                            var i = 0;
                                            i < recipients.length;
                                            i++
                                          ) {
                                            final r = recipients[i];
                                            final perCode =
                                                await fetchGeneratedCode(
                                                  client,
                                                  messenger: messenger,
                                                  id: 2,
                                                );
                                            final clientId =
                                                (perCode != null &&
                                                    perCode.isNotEmpty)
                                                ? perCode
                                                : 'CR-${i + 1}';

                                            final item = {
                                              'id': clientId,
                                              'firstName':
                                                  (r['firstName'] ?? '')
                                                      .toString(),
                                              'lastName': (r['lastName'] ?? '')
                                                  .toString(),
                                              'dateOfBirth':
                                                  (r['dateOfBirth'] ?? '')
                                                      .toString()
                                                      .isNotEmpty
                                                  ? r['dateOfBirth']
                                                  : null,
                                              'gender': (r['gender'] ?? '')
                                                  .toString(),
                                              'email': (r['email'] ?? '')
                                                  .toString(),
                                              'phone': (r['phone'] ?? '')
                                                  .toString(),
                                              'caregiverId': caregiverId,
                                              'type':
                                                  (r['careRecipientTypeId'] ??
                                                          r['type'] ??
                                                          '')
                                                      .toString(),
                                            };

                                            recipientsList.add(item);
                                            debugPrint(
                                              'generatedCode for #${i + 1}: $perCode',
                                            );
                                            debugPrint(
                                              'Built recipient id=$clientId, name=${item['firstName']} ${item['lastName']}',
                                            );
                                          }

                                          final result = await client.mutate(
                                            MutationOptions(
                                              document: gql(mutation),
                                              variables: {
                                                'objects': recipientsList,
                                              },
                                              fetchPolicy:
                                                  FetchPolicy.networkOnly,
                                            ),
                                          );

                                          if (result.hasException) {
                                            debugPrint(
                                              result.exception.toString(),
                                            );
                                            _showSnack(
                                              'Insert failed: ${result.exception.toString()}',
                                            );
                                            return;
                                          }

                                          final insertPayload = result
                                              .data?['insert_care_recipient'];

                                          final inserted =
                                              (insertPayload is Map &&
                                                  insertPayload['returning'] !=
                                                      null)
                                              ? insertPayload['returning']
                                              : insertPayload ?? result.data;

                                          debugPrint('Inserted: $inserted');

                                          _showSnack(
                                            'Recipients saved successfully',
                                          );

                                          // 创建 Firebase 帐号 + 发送 email
                                          try {
                                            final functions =
                                                FirebaseFunctions.instanceFor(
                                                  region: 'us-central1',
                                                );

                                            for (final r in recipientsList) {
                                              final email = (r['email'] ?? '')
                                                  .toString();
                                              if (email.isEmpty) continue;

                                              final password =
                                                  _generatePassword();

                                              final callable = functions
                                                  .httpsCallable(
                                                    'sendTestEmail',
                                                  );

                                              final subject =
                                                  'CareLink account created — action required';

                                              final text =
                                                  'Hello ${r['firstName']} ${r['lastName']},\n\n'
                                                  'An account has been created for you on CareLink. Use the credentials below to sign in for the first time:\n\n'
                                                  'Email: $email\n'
                                                  'Temporary password: $password\n\n'
                                                  'For your security, please sign in and change your password as soon as possible. If you did not expect this email, contact your caregiver or support immediately.\n\n'
                                                  'Download the app or sign in at: https://your-app-url.example\n\n'
                                                  'Regards,\nCareLink Team';

                                              final html =
                                                  '''
<p>Hello ${r['firstName']} ${r['lastName']},</p>
<p>An account has been created for you on <strong>CareLink</strong>. Use the credentials below to sign in for the first time:</p>
<ul>
  <li><strong>Email:</strong> $email</li>
  <li><strong>Temporary password:</strong> $password</li>
</ul>
<p>Please sign in and change your password as soon as possible. If you did not expect this email, contact your caregiver or support immediately.</p>
<p>Regards,<br/>CareLink Team</p>
''';

                                              final resp = await callable.call(<
                                                String,
                                                dynamic
                                              >{
                                                'recipientId': r['id'],
                                                'email': email,
                                                'displayName':
                                                    '${r['firstName']} ${r['lastName']}',
                                                'password': password,
                                                'to': email,
                                                'subject': subject,
                                                'text': text,
                                                'html': html,
                                              });

                                              debugPrint(
                                                'createUserForRecipient resp: ${resp.data}',
                                              );

                                              try {
                                                final respData = resp.data;
                                                String? returnedUid;
                                                if (respData is Map) {
                                                  if (respData['uid'] != null) {
                                                    returnedUid =
                                                        respData['uid']
                                                            .toString();
                                                  } else if (respData['uids']
                                                          is List &&
                                                      (respData['uids'] as List)
                                                          .isNotEmpty) {
                                                    returnedUid =
                                                        (respData['uids']
                                                                as List)[0]
                                                            ?.toString();
                                                  } else if (respData['recipients']
                                                          is List &&
                                                      (respData['recipients']
                                                              as List)
                                                          .isNotEmpty) {
                                                    final first =
                                                        (respData['recipients']
                                                            as List)[0];
                                                    if (first is Map &&
                                                        first['createdUser']
                                                            is Map &&
                                                        first['createdUser']['uid'] !=
                                                            null) {
                                                      returnedUid =
                                                          first['createdUser']['uid']
                                                              .toString();
                                                    }
                                                  }
                                                }

                                                if (returnedUid != null &&
                                                    returnedUid.isNotEmpty) {
                                                  r['authUid'] = returnedUid;
                                                  debugPrint(
                                                    'Attached authUid=$returnedUid to recipient id=${r['id']}',
                                                  );

                                                  // 同步 Firebase -> Postgres 并更新 user_account
                                                  try {
                                                    try {
                                                      const syncMutation = r'''
                                                        mutation SyncUsersToPostgres {
                                                          syncUsersToPostgres {
                                                            success
                                                            synced
                                                          }
                                                        }
                                                      ''';

                                                      final syncResult =
                                                          await client.mutate(
                                                            MutationOptions(
                                                              document: gql(
                                                                syncMutation,
                                                              ),
                                                              fetchPolicy:
                                                                  FetchPolicy
                                                                      .noCache,
                                                            ),
                                                          );

                                                      if (syncResult
                                                          .hasException) {
                                                        debugPrint(
                                                          'syncUsersToPostgres mutation error: ${syncResult.exception}',
                                                        );
                                                        _showSnack(
                                                          'Warning: user sync failed (continuing).',
                                                        );
                                                      } else {
                                                        final syncData = syncResult
                                                            .data?['syncUsersToPostgres'];
                                                        if (syncData is Map) {
                                                          debugPrint(
                                                            'syncUsersToPostgres: success=${syncData['success']}, synced=${syncData['synced']}',
                                                          );
                                                        } else if (syncData
                                                            is bool) {
                                                          debugPrint(
                                                            'syncUsersToPostgres: result=$syncData',
                                                          );
                                                        } else {
                                                          debugPrint(
                                                            'syncUsersToPostgres: unexpected result: $syncData',
                                                          );
                                                        }
                                                      }
                                                    } catch (e, st) {
                                                      debugPrint(
                                                        'syncUsersToPostgres call failed: $e\n$st',
                                                      );
                                                      _showSnack(
                                                        'Warning: user sync failed (continuing).',
                                                      );
                                                    }

                                                    const String
                                                    updateUserMutation = r'''
mutation UpdateUser($uid: String!, $new_id: String!, $userType: String!) {
  update_caregiver_account(uid: $uid, new_id: $new_id, userType: $userType) {
    uid
    id
    userType
  }
}
''';

                                                    final updateResult =
                                                        await client.mutate(
                                                          MutationOptions(
                                                            document: gql(
                                                              updateUserMutation,
                                                            ),
                                                            variables: {
                                                              'uid':
                                                                  returnedUid,
                                                              'new_id': r['id'],
                                                              'userType':
                                                                  'Care Recipient',
                                                            },
                                                            fetchPolicy:
                                                                FetchPolicy
                                                                    .noCache,
                                                          ),
                                                        );

                                                    if (updateResult
                                                        .hasException) {
                                                      debugPrint(
                                                        'Failed to update user_account for uid=$returnedUid: ${updateResult.exception}',
                                                      );
                                                      _showSnack(
                                                        'Failed to link account in backend',
                                                      );
                                                    } else {
                                                      debugPrint(
                                                        'Updated user_account for uid=$returnedUid: ${updateResult.data}',
                                                      );
                                                    }
                                                  } catch (e) {
                                                    debugPrint(
                                                      'GraphQL update error for uid=$returnedUid: $e',
                                                    );
                                                  }
                                                } else {
                                                  debugPrint(
                                                    'No uid returned for recipient id=${r['id']}',
                                                  );
                                                }
                                              } catch (e) {
                                                debugPrint(
                                                  'Failed to parse function response for uid: $e',
                                                );
                                              }
                                            }
                                          } catch (e) {
                                            debugPrint(
                                              'Account creation (cloud function) failed: $e',
                                            );
                                            _showSnack(
                                              'Accounts not created: cloud function unavailable',
                                            );
                                          }

                                          // 完成后跳转到完成页
                                          if (!mounted) return;
                                          context.go(
                                            '/register/registercomplete',
                                          );
                                        } catch (e) {
                                          debugPrint('Request failed: $e');
                                          _showSnack('Request failed: $e');
                                        } finally {
                                          try {
                                            dismissLoading();
                                          } catch (_) {}
                                          if (mounted) {
                                            setState(() => _saving = false);
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              // right arrow
                              IconButton(
                                onPressed: _activeIndex < _count - 1
                                    ? () => setState(
                                        () => _activeIndex = _activeIndex + 1,
                                      )
                                    : null,
                                icon: Icon(Icons.chevron_right, size: 28.sp),
                                color: accent,
                                disabledColor: Colors.black12,
                                tooltip: 'Next recipient',
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 16.h),

                        // Back 按钮
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  final ok = await _onWillPop();
                                  if (!mounted) return;
                                  if (ok) {
                                    Navigator.of(context).maybePop();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                ),
                                child: Text(
                                  'Back',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12.w),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
