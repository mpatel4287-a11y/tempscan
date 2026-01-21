import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class WatermarkOptions {
  String text;
  double fontSize;
  PdfColor color;
  double opacity;
  bool showOnAllPages;
  bool isDiagonal;

  WatermarkOptions({
    this.text = 'TempScan',
    this.fontSize = 20,
    this.color = PdfColors.grey,
    this.opacity = 0.3,
    this.showOnAllPages = true,
    this.isDiagonal = false,
  });
}

class WatermarkUtil {
  static pw.Widget createWatermark(WatermarkOptions options) {
    return pw.Opacity(
      opacity: options.opacity,
      child: pw.Transform.rotate(
        angle: options.isDiagonal ? 0.7854 : 0,
        child: pw.Center(
          child: pw.Text(
            options.text,
            style: pw.TextStyle(
              fontSize: options.fontSize,
              color: options.color,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
