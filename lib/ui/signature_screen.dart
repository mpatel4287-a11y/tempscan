// ignore_for_file: prefer_final_fields, unused_import

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/file_size_helper.dart';

class SignatureScreen extends StatefulWidget {
  const SignatureScreen({super.key});

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  final List<File> _savedSignatures = [];
  bool _isSaving = false;
  Color _selectedColor = Colors.black;
  double _strokeWidth = 3.0;

  // Drawing controller
  final GlobalKey<_SignaturePainterState> _painterKey =
      GlobalKey<_SignaturePainterState>();

  Future<void> _saveSignature() async {
    if (_painterKey.currentState?.isEmpty ?? true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please draw a signature first')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Get the image from the painter
      final image = await _painterKey.currentState!.getImage();
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final signatureDir = Directory('${tempDir.path}/signatures');

      if (!await signatureDir.exists()) {
        await signatureDir.create(recursive: true);
      }

      final fileName = 'signature_${DateTime.now().millisecondsSinceEpoch}.png';
      final signatureFile = File('${signatureDir.path}/$fileName');
      await signatureFile.writeAsBytes(bytes);

      setState(() {
        _savedSignatures.add(signatureFile);
        _isSaving = false;
      });

      // Clear the drawing pad after saving
      _painterKey.currentState?.clear();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Signature saved!')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving signature: $e')));
    }
  }

  Future<void> _deleteSignature(int index) async {
    final file = _savedSignatures[index];
    if (await file.exists()) {
      await file.delete();
    }

    setState(() {
      _savedSignatures.removeAt(index);
    });
  }

  Future<void> _shareSignature(int index) async {
    final file = _savedSignatures[index];

    try {
      await Share.shareXFiles([XFile(file.path)], text: 'Here is my signature');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sharing: $e')));
      }
    }
  }

  void _addToPdf(int index) {
    final file = _savedSignatures[index];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Signature "${file.path.split('/').last}" ready to add to PDF',
        ),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );
  }

  void _pickExistingSignature() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowedExtensions: ['png', 'jpg', 'jpeg'],
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        setState(() {
          _savedSignatures.add(file);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking signature: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Add Signature'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _pickExistingSignature,
            tooltip: 'Pick existing',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drawing pad
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Toolbar
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Color picker
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildColorOption(Colors.black),
                                  const SizedBox(width: 8),
                                  _buildColorOption(Colors.blue),
                                  const SizedBox(width: 8),
                                  _buildColorOption(Colors.red),
                                  const SizedBox(width: 8),
                                  _buildColorOption(Colors.green),
                                  const SizedBox(width: 8),
                                  _buildColorOption(Colors.purple),
                                ],
                              ),
                              const Spacer(),
                              // Undo button
                              IconButton(
                                icon: const Icon(Icons.undo),
                                onPressed: () =>
                                    _painterKey.currentState?.undo(),
                                tooltip: 'Undo',
                              ),
                              const SizedBox(width: 8),
                              // Clear button
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () =>
                                    _painterKey.currentState?.clear(),
                                tooltip: 'Clear',
                              ),
                            ],
                          ),
                        ),
                        // Signature pad
                        Container(
                          height: 200,
                          margin: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SignaturePainter(
                              key: _painterKey,
                              strokeColor: _selectedColor,
                              strokeWidth: _strokeWidth,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Saved signatures
                  if (_savedSignatures.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Saved Signatures',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${_savedSignatures.length} signature(s)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _savedSignatures.length,
                      itemBuilder: (context, index) {
                        final file = _savedSignatures[index];
                        final fileSize = FileSizeHelper.readable(file);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Image.file(file, fit: BoxFit.contain),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      file.path.split('/').last,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      fileSize,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.picture_as_pdf,
                                  color: Colors.blue[500],
                                  size: 20,
                                ),
                                onPressed: () => _addToPdf(index),
                                tooltip: 'Add to PDF',
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.share,
                                  color: Colors.green[500],
                                  size: 20,
                                ),
                                onPressed: () => _shareSignature(index),
                                tooltip: 'Share',
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Colors.red[500],
                                  size: 20,
                                ),
                                onPressed: () => _deleteSignature(index),
                                tooltip: 'Delete',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _saveSignature,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.save),
        label: const Text('Save Signature'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildColorOption(Color color) {
    final isSelected = _selectedColor == color;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedColor = color);
      },
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 14)
            : null,
      ),
    );
  }
}

