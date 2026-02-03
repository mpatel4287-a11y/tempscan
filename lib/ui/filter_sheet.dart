// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../temp_storage/temp_image_manager.dart';

/// Filter types with icons and display names
enum ImageFilterType {
  none('Original', Icons.auto_fix_high, Color(0x00000000)),
  grayscale('B&W', Icons.filter_b_and_w, Color(0xFF808080)),
  sepia('Sepia', Icons.filter_vintage, Color(0xFF704214)),
  brightness('Bright', Icons.wb_sunny, Color(0xFFFFFDE7)),
  contrast('Contrast', Icons.contrast, Color(0xFF607D8B)),
  saturation('Vivid', Icons.palette, Color(0xFFF8BBD9)),
  cool('Cool', Icons.ac_unit, Color(0xFFB2EBF2)),
  warm('Warm', Icons.whatshot, Color(0xFFFFCC80)),
  modernPro('Modern Pro', Icons.auto_awesome, Color(0xFFE3F2FD)),
  vintageDoc('Vintage Doc', Icons.history_edu, Color(0xFFF3E5F5));

  final String label;
  final IconData icon;
  final Color overlayColor;

  const ImageFilterType(this.label, this.icon, this.overlayColor);
}

/// Simple color filter application widget
class FilterPreviewWidget extends StatefulWidget {
  final String imagePath;
  final ImageFilter filter;
  final Map<String, double> filterValues;
  final double rotation;

  const FilterPreviewWidget({
    super.key,
    required this.imagePath,
    this.filter = ImageFilter.none,
    this.filterValues = const {},
    this.rotation = 0,
  });

  @override
  State<FilterPreviewWidget> createState() => _FilterPreviewWidgetState();
}

