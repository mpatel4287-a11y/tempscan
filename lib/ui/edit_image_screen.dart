// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import '../temp_storage/temp_image_manager.dart';
import 'crop_screen.dart';
import 'filter_sheet.dart';
import 'rotate_sheet.dart';

/// Main edit image screen with all tools
/// Opens when user taps/holds on any image in review screen
class EditImageScreen extends StatefulWidget {
  final int pageIndex;

  const EditImageScreen({super.key, required this.pageIndex});

  @override
  State<EditImageScreen> createState() => _EditImageScreenState();
}

class _EditImageScreenState extends State<EditImageScreen> {
  final _manager = TempImageManager();

  late ScannedPage _page;
  late int _currentRotation;
  late ImageFilter _currentFilter;
  late Map<String, double> _currentFilterValues;
  late CropRect _currentCropRect;

  bool _showCropScreen = false;
  bool _showFilterSheet = false;
  bool _showRotateSheet = false;

  @override
  void initState() {
    super.initState();
    _loadPageData();
  }

  void _loadPageData() {
    final page = _manager.getPage(widget.pageIndex);
    if (page != null) {
      _page = page;
      _currentRotation = page.rotation;
      _currentFilter = page.filter;
      _currentFilterValues = Map.from(page.filterValues);
      _currentCropRect = page.cropRect;
    }
  }

  void _updatePageData() {
    _manager.rotatePage(widget.pageIndex, _currentRotation - _page.rotation);
    _manager.applyFilter(
      widget.pageIndex,
      _currentFilter,
      _currentFilterValues,
    );
    _manager.applyCrop(widget.pageIndex, _currentCropRect);
  }