// Signature Painter Widget
class SignaturePainter extends StatefulWidget {
  final Color strokeColor;
  final double strokeWidth;

  const SignaturePainter({
    super.key,
    this.strokeColor = Colors.black,
    this.strokeWidth = 3.0,
  });

  @override
  State<SignaturePainter> createState() => _SignaturePainterState();
}

class _SignaturePainterState extends State<SignaturePainter> {
  final List<List<Offset>> _strokes = [];
  List<Offset>? _currentStroke;

  bool get isEmpty =>
      _strokes.isEmpty && (_currentStroke == null || _currentStroke!.isEmpty);

  void _startStroke(Offset point) {
    setState(() {
      _currentStroke = [point];
    });
  }

  void _updateStroke(Offset point) {
    if (_currentStroke != null) {
      setState(() {
        _currentStroke = [..._currentStroke!, point];
      });
    }
  }

  void _endStroke() {
    if (_currentStroke != null && _currentStroke!.length > 1) {
      setState(() {
        _strokes.add(List.from(_currentStroke!));
      });
    }
    _currentStroke = null;
  }

  void undo() {
    if (_strokes.isNotEmpty) {
      setState(() {
        _strokes.removeLast();
      });
    }
  }

  void clear() {
    setState(() {
      _strokes.clear();
      _currentStroke = null;
    });
  }

  Future<ui.Image> getImage() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw white background
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 500, 200),
      Paint()..color = Colors.white,
    );

    // Draw strokes
    for (final stroke in _strokes) {
      if (stroke.length < 2) continue;

      final paint = Paint()
        ..color = widget.strokeColor
        ..strokeWidth = widget.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path()..moveTo(stroke[0].dx, stroke[0].dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    // Draw current stroke
    if (_currentStroke != null && _currentStroke!.length > 1) {
      final paint = Paint()
        ..color = widget.strokeColor
        ..strokeWidth = widget.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path()..moveTo(_currentStroke![0].dx, _currentStroke![0].dy);
      for (int i = 1; i < _currentStroke!.length; i++) {
        path.lineTo(_currentStroke![i].dx, _currentStroke![i].dy);
      }
      canvas.drawPath(path, paint);
    }

    final picture = recorder.endRecording();
    return picture.toImage(500, 200);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) => _startStroke(details.localPosition),
      onPanUpdate: (details) => _updateStroke(details.localPosition),
      onPanEnd: (details) => _endStroke(),
      child: CustomPaint(
        painter: _SignaturePainterPainter(
          strokes: _strokes,
          currentStroke: _currentStroke,
          strokeColor: widget.strokeColor,
          strokeWidth: widget.strokeWidth,
        ),
      ),
    );
  }
}

class _SignaturePainterPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset>? currentStroke;
  final Color strokeColor;
  final double strokeWidth;

  _SignaturePainterPainter({
    required this.strokes,
    this.currentStroke,
    required this.strokeColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw white background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    // Draw grid lines for guidance
    final gridPaint = Paint()
      ..color = Colors.grey[200]!
      ..strokeWidth = 0.5;

    for (double y = size.height / 4; y < size.height; y += size.height / 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (double x = size.width / 4; x < size.width; x += size.width / 4) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    final paint = Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Draw completed strokes
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;

      final path = Path()..moveTo(stroke[0].dx, stroke[0].dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    // Draw current stroke
    if (currentStroke != null && currentStroke!.length > 1) {
      final path = Path()..moveTo(currentStroke![0].dx, currentStroke![0].dy);
      for (int i = 1; i < currentStroke!.length; i++) {
        path.lineTo(currentStroke![i].dx, currentStroke![i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainterPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.currentStroke != currentStroke ||
        oldDelegate.strokeColor != strokeColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
