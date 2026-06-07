import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../models/document.dart';
import '../../models/category.dart';
import '../../providers/providers.dart';
import '../../services/encryption_service.dart';
import '../../utils/app_router.dart';
import '../../utils/app_utils.dart';
import '../../widgets/processing_overlay.dart';

class ViewDocumentScreen extends ConsumerStatefulWidget {
  final Document document;
  const ViewDocumentScreen({super.key, required this.document});

  @override
  ConsumerState<ViewDocumentScreen> createState() => _ViewDocumentScreenState();
}

class _ViewDocumentScreenState extends ConsumerState<ViewDocumentScreen> {
  int _currentIndex = 0;
  final Map<int, File> _decryptedFiles = {}; // index -> tempFile
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCurrentFile();
  }

  Future<void> _loadCurrentFile() async {
    if (_decryptedFiles.containsKey(_currentIndex)) {
      setState(() {
        _loading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final file = widget.document.files[_currentIndex];
      final f = await EncryptionService.decryptToTemp(
        file.encryptedFilePath,
        file.fileExtension,
      );
      
      if (mounted) {
        setState(() {
          _decryptedFiles[_currentIndex] = f;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    for (var f in _decryptedFiles.values) {
      f.delete().catchError((_) => f);
    }
    super.dispose();
  }

  Future<void> _share() async {
    final file = _decryptedFiles[_currentIndex];
    if (file == null) return;
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: '${widget.document.name} - Part ${_currentIndex + 1}',
    );
  }

  @override
  Widget build(BuildContext context) {
    // We fetch the document from the provider to ensure we have the latest data if edited
    final docsAsync = ref.watch(documentsProvider);
    final doc = docsAsync.when(
      data: (list) => list.firstWhere((d) => d.id == widget.document.id, orElse: () => widget.document),
      loading: () => widget.document,
      error: (_, __) => widget.document,
    );
    
    final scheme = Theme.of(context).colorScheme;

    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final category = categories.firstWhere(
      (c) => c.id == doc.categoryId,
      orElse: () => categories.isNotEmpty 
          ? categories.first 
          : Category(id: -1, name: 'Unknown', icon: '❓'),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(doc.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => Navigator.pushNamed(
              context,
              AppRouter.addDocument,
              arguments: doc,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: _share,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // ── Metadata card ────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(category.icon,
                        style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            children: [
                              if (doc.issueDate != null)
                                _chip(
                                    'Issued: ${AppUtils.formatDate(doc.issueDate)}',
                                    false),
                              if (doc.expiryDate != null)
                                _chip(
                                  AppUtils.daysUntilExpiry(doc.expiryDate!),
                                  AppUtils.isExpiringSoon(doc.expiryDate) ||
                                      AppUtils.isExpired(doc.expiryDate),
                                ),
                              _chip(
                                  AppUtils.formatFileSize(doc.files[_currentIndex].fileSizeBytes),
                                  false),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── File viewer ──────────────────────────────────────────────
              Expanded(
                child: _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('Could not open file:\n$_error',
                              textAlign: TextAlign.center),
                        ),
                      )
                    : _buildViewer(doc.files[_currentIndex]),
              ),

              // ── Thumbnail Strip ──────────────────────────────────────────
              if (doc.files.length > 1) _buildThumbnailStrip(doc),
            ],
          ),
          // ── Overlay Loading ──────────────────────────────────────────
          if (_loading)
            const ProcessingOverlay(isDecryption: true),
        ],
      ),
    );
  }

  Widget _buildThumbnailStrip(Document doc) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: doc.files.length,
        itemBuilder: (context, i) {
          final isSelected = _currentIndex == i;
          final file = doc.files[i];
          final ext = file.fileExtension.toLowerCase();
          final isImage = ['jpg', 'jpeg', 'png', 'webp'].contains(ext);
          final decrypted = _decryptedFiles[i];

          return GestureDetector(
            onTap: () {
              if (_currentIndex != i) {
                setState(() => _currentIndex = i);
                _loadCurrentFile();
              }
            },
            child: Container(
              width: 60,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? scheme.primary : scheme.outlineVariant,
                  width: isSelected ? 2 : 1,
                ),
                image: (isImage && decrypted != null)
                    ? DecorationImage(image: FileImage(decrypted), fit: BoxFit.cover)
                    : null,
              ),
              child: (!isImage || decrypted == null)
                  ? Center(
                      child: Icon(
                        ext == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_rounded,
                        size: 20,
                        color: ext == 'pdf' ? Colors.red : scheme.primary,
                      ),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildViewer(DocumentFile file) {
    final ext = file.fileExtension.toLowerCase();
    final tempFile = _decryptedFiles[_currentIndex];
    
    if (tempFile == null) return const Center(child: CircularProgressIndicator());

    if (ext == 'pdf') {
      return SfPdfViewer.file(tempFile);
    }
    return InteractiveViewer(
      child: Center(
        child: Image.file(tempFile, fit: BoxFit.contain),
      ),
    );
  }

  Widget _chip(String label, bool isWarning) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isWarning
            ? Colors.orange.shade100
            : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isWarning
              ? Colors.orange.shade800
              : scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
