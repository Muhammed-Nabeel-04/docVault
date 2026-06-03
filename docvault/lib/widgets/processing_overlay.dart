import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ProcessingOverlay extends StatelessWidget {
  final String message;
  final bool isDecryption;

  const ProcessingOverlay({
    super.key,
    required this.message,
    this.isDecryption = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      color: Colors.black54,
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Container(
          width: 200,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with pulsing and rotating animation
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isDecryption
                      ? scheme.secondaryContainer
                      : scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDecryption ? Icons.lock_open_rounded : Icons.enhanced_encryption_rounded,
                  size: 36,
                  color: isDecryption ? scheme.secondary : scheme.primary,
                )
                    .animate(onPlay: (controller) => controller.repeat())
                    .shimmer(duration: 1500.ms, color: Colors.white.withValues(alpha: 0.5))
                    .scale(
                      begin: const Offset(0.9, 0.9),
                      end: const Offset(1.1, 1.1),
                      duration: 1000.ms,
                      curve: Curves.easeInOut,
                    )
                    .then()
                    .scale(
                      begin: const Offset(1.1, 1.1),
                      end: const Offset(0.9, 0.9),
                      duration: 1000.ms,
                      curve: Curves.easeInOut,
                    ),
              ),
              const SizedBox(height: 24),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 8),
              Text(
                'Securing your data...',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ).animate().fadeIn(delay: 400.ms),
            ],
          ),
        ).animate().scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1.0, 1.0),
              duration: 400.ms,
              curve: Curves.easeOutBack,
            ).fadeIn(duration: 300.ms),
      ),
    );
  }

  /// Helper to show the overlay as a dialog
  static Future<void> show(BuildContext context, {required String message, bool isDecryption = false}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent, // We handle our own background
      builder: (_) => ProcessingOverlay(message: message, isDecryption: isDecryption),
    );
  }
}
