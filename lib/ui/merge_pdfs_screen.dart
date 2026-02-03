// ignore_for_file: prefer_final_fields, deprecated_member_use

import 'dart:io';
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
  final List<File> _selectedPdfs = [];
  bool _isProcessing = false;
  String? _customFileName;
  bool _addWatermark = true;
  String _watermarkText = 'TempScan Secure';

  Future<void> _pickPdfs() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );

      if (result != null) {
        for (final file in result.files) {
          final pdfFile = File(file.path!);
          
          // Check if PDF is password protected early
          try {
            final pdfDoc = await pdfx.PdfDocument.openFile(pdfFile.path);
            await pdfDoc.close();
          } catch (e) {
            final errorMessage = e.toString().toLowerCase();
            final isPasswordError = errorMessage.contains('password') || 
                                   errorMessage.contains('encrypted') || 
                                   errorMessage.contains('11') ||
                                   errorMessage.contains('not authenticated');
            
            if (isPasswordError) {
              final password = await _showPasswordPromptDialog();
              if (password != null) {
                try {
                  final pdfDoc = await pdfx.PdfDocument.openFile(pdfFile.path, password: password);
                  await pdfDoc.close();
                } catch (innerE) {
                  if (mounted) _showError('Incorrect password for ${file.name}');
                  continue; // Skip this file
                }
              } else {
                continue; // User cancelled password prompt for this file
              }
            }
          }

          if (!_selectedPdfs.any((existing) => existing.path == pdfFile.path)) {
            setState(() => _selectedPdfs.add(pdfFile));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<void> _mergePdfs() async {
    if (_selectedPdfs.length < 2) {
      _showError('Select at least 2 PDFs to merge');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final pdf = pw.Document();

      for (final pdfFile in _selectedPdfs) {
        pdfx.PdfDocument? pdfDoc;
        try {
          pdfDoc = await pdfx.PdfDocument.openFile(pdfFile.path);
        } catch (e) {
          final errorMessage = e.toString().toLowerCase();
          final isPasswordError = errorMessage.contains('password') || 
                                 errorMessage.contains('encrypted') || 
                                 errorMessage.contains('11') ||
                                 errorMessage.contains('not authenticated');
          
          if (isPasswordError) {
            final password = await _showPasswordPromptDialog();
            if (password != null) {
              try {
                pdfDoc = await pdfx.PdfDocument.openFile(pdfFile.path, password: password);
              } catch (innerE) {
                rethrow;
              }
            } else {
              setState(() => _isProcessing = false);
              return;
            }
          } else {
            rethrow;
          }
        }
        

        for (int i = 0; i < pdfDoc.pagesCount; i++) {
          final page = await pdfDoc.getPage(i + 1);
          final pageImage = await page.render(
            width: page.width * 2,
            height: page.height * 2,
            format: pdfx.PdfPageImageFormat.png,
          );

          if (pageImage != null) {
            pdf.addPage(
              pw.Page(
                pageFormat: PdfPageFormat(page.width, page.height),
                margin: pw.EdgeInsets.zero,
                build: (context) {
                  return pw.Stack(
                    children: [
                      pw.Center(
                        child: pw.Image(pw.MemoryImage(pageImage.bytes), fit: pw.BoxFit.contain),
                      ),
                      if (_addWatermark)
                        pw.Positioned(
                          bottom: 20,
                          right: 20,
                          child: pw.Opacity(
                            opacity: 0.3,
                            child: pw.Text(
                              _watermarkText,
                              style: pw.TextStyle(
                                fontSize: 14,
                                color: PdfColors.grey700,
                                fontWeight: pw.FontWeight.bold,
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
        await pdfDoc.close();
      }

      final directoryPath = await SettingsService.getOrPickSavePath();
      if (directoryPath == null) {
        if (mounted) setState(() => _isProcessing = false);
        return;
      }

      final fileName = (_customFileName ?? 'Merged').endsWith('.pdf') ? _customFileName! : '${_customFileName ?? 'Merged'}.pdf';
      final filePath = '$directoryPath/$fileName';
      final outputFile = File(filePath);
      
      await outputFile.writeAsBytes(await pdf.save());

      if (!mounted) return;
      setState(() => _isProcessing = false);

      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PdfSuccessScreen(pdfFile: outputFile)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showError('Merge failed: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
  }


  void _showRenameDialog() {
    showDialog(
      context: context,
      builder: (_) => RenameDialog(
        initialName: _customFileName ?? 'Merged_${DateTime.now().millisecondsSinceEpoch}',
        onConfirm: (name) => setState(() => _customFileName = name),
      ),
    );
  }

  void _showWatermarkDialog() {
    showDialog(
      context: context,
      builder: (_) => _WatermarkDialog(
        initialText: _watermarkText,
        isEnabled: _addWatermark,
        onConfirm: (text, enabled) => setState(() {
          _watermarkText = text;
          _addWatermark = enabled;
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Merge PDFs', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_selectedPdfs.isNotEmpty) ...[
            IconButton(icon: const Icon(Icons.edit_note), onPressed: _showRenameDialog),
            IconButton(icon: const Icon(Icons.water_drop_outlined), onPressed: _showWatermarkDialog, color: _addWatermark ? Colors.blueAccent : null),
          ],
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => SettingsService.getOrPickSavePath(forcePick: true)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _selectedPdfs.isEmpty ? _buildEmptyState() : _buildReorderableList(),
          ),
          if (_selectedPdfs.isNotEmpty) _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle),
            child: Icon(Icons.picture_as_pdf_outlined, size: 64, color: Colors.blueAccent.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 24),
          const Text('No PDFs selected', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Select multiple files to merge them into one.', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _pickPdfs,
            icon: const Icon(Icons.add),
            label: const Text('ADD PDFS'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReorderableList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blueAccent, size: 16),
              const SizedBox(width: 8),
              Text('Hold and drag to reorder files', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
              const Spacer(),
              TextButton.icon(onPressed: _pickPdfs, icon: const Icon(Icons.add_circle_outline, size: 16), label: const Text('ADD MORE')),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _selectedPdfs.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final item = _selectedPdfs.removeAt(oldIndex);
                _selectedPdfs.insert(newIndex, item);
              });
            },
            itemBuilder: (context, index) {
              final pdf = _selectedPdfs[index];
              return Container(
                key: Key(pdf.path),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(pdf.path.split('/').last, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text(FileSizeHelper.readable(pdf), style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white24, size: 20), onPressed: () => setState(() => _selectedPdfs.removeAt(index))),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05)))),
      child: Column(
        children: [
          if (_customFileName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  const Icon(Icons.drive_file_rename_outline, color: Colors.white38, size: 16),
                  const SizedBox(width: 8),
                  Text('Output: $_customFileName.pdf', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF845EF7), Color(0xFF5C7CFA)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _mergePdfs,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isProcessing
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('MERGE ${_selectedPdfs.length} DOCUMENTS', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _showPasswordPromptDialog() async {
    String tempPass = '';
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Password Protected', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('A PDF in your selection is encrypted. Enter password to continue.', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 20),
            TextField(
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Password',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (v) => tempPass = v,
              onSubmitted: (v) => Navigator.pop(context, v),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, tempPass), child: const Text('Unlock', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold))),
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

  const _WatermarkDialog({required this.initialText, required this.isEnabled, required this.onConfirm});

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
      backgroundColor: const Color(0xFF1A1A1A),
      title: const Text('Watermark Settings', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: const Text('Add Watermark', style: TextStyle(color: Colors.white)),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          if (_enabled)
            TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Text', labelStyle: TextStyle(color: Colors.white38)),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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

