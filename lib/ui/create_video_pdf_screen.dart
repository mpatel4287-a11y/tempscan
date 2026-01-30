import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:temp_scan/utils/video_embed_builder.dart';
import 'package:temp_scan/services/settings_service.dart';

class CreateVideoPdfScreen extends StatefulWidget {
  const CreateVideoPdfScreen({super.key});

  @override
  State<CreateVideoPdfScreen> createState() => _CreateVideoPdfScreenState();
}

class _CreateVideoPdfScreenState extends State<CreateVideoPdfScreen> {
  final List<File> _selectedVideos = [];
  bool _isGenerating = false;

  Future<void> _pickVideos() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        _selectedVideos.addAll(result.paths.map((path) => File(path!)));
      });
    }
  }

  Future<void> _generatePdf() async {
    if (_selectedVideos.isEmpty) return;

    // Ask for filename and save location check
    final fileNameController = TextEditingController(text: 'MyVideoPDF');
    final String? fileName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save PDF'),
        content: TextField(
          controller: fileNameController,
          decoration: const InputDecoration(labelText: 'File Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, fileNameController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (fileName == null || fileName.isEmpty) return;

    setState(() => _isGenerating = true);

    try {
      final pdf = pw.Document(version: PdfVersion.pdf_1_5, compress: false);

      // Generate Thumbnails and Pages
      // Logic: 1 Page = 1 Video
      // We embed the video content with metadata: "VideoIndex: i"
      // But actually, VideoEmbedBuilder embeds all files.
      // We just need to make sure the pages correspond to the extracted list order.
      // VideoEmbedBuilder.embedVideos embeds files in list order.
      // Extraction should preserve order.
      
      for (int i = 0; i < _selectedVideos.length; i++) {
        final videoFile = _selectedVideos[i];
        
        // Generate real thumbnail
        final thumbData = await VideoThumbnail.thumbnailData(
          video: videoFile.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 200,
          quality: 50,
        );

        pdf.addPage(
          pw.Page(
            build: (context) {
              return pw.Center(
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Container(
                      width: 300,
                      height: 200,
                      child: pw.Image(pw.MemoryImage(thumbData)),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Text('Video ${i + 1}', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 10),
                    pw.Text('Open in TempScan to play', style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey)),
                    pw.SizedBox(height: 20),
                    // Play icon overlay
                    pw.Container(
                      width: 60,
                      height: 60,
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.black,
                        shape: pw.BoxShape.circle,
                      ),
                      child: pw.Center(
                        child: pw.Text('▶', style: pw.TextStyle(color: PdfColors.white, fontSize: 30)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      }

      // Embed Videos
      await VideoEmbedBuilder.embedVideos(pdf, _selectedVideos);

      // Save using SettingsService
      final selectedDirectory = await SettingsService.getOrPickSavePath();
      if (selectedDirectory == null) {
        if (mounted) setState(() => _isGenerating = false);
        return;
      }

      final filePath = '$selectedDirectory/$fileName.vpdf';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to $filePath')));
        // Also ensure we share it so user can move it if they want
        Share.shareXFiles([XFile(file.path)], text: 'Here is your Video PDF');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  void _removeVideo(int index) {
    setState(() {
      _selectedVideos.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Video PDF'),
        actions: [
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
            child: _selectedVideos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.video_library, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('No videos selected'),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _pickVideos,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Videos'),
                        ),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    itemCount: _selectedVideos.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _selectedVideos.removeAt(oldIndex);
                        _selectedVideos.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final file = _selectedVideos[index];
                      return ListTile(
                        key: ValueKey(file.path),
                        leading: const Icon(Icons.movie),
                        title: Text(file.path.split('/').last),
                        subtitle: Text('${(file.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeVideo(index),
                        ),
                      );
                    },
                  ),
          ),
          if (_selectedVideos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                   Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickVideos,
                      icon: const Icon(Icons.add),
                      label: const Text('Add More'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isGenerating ? null : _generatePdf,
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.picture_as_pdf),
                      label: Text(_isGenerating ? 'Generating...' : 'Save PDF'),
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
