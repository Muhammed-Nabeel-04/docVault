import 'package:flutter/material.dart';

class PinKeypad extends StatelessWidget {
  final Function(String) onKey;
  final VoidCallback onDelete;
  final VoidCallback? onBio;
  final bool showBio;
  final bool isLocked;

  const PinKeypad({
    super.key,
    required this.onKey,
    required this.onDelete,
    this.onBio,
    this.showBio = false,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      [showBio ? 'BIO' : '', '0', '⌫'],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((key) {
              if (key.isEmpty) {
                return const SizedBox(width: 96); // 72 width + 24 padding
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
                        onBio?.call();
                      } else if (key == '⌫') {
                        onDelete();
                      } else {
                        onKey(key);
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
