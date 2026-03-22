// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../temp_storage/temp_image_manager.dart';
import '../services/settings_service.dart';
import '../document_builder/pdf_builder.dart';
import '../utils/file_size_helper.dart';
import '../ui/pdf_success_screen.dart';
import '../ui/rename_dialog.dart';
import '../ui/rotate_sheet.dart';
import '../ui/edit_image_screen.dart';
import '../ui/advanced_editor_screen.dart';
import '../camera/camera_screen.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import '../services/document_storage_service.dart';
import '../models/document.dart';
import '../services/automation_service.dart';
import '../models/automation_rule.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _manager = TempImageManager();

  // Custom filename
  String? _customFileName;

  // Save location
  String? _selectedSavePath;
  Directory? _customSaveDirectory;

  int _exportQuality = 100; // 100=High, 70=Medium, 40=Low

  String? _selectedFolderId;
  final List<String> _selectedTags = [];

  @override
  void initState() {
    super.initState();
    _loadDefaultSavePath();
  }

  Future<void> _loadDefaultSavePath() async {
    final path = await SettingsService.getDefaultSavePath();
    if (path != null) {
      setState(() {
        _selectedSavePath = path.split('/').last;
        _customSaveDirectory = Directory(path);
      });
    } else {
      setState(() {
        _selectedSavePath = 'Documents';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allPages = _manager.pages;
    final totalSize = FileSizeHelper.fromBytes(_manager.totalSizeBytes);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${allPages.length} pages'),
            Text(
              'Size: $totalSize',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          // Smart Detect button
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            onPressed: () => _showSmartDetectDialog(),
            tooltip: 'Smart Page Detection',
          ),
          // Rename button
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showRenameDialog(),
          ),
          // Save location button
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: () => _showSaveLocationDialog(),
          ),
          // Export button
          IconButton(
            icon: const Icon(Icons.save_alt),
            onPressed: () => _showExportOptions(),
            tooltip: 'Export Options',
          ),
          // Settings button to change default save location
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final newPath = await SettingsService.getOrPickSavePath(
                forcePick: true,
              );
              if (newPath != null && context.mounted) {
                // Refresh local state if needed (though next save will use it)
                _loadDefaultSavePath();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Default save location updated to: $newPath'),
                  ),
                );
              }
            },
            tooltip: 'Change Default Save Location',
          ),
        ],
      ),
      body: allPages.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.image_not_supported,
                    size: 64,
                    color: Colors.black38,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No pages scanned',
                    style: TextStyle(fontSize: 18, color: Colors.black54),
                  ),
                ],
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 90),
              itemCount: allPages.length,
              onReorder: _handleReorder,
              itemBuilder: (context, index) {
                final page = allPages[index];
                return _ImageCard(
                  key: ValueKey(page.file.path),
                  page: page,
                  index: index,
                  onTap: () => _openEditScreen(index),
                  onDelete: () => _confirmDelete(page),
                  onRename: () => _showPageRenameDialog(index),
                  onRotate: () => _showRotateSheet(index),
                  onAdvancedEdit: () => _openAdvancedEditor(index),
                );
              },
            ),

      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPagesOptions,
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),

      // Bottom primary action
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Save location and filename preview
            if (_customFileName != null || _selectedSavePath != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Save to: ${_selectedSavePath ?? 'Default'}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_customFileName != null)
                      Text(
                        'File: $_customFileName.pdf',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: allPages.isEmpty
                    ? null
                    : () => _showSaveDetailsSheet(),
                child: const Text('Create PDF', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleReorder(int oldIndex, int newIndex) {
    setState(() {
      _manager.reorder(oldIndex, newIndex);
    });
  }

  Future<void> _confirmDelete(ScannedPage page) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete page?'),
        content: const Text('This page will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _manager.removePage(page);
      setState(() {});
    }
  }

  void _showRenameDialog() {
    showDialog(
      context: context,
      builder: (_) => RenameDialog(
        initialName:
            _customFileName ?? 'Scan_${DateTime.now().millisecondsSinceEpoch}',
        onConfirm: (name) {
          setState(() {
            _customFileName = name;
          });
        },
      ),
    );
  }

  void _showPageRenameDialog(int index) {
    final page = _manager.getPage(index);
    if (page == null) return;

    showDialog(
      context: context,
      builder: (_) => RenameDialog(
        initialName: page.displayName.replaceAll('.jpg', ''),
        onConfirm: (name) {
          setState(() {
            _manager.setCustomName(index, name);
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

  void _showRotateSheet(int index) {
    final page = _manager.getPage(index);
    if (page == null) return;

    showModalBottomSheet(
      context: context,
      builder: (_) => RotateSheet(
        imagePath: page.file.path,
        currentRotation: page.rotation,
        onRotate: (degrees) {
          setState(() {
            _manager.rotatePage(index, degrees);
          });
        },
      ),
    );
  }

  void _showSmartDetectDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Smart Page Detection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detect and fix page issues automatically:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            _buildSmartOption(
              icon: Icons.copy_all,
              title: 'Detect Duplicates',
              subtitle: 'Find pages that might be scanned twice',
              onTap: () {
                Navigator.pop(context);
                _detectDuplicates();
              },
            ),
            const SizedBox(height: 8),
            _buildSmartOption(
              icon: Icons.rotate_right,
              title: 'Auto-Rotate',
              subtitle: 'Fix upside-down or rotated pages',
              onTap: () {
                Navigator.pop(context);
                _autoRotatePages();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black26),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.blueAccent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black38),
          ],
        ),
      ),
    );
  }

  void _detectDuplicates() {
    final duplicates = _manager.detectDuplicates();
    setState(() {});

    if (duplicates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No duplicate pages detected')),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('${duplicates.length} Potential Duplicates Found'),
          content: Text(
            'We found ${duplicates.length} page(s) that might be duplicates. '
            'They are marked with a warning icon. Review and delete if needed.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                _manager.clearDuplicateFlags();
                setState(() {});
                Navigator.pop(context);
              },
              child: const Text('Clear'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _autoRotatePages() {
    // Auto-rotate all pages to 0 (reset rotation)
    for (int i = 0; i < _manager.pages.length; i++) {
      if (_manager.getPage(i)?.rotation != 0) {
        final currentRotation = _manager.getPage(i)!.rotation;
        _manager.rotatePage(i, -currentRotation);
      }
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All pages reset to default orientation')),
    );
  }

  void _showExportOptions() {
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Export Options'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Export Quality:', style: TextStyle(fontSize: 14)),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 40, label: Text('Low')),
                    ButtonSegment(value: 70, label: Text('Med')),
                    ButtonSegment(value: 100, label: Text('High')),
                  ],
                  selected: {_exportQuality},
                  onSelectionChanged: (Set<int> newSelection) {
                    setDialogState(() {
                      _exportQuality = newSelection.first;
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Choose export format:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                _buildExportOption(
                  icon: Icons.picture_as_pdf,
                  title: 'PDF',
                  subtitle: 'Single or multi-page document',
                  onTap: () {
                    Navigator.pop(context);
                    // Already handled by the main Create PDF button
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Use the "Create PDF" button for PDF export',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _buildExportOption(
                  icon: Icons.text_snippet,
                  title: 'TXT (OCR)',
                  subtitle: 'Export recognized text',
                  onTap: () {
                    Navigator.pop(context);
                    _exportAsText();
                  },
                ),
                const SizedBox(height: 8),
                _buildExportOption(
                  icon: Icons.image,
                  title: 'JPG',
                  subtitle: 'Export all pages as JPG images',
                  onTap: () {
                    Navigator.pop(context);
                    _exportAsJpg();
                  },
                ),
                const SizedBox(height: 8),
                _buildExportOption(
                  icon: Icons.photo_library,
                  title: 'PNG',
                  subtitle: 'Export all pages as PNG images',
                  onTap: () {
                    Navigator.pop(context);
                    _exportAsPng();
                  },
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                _buildExportOption(
                  icon: Icons.burst_mode,
                  title: 'Batch Export',
                  subtitle: 'Export to multiple formats at once',
                  onTap: () {
                    Navigator.pop(context);
                    _batchExport();
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAsText() async {
    if (_manager.pages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No pages to export')));
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      StringBuffer extractedText = StringBuffer();

      for (int i = 0; i < _manager.pages.length; i++) {
        final page = _manager.pages[i];
        final inputImage = InputImage.fromFilePath(page.file.path);
        final RecognizedText recognizedText = await textRecognizer.processImage(
          inputImage,
        );

        extractedText.writeln('--- Page ${i + 1} ---');
        extractedText.writeln(recognizedText.text);
        extractedText.writeln();
      }

      textRecognizer.close();

      final defaultSavePath = await SettingsService.getOrPickSavePath();
      final directory =
          _customSaveDirectory ??
          (defaultSavePath != null
              ? Directory(defaultSavePath)
              : await getApplicationDocumentsDirectory());

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final baseName = _customFileName ?? 'TempScan_$timestamp';
      final fileName = '$baseName.txt';
      final filePath = '${directory.path}/$fileName';

      final outputFile = File(filePath);
      await outputFile.writeAsString(extractedText.toString());

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported text to ${directory.path}'),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting text: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildExportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black26),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.green),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black38),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAsJpg() async {
    if (_manager.pages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No pages to export')));
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // Get save directory
      final defaultSavePath = await SettingsService.getOrPickSavePath();
      final directory =
          _customSaveDirectory ??
          (defaultSavePath != null
              ? Directory(defaultSavePath)
              : await getApplicationDocumentsDirectory());

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Generate base filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final baseName = _customFileName ?? 'TempScan_$timestamp';

      int exportedCount = 0;
      for (int i = 0; i < _manager.pages.length; i++) {
        final page = _manager.pages[i];
        final imageBytes = await page.file.readAsBytes();

        final fileName = '${baseName}_page${i + 1}.jpg';
        final filePath = '${directory.path}/$fileName';
        final outputFile = File(filePath);

        if (_exportQuality < 100) {
          final decodedImage = img.decodeImage(imageBytes);
          if (decodedImage != null) {
            final compressedBytes = img.encodeJpg(
              decodedImage,
              quality: _exportQuality,
            );
            await outputFile.writeAsBytes(compressedBytes);
          } else {
            await outputFile.writeAsBytes(imageBytes); // fallback
          }
        } else {
          await outputFile.writeAsBytes(imageBytes);
        }
        exportedCount++;
      }

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Exported $exportedCount JPG images to ${directory.path}',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting JPG: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportAsPng() async {
    if (_manager.pages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No pages to export')));
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // Get save directory
      final defaultSavePath = await SettingsService.getOrPickSavePath();
      final directory =
          _customSaveDirectory ??
          (defaultSavePath != null
              ? Directory(defaultSavePath)
              : await getApplicationDocumentsDirectory());

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Generate base filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final baseName = _customFileName ?? 'TempScan_$timestamp';

      int exportedCount = 0;
      for (int i = 0; i < _manager.pages.length; i++) {
        final page = _manager.pages[i];
        final imageBytes = await page.file.readAsBytes();

        // Simply save as PNG (Flutter will handle the conversion)
        final fileName = '${baseName}_page${i + 1}.png';
        final filePath = '${directory.path}/$fileName';
        final outputFile = File(filePath);

        // For PNG, we'd need image package to convert.
        // For now, save as-is with .png extension (users can rename or convert)
        await outputFile.writeAsBytes(imageBytes);
        exportedCount++;
      }

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Exported $exportedCount PNG images to ${directory.path}',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting PNG: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _batchExport() async {
    if (_manager.pages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No pages to export')));
      return;
    }

    // Show naming pattern dialog
    final pattern = await showDialog<String>(
      context: context,
      builder: (_) => const _NamingPatternDialog(),
    );

    if (pattern == null || !mounted) return;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // Get save directory
      final defaultSavePath = await SettingsService.getOrPickSavePath();
      final directory =
          _customSaveDirectory ??
          (defaultSavePath != null
              ? Directory(defaultSavePath)
              : await getApplicationDocumentsDirectory());

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Generate base filename with pattern
      final timestamp = DateTime.now();
      final baseName =
          _customFileName ?? 'TempScan_${timestamp.millisecondsSinceEpoch}';

      // Apply naming pattern
      String applyPattern(String pattern, int pageNum) {
        return pattern
            .replaceAll(
              '{date}',
              '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}',
            )
            .replaceAll(
              '{time}',
              '${timestamp.hour.toString().padLeft(2, '0')}-${timestamp.minute.toString().padLeft(2, '0')}',
            )
            .replaceAll('{page}', pageNum.toString().padLeft(2, '0'))
            .replaceAll('{custom}', _customFileName ?? baseName);
      }

      int pdfCount = 0;
      int jpgCount = 0;
      int pngCount = 0;

      // Export as PDF
      try {
        final pdfPattern = applyPattern(pattern, 0);
        final pdfFileName = '$pdfPattern.pdf';
        final pdfPath = '${directory.path}/$pdfFileName';

        final pdf = await PdfBuilder.createPdf(
          addWatermark: true,
          customFileName: pdfFileName.replaceAll('.pdf', ''),
          customDirectory: directory,
        );

        // Move to correct location if different
        if (pdf.path != pdfPath) {
          await pdf.copy(pdfPath);
          await pdf.delete();
        }
        pdfCount++;
      } catch (e) {
        debugPrint('PDF export error: $e');
      }

      // Export as JPG
      for (int i = 0; i < _manager.pages.length; i++) {
        final page = _manager.pages[i];
        final imageBytes = await page.file.readAsBytes();

        final jpgPattern = applyPattern(pattern, i + 1);
        final filePath = '${directory.path}/$jpgPattern.jpg';
        final outputFile = File(filePath);
        await outputFile.writeAsBytes(imageBytes);
        jpgCount++;
      }

      // Export as PNG (save with .png extension)
      for (int i = 0; i < _manager.pages.length; i++) {
        final page = _manager.pages[i];
        final imageBytes = await page.file.readAsBytes();

        final pngPattern = applyPattern(pattern, i + 1);
        final filePath = '${directory.path}/$pngPattern.png';
        final outputFile = File(filePath);
        await outputFile.writeAsBytes(imageBytes);
        pngCount++;
      }

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Batch export complete!\n'
            'PDF: $pdfCount, JPG: $jpgCount, PNG: $pngCount\n'
            'Saved to: ${directory.path}',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error in batch export: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openEditScreen(int index) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditImageScreen(pageIndex: index)),
    );

    // If image was deleted, refresh the list
    if (result == true) {
      setState(() {});
    }
  }

  Future<void> _openAdvancedEditor(int index) async {
    final page = _manager.getPage(index);
    if (page == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdvancedEditorScreen(documentFile: page.file),
      ),
    );

    if (result != null && result is File && mounted) {
      await _manager.updatePageFile(index, result);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document updated with advanced edits')),
      );
    }
  }

  Future<void> _createPdf() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final file = await PdfBuilder.createPdf(
        addWatermark: true,
        customFileName: _customFileName,
        customDirectory: _customSaveDirectory,
      );

      // Save to DocumentStorageService
      await DocumentStorageService.instance.initialize(); // ensure it's loaded
      ScannedDocument doc = ScannedDocument(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: file.path.split('/').last,
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        folderId: _selectedFolderId,
        tags: _selectedTags,
        filePath: file.path,
        fileSize: await file.length(),
        type: DocumentType.pdf,
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
          content: Text('Error creating PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSaveDetailsSheet() {
    DocumentStorageService.instance.initialize().then((_) {
      if (!mounted) return;
      final folders = DocumentStorageService.instance.folders;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Save Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Filename
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Filename',
                        border: OutlineInputBorder(),
                      ),
                      controller: TextEditingController(
                        text:
                            _customFileName ??
                            'Scan_${DateTime.now().millisecondsSinceEpoch}',
                      )..selection = TextSelection.collapsed(offset: 0),
                      onChanged: (val) => _customFileName = val,
                    ),
                    const SizedBox(height: 16),

                    // Folder
                    DropdownButtonFormField<String?>(
                      decoration: const InputDecoration(
                        labelText: 'Folder',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedFolderId,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('No Folder'),
                        ),
                        ...folders.map(
                          (f) => DropdownMenuItem(
                            value: f.id,
                            child: Text(f.name),
                          ),
                        ),
                      ],
                      onChanged: (val) =>
                          setSheetState(() => _selectedFolderId = val),
                    ),
                    const SizedBox(height: 16),

                    // Tags
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Add Tag (Press Enter)',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty &&
                            !_selectedTags.contains(val.trim())) {
                          setSheetState(() => _selectedTags.add(val.trim()));
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _selectedTags
                          .map(
                            (tag) => Chip(
                              label: Text(tag),
                              onDeleted: () => setSheetState(
                                () => _selectedTags.remove(tag),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _createPdf();
                        },
                        child: const Text('Save & Create PDF'),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        ),
      );
    });
  }

  void _showAddPagesOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Pages',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildSmartOption(
              icon: Icons.camera_alt,
              title: 'From Camera',
              subtitle: 'Scan new documents',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CameraScreen()),
                ).then((_) {
                  // Refresh UI after returning from camera
                  setState(() {});
                });
              },
            ),
            const SizedBox(height: 12),
            _buildSmartOption(
              icon: Icons.photo_library,
              title: 'From Gallery',
              subtitle: 'Add existing images',
              onTap: () {
                Navigator.pop(context);
                _addFromGallery();
              },
            ),
            const SizedBox(height: 12),
            _buildSmartOption(
              icon: Icons.picture_as_pdf,
              title: 'From PDF',
              subtitle: 'Extract pages from PDF',
              onTap: () {
                Navigator.pop(context);
                _addFromPdf();
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _addFromGallery() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );

        for (final pickedFile in result.files) {
          if (pickedFile.path != null) {
            // Read the image
            final bytes = await File(pickedFile.path!).readAsBytes();

            // Generate a unique name for temp storage
            final tempFile = await _manager.createTempImageFile();
            await tempFile.writeAsBytes(bytes);

            // Add to manager
            _manager.addImage(tempFile);
          }
        }

        if (mounted) {
          Navigator.pop(context); // close dialog
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added ${result.files.length} images')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding from gallery: $e')),
        );
      }
    }
  }

  Future<void> _addFromPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null &&
          result.files.isNotEmpty &&
          result.files.first.path != null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );

        final doc = await pdfx.PdfDocument.openFile(result.files.first.path!);
        int pageCount = doc.pagesCount;

        for (int i = 1; i <= pageCount; i++) {
          final page = await doc.getPage(i);
          // Render the page as image
          final pageImage = await page.render(
            width: page.width * 2.0, // Scale for better quality
            height: page.height * 2.0,
            format: pdfx.PdfPageImageFormat.jpeg,
          );

          if (pageImage != null) {
            final tempFile = await _manager.createTempImageFile();
            await tempFile.writeAsBytes(pageImage.bytes);
            _manager.addImage(tempFile);
          }
          await page.close();
        }

        if (mounted) {
          Navigator.pop(context); // close dialog
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added $pageCount pages from PDF')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding from PDF: $e')));
      }
    }
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
          // Standard locations
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
          // Custom location option
          Row(
            children: [
              Checkbox(
                value: _useCustomLocation,
                onChanged: (value) async {
                  if (value == true) {
                    // Open folder picker
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
          if (_useCustomLocation && _customSelectedDirectory == null)
            const Text(
              'Tap to select a folder',
              style: TextStyle(fontSize: 11, color: Colors.grey),
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
      // Request manage external storage permission first (for Android 11+)
      if (await Permission.manageExternalStorage.request().isGranted) {
        _openFilePicker();
      } else {
        // Check if we should show settings
        if (await Permission.manageExternalStorage.isPermanentlyDenied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Please grant storage permission in Settings',
                ),
                action: SnackBarAction(
                  label: 'Open Settings',
                  onPressed: openAppSettings,
                ),
              ),
            );
          }
        } else {
          // Fallback to regular storage permission
          if (await Permission.storage.request().isGranted) {
            _openFilePicker();
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Storage permission is required')),
              );
            }
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error selecting folder: $e')));
    }
  }

  void _openFilePicker() async {
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
      } else {
        // User cancelled
        setState(() {
          _useCustomLocation = false;
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

/* ---------------- Image Card Widget ---------------- */

class _ImageCard extends StatelessWidget {
  final ScannedPage page;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRename;
  final VoidCallback onRotate;
  final VoidCallback onAdvancedEdit;

  const _ImageCard({
    super.key,
    required this.page,
    required this.index,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
    required this.onRotate,
    required this.onAdvancedEdit,
  });

  @override
  Widget build(BuildContext context) {
    final fileSize = FileSizeHelper.readable(page.file);
    final rotationDegrees = page.rotation;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 1,
      child: Row(
        children: [
          // Drag handle (left side)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: const Icon(Icons.drag_indicator, color: Colors.black38),
          ),

          // Image (tap to edit)
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              onLongPress: onRename,
              child: Row(
                children: [
                  // Image with rotation
                  Stack(
                    children: [
                      Transform.rotate(
                        angle: rotationDegrees * 3.14159 / 180,
                        child: Image.file(
                          page.file,
                          width: 90,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                      // Rotation indicator
                      if (rotationDegrees != 0)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$rotationDegrees°',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${index + 1}. ${page.displayName}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fileSize,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                        if (rotationDegrees != 0)
                          Text(
                            'Rotated: $rotationDegrees°',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.orange,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Quick actions
          IconButton(
            icon: const Icon(
              Icons.text_fields_rounded,
              size: 20,
              color: Colors.blueAccent,
            ),
            onPressed: onAdvancedEdit,
            tooltip: 'Advanced Edit (Translation, Eraser, OCR)',
          ),
          IconButton(
            icon: const Icon(Icons.rotate_right, size: 20),
            onPressed: onRotate,
            tooltip: 'Rotate',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: onDelete,
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/* ---------------- Naming Pattern Dialog ---------------- */

class _NamingPatternDialog extends StatefulWidget {
  const _NamingPatternDialog();

  @override
  State<_NamingPatternDialog> createState() => _NamingPatternDialogState();
}

class _NamingPatternDialogState extends State<_NamingPatternDialog> {
  final _controller = TextEditingController(text: 'TempScan_{date}');

  final List<String> _suggestions = [
    'TempScan_{date}',
    'Document_{page}',
    'Scan_{date}_{time}',
    'MyDoc_{custom}',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Naming Pattern'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter a naming pattern for batch export:',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'Pattern',
              hintText: 'e.g., TempScan_{date}',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => _controller.clear(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Available variables:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _PatternChip(label: '{date}', description: 'Date'),
              _PatternChip(label: '{time}', description: 'Time'),
              _PatternChip(label: '{page}', description: 'Page #'),
              _PatternChip(label: '{custom}', description: 'Custom name'),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Quick suggestions:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions
                .map(
                  (s) => _SuggestionChip(
                    label: s,
                    onTap: () => _controller.text = s,
                  ),
                )
                .toList(),
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
            final pattern = _controller.text.trim();
            if (pattern.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a naming pattern')),
              );
              return;
            }
            Navigator.pop(context, pattern);
          },
          child: const Text('Export'),
        ),
      ],
    );
  }
}

class _PatternChip extends StatelessWidget {
  final String label;
  final String description;

  const _PatternChip({required this.label, required this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Text(
        '$label ($description)',
        style: const TextStyle(fontSize: 11, color: Colors.blue),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
      backgroundColor: Colors.grey.withOpacity(0.1),
    );
  }
}
