import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import 'package:share_plus/share_plus.dart';

class ExcelExportService {
  static final ExcelExportService instance = ExcelExportService._internal();
  ExcelExportService._internal();

  /// Exports 2D list to an Excel file and shares it.
  Future<void> exportAndShare(List<List<String>> data, String fileName) async {
    if (data.isEmpty) return;

    // Create a new Excel document
    final Workbook workbook = Workbook();
    final Worksheet sheet = workbook.worksheets[0];

    // Populate data
    for (int rowIndex = 0; rowIndex < data.length; rowIndex++) {
      final rowData = data[rowIndex];
      for (int colIndex = 0; colIndex < rowData.length; colIndex++) {
        // Excel is 1-indexed for rows and columns
        final Range cell = sheet.getRangeByIndex(rowIndex + 1, colIndex + 1);
        cell.setText(rowData[colIndex]);
        
        // Basic styling for header row
        if (rowIndex == 0) {
          cell.cellStyle.bold = true;
          cell.cellStyle.backColor = '#D3D3D3';
        }
      }
    }

    // Auto-fit columns
    for (int i = 1; i <= data[0].length; i++) {
      // Logic for autofit is sometimes limited in simple xlsio, but we can set widths
      sheet.getRangeByIndex(1, i).columnWidth = 20;
    }

    // Save the file
    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    final directory = await getApplicationDocumentsDirectory();
    final String path = '${directory.path}/$fileName.xlsx';
    final File file = File(path);
    await file.writeAsBytes(bytes);

    // Share the file
    await Share.shareXFiles([XFile(path)], text: 'Exported Table from TempScan');
  }
}
