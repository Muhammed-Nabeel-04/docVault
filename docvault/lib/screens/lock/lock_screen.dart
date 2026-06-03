import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:docvault/providers/providers.dart';
import 'package:docvault/services/auth_service.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _pin = '';
  String? _error;
  bool _bioAvailable = false;
  DateTime? _lockoutUntil;
  Timer? _lockoutTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    await _checkLockout();
    
    final available = await AuthService.isBiometricsAvailable();
    final enabled = await AuthService.isBiometricEnabled();
    setState(() => _bioAvailable = available && enabled);
    
    // Auto-trigger biometrics if enabled and NOT locked out
    if (available && enabled && _lockoutUntil == null) {
      _tryBio();
    }
  }

  Future<void> _checkLockout() async {
    final until = await AuthService.getLockoutUntil();
    setState(() => _lockoutUntil = until);
    
    if (until != null) {
      _startLockoutTimer(until);
    }
  }

  void _startLockoutTimer(DateTime until) {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (DateTime.now().isAfter(until)) {
        setState(() => _lockoutUntil = null);
        timer.cancel();
        // Auto-trigger biometrics again once lockout ends
        if (_bioAvailable) {
          _tryBio();
        }
      } else {
        setState(() {}); // Refresh countdown
      }
    });
  }

  Future<void> _tryBio() async {
    if (_lockoutUntil != null) return;
    final ok = await AuthService.authenticateWithBiometrics();
    if (ok && mounted) _unlock();
  }

  Future<void> _unlock() async {
    await AuthService.resetFailedAttempts();
    if (!mounted) return;
    ref.read(isUnlockedProvider.notifier).state = true;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  void _onKey(String key) {
    if (_lockoutUntil != null) return;
    if (_pin.length >= 4) return;
    setState(() {
      _pin += key;
      _error = null;
    });
    if (_pin.length == 4) _verify();
  }

  void _onDelete() {
    if (_lockoutUntil != null) return;
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _verify() async {
    final ok = await AuthService.verifyPin(_pin);
    if (ok) {
      _unlock();
    } else {
      final until = await AuthService.getLockoutUntil();
      if (until != null) {
        setState(() {
          _pin = '';
          _lockoutUntil = until;
          _error = null;
        });
        _startLockoutTimer(until);
      } else {
        setState(() {
          _pin = '';
          _error = 'Incorrect PIN. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    String topText;
    if (_lockoutUntil != null) {
      final diff = _lockoutUntil!.difference(DateTime.now());
      final seconds = diff.inSeconds.clamp(0, 3600);
      topText = 'Locked. Try again in $seconds seconds';
    } else {
      topText = 'Enter your PIN to continue';
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Do nothing, preventing back navigation
      },
      child: Scaffold(
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
                Text(topText,
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: _lockoutUntil != null ? scheme.error : scheme.onSurfaceVariant)),
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
                  child: (_error != null && _lockoutUntil == null)
                      ? Text(_error!,
                          style: TextStyle(
                              color: scheme.error, fontSize: 13))
                      : null,
                ),
                const SizedBox(height: 24),

                // Keypad
                _buildKeypad(scheme),

                const Spacer(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad(ColorScheme scheme) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['BIO', '0', '⌫'],
    ];

    final isLocked = _lockoutUntil != null;

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((key) {
              if (key == 'BIO' && !_bioAvailable) {
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
                      backgroundColor: key == 'BIO' || key == '⌫'
                          ? Colors.transparent
                          : scheme.surfaceContainerHighest.withValues(alpha: isLocked ? 0.2 : 0.5),
                    ),
                    onPressed: isLocked ? null : () {
                      if (key == 'BIO') {
                        _tryBio();
                      } else if (key == '⌫') {
                        _onDelete();
                      } else {
                        _onKey(key);
                      }
                    },
                    child: key == 'BIO'
                        ? Icon(Icons.fingerprint_rounded,
                            size: 32, color: isLocked ? scheme.outline : scheme.primary)
                        : Text(
                            key,
                            style: TextStyle(
                              fontSize: key == '⌫' ? 22 : 28,
                              color: isLocked ? scheme.outline : scheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
