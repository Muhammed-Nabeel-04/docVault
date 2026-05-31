import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/document.dart';
import '../../providers/providers.dart';
import '../../services/database_service.dart';
import '../../services/encryption_service.dart';
import '../../services/notification_service.dart';

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

  DocumentCategory _category = DocumentCategory.identity;
  DateTime? _issueDate;
  DateTime? _expiryDate;
  File? _pickedFile;
  String? _fileExtension;
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
      _category = doc.category;
      _issueDate = doc.issueDate;
      _expiryDate = doc.expiryDate;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
            if (!_isEditing) ...[
              _label('Document File *'),
              const SizedBox(height: 8),
              _filePicker(scheme),
              const SizedBox(height: 20),
            ],

            // ── Name ─────────────────────────────────────────────────
            _label('Document Name *'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                  hintText: 'e.g. Aadhaar Card, Driving Licence'),
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Name is required'
                  : null,
            ),
            const SizedBox(height: 20),

            // ── Category ─────────────────────────────────────────────
            _label('Category'),
            const SizedBox(height: 8),
            _categoryGrid(scheme),
            const SizedBox(height: 20),

            // ── Note ─────────────────────────────────────────────────
            _label('Note (optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                  hintText: 'e.g. Original kept in drawer'),
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // ── Tags ─────────────────────────────────────────────────
            _label('Tags (comma separated, optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _tagsCtrl,
              decoration: const InputDecoration(
                  hintText: 'e.g. aadhaar, uid, identity'),
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

  Widget _filePicker(ColorScheme scheme) {
    return GestureDetector(
      onTap: _showPickerSheet,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          border: Border.all(
            color: _pickedFile != null
                ? scheme.primary
                : scheme.outlineVariant,
            width: _pickedFile != null ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: _pickedFile != null
              ? scheme.primaryContainer.withOpacity(0.2)
              : scheme.surfaceVariant.withOpacity(0.3),
        ),
        child: _pickedFile != null
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: scheme.primary),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _pickedFile!.path.split('\\').last.split('/').last,
                      style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: scheme.error, size: 20),
                    onPressed: () => setState(() => _pickedFile = null),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.upload_file_rounded,
                      size: 32, color: scheme.onSurfaceVariant),
                  const SizedBox(height: 6),
                  Text('Tap to pick file or scan document',
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 13)),
                ],
              ),
      ),
    );
  }

  Widget _categoryGrid(ColorScheme scheme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: DocumentCategory.values.map((cat) {
        final selected = _category == cat;
        return GestureDetector(
          onTap: () => setState(() => _category = cat),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primaryContainer
                  : scheme.surfaceVariant.withOpacity(0.5),
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
                  cat.label,
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
      }).toList(),
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
              title: const Text('Pick from storage'),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromStorage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromCamera();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromStorage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _pickedFile = File(result.files.single.path!);
        _fileExtension =
            result.files.single.extension?.toLowerCase() ?? 'pdf';
      });
    }
  }

  Future<void> _pickFromCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) return;
    final image =
        await ImagePicker().pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _pickedFile = File(image.path);
        _fileExtension = 'jpg';
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isEditing && _pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a document file')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = ref.read(dbProvider);
      final tags = _tagsCtrl.text
          .split(',')
          .map((t) => t.trim().toLowerCase())
          .where((t) => t.isNotEmpty)
          .toList();

      if (_isEditing) {
        final updated = widget.existingDocument!.copyWith(
          name: _nameCtrl.text.trim(),
          note: _noteCtrl.text.trim().isEmpty
              ? null
              : _noteCtrl.text.trim(),
          category: _category,
          tags: tags,
          issueDate: _issueDate,
          expiryDate: _expiryDate,
          updatedAt: DateTime.now(),
        );
        await db.updateDocument(updated);
        if (_expiryDate != null) {
          await NotificationService.scheduleExpiryReminder(updated);
        }
      } else {
        final encPath =
            await EncryptionService.encryptFile(_pickedFile!);
        final now = DateTime.now();
        final doc = Document(
          name: _nameCtrl.text.trim(),
          note: _noteCtrl.text.trim().isEmpty
              ? null
              : _noteCtrl.text.trim(),
          category: _category,
          encryptedFilePath: encPath,
          fileExtension: _fileExtension ?? 'pdf',
          fileSizeBytes: await _pickedFile!.length(),
          tags: tags,
          issueDate: _issueDate,
          expiryDate: _expiryDate,
          createdAt: now,
          updatedAt: now,
        );
        final id = await db.addDocument(doc);
        if (_expiryDate != null) {
          await NotificationService.scheduleExpiryReminder(
              doc.copyWith(id: id));
        }
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
