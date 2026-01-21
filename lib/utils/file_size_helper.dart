import 'dart:io';

class FileSizeHelper {
  static String readable(File file) {
    final bytes = file.lengthSync();
    return format(bytes);
  }

  static int bytes(File file) {
    return file.lengthSync();
  }

  static String format(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  static String fromBytes(int bytes) {
    return format(bytes);
  }
}
