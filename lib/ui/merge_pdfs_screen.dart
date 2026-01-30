// ignore_for_file: prefer_final_fields, deprecated_member_use

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;
import '../utils/file_size_helper.dart';
import '../services/settings_service.dart';
import 'pdf_success_screen.dart';
import 'rename_dialog.dart';

class MergePdfsScreen extends StatefulWidget {
  const MergePdfsScreen({super.key});

  @override
  State<MergePdfsScreen> createState() => _MergePdfsScreenState();
}

class _MergePdfsScreenState extends State<MergePdfsScreen> {
  List<File> _selectedPdfs = [];
  bool _isProcessing = false;
  String? _customFileName;
  String? _selectedSavePath;
  Directory? _customSaveDirectory;
  bool _addWatermark = true;
  String _watermarkText = 'TempScan';

  Future<void> _pickPdfs() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );

      if (result != null) {
        setState(() {
          final newPdfs = result.files
              .map((file) => File(file.path!))
              .where(
                (pdf) =>
                    !_selectedPdfs.any((existing) => existing.path == pdf.path),
              )
              .toList();
          _selectedPdfs.addAll(newPdfs);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking PDFs: $e')));
      }
    }
  }

  Future<void> _mergePdfs() async {
    if (_selectedPdfs.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 2 PDFs to merge')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final pdf = pw.Document();

      // Load and copy pages from each PDF using pdfx for reading
      for (final pdfFile in _selectedPdfs) {
        final pdfDoc = await pdfx.PdfDocument.openFile(pdfFile.path);

        // Copy all pages from the loaded PDF
        for (int i = 0; i < pdfDoc.pagesCount; i++) {
          final page = await pdfDoc.getPage(i + 1);
          final pageImage = await page.render(
            width: page.width,
            height: page.height,
            format: pdfx.PdfPageImageFormat.png,
          );

          if (pageImage != null) {
            pdf.addPage(
              pw.Page(
                pageFormat: PdfPageFormat(page.width, page.height),
                build: (context) {
                  return pw.Center(
                    child: pw.Image(
                      pw.MemoryImage(pageImage.bytes),
                      fit: pw.BoxFit.contain,
                    ),
                  );
                },
              ),
            );
          }

          // Close the page to free resources
          await page.close();
        }

        // Close the document to free resources
        await pdfDoc.close();
      }

      // Determine save location using SettingsService
      final directoryPath = await SettingsService.getOrPickSavePath();
      if (directoryPath == null) {
        if (mounted) setState(() => _isProcessing = false);
        return;
      }
      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = (_customFileName ?? 'Merged_$timestamp').endsWith('.pdf')
          ? (_customFileName ?? 'Merged_$timestamp')
          : '${_customFileName ?? 'Merged_$timestamp'}.pdf';
      final filePath = '${directory.path}/$fileName';

      final outputFile = File(filePath);
      final pdfBytes = await pdf.save();

      // Add watermark if enabled
      if (_addWatermark) {
        final watermarkedBytes = await _addWatermarkToPdf(
          pdfBytes,
          _watermarkText,
        );
        await outputFile.writeAsBytes(watermarkedBytes);
      } else {
        await outputFile.writeAsBytes(pdfBytes);
      }

      if (!mounted) return;

      setState(() => _isProcessing = false);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PdfSuccessScreen(pdfFile: outputFile),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error merging PDFs: $e')));
    }
  }

  Future<Uint8List> _addWatermarkToPdf(
    Uint8List pdfBytes,
    String watermark,
  ) async {
    // For watermark, we use the pdf package's built-in functionality
    // to create a new PDF with the watermark overlay
    final outputDoc = pw.Document();

    // Use pdfx to read the original PDF and render pages with watermark
    final inputDoc = await pdfx.PdfDocument.openData(pdfBytes);

    for (int i = 0; i < inputDoc.pagesCount; i++) {
      final page = await inputDoc.getPage(i + 1);
      final pageImage = await page.render(
        width: page.width,
        height: page.height,
        format: pdfx.PdfPageImageFormat.png,
      );

      if (pageImage != null) {
        outputDoc.addPage(
          pw.Page(
            margin: const pw.EdgeInsets.all(40),
            orientation: pw.PageOrientation.portrait,
            pageFormat: PdfPageFormat(page.width, page.height),
            build: (context) {
              return pw.Stack(
                children: [
                  pw.Center(
                    child: pw.Image(
                      pw.MemoryImage(pageImage.bytes),
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                  pw.Positioned.fill(
                    child: pw.Opacity(
                      opacity: 0.3,
                      child: pw.Transform.rotate(
                        angle: 0.7854,
                        child: pw.Center(
                          child: pw.Text(
                            watermark,
                            style: pw.TextStyle(
                              fontSize: 20,
                              color: PdfColors.grey,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }

      await page.close();
    }

    await inputDoc.close();

    return outputDoc.save();
  }

  void _removePdf(int index) {
    setState(() {
      _selectedPdfs.removeAt(index);
    });
  }

  void _reorderPdfs(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _selectedPdfs.removeAt(oldIndex);
      _selectedPdfs.insert(newIndex, item);
    });
  }

  void _showRenameDialog() {
    showDialog(
      context: context,
      builder: (_) => RenameDialog(
        initialName:
            _customFileName ??
            'Merged_${DateTime.now().millisecondsSinceEpoch}',
        onConfirm: (name) {
          setState(() {
            _customFileName = name;
          });
        },
      ),
    );
  }

  void _showSaveLocationDialog() {
    showDialog(
      context: context,
      builder: (_) => _SaveLocationDialog(
        currentPath: _selectedSavePath,
        customDirectory: _customSaveDirectory,
        onConfirm: (path, directory) {
          setState(() {
            _selectedSavePath = path;
            _customSaveDirectory = directory;
          });
        },
      ),
    );
  }

  void _showWatermarkDialog() {
    showDialog(
      context: context,
      builder: (_) => _WatermarkDialog(
        initialText: _watermarkText,
        isEnabled: _addWatermark,
        onConfirm: (text, enabled) {
          setState(() {
            _watermarkText = text;
            _addWatermark = enabled;
          });
        },
      ),
    );
  }

  Widget _buildPdfList() {
    if (_selectedPdfs.isEmpty) {
      return GestureDetector(
        onTap: _pickPdfs,
        child: Container(
          height: 150,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.picture_as_pdf, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                'Tap to select PDFs',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Selected PDFs (${_selectedPdfs.length})',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            TextButton(onPressed: _pickPdfs, child: const Text('Add More')),
          ],
        ),
        const SizedBox(height: 8),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _selectedPdfs.length,
          onReorder: _reorderPdfs,
          itemBuilder: (context, index) {
            final pdf = _selectedPdfs[index];
            final fileSize = FileSizeHelper.readable(pdf);

            return Container(
              key: Key(pdf.path),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.picture_as_pdf, color: Colors.red[700]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${index + 1}. ${pdf.path.split('/').last}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          fileSize,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.grey[500],
                      size: 20,
                    ),
                    onPressed: () => _removePdf(index),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Merge PDFs'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (_selectedPdfs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _showRenameDialog,
              tooltip: 'Rename',
            ),
          if (_selectedPdfs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.folder_open),
              onPressed: _showSaveLocationDialog,
              tooltip: 'Save location',
            ),
          if (_selectedPdfs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.water_drop),
              onPressed: _showWatermarkDialog,
              tooltip: 'Watermark',
              color: _addWatermark ? Colors.blue : null,
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final newPath = await SettingsService.getOrPickSavePath(forcePick: true);
              if (newPath != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Default save location updated to: $newPath')),
                );
              }
            },
            tooltip: 'Change Default Save Location',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPdfList(),
                  const SizedBox(height: 24),
                  if (_selectedPdfs.isNotEmpty) ...[
                    const Text(
                      'Tips',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50]!,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: Colors.blue[700]!,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Drag and drop to reorder PDFs. The order shown here will be the order in the merged document.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_selectedPdfs.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                children: [
                  if (_customFileName != null || _selectedSavePath != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.description, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'File: ${(_customFileName ?? 'Merged')}.pdf',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          if (_selectedSavePath != null)
                            Text(
                              'Save: $_selectedSavePath',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _mergePdfs,
                      child: _isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _selectedPdfs.length < 2
                                  ? 'Select at least 2 PDFs'
                                  : 'Merge ${_selectedPdfs.length} PDFs',
                              style: const TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/* ---------------- Watermark Dialog ---------------- */

class _WatermarkDialog extends StatefulWidget {
  final String initialText;
  final bool isEnabled;
  final Function(String text, bool enabled) onConfirm;

  const _WatermarkDialog({
    required this.initialText,
    required this.isEnabled,
    required this.onConfirm,
  });

  @override
  State<_WatermarkDialog> createState() => __WatermarkDialogState();
}

class __WatermarkDialogState extends State<_WatermarkDialog> {
  late TextEditingController _controller;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _enabled = widget.isEnabled;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Watermark Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Checkbox(
                value: _enabled,
                onChanged: (value) {
                  setState(() {
                    _enabled = value ?? true;
                  });
                },
              ),
              const Expanded(child: Text('Add watermark')),
            ],
          ),
          const SizedBox(height: 8),
          if (_enabled)
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Watermark text',
                border: OutlineInputBorder(),
              ),
              maxLength: 30,
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onConfirm(_controller.text.trim(), _enabled);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/* ---------------- Save Location Dialog ---------------- */

class _SaveLocationDialog extends StatefulWidget {
  final String? currentPath;
  final Directory? customDirectory;
  final Function(String path, Directory? directory) onConfirm;

  const _SaveLocationDialog({
    this.currentPath,
    this.customDirectory,
    required this.onConfirm,
  });

  @override
  State<_SaveLocationDialog> createState() => __SaveLocationDialogState();
}

class __SaveLocationDialogState extends State<_SaveLocationDialog> {
  String _selectedPath = 'Documents';
  bool _useCustomLocation = false;
  Directory? _customSelectedDirectory;

  @override
  void initState() {
    super.initState();
    _selectedPath = widget.currentPath ?? 'Documents';
    _useCustomLocation = widget.customDirectory != null;
    _customSelectedDirectory = widget.customDirectory;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save PDF Location'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Choose where to save your PDF:',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          _locationOption(
            icon: Icons.folder,
            label: 'Documents',
            subtitle: 'Standard documents folder',
            isSelected: _selectedPath == 'Documents' && !_useCustomLocation,
            onTap: () {
              setState(() {
                _selectedPath = 'Documents';
                _useCustomLocation = false;
              });
            },
          ),
          const SizedBox(height: 8),
          _locationOption(
            icon: Icons.download,
            label: 'Downloads',
            subtitle: 'Downloads folder',
            isSelected: _selectedPath == 'Downloads' && !_useCustomLocation,
            onTap: () {
              setState(() {
                _selectedPath = 'Downloads';
                _useCustomLocation = false;
              });
            },
          ),
          const SizedBox(height: 8),
          _locationOption(
            icon: Icons.folder_special,
            label: 'TempScan',
            subtitle: 'App-specific folder',
            isSelected: _selectedPath == 'TempScan' && !_useCustomLocation,
            onTap: () {
              setState(() {
                _selectedPath = 'TempScan';
                _useCustomLocation = false;
              });
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: _useCustomLocation,
                onChanged: (value) async {
                  if (value == true) {
                    await _pickCustomFolder();
                  } else {
                    setState(() {
                      _useCustomLocation = false;
                    });
                  }
                },
              ),
              const Expanded(child: Text('Choose custom folder')),
              if (_useCustomLocation && _customSelectedDirectory != null)
                Text(
                  _customSelectedDirectory!.path.split('/').last,
                  style: const TextStyle(fontSize: 11, color: Colors.blue),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_useCustomLocation && _customSelectedDirectory == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please select a folder first')),
              );
              return;
            }

            widget.onConfirm(_selectedPath, _customSelectedDirectory);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _pickCustomFolder() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select folder to save PDF',
      );

      if (result != null) {
        setState(() {
          _useCustomLocation = true;
          _selectedPath = 'Custom';
          _customSelectedDirectory = Directory(result);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error selecting folder: $e')));
    }
  }

  Widget _locationOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: isSelected ? Colors.blue : Colors.black26),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.blue : Colors.black54),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isSelected ? Colors.blue : Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.blue, size: 20),
          ],
        ),
      ),
    );
  }
}
