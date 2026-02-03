// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import '../temp_storage/temp_image_manager.dart';
import 'crop_screen.dart';
import '../services/signature_service.dart';
import 'dart:io';
import 'dart:math' as math;
import 'annotation_sheet.dart';
import 'rename_dialog.dart';
import 'signature_screen.dart';

enum EditTool { none, rotate, filter, enhance, markup, signature }

/// Main edit image screen with all tools
/// Opens when user taps/holds on any image in review screen
class EditImageScreen extends StatefulWidget {
  final int pageIndex;

  const EditImageScreen({super.key, required this.pageIndex});

  @override
  State<EditImageScreen> createState() => _EditImageScreenState();
}

class _EditImageScreenState extends State<EditImageScreen> {
  final _manager = TempImageManager();

  late ScannedPage _page;
  late int _currentRotation;
  late ImageFilter _currentFilter;
  late Map<String, double> _currentFilterValues;
  late CropRect _currentCropRect;

  bool _showCropScreen = false;
  bool _showSignaturePicker = false;
  
  String? _signaturePath;
  Offset? _signaturePosition;
  
  bool _showAnnotationSheet = false;
  List<Annotation> _annotations = [];
  AnnotationType _currentAnnotationType = AnnotationType.pen;
  Color _currentAnnotationColor = Colors.yellowAccent;
  double _currentAnnotationWidth = 4.0;
  List<Offset> _currentPoints = [];
  
  double _clarity = 0.0;
  double _noiseReduction = 0.0;
  
  int _activeTabIndex = 0; // 0: Fix, 1: Enhance, 2: Markup
  EditTool _activeTool = EditTool.none;
  double _rotationAngle = 0.0;
  List<File> _savedSignatures = [];

  @override
  void initState() {
    super.initState();
    _loadPageData();
    _loadSignatures();
  }

  Future<void> _loadSignatures() async {
    final sigs = await SignatureService.getSavedSignatures();
    if (mounted) setState(() => _savedSignatures = sigs);
  }

  void _loadPageData() {
    final page = _manager.getPage(widget.pageIndex);
    if (page != null) {
      _page = page;
      _currentRotation = page.rotation;
      _currentFilter = page.filter;
      _currentFilterValues = Map.from(page.filterValues);
      _currentCropRect = page.cropRect;
      _signaturePath = page.signaturePath;
      _signaturePosition = page.signaturePosition;
      _annotations = List.from(page.annotations);
      _clarity = page.clarity;
      _noiseReduction = page.noiseReduction;
      _rotationAngle = page.rotation.toDouble();
    }
  }

  void _updatePageData() {
    _manager.rotatePage(widget.pageIndex, _currentRotation - _page.rotation);
    _manager.applyFilter(
      widget.pageIndex,
      _currentFilter,
      _currentFilterValues,
    );
    _manager.applyCrop(widget.pageIndex, _currentCropRect);
    _manager.applySignature(widget.pageIndex, _signaturePath, _signaturePosition);
    _manager.applyAnnotations(widget.pageIndex, _annotations);
    _manager.applyEnhancements(widget.pageIndex, clarity: _clarity, noiseReduction: _noiseReduction);
  }

