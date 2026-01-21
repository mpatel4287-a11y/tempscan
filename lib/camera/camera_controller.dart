// ignore_for_file: unused_import

import 'dart:developer' as developer;
import 'package:camera/camera.dart';
import '../temp_storage/temp_image_manager.dart';

class TempScanCameraController {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  int _flashMode = 0; // 0 = off, 1 = on, 2 = auto

  CameraController? get controller => _controller;

  Future<void> initialize() async {
    _cameras = await availableCameras();
    _controller = CameraController(
      _cameras!.first,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _controller!.initialize();
  }

  Future<void> setFlashMode(int mode) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    _flashMode = mode;
    try {
      switch (mode) {
        case 0:
          await _controller!.setFlashMode(FlashMode.off);
          break;
        case 1:
          await _controller!.setFlashMode(FlashMode.always);
          break;
        case 2:
          await _controller!.setFlashMode(FlashMode.auto);
          break;
      }
    } catch (e) {
      // Flash not supported on this device
    }
  }

  int get flashMode => _flashMode;

  Future<void> captureImage() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final tempFile = await TempImageManager().createTempImageFile();

    final image = await _controller!.takePicture();
    await image.saveTo(tempFile.path);

    TempImageManager().addImage(tempFile);
  }

  Future<void> dispose() async {
    await _controller?.dispose();
  }
}
