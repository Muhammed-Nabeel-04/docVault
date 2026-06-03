import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../models/document.dart';
import '../../services/encryption_service.dart';
import '../../utils/app_router.dart';
import '../../utils/app_utils.dart';

class ViewDocumentScreen extends StatefulWidget {
  final Document document;
  const ViewDocumentScreen({super.key, required this.document});

  @override
  State<ViewDocumentScreen> createState() => _ViewDocumentScreenState();
}

class _ViewDocumentScreenState extends State<ViewDocumentScreen> {
  File? _tempFile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  Future<void> _loadFile() async {
    try {
      final f = await EncryptionService.decryptToTemp(
        widget.document.encryptedFilePath,
        widget.document.fileExtension,
      );
      setState(() {
        _tempFile = f;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    if (_tempFile != null) {
      _tempFile!.delete().catchError((_) => _tempFile!);
    }
    super.dispose();
  }

  Future<void> _share() async {
    if (_tempFile == null) return;
    await Share.shareXFiles(
      [XFile(_tempFile!.path)],
      subject: widget.document.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;
    final scheme = Theme.of(context).colorScheme;

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
      body: Column(
        children: [
          // ── Metadata card ────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(doc.category.icon,
                    style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.category.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (doc.note != null) ...[
                        const SizedBox(height: 2),
                        Text(doc.note!,
                            style: TextStyle(
                                fontSize: 13,
                                color: scheme.onSurfaceVariant)),
                      ],
                      const SizedBox(height: 6),
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
                              AppUtils.formatFileSize(doc.fileSizeBytes),
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
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('Could not open file:\n$_error',
                              textAlign: TextAlign.center),
                        ),
                      )
                    : _buildViewer(),
          ),
        ],
      ),
    );
  }

  Widget _buildViewer() {
    final ext = widget.document.fileExtension.toLowerCase();
    if (ext == 'pdf') {
      return SfPdfViewer.file(_tempFile!);
    }
    return InteractiveViewer(
      child: Center(
        child: Image.file(_tempFile!, fit: BoxFit.contain),
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
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isWarning
              ? Colors.orange.shade800
              : scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
