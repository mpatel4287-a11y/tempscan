// lib/utils/font_matcher.dart

class FontMatcher {
  /// Heuristically matches a source font to a standard Flutter font.
  /// 
  /// In a real production scenario, we might use a neural network 
  /// or deep analysis of the character shapes.
  /// For this advanced implementation, we use structural metadata 
  /// provided by OCR (like block height-to-width ratio).
  static String matchFont(double avgCharWidth, double avgCharHeight) {
    if (avgCharWidth == 0 || avgCharHeight == 0) return 'Sans-Serif';

    final ratio = avgCharWidth / avgCharHeight;

    // Serif fonts like Times New Roman often have tighter character spacing
    // or specific height ratios.
    // Sans-Serif fonts like Arial are often wider.
    if (ratio < 0.45) {
      return 'Serif'; 
    } else if (ratio > 0.6) {
      return 'Monospace';
    }
    
    return 'Sans-Serif';
  }

  /// Returns actual Flutter font family name based on type
  static String getFlutterFontFamily(String type) {
    switch (type.toLowerCase()) {
      case 'serif':
        return 'Georgia'; // or 'Times New Roman'
      case 'monospace':
        return 'Courier New';
      default:
        return 'Inter'; // Default Modern Sans
    }
  }
}
