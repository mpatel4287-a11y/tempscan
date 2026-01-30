import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class SettingsService {
  static const String _keyDefaultSavePath = 'default_save_path';

  static Future<String?> getDefaultSavePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDefaultSavePath);
  }

  static Future<void> setDefaultSavePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDefaultSavePath, path);
  }

  /// Gets the default save path or asks the user to pick one if not set.
  /// If [forcePick] is true, it will always ask and update the preference.
  static Future<String?> getOrPickSavePath({bool forcePick = false}) async {
    String? path = await getDefaultSavePath();

    if (path == null || forcePick) {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory != null) {
        await setDefaultSavePath(selectedDirectory);
        path = selectedDirectory;
      }
    }

    if (path != null) {
      // Ensure it still exists
      final dir = Directory(path);
      if (!await dir.exists()) {
        final selectedDirectory = await FilePicker.platform.getDirectoryPath();
        if (selectedDirectory != null) {
          await setDefaultSavePath(selectedDirectory);
          path = selectedDirectory;
        } else {
          path = null;
        }
      }
    }

    return path;
  }
}
