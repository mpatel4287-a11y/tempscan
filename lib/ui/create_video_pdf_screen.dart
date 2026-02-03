import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
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
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add Videos', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildPickOption(
                  icon: Icons.movie_outlined,
                  label: 'Gallery',
                  color: Colors.purpleAccent,
                  onTap: () async {
                    Navigator.pop(context);
                    final picker = ImagePicker();
                    // Using pickVideo with source gallery to ensure the Gallery app is opened.
                    final XFile? video = await picker.pickVideo(source: ImageSource.gallery); 
                    if (video != null) {
                      setState(() => _selectedVideos.add(File(video.path)));
                    }
                  },
                ),
                const SizedBox(width: 16),
                _buildPickOption(
                  icon: Icons.folder_open_outlined,
                  label: 'Files',
                  color: Colors.blueAccent,
                  onTap: () async {
                    Navigator.pop(context);
                    final result = await FilePicker.platform.pickFiles(type: FileType.video, allowMultiple: true);
                    if (result != null) {
                      setState(() => _selectedVideos.addAll(result.paths.map((path) => File(path!))));
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickOption({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 12),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generatePdf() async {
    if (_selectedVideos.isEmpty) return;

    final fileNameController = TextEditingController(text: 'VideoDocs_${DateTime.now().millisecondsSinceEpoch}');
    final String? fileName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Save Video PDF', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: fileNameController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'File Name',
            labelStyle: TextStyle(color: Colors.white70),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
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
      
      for (int i = 0; i < _selectedVideos.length; i++) {
        final videoFile = _selectedVideos[i];

        final Uint8List? thumbData = await VideoThumbnail.thumbnailData(
          video: videoFile.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 400,
          quality: 70,
        );

        if (thumbData == null) {
          // Skip this video but continue generating the PDF instead of crashing.
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not generate thumbnail for ${videoFile.path.split('/').last}. Skipping this video.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          continue;
        }

        pdf.addPage(
          pw.Page(
            build: (context) {
              return pw.Center(
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Container(
                      width: 400,
                      height: 250,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300, width: 1),
                      ),
                      child: pw.Image(pw.MemoryImage(thumbData), fit: pw.BoxFit.cover),
                    ),
                    pw.SizedBox(height: 30),
                    pw.Text('Video ${i + 1}', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 5),
                    pw.Text(videoFile.path.split('/').last, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                    pw.SizedBox(height: 20),
                    pw.Text('Play this video in TempScan Player', style: const pw.TextStyle(fontSize: 14, color: PdfColors.blueAccent)),
                  ],
                ),
              );
            },
          ),
        );
      }

      await VideoEmbedBuilder.embedVideos(pdf, _selectedVideos);

      final selectedDirectory = await SettingsService.getOrPickSavePath();
      if (selectedDirectory == null) {
        if (mounted) setState(() => _isGenerating = false);
        return;
      }

      final filePath = '$selectedDirectory/$fileName.vpdf';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        _showSuccessSheet(filePath, file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Generation failed: $e'), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  void _showSuccessSheet(String path, File file) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 64),
            const SizedBox(height: 16),
            const Text('PDF Created Successfully', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Saved to: $path', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Share.shareXFiles([XFile(file.path)], text: 'My Video PDF');
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _removeVideo(int index) {
    setState(() {
      _selectedVideos.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Create Video PDF', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await SettingsService.getOrPickSavePath(forcePick: true);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _selectedVideos.isEmpty
                ? _buildEmptyState()
                : _buildVideoList(),
          ),
          if (_selectedVideos.isNotEmpty) _buildBottomActions(),
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
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.video_library_outlined, size: 80, color: Colors.white.withValues(alpha: 0.2)),
          ),
          const SizedBox(height: 24),
          const Text('Translate your videos into PDFs', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Select multiple videos to embed them', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _pickVideos,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Pick Videos'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
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
        return Padding(
          key: ValueKey(file.path),
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.movie_outlined, color: Colors.blueAccent),
              ),
              title: Text(file.path.split('/').last, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
              subtitle: Text('${(file.lengthSync() / 1024 / 1024).toStringAsFixed(1)} MB', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
              trailing: IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                onPressed: () => _removeVideo(index),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _pickVideos,
              icon: const Icon(Icons.add),
              label: const Text('Add More'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFB721FF), Color(0xFF21D4FD)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generatePdf,
                icon: _isGenerating
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.picture_as_pdf_rounded),
                label: Text(_isGenerating ? 'GENERATING...' : 'SAVE PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
