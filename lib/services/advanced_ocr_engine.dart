import 'dart:ui';
import 'dart:io';
import 'dart:math';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:temp_scan/utils/font_matcher.dart';

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
    final inputImage = InputImage.fromFile(imageFile);
    final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
    
    final List<EditableTextBlock> blocks = [];

    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        // Estimate Font Size roughly based on the bounding box height
        final double height = line.boundingBox.height;
        // In Flutter, fontSize is roughly pixel height * 0.75 for standard fonts
        final double estimatedSize = height * 0.75;
        
        // Estimate Font Style based on geometry
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
}
