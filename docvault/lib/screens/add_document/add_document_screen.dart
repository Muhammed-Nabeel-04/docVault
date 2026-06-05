import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../models/document.dart';
import '../../models/category.dart';
import '../../providers/providers.dart';
import '../../services/encryption_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/processing_overlay.dart';

class AddDocumentScreen extends ConsumerStatefulWidget {
  final Document? existingDocument;
  const AddDocumentScreen({super.key, this.existingDocument});

  @override
  ConsumerState<AddDocumentScreen> createState() =>
      _AddDocumentScreenState();
}

class _AddDocumentScreenState extends ConsumerState<AddDocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();

  int? _categoryId;
  DateTime? _issueDate;
  DateTime? _expiryDate;
  
  // Multi-file state
  List<DocumentFile> _existingFiles = [];
  final List<File> _newFiles = [];
  final List<DocumentFile> _filesToDelete = [];
  final Map<String, File> _decryptedPreviews = {}; // Map of encryptedPath -> decryptedTempFile

  bool _isSaving = false;
  bool get _isEditing => widget.existingDocument != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final doc = widget.existingDocument!;
      _nameCtrl.text = doc.name;
      _noteCtrl.text = doc.note ?? '';
      _tagsCtrl.text = doc.tags.join(', ');
      _categoryId = doc.categoryId;
      _issueDate = doc.issueDate;
      _expiryDate = doc.expiryDate;
      _existingFiles = List.from(doc.files);
      _loadPreviews();
    }
  }

  Future<void> _loadPreviews() async {
    if (_existingFiles.isEmpty) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        ProcessingOverlay.show(context, message: 'Decrypting previews...', isDecryption: true);

        final startTime = DateTime.now();
        for (var file in _existingFiles) {
          final decrypted = await EncryptionService.decryptToTemp(
            file.encryptedFilePath, 
            file.fileExtension,
          );
          _decryptedPreviews[file.encryptedFilePath] = decrypted;
        }
        
        final elapsed = DateTime.now().difference(startTime);
        if (elapsed < const Duration(seconds: 1)) {
          await Future.delayed(const Duration(seconds: 1) - elapsed);
        }
        
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
        if (mounted) setState(() {});
      } catch (e) {
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
        debugPrint('Error loading previews: $e');
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    _tagsCtrl.dispose();
    // Clean up temporary preview files
    for (var f in _decryptedPreviews.values) {
      f.delete().catchError((_) => f);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final categoriesAsync = ref.watch(categoriesProvider);

    ref.listen(categoriesProvider, (prev, next) {
      final categories = next.valueOrNull;
      if (categories != null && categories.isNotEmpty && _categoryId == null && !_isEditing) {
        // Safe to call setState in listen
        setState(() {
          _categoryId = categories.first.id;
        });
      }
    });

    final categories = categoriesAsync.valueOrNull ?? [];
    
    // Fallback: If categories are already available but _categoryId hasn't been set yet
    if (!_isEditing && _categoryId == null && categories.isNotEmpty) {
      _categoryId = categories.first.id;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Document' : 'Add Document'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── File picker ──────────────────────────────────────────
            _label('Files (${_existingFiles.length + _newFiles.length}) *'),
            const SizedBox(height: 8),
            _multiFilePicker(scheme),
            const SizedBox(height: 20),

            // ── Name ─────────────────────────────────────────────────
            _label('Document Name *'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                  hintText: 'e.g. Identity Bundle, Medical Reports'),
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Name is required'
                  : null,
            ),
            const SizedBox(height: 20),

            // ── Category ─────────────────────────────────────────────
            _label('Category'),
            const SizedBox(height: 8),
            categoriesAsync.when(
              data: (cats) => _categoryGrid(scheme, cats),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Error loading categories'),
            ),
            const SizedBox(height: 20),

            // ── Note ─────────────────────────────────────────────────
            _label('Note (optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                  hintText: 'e.g. Contains multiple pages'),
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // ── Tags ─────────────────────────────────────────────────
            _label('Tags (comma separated, optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _tagsCtrl,
              decoration: const InputDecoration(
                  hintText: 'e.g. tax, personal, multiple'),
            ),
            const SizedBox(height: 20),

            // ── Dates ─────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Issue Date'),
                      const SizedBox(height: 8),
                      _datePicker(
                        value: _issueDate,
                        hint: 'Pick date',
                        onPicked: (d) =>
                            setState(() => _issueDate = d),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Expiry Date'),
                      const SizedBox(height: 8),
                      _datePicker(
                        value: _expiryDate,
                        hint: 'Pick date',
                        onPicked: (d) =>
                            setState(() => _expiryDate = d),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Save button ───────────────────────────────────────────
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _isEditing ? 'Save Changes' : 'Save Document',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────

  Widget _label(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );

  Widget _multiFilePicker(ColorScheme scheme) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        itemCount: _existingFiles.length + _newFiles.length + 1,
        itemBuilder: (context, i) {
          // Add button at the end
          if (i == _existingFiles.length + _newFiles.length) {
            return _addFileButton(scheme);
          }

          final bool isExisting = i < _existingFiles.length;
          final dynamic file = isExisting ? _existingFiles[i] : _newFiles[i - _existingFiles.length];
          
          return _fileThumbnail(scheme, file, isExisting);
        },
      ),
    );
  }

  Widget _addFileButton(ColorScheme scheme) {
    return GestureDetector(
      onTap: _showPickerSheet,
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.3), style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_rounded, color: scheme.primary, size: 28),
            const SizedBox(height: 8),
            Text('Add File', style: TextStyle(color: scheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _fileThumbnail(ColorScheme scheme, dynamic file, bool isExisting) {
    String ext = '';
    File? displayFile;
    
    if (isExisting) {
      final df = file as DocumentFile;
      ext = df.fileExtension.toLowerCase();
      displayFile = _decryptedPreviews[df.encryptedFilePath];
    } else {
      final f = file as File;
      ext = f.path.split('.').last.toLowerCase();
      displayFile = f;
    }

    final isImage = ['jpg', 'jpeg', 'png', 'webp'].contains(ext);

    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
              image: (isImage && displayFile != null)
                  ? DecorationImage(image: FileImage(displayFile), fit: BoxFit.cover)
                  : null,
            ),
            child: (!isImage || displayFile == null)
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(ext == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_rounded, 
                             color: ext == 'pdf' ? Colors.red : scheme.primary, 
                             size: 32),
                        const SizedBox(height: 4),
                        Text(ext.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                : null,
          ),
          // Remove button
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (isExisting) {
                    _filesToDelete.add(file as DocumentFile);
                    _existingFiles.remove(file);
                  } else {
                    _newFiles.remove(file as File);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryGrid(ColorScheme scheme, List<Category> categories) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...categories.map((cat) {
          final selected = _categoryId == cat.id;
          return GestureDetector(
            onTap: () => setState(() => _categoryId = cat.id),
            onLongPress: () => _showCategoryOptions(cat),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? scheme.primary : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(cat.icon, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    cat.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: selected
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        GestureDetector(
          onTap: _showAddCategoryDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: scheme.outlineVariant,
                width: 1,
                style: BorderStyle.solid,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: 16, color: scheme.primary),
                const SizedBox(width: 4),
                Text(
                  'New',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showAddCategoryDialog({Category? editCategory}) {
    final nameCtrl = TextEditingController(text: editCategory?.name);
    final iconCtrl = TextEditingController(text: editCategory?.icon ?? '📄');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(editCategory == null ? 'Add Category' : 'Edit Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: iconCtrl,
              decoration: const InputDecoration(labelText: 'Icon (Emoji)'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Category Name'),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final icon = iconCtrl.text.trim();
              if (name.isNotEmpty && icon.isNotEmpty) {
                if (editCategory == null) {
                  ref.read(categoriesProvider.notifier).addCategory(name, icon);
                } else {
                  ref.read(categoriesProvider.notifier).updateCategory(
                    editCategory.copyWith(name: name, icon: icon),
                  );
                }
                Navigator.pop(ctx);
              }
            },
            child: Text(editCategory == null ? 'Add' : 'Update'),
          ),
        ],
      ),
    );
  }

  void _showCategoryOptions(Category category) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_rounded),
            title: const Text('Edit Category'),
            onTap: () {
              Navigator.pop(ctx);
              _showAddCategoryDialog(editCategory: category);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            title: const Text('Delete Category', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(ctx);
              _confirmDeleteCategory(category);
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCategory(Category category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text('Documents in "${category.name}" will be moved to "Other".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(categoriesProvider.notifier).deleteCategory(category.id!);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _datePicker({
    required DateTime? value,
    required String hint,
    required ValueChanged<DateTime> onPicked,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).inputDecorationTheme.fillColor,
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              value != null
                  ? '${value.day}/${value.month}/${value.year}'
                  : hint,
              style: TextStyle(
                fontSize: 13,
                color: value != null
                    ? scheme.onSurface
                    : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Logic ─────────────────────────────────────────────────────────────

  void _showPickerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload_file_rounded),
              title: const Text('Pick files from storage'),
              onTap: () {
                Navigator.pop(ctx);
                _pickFiles();
              },
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Pick images from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhotos();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _takePhoto();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _takePhoto() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) return;
    final image = await ImagePicker().pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _newFiles.add(File(image.path));
      });
    }
  }

  Future<void> _pickFiles() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt < 33) {
        final status = await Permission.storage.request();
        if (!status.isGranted) return;
      }
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: true,
    );
    if (result != null) {
      setState(() {
        _newFiles.addAll(result.files.where((f) => f.path != null).map((f) => File(f.path!)));
      });
    }
  }

  Future<void> _pickPhotos() async {
    final status = await Permission.photos.request();
    if (!status.isGranted) return;
    final images = await ImagePicker().pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _newFiles.addAll(images.map((img) => File(img.path)));
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_existingFiles.isEmpty && _newFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one file')),
      );
      return;
    }

    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    setState(() => _isSaving = true);
    bool overlayShown = false;
    
    if (mounted) {
      ProcessingOverlay.show(
        context, 
        message: _newFiles.isNotEmpty ? 'Encrypting files...' : 'Saving changes...',
      );
      overlayShown = true;
    }

    final startTime = DateTime.now();

    try {
      final db = ref.read(dbProvider);
      final tags = _tagsCtrl.text
          .split(',')
          .map((t) => t.trim().toLowerCase())
          .where((t) => t.isNotEmpty)
          .toList();

      // 1. Encrypt new files
      List<DocumentFile> finalFileList = List.from(_existingFiles);
      for (var f in _newFiles) {
        final encPath = await EncryptionService.encryptFile(f);
        finalFileList.add(DocumentFile(
          encryptedFilePath: encPath, 
          fileExtension: f.path.split('.').last.toLowerCase(), 
          fileSizeBytes: await f.length(),
        ));
      }

      // 2. Delete removed files from disk
      for (var f in _filesToDelete) {
        await EncryptionService.deleteEncryptedFile(f.encryptedFilePath);
      }

      if (_isEditing) {
        final updated = widget.existingDocument!.copyWith(
          name: _nameCtrl.text.trim(),
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          categoryId: _categoryId!,
          files: finalFileList,
          tags: tags,
          issueDate: _issueDate,
          expiryDate: _expiryDate,
          updatedAt: DateTime.now(),
        );
        
        await NotificationService.cancelReminder(updated.id!);
        await db.updateDocument(updated);
        
        if (_expiryDate != null) {
          final hasPerm = await NotificationService.hasPermission();
          if (hasPerm) await NotificationService.scheduleExpiryReminder(updated);
        }
      } else {
        final now = DateTime.now();
        final doc = Document(
          name: _nameCtrl.text.trim(),
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          categoryId: _categoryId!,
          files: finalFileList,
          tags: tags,
          issueDate: _issueDate,
          expiryDate: _expiryDate,
          createdAt: now,
          updatedAt: now,
        );
        final id = await db.addDocument(doc);
        if (_expiryDate != null) {
          final hasPerm = await NotificationService.hasPermission();
          if (hasPerm) await NotificationService.scheduleExpiryReminder(doc.copyWith(id: id));
        }
      }

      final elapsed = DateTime.now().difference(startTime);
      if (elapsed < const Duration(seconds: 1)) {
        await Future.delayed(const Duration(seconds: 1) - elapsed);
      }

      if (mounted) {
        if (overlayShown && Navigator.canPop(context)) {
          Navigator.pop(context);
          overlayShown = false;
        }
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        if (overlayShown && Navigator.canPop(context)) {
          Navigator.pop(context);
          overlayShown = false;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
