import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

class PdfSuccessScreen extends StatefulWidget {
  final File pdfFile;
  const PdfSuccessScreen({super.key, required this.pdfFile});

  @override
  State<PdfSuccessScreen> createState() => _PdfSuccessScreenState();
}

class _PdfSuccessScreenState extends State<PdfSuccessScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _showSaveLocationSnackbar();
    });
  }

  void _showSaveLocationSnackbar() {
    final folderPath = widget.pdfFile.parent.path;
    final displayPath = _formatPath(folderPath);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text('Saved: $displayPath', style: const TextStyle(fontSize: 13, color: Colors.white))),
          ],
        ),
        action: SnackBarAction(
          label: 'OPEN',
          textColor: Colors.blueAccent,
          onPressed: () => OpenFilex.open(widget.pdfFile.parent.path),
        ),
      ),
    );
  }

  String _formatPath(String fullPath) {
    if (fullPath.contains('/Android/data/')) return 'Storage › TempScan';
    if (fullPath.contains('/Documents/')) return 'Documents › TempScan';
    final parts = fullPath.split('/').where((e) => e.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[parts.length - 2]} › ${parts[parts.length - 1]}';
    return fullPath;
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.pdfFile.path.split('/').last;
    final fileSize = widget.pdfFile.lengthSync();
    final folderPath = _formatPath(widget.pdfFile.parent.path);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.05), blurRadius: 40, spreadRadius: 10)],
                ),
                child: const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 80),
              ),
              const SizedBox(height: 32),
              const Text('Successfully Created', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(fileName, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
              const SizedBox(height: 4),
              Text(_formatFileSize(fileSize), style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => OpenFilex.open(widget.pdfFile.parent.path),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.folder_open_outlined, size: 14, color: Colors.blueAccent),
                      const SizedBox(width: 8),
                      Text(folderPath, style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => OpenFilex.open(widget.pdfFile.path),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('OPEN PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () => Share.shareXFiles([XFile(widget.pdfFile.path)]),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('SHARE', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              TextButton(
                onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                child: Text('RETURN HOME', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), letterSpacing: 1.2, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
