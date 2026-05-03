import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:csv/csv.dart' as csv_parser;

const bool _debugLogging = !bool.fromEnvironment('dart.vm.product') && !bool.fromEnvironment('dart.vm.profile');

void debugLog(String msg) {
  if (_debugLogging) {
    debugPrint('[BAGO] $msg');
  }
}

// Document Viewer Page - handles PDF, Office docs, and CSV
class DocumentViewerPage extends StatefulWidget {
  final String title;
  final Uint8List fileBytes;
  final String fileType;

  const DocumentViewerPage({
    Key? key,
    required this.title,
    required this.fileBytes,
    required this.fileType,
  }) : super(key: key);

  @override
  State<DocumentViewerPage> createState() => _DocumentViewerPageState();
}

class _DocumentViewerPageState extends State<DocumentViewerPage> {
  PdfController? _pdfController;
  List<List<dynamic>>? _csvData;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _loadDocument() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ext = widget.fileType.toLowerCase();
      
      if (ext == 'pdf') {
        // Load PDF
        _pdfController = PdfController(
          document: PdfDocument.openData(widget.fileBytes),
        );
      } else if (ext == 'csv') {
        // Parse CSV
        final csvString = utf8.decode(widget.fileBytes);
        final csvTable = const csv_parser.CsvToListConverter().convert(csvString);
        _csvData = csvTable;
      }
      
      setState(() => _loading = false);
    } catch (e) {
      debugLog('[DocumentViewer] Error loading document: $e');
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = widget.fileType.toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        backgroundColor: const Color(0xFF228B22),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        const Text('Failed to load document', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                )
              : _buildViewer(ext),
    );
  }

  Widget _buildViewer(String ext) {
    if (ext == 'pdf' && _pdfController != null) {
      return PdfView(controller: _pdfController!);
    } else if (ext == 'csv' && _csvData != null) {
      return _buildCsvViewer();
    } else if (['docx', 'doc', 'xlsx', 'xls'].contains(ext)) {
      return _buildOfficeViewer();
    } else {
      return const Center(child: Text('Unsupported file type'));
    }
  }

  Widget _buildCsvViewer() {
    if (_csvData == null || _csvData!.isEmpty) {
      return const Center(child: Text('No data in CSV'));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: DataTable(
            border: TableBorder.all(color: Colors.grey[300]!),
            headingRowColor: WidgetStateProperty.all(const Color(0xFF228B22).withOpacity(0.1)),
            columns: _csvData!.first
                .map((cell) => DataColumn(
                      label: Text(
                        cell.toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ))
                .toList(),
            rows: _csvData!
                .skip(1)
                .map(
                  (row) => DataRow(
                    cells: row
                        .map((cell) => DataCell(Text(cell.toString())))
                        .toList(),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildOfficeViewer() {
    // Use Google Docs Viewer for Office documents
    final base64String = base64Encode(widget.fileBytes);
    final dataUrl = 'data:application/${widget.fileType};base64,$base64String';
    final encodedUrl = Uri.encodeComponent(dataUrl);
    final viewerUrl = 'https://docs.google.com/viewer?url=$encodedUrl&embedded=true';

    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(viewerUrl)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        useOnDownloadStart: true,
        allowFileAccess: true,
      ),
      onLoadStart: (controller, url) {
        debugLog('[DocumentViewer] Loading Office doc in Google Viewer');
      },
      onLoadError: (controller, url, code, message) {
        debugLog('[DocumentViewer] Load error: $message');
        if (mounted) {
          setState(() {
            _error = 'Cannot load document viewer. This file type may not be supported online.';
          });
        }
      },
      onConsoleMessage: (controller, consoleMessage) {
        debugLog('[DocumentViewer] Console: ${consoleMessage.message}');
      },
    );
  }
}
