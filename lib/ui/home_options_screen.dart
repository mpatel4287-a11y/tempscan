// ignore_for_file: unused_field

import 'dart:async';
import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'ocr_screen.dart';
import 'merge_pdfs_screen.dart';
import 'password_pdf_screen.dart';
import 'signature_screen.dart';
import '../camera/camera_screen.dart';
import '../services/document_storage_service.dart';
import '../models/document.dart';
import '../models/folder.dart';
import 'create_video_pdf_screen.dart';
import 'video_pdf_viewer_screen.dart';
import 'multi_file_reader_screen.dart';
import '../services/backup_service.dart';
import 'package:uri_content/uri_content.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

class HomeOptionsScreen extends StatefulWidget {
  const HomeOptionsScreen({super.key});

  @override
  State<HomeOptionsScreen> createState() => _HomeOptionsScreenState();
}

class _HomeOptionsScreenState extends State<HomeOptionsScreen> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  // Document storage
  List<ScannedDocument> _documents = [];
  List<DocumentFolder> _folders = [];
  String _selectedTag = 'All';
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    await DocumentStorageService.instance.initialize();
    setState(() {
      _documents = DocumentStorageService.instance.documents;
      _folders = DocumentStorageService.instance.folders;
      _isLoading = false;
    });
  }

  List<ScannedDocument> get _filteredDocuments {
    var docs = _documents;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      docs = docs
          .where(
            (doc) =>
                doc.name.toLowerCase().contains(query) ||
                (doc.ocrText?.toLowerCase().contains(query) ?? false),
          )
          .toList();
    }

    // Filter by tag
    if (_selectedTag != 'All') {
      docs = docs.where((doc) => doc.tags.contains(_selectedTag)).toList();
    }

    return docs;
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();

    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleLink(uri);
    });

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleLink(uri);
    });
  }

  void _handleLink(Uri uri) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      File file;
      if (uri.scheme == 'content') {
        final bytes = await uri.getContentOrNull();
        if (bytes == null) {
          debugPrint('Failed to get content from URI: $uri');
          return;
        }
        final tempDir = await getTemporaryDirectory();
        
        // --- SMART EXTENSION DETECTION (Magic Bytes) ---
        String ext = 'file';
        if (uri.path.contains('.')) {
          ext = uri.path.split('.').last.toLowerCase();
        }

        // Sniff bytes if extension is missing or generic
        if (ext == 'file' || ext.isEmpty || ext.length > 5) {
          if (bytes.length > 4) {
            final header = bytes.sublist(0, 4);
            // Check for PDF (%PDF)
            if (header[0] == 0x25 && header[1] == 0x50 && header[2] == 0x44 && header[3] == 0x46) {
              ext = 'pdf';
            }
            // Check for XLSX/ZIP (PK..)
            else if (header[0] == 0x50 && header[1] == 0x4B && header[2] == 0x03 && header[3] == 0x04) {
              ext = 'xlsx';
            }
            // Check for JPEG
            else if (header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF) {
              ext = 'jpg';
            }
          }
        }
        
        file = File('${tempDir.path}/temp_file_$timestamp.$ext');
        await file.writeAsBytes(bytes);
      } else {
        file = File(uri.toFilePath());
      }

      if (!mounted) return;

      final path = file.path.toLowerCase();
      if (path.endsWith('.vpdf')) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VideoPdfViewerScreen(initialFile: file),
          ),
        );
      } else {
        // Route everything else to Multi-File Reader
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MultiFileReaderScreen(initialFile: file),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error handling link: $e');
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0F0F0F),
              const Color(0xFF1A1A1A),
              const Color(0xFF0F0F0F),
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.document_scanner,
                              color: Colors.blueAccent,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'TempScan',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 14,
                              color: Colors.greenAccent,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Privacy First: Images are never saved on device',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.95,
                  ),
                  delegate: SliverChildListDelegate([
                    // PRIMARY - Smart Scan (most common use case)
                    _OptionCard(
                      icon: Icons.camera_enhance,
                      title: 'Smart Scan',
                      subtitle: 'Scan new documents',
                      gradient: [
                        const Color(0xFFFF0844),
                        const Color(0xFFFFB199),
                      ],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CameraScreen()),
                      ),
                    ),

                    // OCR Tool
                    _OptionCard(
                      icon: Icons.text_snippet,
                      title: 'OCR Tool',
                      subtitle: 'Extract text instantly',
                      gradient: [
                        const Color(0xFF43E97B),
                        const Color(0xFF38F9D7),
                      ],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const OcrScreen()),
                      ),
                    ),
                    // Secure PDF
                    _OptionCard(
                      icon: Icons.lock_person,
                      title: 'Secure PDF',
                      subtitle: 'Password protection',
                      gradient: [
                        const Color(0xFFFA709A),
                        const Color(0xFFFEE140),
                      ],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PasswordPdfScreen(),
                        ),
                      ),
                    ),
                    // Merge PDFs
                    _OptionCard(
                      icon: Icons.merge_type,
                      title: 'Merge PDFs',
                      subtitle: 'Combine documents',
                      gradient: [
                        const Color(0xFF667EEA),
                        const Color(0xFF764BA2),
                      ],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MergePdfsScreen(),
                        ),
                      ),
                    ),
                    // Signature
                    _OptionCard(
                      icon: Icons.draw_rounded,
                      title: 'Signature',
                      subtitle: 'Sign your documents',
                      gradient: [
                        const Color(0xFF2AF598),
                        const Color(0xFF009EFD),
                      ],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SignatureScreen(),
                        ),
                      ),
                    ),
                    // Document Organization (NEW)
                    _OptionCard(
                      icon: Icons.folder_outlined,
                      title: 'My Documents',
                      subtitle: 'Organize & search',
                      gradient: [
                        const Color(0xFFFC5C7D),
                        const Color(0xFF6A82FB),
                      ],
                      onTap: () => _showDocumentOrganization(),
                    ),
                    // Multi-File Reader (NEW)
                    _OptionCard(
                      icon: Icons.folder_shared_rounded,
                      title: 'File Reader',
                      subtitle: 'All OS formats',
                      gradient: [
                        const Color(0xFF11998E),
                        const Color(0xFF38EF7D),
                      ],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MultiFileReaderScreen(),
                        ),
                      ),
                    ),

                    // Video PDF
                    _OptionCard(
                      icon: Icons.video_collection,
                      title: 'Video PDF',
                      subtitle: 'Embed video in PDF',
                      gradient: [
                        const Color(0xFFB721FF),
                        const Color(0xFF21D4FD),
                      ],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateVideoPdfScreen(),
                        ),
                      ),
                    ),
                    // Player
                    _OptionCard(
                      icon: Icons.play_circle_filled_rounded,
                      title: 'Player',
                      subtitle: 'Play Video PDFs',
                      gradient: [
                        const Color(0xFFFEC867),
                        const Color(0xFFF72585),
                      ],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const VideoPdfViewerScreen(),
                        ),
                      ),
                    ),
                    // Backup Data
                    _OptionCard(
                      icon: Icons.cloud_upload_outlined,
                      title: 'Backup Data',
                      subtitle: 'Export to ZIP',
                      gradient: [
                        const Color(0xFF4CA1AF),
                        const Color(0xFFC4E0E5),
                      ],
                      onTap: () => BackupService.exportBackup(context),
                    ),
                    // Restore Data
                    _OptionCard(
                      icon: Icons.cloud_download_outlined,
                      title: 'Restore Data',
                      subtitle: 'Import from ZIP',
                      gradient: [
                        const Color(0xFF8E2DE2),
                        const Color(0xFF4A00E0),
                      ],
                      onTap: () => BackupService.importBackup(context),
                    ),
                  ]),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }




  void _showDocumentOrganization() {
    // Refresh documents before showing
    setState(() {
      _documents = DocumentStorageService.instance.documents;
      _folders = DocumentStorageService.instance.folders;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) => Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'My Documents',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Search bar
                TextField(
                  onChanged: (value) {
                    setSheetState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search documents...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                ),
                const SizedBox(height: 16),
                // Tags filter
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildTagChip(
                        'All',
                        isSelected: _selectedTag == 'All',
                        onTap: () {
                          setSheetState(() => _selectedTag = 'All');
                        },
                      ),
                      _buildTagChip(
                        'Bills',
                        isSelected: _selectedTag == 'Bills',
                        onTap: () {
                          setSheetState(() => _selectedTag = 'Bills');
                        },
                      ),
                      _buildTagChip(
                        'IDs',
                        isSelected: _selectedTag == 'IDs',
                        onTap: () {
                          setSheetState(() => _selectedTag = 'IDs');
                        },
                      ),
                      _buildTagChip(
                        'Notes',
                        isSelected: _selectedTag == 'Notes',
                        onTap: () {
                          setSheetState(() => _selectedTag = 'Notes');
                        },
                      ),
                      _buildTagChip(
                        'Work',
                        isSelected: _selectedTag == 'Work',
                        onTap: () {
                          setSheetState(() => _selectedTag = 'Work');
                        },
                      ),
                      _buildTagChip(
                        'Personal',
                        isSelected: _selectedTag == 'Personal',
                        onTap: () {
                          setSheetState(() => _selectedTag = 'Personal');
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                // Documents list
                Text(
                  _selectedTag == 'All'
                      ? 'All Documents'
                      : 'Filtered Documents',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredDocuments.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: controller,
                          itemCount: _filteredDocuments.length,
                          itemBuilder: (context, index) {
                            final doc = _filteredDocuments[index];
                            return _buildDocumentItem(
                              title: doc.name,
                              date: doc.timeAgo,
                              size: doc.formattedSize,
                              tags: doc.tags,
                              isPdf: doc.type == DocumentType.pdf,
                              onTap: () {
                                OpenFilex.open(doc.filePath);
                              },
                              onMoreTap: () {
                                _showDocumentActions(doc);
                              }
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Icon(Icons.folder_open, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No documents found',
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CameraScreen()),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Start Scanning'),
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip(
    String label, {
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        backgroundColor: Colors.grey.shade200,
        selectedColor: Colors.blue.withValues(alpha: 0.2),
      ),
    );
  }

  Widget _buildDocumentItem({
    required String title,
    required String date,
    required String size,
    required List<String> tags,
    bool isPdf = true,
    required VoidCallback onTap,
    required VoidCallback onMoreTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isPdf ? Colors.red : Colors.blue).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isPdf ? Icons.picture_as_pdf : Icons.image,
              color: isPdf ? Colors.red : Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      date,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const Text(' • ', style: TextStyle(color: Colors.grey)),
                    Text(
                      size,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  children: tags
                      .map(
                        (tag) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            onPressed: onMoreTap,
          ),
        ],
      ),
    ),
    );
  }

  void _showDocumentActions(ScannedDocument doc) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(doc.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Open'),
              onTap: () {
                Navigator.pop(context);
                OpenFilex.open(doc.filePath);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                Share.shareXFiles([XFile(doc.filePath)], text: doc.name);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                // Future expansion: actually delete the document via DocumentStorageService
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delete functionality coming soon')));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<_OptionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: widget.gradient
                          .map((e) => e.withValues(alpha: 0.2))
                          .toList(),
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: widget.gradient,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: widget.gradient.first.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(widget.icon, color: Colors.white, size: 28),
                    ),
                    const Spacer(),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.6),
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
