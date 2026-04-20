import 'dart:ui';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:temp_scan/utils/font_matcher.dart';
import 'package:path_provider/path_provider.dart';

class EditableTextBlock {
  String text;
  final Rect boundingBox;
  final double estimatedFontSize;
  final String estimatedFontFamily;
  final List<Point<int>> cornerPoints;
  
  EditableTextBlock({
    required this.text,
    required this.boundingBox,
    required this.estimatedFontSize,
    required this.estimatedFontFamily,
    required this.cornerPoints,
  });
}

class AdvancedOcrEngine {
  static final AdvancedOcrEngine instance = AdvancedOcrEngine._internal();
  AdvancedOcrEngine._internal();

  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<List<EditableTextBlock>> parseDocument(File imageFile) async {
    // MULTI-PASS STRATEGY
    
    // Pass 1: Original Image
    var blocks = await _scanImage(imageFile);
    
    // If Pass 1 fail (heuristic: less than 15 chars), try Pass 2
    if (_totalCharCount(blocks) < 15) {
      debugPrint('OCR Pass 1 sub-optimal, trying Pass 2 (Enhanced)...');
      final enhancedFile = await _preprocessImage(imageFile, mode: 'enhanced');
      blocks = await _scanImage(enhancedFile);
      try { await enhancedFile.delete(); } catch (_) {}
    }

    // If still fail, try Pass 3 (Binarized)
    if (_totalCharCount(blocks) < 15) {
      debugPrint('OCR Pass 2 sub-optimal, trying Pass 3 (Binarized)...');
      final binaryFile = await _preprocessImage(imageFile, mode: 'binary');
      blocks = await _scanImage(binaryFile);
      try { await binaryFile.delete(); } catch (_) {}
    }

    return blocks;
  }

  int _totalCharCount(List<EditableTextBlock> blocks) {
    return blocks.fold(0, (sum, b) => sum + b.text.length);
  }

  Future<List<EditableTextBlock>> _scanImage(File file) async {
    final inputImage = InputImage.fromFile(file);
    final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
    
    final List<EditableTextBlock> blocks = [];
    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        final double height = line.boundingBox.height;
        final double estimatedSize = height * 0.75;
        final String fontType = FontMatcher.matchFont(
          line.boundingBox.width / (line.text.length + 1), 
          line.boundingBox.height
        );
        final estimatedFontFamily = FontMatcher.getFlutterFontFamily(fontType);

        blocks.add(EditableTextBlock(
          text: line.text,
          boundingBox: line.boundingBox,
          estimatedFontSize: estimatedSize,
          estimatedFontFamily: estimatedFontFamily,
          cornerPoints: line.cornerPoints,
        ));
      }
    }
    return blocks;
  }

  void dispose() {
    _textRecognizer.close();
  }

  Future<File> _preprocessImage(File inputFile, {String mode = 'enhanced'}) async {
    try {
      final bytes = await inputFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image == null) return inputFile;

      if (mode == 'enhanced') {
        // Grayscale + Contrast + Sharpen
        image = img.grayscale(image);
        image = img.contrast(image, contrast: 1.3);
        // Sharpening kernel
        image = img.convolution(image, filter: [0, -1, 0, -1, 5, -1, 0, -1, 0]);
      } else if (mode == 'binary') {
        // Aggressive Binarization for very dark/light backgrounds
        image = img.grayscale(image);
        image = img.luminanceThreshold(image, threshold: 0.5);
      }

      // Save to a temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/processed_${mode}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(img.encodeJpg(image, quality: 90));
      
      return tempFile;
    } catch (e) {
      debugPrint('Pre-processing ($mode) failed: $e');
      return inputFile;
    }
  }
}
