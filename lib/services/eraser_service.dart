import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class EraserService {
  static final EraserService instance = EraserService._internal();
  EraserService._internal();

  /// Erases a rectangular area from an image by filling it with the
  /// average background color sampled from the borders of the rectangle.
  Future<File> eraseArea(File origin, Rect area) async {
    final bytes = await origin.readAsBytes();
    final image = img.decodeImage(bytes);
    
    if (image == null) return origin;

    // Expand sampling area slightly to find "pure" background 
    // outside the text block bounds
    final int startX = area.left.toInt();
    final int startY = area.top.toInt();
    final int endX = area.right.toInt();
    final int endY = area.bottom.toInt();

    int rTotal = 0;
    int gTotal = 0;
    int bTotal = 0;
    int samples = 0;

    // Sample top and bottom edges
    for (int x = startX - 2; x <= endX + 2; x++) {
       if (x >= 0 && x < image.width) {
         if (startY - 2 >= 0) {
            final p = image.getPixelSafe(x, startY - 2);
            rTotal += p.r.toInt();
            gTotal += p.g.toInt();
            bTotal += p.b.toInt();
            samples++;
         }
         if (endY + 2 < image.height) {
            final p = image.getPixelSafe(x, endY + 2);
            rTotal += p.r.toInt();
            gTotal += p.g.toInt();
            bTotal += p.b.toInt();
            samples++;
         }
       }
    }

    // Average Background Color
    final r = samples > 0 ? (rTotal / samples).round() : 255;
    final g = samples > 0 ? (gTotal / samples).round() : 255;
    final b = samples > 0 ? (bTotal / samples).round() : 255;
    final bgColor = img.ColorRgb8(r, g, b);

    // Paint over the text block
    for (int y = startY; y <= endY; y++) {
      for (int x = startX; x <= endX; x++) {
        if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
          image.setPixel(x, y, bgColor);
        }
      }
    }

    // Save erased image
    final modifiedBytes = img.encodeJpg(image, quality: 90);
    final tempDir = Directory.systemTemp;
    final erasedFile = File('${tempDir.path}/erased_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await erasedFile.writeAsBytes(modifiedBytes);

    return erasedFile;
  }
}
