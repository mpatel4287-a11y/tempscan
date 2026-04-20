import 'advanced_ocr_engine.dart';

class TableExtractionService {
  static final TableExtractionService instance = TableExtractionService._internal();
  TableExtractionService._internal();

  /// Extracts a table from OCR blocks.
  /// Returns a 2D list where each inner list is a row of cells.
  List<List<String>> extractTable(List<EditableTextBlock> blocks) {
    if (blocks.isEmpty) return [];

    // 1. Group blocks into potential rows
    // We sort by 'top' first to facilitate grouping
    final sortedBlocks = List<EditableTextBlock>.from(blocks)
      ..sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

    final List<List<EditableTextBlock>> rowGroups = [];
    if (sortedBlocks.isNotEmpty) {
      List<EditableTextBlock> currentRow = [sortedBlocks.first];
      
      for (int i = 1; i < sortedBlocks.length; i++) {
        final block = sortedBlocks[i];
        final prevBlock = currentRow.last;

        // If the vertical difference between this block and the current row's average 'top' 
        // is small enough, it's likely the same row.
        // We use 50% of the block height as a threshold.
        final double avgHeight = currentRow.fold(0.0, (sum, b) => sum + b.boundingBox.height) / currentRow.length;
        final double verticalDist = (block.boundingBox.center.dy - prevBlock.boundingBox.center.dy).abs();

        if (verticalDist < avgHeight * 0.6) {
          currentRow.add(block);
        } else {
          rowGroups.add(currentRow);
          currentRow = [block];
        }
      }
      rowGroups.add(currentRow);
    }

    // 2. Sort blocks within each row by X-axis
    for (var row in rowGroups) {
      row.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
    }

    // 3. Find Global Columns
    // Tables often have misaligned text. We try to find X-intervals that are frequently used.
    final List<double> xCentroids = [];
    for (var row in rowGroups) {
      for (var block in row) {
        xCentroids.add(block.boundingBox.center.dx);
      }
    }
    xCentroids.sort();

    // Group X-centroids to find common column centers
    final List<double> columnCenters = [];
    if (xCentroids.isNotEmpty) {
      double currentGroupSum = xCentroids.first;
      int count = 1;
      for (int i = 1; i < xCentroids.length; i++) {
        if ((xCentroids[i] - xCentroids[i - 1]).abs() < 40) { // Column spacing threshold
          currentGroupSum += xCentroids[i];
          count++;
        } else {
          columnCenters.add(currentGroupSum / count);
          currentGroupSum = xCentroids[i];
          count = 1;
        }
      }
      columnCenters.add(currentGroupSum / count);
    }

    // 4. Map blocks to the detected columns
    final List<List<String>> tableData = [];
    for (var row in rowGroups) {
      final List<String> cells = List.filled(columnCenters.length, '');
      
      for (var block in row) {
        // Find the closest column center
        int colIndex = -1;
        double minDist = double.infinity;
        for (int i = 0; i < columnCenters.length; i++) {
          final dist = (block.boundingBox.center.dx - columnCenters[i]).abs();
          if (dist < minDist) {
            minDist = dist;
            colIndex = i;
          }
        }
        
        if (colIndex != -1) {
          if (cells[colIndex].isEmpty) {
            cells[colIndex] = block.text;
          } else {
            cells[colIndex] += ' ${block.text}';
          }
        }
      }
      tableData.add(cells);
    }

    return tableData;
  }
}
