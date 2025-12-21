import 'dart:io';
import 'package:carelink_mobile/utils/firebse_storage.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class MedicalReportViewer extends StatefulWidget {
  final String storagePath;

  // If no storagePath is provided, default to the dummy PDF in Firebase Storage.
  const MedicalReportViewer({
    super.key,
    String? storagePath,
  }) : storagePath = storagePath ??
            'medical_report/dummy_health_report.pdf';

  @override
  State<MedicalReportViewer> createState() =>
      _MedicalReportViewerState();
}

class _MedicalReportViewerState extends State<MedicalReportViewer> {
  File? pdfFile;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  /// ✅ 支持：
  /// - medical_report/xxx.pdf
  /// - gs://bucket-name/medical_report/xxx.pdf
  String _normalizeStoragePath(String path) {
    if (path.startsWith('gs://')) {
      return path.replaceFirst(RegExp(r'^gs://[^/]+/'), '');
    }
    return path;
  }

  Future<void> _loadPdf() async {
    try {
      final normalizedPath =
          _normalizeStoragePath(widget.storagePath);

      final file =
          await downloadPdfFromFirebase(normalizedPath);

      if (!mounted) return;

      setState(() {
        pdfFile = file;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Report'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Text(
                    'Error: $error',
                    textAlign: TextAlign.center,
                  ),
                )
              : SfPdfViewer.file(pdfFile!),
    );
  }
}