  Future<void> _deleteImage() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Image?'),
        content: const Text('This image will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _manager.removePage(_page);
      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate deletion
      }
    }
  }

  void _showCrop() {
    setState(() {
      _showCropScreen = true;
    });
  }

  void _hideCrop() {
    setState(() {
      _showCropScreen = false;
    });
  }

  void _onCropChanged(CropRect newCrop) {
    _currentCropRect = newCrop;
    _updatePageData();
  }

  void _onCropApplied() {
    _hideCrop();
  }

  void _onCropReset() {
    _currentCropRect = CropRect.full;
    _updatePageData();
  }

  void _showFilter() {
    setState(() {
      _showFilterSheet = true;
    });
  }

  void _hideFilter() {
    setState(() {
      _showFilterSheet = false;
    });
  }

  void _onFilterSelected(ImageFilter filter, Map<String, double> values) {
    _currentFilter = filter;
    _currentFilterValues = values;
    _updatePageData();
  }

  void _showRotate() {
    setState(() {
      _showRotateSheet = true;
    });
  }

  void _hideRotate() {
    setState(() {
      _showRotateSheet = false;
    });
  }

  void _onRotated(int degrees) {
    _currentRotation = (_currentRotation + degrees) % 360;
    if (_currentRotation < 0) _currentRotation += 360;
    _updatePageData();
  }

  ColorFilter? _getColorFilter() {
    switch (_currentFilter) {
      case ImageFilter.none:
        return null;
      case ImageFilter.grayscale:
        return const ColorFilter.matrix([
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case ImageFilter.sepia:
        return const ColorFilter.matrix([
          0.393,
          0.769,
          0.189,
          0,
          0,
          0.349,
          0.686,
          0.168,
          0,
          0,
          0.272,
          0.534,
          0.131,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case ImageFilter.brightness:
        final brightness = _currentFilterValues['value'] ?? 0.0;
        final adjusted = brightness * 128;
        return ColorFilter.matrix([
          1,
          0,
          0,
          0,
          adjusted,
          0,
          1,
          0,
          0,
          adjusted,
          0,
          0,
          1,
          0,
          adjusted,
          0,
          0,
          0,
          1,
          0,
        ]);
      case ImageFilter.contrast:
        final contrast = _currentFilterValues['value'] ?? 0.0;
        final factor = (contrast + 1) * contrast;
        return ColorFilter.matrix([
          factor,
          0,
          0,
          0,
          128 * (1 - factor),
          0,
          factor,
          0,
          0,
          128 * (1 - factor),
          0,
          0,
          factor,
          0,
          128 * (1 - factor),
          0,
          0,
          0,
          1,
          0,
        ]);
      case ImageFilter.saturation:
        final saturation = _currentFilterValues['value'] ?? 0.0;
        final luminance = 0.2126 + 0.7152 + 0.0722;
        return ColorFilter.matrix([
          (1 - saturation) * 0.2126 + saturation,
          (1 - saturation) * 0.7152,
          (1 - saturation) * 0.0722,
          0,
          0,
          (1 - saturation) * 0.2126,
          (1 - saturation) * 0.7152 + saturation,
          (1 - saturation) * 0.0722,
          0,
          0,
          (1 - saturation) * 0.2126,
          (1 - saturation) * 0.7152,
          (1 - saturation) * 0.0722 + saturation,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showCropScreen) {
      return CropScreen(
        imagePath: _page.file.path,
        initialCrop: _currentCropRect,
        onCropChanged: _onCropChanged,
        onApply: _onCropApplied,
        onReset: _onCropReset,
        onCancel: _hideCrop,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Column(
            children: [
              // Top bar with return icon
              _buildTopBar(),

              // Image preview (takes remaining space)
              Expanded(child: Center(child: _buildImagePreview())),

              // Bottom toolbar with options
              _buildBottomToolbar(),
            ],
          ),

          // Filter sheet overlay
          if (_showFilterSheet)
            GestureDetector(
              onTap: _hideFilter,
              child: Container(
                color: Colors.black54,
                child: FilterSheet(
                  imagePath: _page.file.path,
                  currentFilter: _currentFilter,
                  currentFilterValues: _currentFilterValues,
                  onFilterSelected: _onFilterSelected,
                  onCancel: _hideFilter,
                ),
              ),
            ),

          // Rotate sheet overlay
          if (_showRotateSheet)
            GestureDetector(
              onTap: _hideRotate,
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: _hideRotate,
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                              const Text(
                                'Rotate',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 64),
                            ],
                          ),
                        ),
                        RotateSheet(
                          imagePath: _page.file.path,
                          currentRotation: _currentRotation,
                          onRotate: (degrees) {
                            _onRotated(degrees);
                            _hideRotate();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          // Return icon (top-left)
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              _updatePageData();
              Navigator.pop(context);
            },
          ),
          const Spacer(),
          // Page indicator
          Text(
            'Page ${widget.pageIndex + 1}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    final colorFilter = _getColorFilter();

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 3.0,
      child: Transform.rotate(
        angle: _currentRotation * 3.14159 / 180,
        child: ClipRect(
          child: ColorFiltered(
            colorFilter:
                colorFilter ??
                const ColorFilter.matrix([
                  1,
                  0,
                  0,
                  0,
                  0,
                  0,
                  1,
                  0,
                  0,
                  0,
                  0,
                  0,
                  1,
                  0,
                  0,
                  0,
                  0,
                  0,
                  1,
                  0,
                ]),
            child: Image.file(_page.file, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.9)],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildToolButton(icon: Icons.crop, label: 'Crop', onTap: _showCrop),
          _buildToolButton(
            icon: Icons.filter_alt,
            label: 'Filter',
            onTap: _showFilter,
          ),
          _buildToolButton(
            icon: Icons.delete,
            label: 'Delete',
            onTap: _deleteImage,
            color: Colors.red,
          ),
          _buildToolButton(
            icon: Icons.rotate_right,
            label: 'Rotate',
            onTap: _showRotate,
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: (color ?? Colors.white).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color ?? Colors.white, size: 26),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: color ?? Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
