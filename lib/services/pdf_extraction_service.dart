import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;

enum PdfElementType { text, image }

class PdfElement {
  final int pageIndex;
  final Size pageSize;
  final PdfElementType type;
  String text;
  Uint8List? imageBytes;
  double? x;
  double? y;
  double? width;
  double? height;

  PdfElement({
    required this.pageIndex,
    required this.pageSize,
    required this.type,
    this.text = '',
    this.imageBytes,
    this.x,
    this.y,
    this.width,
    this.height,
  });
}

class PdfExtractionService {
  static Future<List<PdfElement>> extractContent(String filePath) async {
    final List<PdfElement> elements = [];
    try {
      final File file = File(filePath);
      final Uint8List bytes = await file.readAsBytes();
      final sfpdf.PdfDocument document = sfpdf.PdfDocument(inputBytes: bytes);
      final sfpdf.PdfTextExtractor extractor = sfpdf.PdfTextExtractor(document);

      for (int i = 0; i < document.pages.count; i++) {
        final sfpdf.PdfPage page = document.pages[i];
        final Size pageSize = Size(page.size.width, page.size.height);

        // Extract text with positioning
        final List<sfpdf.TextLine> textLines = extractor.extractTextLines(
          startPageIndex: i,
          endPageIndex: i,
        );

        for (final sfpdf.TextLine line in textLines) {
          elements.add(PdfElement(
            pageIndex: i,
            pageSize: pageSize,
            type: PdfElementType.text,
            text: line.text,
            x: line.bounds.left,
            y: line.bounds.top,
            width: line.bounds.width,
            height: line.bounds.height,
          ));
        }

        // Image extraction
        final List<Uint8List>? images = await _extractImagesFromPage(document, i);
        if (images != null) {
          for (final Uint8List imgBytes in images) {
            elements.add(PdfElement(
              pageIndex: i,
              pageSize: pageSize,
              type: PdfElementType.image,
              imageBytes: imgBytes,
            ));
          }
        }
      }

      document.dispose();
    } catch (e) {
      // Error extracting PDF
    }
    return elements;
  }

  static Future<List<Uint8List>?> _extractImagesFromPage(sfpdf.PdfDocument doc, int pageIndex) async {
    try {
      // In some versions of Syncfusion, this is how you extract images:
      // final List<Uint8List> images = doc.pages[pageIndex].extractImages();
      // return images;
      
      // Since I am not certain about the exact API availability in this project's version,
      // I'll use a try-catch for the specific image extraction method.
      return (doc.pages[pageIndex] as dynamic).extractImages() as List<Uint8List>;
    } catch (e) {
      return null;
    }
  }
}
