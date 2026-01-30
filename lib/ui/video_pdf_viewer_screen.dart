import 'dart:io';
import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:temp_scan/utils/video_embed_builder.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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
      // Check for broad storage permissions on Android 11+
      if (Platform.isAndroid) {
         if (await Permission.manageExternalStorage.isDenied) {
           await Permission.manageExternalStorage.request();
         }
         // Fallback to regular storage if management is not granted or supported
         await Permission.storage.request();
      }

      final List<Directory?> searchDirs = [
        Directory('/storage/emulated/0'), // Internal Storage Root
        await getExternalStorageDirectory(),
        await getApplicationDocumentsDirectory(),
      ];

      final List<File> found = [];
      final Set<String> seenPaths = {}; // To avoid duplicates from overlapping roots

      for (final dir in searchDirs) {
        if (dir != null && await dir.exists()) {
          try {
            // We use a manual recursion to avoid deep system folders and hanging
            await _recursiveScan(dir, found, seenPaths, 0, 3);
          } catch (e) {
             debugPrint('Error scanning dir ${dir.path}: $e');
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

  Future<void> _recursiveScan(Directory dir, List<File> found, Set<String> seen, int depth, int maxDepth) async {
    if (depth > maxDepth) return;
    
    // Skip hidden or system-heavy directories to avoid lag/permission issues
    final dirName = dir.path.split('/').last.toLowerCase();
    if (dirName.startsWith('.') || 
        dirName == 'android' || 
        dirName == 'data' || 
        dirName == 'com.android.providers.media' ||
        dirName == 'cache') {
      return;
    }

    try {
      final entities = dir.listSync(recursive: false);
      for (final entity in entities) {
        if (entity is File) {
          if (entity.path.endsWith('.vpdf') && !seen.contains(entity.path)) {
            found.add(entity);
            seen.add(entity.path);
          }
        } else if (entity is Directory) {
          await _recursiveScan(entity, found, seen, depth + 1, maxDepth);
        }
      }
    } catch (e) {
      // Ignore directories we can't access
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
       errorBuilder: (context, errorMessage) {
         return Center(child: Text(errorMessage, style: const TextStyle(color: Colors.white)));
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
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Icon(Icons.manage_search, size: 32, color: Colors.blue),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Discovered Video PDFs', 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('${_discoveredFiles.length} files found',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
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
                      const Icon(Icons.search_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No Video PDFs found in standard folders.'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _pickPdf,
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Open File Manually'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _discoveredFiles.length,
                  itemBuilder: (context, index) {
                    final file = _discoveredFiles[index];
                    final isVPDF = file.path.endsWith('.vpdf');
                    return ListTile(
                      leading: Icon(
                        isVPDF ? Icons.video_file : Icons.picture_as_pdf,
                        color: isVPDF ? Colors.blue : Colors.red,
                      ),
                      title: Text(file.path.split('/').last),
                      subtitle: Text(file.path, 
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10)),
                      onTap: () => _loadPdf(file),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
