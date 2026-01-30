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
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result != null) {
        setState(() {
          _selectedImages = result.files
              .map((file) => File(file.path!))
              .toList();
          _currentIndex = 0;
          _enhancedBytes = null;
          _resetAdjustments();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking images: $e')));
      }
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

      for (int i = 0; i < _selectedImages.length; i++) {
        final image = _selectedImages[i];
        
        // Check if we have enhancements to apply
        // For simplicity in this edit, we re-process to get the enhanced bytes if needed
        // In a real app we might optimize this to avoid re-processing 
        
        final bytes = await image.readAsBytes();
        
        // We need to re-apply the current settings to this image
        // BUT current settings (_brightness, etc) only apply to the current preview image.
        // This logic implies we apply the *current slider settings* to ALL images?
        // Or should we process them one by one?
        // The UI shows Global settings. So we apply global settings to all images.
        
        final processedBytes = _processImage(bytes);
        
        // always save as new temp file
        final tempFile = await _manager.createTempImageFile();
        await tempFile.writeAsBytes(processedBytes);
        
        _manager.addImage(tempFile);
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ReviewScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error enhancing images: $e')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Uint8List _processImage(Uint8List imageBytes) {
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;

    // Apply brightness and contrast
    if (_brightness != 0 || _contrast != 1.0) {
      image = _adjustBrightnessContrast(image, _brightness, _contrast);
    }

    // Apply sharpness using gaussian blur based approach
    if (_sharpness > 0) {
      image = _sharpen(image, _sharpness);
    }

    return Uint8List.fromList(img.encodeJpg(image, quality: 85));
  }

  img.Image _adjustBrightnessContrast(
    img.Image image,
    double brightness,
    double contrast,
  ) {
    final factor =
        (259 * (contrast * 255 + 255)) / (255 * (259 - contrast * 255));
    final brightnessOffset = brightness;

    for (final pixel in image) {
      int r = (factor * (pixel.r + brightnessOffset - 128) + 128).round().clamp(
        0,
        255,
      );
      int g = (factor * (pixel.g + brightnessOffset - 128) + 128).round().clamp(
        0,
        255,
      );
      int b = (factor * (pixel.b + brightnessOffset - 128) + 128).round().clamp(
        0,
        255,
      );

      pixel.r = r;
      pixel.g = g;
      pixel.b = b;
    }

    return image;
  }

  img.Image _sharpen(img.Image image, double amount) {
    // Create a copy for the blurred version
    final blurred = img.copyResize(
      image,
      width: (image.width * 0.5).round(),
      height: (image.height * 0.5).round(),
    );
    final resized = img.copyResize(
      blurred,
      width: image.width,
      height: image.height,
    );

    final sharpenAmount = amount.clamp(0.0, 5.0);

    for (final pixel in image) {
      final origR = pixel.r;
      final origG = pixel.g;
      final origB = pixel.b;

      final blurR = resized.getPixel(pixel.x, pixel.y).r;
      final blurG = resized.getPixel(pixel.x, pixel.y).g;
      final blurB = resized.getPixel(pixel.x, pixel.y).b;

      int r = (origR + (origR - blurR) * sharpenAmount).round().clamp(0, 255);
      int g = (origG + (origG - blurG) * sharpenAmount).round().clamp(0, 255);
      int b = (origB + (origB - blurB) * sharpenAmount).round().clamp(0, 255);

      pixel.r = r;
      pixel.g = g;
      pixel.b = b;
    }

    return image;
  }

  void _updatePreview() async {
    if (_selectedImages.isEmpty) return;

    try {
      final bytes = await _selectedImages[_currentIndex].readAsBytes();
      final processed = _processImage(bytes);

      setState(() {
        _enhancedBytes = processed;
      });
    } catch (e) {
      debugPrint('Error updating preview: $e');
    }
  }

  Widget _buildImagePreview() {
    if (_selectedImages.isEmpty) {
      return GestureDetector(
        onTap: _pickImages,
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_photo_alternate,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 8),
              Text(
                'Tap to select images',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        height: 250,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.file(
                      _selectedImages[_currentIndex],
                      fit: BoxFit.contain,
                    ),
                  ),
                  if (_enhancedBytes != null)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width:
                          (MediaQuery.of(context).size.width - 32) *
                          _comparisonPosition,
                      child: ClipRect(
                        child: Image.memory(
                          _enhancedBytes!,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            if (_enhancedBytes != null)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.compare, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'After',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            if (_enhancedBytes != null)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Before',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),

            if (_enhancedBytes != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 8,
                child: Center(
                  child: Container(
                    width: 200,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.compare_arrows,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 2,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 8,
                              ),
                              activeTrackColor: Colors.white,
                              inactiveTrackColor: Colors.white30,
                            ),
                            child: Slider(
                              value: _comparisonPosition,
                              min: 0,
                              max: 1,
                              onChanged: (value) {
                                setState(() => _comparisonPosition = value);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            Positioned(
              top: 8,
              right: _enhancedBytes != null ? 100 : 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_currentIndex + 1}/${_selectedImages.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),

            if (_selectedImages.length > 1) ...[
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                    onPressed: _currentIndex > 0
                        ? () {
                            setState(() {
                              _currentIndex--;
                              _resetAdjustments();
                              _enhancedBytes = null;
                            });
                          }
                        : null,
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    icon: const Icon(Icons.chevron_right, color: Colors.white),
                    onPressed: _currentIndex < _selectedImages.length - 1
                        ? () {
                            setState(() {
                              _currentIndex++;
                              _resetAdjustments();
                              _enhancedBytes = null;
                            });
                          }
                        : null,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Auto Enhance'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (_selectedImages.isNotEmpty)
            TextButton(onPressed: _pickImages, child: const Text('Change')),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImagePreview(),
                  const SizedBox(height: 24),
                  if (_selectedImages.isNotEmpty) ...[
                    const Text(
                      'Quick Presets',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildPresetChip('Original', () {
                            setState(() {
                              _resetAdjustments();
                              _enhancedBytes = null;
                            });
                          }),
                          const SizedBox(width: 8),
                          _buildPresetChip('Document', () {
                            setState(() {
                              _brightness = 30;
                              _contrast = 1.2;
                              _sharpness = 0.5;
                            });
                            _updatePreview();
                          }),
                          const SizedBox(width: 8),
                          _buildPresetChip('Bright', () {
                            setState(() {
                              _brightness = 50;
                              _contrast = 1.0;
                              _sharpness = 0;
                            });
                            _updatePreview();
                          }),
                          const SizedBox(width: 8),
                          _buildPresetChip('Sharp', () {
                            setState(() {
                              _brightness = 0;
                              _contrast = 1.0;
                              _sharpness = 1.5;
                            });
                            _updatePreview();
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Manual Adjustments',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSlider(
                      icon: Icons.brightness_6,
                      title: 'Brightness',
                      value: _brightness,
                      min: -100,
                      max: 100,
                      onChanged: (value) {
                        setState(() => _brightness = value);
                        _updatePreview();
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildSlider(
                      icon: Icons.contrast,
                      title: 'Contrast',
                      value: _contrast,
                      min: 0.5,
                      max: 2.0,
                      onChanged: (value) {
                        setState(() => _contrast = value);
                        _updatePreview();
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildSlider(
                      icon: Icons.blur_on,
                      title: 'Sharpness',
                      value: _sharpness,
                      min: 0,
                      max: 3,
                      onChanged: (value) {
                        setState(() => _sharpness = value);
                        _updatePreview();
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _resetAdjustments();
                            _enhancedBytes = null;
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset All'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_selectedImages.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isProcessing ? null : _pickImages,
                      child: const Text('Add More'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _applyEnhancements,
                      child: _isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Apply & Continue'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Colors.grey[100],
      labelStyle: const TextStyle(fontSize: 13),
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildSlider({
    required IconData icon,
    required String title,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Text(
              value.toStringAsFixed(value % 1 == 0 ? 0 : 1),
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}
