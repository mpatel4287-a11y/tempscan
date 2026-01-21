// ignore_for_file: deprecated_member_use, unused_local_variable, unused_element

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'camera_controller.dart';
import '../temp_storage/temp_image_manager.dart';
import '../utils/file_size_helper.dart';
import '../ui/review_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final _cameraController = TempScanCameraController();
  bool _ready = false;
  bool _showFlash = false;
  bool _showGrid = false;
  int _flashMode = 0; // 0 = off, 1 = on, 2 = auto

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    await _cameraController.initialize();
    setState(() => _ready = true);
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  void _toggleFlash() {
    setState(() {
      _flashMode = (_flashMode + 1) % 3;
    });
    _cameraController.setFlashMode(_flashMode);
  }

  Widget _buildFlashIcon() {
    switch (_flashMode) {
      case 0:
        return const Icon(Icons.flash_off, color: Colors.white);
      case 1:
        return const Icon(Icons.flash_on, color: Colors.white);
      case 2:
        return const Icon(Icons.flash_auto, color: Colors.white);
      default:
        return const Icon(Icons.flash_off, color: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Initializing camera...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    final hasImages = TempImageManager().images.isNotEmpty;
    final pageCount = TempImageManager().images.length;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          SizedBox.expand(child: CameraPreview(_cameraController.controller!)),

          // Grid overlay
          if (_showGrid) Positioned.fill(child: _GridOverlay()),

          // Flash feedback animation
          if (_showFlash)
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: _showFlash ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 60),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.2,
                      colors: [
                        Colors.white.withOpacity(0.9),
                        Colors.white.withOpacity(0.4),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Top control bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Close button
                  _buildTopButton(
                    icon: Icons.close,
                    onTap: () => Navigator.pop(context),
                  ),

                  // Flash toggle
                  _buildTopButton(
                    icon: Icons
                        .flash_off, // Will be replaced by _buildFlashIcon widget
                    onTap: _toggleFlash,
                  ),
                ],
              ),
            ),
          ),

          // Scan frame overlay
          const _ScanFrameOverlay(),

          // Bottom control bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                bottom: 24 + MediaQuery.of(context).padding.bottom,
                top: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.9),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Quick actions row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Grid toggle
                      _buildBottomActionButton(
                        icon: _showGrid ? Icons.grid_on : Icons.grid_off,
                        label: 'Grid',
                        isActive: _showGrid,
                        onTap: () {
                          setState(() => _showGrid = !_showGrid);
                        },
                      ),

                      // Capture button
                      _CaptureButton(
                        onCapture: () async {
                          setState(() => _showFlash = true);
                          await _cameraController.captureImage();
                          await Future.delayed(
                            const Duration(milliseconds: 50),
                          );
                          setState(() => _showFlash = false);
                        },
                      ),

                      // Gallery/Review button
                      _buildBottomActionButton(
                        icon: Icons.photo_library,
                        label: 'Review',
                        hasBadge: hasImages,
                        badgeCount: pageCount,
                        onTap: hasImages
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ReviewScreen(),
                                  ),
                                );
                              }
                            : null,
                      ),
                    ],
                  ),

                  // Page count indicator
                  if (hasImages)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.document_scanner,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                FutureBuilder<int>(
                                  future: Future.value(
                                    TempImageManager().totalSizeBytes,
                                  ),
                                  builder: (context, snapshot) {
                                    final sizeText = snapshot.data != null
                                        ? ' • ${FileSizeHelper.format(snapshot.data!)}'
                                        : '';
                                    return Text(
                                      '$pageCount page${pageCount > 1 ? 's' : ''}$sizeText',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildBottomActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool isActive = false,
    bool hasBadge = false,
    int badgeCount = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (onTap != null)
                      ? (isActive ? Colors.blue : Colors.black26)
                      : Colors.black26.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  icon,
                  color: (onTap != null) ? Colors.white : Colors.white54,
                ),
              ),
              if (hasBadge)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: (onTap != null)
                  ? Colors.white.withOpacity(0.8)
                  : Colors.white38,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/* ----------------------- Widgets ----------------------- */

class _CaptureButton extends StatelessWidget {
  final VoidCallback onCapture;

  const _CaptureButton({required this.onCapture});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCapture,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _GridOverlay extends StatelessWidget {
  const _GridOverlay();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width * 0.85;
    final height = size.height * 0.55;
    final thirdWidth = width / 3;
    final thirdHeight = height / 3;

    return IgnorePointer(
      child: Stack(
        children: [
          // Semi-transparent overlay
          Container(color: Colors.black.withOpacity(0.25)),

          // Document frame
          Center(
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withOpacity(0.8),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                children: [
                  // Vertical grid lines
                  Positioned(
                    left: thirdWidth,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 1,
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                  Positioned(
                    left: thirdWidth * 2,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 1,
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                  // Horizontal grid lines
                  Positioned(
                    top: thirdHeight,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 1,
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                  Positioned(
                    top: thirdHeight * 2,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 1,
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                  // Corner markers
                  _buildCornerMarker(Alignment.topLeft),
                  _buildCornerMarker(Alignment.topRight),
                  _buildCornerMarker(Alignment.bottomLeft),
                  _buildCornerMarker(Alignment.bottomRight),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCornerMarker(Alignment alignment) {
    final double x = alignment.x == -1 ? 0 : (alignment.x == 1 ? 1 : 0.5);
    final double y = alignment.y == -1 ? 0 : (alignment.y == 1 ? 1 : 0.5);

    return Positioned(
      left: 0,
      top: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Stack(
          children: [
            // Top-left
            if (alignment == Alignment.topLeft) ...[
              Positioned(
                left: -2,
                top: -2,
                child: SizedBox(
                  width: 16,
                  height: 2,
                  child: Container(color: Colors.blue),
                ),
              ),
              Positioned(
                left: -2,
                top: -2,
                child: SizedBox(
                  width: 2,
                  height: 16,
                  child: Container(color: Colors.blue),
                ),
              ),
            ],
            // Top-right
            if (alignment == Alignment.topRight) ...[
              Positioned(
                right: -2,
                top: -2,
                child: SizedBox(
                  width: 16,
                  height: 2,
                  child: Container(color: Colors.blue),
                ),
              ),
              Positioned(
                right: -2,
                top: -2,
                child: SizedBox(
                  width: 2,
                  height: 16,
                  child: Container(color: Colors.blue),
                ),
              ),
            ],
            // Bottom-left
            if (alignment == Alignment.bottomLeft) ...[
              Positioned(
                left: -2,
                bottom: -2,
                child: SizedBox(
                  width: 16,
                  height: 2,
                  child: Container(color: Colors.blue),
                ),
              ),
              Positioned(
                left: -2,
                bottom: -2,
                child: SizedBox(
                  width: 2,
                  height: 16,
                  child: Container(color: Colors.blue),
                ),
              ),
            ],
            // Bottom-right
            if (alignment == Alignment.bottomRight) ...[
              Positioned(
                right: -2,
                bottom: -2,
                child: SizedBox(
                  width: 16,
                  height: 2,
                  child: Container(color: Colors.blue),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: SizedBox(
                  width: 2,
                  height: 16,
                  child: Container(color: Colors.blue),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScanFrameOverlay extends StatelessWidget {
  const _ScanFrameOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Container(color: Colors.black.withOpacity(0.25)),
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              height: MediaQuery.of(context).size.height * 0.55,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withOpacity(0.8),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
