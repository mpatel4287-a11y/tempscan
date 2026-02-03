import 'dart:io';
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
  Color _selectedColor = Colors.white;
  final double _strokeWidth = 3.0;

  final GlobalKey<_SignaturePainterState> _painterKey = GlobalKey<_SignaturePainterState>();

  @override
  void initState() {
    super.initState();
    _loadSavedSignatures();
  }

  Future<void> _loadSavedSignatures() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final signatureDir = Directory('${tempDir.path}/signatures');
      if (await signatureDir.exists()) {
        final files = signatureDir.listSync().where((entity) => entity is File && entity.path.endsWith('.png')).map((entity) => File(entity.path)).toList();
        files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        if (mounted) setState(() => _savedSignatures.addAll(files));
      }
    } catch (e) {
      debugPrint('Load signatures error: $e');
    }
  }

  Future<void> _saveSignature() async {
    if (_painterKey.currentState?.isEmpty ?? true) {
      _showError('Draw a signature first');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final image = await _painterKey.currentState!.getImage();
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final signatureDir = Directory('${tempDir.path}/signatures');
      if (!await signatureDir.exists()) await signatureDir.create(recursive: true);

      final fileName = 'sig_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${signatureDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      setState(() {
        _savedSignatures.insert(0, file);
        _isSaving = false;
      });
      if (!mounted) return;
      _painterKey.currentState?.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signature saved!')));
    } catch (e) {
      setState(() => _isSaving = false);
      _showError('Save failed: $e');
    }
  }

  void _showError(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.redAccent));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Add Signature', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.folder_open_outlined), onPressed: _pickExisting),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildDrawingPad(),
                  if (_savedSignatures.isNotEmpty) ...[
                    const SizedBox(height: 48),
                    _buildSavedSignaturesList(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _saveSignature,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        icon: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(Icons.check),
        label: const Text('SAVE SIGNATURE', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Create Signature', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Draw your unique signature and reuse it on any PDF.', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
      ],
    );
  }

  Widget _buildDrawingPad() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildColorCircle(Colors.white),
                const SizedBox(width: 12),
                _buildColorCircle(Colors.blue),
                const SizedBox(width: 12),
                _buildColorCircle(Colors.red),
                const Spacer(),
                IconButton(icon: const Icon(Icons.undo_rounded, color: Colors.white54), onPressed: () => _painterKey.currentState?.undo()),
                IconButton(icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white54), onPressed: () => _painterKey.currentState?.clear()),
              ],
            ),
          ),
          Container(
            height: 200,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SignaturePainter(key: _painterKey, strokeColor: _selectedColor == Colors.white ? Colors.black : _selectedColor, strokeWidth: _strokeWidth),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorCircle(Color c) {
    bool isSelected = _selectedColor == c;
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = c),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.blueAccent, width: 2) : Border.all(color: Colors.white24),
        ),
        child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.black) : null,
      ),
    );
  }

  Widget _buildSavedSignaturesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Signatures', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _savedSignatures.length,
          itemBuilder: (context, index) {
            final file = _savedSignatures[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 80,
                    height: 50,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    child: Image.file(file, fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(file.path.split('/').last, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1),
                        Text(FileSizeHelper.readable(file), style: TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.share_outlined, color: Colors.white38, size: 20), onPressed: () => Share.shareXFiles([XFile(file.path)])),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                    onPressed: () => setState(() {
                      file.deleteSync();
                      _savedSignatures.removeAt(index);
                    }),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _pickExisting() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      setState(() => _savedSignatures.insert(0, File(result.files.single.path!)));
    }
  }
}

class SignaturePainter extends StatefulWidget {
  final Color strokeColor;
  final double strokeWidth;
  const SignaturePainter({super.key, this.strokeColor = Colors.black, this.strokeWidth = 3.0});

  @override
  State<SignaturePainter> createState() => _SignaturePainterState();
}

class _SignaturePainterState extends State<SignaturePainter> {
  final List<List<Offset>> _strokes = [];
  List<Offset>? _currentStroke;

  bool get isEmpty => _strokes.isEmpty && (_currentStroke == null || _currentStroke!.isEmpty);

  void undo() => setState(() { if (_strokes.isNotEmpty) _strokes.removeLast(); });
  void clear() => setState(() { _strokes.clear(); _currentStroke = null; });

  Future<ui.Image> getImage() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..color = widget.strokeColor
      ..strokeWidth = widget.strokeWidth
      ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

    for (final stroke in _strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke[0].dx, stroke[0].dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
    final picture = recorder.endRecording();
    return picture.toImage(500, 200);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (d) => setState(() => _currentStroke = [d.localPosition]),
      onPanUpdate: (d) => setState(() => _currentStroke!.add(d.localPosition)),
      onPanEnd: (d) {
        if (_currentStroke != null && _currentStroke!.length > 1) {
          setState(() => _strokes.add(List.from(_currentStroke!)));
        }
        _currentStroke = null;
      },
      child: CustomPaint(
        painter: _Painter(strokes: _strokes, current: _currentStroke, color: widget.strokeColor, width: widget.strokeWidth),
        size: Size.infinite,
      ),
    );
  }
}

class _Painter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset>? current;
  final Color color;
  final double width;
  _Painter({required this.strokes, this.current, required this.color, required this.width});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final s in strokes) {
      if (s.length < 2) continue;
      final p = Path()..moveTo(s[0].dx, s[0].dy);
      for (int i = 1; i < s.length; i++) {
        p.lineTo(s[i].dx, s[i].dy);
      }
      canvas.drawPath(p, paint);
    }
    if (current != null && current!.length > 1) {
      final p = Path()..moveTo(current![0].dx, current![0].dy);
      for (int i = 1; i < current!.length; i++) {
        p.lineTo(current![i].dx, current![i].dy);
      }
      canvas.drawPath(p, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _Painter old) => true;
}
