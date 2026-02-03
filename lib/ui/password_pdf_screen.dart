// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;
import '../utils/file_size_helper.dart';
import '../services/settings_service.dart';
import '../services/signature_service.dart'; // Added
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
  bool _addWatermark = false; // Changed default
  String _watermarkText = 'TempScan'; // Changed default
  bool _isGenerating = false; // Renamed from _isProcessing

  File? _selectedSignature; // Added
  ui.Offset _signaturePosition = const ui.Offset(0.7, 0.8); // Added
  bool _showSignaturePicker = false; // Added

  String _password = '';
  String _confirmPassword = '';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Added for password section
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        
        // Check if PDF is password protected early
        try {
          final pdfDoc = await pdfx.PdfDocument.openFile(file.path);
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
                final pdfDoc = await pdfx.PdfDocument.openFile(file.path, password: password);
                await pdfDoc.close();
              } catch (innerE) {
                if (mounted) _showError('Incorrect password');
                return;
              }
            } else {
              return; // User cancelled password prompt
            }
          }
        }

        setState(() {
          _selectedPdf = file;
          _customFileName = 'Protected_${DateTime.now().millisecondsSinceEpoch}';
        });
      }
    } catch (e) {
      if (mounted) {
        _showError('Error picking PDF: $e');
      }
    }
  }

  void _scanDocument() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraScreen())).then((_) => setState(() {}));
  }

  Future<void> _protectPdf() async {
    if (_selectedPdf == null) {
      _showError('Please select a PDF first');
      return;
    }

    if (_password.isEmpty) {
      _showError('Please enter a password');
      return;
    }

    if (_password != _confirmPassword) {
      _showError('Passwords do not match');
      return;
    }

    setState(() => _isGenerating = true);

    try {
      // Open original PDF (handling password-protected inputs too).
      pdfx.PdfDocument? pdfDoc;
      try {
        pdfDoc = await pdfx.PdfDocument.openFile(_selectedPdf!.path);
      } catch (e) {
        // If it's a password error, prompt the user
        final errorMessage = e.toString().toLowerCase();
        if (errorMessage.contains('password') || errorMessage.contains('encrypted') || errorMessage.contains('11')) {
          final password = await _showPasswordPromptDialog();
          if (password != null) {
            try {
              pdfDoc = await pdfx.PdfDocument.openFile(_selectedPdf!.path, password: password);
            } catch (innerE) {
              rethrow;
            }
          } else {
            setState(() => _isGenerating = false);
            return;
          }
        } else {
          rethrow;
        }
      }

      

      // Pre-load signature bytes if selected
      Uint8List? sigBytes;
      if (_selectedSignature != null) {
        sigBytes = await _selectedSignature!.readAsBytes();
      }

      // Build encrypted PDF with Syncfusion.
      final secureDoc = sfpdf.PdfDocument();

      for (int i = 0; i < pdfDoc.pagesCount; i++) {
        final page = await pdfDoc.getPage(i + 1);
        final pageImage = await page.render(
          width: page.width * 2, // Better quality
          height: page.height * 2,
          format: pdfx.PdfPageImageFormat.png,
        );

        if (pageImage != null) {
          final sfPage = secureDoc.pages.add();
          final pageSize = sfPage.getClientSize();
          final img = sfpdf.PdfBitmap(pageImage.bytes);

          // Draw original page content as bitmap.
          sfPage.graphics.drawImage(
            img,
            ui.Rect.fromLTWH(0, 0, pageSize.width, pageSize.height),
          );

          // Optional watermark.
          if (_addWatermark && _watermarkText.isNotEmpty) {
            final fmt = sfpdf.PdfStringFormat()
              ..alignment = sfpdf.PdfTextAlignment.right
              ..lineAlignment = sfpdf.PdfVerticalAlignment.bottom;

            sfPage.graphics.drawString(
              _watermarkText,
              sfpdf.PdfStandardFont(sfpdf.PdfFontFamily.helvetica, 12),
              bounds: ui.Rect.fromLTWH(0, 0, pageSize.width - 20, pageSize.height - 20),
              brush: sfpdf.PdfSolidBrush(sfpdf.PdfColor(120, 120, 120)),
              format: fmt,
            );
          }

          // Optional signature image.
          if (_selectedSignature != null && sigBytes != null) {
            final sigImg = sfpdf.PdfBitmap(sigBytes);
            const sigW = 80.0;
            const sigH = 50.0;
            final sigX = _signaturePosition.dx * (pageSize.width - sigW);
            final sigY = _signaturePosition.dy * (pageSize.height - sigH);

            sfPage.graphics.drawImage(
              sigImg,
              ui.Rect.fromLTWH(sigX, sigY, sigW, sigH),
            );
          }
        }

        await page.close();
      }
      await pdfDoc.close();

      // Apply password protection.
      secureDoc.security.userPassword = _password;
      secureDoc.security.ownerPassword = _password;

      final directoryPath = await SettingsService.getOrPickSavePath();
      if (directoryPath == null) {
        if (mounted) setState(() => _isGenerating = false);
        return;
      }

      final fileName = (_customFileName ?? 'Protected').endsWith('.pdf') ? _customFileName! : '${_customFileName ?? 'Protected'}.pdf';
      final filePath = '$directoryPath/$fileName';
      final outputFile = File(filePath);

      final bytes = secureDoc.saveSync();
      secureDoc.dispose();
      await outputFile.writeAsBytes(bytes);

      if (!mounted) return;
      setState(() => _isGenerating = false);

      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PdfSuccessScreen(pdfFile: outputFile)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      _showError('Error protecting PDF: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
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
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 2, style: BorderStyle.solid),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline, size: 48, color: Colors.blueAccent.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const Text('Select PDF to Protect', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('OR', style: TextStyle(color: Colors.white24, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _scanDocument,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Scan New Document'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.picture_as_pdf, color: Colors.blueAccent, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_selectedPdf!.path.split('/').last, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(FileSizeHelper.readable(_selectedPdf!), style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.close, color: Colors.white38), onPressed: () => setState(() => _selectedPdf = null)),
        ],
      ),
    );
  }

  Widget _buildPasswordSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Set Protection Password', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Encryption Password',
          hint: 'Enter strong password',
          icon: Icons.lock_outline,
          obscure: _obscurePassword,
          onChanged: (v) => _password = v,
          onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Confirm Password',
          hint: 'Repeat password',
          icon: Icons.lock_person_outlined,
          obscure: _obscureConfirmPassword,
          onChanged: (v) => _confirmPassword = v,
          onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.orangeAccent.withOpacity(0.1))),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.orangeAccent, size: 20),
              const SizedBox(width: 12),
              const Expanded(child: Text('This password will be required every time the PDF is opened.', style: TextStyle(color: Colors.orangeAccent, fontSize: 12))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({required String label, required String hint, required IconData icon, required bool obscure, required Function(String) onChanged, required VoidCallback onToggle}) {
    return TextField(
      obscureText: obscure,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white12),
        prefixIcon: Icon(icon, color: Colors.white38),
        suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white38), onPressed: onToggle),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.blueAccent)),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05)))),
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
                gradient: const LinearGradient(colors: [Color(0xFFFA709A), Color(0xFFFEE140)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _protectPdf, // Changed from _isProcessing
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isGenerating // Changed from _isProcessing
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('ENCRYPT & SAVE PDF', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Lock your documents', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Add protection to your PDF files instantly.', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
      ],
    );
  }

  Widget _buildSignatureSetup() {
    if (_selectedSignature == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        const Text('Signature Position', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
          child: Column(
            children: [
              Row(
                children: [
                  Container(width: 60, height: 40, color: Colors.white, child: Image.file(_selectedSignature!, fit: BoxFit.contain)),
                  const SizedBox(width: 16),
                  const Expanded(child: Text('Position signature by dragging sliders below', style: TextStyle(color: Colors.white70, fontSize: 12))),
                  IconButton(icon: const Icon(Icons.close, color: Colors.redAccent, size: 20), onPressed: () => setState(() => _selectedSignature = null)),
                ],
              ),
              const SizedBox(height: 16),
              _buildSlider('Horizontal', _signaturePosition.dx, (v) => setState(() => _signaturePosition = ui.Offset(v, _signaturePosition.dy))),
              _buildSlider('Vertical', _signaturePosition.dy, (v) => setState(() => _signaturePosition = ui.Offset(_signaturePosition.dx, v))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSlider(String label, double val, ValueChanged<double> onCh) {
    return Row(
      children: [
        SizedBox(width: 70, child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11))),
        Expanded(child: Slider(value: val, onChanged: onCh, activeColor: Colors.blueAccent, inactiveColor: Colors.white10)),
      ],
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
            const Text('This PDF is encrypted. Enter password to continue.', style: TextStyle(color: Colors.white70, fontSize: 14)),
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

  void _showSignatureSelection() {
    setState(() => _showSignaturePicker = true);
  }

  Widget _buildSignaturePickerOverlay() {
    return Positioned.fill( // Changed to Positioned.fill to cover the whole screen
      child: Container(
        color: Colors.black87,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white10)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Select Signature', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => setState(() => _showSignaturePicker = false)),
                  ],
                ),
                const SizedBox(height: 16),
                FutureBuilder<List<File>>(
                  future: SignatureService.getSavedSignatures(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Padding(padding: EdgeInsets.symmetric(vertical: 32), child: Text('No saved signatures found', style: TextStyle(color: Colors.white38)));
                    }
                    return SizedBox(
                      height: 200,
                      child: ListView.builder(
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          final file = snapshot.data![index];
                          return InkWell(
                            onTap: () => setState(() {
                              _selectedSignature = file;
                              _showSignaturePicker = false;
                            }),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                children: [
                                  Container(width: 60, height: 40, color: Colors.white, child: Image.file(file, fit: BoxFit.contain)),
                                  const SizedBox(width: 16),
                                  const Text('Signature', style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Secure PDF', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_selectedPdf != null) ...[
            IconButton(icon: const Icon(Icons.edit_note), onPressed: _showRenameDialog, tooltip: 'Rename'),
            IconButton(icon: const Icon(Icons.water_drop_outlined), onPressed: _showWatermarkDialog, color: _addWatermark ? Colors.blueAccent : null),
            IconButton(icon: const Icon(Icons.history_edu_rounded), onPressed: _showSignatureSelection, color: _selectedSignature != null ? Colors.blueAccent : null), // Added
          ],
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async => await SettingsService.getOrPickSavePath(forcePick: true),
          ),
        ],
      ),
      body: Stack( // Changed to Stack to allow overlay
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 32),
                      _buildPdfPreview(),
                      if (_selectedPdf != null) ...[
                        const SizedBox(height: 32),
                        _buildPasswordSection(),
                        if (_selectedSignature != null) _buildSignatureSetup(), // Added
                      ],
                    ],
                  ),
                ),
              ),
              if (_selectedPdf != null) _buildBottomBar(),
            ],
          ),
          if (_showSignaturePicker) _buildSignaturePickerOverlay(), // Added
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
      backgroundColor: const Color(0xFF1A1A1A),
      title: const Text('Watermark Settings', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: const Text('Add Watermark', style: TextStyle(color: Colors.white)),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
            activeColor: Colors.blueAccent,
            tileColor: Colors.white.withOpacity(0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          const SizedBox(height: 16),
          if (_enabled)
            TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Watermark text',
                labelStyle: const TextStyle(color: Colors.white38),
                hintStyle: const TextStyle(color: Colors.white12),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent)),
              ),
              maxLength: 30,
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onConfirm(_controller.text.trim(), _enabled);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

