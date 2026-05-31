import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/encryption_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _hasPin = false;
  bool _bioAvailable = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pin = await AuthService.hasPin();
    final bio = await AuthService.isBiometricsAvailable();
    setState(() {
      _hasPin = pin;
      _bioAvailable = bio;
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
            ListTile(
              leading: const Icon(Icons.fingerprint_rounded),
              title: const Text('Biometric Unlock'),
              subtitle: const Text('Use fingerprint or face ID'),
              trailing: const Icon(Icons.chevron_right_rounded),
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
    setState(() => _hasPin = false);
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

    // Step 2: Verification (PIN or "DELETE" text)
    bool verified = false;
    if (_hasPin) {
      final pin = await _verifyPinDialog();
      if (pin != null) {
        verified = await AuthService.verifyPin(pin);
        if (!verified && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Incorrect PIN')),
          );
        }
      }
    } else {
      verified = await _typeDeleteDialog();
    }

    if (!verified) return;

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
}
