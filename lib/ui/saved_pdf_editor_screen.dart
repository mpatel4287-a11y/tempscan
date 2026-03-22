import 'dart:io';
import 'package:flutter/material.dart';
import '../temp_storage/temp_image_manager.dart';
import 'advanced_editor_screen.dart';
import 'edit_image_screen.dart';
import '../document_builder/pdf_builder.dart';
import '../services/document_storage_service.dart';
import '../models/document.dart';
import 'pdf_success_screen.dart';
import '../services/automation_service.dart';
import '../models/automation_rule.dart';

class SavedPdfEditorScreen extends StatefulWidget {
  const SavedPdfEditorScreen({super.key});

  @override
  State<SavedPdfEditorScreen> createState() => _SavedPdfEditorScreenState();
}

class _SavedPdfEditorScreenState extends State<SavedPdfEditorScreen> {
  final _manager = TempImageManager();
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _openAdvancedEditor() async {
    final page = _manager.getPage(_currentPage);
    if (page == null) return;
    
    final result = await Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => AdvancedEditorScreen(documentFile: page.file))
    );
    
    if (result != null && result is File && mounted) {
       await _manager.updatePageFile(_currentPage, result);
       setState(() {});
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Page updated with advanced edits')));
    }
  }

  Future<void> _openStandardEditor() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditImageScreen(pageIndex: _currentPage)),
    );

    // If image was deleted inside the standard editor
    if (result == true) {
      if (_manager.pages.isEmpty) {
        if (mounted) Navigator.pop(context);
      } else {
        setState(() {
          // Adjust _currentPage if we deleted the last page
          if (_currentPage >= _manager.pages.length) {
            _currentPage = _manager.pages.length - 1;
            _pageController.jumpToPage(_currentPage);
          }
        });
      }
    } else {
      // Just refresh modifications
      setState(() {});
    }
  }

  Future<void> _savePdf() async {
    if (_manager.pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No pages to save.')));
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final file = await PdfBuilder.createPdf(
        addWatermark: true,
      );

      // Save to DocumentStorageService as a new document
      await DocumentStorageService.instance.initialize();
      ScannedDocument doc = ScannedDocument(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: file.path.split('/').last,
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        filePath: file.path,
        fileSize: await file.length(),
        type: DocumentType.pdf,
        tags: ['Edited'],
      );
      
      await AutomationService.instance.initialize();
      final automatedDoc = await AutomationService.instance.executeRules(
        document: doc,
        trigger: RuleTrigger.afterScan,
      );
      if (automatedDoc != null) {
        doc = automatedDoc;
      }

      await DocumentStorageService.instance.addDocument(doc);

      // Clear temp images after PDF creation
      await TempImageManager().clearAll();

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PdfSuccessScreen(pdfFile: file)),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = _manager.pages;
    
    if (pages.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit PDF')),
        body: const Center(child: Text('No pages found.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Page ${_currentPage + 1} of ${pages.length}'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        itemCount: pages.length,
        itemBuilder: (context, index) {
          final pageData = pages[index];
          return InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: Center(
               child: Stack(
                 alignment: Alignment.center,
                 children: [
                   Transform.rotate(
                     angle: pageData.rotation * 3.14159 / 180,
                     child: Image.file(
                       pageData.file,
                       fit: BoxFit.contain,
                     ),
                   ),
                 ],
               ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          color: Colors.black87,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildControlItem(
                icon: Icons.text_fields_rounded,
                label: 'T-Edit/Translate',
                color: Colors.blueAccent,
                onTap: _openAdvancedEditor,
              ),
              _buildControlItem(
                icon: Icons.edit,
                label: 'Filter/Crop/Sign',
                color: Colors.white,
                onTap: _openStandardEditor,
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _savePdf,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Save PDF', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
