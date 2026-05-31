import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../services/auth_service.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _pin = '';
  String? _error;
  bool _bioAvailable = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final bio = await AuthService.isBiometricsAvailable();
    setState(() => _bioAvailable = bio);
    if (bio) _tryBio();
  }

  Future<void> _tryBio() async {
    final ok = await AuthService.authenticateWithBiometrics();
    if (ok && mounted) _unlock();
  }

  void _unlock() {
    ref.read(isUnlockedProvider.notifier).state = true;
    Navigator.pushReplacementNamed(context, '/');
  }

  void _onKey(String key) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += key;
      _error = null;
    });
    if (_pin.length == 4) _verify();
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _verify() async {
    final ok = await AuthService.verifyPin(_pin);
    if (ok) {
      _unlock();
    } else {
      setState(() {
        _pin = '';
        _error = 'Incorrect PIN. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              const Spacer(),

              // Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_rounded,
                    size: 32, color: scheme.primary),
              ),
              const SizedBox(height: 20),
              const Text('DocVault',
                  style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Enter your PIN to continue',
                  style:
                      TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 36),

              // PIN dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < _pin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          filled ? scheme.primary : Colors.transparent,
                      border: Border.all(
                        color: filled ? scheme.primary : scheme.outline,
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),

              // Error text
              const SizedBox(height: 16),
              SizedBox(
                height: 20,
                child: _error != null
                    ? Text(_error!,
                        style: TextStyle(
                            color: scheme.error, fontSize: 13))
                    : null,
              ),
              const SizedBox(height: 24),

              // Keypad
              ..._buildKeypad(scheme),

              const Spacer(),

              if (_bioAvailable)
                TextButton.icon(
                  onPressed: _tryBio,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: const Text('Use Biometrics'),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildKeypad(ColorScheme scheme) {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

    return rows.map((row) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((key) {
            if (key.isEmpty) {
              return const SizedBox(width: 80);
            }
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 72,
                height: 72,
                child: TextButton(
                  style: TextButton.styleFrom(
                    shape: const CircleBorder(),
                    backgroundColor:
                        scheme.surfaceVariant.withOpacity(0.5),
                  ),
                  onPressed: () =>
                      key == '⌫' ? _onDelete() : _onKey(key),
                  child: Text(
                    key,
                    style: TextStyle(
                      fontSize: key == '⌫' ? 18 : 24,
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
    }).toList();
  }
}
