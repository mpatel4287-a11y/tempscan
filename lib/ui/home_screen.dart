import 'package:flutter/material.dart';
import '../camera/camera_screen.dart';
import 'create_video_pdf_screen.dart';
import 'video_pdf_viewer_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              _buildHeroHeader(),
              const Spacer(),
              _buildMainButton(
                context,
                title: 'Start Scanning',
                subtitle: 'Scan documents with zero data saving',
                icon: Icons.qr_code_scanner_rounded,
                isPrimary: true,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraScreen())),
              ),
              const SizedBox(height: 16),
              _buildMainButton(
                context,
                title: 'Video PDF',
                subtitle: 'Create interactive document walkthroughs',
                icon: Icons.video_collection_outlined,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateVideoPdfScreen())),
              ),
              const SizedBox(height: 16),
              _buildMainButton(
                context,
                title: 'Video PDF Player',
                subtitle: 'Play secured interactive PDFs',
                icon: Icons.play_circle_outline_rounded,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VideoPdfViewerScreen())),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF00D2FF), Color(0xFF3A7BD5)]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 32),
        const Text('TempScan', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        const SizedBox(height: 12),
        Text(
          'Private, Secure, Temporary.\nDocuments are never stored permanantly.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildMainButton(BuildContext context, {required String title, required String subtitle, required IconData icon, bool isPrimary = false, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isPrimary ? Colors.white : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isPrimary ? Colors.white : Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: isPrimary ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: isPrimary ? Colors.black : Colors.blueAccent),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: isPrimary ? Colors.black : Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: isPrimary ? Colors.black54 : Colors.white.withValues(alpha: 0.4), fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: isPrimary ? Colors.black26 : Colors.white24),
          ],
        ),
      ),
    );
  }
}
