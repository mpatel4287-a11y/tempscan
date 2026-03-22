// ignore_for_file: implementation_imports
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/src/pdf/obj/object.dart';
import 'package:pdf/src/pdf/format/dict.dart';
import 'package:pdf/src/pdf/format/string.dart';
import 'package:pdf/src/pdf/format/num.dart';
import 'package:pdf/src/pdf/format/array.dart';
import 'package:pdf/src/pdf/format/dict_stream.dart';
import 'package:path_provider/path_provider.dart';

// Key used to identify our embedded video files
const String kTempScanVideoKey = '/TempScanVideoID';
const String kStartMarker = 'TEMPSCAN_VIDEO_START';
const String kEndMarker = 'TEMPSCAN_VIDEO_END';

/// Custom PDF Object for embedding video data seamlessly
class CustomEmbeddedFile extends PdfObject<PdfDictStream> {
  CustomEmbeddedFile(
    super.pdfDocument,
    this.fileName,
    this.content,
  ) : super(
          params: PdfDictStream(
            compress: false, //  CRITICAL: No compression for easy byte-scanning
            encrypt: false,
          ),
        );

  final String fileName;
  final List<int> content;

  @override
  void prepare() {
    super.prepare();

    params['/Type'] = const PdfName('/EmbeddedFile');
    params['/Subtype'] = const PdfName('/application/octet-stream');
    params[kTempScanVideoKey] = PdfString.fromString(fileName);
    
    // Optional: Add markers if we want to double check boundaries
    // But since we use Length, we should be fine if we find the start.
    
    params['/Params'] = PdfDict({
      '/Size': PdfNum(content.length),
    });

    params.data = Uint8List.fromList(content);
  }
}

class VideoEmbedBuilder {
  /// Embeds a list of video files into a PDF Document
  static Future<void> embedVideos(pw.Document pdf, List<File> videoFiles) async {
    // 1. Get the low-level document
    final doc = pdf.document;
    
    final references = <CustomEmbeddedFile>[];

    for (var file in videoFiles) {
       final bytes = await file.readAsBytes();
       final fileName = file.path.split('/').last;
       
       // Create the object (automatically adds to doc.objects)
       final embed = CustomEmbeddedFile(doc, fileName, bytes);
       references.add(embed);
    }
    
    // 2. Reference them in the Catalog to ensure they are written and theoretically "linked"
    // We create a custom array in the catalog to hold these references
    final refArray = PdfArray(references.map((e) => e.ref()).toList());
    doc.catalog.params['/TempScanVideos'] = refArray;
  }
  
  /// Extracts videos from a PDF file path
  static Future<List<File>> extractVideos(String pdfPath) async {
     final file = File(pdfPath);
     if (!file.existsSync()) return [];

     final bytes = await file.readAsBytes();
     final extractedFiles = <File>[];
     
     // Scanning Logic:
     // We look for the pattern: /TempScanVideoID (filename) ... stream ... endstream
     // Or more robustly, we just parse the PDF structure manually?
     // Manual parsing is hard.
     // String scanning is risky but effective for uncompressed streams.
     
     // 1. Find all instances of /TempScanVideoID
     final keyBytes = utf8.encode(kTempScanVideoKey);
     var cursor = 0;
     
     while (true) {
       final index = _indexOf(bytes, keyBytes, cursor);
       if (index == -1) break;
       
       debugPrint('VPDF: Found key at byte $index');
       
       // Found a video marker!
       // Parse filename
       // Structure: /TempScanVideoID (filename.mp4)
       // We need to parse the string inside ().
       
       // Advance past key
       var ptr = index + keyBytes.length;
       
       // Find start of string '('
       while (ptr < bytes.length && bytes[ptr] != 40) { // '(' is 40
          ptr++;
       }
       
       if (ptr >= bytes.length) {
         debugPrint('VPDF: Could not find filename start "(" after key');
         break;
       }
       
       var startFilename = ptr + 1;
       var endFilename = startFilename;
        while (endFilename < bytes.length && bytes[endFilename] != 41) { // ')' is 41
          endFilename++;
       }
       
       final filenameBytes = bytes.sublist(startFilename, endFilename);
       final filename = String.fromCharCodes(filenameBytes); 
       debugPrint('VPDF: Found filename: $filename');
       
       // Now find the 'stream' keyword
       final streamBytes = utf8.encode('stream');
       final streamIndex = _indexOf(bytes, streamBytes, endFilename);
       
       if (streamIndex != -1) {
          debugPrint('VPDF: Found stream at $streamIndex');
          // Stream content starts after 'stream\r\n' or 'stream\n'
          var dataStart = streamIndex + streamBytes.length;
          
          // Skip whitespace/newlines (0x0D, 0x0A)
          while (dataStart < bytes.length && (bytes[dataStart] == 10 || bytes[dataStart] == 13)) {
            dataStart++;
          }
          
          // Now find 'endstream'
          final endStreamBytes = utf8.encode('endstream');
          final endStreamIndex = _indexOf(bytes, endStreamBytes, dataStart);
          
          if (endStreamIndex != -1) {
             debugPrint('VPDF: Found endstream at $endStreamIndex. Lenght: ${endStreamIndex - dataStart}');
             final videoData = bytes.sublist(dataStart, endStreamIndex);
             
             // Save to temp file
             final tempDir = await getTemporaryDirectory();
             final outFile = File('${tempDir.path}/extracted_$filename');
             // Avoid dupes
             var counter = 0;
             var finalOutFile = outFile;
             while(finalOutFile.existsSync()) {
               counter++;
               finalOutFile = File('${tempDir.path}/extracted_${counter}_$filename');
             }
             
             await finalOutFile.writeAsBytes(videoData);
             extractedFiles.add(finalOutFile);
             debugPrint('VPDF: Extracted to ${finalOutFile.path}');
          } else {
             debugPrint('VPDF: Could not find endstream for $filename');
          }
       } else {
         debugPrint('VPDF: Could not find stream content for $filename');
       }
       
       cursor = ptr + 1;
     }

     return extractedFiles;
  }
  
  static int _indexOf(List<int> source, List<int> pattern, int start) {
    if (pattern.isEmpty) return -1;
    for (int i = start; i < source.length - pattern.length + 1; i++) {
      bool match = true;
      for (int j = 0; j < pattern.length; j++) {
        if (source[i + j] != pattern[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }
}
