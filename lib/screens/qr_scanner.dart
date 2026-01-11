import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:carelink_mobile/utils/watch_login.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _processing = false;

      void _handleBarcode(String code) async {
    if (_processing) return;
    _processing = true;

    try {
      if (code.startsWith('CareLink:Login:')) {
        // delegate to existing logic in utils/watch_login.dart
        onScanSuccess(code);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已发送登录请求到手表'))


        );

        // Close scanner after short delay
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.of(context).pop(true);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('不是有效的 CareLink 登录二维码')),

        );
        // allow scanning again
        _processing = false;
      }
    } catch (e) {
      _processing = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('扫描失败: $e')),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫描手表登录二维码'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
            tooltip: '闪光灯',
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
            tooltip: '切换相机',
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;
              final String? raw = barcodes.first.rawValue;
              if (raw == null) return;
              _handleBarcode(raw);
            },
          ),
          // simple overlay
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
