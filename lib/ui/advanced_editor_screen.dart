import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:temp_scan/services/advanced_ocr_engine.dart';
import 'package:temp_scan/services/eraser_service.dart';
import 'package:temp_scan/services/form_recognition_service.dart';
import 'package:temp_scan/services/translation_service.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class AdvancedEditorScreen extends StatefulWidget {
  final File documentFile;

  const AdvancedEditorScreen({super.key, required this.documentFile});

  @override
  State<AdvancedEditorScreen> createState() => _AdvancedEditorScreenState();
}

class _AdvancedEditorScreenState extends State<AdvancedEditorScreen> {
  bool _isLoading = true;
  late File _currentImage;
  List<EditableTextBlock> _textBlocks = [];
  EditableTextBlock? _activeBlock;
  
  // Transform controllers for zooming/panning
  final TransformationController _transformController = TransformationController();
  
  // Text Editing Controller for active block
  final TextEditingController _textEditingController = TextEditingController();
  
  // Image Dimensions for scaling boxes
  double _imageWidth = 1.0;
  double _imageHeight = 1.0;
  
  @override
  void initState() {
    super.initState();
    _currentImage = widget.documentFile;
    _initializeEditor();
  }

  Future<void> _initializeEditor() async {
    // 1. Get exact image dimensions so we can map ML Kit bounding boxes perfectly
    final decodedImage = await decodeImageFromList(await _currentImage.readAsBytes());
    _imageWidth = decodedImage.width.toDouble();
    _imageHeight = decodedImage.height.toDouble();

    // 2. Parse Text Blocks using ML Kit
    _textBlocks = await AdvancedOcrEngine.instance.parseDocument(_currentImage);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _onBlockTapped(EditableTextBlock block) async {
    setState(() => _isLoading = true);
    
    // 1. Visually "Erase" the text from the background image
    final erasedImage = await EraserService.instance.eraseArea(_currentImage, block.boundingBox);
    
    setState(() {
      _currentImage = erasedImage; // Update canvas to show the "blank" space
      _activeBlock = block;
      _textEditingController.text = block.text;
      _isLoading = false;
    });
  }

  void _saveActiveBlockEdit() {
    if (_activeBlock == null) return;
    
    setState(() {
      _activeBlock!.text = _textEditingController.text;
      _activeBlock = null; // Deselect
    });
    
    // Note: The background image remains "erased". 
    // The new text is permanently floating as a Flutter Widget for now.
    // At export, we will flatten it all.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Advanced Editor'),
        actions: [
          if (_activeBlock != null)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveActiveBlockEdit,
            ),
          IconButton(
            icon: const Icon(Icons.dynamic_form_outlined),
            onPressed: _detectForms,
            tooltip: 'Detect Form Fields',
          ),
          IconButton(
            icon: const Icon(Icons.translate),
            onPressed: _showTranslateDialog,
            tooltip: 'Translate Document',
          ),
          TextButton(
             onPressed: _isLoading ? null : _exportDocument, 
             child: const Text('Export', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : _buildCanvas(),
    );
  }

  Future<void> _exportDocument() async {
    setState(() => _isLoading = true);

    try {
      // 1. Prepare PictureRecorder and Canvas at native image resolution
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      // 2. Load the current background image as a ui.Image
      final data = await _currentImage.readAsBytes();
      final codec = await ui.instantiateImageCodec(data);
      final frame = await codec.getNextFrame();
      final ui.Image image = frame.image;

      // 3. Draw the background image
      canvas.drawImage(image, Offset.zero, Paint());

      // 4. Draw each text block
      for (final block in _textBlocks) {
        final textStyle = ui.TextStyle(
          color: Colors.black,
          fontSize: block.estimatedFontSize,
          fontFamily: block.estimatedFontFamily,
        );
        final paragraphStyle = ui.ParagraphStyle(textAlign: TextAlign.left);
        final paragraphBuilder = ui.ParagraphBuilder(paragraphStyle)
          ..pushStyle(textStyle)
          ..addText(block.text);

        final paragraph = paragraphBuilder.build();
        // Constraints based on bounding box width
        paragraph.layout(ui.ParagraphConstraints(width: block.boundingBox.width));

        canvas.drawParagraph(paragraph, Offset(block.boundingBox.left, block.boundingBox.top));
      }

      // 5. Convert back to image and save
      final ui.Image renderedImage = await recorder.endRecording().toImage(
        image.width,
        image.height,
      );
      final byteData = await renderedImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to render edited image');

      final finalBytes = byteData.buffer.asUint8List();
      
      // Save to a fresh temp file
      final tempDir = Directory.systemTemp;
      final outputFile = File('${tempDir.path}/edited_doc_${DateTime.now().millisecondsSinceEpoch}.png');
      await outputFile.writeAsBytes(finalBytes);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document exported successfully!')));
        Navigator.pop(context, outputFile); // Return the newly edited file
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _detectForms() {
    final fields = FormRecognitionService.instance.detectFields(_textBlocks);
    
    if (fields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No form fields detected')));
      return;
    }

    setState(() {
      for (final field in fields) {
        // Add form fields as editable blocks
        _textBlocks.add(EditableTextBlock(
          text: '', // Empty for user to fill
          boundingBox: field.boundingBox,
          estimatedFontSize: field.boundingBox.height * 0.75,
          estimatedFontFamily: 'Sans-Serif',
          cornerPoints: [],
        ));
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Detected ${fields.length} potential fields')));
  }

  void _showTranslateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Select Target Language', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: TranslationService.supportedLanguages.length,
            itemBuilder: (context, index) {
              final entry = TranslationService.supportedLanguages.entries.elementAt(index);
              return ListTile(
                title: Text(entry.key, style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _translateDocument(entry.value);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _translateDocument(TranslateLanguage target) async {
    setState(() => _isLoading = true);

    try {
      final source = TranslateLanguage.english; // Assume English as source for now, could be improved

      // 1. Check if model is downloaded
      final isDownloaded = await TranslationService.instance.isModelDownloaded(target);
      if (!isDownloaded) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading translation model...')));
        }
        await TranslationService.instance.downloadModel(target);
      }

      // 2. Translate all blocks
      final List<String> originalTexts = _textBlocks.map((b) => b.text).toList();
      final List<String> translatedTexts = await TranslationService.instance.translateBatch(
        texts: originalTexts,
        source: source,
        target: target,
      );

      // 3. Update blocks and erase original text backgrounds
      for (int i = 0; i < _textBlocks.length; i++) {
        final block = _textBlocks[i];
        if (block.text.trim().isNotEmpty) {
           // We erase the original text background to make space for translated text
           final erasedImage = await EraserService.instance.eraseArea(_currentImage, block.boundingBox);
           _currentImage = erasedImage;
        }
        block.text = translatedTexts[i];
      }

      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Translation complete')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Translation failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate scaling factors between actual image size and screen size
        // We use BoxFit.contain for the image, so we need to know how it scales
        final double screenRatio = constraints.maxWidth / constraints.maxHeight;
        final double imageRatio = _imageWidth / _imageHeight;
        
        double displayWidth, displayHeight;
        
        if (screenRatio > imageRatio) {
          // Height is constrained
          displayHeight = constraints.maxHeight;
          displayWidth = displayHeight * imageRatio;
        } else {
          // Width is constrained
          displayWidth = constraints.maxWidth;
          displayHeight = displayWidth / imageRatio;
        }

        final scaleX = displayWidth / _imageWidth;
        final scaleY = displayHeight / _imageHeight;

        return InteractiveViewer(
          transformationController: _transformController,
          minScale: 1.0,
          maxScale: 5.0,
          panEnabled: _activeBlock == null, // Disable pan when editing
          scaleEnabled: _activeBlock == null, // Disable scale when editing
          child: Center(
            child: SizedBox(
               width: displayWidth,
               height: displayHeight,
               child: Stack(
                 children: [
                   // Base Image (Erased or Original)
                   Image.file(_currentImage, width: displayWidth, height: displayHeight, fit: BoxFit.contain),
                   
                   // Interactive Overlays
                   ..._textBlocks.map((block) {
                       final rect = block.boundingBox;
                       
                       // Scale ML Kit rect coordinates to match current screen display
                       final left = rect.left * scaleX;
                       final top = rect.top * scaleY;
                       final width = rect.width * scaleX;
                       final height = rect.height * scaleY;
                       
                       // The scaled estimated font size
                       final displayFontSize = block.estimatedFontSize * scaleY;

                       // If this is the currently actively edited block
                       if (_activeBlock == block) {
                          return Positioned(
                             left: left,
                             top: top,
                             width: width + 50, // Give some extra breathing room for typing
                             height: height,
                             child: Material(
                               color: Colors.transparent,
                               child: TextField(
                                  controller: _textEditingController,
                                  autofocus: true,
                                  style: TextStyle(
                                    fontSize: displayFontSize,
                                    fontFamily: block.estimatedFontFamily,
                                    color: Colors.black, // Default text color, could sample later
                                    height: 1.0,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  maxLines: null,
                               ),
                             ),
                          );
                       }

                       // If this is just a normal, unselected block
                       return Positioned(
                          left: left,
                          top: top,
                          width: width,
                          height: height,
                          child: GestureDetector(
                             behavior: HitTestBehavior.opaque,
                             onTap: () => _onBlockTapped(block),
                             child: Container(
                               // Slight yellow highlight to show it's editable when not active
                               decoration: BoxDecoration(
                                 border: Border.all(color: Colors.yellow.withValues(alpha: 0.3)),
                                 color: Colors.yellow.withValues(alpha: 0.1),
                               ),
                               child: Text(
                                 block.text,
                                 style: TextStyle(
                                   fontSize: displayFontSize,
                                   fontFamily: block.estimatedFontFamily,
                                   color: Colors.black, // Show black text on the erased background
                                 ),
                               ),
                             ),
                          ),
                       );
                   }),
                 ],
               ),
            ),
          ),
        );
      },
    );
  }
}
