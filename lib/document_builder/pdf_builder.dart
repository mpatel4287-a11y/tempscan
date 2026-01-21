import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../temp_storage/temp_image_manager.dart';

class PdfBuilder {
  static Future<File> createPdf({
    required bool addWatermark,
    String? customFileName,
    Directory? customDirectory,
  }) async {
    final pdf = pw.Document();
    final manager = TempImageManager();
    final pages = manager.pages;

    for (int i = 0; i < pages.length; i++) {
      final page = pages[i];

      // Read image bytes
      final imageBytes = await page.file.readAsBytes();
      final image = pw.MemoryImage(imageBytes);

      // Calculate rotation
      final rotation = page.rotation;

      pdf.addPage(
        pw.Page(
          margin: const pw.EdgeInsets.all(20),
          orientation: (rotation == 90 || rotation == 270)
              ? pw.PageOrientation.landscape
              : pw.PageOrientation.portrait,
          build: (context) {
            return pw.Transform.rotate(
              angle: rotation * 3.14159 / 180,
              child: pw.Stack(
                children: [
                  pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
                  if (addWatermark)
                    pw.Positioned(
                      bottom: 20,
                      right: 20,
                      child: pw.Opacity(
                        opacity: 0.3,
                        child: pw.Text(
                          'TempScan',
                          style: pw.TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );
    }

    // Use custom directory or default to documents
    final directory =
        customDirectory ?? await getApplicationDocumentsDirectory();

    // Ensure directory exists
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = (customFileName ?? 'TempScan_$timestamp').endsWith('.pdf')
        ? (customFileName ?? 'TempScan_$timestamp')
        : '${customFileName ?? 'TempScan_$timestamp'}.pdf';
    final filePath = '${directory.path}/$fileName';

    final outputFile = File(filePath);
    await outputFile.writeAsBytes(await pdf.save());

    return outputFile;
  }
}
