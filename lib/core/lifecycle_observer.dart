import 'package:flutter/widgets.dart';
import '../temp_storage/temp_image_manager.dart';

class AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      TempImageManager().clearAll();
    }
  }
}
