// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../temp_storage/temp_image_manager.dart';

/// Aspect ratio options for cropping with icons
enum CropAspectRatio {
  free(0, 'Free', Icons.crop_free),
  original(0, 'Original', Icons.crop_original),
  square(1.0, '1:1', Icons.crop_square),
  ratio4_3(4.0 / 3.0, '4:3', Icons.aspect_ratio),
  ratio3_4(3.0 / 4.0, '3:4', Icons.aspect_ratio),
  ratio16_9(16.0 / 9.0, '16:9', Icons.tab),
  ratio9_16(9.0 / 16.0, '9:16', Icons.smartphone),
  ratioA4(1.0 / 1.414, 'A4', Icons.description);

  final double ratio;
  final String label;
  final IconData icon;

  const CropAspectRatio(this.ratio, this.label, this.icon);
}

/// Crop controller for managing crop state and history
class CropController extends ChangeNotifier {
  CropRect _currentCrop = CropRect.full;
  CropRect _previousCrop = CropRect.full;
  List<CropRect> _history = [];
  int _historyIndex = -1;
  bool _showGrid = true;
  bool _isRotated = false;

  CropRect get currentCrop => _currentCrop;
  bool get showGrid => _showGrid;
  bool get isRotated => _isRotated;
  bool get canUndo => _historyIndex > 0;
  bool get canRedo => _historyIndex < _history.length - 1;

  void setCropRect(CropRect crop) {
    _saveToHistory();
    _currentCrop = crop;
    notifyListeners();
  }

  void setShowGrid(bool show) {
    _showGrid = show;
    notifyListeners();
  }

  void toggleRotation() {
    _isRotated = !_isRotated;
    notifyListeners();
  }

  void _saveToHistory() {
    if (_historyIndex < _history.length - 1) {
      _history = _history.sublist(0, _historyIndex + 1);
    }
    _history.add(_currentCrop);
    if (_history.length > 20) {
      _history.removeAt(0);
    } else {
      _historyIndex++;
    }
  }

  void undo() {
    if (canUndo) {
      _historyIndex--;
      _currentCrop = _history[_historyIndex];
      notifyListeners();
    }
  }

  void redo() {
    if (canRedo) {
      _historyIndex++;
      _currentCrop = _history[_historyIndex];
      notifyListeners();
    }
  }

  void reset() {
    _currentCrop = CropRect.full;
    _saveToHistory();
    notifyListeners();
  }

  void restorePrevious() {
    _currentCrop = _previousCrop;
    notifyListeners();
  }

  void saveCurrentAsPrevious() {
    _previousCrop = _currentCrop;
  }
}

/// Full-screen crop editor with modern UI
class CropScreen extends StatefulWidget {
  final String imagePath;
  final CropRect initialCrop;
  final Function(CropRect) onCropChanged;
  final VoidCallback onApply;
  final VoidCallback onReset;
  final VoidCallback onCancel;
  final CropController? controller;

  const CropScreen({
    super.key,
    required this.imagePath,
    required this.initialCrop,
    required this.onCropChanged,
    required this.onApply,
    required this.onReset,
    required this.onCancel,
    this.controller,
  });

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  ui.Image? _image;
  late CropController _cropController;
  CropAspectRatio _selectedRatio = CropAspectRatio.free;

