import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class XlsxReaderService {
  static final XlsxReaderService instance = XlsxReaderService._internal();
  XlsxReaderService._internal();

  Future<List<List<String>>> readXlsx(File file) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // 1. Read Shared Strings
    final List<String> sharedStrings = [];
    final sharedStringsFile = archive.findFile('xl/sharedStrings.xml');
    if (sharedStringsFile != null) {
      final content = utf8.decode(sharedStringsFile.content as List<int>);
      final document = XmlDocument.parse(content);
      final tTags = document.findAllElements('t');
      for (var t in tTags) {
        sharedStrings.add(t.innerText);
      }
    }

    // 2. Read Sheet1 (First sheet by default)
    final List<List<String>> rows = [];
    final sheetFile = archive.findFile('xl/worksheets/sheet1.xml');
    if (sheetFile == null) return [];

    final sheetContent = utf8.decode(sheetFile.content as List<int>);
    final sheetDocument = XmlDocument.parse(sheetContent);
    final rowElements = sheetDocument.findAllElements('row');

    for (var rowElement in rowElements) {
      final List<String> cells = [];
      final cElements = rowElement.findElements('c');
      
      // Handle sparse cells (missing column values)
      int lastColIndex = -1;

      for (var c in cElements) {
        final r = c.getAttribute('r'); // e.g., "A1", "B1"
        final colIndex = _getColumnIndex(r ?? '');
        
        // Fill gaps if any
        while (lastColIndex + 1 < colIndex) {
          cells.add('');
          lastColIndex++;
        }

        final type = c.getAttribute('t'); // "s" for shared string
        final vElement = c.getElement('v');
        String value = '';

        if (vElement != null) {
          if (type == 's') {
            final index = int.tryParse(vElement.innerText);
            if (index != null && index < sharedStrings.length) {
              value = sharedStrings[index];
            }
          } else {
            value = vElement.innerText;
          }
        }
        cells.add(value);
        lastColIndex = colIndex;
      }
      rows.add(cells);
    }

    // Normalize row lengths
    int maxCols = 0;
    for (var row in rows) {
      if (row.length > maxCols) maxCols = row.length;
    }
    for (var row in rows) {
      while (row.length < maxCols) {
        row.add('');
      }
    }

    return rows;
  }

  int _getColumnIndex(String cellRef) {
    // A1 -> 0, B1 -> 1, AA1 -> 26
    final colStr = cellRef.replaceAll(RegExp(r'[0-9]'), '');
    int index = 0;
    for (int i = 0; i < colStr.length; i++) {
      index = index * 26 + (colStr.codeUnitAt(i) - 64);
    }
    return index - 1;
  }
}
