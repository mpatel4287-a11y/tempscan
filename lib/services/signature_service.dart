import 'dart:io';
import 'package:path_provider/path_provider.dart';

class SignatureService {
  static Future<List<File>> getSavedSignatures() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final signatureDir = Directory('${tempDir.path}/signatures');
      
      if (!await signatureDir.exists()) return [];
      
      final files = signatureDir.listSync()
          .where((entity) => entity is File && entity.path.endsWith('.png'))
          .map((entity) => File(entity.path))
          .toList();
          
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      return files;
    } catch (e) {
      return [];
    }
  }

  static Future<void> deleteSignature(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // ignore
    }
  }
}