  @override
  void initState() {
    super.initState();
    _cropController = widget.controller ?? CropController();
    _cropController.setCropRect(widget.initialCrop);
    _cropController.saveCurrentAsPrevious();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();

      if (mounted) {
        setState(() {
          _image = frame.image;
        });
      }
    } catch (e) {
      debugPrint('Error loading image: $e');
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  void _setAspectRatio(CropAspectRatio ratio) {
    if (_image == null) return;

    setState(() {
      _selectedRatio = ratio;
    });

    final ratioValue = ratio.ratio;
    final imageAspect = _image!.width / _image!.height;

    CropRect newCrop;

    if (ratioValue > 0) {
      final effectiveRatio = ratioValue / imageAspect;
      if (effectiveRatio > 1) {
        newCrop = CropRect(
          x: 0.05,
          y: (1.0 - 0.9 / effectiveRatio) / 2,
          width: 0.9,
          height: 0.9 / effectiveRatio,
        );
      } else {
        newCrop = CropRect(
          x: (1.0 - 0.9 * effectiveRatio) / 2,
          y: 0.05,
          width: 0.9 * effectiveRatio,
          height: 0.9,
        );
      }
    } else {
      newCrop = CropRect(x: 0.05, y: 0.05, width: 0.9, height: 0.9);
    }

    _cropController.setCropRect(newCrop);
    widget.onCropChanged(newCrop);
  }

  void _onApply() {
    widget.onCropChanged(_cropController.currentCrop);
    widget.onApply();
  }

  void _onReset() {
    _cropController.reset();
    widget.onCropChanged(CropRect.full);
    widget.onReset();
  }

  void _onUndo() {
    if (_cropController.canUndo) {
      _cropController.undo();
      widget.onCropChanged(_cropController.currentCrop);
    }
  }

  void _onGridToggle() {
    _cropController.setShowGrid(!_cropController.showGrid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Image preview with crop area
          Expanded(
            child: _image == null
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : _CropInteractiveArea(
                    imagePath: widget.imagePath,
                    image: _image!,
                    controller: _cropController,
                    onCropChanged: (crop) {
                      widget.onCropChanged(crop);
                    },
                  ),
          ),

          // Control panel
          _buildControlPanel(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1E1E1E),
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: widget.onCancel,
        tooltip: 'Cancel',
      ),
      title: const Text(
        'Crop',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      actions: [
        // Undo button
        IconButton(
          icon: const Icon(Icons.undo),
          onPressed: _cropController.canUndo ? _onUndo : null,
          tooltip: 'Undo',
          color: _cropController.canUndo ? Colors.white : Colors.white38,
        ),
        // Grid toggle
        IconButton(
          icon: Icon(_cropController.showGrid ? Icons.grid_on : Icons.grid_off),
          onPressed: _onGridToggle,
          tooltip: 'Toggle Grid',
          color: _cropController.showGrid ? Colors.blue : Colors.white38,
        ),
        // Reset button
        TextButton(
          onPressed: _onReset,
          child: const Text(
            'Reset',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ),
        // Apply button
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ElevatedButton(
            onPressed: _onApply,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Apply',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlPanel() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Aspect ratio selector
          _buildAspectRatioSelector(),

          // Instructions
          _buildInstructions(),
        ],
      ),
    );
  }

  Widget _buildAspectRatioSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16, bottom: 12),
            child: Text(
              'Aspect Ratio',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: CropAspectRatio.values.length,
              itemBuilder: (context, index) {
                final ratio = CropAspectRatio.values[index];
                final isSelected = _selectedRatio == ratio;

                return _AspectRatioButton(
                  ratio: ratio,
                  isSelected: isSelected,
                  onTap: () => _setAspectRatio(ratio),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.only(bottom: 20, top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app, size: 14, color: Colors.white38),
          const SizedBox(width: 6),
          Text(
            'Drag handles to resize • Pinch to zoom',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Modern aspect ratio button with icon and label
class _AspectRatioButton extends StatelessWidget {
  final CropAspectRatio ratio;
  final bool isSelected;
  final VoidCallback onTap;

  const _AspectRatioButton({
    required this.ratio,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? Colors.blue.withValues(alpha: 0.2)
              : Colors.transparent,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.white24,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              ratio.icon,
              size: 24,
              color: isSelected ? Colors.blue : Colors.white70,
            ),
            const SizedBox(height: 4),
            Text(
              ratio.label,
              style: TextStyle(
                color: isSelected ? Colors.blue : Colors.white70,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Interactive crop area with pinch-to-zoom and handles
class _CropInteractiveArea extends StatefulWidget {
  final String imagePath;
  final ui.Image image;
  final CropController controller;
  final Function(CropRect) onCropChanged;

  const _CropInteractiveArea({
    required this.imagePath,
    required this.image,
    required this.controller,
    required this.onCropChanged,
  });

  @override
  State<_CropInteractiveArea> createState() => _CropInteractiveAreaState();
}

class _CropInteractiveAreaState extends State<_CropInteractiveArea> {
  String? _activeHandle;
  CropRect _startCrop = CropRect.full;
  CropRect _localCrop = CropRect.full;
  double _scale = 1.0;
  Offset _offset = Offset.zero;

  Rect _imageDisplayRect = Rect.zero;

  @override
  void initState() {
    super.initState();
    _localCrop = widget.controller.currentCrop;
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(_CropInteractiveArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
    if (oldWidget.controller.currentCrop != widget.controller.currentCrop) {
      _localCrop = widget.controller.currentCrop;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {
        _localCrop = widget.controller.currentCrop;
      });
    }
  }

  void _calculateDisplayRect(Size screenSize) {
    final imageAspect = widget.image.width / widget.image.height;
    final screenAspect = screenSize.width / screenSize.height;

    if (screenAspect > imageAspect) {
      // Screen is wider than image - image is centered vertically
      final displayHeight =
          screenSize.height * 0.85; // Use 85% of screen height
      final displayWidth = displayHeight * imageAspect;
      _imageDisplayRect = Rect.fromLTWH(
        (screenSize.width - displayWidth) / 2,
        (screenSize.height - displayHeight) / 2,
        displayWidth,
        displayHeight,
      );
    } else {
      // Screen is taller than image - image is centered horizontally
      final displayWidth = screenSize.width * 0.95; // Use 95% of screen width
      final displayHeight = displayWidth / imageAspect;
      _imageDisplayRect = Rect.fromLTWH(
        (screenSize.width - displayWidth) / 2,
        (screenSize.height - displayHeight) / 2,
        displayWidth,
        displayHeight,
      );
    }
  }

  void _handleDragStart(DragStartDetails details, String handle) {
    _activeHandle = handle;
    _startCrop = _localCrop;
    widget.controller.saveCurrentAsPrevious();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_activeHandle == null) return;

    final screenSize = MediaQuery.of(context).size;
    _calculateDisplayRect(screenSize);

    final relativeX =
        (details.globalPosition.dx - _imageDisplayRect.left) /
        _imageDisplayRect.width;
    final relativeY =
        (details.globalPosition.dy - _imageDisplayRect.top) /
        _imageDisplayRect.height;

    CropRect newCrop;

    switch (_activeHandle) {
      case 'topLeft':
        newCrop = CropRect(
          x: relativeX.clamp(0.0, _startCrop.x + _startCrop.width - 0.1),
          y: relativeY.clamp(0.0, _startCrop.y + _startCrop.height - 0.1),
          width: (_startCrop.x + _startCrop.width - relativeX).clamp(0.1, 1.0),
          height: (_startCrop.y + _startCrop.height - relativeY).clamp(
            0.1,
            1.0,
          ),
        );
        break;
      case 'topRight':
        newCrop = CropRect(
          x: _startCrop.x,
          y: relativeY.clamp(0.0, _startCrop.y + _startCrop.height - 0.1),
          width: (relativeX - _startCrop.x).clamp(0.1, 1.0),
          height: (_startCrop.y + _startCrop.height - relativeY).clamp(
            0.1,
            1.0,
          ),
        );
        break;
      case 'bottomLeft':
        newCrop = CropRect(
          x: relativeX.clamp(0.0, _startCrop.x + _startCrop.width - 0.1),
          y: _startCrop.y,
          width: (_startCrop.x + _startCrop.width - relativeX).clamp(0.1, 1.0),
          height: (relativeY - _startCrop.y).clamp(0.1, 1.0),
        );
        break;
      case 'bottomRight':
        newCrop = CropRect(
          x: _startCrop.x,
          y: _startCrop.y,
          width: (relativeX - _startCrop.x).clamp(0.1, 1.0),
          height: (relativeY - _startCrop.y).clamp(0.1, 1.0),
        );
        break;
      default:
        newCrop = _localCrop;
    }

    if (mounted) {
      setState(() {
        _localCrop = newCrop;
      });
    }
    widget.controller.setCropRect(newCrop);
    widget.onCropChanged(newCrop);
  }

  void _handleDragEnd(DragEndDetails details) {
    _activeHandle = null;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (details.scale != 1.0) {
      setState(() {
        _scale = (_scale * details.scale).clamp(0.5, 3.0);
      });
    }
    if (details.focalPointDelta != Offset.zero) {
      setState(() {
        _offset += details.focalPointDelta;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    _calculateDisplayRect(screenSize);

    final cropScreenRect = Rect.fromLTWH(
      _imageDisplayRect.left + _localCrop.x * _imageDisplayRect.width,
      _imageDisplayRect.top + _localCrop.y * _imageDisplayRect.height,
      _localCrop.width * _imageDisplayRect.width,
      _localCrop.height * _imageDisplayRect.height,
    );

    return Stack(
      children: [
        // Image with zoom
        Center(
          child: Transform(
            transform: Matrix4.identity()
              ..translate(_offset.dx, _offset.dy)
              ..scale(_scale),
            child: Image.file(File(widget.imagePath), fit: BoxFit.contain),
          ),
        ),

        // Crop overlay
        Positioned.fill(
          child: GestureDetector(
            onScaleUpdate: _handleScaleUpdate,
            child: CustomPaint(
              painter: _CropOverlayPainter(
                cropScreenRect: cropScreenRect,
                showGrid: widget.controller.showGrid,
              ),
            ),
          ),
        ),

        // Corner handles
        _CropHandle(
          position: Offset(cropScreenRect.left, cropScreenRect.top),
          onDragStart: (details) => _handleDragStart(details, 'topLeft'),
          onDragUpdate: _handleDragUpdate,
          onDragEnd: _handleDragEnd,
        ),
        _CropHandle(
          position: Offset(cropScreenRect.right, cropScreenRect.top),
          onDragStart: (details) => _handleDragStart(details, 'topRight'),
          onDragUpdate: _handleDragUpdate,
          onDragEnd: _handleDragEnd,
        ),
        _CropHandle(
          position: Offset(cropScreenRect.left, cropScreenRect.bottom),
          onDragStart: (details) => _handleDragStart(details, 'bottomLeft'),
          onDragUpdate: _handleDragUpdate,
          onDragEnd: _handleDragEnd,
        ),
        _CropHandle(
          position: Offset(cropScreenRect.right, cropScreenRect.bottom),
          onDragStart: (details) => _handleDragStart(details, 'bottomRight'),
          onDragUpdate: _handleDragUpdate,
          onDragEnd: _handleDragEnd,
        ),
      ],
    );
  }
}

/// Modern crop handle with enhanced styling
class _CropHandle extends StatelessWidget {
  final Offset position;
  final Function(DragStartDetails) onDragStart;
  final Function(DragUpdateDetails) onDragUpdate;
  final Function(DragEndDetails) onDragEnd;

  const _CropHandle({
    required this.position,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx - 24,
      top: position.dy - 24,
      width: 48,
      height: 48,
      child: GestureDetector(
        onPanStart: onDragStart,
        onPanUpdate: onDragUpdate,
        onPanEnd: onDragEnd,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.15),
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: Colors.blue.shade400, width: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Enhanced crop overlay painter with grid option
class _CropOverlayPainter extends CustomPainter {
  final Rect cropScreenRect;
  final bool showGrid;

  _CropOverlayPainter({required this.cropScreenRect, required this.showGrid});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw dark overlay outside crop area
    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;

    // Left
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, cropScreenRect.left, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), overlayPaint);
    canvas.restore();

    // Right
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(
        cropScreenRect.right,
        0,
        size.width - cropScreenRect.right,
        size.height,
      ),
    );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), overlayPaint);
    canvas.restore();

    // Top
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, cropScreenRect.top));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), overlayPaint);
    canvas.restore();

    // Bottom
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(
        0,
        cropScreenRect.bottom,
        size.width,
        size.height - cropScreenRect.bottom,
      ),
    );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), overlayPaint);
    canvas.restore();

    // Draw grid overlay if enabled
    if (showGrid) {
      _drawGrid(canvas, cropScreenRect);
    }

    // White border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawRect(cropScreenRect, borderPaint);
  }

  void _drawGrid(Canvas canvas, Rect rect) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Rule of thirds
    final thirdWidth = rect.width / 3;
    final thirdHeight = rect.height / 3;

    // Vertical lines
    canvas.drawLine(
      Offset(rect.left + thirdWidth, rect.top),
      Offset(rect.left + thirdWidth, rect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(rect.left + 2 * thirdWidth, rect.top),
      Offset(rect.left + 2 * thirdWidth, rect.bottom),
      gridPaint,
    );

    // Horizontal lines
    canvas.drawLine(
      Offset(rect.left, rect.top + thirdHeight),
      Offset(rect.right, rect.top + thirdHeight),
      gridPaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.top + 2 * thirdHeight),
      Offset(rect.right, rect.top + 2 * thirdHeight),
      gridPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
