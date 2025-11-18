// ignore_for_file: use_build_context_synchronously

import 'package:carelink_mobile/components/text_field.dart';
import 'package:carelink_mobile/utils/auth_service.dart';
import 'package:carelink_mobile/utils/graphql_service.dart';
// import 'package:carelink_mobile/utils/auth_service.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

/// Create Primary Caregiver Account step
/// Exposes callbacks:
/// - onBack: VoidCallback
/// - onNext: ValueChanged<Map<String, dynamic>> with collected form data
/// - onLogin: VoidCallback
class RegisterCaregiverPage extends StatefulWidget {
  const RegisterCaregiverPage({
    super.key,
    this.onBack,
    this.onNext,
    this.onLogin,
  });

  final VoidCallback? onBack;
  final ValueChanged<Map<String, dynamic>>? onNext;
  final VoidCallback? onLogin;

  @override
  State<RegisterCaregiverPage> createState() => _RegisterCaregiverPageState();
}

class _RegisterCaregiverPageState extends State<RegisterCaregiverPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _handleNext() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'firstName': _firstName.text.trim(),
      'lastName': _lastName.text.trim(),
      'email': _email.text.trim(),
      'password': _password.text,
    };

    if (widget.onNext != null) {
      widget.onNext!(data);
      return;
    }

    // Check whether the email already exists in the backend via GraphQL.
    // The dev middleware exposes a `users` query (see GraphQLTestPage), so we
    // query `users { email }` and match client-side. Replace with a filtered
    // query if your server exposes one for efficiency.
    try {
      final client = GraphQLProvider.of(context).value;
      final result = await client.query(
        QueryOptions(
          document: gql(r'''
          query {
            users {
              email
            }
          }
        '''),
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (result.hasException) {
        final msg = result.exception.toString();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Server error: $msg')));
        return;
      }

      final users = result.data?['users'] as List<dynamic>?;
      final emailValue = data['email'] as String;
      final exists =
          users?.any(
            (u) =>
                (u['email'] as String?)?.toLowerCase() ==
                emailValue.toLowerCase(),
          ) ??
          false;

      if (exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You already created an account before, please sign in',
            ),
          ),
        );
        return;
      }

      // help me insert an id column in user_account table through gqlusing the index_table's id ==1
      // 1) read the index row where id == 1 to get the next id
      final idxResult = await client.query(
        QueryOptions(
          document: gql(r'''
            query GetIndexByPk($id: Int!) {
              index_table_by_pk(id: $id) {
                id
                name
                index
                prefix
              }
            }
            '''),
          variables: {'id': 1},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (idxResult.hasException) {
        final msg = idxResult.exception.toString();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Index fetch failed: $msg')));
        return;
      }

      // read from Hasura response key for single-row by-pk
      final index = idxResult.data!['index_table_by_pk']['index'] as int;

      final prefix = idxResult.data?['index_table_by_pk']['prefix'] as String?;

      final generatedCode = '$prefix-${index.toString().padLeft(3, '0')}';
      debugPrint('Generated Code = $generatedCode');

      final userCredential = await AuthService.instance.signUpWithEmail(
        email: data['email'] as String,
        password: data['password'] as String,
      );

      final uid = userCredential.user!.uid;
      print("New UID = $uid");

      // refresh usertable first through gql query from firebase
  final userTableResult = await client.query(
        QueryOptions(
          document: gql('''
            query {
              users {
                uid
                email
              }
            }
          '''),
        ),
      );

//print the usertableresult
print(userTableResult.data);




      // If we have a Firebase UID for this user, update the user_account.id
      // where uid matches the Firebase UID to reserve the generatedCode.
      if (uid.isNotEmpty) {
        // Use server's expected mutation signature: pass uid and new_id directly
        final updateUserIdGql = r'''
          mutation UpdateUserAccountId($uid: String!, $new_id: String!) {
            update_user_account(uid: $uid, new_id: $new_id) {
              id
            }
          }
          ''';

        final updateResult = await client.mutate(
          MutationOptions(
            document: gql(updateUserIdGql),
            variables: {'uid': uid, 'new_id': generatedCode},
            fetchPolicy: FetchPolicy.noCache,
          ),
        );
        // Detailed logging for update result
        if (updateResult.hasException) {
          debugPrint(
            'Update user_account id failed: ${updateResult.exception}',
          );
          // log GraphQL errors and link exceptions if present
          final ex = updateResult.exception;
          if (ex != null) {
            if (ex.graphqlErrors.isNotEmpty) {
              for (final ge in ex.graphqlErrors) {
                debugPrint(
                  'GraphQL error: ${ge.message}; path: ${ge.path}; extensions: ${ge.extensions}',
                );
              }
            }
            if (ex.linkException != null) {
              debugPrint('Link exception: ${ex.linkException}');
            }
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to update account id: ${updateResult.exception}',
              ),
            ),
          );
        }

        debugPrint('Update user_account result: ${updateResult.data}');

        // Server returns the updated user object with `id` (or null on failure).
       final returnedId =
            updateResult.data?['update_user_account']?['id'] as  String?;
        final accountSet = returnedId != null && returnedId.isNotEmpty;

        if (!accountSet) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to set user_account.id for this uid.'),
            ),
          );
          return;
        }
      }

      // Insert user_account row using the generated code
      //   final String upsertCaregiverGql = r'''
      // mutation UpsertCaregiver($input: CaregiverInput!) {
      //   upsertCaregiver(input: $input) {
      //     id
      //     firstName
      //     lastName
      //     name
      //     email
      //     phone
      //     caregiverType
      //     careRecipientId
      //   }
      // }
      // ''';

      //   final variables = {
      //     'id': generatedCode,
      //     'firstName': data['firstName'],
      //     'lastName': data['lastName'],
      //     'email': data['email'],
      //     'phone': null,
      //     'caregiverType': 'Primary',
      //     'careRecipientId': null,
      //   };

      //   final insertResult = await client.mutate(
      //     MutationOptions(
      //       document: gql(upsertCaregiverGql),
      //       variables: {'input': variables},
      //       fetchPolicy: FetchPolicy.noCache,
      //     ),
      //   );

      //   if (insertResult.hasException) {
      //     debugPrint('Upsert failed: ${insertResult.exception}');
      //   } else {
      //     debugPrint('Upsert result: ${insertResult.data}');
      //   }

      // Before incrementing the index, ensure the account row was actually set


      // increment the index on the server to reserve this id and get updated row
      final incResult = await client.mutate(
        MutationOptions(
          document: gql(r'''
            mutation IncrementIndex($id: Int!) {
              incrementIndex(id: $id) {
                index
                prefix
              }
            }
          '''),
          variables: {'id': 1},
        ),
      );

      if (incResult.hasException) {
        final msg = incResult.exception.toString();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Index increment failed: $msg')));
        return;
      }

      // if create a caregiver success and upsert success create a debugmessage
      debugPrint(
        'Caregiver created and upserted successfully with code: $generatedCode',
      );

      // Directly navigate to recipient detail and pass useful values via extra
      // if (!mounted) return;
      // context.push(
      //   '/register/caregiver/recipientdetail',
      //   extra: {'cgid': generatedCode, 'count': 1},
      // );
    } catch (e, st) {
      debugPrint('Request failed: $e\n$st');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Request failed: $e')));
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color card = Colors.white;

    return Scaffold(
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16.w,
                                    vertical: 8.h,
                                  ),

                                  decoration: BoxDecoration(
                                    color: Color(0xFFF4CBA1),

                                    borderRadius: BorderRadius.circular(16.w),
                                  ),

                                  child: Text(
                                    '2',
                                    style: TextStyle(fontSize: 24.sp),
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
                                      'Create Primary Caregiver',
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
                                  color: Color(0xFFFFF8F0),
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
                                      // 防止长文字溢出
                                      child: Text(
                                        'Allows us to customize the care experience based on the caregiver\'s relationship, preferences, and responsibilities.',
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

                      SizedBox(height: 14.h),

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
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              FormTextField(
                                controller: _firstName,
                                hint: 'First Name',
                              ),
                              SizedBox(height: 10.h),
                              FormTextField(
                                controller: _lastName,
                                hint: 'Last Name',
                              ),
                              SizedBox(height: 10.h),
                              FormTextField(
                                controller: _email,
                                hint: 'Email',
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty)
                                    return 'Enter email';
                                  if (!v.contains('@'))
                                    return 'Enter a valid email';
                                  return null;
                                },
                              ),
                              SizedBox(height: 10.h),
                              FormTextField(
                                controller: _password,
                                hint: 'Password',
                                obscureText: true,
                                validator: (v) {
                                  if (v == null || v.isEmpty)
                                    return 'Enter password';
                                  if (v.length < 6)
                                    return 'Password must be at least 6 characters';
                                  return null;
                                },
                              ),
                              SizedBox(height: 10.h),
                              FormTextField(
                                controller: _confirm,
                                hint: 'Confirm Password',
                                obscureText: true,
                                validator: (v) {
                                  if (v == null || v.isEmpty)
                                    return 'Confirm password';
                                  if (v != _password.text)
                                    return 'Passwords do not match';
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 18.h),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  widget.onBack ??
                                  () => Navigator.of(context).maybePop(),
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
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _handleNext,
                              child: Text(
                                'Next',
                                style: TextStyle(fontSize: 14.sp),
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 16.h),

                      Center(
                        child: Text(
                          'Already have account? Login here',
                          style: TextStyle(
                            fontSize: 15.sp,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
