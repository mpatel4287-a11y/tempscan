import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../temp_storage/temp_image_manager.dart';
import '../services/settings_service.dart';

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

      // Load signature if exists
      pw.MemoryImage? signatureImage;
      if (page.signaturePath != null) {
        final sigFile = File(page.signaturePath!);
        if (await sigFile.exists()) {
          signatureImage = pw.MemoryImage(await sigFile.readAsBytes());
        }
      }

      // Calculate rotation
      final rotation = page.rotation;

      pdf.addPage(
        pw.Page(
          margin: const pw.EdgeInsets.all(20),
          orientation: (rotation == 90 || rotation == 270)
              ? pw.PageOrientation.landscape
              : pw.PageOrientation.portrait,
          build: (context) {
            final pageContent = pw.Stack(
              children: [
                pw.Center(
                  child: pw.ClipRect(
                    child: pw.Container(
                      width: PdfPageFormat.a4.width - 40,
                      height: PdfPageFormat.a4.height - 40,
                      child: pw.Image(
                        image,
                        alignment: pw.Alignment(
                          -1.0 + (page.cropRect.x + page.cropRect.width / 2) * 2 / (1 - page.cropRect.width + 0.00001),
                          -1.0 + (page.cropRect.y + page.cropRect.height / 2) * 2 / (1 - page.cropRect.height + 0.00001),
                        ),
                        fit: pw.BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                if (addWatermark)
                  pw.Positioned(
                    bottom: 20,
                    right: 20,
                    child: pw.Opacity(
                      opacity: 0.3,
                      child: pw.Text(
                        'TempScan',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ),
                if (signatureImage != null)
                  pw.Positioned(
                    left: (page.signaturePosition?.dx ?? 0.7) * (PdfPageFormat.a4.width - 100),
                    top: (page.signaturePosition?.dy ?? 0.8) * (PdfPageFormat.a4.height - 110),
                    child: pw.Image(signatureImage, width: 80, height: 50),
                  ),
              ],
            );

            if (rotation != 0) {
              return pw.Transform.rotate(
                angle: rotation * 3.14159 / 180,
                child: pageContent,
              );
            }
            return pageContent;
          },
        ),
      );
    }

    // Use custom directory, default save path from SettingsService, or documents folder
    final defaultSavePath = await SettingsService.getOrPickSavePath();
    final directory = customDirectory ?? 
        (defaultSavePath != null ? Directory(defaultSavePath) : await getApplicationDocumentsDirectory());

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
