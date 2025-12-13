import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Simple barcode scanner util that opens a full-screen scanner and returns
/// the first scanned value. If camera access fails or user cancels, it will
/// fall back to a manual-entry dialog.
class BarcodeScanner {
  /// Open scanner and return scanned barcode string or null if cancelled.
  static Future<String?> scan(BuildContext context) async {
    try {
      final result = await showDialog<String?>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return _MobileScannerDialog();
        },
      );

      if (result != null && result.isNotEmpty) return result;
    } catch (e) {
      // fallthrough to manual
      debugPrint('mobile scanner failed: $e');
    }

    // Manual fallback
    return await _manualEntry(context);
  }

  static Future<String?> _manualEntry(BuildContext context) async {
    final TextEditingController ctrl = TextEditingController();
    final res = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter barcode / SKU'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Paste or type code'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()), child: const Text('OK')),
        ],
      ),
    );

    return res;
  }
}

class _MobileScannerDialog extends StatefulWidget {
  @override
  State<_MobileScannerDialog> createState() => _MobileScannerDialogState();
}

class _MobileScannerDialogState extends State<_MobileScannerDialog> {
  String? _found;
  bool _scanned = false;
  final MobileScannerController _controller = MobileScannerController(
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // return null to indicate cancel
        Navigator.of(context).pop(null);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: (capture) async {
                        if (_scanned) return;
                        final List<Barcode> barcodes = capture.barcodes;
                        if (barcodes.isEmpty) return;
                        final raw = barcodes.first.rawValue;
                        if (raw == null || raw.isEmpty) return;
                        _scanned = true;
                        Navigator.of(context).pop(raw);
                      },
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(null),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                color: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _found ?? 'Point camera at barcode',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final manual = await BarcodeScanner._manualEntry(context);
                        if (manual != null && manual.isNotEmpty) {
                          Navigator.of(context).pop(manual);
                        }
                      },
                      child: const Text('Enter manually', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
