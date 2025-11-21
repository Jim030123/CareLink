import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
    final result = await callable.call(<String, dynamic>{
      // send as a list to ensure receiver normalization on the function side
      'to': 'b240048a@sc.edu.my',
      'subject': 'Testing email 2',
      'text': 'Hello from Flutter \nThis is a test email sent from the Flutter app.',
    });

    final data = result.data;
    String msg;
    if (data == null) {
      msg = 'Function returned no data.';
    } else if (data is Map) {
      final success = data['success'] == true;
      final sentTo = data['sentTo'];
      final info = data['info'];
      msg = 'Success: $success\nSent to: $sentTo\nInfo: $info';
    } else {
      msg = 'Result: ${data.toString()}';
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
