import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:docvault/providers/providers.dart';
import 'package:docvault/services/auth_service.dart';
import 'package:docvault/services/encryption_service.dart';
import 'package:docvault/models/category.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _hasPin = false;
  bool _bioAvailable = false;
  bool _bioEnabled = false;
  int _autoLockSeconds = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pin = await AuthService.hasPin();
    final bioAvail = await AuthService.isBiometricsAvailable();
    final bioEnabled = await AuthService.isBiometricEnabled();
    final autoLock = await AuthService.getAutoLockDuration();

    if (!mounted) return;
    setState(() {
      _hasPin = pin;
      _bioAvailable = bioAvail;
      _bioEnabled = bioEnabled;
      _autoLockSeconds = autoLock;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── Security ─────────────────────────────────────────────────
          _header('Security'),
          SwitchListTile(
            secondary: const Icon(Icons.pin_rounded),
            title: const Text('PIN Lock'),
            subtitle: const Text('Require PIN to open app'),
            value: _hasPin,
            onChanged: (v) => v ? _setupPin() : _removePin(),
          ),
          if (_bioAvailable)
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint_rounded),
              title: const Text('Biometric Unlock'),
              subtitle: const Text('Use fingerprint or face ID'),
              value: _bioEnabled,
              onChanged: _hasPin
                  ? (v) async {
                      await AuthService.setBiometricEnabled(v);
                      setState(() => _bioEnabled = v);
                    }
                  : null,
            ),
          ListTile(
            leading: const Icon(Icons.timer_rounded),
            title: const Text('Automatically Lock'),
            subtitle: Text(_getAutoLockLabel(_autoLockSeconds)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _showAutoLockPicker,
          ),

          const Divider(),

          // ── Appearance & Content ─────────────────────────────────────
          _header('Appearance & Content'),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Manage Categories'),
            subtitle: const Text('Add, edit or delete document categories'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _showCategoriesManager,
          ),

          const Divider(),

          // ── Storage ───────────────────────────────────────────────────
          _header('Storage'),
          ListTile(
            leading: Icon(Icons.lock_rounded, color: scheme.primary),
            title: const Text('All files encrypted'),
            subtitle:
                const Text('AES-256 · stored on device only · no cloud'),
            trailing: Icon(Icons.check_circle_rounded,
                color: scheme.primary),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded,
                color: Colors.red),
            title: const Text('Clear all documents',
                style: TextStyle(color: Colors.red)),
            subtitle: const Text('Permanently delete everything'),
            onTap: _confirmClearAll,
          ),

          const Divider(),

          // ── About ─────────────────────────────────────────────────────
          _header('About'),
          const ListTile(
            leading: Icon(Icons.info_outline_rounded),
            title: Text('DocVault'),
            subtitle: Text('v1.0.0 · No data ever leaves your device'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.open_in_new_rounded, size: 18),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  void _showCategoriesManager() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _CategoryManagerSheet(),
    );
  }

  Widget _header(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 1,
          ),
        ),
      );

  String _getAutoLockLabel(int seconds) {
    if (seconds == 0) return 'Immediately';
    if (seconds < 60) return '$seconds seconds';
    return '${seconds ~/ 60} minutes';
  }

  void _showAutoLockPicker() {
    final options = {
      0: 'Immediately',
      60: '1 minute',
      120: '2 minutes',
      300: '5 minutes',
      600: '10 minutes',
    };

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Auto-lock Duration',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...options.entries.map((e) => ListTile(
                  title: Text(e.value),
                  trailing: _autoLockSeconds == e.key
                      ? Icon(Icons.check_circle_rounded,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () async {
                    final nav = Navigator.of(ctx);
                    await AuthService.setAutoLockDuration(e.key);
                    if (mounted) {
                      setState(() => _autoLockSeconds = e.key);
                    }
                    nav.pop();
                  },
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _setupPin() async {
    final pin = await _pinDialog('Set PIN');
    if (pin != null && pin.length == 4) {
      await AuthService.setPin(pin);
      setState(() => _hasPin = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN set successfully')),
        );
      }
    }
  }

  Future<void> _removePin() async {
    await AuthService.removePin();
    await AuthService.setBiometricEnabled(false);
    setState(() {
      _hasPin = false;
      _bioEnabled = false;
    });
  }

  Future<String?> _pinDialog(String title) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(hintText: '4-digit PIN'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Set')),
        ],
      ),
    );
  }

  void _confirmClearAll() async {
    // Step 1: Initial Confirmation
    final confirm1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all documents?'),
        content: const Text(
            'This will permanently delete ALL documents and their encrypted files. This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm1 != true) return;

    // Step 2: Verification (Biometrics, PIN or "DELETE" text)
    bool verified = false;
    if (_hasPin) {
      if (_bioEnabled) {
        // Try biometrics first if enabled
        verified = await AuthService.authenticateWithBiometrics();
      }
      
      if (!verified) {
        // Fallback to PIN if bio fails or is disabled
        if (!mounted) return;
        final pin = await _verifyPinDialog();
        if (pin != null) {
          verified = await AuthService.verifyPin(pin);
          if (!verified && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Incorrect PIN')),
            );
          }
        }
      }
    } else {
      if (!mounted) return;
      verified = await _typeDeleteDialog();
    }

    if (!verified) return;

    // Step 3: CAPTCHA (Math Problem)
    if (!mounted) return;
    final captchaOk = await _captchaDialog();
    if (captchaOk != true) return;

    // Final Action
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      await ref.read(dbProvider).deleteAllDocuments();
      await EncryptionService.clearAllFiles();
      ref.read(documentsProvider.notifier).load();

      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data cleared successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing data: $e')),
        );
      }
    }
  }

  Future<String?> _verifyPinDialog() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your 4-digit PIN to confirm deletion.'),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 16),
              decoration: const InputDecoration(counterText: ''),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Confirm')),
        ],
      ),
    );
  }

  Future<bool> _typeDeleteDialog() async {
    final ctrl = TextEditingController();
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Type "DELETE" in all caps to confirm.'),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(hintText: 'DELETE'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (ctrl.text == 'DELETE') {
                Navigator.pop(ctx, true);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Word does not match')),
                );
              }
            },
            child: const Text('Delete Everything',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  Future<bool?> _captchaDialog() async {
    final random = Random();
    final a = random.nextInt(10) + 1;
    final b = random.nextInt(10) + 1;
    final sum = a + b;
    final ctrl = TextEditingController();

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Security CAPTCHA'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Solve this simple math problem to confirm you are human:'),
            const SizedBox(height: 20),
            Center(
              child: Text(
                '$a + $b = ?',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(hintText: 'Answer'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (int.tryParse(ctrl.text) == sum) {
                Navigator.pop(ctx, true);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Incorrect answer. Please try again.')),
                );
              }
            },
            child: const Text('Verify & Delete All', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _CategoryManagerSheet extends ConsumerWidget {
  const _CategoryManagerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final scheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  'Manage Categories',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton.filledTonal(
                  onPressed: () => _showAddCategoryDialog(context, ref),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: categoriesAsync.when(
              data: (categories) => ListView.builder(
                controller: scrollController,
                itemCount: categories.length,
                padding: const EdgeInsets.only(bottom: 40),
                itemBuilder: (ctx, i) {
                  final cat = categories[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: scheme.primaryContainer.withValues(alpha: 0.5),
                      child: Text(cat.icon, style: const TextStyle(fontSize: 18)),
                    ),
                    title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _showAddCategoryDialog(context, ref, editCategory: cat),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                          onPressed: () => _confirmDeleteCategory(context, ref, cat, categories.length),
                        ),
                      ],
                    ),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref, {Category? editCategory}) {
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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

  void _confirmDeleteCategory(BuildContext context, WidgetRef ref, Category category, int count) {
    if (count <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete the last category')),
      );
      return;
    }

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
}
