import 'dart:convert';
import 'package:web_socket_channel/io.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


// 扫码成功后的回调
Future<void> onScanSuccess(String code) async {
  if (!code.startsWith("CareLink:Login:")) return;

  final watchId = code.substring("CareLink:Login:".length);

  // 从安全存储获取账号密码
  final storage = FlutterSecureStorage();
  final String? email = await storage.read(key: "email");
  final String? password = await storage.read(key: "password");

  if (email == null || password == null) {
    print('onScanSuccess: no credentials stored');
    return;
  }

  final wsUrl = dotenv.env['WS_URL'] ?? '';
  if (wsUrl.isEmpty) {
    print('onScanSuccess: WS_URL not configured');
    return;
  }

  IOWebSocketChannel? channel;
  try {
    channel = IOWebSocketChannel.connect(wsUrl);

    final clientId = 'Phone_Manager_${DateTime.now().millisecondsSinceEpoch}';

    // send join first
    channel.sink.add(jsonEncode({
      'type': 'join',
      'clientId': clientId,
      'role': 'caregiver',
    }));

    // small delay to allow the server to process join
    await Future.delayed(const Duration(milliseconds: 250));

    // send remote_login to target watch
    final loginMsg = {
      'type': 'remote_login',
      'to': watchId,
      'email': email,
      'password': password,
    };

    channel.sink.add(jsonEncode(loginMsg));
    print('已向手表 $watchId 发送登录请求');

    // optionally listen for responses/errors for a short period
    channel.stream.timeout(const Duration(seconds: 2), onTimeout: (sink) => null).listen(
      (message) {
        print('WS message: $message');
      },
      onError: (err) => print('WS error: $err'),
      onDone: () => print('WS done'),
    );

    // keep connection briefly to ensure delivery
    await Future.delayed(const Duration(seconds: 1));
  } catch (e) {
    print('onScanSuccess error: $e');
  } finally {
    try {
      await channel?.sink.close();
    } catch (_) {}
  }
}