class _FilterPreviewWidgetState extends State<FilterPreviewWidget> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(FilterPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _loadImage();
    }
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

  ColorFilter? _getColorFilter() {
    switch (widget.filter) {
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
        final brightness = widget.filterValues['value'] ?? 0.0;
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
        final contrast = widget.filterValues['value'] ?? 0.0;
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
        final saturation = widget.filterValues['value'] ?? 0.0;
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
      case ImageFilter.modernPro:
        return const ColorFilter.matrix([
          1.2, 0.1, 0.1, 0, -20,
          0.1, 1.2, 0.1, 0, -20,
          0.1, 0.1, 1.2, 0, -20,
          0, 0, 0, 1, 0,
        ]);
      case ImageFilter.vintageDoc:
        return const ColorFilter.matrix([
          0.9, 0.5, 0.1, 0, 0,
          0.3, 0.8, 0.1, 0, 0,
          0.2, 0.3, 0.5, 0, 0,
          0, 0, 0, 1, 0,
        ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_image == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Transform.rotate(
      angle: widget.rotation * 3.14159 / 180,
      child: ColorFiltered(
        colorFilter:
            _getColorFilter() ??
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
        child: Image.file(
          File(widget.imagePath),
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }
}

/// Bottom sheet for filter selection with modern UI
class FilterSheet extends StatefulWidget {
  final String imagePath;
  final ImageFilter currentFilter;
  final Map<String, double> currentFilterValues;
  final Function(ImageFilter, Map<String, double>) onFilterSelected;
  final VoidCallback onCancel;

  const FilterSheet({
    super.key,
    required this.imagePath,
    required this.currentFilter,
    required this.currentFilterValues,
    required this.onFilterSelected,
    required this.onCancel,
  });

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  ImageFilter _selectedFilter = ImageFilter.none;
  Map<String, double> _filterValues = {};
  final GlobalKey _previewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.currentFilter;
    _filterValues = Map.from(widget.currentFilterValues);
  }

  void _selectFilter(ImageFilter filter) {
    setState(() {
      _selectedFilter = filter;
      if (filter == ImageFilter.none) {
        _filterValues = {};
      } else if (filter == ImageFilter.brightness ||
          filter == ImageFilter.contrast ||
          filter == ImageFilter.saturation) {
        _filterValues = {'value': _filterValues['value'] ?? 0.0};
      }
    });
  }

  void _adjustFilterValue(double value) {
    setState(() {
      _filterValues = {'value': value.clamp(-1.0, 1.0)};
    });
  }

  ImageFilterType _getFilterType(ImageFilter filter) {
    switch (filter) {
      case ImageFilter.none:
        return ImageFilterType.none;
      case ImageFilter.grayscale:
        return ImageFilterType.grayscale;
      case ImageFilter.sepia:
        return ImageFilterType.sepia;
      case ImageFilter.brightness:
        return ImageFilterType.brightness;
      case ImageFilter.contrast:
        return ImageFilterType.contrast;
      case ImageFilter.saturation:
        return ImageFilterType.saturation;
      case ImageFilter.modernPro:
        return ImageFilterType.modernPro;
      case ImageFilter.vintageDoc:
        return ImageFilterType.vintageDoc;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header with handle
          _buildHeader(),

          // Filter preview
          Expanded(flex: 4, child: _buildPreview()),

          // Slider for adjustable filters
          if (_selectedFilter == ImageFilter.brightness ||
              _selectedFilter == ImageFilter.contrast ||
              _selectedFilter == ImageFilter.saturation)
            _buildSliderControl(),

          // Filter options
          Expanded(flex: 3, child: _buildFilterGrid()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF252525),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: widget.onCancel,
            icon: const Icon(Icons.close, color: Colors.white70),
          ),
          const Text(
            'Filter',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          ElevatedButton(
            onPressed: () {
              widget.onFilterSelected(_selectedFilter, _filterValues);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'Apply',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24, width: 1),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FilterPreviewWidget(
          key: _previewKey,
          imagePath: widget.imagePath,
          filter: _selectedFilter,
          filterValues: _filterValues,
        ),
      ),
    );
  }

  Widget _buildSliderControl() {
    final value = _filterValues['value'] ?? 0.0;
    final filterType = _getFilterType(_selectedFilter);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(filterType.icon, size: 20, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    filterType.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Text(
                value.toStringAsFixed(2),
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: value,
            min: -1.0,
            max: 1.0,
            divisions: 40,
            activeColor: Colors.blue,
            inactiveColor: Colors.white24,
            onChanged: _adjustFilterValue,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                '-1.0',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
              Text('0', style: TextStyle(color: Colors.white38, fontSize: 10)),
              Text(
                '+1.0',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterGrid() {
    final filterTypes = ImageFilterType.values;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 12),
            child: Text(
              'Choose Filter',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.85,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: filterTypes.length,
              itemBuilder: (context, index) {
                final filterType = filterTypes[index];
                final isSelected =
                    _selectedFilter == _getFilterEnum(filterType);

                return _FilterButton(
                  filterType: filterType,
                  imagePath: widget.imagePath,
                  isSelected: isSelected,
                  onTap: () => _selectFilter(_getFilterEnum(filterType)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  ImageFilter _getFilterEnum(ImageFilterType type) {
    switch (type) {
      case ImageFilterType.none:
        return ImageFilter.none;
      case ImageFilterType.grayscale:
        return ImageFilter.grayscale;
      case ImageFilterType.sepia:
        return ImageFilter.sepia;
      case ImageFilterType.brightness:
        return ImageFilter.brightness;
      case ImageFilterType.contrast:
        return ImageFilter.contrast;
      case ImageFilterType.saturation:
        return ImageFilter.saturation;
      case ImageFilterType.cool:
        return ImageFilter.brightness; // Map to brightness for now
      case ImageFilterType.warm:
        return ImageFilter.brightness; // Map to brightness for now
      case ImageFilterType.modernPro:
        return ImageFilter.modernPro;
      case ImageFilterType.vintageDoc:
        return ImageFilter.vintageDoc;
    }
  }
}

/// Modern filter button with preview
class _FilterButton extends StatelessWidget {
  final ImageFilterType filterType;
  final String imagePath;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterButton({
    required this.filterType,
    required this.imagePath,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? Colors.blue.withValues(alpha: 0.15)
              : Colors.transparent,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.white24,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Preview container
            Container(
              width: 56,
              height: 56,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.white24,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: FileImage(File(imagePath)),
                  fit: BoxFit.cover,
                ),
              ),
              child: filterType.overlayColor != Colors.transparent
                  ? Container(
                      decoration: BoxDecoration(
                        color: filterType.overlayColor.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    )
                  : null,
            ),
            // Label
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  filterType.icon,
                  size: 12,
                  color: isSelected ? Colors.blue : Colors.white54,
                ),
                const SizedBox(width: 4),
                Text(
                  filterType.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected ? Colors.blue : Colors.white54,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
