import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:convert';

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  bool isLoading = false;
  String resultText = '';

  Future<void> testSendEmailFunction() async {
  setState(() {
    isLoading = true;
    resultText = '';
  });

  final functions = FirebaseFunctions.instanceFor(region: 'us-central1'); // 你函数的 region
  final callable = functions.httpsCallable('sendTestEmail');

  try {
    // Sample payload — adjust these values for your test environment
    final samplePayload = <String, dynamic>{
      // `to` can be a single string or an array of strings
      'to': [
        // Use an address you control or a test inbox
        'b240041a@sc.edu.my'
      ],
      // Optional fields used by the function
      'password': 'TempPass123!',
      'displayName': 'Test Recipient',
      // If you want the function to write authUid into a Firestore doc, set a recipientId
      'recipientId': 'test_recipient_doc_id',
      'subject': 'CareLink Test Email',
      'text': 'This is a test email from CareLink function. If you received this, the function worked.'
    };

    final result = await callable.call(samplePayload);

    final data = result.data;
    String msg;
    if (data == null) {
      msg = 'Function returned no data.';
    } else {
      // Try to extract a convenient UID if present
      String? returnedUid;
      try {
        if (data is Map) {
          if (data['uid'] != null) returnedUid = data['uid'].toString();
          else if (data['uids'] is List && (data['uids'] as List).isNotEmpty) returnedUid = (data['uids'] as List)[0]?.toString();
          else if (data['recipients'] is List && (data['recipients'] as List).isNotEmpty) {
            final first = (data['recipients'] as List)[0];
            if (first is Map && first['createdUser'] is Map && first['createdUser']['uid'] != null) returnedUid = first['createdUser']['uid'].toString();
          }
        }
      } catch (_) {
        returnedUid = null;
      }

      // Format the JSON for display; include UID summary at top if available
      String jsonPart;
      try {
        jsonPart = const JsonEncoder.withIndent('  ').convert(data);
      } catch (_) {
        jsonPart = data.toString();
      }

      if (returnedUid != null && returnedUid.isNotEmpty) {
        msg = 'Returned UID: $returnedUid\n\n$jsonPart';
      } else {
        msg = jsonPart;
      }
    }

    setState(() {
      resultText = msg;
    });
  } on FirebaseFunctionsException catch (e, st) {
    final msg = 'Error (${e.code}): ${e.message}';
    setState(() {
      resultText = msg;
    });
    print(st);
  } catch (e, st) {
    setState(() {
      resultText = 'Other error: $e';
    });
    print(st);
  } finally {
    setState(() {
      isLoading = false;
    });
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Firebase Function'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: isLoading ? null : testSendEmailFunction,
              child: isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Test sendTestEmail Function'),
            ),
            const SizedBox(height: 20),
            Text(
              resultText,
              style: TextStyle(
                color: resultText.startsWith('Error') ? Colors.red : Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

}
