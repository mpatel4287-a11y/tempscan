import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import '../temp_storage/temp_image_manager.dart';
import 'review_screen.dart';

class AutoEnhanceScreen extends StatefulWidget {
  const AutoEnhanceScreen({super.key});

  @override
  State<AutoEnhanceScreen> createState() => _AutoEnhanceScreenState();
}

class _AutoEnhanceScreenState extends State<AutoEnhanceScreen> {
  final _manager = TempImageManager();
  List<File> _selectedImages = [];
  bool _isProcessing = false;
  double _brightness = 0;
  double _contrast = 1.0;
  double _sharpness = 0;
  int _currentIndex = 0;
  double _comparisonPosition = 0.5;
  Uint8List? _enhancedBytes;

  Future<void> _pickImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
      if (result != null) {
        setState(() {
          _selectedImages = result.files.map((file) => File(file.path!)).toList();
          _currentIndex = 0;
          _enhancedBytes = null;
          _resetAdjustments();
        });
      }
    } catch (e) {
      if (mounted) _showError('Pick images error: $e');
    }
  }

  void _resetAdjustments() {
    _brightness = 0;
    _contrast = 1.0;
    _sharpness = 0;
    _comparisonPosition = 0.5;
  }

  Future<void> _applyEnhancements() async {
    if (_selectedImages.isEmpty) return;
    setState(() => _isProcessing = true);
    try {
      await _manager.clearAll();
      for (final image in _selectedImages) {
        final bytes = await image.readAsBytes();
        final processedBytes = _processImage(bytes);
        final tempFile = await _manager.createTempImageFile();
        await tempFile.writeAsBytes(processedBytes);
        _manager.addImage(tempFile);
      }
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ReviewScreen()));
    } catch (e) {
      if (mounted) _showError('Enhancement error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Uint8List _processImage(Uint8List imageBytes) {
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;
    if (_brightness != 0 || _contrast != 1.0) {
      image = _adjustBrightnessContrast(image, _brightness, _contrast);
    }
    if (_sharpness > 0) image = _sharpen(image, _sharpness);
    return Uint8List.fromList(img.encodeJpg(image, quality: 85));
  }

  img.Image _adjustBrightnessContrast(img.Image image, double brightness, double contrast) {
    final factor = (259 * (contrast * 255 + 255)) / (255 * (259 - contrast * 255));
    for (final pixel in image) {
      pixel.r = (factor * (pixel.r + brightness - 128) + 128).round().clamp(0, 255);
      pixel.g = (factor * (pixel.g + brightness - 128) + 128).round().clamp(0, 255);
      pixel.b = (factor * (pixel.b + brightness - 128) + 128).round().clamp(0, 255);
    }
    return image;
  }

  img.Image _sharpen(img.Image image, double amount) {
    final blurred = img.copyResize(image, width: (image.width * 0.5).round(), height: (image.height * 0.5).round());
    final resized = img.copyResize(blurred, width: image.width, height: image.height);
    for (final pixel in image) {
      final bP = resized.getPixel(pixel.x, pixel.y);
      pixel.r = (pixel.r + (pixel.r - bP.r) * amount).round().clamp(0, 255);
      pixel.g = (pixel.g + (pixel.g - bP.g) * amount).round().clamp(0, 255);
      pixel.b = (pixel.b + (pixel.b - bP.b) * amount).round().clamp(0, 255);
    }
    return image;
  }

  void _updatePreview() async {
    if (_selectedImages.isEmpty) return;
    try {
      final bytes = await _selectedImages[_currentIndex].readAsBytes();
      final processed = _processImage(bytes);
      setState(() => _enhancedBytes = processed);
    } catch (e) {
      debugPrint('Preview error: $e');
    }
  }

  void _showError(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.redAccent));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Enhance Tool', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_selectedImages.isNotEmpty) IconButton(icon: const Icon(Icons.add_photo_alternate_outlined), onPressed: _pickImages),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPreviewSection(),
                  if (_selectedImages.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _buildAdjustmentsSection(),
                  ],
                ],
              ),
            ),
          ),
          if (_selectedImages.isNotEmpty) _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildPreviewSection() {
    if (_selectedImages.isEmpty) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 60),
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), shape: BoxShape.circle),
              child: Icon(Icons.auto_fix_high_rounded, size: 64, color: Colors.blueAccent.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 24),
            const Text('Auto Enhance', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Quickly fix brightness, contrast and sharpness\nacross all selected images.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14)),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.add_rounded),
              label: const Text('SELECT IMAGES'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 300,
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(child: Image.file(_selectedImages[_currentIndex], fit: BoxFit.contain)),
            if (_enhancedBytes != null)
              Positioned(
                left: 0, top: 0, bottom: 0,
                width: (MediaQuery.of(context).size.width - 48) * _comparisonPosition,
                child: ClipRect(child: Image.memory(_enhancedBytes!, fit: BoxFit.contain)),
              ),
            Positioned(
              left: 0, right: 0, bottom: 16,
              child: _buildComparisonSlider(),
            ),
            Positioned(
              top: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                child: Text('${_currentIndex + 1}/${_selectedImages.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
            if (_selectedImages.length > 1) ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildNavBtn(Icons.chevron_left, _currentIndex > 0 ? () => setState(() { _currentIndex--; _enhancedBytes = null; }) : null),
                      _buildNavBtn(Icons.chevron_right, _currentIndex < _selectedImages.length -1 ? () => setState(() { _currentIndex++; _enhancedBytes = null; }) : null),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNavBtn(IconData i, VoidCallback? onTap) {
    return Container(
      decoration: BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
      child: IconButton(icon: Icon(i, color: onTap == null ? Colors.white24 : Colors.white), onPressed: onTap),
    );
  }

  Widget _buildComparisonSlider() {
    return Center(
      child: Container(
        width: 140, height: 32,
        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(16)),
        child: SliderTheme(
          data: SliderThemeData(trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), activeTrackColor: Colors.white, inactiveTrackColor: Colors.white24),
          child: Slider(value: _comparisonPosition, onChanged: (v) => setState(() => _comparisonPosition = v)),
        ),
      ),
    );
  }

  Widget _buildAdjustmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Presets', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildPresetChip('Original', 0, 1.0, 0),
              _buildPresetChip('Document', 40, 1.3, 0.4),
              _buildPresetChip('Bright', 60, 1.0, 0),
              _buildPresetChip('Vivid', 20, 1.5, 0.2),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Text('Fine Tune', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _buildSliderItem(Icons.light_mode_outlined, 'Brightness', _brightness, -100, 100, (v) { _brightness = v; _updatePreview(); }),
        const SizedBox(height: 24),
        _buildSliderItem(Icons.contrast_rounded, 'Contrast', _contrast, 0.5, 2.0, (v) { _contrast = v; _updatePreview(); }),
        const SizedBox(height: 24),
        _buildSliderItem(Icons.shutter_speed_rounded, 'Sharpness', _sharpness, 0, 3, (v) { _sharpness = v; _updatePreview(); }),
      ],
    );
  }

  Widget _buildPresetChip(String label, double b, double c, double s) {
    bool isSelected = _brightness == b && _contrast == c && _sharpness == s;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (v) {
          setState(() { _brightness = b; _contrast = c; _sharpness = s; });
          _updatePreview();
        },
        backgroundColor: Colors.white.withValues(alpha: 0.05),
        selectedColor: Colors.blueAccent,
        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white60, fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide.none),
      ),
    );
  }

  Widget _buildSliderItem(IconData i, String t, double v, double min, double max, ValueChanged<double> onC) {
    return Column(
      children: [
        Row(
          children: [
            Icon(i, size: 18, color: Colors.blueAccent),
            const SizedBox(width: 8),
            Text(t, style: const TextStyle(color: Colors.white, fontSize: 14)),
            const Spacer(),
            Text(v.toStringAsFixed(1), style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(activeTrackColor: Colors.blueAccent, inactiveTrackColor: Colors.white10, thumbColor: Colors.white),
          child: Slider(value: v, min: min, max: max, onChanged: (val) => setState(() => onC(val))),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05)))),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isProcessing ? null : () => setState(() { _resetAdjustments(); _enhancedBytes = null; }),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('RESET'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF00D2FF), Color(0xFF3A7BD5)]), borderRadius: BorderRadius.circular(16)),
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _applyEnhancements,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: _isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('ENHANCE ALL', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
