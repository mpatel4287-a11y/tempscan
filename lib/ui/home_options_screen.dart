import 'package:flutter/material.dart';
import 'auto_enhance_screen.dart';
import 'ocr_screen.dart';
import 'merge_pdfs_screen.dart';
import 'password_pdf_screen.dart';
import 'signature_screen.dart';
import '../camera/camera_screen.dart';

class HomeOptionsScreen extends StatelessWidget {
  const HomeOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                'TempScan',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Images are never saved to your phone.',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                  children: [
                    _OptionCard(
                      icon: Icons.auto_fix_high,
                      title: 'Auto Enhance',
                      subtitle: 'Automatically improve image quality',
                      color: Colors.blue,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AutoEnhanceScreen(),
                          ),
                        );
                      },
                    ),
                    _OptionCard(
                      icon: Icons.text_snippet,
                      title: 'OCR - Copy Text',
                      subtitle: 'Extract text from images',
                      color: Colors.green,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const OcrScreen()),
                        );
                      },
                    ),
                    _OptionCard(
                      icon: Icons.lock,
                      title: 'Password PDF',
                      subtitle: 'Create encrypted PDFs',
                      color: Colors.orange,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PasswordPdfScreen(),
                          ),
                        );
                      },
                    ),
                    _OptionCard(
                      icon: Icons.merge_type,
                      title: 'Merge PDFs',
                      subtitle: 'Combine multiple PDFs',
                      color: Colors.purple,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MergePdfsScreen(),
                          ),
                        );
                      },
                    ),
                    _OptionCard(
                      icon: Icons.draw,
                      title: 'Add Signature',
                      subtitle: 'Create and add signature',
                      color: Colors.teal,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SignatureScreen(),
                          ),
                        );
                      },
                    ),
                    _OptionCard(
                      icon: Icons.document_scanner,
                      title: 'Scan Document',
                      subtitle: 'Scan new documents',
                      color: Colors.red,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CameraScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
