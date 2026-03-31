import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:temp_scan/utils/video_embed_builder.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:temp_scan/services/document_storage_service.dart';

// Top-level function for background Isolate task
List<String> _searchIsolateAction(String rootPath) {
  final found = <String>[];
  try {
    final root = Directory(rootPath);
    if (!root.existsSync()) return found;
    
    void search(Directory dir, int depth) {
      if (depth > 6) return; // Prevent infinite hanging
      final dirName = dir.path.split('/').last.toLowerCase();
      // Skip system heavy/hidden directories
      if (dirName.startsWith('.') || dirName == 'android' || dirName == 'data' || dirName == 'cache') return;
      
      try {
        final entities = dir.listSync(recursive: false);
        for (final e in entities) {
          if (e is File && e.path.toLowerCase().endsWith('.vpdf')) {
            found.add(e.path);
          } else if (e is Directory) {
            search(e, depth + 1);
          }
        }
      } catch (_) {}
    }
    search(root, 0);
  } catch (_) {}
  return found;
}

class VideoPdfViewerScreen extends StatefulWidget {
  final File? initialFile;
  const VideoPdfViewerScreen({super.key, this.initialFile});

  @override
  State<VideoPdfViewerScreen> createState() => _VideoPdfViewerScreenState();
}

class _VideoPdfViewerScreenState extends State<VideoPdfViewerScreen> {
  List<File> _extractedVideos = [];
  bool _isLoadingContent = false;
  List<File> _discoveredFiles = [];
  bool _isScanning = false;
  
  // PDF Controller
  PdfController? _pdfController;
  
  // Playback State
  bool _isVideoPlaying = false;
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  int _currentVideoIndex = -1; // -1 means no video playing
  
  // Mapping: Page Index -> Video Index
  // Assumption: Page 0 = Cover/Video 0?, Page 1 = Video 1?
  // Our generator: Page 0 = Video 0, Page 1 = Video 1.
  // BUT: Extracted list order presumably matches page generation order.
  // So Page K = Video K.
  
  @override
  void initState() {
    super.initState();
    _scanForFiles();
    if (widget.initialFile != null) {
      _loadPdf(widget.initialFile!);
    }
  }

