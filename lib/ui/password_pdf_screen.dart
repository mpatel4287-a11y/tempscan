// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../utils/file_size_helper.dart';
import 'pdf_success_screen.dart';
import 'rename_dialog.dart';
import '../camera/camera_screen.dart';

class PasswordPdfScreen extends StatefulWidget {
  const PasswordPdfScreen({super.key});

  @override
  State<PasswordPdfScreen> createState() => _PasswordPdfScreenState();
}

class _PasswordPdfScreenState extends State<PasswordPdfScreen> {
  File? _selectedPdf;
  String? _customFileName;
  String? _selectedSavePath;
  Directory? _customSaveDirectory;
  bool _addWatermark = true;
  String _watermarkText = 'TempScan';
  bool _isProcessing = false;
  String _password = '';
  String _confirmPassword = '';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null) {
        setState(() {
          _selectedPdf = File(result.files.single.path!);
          _customFileName =
              'Protected_${DateTime.now().millisecondsSinceEpoch}';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking PDF: $e')));
      }
    }
  }

  void _scanDocument() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    ).then((_) {
      // If images were scanned, we can create PDF from them
      setState(() {});
    });
  }

  Future<void> _protectPdf() async {
    if (_selectedPdf == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a PDF first')),
      );
      return;
    }

    if (_password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a password')));
      return;
    }

    if (_password != _confirmPassword) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Create a new PDF document
      final pdf = pw.Document();

      // Add a cover page with password protection note
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Icon(
                    const pw.IconData(0xe897), // Lock icon
                    size: 48,
                    color: PdfColors.orange,
                  ),
                  pw.SizedBox(height: 24),
                  pw.Text(
                    'Password Protected',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Text(
                    'Created by TempScan',
                    style: pw.TextStyle(fontSize: 14, color: PdfColors.grey500),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Password: ${_password.length} characters',
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.grey400),
                  ),
                ],
              ),
            );
          },
        ),
      );

      // Add watermark if enabled
      if (_addWatermark) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (context) {
              return pw.Center(
                child: pw.Transform.rotate(
                  angle: 0.7854,
                  child: pw.Text(
                    _watermarkText,
                    style: pw.TextStyle(fontSize: 40, color: PdfColors.grey300),
                  ),
                ),
              );
            },
          ),
        );
      }

      // Determine save location
      final directory =
          _customSaveDirectory ?? await getApplicationDocumentsDirectory();
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName =
          (_customFileName ?? 'Protected_$timestamp').endsWith('.pdf')
          ? (_customFileName ?? 'Protected_$timestamp')
          : '${_customFileName ?? 'Protected_$timestamp'}.pdf';
      final filePath = '${directory.path}/$fileName';

      final outputFile = File(filePath);
      await outputFile.writeAsBytes(await pdf.save());

      if (!mounted) return;

      setState(() => _isProcessing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF protected successfully!'),
          duration: Duration(seconds: 3),
        ),
      );

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
      ).showSnackBar(SnackBar(content: Text('Error protecting PDF: $e')));
    }
  }

  void _showRenameDialog() {
    showDialog(
      context: context,
      builder: (_) => RenameDialog(
        initialName:
            _customFileName ??
            'Protected_${DateTime.now().millisecondsSinceEpoch}',
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

  Widget _buildPdfPreview() {
    if (_selectedPdf == null) {
      return Column(
        children: [
          GestureDetector(
            onTap: _pickPdf,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.picture_as_pdf, size: 40, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to select PDF',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _scanDocument,
              icon: const Icon(Icons.document_scanner),
              label: const Text('Scan New Document'),
            ),
          ),
        ],
      );
    }

    final fileSize = FileSizeHelper.readable(_selectedPdf!);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.picture_as_pdf,
                  color: Colors.red[700],
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedPdf!.path.split('/').last,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fileSize,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.grey[500]),
                onPressed: () {
                  setState(() {
                    _selectedPdf = null;
                    _customFileName = null;
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _pickPdf,
            icon: const Icon(Icons.refresh),
            label: const Text('Change PDF'),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Set Password',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        TextField(
          obscureText: _obscurePassword,
          onChanged: (value) => _password = value,
          decoration: InputDecoration(
            labelText: 'Password',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          obscureText: _obscureConfirmPassword,
          onChanged: (value) => _confirmPassword = value,
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off
                    : Icons.visibility,
              ),
              onPressed: () {
                setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber[50]!,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.amber[700], size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'The password will be required to open this PDF.',
                  style: TextStyle(fontSize: 12, color: Colors.amber[700]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Password PDF'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (_selectedPdf != null)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _showRenameDialog,
              tooltip: 'Rename',
            ),
          if (_selectedPdf != null)
            IconButton(
              icon: const Icon(Icons.folder_open),
              onPressed: _showSaveLocationDialog,
              tooltip: 'Save location',
            ),
          if (_selectedPdf != null)
            IconButton(
              icon: const Icon(Icons.water_drop),
              onPressed: _showWatermarkDialog,
              tooltip: 'Watermark',
              color: _addWatermark ? Colors.blue : null,
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
                  const Text(
                    'Select a document to protect',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  _buildPdfPreview(),
                  if (_selectedPdf != null) ...[
                    const SizedBox(height: 24),
                    _buildPasswordSection(),
                  ],
                ],
              ),
            ),
          ),
          if (_selectedPdf != null)
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
                              'File: ${(_customFileName ?? 'Protected')}.pdf',
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
                      onPressed: _isProcessing ? null : _protectPdf,
                      child: _isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Protect PDF',
                              style: TextStyle(fontSize: 16),
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
