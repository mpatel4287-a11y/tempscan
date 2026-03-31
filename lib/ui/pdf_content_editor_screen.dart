import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/pdf_extraction_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;
import 'pdf_success_screen.dart';
import '../services/document_storage_service.dart';
import '../models/document.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:image_picker/image_picker.dart';

class PdfContentEditorScreen extends StatefulWidget {
  final String filePath;

  const PdfContentEditorScreen({super.key, required this.filePath});

  @override
  State<PdfContentEditorScreen> createState() => _PdfContentEditorScreenState();
}

class _PdfContentEditorScreenState extends State<PdfContentEditorScreen> {
  List<PdfElement> _elements = [];
  bool _isLoading = true;
  PdfController? _pdfController;
  int _pageCount = 0;
  final Map<int, Uint8List> _pageImages = {};
  final ScrollController _scrollController = ScrollController();
  int _activePage = 0;

  @override
  void initState() {
    super.initState();
    _loadContent();
    _scrollController.addListener(_updateActivePage);
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _updateActivePage() {
    if (_scrollController.hasClients) {
      // Very rough estimate of active page based on scroll position
      // In a real app, this would be more precise
      final double position = _scrollController.offset;
      final int newPage = (position / 800).floor().clamp(0, _pageCount - 1);
      if (newPage != _activePage) {
        setState(() => _activePage = newPage);
      }
    }
  }

  Future<void> _loadContent() async {
    final elements = await PdfExtractionService.extractContent(widget.filePath);
    
    _pdfController = PdfController(
      document: PdfDocument.openFile(widget.filePath),
    );
    final doc = await _pdfController!.document;
    
    setState(() {
      _elements = elements;
      _pageCount = doc.pagesCount;
      _isLoading = false;
    });
  }

  Future<Uint8List?> _renderPage(int pageIndex) async {
    if (_pageImages.containsKey(pageIndex)) return _pageImages[pageIndex];
    
    try {
      final doc = await _pdfController!.document;
      final page = await doc.getPage(pageIndex + 1);
      final pageImage = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: PdfPageImageFormat.jpeg,
        quality: 100,
      );
      await page.close();
      if (pageImage != null) {
        _pageImages[pageIndex] = pageImage.bytes;
        return pageImage.bytes;
      }
    } catch (e) {
      debugPrint('Error rendering page $pageIndex: $e');
    }
    return null;
  }

  Future<void> _addText() async {
    final elementsOnPage = _elements.where((e) => e.pageIndex == _activePage).toList();
    final Size pageSize = elementsOnPage.isNotEmpty ? elementsOnPage.first.pageSize : const Size(595, 842);

    setState(() {
      _elements.add(PdfElement(
        type: PdfElementType.text,
        text: 'New Text',
        x: pageSize.width / 4,
        y: pageSize.height / 4,
        width: 200,
        height: 40,
        pageIndex: _activePage,
        pageSize: pageSize,
      ));
    });
  }

  Future<void> _addImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final bytes = await image.readAsBytes();
    final elementsOnPage = _elements.where((e) => e.pageIndex == _activePage).toList();
    final Size pageSize = elementsOnPage.isNotEmpty ? elementsOnPage.first.pageSize : const Size(595, 842);

