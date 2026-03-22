import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'document_storage_service.dart';
import 'automation_service.dart';

class BackupService {
  static Future<void> exportBackup(BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final prefs = await SharedPreferences.getInstance();
      
      // 1. Gather all metadata into a JSON string
      final Map<String, dynamic> metadata = {
        'scanned_documents': prefs.getString('scanned_documents') ?? '[]',
        'document_folders': prefs.getString('document_folders') ?? '[]',
        'custom_tags': prefs.getStringList('custom_tags') ?? [],
        'automation_rules': prefs.getString('automation_rules') ?? '[]',
      };
      final metadataJson = jsonEncode(metadata);

      // 2. Create archive
      final archive = Archive();
      archive.addFile(ArchiveFile('metadata.json', metadataJson.length, utf8.encode(metadataJson)));

      // 3. Add all physical documents
      await DocumentStorageService.instance.initialize();
      final docs = DocumentStorageService.instance.documents;
      for (final doc in docs) {
        final file = File(doc.filePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final fileName = doc.filePath.split('/').last;
          archive.addFile(ArchiveFile('files/$fileName', bytes.length, bytes));
        }
      }

      // 4. Encode archive to zip
      final zipEncoder = ZipEncoder();
      final zipData = zipEncoder.encode(archive);

      // 5. Ask user to save/share it
      final tempDir = await getTemporaryDirectory();
      final tempZipFile = File('${tempDir.path}/TempScan_Backup_${DateTime.now().millisecondsSinceEpoch}.zip');
      await tempZipFile.writeAsBytes(zipData);

      if (context.mounted) Navigator.pop(context); // Close loading dialog BEFORE sharing

      await Share.shareXFiles(
        [XFile(tempZipFile.path)],
        text: 'TempScan Backup',
        subject: 'TempScan_Backup.zip',
      );

    } catch (e) {
      if (context.mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context); // Close loading dialog if still open
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  static Future<void> importBackup(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.isEmpty || result.files.first.path == null) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final bytes = await File(result.files.first.path!).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Find metadata.json
      ArchiveFile? metadataFile;
      for (final file in archive) {
        if (file.name == 'metadata.json') {
          metadataFile = file;
          break;
        }
      }

      if (metadataFile == null) throw Exception('Invalid backup file. Missing metadata.json.');

      final metadataJson = utf8.decode(metadataFile.content as List<int>);
      final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;

      final prefs = await SharedPreferences.getInstance();
      final appDocsDir = await getApplicationDocumentsDirectory();

      // restore metadata
      if (metadata['scanned_documents'] != null) {
        final docsList = jsonDecode(metadata['scanned_documents']) as List<dynamic>;
        
        final updatedDocsList = docsList.map((docMapDynamic) {
          final docMap = docMapDynamic as Map<String, dynamic>;
          final fileName = docMap['filePath']?.split('/').last ?? docMap['name'];
          docMap['filePath'] = '${appDocsDir.path}/$fileName';
          return docMap;
        }).toList();

        await prefs.setString('scanned_documents', jsonEncode(updatedDocsList));
      }
      if (metadata['document_folders'] != null) {
        // Just write the string back since it's already encoded JSON
        await prefs.setString('document_folders', metadata['document_folders']);
      }
      if (metadata['custom_tags'] != null) {
        await prefs.setStringList('custom_tags', List<String>.from(metadata['custom_tags']));
      }
      if (metadata['automation_rules'] != null) {
        if (metadata['automation_rules'] is String) {
          await prefs.setString('automation_rules', metadata['automation_rules']);
        } else if (metadata['automation_rules'] is List) {
          await prefs.setString('automation_rules', jsonEncode(metadata['automation_rules']));
        }
      }

      // Restore files
      for (final file in archive) {
        if (file.isFile && file.name.startsWith('files/')) {
          final fileName = file.name.split('/').last;
          final targetFile = File('${appDocsDir.path}/$fileName');
          await targetFile.writeAsBytes(file.content as List<int>);
        }
      }

      // Re-initialize services
      await DocumentStorageService.instance.initialize();
      await AutomationService.instance.initialize();

      if (context.mounted) {
        Navigator.pop(context); // close dialog
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup restored successfully')));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // close dialog
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore failed: $e'), backgroundColor: Colors.red));
      }
    }
  }
}
