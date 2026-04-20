import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdfx/pdfx.dart';
import '../services/xlsx_reader_service.dart';

class MultiFileReaderScreen extends StatefulWidget {
  final File? initialFile;
  const MultiFileReaderScreen({super.key, this.initialFile});

  @override
  State<MultiFileReaderScreen> createState() => _MultiFileReaderScreenState();
}

class _MultiFileReaderScreenState extends State<MultiFileReaderScreen> {
  File? _selectedFile;
  bool _isPdf = false;
  bool _isImage = false;
  bool _isText = false;
  bool _isExcel = false;
  String? _textContent;
  List<List<String>> _excelData = [];
  PdfController? _pdfController;

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      _processFile(widget.initialFile!);
    }
  }

  void _processFile(File file) async {
    final path = file.path.toLowerCase();
    final ext = path.split('.').last.toLowerCase();
    
    // Clear previous state
    _pdfController?.dispose();
    _pdfController = null;
    _textContent = null;
    _excelData = [];

    final isPdf = ext == 'pdf';
    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
    final isText = ['txt', 'csv', 'sh', 'log', 'bat', 'py', 'js', 'dart', 'html', 'json', 'yaml', 'xml', 'md', 'sql', 'ini', 'conf'].contains(ext);
    final isExcel = ['xlsx', 'xls'].contains(ext);

    if (isPdf) {
      _pdfController = PdfController(
        document: PdfDocument.openFile(file.path),
      );
    } else if (isText) {
      try {
        _textContent = await file.readAsString();
      } catch (e) {
        _textContent = 'Could not read file as text: $e';
      }
    } else if (isExcel) {
      try {
        _excelData = await XlsxReaderService.instance.readXlsx(file);
      } catch (e) {
        _excelData = [['Error reading Excel: $e']];
      }
    }

    setState(() {
      _selectedFile = file;
      _isPdf = isPdf;
      _isImage = isImage;
      _isText = isText;
      _isExcel = isExcel;
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
    );
    if (result != null && result.files.single.path != null) {
      _processFile(File(result.files.single.path!));
    }
  }

  void _openSystemFile(String path) {
    OpenFilex.open(path);
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Multi-File Reader', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_selectedFile != null)
            IconButton(
              icon: const Icon(Icons.open_in_new, color: Colors.blueAccent),
              onPressed: () => _openSystemFile(_selectedFile!.path),
            ),
        ],
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (_selectedFile == null)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.file_open_rounded, size: 64, color: Colors.blueAccent),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Universal Multi-File Reader',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Open documents from Linux, Windows, or Mobile storage.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, fontSize: 14),
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.add),
                      label: const Text('Select a File'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              )
            else
              Expanded(
                child: Column(
                  children: [
                    // Header info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isPdf ? Icons.picture_as_pdf : (_isImage ? Icons.image : Icons.insert_drive_file),
                            color: Colors.blueAccent,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedFile!.path.split('/').last,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed: _pickFile,
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Content Preview
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: _buildPreview(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_isPdf && _pdfController != null) {
      return PdfView(controller: _pdfController!);
    } else if (_isImage) {
      return InteractiveViewer(
        child: Image.file(_selectedFile!),
      );
    } else if (_isText && _textContent != null) {
      return Container(
        color: const Color(0xFF1A1A1A),
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: SelectableText(
            _textContent!,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      );
    } else if (_isExcel && _excelData.isNotEmpty) {
      return _buildExcelGrid();
    } else {
      // PROPER METADATA VIEW for Binary/Fallback
      return _buildMetadataView();
    }
  }

  String _getColLabel(int index) {
    String label = '';
    int n = index + 1;
    while (n > 0) {
      int m = (n - 1) % 26;
      label = String.fromCharCode(65 + m) + label;
      n = (n - m) ~/ 26;
    }
    return label;
  }

  Widget _buildExcelGrid() {
    if (_excelData.isEmpty) return const SizedBox();

    return Container(
      color: const Color(0xFF1A1A1A),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 24,
            horizontalMargin: 12,
            border: TableBorder.all(color: Colors.white10),
            headingRowHeight: 40,
            dataRowMinHeight: 32,
            dataRowMaxHeight: 48,
            headingRowColor: WidgetStateProperty.all(Colors.blueAccent),
            columns: [
              // Row Index Column Header
              const DataColumn(label: SizedBox(width: 30, child: Center(child: Text('#', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))))),
              // Data Column Headers (A, B, C...)
              ...List.generate(
                _excelData[0].length,
                (i) => DataColumn(
                  label: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(_getColLabel(i), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ),
            ],
            rows: List.generate(_excelData.length, (rowIndex) {
              final row = _excelData[rowIndex];
              return DataRow(
                cells: [
                  // Row Index Cell
                  DataCell(
                    Container(
                      width: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.1),
                        border: const Border(right: BorderSide(color: Colors.white10)),
                      ),
                      child: Text('${rowIndex + 1}', style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  // Data Cells
                  ...row.map((cell) => DataCell(
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(cell, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        ),
                      )),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataView() {
    final fileName = _selectedFile!.path.split('/').last;
    final sizeInBytes = _selectedFile!.lengthSync();
    final sizeKb = (sizeInBytes / 1024).toStringAsFixed(2);
    final lastMod = _selectedFile!.lastModifiedSync();
    final extension = fileName.contains('.') ? fileName.split('.').last.toUpperCase() : 'UNKNOWN';

    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                extension == 'XLSX' || extension == 'XLS' ? Icons.table_chart : Icons.insert_drive_file_rounded,
                size: 48,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              extension,
              style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 2),
            ),
            const SizedBox(height: 12),
            Text(
              fileName,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '$sizeKb KB • ${lastMod.day}/${lastMod.month}/${lastMod.year}',
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 32),
            const Text(
              'This format is supported for system viewing.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _openSystemFile(_selectedFile!.path),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open with External App'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white10,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
