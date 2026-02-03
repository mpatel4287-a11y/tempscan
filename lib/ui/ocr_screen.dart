import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  File? _selectedImage;
  String _extractedText = '';
  bool _isProcessing = false;
  bool _hasError = false;
  String _errorMessage = '';
  List<String> _detectedLines = [];

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null) {
        setState(() {
          _selectedImage = File(result.files.single.path!);
          _extractedText = '';
          _hasError = false;
          _detectedLines.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<void> _extractText() async {
    if (_selectedImage == null) return;

    setState(() {
      _isProcessing = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final inputImage = InputImage.fromFile(_selectedImage!);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      if (!mounted) return;

      setState(() {
        _extractedText = recognizedText.text;
        _detectedLines = _extractedText.split('\n').where((line) => line.trim().isNotEmpty).toList();
        _isProcessing = false;
      });

      if (_extractedText.isEmpty) {
        setState(() {
          _hasError = true;
          _errorMessage = 'No text detected. Try a clearer image.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _hasError = true;
        _errorMessage = 'Extraction failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('OCR Tool', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_selectedImage != null)
            TextButton(
              onPressed: _pickImage,
              child: const Text('CHANGE', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildImagePreview(),
                  if (_selectedImage != null) ...[
                    const SizedBox(height: 24),
                    _buildExtractButton(),
                  ],
                  if (_extractedText.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _buildExtractedContent(),
                  ],
                  if (_hasError) _buildErrorState(),
                ],
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
        const Text('Extract Text', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Convert images to selectable text instantly.', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
      ],
    );
  }

  Widget _buildImagePreview() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: _selectedImage == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined, size: 48, color: Colors.blueAccent.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    const Text('Select Image', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
                  ],
                )
              : Image.file(_selectedImage!, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _buildExtractButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF43E97B), Color(0xFF38F9D7)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ElevatedButton.icon(
        onPressed: _isProcessing ? null : _extractText,
        icon: _isProcessing
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
            : const Icon(Icons.flash_on_rounded, color: Colors.black),
        label: Text(_isProcessing ? 'SCANNING...' : 'EXTRACT TEXT', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildExtractedContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildStatTag('${_detectedLines.length} Lines'),
            const SizedBox(width: 8),
            _buildStatTag('${_extractedText.length} Chars'),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.copy_rounded, color: Colors.white70),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _extractedText));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
              },
            ),
            IconButton(
              icon: const Icon(Icons.share_rounded, color: Colors.white70),
              onPressed: () => Share.share(_extractedText),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: SelectableText(
            _extractedText,
            style: const TextStyle(color: Colors.white, height: 1.5, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildStatTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildErrorState() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 12),
          Expanded(child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
        ],
      ),
    );
  }
}
