import 'dart:async';
import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'auto_enhance_screen.dart';
import 'ocr_screen.dart';
import 'merge_pdfs_screen.dart';
import 'password_pdf_screen.dart';
import 'signature_screen.dart';
import '../camera/camera_screen.dart';
import 'create_video_pdf_screen.dart';
import 'video_pdf_viewer_screen.dart';

class HomeOptionsScreen extends StatefulWidget {
  const HomeOptionsScreen({super.key});

  @override
  State<HomeOptionsScreen> createState() => _HomeOptionsScreenState();
}

class _HomeOptionsScreenState extends State<HomeOptionsScreen> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();

    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleLink(uri);
    });

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleLink(uri);
    });
  }

  void _handleLink(Uri uri) {
    final path = uri.toFilePath();
    if (path.endsWith('.vpdf') || path.endsWith('.pdf')) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VideoPdfViewerScreen(initialFile: File(path)),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0F0F0F),
              const Color(0xFF1A1A1A),
              const Color(0xFF0F0F0F),
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.document_scanner,
                              color: Colors.blueAccent,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'TempScan',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shield_outlined, size: 14, color: Colors.greenAccent),
                            const SizedBox(width: 6),
                            const Text(
                              'Privacy First: Images are never saved on device',
                              style: TextStyle(fontSize: 12, color: Colors.greenAccent, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.95,
                  ),
                  delegate: SliverChildListDelegate([
                    _OptionCard(
                      icon: Icons.auto_fix_high,
                      title: 'Auto Enhance',
                      subtitle: 'AI-powered quality boost',
                      gradient: [const Color(0xFF4FACFE), const Color(0xFF00F2FE)],
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AutoEnhanceScreen())),
                    ),
                    _OptionCard(
                      icon: Icons.text_snippet,
                      title: 'OCR Tool',
                      subtitle: 'Extract text instantly',
                      gradient: [const Color(0xFF43E97B), const Color(0xFF38F9D7)],
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OcrScreen())),
                    ),
                    _OptionCard(
                      icon: Icons.lock_person,
                      title: 'Secure PDF',
                      subtitle: 'Password protection',
                      gradient: [const Color(0xFFFA709A), const Color(0xFFFEE140)],
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PasswordPdfScreen())),
                    ),
                    _OptionCard(
                      icon: Icons.merge_type,
                      title: 'Merge PDFs',
                      subtitle: 'Combine documents',
                      gradient: [const Color(0xFF667EEA), const Color(0xFF764BA2)],
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MergePdfsScreen())),
                    ),
                    _OptionCard(
                      icon: Icons.draw_rounded,
                      title: 'Signature',
                      subtitle: 'Sign your documents',
                      gradient: [const Color(0xFF2AF598), const Color(0xFF009EFD)],
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignatureScreen())),
                    ),
                    _OptionCard(
                      icon: Icons.camera_enhance,
                      title: 'Smart Scan',
                      subtitle: 'Scan new documents',
                      gradient: [const Color(0xFFFF0844), const Color(0xFFFFB199)],
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraScreen())),
                    ),
                    _OptionCard(
                      icon: Icons.video_collection,
                      title: 'Video PDF',
                      subtitle: 'Embed video in PDF',
                      gradient: [const Color(0xFFB721FF), const Color(0xFF21D4FD)],
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateVideoPdfScreen())),
                    ),
                    _OptionCard(
                      icon: Icons.play_circle_filled_rounded,
                      title: 'Player',
                      subtitle: 'Play Video PDFs',
                      gradient: [const Color(0xFFFEC867), const Color(0xFFF72585)],
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VideoPdfViewerScreen())),
                    ),
                  ]),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<_OptionCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: widget.gradient.map((e) => e.withValues(alpha: 0.2)).toList(),
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: widget.gradient,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: widget.gradient.first.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(widget.icon, color: Colors.white, size: 28),
                    ),
                    const Spacer(),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.6),
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
