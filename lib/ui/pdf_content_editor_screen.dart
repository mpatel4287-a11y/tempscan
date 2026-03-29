import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/pdf_extraction_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;
import 'pdf_success_screen.dart';
import '../services/document_storage_service.dart';
import '../models/document.dart';
import 'package:path_provider/path_provider.dart';

class PdfContentEditorScreen extends StatefulWidget {
  final String filePath;

  const PdfContentEditorScreen({super.key, required this.filePath});

  @override
  State<PdfContentEditorScreen> createState() => _PdfContentEditorScreenState();
}

class _PdfContentEditorScreenState extends State<PdfContentEditorScreen> {
  List<PdfElement> _elements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    final elements = await PdfExtractionService.extractContent(widget.filePath);
    setState(() {
      _elements = elements;
      _isLoading = false;
    });
  }

  Future<void> _savePdf() async {
    setState(() => _isLoading = true);
    
    try {
      final sfpdf.PdfDocument document = sfpdf.PdfDocument();
      sfpdf.PdfPage? currentPage;
      double yOffset = 20;

      for (final element in _elements) {
        if (currentPage == null || yOffset > 700) {
          currentPage = document.pages.add();
          yOffset = 20;
        }

        if (element.type == PdfElementType.text) {
          currentPage.graphics.drawString(
            element.text,
            sfpdf.PdfStandardFont(sfpdf.PdfFontFamily.helvetica, 12),
            bounds: Rect.fromLTWH(20, yOffset, 500, 20),
          );
          yOffset += 20;
        } else if (element.type == PdfElementType.image && element.imageBytes != null) {
          final sfpdf.PdfBitmap image = sfpdf.PdfBitmap(element.imageBytes!);
          currentPage.graphics.drawImage(
            image,
            Rect.fromLTWH(20, yOffset, 200, 150),
          );
          yOffset += 160;
        }
      }

      final List<int> bytes = document.saveSync();
      document.dispose();

      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/Edited_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(path);
      await file.writeAsBytes(bytes);

      // Save to storage
      await DocumentStorageService.instance.initialize();
      final doc = ScannedDocument(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: file.path.split('/').last,
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        filePath: file.path,
        fileSize: bytes.length,
        type: DocumentType.pdf,
        tags: ['Edited'],
      );
      await DocumentStorageService.instance.addDocument(doc);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => PdfSuccessScreen(pdfFile: file)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Edit PDF Content'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _savePdf,
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _elements.length,
              itemBuilder: (context, index) {
                final element = _elements[index];
                if (element.type == PdfElementType.text) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: TextFormField(
                      initialValue: element.text,
                      style: const TextStyle(color: Colors.white),
                      maxLines: null,
                      onChanged: (value) => element.text = value,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  );
                } else {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            element.imageBytes!,
                            fit: BoxFit.contain,
                          ),
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _elements.removeAt(index);
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
    );
  }
}