    setState(() {
      _elements.add(PdfElement(
        type: PdfElementType.image,
        imageBytes: bytes,
        x: pageSize.width / 4,
        y: pageSize.height / 3,
        width: 150,
        height: 100,
        pageIndex: _activePage,
        pageSize: pageSize,
      ));
    });
  }

  Future<void> _savePdf() async {
    setState(() => _isLoading = true);
    
    try {
      final sfpdf.PdfDocument document = sfpdf.PdfDocument();
      
      for (int i = 0; i < _pageCount; i++) {
        final sfpdf.PdfPage currentPage = document.pages.add();
        final pageElements = _elements.where((e) => e.pageIndex == i);
        
        for (final element in pageElements) {
          if (element.type == PdfElementType.text) {
            currentPage.graphics.drawString(
              element.text,
              sfpdf.PdfStandardFont(sfpdf.PdfFontFamily.helvetica, 12),
              bounds: Rect.fromLTWH(
                element.x ?? 20, 
                element.y ?? 20, 
                element.width ?? 500, 
                element.height ?? 20
              ),
            );
          } else if (element.type == PdfElementType.image && element.imageBytes != null) {
            final sfpdf.PdfBitmap image = sfpdf.PdfBitmap(element.imageBytes!);
            currentPage.graphics.drawImage(
              image,
              Rect.fromLTWH(
                element.x ?? 20, 
                element.y ?? 20, 
                element.width ?? 200, 
                element.height ?? 150
              ),
            );
          }
        }
      }

      final List<int> bytes = document.saveSync();
      document.dispose();

      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/Edited_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(path);
      await file.writeAsBytes(bytes);

      // Save to storage
      await DocumentStorageService.instance.initialize();
      final doc = ScannedDocument(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: file.path.split('/').last,
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        filePath: file.path,
        fileSize: bytes.length,
        type: DocumentType.pdf,
        tags: ['Edited'],
      );
      await DocumentStorageService.instance.addDocument(doc);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => PdfSuccessScreen(pdfFile: file)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Edit PDF Content'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _savePdf,
            icon: const Icon(Icons.save),
            tooltip: 'Save',
          ),
        ],
      ),
      body: _isLoading || _pdfController == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                InteractiveViewer(
                  maxScale: 4.0,
                  minScale: 0.5,
                  boundaryMargin: const EdgeInsets.all(300),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                    itemCount: _pageCount,
                    itemBuilder: (context, pageIndex) {
                      return _buildPageEditor(pageIndex);
                    },
                  ),
                ),
                _buildToolbar(),
              ],
            ),
    );
  }

  Widget _buildToolbar() {
    return Positioned(
      bottom: 32,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ToolbarButton(
                icon: Icons.text_fields,
                label: 'Add Text',
                onTap: _addText,
              ),
              const SizedBox(width: 24),
              _ToolbarButton(
                icon: Icons.image,
                label: 'Add Image',
                onTap: _addImage,
              ),
              const VerticalDivider(color: Colors.white10, indent: 8, endIndent: 8),
              const SizedBox(width: 8),
              Text(
                'Page ${_activePage + 1}',
                style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageEditor(int pageIndex) {
    final pageElements = _elements.where((e) => e.pageIndex == pageIndex).toList();
    final Size pageSize = pageElements.isNotEmpty ? pageElements.first.pageSize : const Size(595, 842);

    return Container(
      margin: const EdgeInsets.only(bottom: 64),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 25, offset: const Offset(0, 15)),
        ],
      ),
      child: AspectRatio(
        aspectRatio: pageSize.width / pageSize.height,
        child: FutureBuilder<Uint8List?>(
          future: _renderPage(pageIndex),
          builder: (context, snapshot) {
            return Stack(
              children: [
                // PDF Page Background (ghosted)
                if (snapshot.hasData)
                  Opacity(
                    opacity: 0.2, // Further reduced for better clarity of edits
                    child: Image.memory(snapshot.data!, fit: BoxFit.fill),
                  )
                else
                  const Center(child: CircularProgressIndicator()),
                
                // Editable Overlays
                ...pageElements.map((element) {
                  return Positioned(
                    left: element.x,
                    top: element.y,
                    width: element.width,
                    height: element.height,
                    child: _buildElementOverlay(element),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildElementOverlay(PdfElement element) {
    if (element.type == PdfElementType.text) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          TextFormField(
            initialValue: element.text,
            style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w400),
            maxLines: null,
            onChanged: (value) => element.text = value,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.blue.withValues(alpha: 0.05),
              focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.blueAccent, width: 1)),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blue.withValues(alpha: 0.1), width: 0.5)),
              contentPadding: const EdgeInsets.all(4),
              isDense: true,
            ),
          ),
          Positioned(
            right: -8,
            top: -8,
            child: GestureDetector(
              onTap: () => setState(() => _elements.remove(element)),
              child: const CircleAvatar(
                radius: 8,
                backgroundColor: Colors.red,
                child: Icon(Icons.close, size: 10, color: Colors.white),
              ),
            ),
          ),
        ],
      );
    } else {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3), width: 1),
            ),
            child: element.imageBytes != null 
              ? Image.memory(element.imageBytes!, fit: BoxFit.contain)
              : const Center(child: Icon(Icons.image, color: Colors.grey)),
          ),
          Positioned(
            right: -10,
            top: -10,
            child: GestureDetector(
              onTap: () => setState(() => _elements.remove(element)),
              child: const CircleAvatar(
                radius: 10,
                backgroundColor: Colors.red,
                child: Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      );
    }
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolbarButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.blueAccent, size: 24),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
        ],
      ),
    );
  }
}
