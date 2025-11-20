import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class GraphQLInsertTestPage extends StatefulWidget {
  const GraphQLInsertTestPage({super.key});

  @override
  State<GraphQLInsertTestPage> createState() => _GraphQLInsertTestPageState();
}

class _GraphQLInsertTestPageState extends State<GraphQLInsertTestPage> {
  bool _loading = false;
  final TextEditingController _logController = TextEditingController();

  void _appendLog(String line) {
    final time = DateTime.now().toIso8601String();
    _logController.text = '${_logController.text}[$time] $line\n';
  }

  Future<void> _runInsert() async {
    // Use hard-coded test values so no text inputs are required.
    // Change these values as needed for your environment.


    setState(() => _loading = true);
    try {
      final client = GraphQLProvider.of(context).value;

      // Hard-coded dummy recipients for testing (match schema keys)
      final recipients = [
        {
          'id': 'CR-001',
          'firstName': 'Alice',
          'lastName': 'Tan',
          'email': 'alice.tan+test1@example.com',
          'phone': '+60110000001',
          'caregiverId': 'CG-001',
          'type': 'patient',
        },
        {
          'id': 'CR-002',
          'firstName': 'Bob',
          'lastName': 'Lee',
          'email': 'bob.lee+test2@example.com',
          'phone': '+60110000002',
          'caregiverId': 'CG-001',
          'type': 'patient',
        },
        {
          'id': 'CR-003',
          'firstName': 'Cik',
          'lastName': 'Siti',
          'email': 'siti.siti+test3@example.com',
          'phone': '+60110000003',
          'caregiverId': 'CG-001',
          'type': 'patient',
        },
      ];

      // Use middleware schema: upsertCareRecipient(input: CareRecipientInput!)
      const String mutation = r'''
mutation UpsertCareRecipient($input: CareRecipientInput!) {
  upsertCareRecipient(input: $input) {
    id
    firstName
    lastName
    email
  }
}
''';

      // Call upsert for each recipient and log results
      for (final rec in recipients) {
        // ensure keys use camelCase schema names
        final input = {
          'id': rec['id'],
          'firstName': rec['firstName'],
          'lastName': rec['lastName'],
          'email': rec['email'],
          'phone': rec['phone'],
          'caregiverId': rec['caregiverId'].toString(),
          'type': rec['type'],
        };

        final variables = {'input': input};
        _appendLog('Sending variables: ${jsonEncode(variables)}');

        final result = await client.mutate(MutationOptions(
          document: gql(mutation),
          variables: variables,
          fetchPolicy: FetchPolicy.networkOnly,
        ));

        // Always log the raw result for debugging
        _appendLog('Raw result: ${result.toString()}');

        if (result.hasException) {
          final ex = result.exception.toString();
          _appendLog('GraphQL exception: $ex');
          if (result.exception?.graphqlErrors.isNotEmpty ?? false) {
            _appendLog('GraphQL errors: ${result.exception!.graphqlErrors}');
          }
          if (result.exception?.linkException != null) {
            _appendLog('GraphQL linkException: ${result.exception!.linkException}');
          }
        } else {
          final data = result.data?['upsertCareRecipient'];
          _appendLog('Upsert returned: $data');
          if (data == null) {
            _appendLog('Note: mutation returned null — check server resolver, validation, or constraints (e.g., caregiverId existence).');
          }
        }
      }
    } catch (e, st) {
      _appendLog('Request failed: $e');
      _appendLog('Stack trace: $st');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _logController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GraphQL Insert Test')),
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _loading ? null : _runInsert,
              child: _loading ? const CircularProgressIndicator() : const Text('Insert sample recipient (no input)'),
            ),
            const SizedBox(height: 12),
            const Text('Logs (debug):'),
            const SizedBox(height: 6),
            SizedBox(
              height: 220,
              child: TextField(
                controller: _logController,
                readOnly: true,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => setState(() => _logController.clear()),
                  child: const Text('Clear logs'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => debugPrint(_logController.text),
                  child: const Text('Dump to console'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
