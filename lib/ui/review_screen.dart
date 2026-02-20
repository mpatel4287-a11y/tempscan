// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../temp_storage/temp_image_manager.dart';
import '../services/settings_service.dart';
import '../document_builder/pdf_builder.dart';
import '../utils/file_size_helper.dart';
import '../ui/pdf_success_screen.dart';
import '../ui/rename_dialog.dart';
import '../ui/rotate_sheet.dart';
import '../ui/edit_image_screen.dart';

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
                );
              },
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
                onPressed: allPages.isEmpty ? null : () => _createPdf(),
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
      builder: (_) => AlertDialog(
        title: const Text('Export Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose export format:', style: TextStyle(fontSize: 14)),
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
                    content: Text('Use the "Create PDF" button for PDF export'),
                  ),
                );
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
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
    // Implementation for JPG export
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('JPG export - Use the "Create PDF" and save as JPG'),
      ),
    );
  }

  Future<void> _exportAsPng() async {
    // Implementation for PNG export
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PNG export - Use the "Create PDF" and save as PNG'),
      ),
    );
  }

  Future<void> _batchExport() async {
    // Show naming pattern dialog
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _NamingPatternDialog(),
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Batch export with pattern: $result')),
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

  Future<void> _createPdf() async {
    try {
      final file = await PdfBuilder.createPdf(
        addWatermark: true,
        customFileName: _customFileName,
        customDirectory: _customSaveDirectory,
      );

      // Clear temp images after PDF creation
      await TempImageManager().clearAll();

      if (!context.mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PdfSuccessScreen(pdfFile: file)),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
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

  const _ImageCard({
    super.key,
    required this.page,
    required this.index,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
    required this.onRotate,
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
