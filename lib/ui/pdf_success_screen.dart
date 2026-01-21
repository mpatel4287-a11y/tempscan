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
    // Show save location snackbar after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _showSaveLocationSnackbar();
      }
    });
  }

  void _showSaveLocationSnackbar() {
    final folderPath = widget.pdfFile.parent.path;
    final displayPath = _formatPath(folderPath);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Saved to: $displayPath',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Open folder',
          onPressed: () {
            OpenFilex.open(widget.pdfFile.parent.path);
          },
        ),
      ),
    );
  }

  String _formatPath(String fullPath) {
    // Convert to a more readable format
    if (fullPath.contains('/Android/data/')) {
      return 'Internal storage › TempScan';
    } else if (fullPath.contains('/Documents/')) {
      return 'Documents › TempScan';
    } else {
      // Extract last two parts of path
      final parts = fullPath.split('/').where((e) => e.isNotEmpty).toList();
      if (parts.length >= 2) {
        return '${parts[parts.length - 2]} › ${parts[parts.length - 1]}';
      }
      return fullPath;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.pdfFile.path.split('/').last;
    final fileSize = widget.pdfFile.lengthSync();
    final folderPath = _formatPath(widget.pdfFile.parent.path);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('PDF Created'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),

            // Success icon
            const Icon(Icons.check_circle, color: Colors.green, size: 80),

            const SizedBox(height: 24),

            const Text(
              'Your PDF is ready',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 8),

            Text(
              fileName,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 14),
            ),

            const SizedBox(height: 4),

            Text(
              _formatFileSize(fileSize),
              style: const TextStyle(color: Colors.black38, fontSize: 12),
            ),

            const SizedBox(height: 6),

            GestureDetector(
              onTap: () {
                OpenFilex.open(widget.pdfFile.parent.path);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder, size: 14, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(
                    folderPath,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Open PDF
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  OpenFilex.open(widget.pdfFile.path);
                },
                child: const Text('Open PDF', style: TextStyle(fontSize: 16)),
              ),
            ),

            const SizedBox(height: 12),

            // Share PDF
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () {
                  Share.shareXFiles([XFile(widget.pdfFile.path)]);
                },
                child: const Text('Share', style: TextStyle(fontSize: 16)),
              ),
            ),

            const Spacer(),

            // Done button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: TextButton(
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: const Text('Done', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}
