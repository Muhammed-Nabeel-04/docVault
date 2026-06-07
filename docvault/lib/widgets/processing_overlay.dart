import 'dart:math' as math;
import 'package:flutter/material.dart';

class ProcessingOverlay extends StatelessWidget {
  final bool isDecryption;

  const ProcessingOverlay({
    super.key,
    this.isDecryption = false,
    String message = '',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: Colors.black54,
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: _LockCard(isDecryption: isDecryption, scheme: scheme),
      ),
    );
  }

  static Future<void> show(
    BuildContext context, {
    required String message,
    bool isDecryption = false,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (_) => ProcessingOverlay(isDecryption: isDecryption),
    );
  }
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _LockCard extends StatefulWidget {
  final bool isDecryption;
  final ColorScheme scheme;
  const _LockCard({required this.isDecryption, required this.scheme});

  @override
  State<_LockCard> createState() => _LockCardState();
}

class _LockCardState extends State<_LockCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _cardScale;
  late final Animation<double> _cardOpacity;
  late final Animation<double> _shackle;   // 0.0 = closed, 1.0 = open
  late final Animation<double> _bodyPulse;
  late final Animation<double> _glowOpacity;
  late final Animation<double> _glowScale;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _cardScale = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.20, curve: Curves.easeOutBack),
      ),
    );
    _cardOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.14, curve: Curves.easeOut),
      ),
    );

    if (widget.isDecryption) {
      // Closed → open
      _shackle = TweenSequence<double>([
        TweenSequenceItem(tween: ConstantTween(0.0), weight: 10),
        TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.0)
              .chain(CurveTween(curve: Curves.easeInOutCubic)),
          weight: 45,
        ),
        // small bounce back
        TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.88)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 10,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 0.88, end: 1.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 10,
        ),
        TweenSequenceItem(tween: ConstantTween(1.0), weight: 25),
      ]).animate(_ctrl);
    } else {
      // Open → closed
      _shackle = TweenSequence<double>([
        TweenSequenceItem(tween: ConstantTween(1.0), weight: 10),
        TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.0)
              .chain(CurveTween(curve: Curves.easeInCubic)),
          weight: 40,
        ),
        // bounce on close
        TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 0.14)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 10,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 0.14, end: 0.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 10,
        ),
        TweenSequenceItem(tween: ConstantTween(0.0), weight: 30),
      ]).animate(_ctrl);
    }

    _bodyPulse = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 58),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.07)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 14,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.07, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 14,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 14),
    ]).animate(_ctrl);

    _glowOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 52),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.55)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 12,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.55, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 36,
      ),
    ]).animate(_ctrl);

    _glowScale = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.7), weight: 52),
      TweenSequenceItem(
        tween: Tween(begin: 0.7, end: 1.7)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 48,
      ),
    ]).animate(_ctrl);

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = widget.scheme;
    final color = widget.isDecryption ? scheme.secondary : scheme.primary;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: _cardOpacity.value,
        child: Transform.scale(
          scale: _cardScale.value,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 36,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Center(
              child: SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // glow ring
                    Transform.scale(
                      scale: _glowScale.value,
                      child: Opacity(
                        opacity: _glowOpacity.value,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color.withValues(alpha: 0.16),
                          ),
                        ),
                      ),
                    ),
                    // lock
                    Transform.scale(
                      scale: _bodyPulse.value,
                      child: CustomPaint(
                        size: const Size(60, 68),
                        painter: _LockPainter(
                          openFraction: _shackle.value,
                          color: color,
                          fillColor: scheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Painter ───────────────────────────────────────────────────────────────────
//
// The Perfected 2D Hinge:
// Instead of messing with canvas matrices (which causes the shackle to disconnect 
// and float), we dynamically calculate the perfect geometry for every frame.
// 
// Phase 1 (0% to 40%): Lifts straight up to clear the right hole.
// Phase 2 (40% to 100%): Widens the top arc to "swing" the right leg open,
// while keeping the left leg permanently anchored deep inside the lock body.

class _LockPainter extends CustomPainter {
  final double openFraction; // 0.0 closed  →  1.0 open
  final Color color;
  final Color fillColor;

  const _LockPainter({
    required this.openFraction,
    required this.color,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;   // 60
    final h = size.height;  // 68

    // ── geometry constants ────────────────────────────────────────────────
    const bodyCorner  = 9.0;
    final bodyTop     = h * 0.44;     // ~29.9
    final bodyHeight  = h - bodyTop;  // ~38.1

    final legLeftX    = w * 0.28;     // 16.8 (The Hinge - NEVER moves)
    final baseRightX  = w * 0.72;     // 43.2 (Closed right leg)

    // ── split animation phases ────────────────────────────────────────────
    // Lift for the first 40%, swing open for the remaining 60%
    final liftProgress  = (openFraction / 0.4).clamp(0.0, 1.0);
    final swingProgress = ((openFraction - 0.4) / 0.6).clamp(0.0, 1.0);

    // Max pixels it lifts up
    const maxLift = 14.0; 
    final currentLift = liftProgress * maxLift;

    // Max pixels it swings to the right
    const maxSwing = 16.0; 
    final currentSwing = swingProgress * maxSwing;

    // ── dynamic path calculation ──────────────────────────────────────────
    // The right leg shifts rightwards to open.
    final currentRightX = baseRightX + currentSwing;
    
    // The arc dynamically adjusts its radius to perfectly connect the two legs.
    final currentWidth = currentRightX - legLeftX;
    final arcRadius = currentWidth / 2.0;
    final arcCenterX = legLeftX + arcRadius;

    // The vertical center of the arc moves UP based purely on the lift.
    // When closed, the arc center sits 4px above the body.
    final arcCenterY = (bodyTop - 4.0) - currentLift;

    // ── paints ────────────────────────────────────────────────────────────
    final shacklePaint = Paint()
      ..color       = color
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap   = StrokeCap.round
      ..strokeJoin  = StrokeJoin.round;

    // ── draw shackle (BEHIND the body) ────────────────────────────────────
    final shacklePath = Path();

    // 1. Left leg
    // Starts 15px deep inside the body so it never accidentally pops out.
    shacklePath.moveTo(legLeftX, bodyTop + 15.0); 
    shacklePath.lineTo(legLeftX, arcCenterY);

    // 2. Dynamic Arc
    shacklePath.arcTo(
      Rect.fromCircle(
        center: Offset(arcCenterX, arcCenterY),
        radius: arcRadius,
      ),
      math.pi,   // Start at the left leg (9 o'clock)
      math.pi,   // Sweep exactly 180 degrees clockwise over the top
      false,
    );

    // 3. Right leg
    // Base closed Y is 3px inside the body. The lift pulls it up and out.
    final rightLegBottomY = bodyTop + 3.0 - currentLift;
    shacklePath.lineTo(currentRightX, rightLegBottomY);

    canvas.drawPath(shacklePath, shacklePaint);

    // ── draw lock body (ON TOP to mask the holes cleanly) ─────────────────
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, bodyTop, w, bodyHeight),
      const Radius.circular(bodyCorner),
    );

    canvas.drawRRect(bodyRect, Paint()..color = fillColor);
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..color       = color
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // ── keyhole ───────────────────────────────────────────────────────────
    final kx = w / 2;
    final ky = bodyTop + bodyHeight * 0.42;

    canvas.drawCircle(Offset(kx, ky), 5.5, Paint()..color = color);

    final stemPath = Path()
      ..moveTo(kx - 3.2, ky + 3.5)
      ..lineTo(kx - 2.0, ky + 11.5)
      ..lineTo(kx + 2.0, ky + 11.5)
      ..lineTo(kx + 3.2, ky + 3.5)
      ..close();
    canvas.drawPath(stemPath, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LockPainter old) =>
      old.openFraction != openFraction ||
      old.color != color ||
      old.fillColor != fillColor;
}