  Future<void> _scanForFiles() async {
    setState(() => _isScanning = true);
    try {
      await DocumentStorageService.instance.initialize();
      final docs = DocumentStorageService.instance.documents;
      
      final List<File> found = [];
      final Set<String> seenPaths = {};

      // 1. Instant O(1) fetch from internal Document Storage
      for (final doc in docs) {
        if (doc.filePath.toLowerCase().endsWith('.vpdf') || doc.name.toLowerCase().endsWith('.vpdf')) {
          if (!seenPaths.contains(doc.filePath)) {
             final f = File(doc.filePath);
             if (await f.exists()) {
               found.add(f);
               seenPaths.add(f.path);
             }
          }
        }
      }

      // 2. Add files from entire device using an Isolate (won't block UI)
      if (Platform.isAndroid) {
         final paths = await compute(_searchIsolateAction, '/storage/emulated/0');
         for (final path in paths) {
           if (!seenPaths.contains(path)) {
             seenPaths.add(path);
             found.add(File(path));
           }
         }
      }

      if (mounted) {
        setState(() {
          _discoveredFiles = found;
          _isScanning = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _pickPdf() async {
    // On Android, custom extensions are sometimes ignored in FileType.custom.
    // Using FileType.any and filtering manually if it fails.
    final result = await FilePicker.platform.pickFiles(
      type: Platform.isAndroid ? FileType.any : FileType.custom,
      allowedExtensions: Platform.isAndroid ? null : ['pdf', 'vpdf'],
    );
    
    if (result != null) {
      final file = File(result.files.single.path!);
      final ext = file.path.split('.').last.toLowerCase();
      if (ext == 'pdf' || ext == 'vpdf') {
        _loadPdf(file);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a .pdf or .vpdf file'))
          );
        }
      }
    }
  }

  Future<Uint8List?> _getThumbnail(File file) async {
    try {
      final doc = await PdfDocument.openFile(file.path);
      final page = await doc.getPage(1);
      final pageImage = await page.render(
        width: page.width / 4,
        height: page.height / 4,
        format: PdfPageImageFormat.jpeg,
      );
      await page.close();
      await doc.close();
      return pageImage?.bytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadPdf(File pdfFile) async {
    setState(() {
      _isLoadingContent = true;
      _stopVideo();
      _extractedVideos = [];
    });

    try {
      String openPath = pdfFile.path;
      
      // pdfx/pdf_renderer might be strict about .pdf extension on some platforms.
      // If extension is .vpdf, create a temporary .pdf symlink or copy.
      if (pdfFile.path.endsWith('.vpdf')) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/temp_preview.pdf');
        await tempFile.writeAsBytes(await pdfFile.readAsBytes());
        openPath = tempFile.path;
      }

      // 1. Initialize PDF Viewer
      _pdfController = PdfController(
        document: PdfDocument.openFile(openPath),
      );
    
      // 2. Extract Videos (from the ORIGINAL vpdf file if possible, or same data)
      final videos = await VideoEmbedBuilder.extractVideos(pdfFile.path);
      
      if (mounted) {
        setState(() {
          _extractedVideos = videos;
          _isLoadingContent = false;
        });

        if (videos.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No videos found in this file. Make sure it was created with "Create Video PDF".'))
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
           _isLoadingContent = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _playVideo(int index) async {
    if (index < 0 || index >= _extractedVideos.length) return;
    
    _stopVideo(); // Stop current if any

    setState(() {
       _currentVideoIndex = index;
       _isVideoPlaying = true;
    });

    final file = _extractedVideos[index];
    _videoPlayerController = VideoPlayerController.file(file);
    await _videoPlayerController!.initialize();

    _chewieController = ChewieController(
       videoPlayerController: _videoPlayerController!,
       autoPlay: true,
       looping: false,
       aspectRatio: _videoPlayerController!.value.aspectRatio,
       allowFullScreen: true,
       allowPlaybackSpeedChanging: true,
       materialProgressColors: ChewieProgressColors(
         playedColor: Colors.blueAccent,
         handleColor: Colors.blue,
         backgroundColor: Colors.grey.shade800,
         bufferedColor: Colors.white38,
       ),
       errorBuilder: (context, errorMessage) {
         return Center(child: Text(errorMessage, style: const TextStyle(color: Colors.redAccent)));
       },
    );

    if (mounted) setState(() {});
  }
  
  void _stopVideo() {
    final oldPlayer = _videoPlayerController;
    final oldChewie = _chewieController;
    
    _videoPlayerController = null;
    _chewieController = null;
    
    // Dispose outside of setState to avoid lifecycle issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldPlayer?.dispose();
      oldChewie?.dispose();
    });

    if (mounted) {
      setState(() {
        _isVideoPlaying = false;
        _currentVideoIndex = -1;
      });
    }
  }

  @override
  void dispose() {
    _stopVideo();
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video PDF Player'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _scanForFiles,
            tooltip: 'Rescan Storage',
          ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _pickPdf,
            tooltip: 'Open PDF',
          ),
        ],
      ),
      body: _isLoadingContent
          ? const Center(child: CircularProgressIndicator())
          : _pdfController == null
              ? _buildDiscoveryView()
              : Stack(
                  children: [
                    PdfView(
                      controller: _pdfController!,
                      onPageChanged: (page) {
                        if (mounted) {
                          setState(() {
                            // PDF page is 1-based, we want 0-based index
                            _currentVideoIndex = page - 1;
                          });
                        }
                      },
                    ),
                    
                    // Video Player Overlay (Full Screen when playing)
                    if (_isVideoPlaying && _chewieController != null)
                      Container(
                        color: Colors.black,
                        child: Stack(
                          children: [
                            Center(child: Chewie(controller: _chewieController!)),
                            Positioned(
                              top: 40,
                              right: 20,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                onPressed: _stopVideo,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Play Button Overlay (When not playing, if video exists)
                    if (!_isVideoPlaying && _currentVideoIndex >= 0 && _currentVideoIndex < _extractedVideos.length)
                      Align(
                        alignment: Alignment.center,
                        child: GestureDetector(
                          onTap: () => _playVideo(_currentVideoIndex),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(20),
                            child: const Icon(Icons.play_arrow, color: Colors.white, size: 50),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _buildDiscoveryView() {
    return Column(
      children: [
        if (_isScanning)
          const LinearProgressIndicator(),
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Video PDFs', 
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('${_discoveredFiles.length} files found',
                    style: const TextStyle(fontSize: 14, color: Colors.white54)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _pickPdf,
                icon: const Icon(Icons.folder_open, size: 20),
                label: const Text('Open'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _discoveredFiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.video_file_outlined, size: 80, color: Colors.white.withValues(alpha: 0.1)),
                      const SizedBox(height: 16),
                      const Text('No Video PDFs found.', style: TextStyle(color: Colors.white54, fontSize: 16)),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                     crossAxisCount: 2,
                     crossAxisSpacing: 16,
                     mainAxisSpacing: 16,
                     childAspectRatio: 0.8,
                  ),
                  itemCount: _discoveredFiles.length,
                  itemBuilder: (context, index) {
                    final file = _discoveredFiles[index];
                    final fileName = file.path.split('/').last;
                    
                    return GestureDetector(
                      onTap: () => _loadPdf(file),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                decoration: const BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                ),
                                child: FutureBuilder<Uint8List?>(
                                  future: _getThumbnail(file),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                                    }
                                    if (snapshot.hasData && snapshot.data != null) {
                                      return Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          ClipRRect(
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                            child: Image.memory(snapshot.data!, fit: BoxFit.cover),
                                          ),
                                          Container(color: Colors.black.withValues(alpha: 0.3)),
                                          const Center(child: Icon(Icons.play_circle_fill, size: 48, color: Colors.white)),
                                        ],
                                      );
                                    }
                                    return const Center(child: Icon(Icons.play_circle_fill, size: 48, color: Colors.white54));
                                  },
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fileName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Video PDF',
                                    style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
