import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'dart:convert';
import 'package:carelink_mobile/utils/secure_auth.dart';

const String getCaregiverWithRecipientsQuery = r'''
query GetCaregiverWithRecipients($id: String!) {
  caregiver_by_pk(id: $id) {
    id
    firstName
    lastName
    name
    email
    phone
    caregiverType
    careRecipients {
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
}
''';

/// Helper to fetch care recipients for a caregiver (returns list of recipients)
Future<List<Map<String, dynamic>>> fetchCareRecipients(
  GraphQLClient client,
  String caregiverId,
) async {
  final options = QueryOptions(
    document: gql(getCaregiverWithRecipientsQuery),
    variables: {'id': caregiverId},
    fetchPolicy: FetchPolicy.networkOnly,
  );

  final result = await client.query(options);
  if (result.hasException) {
    throw result.exception!;
  }

  final data = result.data?['caregiver_by_pk'] as Map<String, dynamic>?;
  if (data == null) return [];
  final recips = (data['careRecipients'] as List<dynamic>?) ?? [];
  return recips.cast<Map<String, dynamic>>();
}

class TestPage extends StatefulWidget {
  const TestPage({super.key});
  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  final TextEditingController _idCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _recipients = [];
  Map<String, String>? _caregiverInfo;


  @override
  void initState() {
    super.initState();
    // Require biometric on page entry for this test page.
    _requireBiometricOnEntry();
  }

  /// Require biometric authentication when the user enters this page.
  /// If the device doesn't support biometrics, or the user exits, the page will be popped.
  void _requireBiometricOnEntry() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final available = await SecureAuth.canAuthenticate();
        if (!available) {
          // Show a blocking dialog explaining biometrics are required
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (c) => AlertDialog(
              title: const Text('Biometric required'),
              content: const Text('This page requires biometric authentication, but your device does not support it.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(c).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          if (mounted) Navigator.of(context).maybePop();
          return;
        }

        var authed = await SecureAuth.authenticate();
        while (!authed && mounted) {
          final choice = await showDialog<String>(
            context: context,
            barrierDismissible: false,
            builder: (c) => AlertDialog(
              title: const Text('Authentication required'),
              content: const Text('Please unlock with biometrics to continue.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(c).pop('exit'),
                  child: const Text('Exit'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(c).pop('retry'),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );

          if (choice == 'retry') {
            authed = await SecureAuth.authenticate();
            continue;
          }

          // Exit chosen -> leave the page
          if (mounted) Navigator.of(context).maybePop();
          return;
        }
      } catch (e, st) {
        debugPrint('TestPage._requireBiometricOnEntry error: $e');
        debugPrint(st.toString());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Biometric error: ${e.toString()}')));
          Navigator.of(context).maybePop();
        }
      }
    });
  }

  // No biometric gate on page open; testing is manual via button below.

  // Credential storage helpers removed from this test page (we only test biometrics)

  Future<void> _tryBiometricSignIn() async {
    try {
      final available = await SecureAuth.canAuthenticate();
      if (!available) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Biometric not available on this device')));
        debugPrint('TestPage: biometric not available');
        return;
      }

      final unlocked = await SecureAuth.authenticate();
      if (unlocked) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Biometric unlocked successfully')));
        debugPrint('TestPage: biometric unlocked successfully');
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Biometric authentication failed')));
        debugPrint('TestPage: biometric authentication failed');
      }
    } catch (e, st) {
      debugPrint('TestPage._tryBiometricSignIn error: $e');
      debugPrint(st.toString());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Biometric error: ${e.toString()}')));
    }
  }

  Future<void> _runQuery() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _recipients = [];
      _caregiverInfo = null;
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
          document: gql(getCaregiverWithRecipientsQuery),
          variables: {'id': caregiverId},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (result.hasException) {
        setState(() {
          // Show graphql exception summary
          _error = result.exception.toString();
        });
        // log exception
        debugPrint('GraphQL exception: ${result.exception.toString()}');
        return;
      }

      final data = result.data?['caregiver_by_pk'] as Map<String, dynamic>?;
      // print full result data to console for debugging
      try {
        final pretty = const JsonEncoder.withIndent('  ').convert(result.data);
        debugPrint('GraphQL result:\n$pretty');
      } catch (_) {
        debugPrint('GraphQL result: ${result.data}');
      }

      final recs = (data?['careRecipients'] as List<dynamic>?) ?? [];

      setState(() {
        _recipients = recs
            .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
            .toList();
        _caregiverInfo = data != null
            ? {
                'id': data['id']?.toString() ?? '',
                'name': (data['name'] ??
                        '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}')
                    .toString(),
                'email': data['email']?.toString() ?? '',
                'phone': data['phone']?.toString() ?? '',
                'caregiverType': data['caregiverType']?.toString() ?? '',
              }
            : null;
      });
    } catch (e, st) {
      setState(() {
        _error = e.toString();
      });
      debugPrint('Query threw error: $e');
      debugPrint(st.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Run the same caregiver query but keep it "hidden":
  /// - does not update visible UI aside from logs
  /// - stores the found caregiver id into `_lastHiddenCaregiverId` for debugging
  Future<void> _runHiddenCaregiverQuery() async {
    final client = GraphQLProvider.of(context).value;
    final caregiverId = _idCtrl.text.trim();
    if (caregiverId.isEmpty) {
      debugPrint('Hidden query skipped: no caregiver id provided.');
      return;
    }

    try {
      final result = await client.query(
        QueryOptions(
          document: gql(getCaregiverWithRecipientsQuery),
          variables: {'id': caregiverId},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (result.hasException) {
        debugPrint('Hidden GraphQL exception: ${result.exception}');
        return;
      }

      final data = result.data?['caregiver_by_pk'] as Map<String, dynamic>?;
      final id = data?['id']?.toString();
      debugPrint('Hidden caregiver id: $id');
    } catch (e, st) {
      debugPrint('Hidden query error: $e');
      debugPrint(st.toString());
    }
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Care Recipients Query'),
        actions: [
          // discreet/hidden trigger for the caregiver ID query
          IconButton(
            icon: const Icon(Icons.visibility_off),
            tooltip: 'Run hidden caregiver query',
            onPressed: _runHiddenCaregiverQuery,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                  // removed credential input and save/check controls (biometric-only test page)
                  TextField(
                    controller: _idCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Caregiver ID',
                      hintText: 'Enter caregiver id',
                    ),
                  ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isLoading ? null : _runQuery,
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Run Query'),
              ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _tryBiometricSignIn,
                    child: const Text('Test Biometric'),
                  ),
              const SizedBox(height: 12),
              if (_error != null)
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      'Error:\n\n$_error',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
              else ...[
                if (_caregiverInfo != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _caregiverInfo!['name'] ?? '',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ID: ${_caregiverInfo!['id'] ?? ''}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(_caregiverInfo!['email'] ?? ''),
                            const SizedBox(height: 2),
                            Text(_caregiverInfo!['phone'] ?? ''),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_recipients.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text('No recipients (run a query)'),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: _recipients.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final r = _recipients[i];
                        final name =
                            '${r['firstName'] ?? ''} ${r['lastName'] ?? ''}'
                                .trim();
                        final contact =
                            (r['email'] as String?) ?? (r['phone'] as String?) ?? '';
                        final type = (r['type'] as String?) ?? '';
                        final id = (r['id'] as String?) ?? r['id']?.toString() ?? '';
                        return ListTile(
                          title: Text(name.isEmpty ? 'No name' : name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (contact.isNotEmpty) Text(contact),
                              Text('ID: $id',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          trailing: Text(type),
                        );
                      },
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}