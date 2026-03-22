import 'dart:ui';
import 'package:temp_scan/services/advanced_ocr_engine.dart';

class FormField {
  final String label;
  final Rect boundingBox; // The area where the user should type
  final bool isCheckbox;
  
  FormField({
    required this.label,
    required this.boundingBox,
    this.isCheckbox = false,
  });
}

class FormRecognitionService {
  static final FormRecognitionService instance = FormRecognitionService._internal();
  FormRecognitionService._internal();

  /// Analyzes parsed text blocks to find potential form fields.
  /// Looks for:
  /// 1. Text followed by underscores (e.g. "Name: ________")
  /// 2. Labels aligned with blank spaces.
  /// 3. Common patterns like "Date", "Signature", "Total".
  List<FormField> detectFields(List<EditableTextBlock> blocks) {
    final List<FormField> fields = [];

    for (int i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      final text = block.text.trim();

      // Pattern 1: Labels ending with ":" (e.g. "Name:")
      if (text.endsWith(':')) {
        // Look ahead for the next block to see if it's on the same line but far away
        // Or if there's a large gap after this colon
        final label = text.substring(0, text.length - 1);
        
        // Example: If "Name:" is at (100, 100) and width is 50.
        // We propose a fillable field starting at (160, 100) with a standard width.
        final fieldRect = Rect.fromLTWH(
          block.boundingBox.right + 10,
          block.boundingBox.top,
          200, // Standard field width
          block.boundingBox.height,
        );
        
        fields.add(FormField(label: label, boundingBox: fieldRect));
      }

      // Pattern 2: Explicit underscores
      if (text.contains('___')) {
        fields.add(FormField(
          label: 'Fillable Field', 
          boundingBox: block.boundingBox,
        ));
      }
      
      // Pattern 3: Common Keywords
      final lowerText = text.toLowerCase();
      if (lowerText == 'date' || lowerText == 'signature' || lowerText == 'total') {
         final fieldRect = Rect.fromLTWH(
          block.boundingBox.left,
          block.boundingBox.bottom + 5,
          block.boundingBox.width,
          20,
        );
        fields.add(FormField(label: text, boundingBox: fieldRect));
      }
    }

    return fields;
  }
}
