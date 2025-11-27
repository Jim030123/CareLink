import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'dart:convert';

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

  @override
  void dispose() {
    _idCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Care Recipients Query')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
    );
  }
}