  Future<void> _deleteImage() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Image?'),
        content: const Text('This image will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _manager.removePage(_page);
      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate deletion
      }
    }
  }

  void _showCrop() {
    setState(() {
      _showCropScreen = true;
    });
  }

  void _hideCrop() {
    setState(() {
      _showCropScreen = false;
    });
  }

  void _onCropChanged(CropRect newCrop) {
    _currentCropRect = newCrop;
    _updatePageData();
  }

  void _onCropApplied() {
    _hideCrop();
  }

  void _onCropReset() {
    _currentCropRect = CropRect.full;
    _updatePageData();
  }



  void _onFilterSelected(ImageFilter filter, Map<String, double> values) {
    setState(() {
      _currentFilter = filter;
      _currentFilterValues = values;
    });
    _updatePageData();
  }


  void _onRotated(int degrees) {
    setState(() {
      _rotationAngle += degrees;
      _currentRotation = (_rotationAngle.round()) % 360;
      if (_currentRotation < 0) _currentRotation += 360;
    });
    _updatePageData();
  }

  ColorFilter? _getColorFilter() {
    switch (_currentFilter) {
      case ImageFilter.none:
        return null;
      case ImageFilter.grayscale:
        return const ColorFilter.matrix([
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case ImageFilter.sepia:
        return const ColorFilter.matrix([
          0.393,
          0.769,
          0.189,
          0,
          0,
          0.349,
          0.686,
          0.168,
          0,
          0,
          0.272,
          0.534,
          0.131,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case ImageFilter.brightness:
        final brightness = _currentFilterValues['value'] ?? 0.0;
        final adjusted = brightness * 128;
        return ColorFilter.matrix([
          1,
          0,
          0,
          0,
          adjusted,
          0,
          1,
          0,
          0,
          adjusted,
          0,
          0,
          1,
          0,
          adjusted,
          0,
          0,
          0,
          1,
          0,
        ]);
      case ImageFilter.contrast:
        final contrast = _currentFilterValues['value'] ?? 0.0;
        final factor = (contrast + 1) * contrast;
        return ColorFilter.matrix([
          factor,
          0,
          0,
          0,
          128 * (1 - factor),
          0,
          factor,
          0,
          0,
          128 * (1 - factor),
          0,
          0,
          factor,
          0,
          128 * (1 - factor),
          0,
          0,
          0,
          1,
          0,
        ]);
      case ImageFilter.saturation:
        final saturation = _currentFilterValues['value'] ?? 0.0;
        final luminance = 0.2126 + 0.7152 + 0.0722;
        return ColorFilter.matrix([
          (1 - saturation) * 0.2126 + saturation,
          (1 - saturation) * 0.7152,
          (1 - saturation) * 0.0722,
          0,
          0,
          (1 - saturation) * 0.2126,
          (1 - saturation) * 0.7152 + saturation,
          (1 - saturation) * 0.0722,
          0,
          0,
          (1 - saturation) * 0.2126,
          (1 - saturation) * 0.7152,
          (1 - saturation) * 0.0722 + saturation,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case ImageFilter.modernPro:
        // High contrast, slight exposure boost, white balance correction
        return const ColorFilter.matrix([
          1.2, 0.1, 0.1, 0, -20,
          0.1, 1.2, 0.1, 0, -20,
          0.1, 0.1, 1.2, 0, -20,
          0, 0, 0, 1, 0,
        ]);
      case ImageFilter.vintageDoc:
        // Sepia-like but preserving text contrast
        return const ColorFilter.matrix([
          0.9, 0.5, 0.1, 0, 0,
          0.3, 0.8, 0.1, 0, 0,
          0.2, 0.3, 0.5, 0, 0,
          0, 0, 0, 1, 0,
        ]);
    }
  }

  Future<void> _showSignature() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SignatureScreen()),
    );
    _loadSignatures();
  }

  void _hideSignature() {
    setState(() => _showSignaturePicker = false);
  }

  void _onSignaturePicked(File file) {
    setState(() {
      _signaturePath = file.path;
      _signaturePosition ??= const Offset(0.7, 0.8);
      _showSignaturePicker = false;
    });
    _updatePageData();
  }

  void _removeSignature() {
    setState(() {
      _signaturePath = null;
      _signaturePosition = null;
    });
    _updatePageData();
  }

  void _showAnnotations() {
    setState(() => _showAnnotationSheet = true);
  }

  void _hideAnnotations() {
    setState(() => _showAnnotationSheet = false);
  }

  void _onUndoAnnotation() {
    if (_annotations.isNotEmpty) {
      setState(() => _annotations.removeLast());
      _updatePageData();
    }
  }

  void _onClearAnnotations() {
    setState(() => _annotations.clear());
    _updatePageData();
  }

  Future<void> _showTextInputDialog(Offset position) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Add Text', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter text here...',
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add', style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );

    if (text != null && text.isNotEmpty) {
      setState(() {
        _annotations.add(Annotation(
          points: [position],
          color: _currentAnnotationColor,
          type: AnnotationType.text,
          text: text,
        ));
      });
      _updatePageData();
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_showCropScreen) {
      return CropScreen(
        imagePath: _page.file.path,
        initialCrop: _currentCropRect,
        rotation: _currentRotation,
        onCropChanged: _onCropChanged,
        onApply: _onCropApplied,
        onReset: _onCropReset,
        onCancel: _hideCrop,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(child: Center(child: _buildImagePreview())),
                _buildBottomToolbar(),
              ],
            ),
          ),

          if (_showSignaturePicker) _buildSignaturePicker(),
          if (_showAnnotationSheet) _buildAnnotationSheet(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        border: const Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              _updatePageData();
              Navigator.pop(context);
            },
          ),
          Text(
            'Edit Page ${widget.pageIndex + 1}',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _currentRotation = 0;
                _rotationAngle = 0.0;
                _currentFilter = ImageFilter.none;
                _currentFilterValues = {};
                _currentCropRect = CropRect.full;
                _clarity = 0.0;
                _noiseReduction = 0.0;
                _annotations.clear();
                _signaturePath = null;
              });
              _updatePageData();
            },
            child: const Text('Reset', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    final colorFilter = _getColorFilter();

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 3.0,
      panEnabled: !_showAnnotationSheet,
      scaleEnabled: !_showAnnotationSheet,
      child: AnimatedRotation(
        turns: _rotationAngle / 360,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: ClipRect(
          child: ColorFiltered(
            colorFilter: colorFilter ?? const ColorFilter.matrix([1,0,0,0,0,0,1,0,0,0,0,0,1,0,0,0,0,0,1,0]),
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRect(
                  child: FractionallySizedBox(
                    widthFactor: 1 / _currentCropRect.width,
                    heightFactor: 1 / _currentCropRect.height,
                    alignment: Alignment(
                      -1.0 + (_currentCropRect.x + _currentCropRect.width / 2) * 2 / (1 - _currentCropRect.width + 0.00001),
                      -1.0 + (_currentCropRect.y + _currentCropRect.height / 2) * 2 / (1 - _currentCropRect.height + 0.00001),
                    ),
                    child: Image.file(_page.file, fit: BoxFit.contain),
                  ),
                ),
                // Annotations Layer (Drawing only)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _AnnotationPainter(
                      annotations: _annotations.where((a) => a.type != AnnotationType.text).toList(),
                      currentPoints: _currentPoints,
                      currentType: _currentAnnotationType,
                      currentColor: _currentAnnotationColor,
                      currentWidth: _currentAnnotationWidth,
                    ),
                  ),
                ),
                if (_showAnnotationSheet)
                  Positioned.fill(
                    child: GestureDetector(
                      onTapDown: (details) {
                        if (_currentAnnotationType == AnnotationType.text) {
                          _showTextInputDialog(details.localPosition);
                        }
                      },
                      onPanStart: (details) {
                        if (_currentAnnotationType != AnnotationType.text) {
                          setState(() => _currentPoints = [details.localPosition]);
                        }
                      },
                      onPanUpdate: (details) {
                        if (_currentAnnotationType != AnnotationType.text) {
                          setState(() => _currentPoints.add(details.localPosition));
                        }
                      },
                      onPanEnd: (_) {
                        if (_currentPoints.isNotEmpty) {
                          setState(() {
                            _annotations.add(Annotation(
                              points: List.from(_currentPoints),
                              color: _currentAnnotationColor,
                              strokeWidth: _currentAnnotationWidth,
                              type: _currentAnnotationType,
                            ));
                            _currentPoints = [];
                          });
                          _updatePageData();
                        }
                      },
                    ),
                  ),
                // Text Annotations Layer (Draggable Widgets)
                ..._buildTextAnnotations(),
                if (_signaturePath != null) _buildDraggableSignature(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTextAnnotations() {
    return _annotations.where((a) => a.type == AnnotationType.text).map((annotation) {
      final pos = annotation.position ?? (annotation.points.isNotEmpty ? annotation.points.first : Offset.zero);
      return _buildDraggableText(annotation, pos);
    }).toList();
  }

  Widget _buildDraggableText(Annotation annotation, Offset position) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            annotation.position = position + details.delta;
          });
        },
        onPanEnd: (_) => _updatePageData(),
        onTap: () => _editAnnotation(annotation),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            annotation.text ?? '',
            style: TextStyle(
              color: annotation.color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              shadows: [
                Shadow(offset: const Offset(1, 1), blurRadius: 2, color: Colors.black.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editAnnotation(Annotation annotation) async {
    final controller = TextEditingController(text: annotation.text);
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text('Edit Text', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Enter text...', hintStyle: TextStyle(color: Colors.white38)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context, controller.text);
            },
            child: const Text('Save', style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );

    if (text != null) {
      setState(() {
        final index = _annotations.indexOf(annotation);
        if (index != -1) {
          _annotations[index] = Annotation(
            id: annotation.id,
            points: annotation.points,
            color: annotation.color,
            type: annotation.type,
            text: text,
            position: annotation.position,
          );
        }
      });
      _updatePageData();
    }
  }

  Widget _buildDraggableSignature() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double left = (_signaturePosition?.dx ?? 0.7) * constraints.maxWidth;
        final double top = (_signaturePosition?.dy ?? 0.8) * constraints.maxHeight;

        return Positioned(
          left: left - 40,
          top: top - 25,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                double newDx = (_signaturePosition!.dx * constraints.maxWidth + details.delta.dx) / constraints.maxWidth;
                double newDy = (_signaturePosition!.dy * constraints.maxHeight + details.delta.dy) / constraints.maxHeight;
                _signaturePosition = Offset(newDx.clamp(0.0, 1.0), newDy.clamp(0.0, 1.0));
              });
            },
            onPanEnd: (_) => _updatePageData(),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                 Image.file(File(_signaturePath!), width: 120, height: 80, fit: BoxFit.contain, color: Colors.black),
                 Positioned(
                  top: -15,
                  right: -15,
                  child: GestureDetector(
                    onTap: _removeSignature,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _buildSignaturePicker() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Select Signature', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: _hideSignature),
                ],
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<File>>(
                future: SignatureService.getSavedSignatures(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text('No saved signatures found', style: TextStyle(color: Colors.white38)),
                    );
                  }
                  return SizedBox(
                    height: 200,
                    child: ListView.builder(
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final file = snapshot.data![index];
                        return InkWell(
                          onTap: () => _onSignaturePicked(file),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 40,
                                  color: Colors.white,
                                  child: Image.file(file, fit: BoxFit.contain),
                                ),
                                const SizedBox(width: 16),
                                const Text('Signature', style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnnotationSheet() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: AnnotationSheet(
        currentType: _currentAnnotationType,
        currentColor: _currentAnnotationColor,
        currentWidth: _currentAnnotationWidth,
        onSettingsChanged: (type, color, width) {
          setState(() {
            _currentAnnotationType = type;
            _currentAnnotationColor = color;
            _currentAnnotationWidth = width;
          });
        },
        onCancel: _hideAnnotations,
        onUndo: _onUndoAnnotation,
        onClear: _onClearAnnotations,
      ),
    );
  }

  Widget _buildBottomToolbar() {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_activeTool != EditTool.none)
            _buildSubToolMenu()
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _buildActiveTools(),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white10))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTabItem(0, 'FIX', Icons.auto_fix_high),
                _buildTabItem(1, 'ENHANCE', Icons.auto_awesome),
                _buildTabItem(2, 'MARKUP', Icons.draw),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String label, IconData icon) {
    final isSelected = _activeTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() {
        _activeTabIndex = index;
        _activeTool = EditTool.none; // Reset sub-tool when changing category
        _showSignaturePicker = false;
      }),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isSelected ? Colors.blueAccent : Colors.white38, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.blueAccent : Colors.white38,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isSelected)
            Container(margin: const EdgeInsets.only(top: 4), height: 2, width: 24, color: Colors.blueAccent),
        ],
      ),
    );
  }

  List<Widget> _buildActiveTools() {
    if (_activeTool != EditTool.none) {
      return [_buildSubToolMenu()];
    }

    switch (_activeTabIndex) {
      case 0: // Fix
        return [
          _buildToolButton(icon: Icons.crop, label: 'Crop', onTap: _showCrop),
          _buildToolButton(icon: Icons.rotate_right, label: 'Rotate', onTap: () => setState(() => _activeTool = EditTool.rotate)),
          _buildToolButton(icon: Icons.edit_note, label: 'Rename', onTap: _showRenameDialog),
          _buildToolButton(icon: Icons.delete, label: 'Delete', onTap: _deleteImage, color: Colors.red),
        ];
      case 1: // Enhance
        return [
          _buildToolButton(icon: Icons.filter_alt, label: 'Filter', onTap: () => setState(() => _activeTool = EditTool.filter)),
          _buildToolButton(icon: Icons.tune, label: 'Fine-Tune', onTap: () => setState(() => _activeTool = EditTool.enhance)),
        ];
      case 2: // Markup
        return [
          _buildToolButton(icon: Icons.history_edu_rounded, label: 'Sign', onTap: () => setState(() => _activeTool = EditTool.signature)),
          _buildToolButton(icon: Icons.gesture, label: 'Markup', onTap: _showAnnotations),
        ];
      default:
        return [];
    }
  }

  Widget _buildSubToolMenu() {
    Widget content;
    String title;

    switch (_activeTool) {
      case EditTool.rotate:
        title = 'Rotate';
        content = Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(Icons.rotate_left, '90° Left', () => _onRotated(-90)),
                _buildActionButton(Icons.rotate_right, '90° Right', () => _onRotated(90)),
                _buildActionButton(Icons.flip, 'Flip', () => _onRotated(180)),
              ],
            ),
            const SizedBox(height: 12),
            _buildInlineSlider(
              label: 'Custom Angle',
              value: (_rotationAngle % 360) / 360,
              onChanged: (v) {
                final angle = v * 360;
                setState(() {
                  _rotationAngle = angle;
                  _currentRotation = angle.round() % 360;
                });
                _updatePageData();
              },
            ),
          ],
        );
        break;
      case EditTool.enhance:
        title = 'Fine-Tune Quality';
        content = Column(
          children: [
            _buildInlineSlider(
              label: 'Clarity',
              value: _clarity,
              onChanged: (v) => setState(() {
                _clarity = v;
                _updatePageData();
              }),
            ),
            _buildInlineSlider(
              label: 'Noise Reduction',
              value: _noiseReduction,
              onChanged: (v) => setState(() {
                _noiseReduction = v;
                _updatePageData();
              }),
            ),
          ],
        );
        break;
      case EditTool.filter:
        title = 'Apply Filter';
        content = SizedBox(
          height: 80,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: ImageFilter.values.map((f) {
              final isSelected = _currentFilter == f;
              return GestureDetector(
                onTap: () {
                  _onFilterSelected(f, {});
                  setState(() {});
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blueAccent : Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSelected ? Colors.blueAccent : Colors.white24),
                  ),
                  child: Center(
                    child: Text(
                      f.name.toUpperCase(),
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
        break;
      case EditTool.signature:
        title = 'Add Signature';
        content = SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildAddSignatureButton(),
              ..._savedSignatures.map((f) => _buildSignatureThumbnail(f)),
            ],
          ),
        );
        break;
      default:
        return Container();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                onPressed: () => setState(() => _activeTool = EditTool.none),
              ),
            ],
          ),
          const SizedBox(height: 8),
          content,
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: Colors.blueAccent, size: 28),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildInlineSlider({required String label, required double value, required ValueChanged<double> onChanged}) {
    return Row(
      children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10))),
        Expanded(
          child: Slider(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.blueAccent,
            inactiveColor: Colors.white10,
          ),
        ),
        Text('${(value * 100).toInt()}%', style: const TextStyle(color: Colors.blueAccent, fontSize: 10)),
      ],
    );
  }

  Future<void> _showRenameDialog() async {
    showDialog(
      context: context,
      builder: (context) => RenameDialog(
        initialName: _page.effectiveName,
        onConfirm: (newName) {
          _manager.setCustomName(widget.pageIndex, newName);
          setState(() {});
        },
      ),
    );
  }

  Widget _buildAddSignatureButton() {
    return GestureDetector(
      onTap: _showSignature,
      child: Container(
        width: 80,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: const Icon(Icons.add, color: Colors.white54),
      ),
    );
  }

  Widget _buildSignatureThumbnail(File file) {
    return GestureDetector(
      onTap: () => _onSignaturePicked(file),
      onLongPress: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Signature?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
            ],
          ),
        );
        if (confirm == true) {
          await SignatureService.deleteSignature(file);
          _loadSignatures();
        }
      },
      child: Container(
        width: 80,
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Image.file(file, fit: BoxFit.contain, color: Colors.white70),
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: (color ?? Colors.white).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color ?? Colors.white, size: 26),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: color ?? Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _AnnotationPainter extends CustomPainter {
  final List<Annotation> annotations;
  final List<Offset> currentPoints;
  final AnnotationType currentType;
  final Color currentColor;
  final double currentWidth;

  _AnnotationPainter({
    required this.annotations,
    required this.currentPoints,
    required this.currentType,
    required this.currentColor,
    required this.currentWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Paint saved annotations
    for (final annotation in annotations) {
      _drawAnnotation(canvas, annotation);
    }

    // Paint current drawing
    if (currentPoints.isNotEmpty) {
      final current = Annotation(
        points: currentPoints,
        color: currentColor,
        strokeWidth: currentWidth,
        type: currentType,
      );
      _drawAnnotation(canvas, current);
    }
  }

  void _drawAnnotation(Canvas canvas, Annotation annotation) {
    if (annotation.points.isEmpty) return;

    final paint = Paint()
      ..color = annotation.color
      ..strokeWidth = annotation.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Adjust paint for highlights
    if (annotation.type == AnnotationType.highlight) {
      paint.color = annotation.color.withValues(alpha: 0.4);
      paint.strokeWidth = annotation.strokeWidth * 2.5; // Thicker for highlight
    }

    switch (annotation.type) {
      case AnnotationType.highlight:
      case AnnotationType.pen:
        final path = Path();
        path.moveTo(annotation.points.first.dx, annotation.points.first.dy);
        for (int i = 1; i < annotation.points.length; i++) {
          path.lineTo(annotation.points[i].dx, annotation.points[i].dy);
        }
        canvas.drawPath(path, paint);
        break;

      case AnnotationType.underline:
        final first = annotation.points.first;
        final last = annotation.points.last;
        canvas.drawLine(first, Offset(last.dx, first.dy), paint);
        break;

      case AnnotationType.square:
        final first = annotation.points.first;
        final last = annotation.points.last;
        canvas.drawRect(Rect.fromPoints(first, last), paint);
        break;

      case AnnotationType.circle:
        final first = annotation.points.first;
        final last = annotation.points.last;
        canvas.drawOval(Rect.fromPoints(first, last), paint);
        break;

      case AnnotationType.arrow:
        final first = annotation.points.first;
        final last = annotation.points.last;
        canvas.drawLine(first, last, paint);
        
        // Draw arrowhead
        final angle = (last - first).direction;
        const arrowAngle = 3.14159 / 6;
        const arrowLength = 20.0;
        
        final path = Path();
        path.moveTo(last.dx - arrowLength * (last - first).dx / (last - first).distance * 0.5, last.dy); // simplified for brevity
        // Actually computing arrowhead points
        final p1 = Offset(last.dx - arrowLength * math.cos(angle - arrowAngle), last.dy - arrowLength * math.sin(angle - arrowAngle));
        final p2 = Offset(last.dx - arrowLength * math.cos(angle + arrowAngle), last.dy - arrowLength * math.sin(angle + arrowAngle));
        
        canvas.drawLine(last, p1, paint);
        canvas.drawLine(last, p2, paint);
        break;

      case AnnotationType.text:
        if (annotation.text != null) {
          final textPainter = TextPainter(
            text: TextSpan(
              text: annotation.text,
              style: TextStyle(
                color: annotation.color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                backgroundColor: Colors.black45,
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();
          textPainter.paint(canvas, annotation.points.first);
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _AnnotationPainter oldDelegate) => true;
}
