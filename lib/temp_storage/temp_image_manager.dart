import 'dart:io';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';

/// Filter types available for images
enum ImageFilter { none, grayscale, sepia, brightness, contrast, saturation, modernPro, vintageDoc }

/// Annotation types
enum AnnotationType { highlight, underline, pen, square, circle, arrow, text }

/// Individual annotation data
class Annotation {
  final String id;
  final List<ui.Offset> points;
  final ui.Color color;
  final double strokeWidth;
  final AnnotationType type;
  final String? text;
  ui.Offset? position; // Used for text or shape displacement

  Annotation({
    String? id,
    required this.points,
    required this.color,
    this.strokeWidth = 4.0,
    required this.type,
    this.text,
    this.position,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();
}

/// Crop rectangle (normalized 0-1 coordinates)
class CropRect {
  final double x;
  final double y;
  final double width;
  final double height;

  const CropRect({
    this.x = 0.0,
    this.y = 0.0,
    this.width = 1.0,
    this.height = 1.0,
  });

  /// Full image crop (no cropping)
  static const CropRect full = CropRect(
    x: 0.0,
    y: 0.0,
    width: 1.0,
    height: 1.0,
  );

  /// Check if this is a full crop (no actual cropping)
  bool get isFull => x == 0 && y == 0 && width == 1.0 && height == 1.0;

  /// Convert to absolute coordinates for an image of given size
  ui.Rect toAbsolute(ui.Image image) {
    return ui.Rect.fromLTWH(
      x * image.width,
      y * image.height,
      width * image.width,
      height * image.height,
    );
  }

  /// Create from absolute coordinates, converting to normalized values
  static CropRect fromAbsolute(ui.Rect absolute, ui.Image image) {
    return CropRect(
      x: absolute.left / image.width,
      y: absolute.top / image.height,
      width: absolute.width / image.width,
      height: absolute.height / image.height,
    );
  }

  CropRect copyWith({double? x, double? y, double? width, double? height}) {
    return CropRect(
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}

/// Represents a scanned image with metadata for rotation, filters, and custom name
class ScannedPage {
  final File file;
  int rotation; // Rotation in degrees (0, 90, 180, 270)
  String? customName;
  ImageFilter filter;
  Map<String, double>
  filterValues; // For adjustable filters like brightness, contrast
  CropRect cropRect; // Crop rectangle (normalized 0-1 coordinates)
  String? signaturePath; // Path to signature image
  ui.Offset? signaturePosition; // Normalized position (0-1)
  List<Annotation> annotations; // List of user annotations
  double clarity; // 0.0 to 1.0
  double noiseReduction; // 0.0 to 1.0

  String get effectiveName => customName ?? file.path.split('/').last;

  ScannedPage({
    required this.file,
    this.rotation = 0,
    this.customName,
    this.filter = ImageFilter.none,
    this.filterValues = const {},
    this.cropRect = CropRect.full,
    this.signaturePath,
    this.signaturePosition,
    this.annotations = const [],
    this.clarity = 0.0,
    this.noiseReduction = 0.0,
  });

  /// Get effective name (custom or auto-generated from filename)
  String get displayName {
    return customName ?? file.path.split('/').last;
  }
}

class TempImageManager {
  TempImageManager._internal();
  static final TempImageManager _instance = TempImageManager._internal();
  factory TempImageManager() => _instance;

  final List<ScannedPage> _pages = [];

  /// Returns a copy to avoid external mutation
  List<ScannedPage> get pages => List.unmodifiable(_pages);

  /// Backward compatibility: get files list
  List<File> get images => _pages.map((p) => p.file).toList();

  /// Create a new temp image file path
  Future<File> createTempImageFile() async {
    final cacheDir = await getTemporaryDirectory();
    final dir = Directory('${cacheDir.path}/tempscan');

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final filePath = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

    return File(filePath);
  }

  /// Register an image after camera capture
  void addImage(File file) {
    _pages.add(ScannedPage(file: file));
  }

  /// Get a specific page
  ScannedPage? getPage(int index) {
    if (index >= 0 && index < _pages.length) {
      return _pages[index];
    }
    return null;
  }

  /// Remove single page (backward compatible)
  Future<void> removeImage(File file) async {
    final page = _pages.firstWhereOrNull((p) => p.file.path == file.path);
    if (page != null) {
      await removePage(page);
    }
  }

  /// Remove single page
  Future<void> removePage(ScannedPage page) async {
    _pages.remove(page);
    if (await page.file.exists()) {
      await page.file.delete();
    }
  }

  /// Clear everything (export / cancel / crash recovery)
  Future<void> clearAll() async {
    for (final page in _pages) {
      if (await page.file.exists()) {
        await page.file.delete();
      }
    }
    _pages.clear();

    // Extra safety: clear orphan cache files
    await _clearCacheDirectory();
  }

  /// Safety cleanup on app start
  Future<void> cleanupOnLaunch() async {
    _pages.clear();
    await _clearCacheDirectory();
  }

  Future<void> _clearCacheDirectory() async {
    final cacheDir = await getTemporaryDirectory();
    final dir = Directory('${cacheDir.path}/tempscan');

    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final page = _pages.removeAt(oldIndex);
    _pages.insert(newIndex, page);
  }

  /// Rotate a page by 90 degrees
  void rotatePage(int index, [int degrees = 90]) {
    if (index >= 0 && index < _pages.length) {
      final page = _pages[index];
      page.rotation = (page.rotation + degrees) % 360;
    }
  }


  /// Set custom name for a page
  void setCustomName(int index, String name) {
    if (index >= 0 && index < _pages.length) {
      _pages[index].customName = name;
    }
  }

  /// Apply filter to a page
  void applyFilter(
    int index,
    ImageFilter filter, [
    Map<String, double> values = const {},
  ]) {
    if (index >= 0 && index < _pages.length) {
      _pages[index].filter = filter;
      _pages[index].filterValues = values;
    }
  }

  /// Apply crop to a page
  void applyCrop(int index, CropRect cropRect) {
    if (index >= 0 && index < _pages.length) {
      _pages[index].cropRect = cropRect;
    }
  }

  /// Apply digital signature
  void applySignature(int index, String? path, [ui.Offset? position]) {
    if (index >= 0 && index < _pages.length) {
      _pages[index].signaturePath = path;
      _pages[index].signaturePosition = position ?? const ui.Offset(0.7, 0.8);
    }
  }

  /// Apply annotations to a page
  void applyAnnotations(int index, List<Annotation> annotations) {
    if (index >= 0 && index < _pages.length) {
      _pages[index].annotations = List.from(annotations);
    }
  }

  /// Apply advanced enhancements
  void applyEnhancements(int index, {double? clarity, double? noiseReduction}) {
    if (index >= 0 && index < _pages.length) {
      if (clarity != null) _pages[index].clarity = clarity;
      if (noiseReduction != null) _pages[index].noiseReduction = noiseReduction;
    }
  }

  /// Get crop rectangle for a page
  CropRect? getCropRect(int index) {
    if (index >= 0 && index < _pages.length) {
      return _pages[index].cropRect;
    }
    return null;
  }

  /// Get filter display name
  String getFilterName(ImageFilter filter) {
    switch (filter) {
      case ImageFilter.none:
        return 'Original';
      case ImageFilter.grayscale:
        return 'Grayscale';
      case ImageFilter.sepia:
        return 'Sepia';
      case ImageFilter.brightness:
        return 'Brightness';
      case ImageFilter.contrast:
        return 'Contrast';
      case ImageFilter.saturation:
        return 'Saturation';
      case ImageFilter.modernPro:
        return 'Modern Pro';
      case ImageFilter.vintageDoc:
        return 'Vintage Doc';
    }
  }

  /// Get total file size of all pages
  int get totalSizeBytes {
    int total = 0;
    for (final page in _pages) {
      if (page.file.existsSync()) {
        total += page.file.lengthSync();
      }
    }
    return total;
  }
}

// Extension for firstWhereOrNull
extension FirstWhereOrNullExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
