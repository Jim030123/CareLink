import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import '../components/care_reciepient_form.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

/// Step: Care Recipient Account — select how many elderly persons the user will manage.
///
/// Callbacks:
/// - onBack: VoidCallback? (defaults to Navigator.pop)
/// - onNext: ValueChanged<int>? receives the selected count
/// - onLogin: VoidCallback? (defaults to pushReplacementNamed('/login'))
class RegisterCareReciepientPage extends StatefulWidget {
  /// number of care recipients to render
  final int count;

  /// optional caregiver identifier (email or id) used to associate recipients
  /// with the caregiver in the backend. If you don't provide this, the
  /// insertion code will show a helpful SnackBar.
  final String? caregiverEmail;

  const RegisterCareReciepientPage({super.key, required this.count, this.caregiverEmail});

  @override
  State<RegisterCareReciepientPage> createState() =>
      _RegisterCareReciepientPageState();
}

class _RegisterCareReciepientPageState
    extends State<RegisterCareReciepientPage> {
  // number of care recipients (comes from widget.count)
  late int _count;
  // currently visible recipient index
  int _activeIndex = 0;

  // controllers and form keys for each recipient
  final List<Map<String, TextEditingController>> _controllers = [];
  final List<GlobalKey<FormState>> _formKeys = [];

  // saving flag to prevent duplicate submissions
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

  Future<bool> _onWillPop() async {
    // Show confirmation dialog. Return true to allow pop.
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm'),
        content: const Text('Going back will clear all entered data. Do you want to continue?'),
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

  // moved form UI into component `CareReciepientForm`
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
                      // step indicator and card
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
                                      color: Color(0xFFF4CBA1),

                                      borderRadius: BorderRadius.circular(16.w),
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
                                      'Care Reciepient Detail',

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

                      // counter controls


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
                      ? () => setState(() => _activeIndex = _activeIndex - 1)
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
                      CareReciepientForm(
                        controllers: _controllers[_activeIndex],
                        formKey: _formKeys[_activeIndex],
                        index: _activeIndex,
                        count: _count,
                        onPrevious: _activeIndex > 0
                            ? () => setState(() => _activeIndex = _activeIndex - 1)
                            : null,
                        onNextOrSave: () async {
                          if (_activeIndex < _count - 1) {
                            setState(() => _activeIndex = _activeIndex + 1);
                            return;
                          }

                          final recipients = _controllers.map((m) => {
                            'first_name': m['first']!.text.trim(),
                            'last_name': m['last']!.text.trim(),
                            'email': m['email']!.text.trim(),
                            'phone': m['phone']!.text.trim(),
                          }).toList();

                          debugPrint('Recipients to insert: $recipients');

                          // Require caregiver email to associate recipients with the caregiver
                          if (widget.caregiverEmail == null || widget.caregiverEmail!.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('Missing caregiver identifier. Cannot insert recipients.'),
                            ));
                            return;
                          }

                          if (_saving) return; // prevent duplicate taps

                          setState(() => _saving = true);
                          try {
                            final client = GraphQLProvider.of(context).value;

                            // NOTE: Replace the mutation below with your middleware's
                            // exact mutation and input types. This is a placeholder
                            // demonstrating how to pass variables to the server.
                            const String mutation = r'''
mutation InsertRecipients($caregiverEmail: String!, $recipients: [RecipientInput!]!) {
  insertRecipients(caregiverEmail: $caregiverEmail, recipients: $recipients) {
    success
    insertedCount
  }
}
''';

                            final result = await client.mutate(MutationOptions(
                              document: gql(mutation),
                              variables: {
                                'caregiverEmail': widget.caregiverEmail,
                                'recipients': recipients,
                              },
                              fetchPolicy: FetchPolicy.networkOnly,
                            ));

                            if (result.hasException) {
                              debugPrint('GraphQL error: ${result.exception}');
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text('Server error: ${result.exception}')));
                              return;
                            }

                            final ok = result.data?['insertRecipients']?['success'] ?? true;
                            if (ok == false) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('Insert failed on server'),
                              ));
                              return;
                            }

                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('Recipients saved successfully'),
                            ));

                            // Advance or close — here we pop back to previous page
                            Navigator.of(context).pop();
                          } catch (e) {
                            debugPrint('Request failed: $e');
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Request failed: $e'),
                            ));
                          } finally {
                            if (mounted) setState(() => _saving = false);
                          }
                        },
                      ),
                    ],
                  ),
                ),

                // right arrow
                IconButton(
                  onPressed: _activeIndex < _count - 1
                      ? () => setState(() => _activeIndex = _activeIndex + 1)
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

                      // Back / Next buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                                onPressed: () async {
                                  final ok = await _onWillPop();
                                  if (ok) Navigator.of(context).pop();
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

                      SizedBox(height: 8.h),
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