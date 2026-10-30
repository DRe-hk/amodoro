import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A dynamic 2.5D swaying sunflowers background ("animación de girasoles
/// meciéndose con el viento en estilo 2.5D").
///
/// Features:
/// - Parallax depth with 3 distinct floral layers (back-row soft blooms, mid-row,
///   and foreground hero sunflowers).
/// - Physics-inspired wind sway using multi-harmonic sine waves and traveling
///   gust harmonics along cubic Bezier curved stems.
/// - Signature Amodoro 2.5D perspective extrusion offsets (crisp unblurred
///   bottom-right rims on stems, leaves, petals, and seed disks).
/// - Multi-layered petals with interleaved back crown (golden-ochre) and front
///   crown (vibrant sunflower yellow) with tilted perspective disks.
/// - Rich 2.5D seed disk centers with Fermat spiral (Fibonacci) seed florets and
///   top-left specular rim highlights.
/// - Rolling 2.5D meadow hills and floating golden pollen motes drifting on the breeze.
/// - Automatic adaptation for both Light and Dark themes while keeping central UI
///   elements (login forms, empty state titles) 100% clear and legible.
class GlassBubbleBackground extends StatefulWidget {
  final Widget child;
  final bool emergeFromBottom;
  final double bubbleSize;

  const GlassBubbleBackground({
    super.key,
    required this.child,
    this.emergeFromBottom = false,
    this.bubbleSize = 310,
  });

  @override
  State<GlassBubbleBackground> createState() => _GlassBubbleBackgroundState();
}

/// Semantic alias for screens using the 2.5D swaying sunflowers background.
typedef SunflowerWindBackground = GlassBubbleBackground;

class _GlassBubbleBackgroundState extends State<GlassBubbleBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final screenHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;

        return Stack(
          fit: StackFit.expand,
          children: [
            // Animated 2.5D swaying sunflowers layer behind the UI
            RepaintBoundary(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return CustomPaint(
                      size: Size(screenWidth, screenHeight),
                      painter: _SunflowerWindPainter(
                        animationProgress: _controller.value,
                        isDark: isDark,
                        emergeFromBottom: widget.emergeFromBottom,
                        bubbleSize: widget.bubbleSize,
                      ),
                    );
                  },
                ),
              ),
            ),

            // Foreground child on top (inputs, cards, navigation)
            widget.child,
          ],
        );
      },
    );
  }
}

/// Leaf definition along the sunflower stem.
class _LeafSpec {
  final double u; // Position along stem curve (0.0 root to 1.0 head)
  final double length;
  final double width;
  final double angle; // Branching angle in radians
  final bool isLeft;

  const _LeafSpec({
    required this.u,
    required this.length,
    required this.width,
    required this.angle,
    required this.isLeft,
  });
}

/// Individual sunflower specification with parallax layer and kinematics.
class _SunflowerSpec {
  final double xRatio; // Relative horizontal position (0.0 to 1.0)
  final double heightRatio; // Stem height relative to screen height
  final double flowerRadius;
  final double phase; // Wind oscillation phase
  final double swayFactor; // Wind sensitivity
  final double restTilt; // Natural resting angle in calm air
  final int layer; // 0: back, 1: mid, 2: foreground hero
  final List<_LeafSpec> leaves;

  const _SunflowerSpec({
    required this.xRatio,
    required this.heightRatio,
    required this.flowerRadius,
    required this.phase,
    required this.swayFactor,
    required this.restTilt,
    required this.layer,
    required this.leaves,
  });
}

/// Floating golden pollen mote drifting in the breeze.
class _PollenSpec {
  final double xRatio;
  final double yRatio;
  final double speedX;
  final double bobFreq;
  final double bobAmp;
  final double size;
  final double phase;

  const _PollenSpec({
    required this.xRatio,
    required this.yRatio,
    required this.speedX,
    required this.bobFreq,
    required this.bobAmp,
    required this.size,
    required this.phase,
  });
}

/// Custom painter rendering the 2.5D swaying sunflower meadow.
class _SunflowerWindPainter extends CustomPainter {
  final double animationProgress; // 0.0 to 1.0
  final bool isDark;
  final bool emergeFromBottom;
  final double bubbleSize;

  const _SunflowerWindPainter({
    required this.animationProgress,
    required this.isDark,
    required this.emergeFromBottom,
    required this.bubbleSize,
  });

  // Cluster of 11 curated sunflowers framing the screen with open center
  static const List<_SunflowerSpec> _sunflowers = [
    // --- Layer 0: Back row (atmospheric, soft golden blooms) ---
    _SunflowerSpec(
      xRatio: 0.12,
      heightRatio: 0.32,
      flowerRadius: 24.0,
      phase: 0.35,
      swayFactor: 0.70,
      restTilt: -0.09,
      layer: 0,
      leaves: [
        _LeafSpec(u: 0.45, length: 24, width: 12, angle: 0.75, isLeft: true),
      ],
    ),
    _SunflowerSpec(
      xRatio: 0.36,
      heightRatio: 0.27,
      flowerRadius: 22.0,
      phase: 1.80,
      swayFactor: 0.65,
      restTilt: 0.04,
      layer: 0,
      leaves: [
        _LeafSpec(u: 0.50, length: 22, width: 11, angle: 0.70, isLeft: false),
      ],
    ),
    _SunflowerSpec(
      xRatio: 0.64,
      heightRatio: 0.28,
      flowerRadius: 23.0,
      phase: 3.20,
      swayFactor: 0.68,
      restTilt: -0.05,
      layer: 0,
      leaves: [
        _LeafSpec(u: 0.42, length: 23, width: 11, angle: 0.72, isLeft: true),
      ],
    ),
    _SunflowerSpec(
      xRatio: 0.88,
      heightRatio: 0.33,
      flowerRadius: 25.0,
      phase: 4.60,
      swayFactor: 0.72,
      restTilt: 0.10,
      layer: 0,
      leaves: [
        _LeafSpec(u: 0.48, length: 25, width: 12, angle: 0.78, isLeft: false),
      ],
    ),

    // --- Layer 1: Mid row (medium blooms, rich amber-gold) ---
    _SunflowerSpec(
      xRatio: 0.22,
      heightRatio: 0.38,
      flowerRadius: 33.0,
      phase: 1.10,
      swayFactor: 0.88,
      restTilt: -0.07,
      layer: 1,
      leaves: [
        _LeafSpec(u: 0.35, length: 32, width: 16, angle: 0.80, isLeft: true),
        _LeafSpec(u: 0.62, length: 28, width: 14, angle: 0.72, isLeft: false),
      ],
    ),
    _SunflowerSpec(
      xRatio: 0.50,
      heightRatio: 0.29,
      flowerRadius: 28.0,
      phase: 2.40,
      swayFactor: 0.80,
      restTilt: 0.02,
      layer: 1,
      leaves: [
        _LeafSpec(u: 0.40, length: 28, width: 14, angle: 0.75, isLeft: false),
      ],
    ),
    _SunflowerSpec(
      xRatio: 0.78,
      heightRatio: 0.39,
      flowerRadius: 34.0,
      phase: 3.85,
      swayFactor: 0.90,
      restTilt: 0.08,
      layer: 1,
      leaves: [
        _LeafSpec(u: 0.38, length: 33, width: 17, angle: 0.82, isLeft: false),
        _LeafSpec(u: 0.65, length: 29, width: 15, angle: 0.74, isLeft: true),
      ],
    ),

    // --- Layer 2: Foreground Hero row (majestic blooms, 2.5D tactile detail) ---
    _SunflowerSpec(
      xRatio: 0.07,
      heightRatio: 0.45,
      flowerRadius: 44.0,
      phase: 0.60,
      swayFactor: 1.05,
      restTilt: -0.15,
      layer: 2,
      leaves: [
        _LeafSpec(u: 0.30, length: 42, width: 22, angle: 0.85, isLeft: true),
        _LeafSpec(u: 0.55, length: 38, width: 20, angle: 0.78, isLeft: false),
      ],
    ),
    _SunflowerSpec(
      xRatio: 0.30,
      heightRatio: 0.39,
      flowerRadius: 39.0,
      phase: 2.05,
      swayFactor: 0.96,
      restTilt: -0.04,
      layer: 2,
      leaves: [
        _LeafSpec(u: 0.34, length: 38, width: 19, angle: 0.82, isLeft: false),
        _LeafSpec(u: 0.60, length: 34, width: 17, angle: 0.75, isLeft: true),
      ],
    ),
    _SunflowerSpec(
      xRatio: 0.70,
      heightRatio: 0.40,
      flowerRadius: 41.0,
      phase: 3.50,
      swayFactor: 0.98,
      restTilt: 0.05,
      layer: 2,
      leaves: [
        _LeafSpec(u: 0.32, length: 40, width: 20, angle: 0.84, isLeft: true),
        _LeafSpec(u: 0.58, length: 35, width: 18, angle: 0.76, isLeft: false),
      ],
    ),
    _SunflowerSpec(
      xRatio: 0.93,
      heightRatio: 0.47,
      flowerRadius: 46.0,
      phase: 4.95,
      swayFactor: 1.10,
      restTilt: 0.17,
      layer: 2,
      leaves: [
        _LeafSpec(u: 0.28, length: 44, width: 23, angle: 0.88, isLeft: false),
        _LeafSpec(u: 0.52, length: 40, width: 21, angle: 0.80, isLeft: true),
      ],
    ),
  ];

  // Drifting golden pollen particles
  static const List<_PollenSpec> _pollenParticles = [
    _PollenSpec(xRatio: 0.08, yRatio: 0.58, speedX: 0.42, bobFreq: 1.2, bobAmp: 12.0, size: 2.2, phase: 0.4),
    _PollenSpec(xRatio: 0.18, yRatio: 0.65, speedX: 0.35, bobFreq: 1.6, bobAmp: 16.0, size: 3.0, phase: 1.8),
    _PollenSpec(xRatio: 0.28, yRatio: 0.50, speedX: 0.50, bobFreq: 0.9, bobAmp: 10.0, size: 2.0, phase: 3.2),
    _PollenSpec(xRatio: 0.40, yRatio: 0.72, speedX: 0.38, bobFreq: 1.4, bobAmp: 14.0, size: 2.6, phase: 4.5),
    _PollenSpec(xRatio: 0.52, yRatio: 0.60, speedX: 0.46, bobFreq: 1.1, bobAmp: 15.0, size: 2.8, phase: 0.9),
    _PollenSpec(xRatio: 0.64, yRatio: 0.54, speedX: 0.33, bobFreq: 1.8, bobAmp: 11.0, size: 2.1, phase: 2.4),
    _PollenSpec(xRatio: 0.76, yRatio: 0.68, speedX: 0.48, bobFreq: 1.3, bobAmp: 18.0, size: 3.2, phase: 3.7),
    _PollenSpec(xRatio: 0.86, yRatio: 0.48, speedX: 0.40, bobFreq: 1.0, bobAmp: 13.0, size: 2.4, phase: 5.1),
    _PollenSpec(xRatio: 0.94, yRatio: 0.62, speedX: 0.36, bobFreq: 1.5, bobAmp: 16.0, size: 2.7, phase: 1.2),
    _PollenSpec(xRatio: 0.14, yRatio: 0.78, speedX: 0.44, bobFreq: 1.3, bobAmp: 14.0, size: 2.5, phase: 2.7),
    _PollenSpec(xRatio: 0.46, yRatio: 0.82, speedX: 0.39, bobFreq: 1.7, bobAmp: 12.0, size: 3.4, phase: 4.1),
    _PollenSpec(xRatio: 0.82, yRatio: 0.75, speedX: 0.47, bobFreq: 1.1, bobAmp: 15.0, size: 2.3, phase: 0.6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final t = animationProgress;

    // Scale multiplier based on bubbleSize prop
    final scaleMultiplier = (bubbleSize / 310.0).clamp(0.85, 1.35);
    final emergenceFactor = emergeFromBottom ? 1.06 : 1.0;

    // 1. Back Rolling Meadow Hill
    _drawBackHill(canvas, size);

    // 2. Parallax Layer 0: Back-row sunflowers
    _drawSunflowerLayer(
      canvas: canvas,
      size: size,
      layer: 0,
      t: t,
      scale: scaleMultiplier * emergenceFactor,
    );

    // 3. Mid Rolling Meadow Hill with 2.5D perspective rim
    _drawMidHill(canvas, size);

    // 4. Parallax Layer 1: Mid-row sunflowers
    _drawSunflowerLayer(
      canvas: canvas,
      size: size,
      layer: 1,
      t: t,
      scale: scaleMultiplier * emergenceFactor,
    );

    // 5. Foreground Turf with grass tufts & 2.5D extrusion
    _drawForegroundTurf(canvas, size, t);

    // 6. Parallax Layer 2: Foreground Hero sunflowers
    _drawSunflowerLayer(
      canvas: canvas,
      size: size,
      layer: 2,
      t: t,
      scale: scaleMultiplier * emergenceFactor,
    );

    // 7. Floating golden pollen & wind motes in the air
    _drawPollenMotes(canvas, size, t);
  }

  /// Draws all sunflowers assigned to a specific depth layer.
  void _drawSunflowerLayer({
    required Canvas canvas,
    required Size size,
    required int layer,
    required double t,
    required double scale,
  }) {
    for (final spec in _sunflowers) {
      if (spec.layer != layer) continue;

      final baseX = spec.xRatio * size.width;
      final baseY = size.height + 15.0; // Anchored beneath ground line
      final stemHeight = size.height * spec.heightRatio * scale;
      final flowerR = spec.flowerRadius * scale;

      // Kinematic wind sway: travelling wave across screen width
      final spatialPhase = spec.phase + (spec.xRatio * 1.6);
      final windWave = math.sin(t * 2 * math.pi + spatialPhase);
      final gustWave = math.sin(t * 4 * math.pi * 1.3 + spatialPhase * 1.4) * 0.35;
      final flutterWave = math.sin(t * 8 * math.pi * 0.9 + spatialPhase * 2.1) * 0.12;
      // Gentle prevailing breeze bias to the right (+ 0.18)
      final combinedWind = windWave + gustWave + flutterWave + 0.18;

      final maxSwayPixels = stemHeight * 0.15 * spec.swayFactor;
      final swayX = combinedWind * maxSwayPixels;

      // Cubic Bezier curve control points for the stem
      final p0 = Offset(baseX, baseY);
      final p1 = Offset(baseX + swayX * 0.12, baseY - stemHeight * 0.38);
      final p2 = Offset(baseX + swayX * 0.62, baseY - stemHeight * 0.76);
      final p3 = Offset(baseX + swayX, baseY - stemHeight);

      // Tilt angle of the flower head matching the stem tangent
      final dx = p3.dx - p2.dx;
      final dy = p3.dy - p2.dy;
      final tiltAngle = math.atan2(dx, -dy) + spec.restTilt;

      // Draw 2.5D curved stem
      _drawStem(canvas, p0, p1, p2, p3, flowerR, layer);

      // Draw 2.5D leaves
      _drawLeaves(canvas, p0, p1, p2, p3, spec.leaves, t, spatialPhase, scale, layer);

      // Draw 2.5D flower head (petals, tilted perspective disk, seed disk, Fibonacci florets)
      _drawFlowerHead(canvas, p3, tiltAngle, flowerR, layer);
    }
  }

  /// Evaluates a point on a cubic Bezier curve at parameter u.
  Offset _cubicPoint(Offset p0, Offset p1, Offset p2, Offset p3, double u) {
    final omt = 1.0 - u;
    final omt2 = omt * omt;
    final omt3 = omt2 * omt;
    final u2 = u * u;
    final u3 = u2 * u;
    return Offset(
      omt3 * p0.dx + 3 * omt2 * u * p1.dx + 3 * omt * u2 * p2.dx + u3 * p3.dx,
      omt3 * p0.dy + 3 * omt2 * u * p1.dy + 3 * omt * u2 * p2.dy + u3 * p3.dy,
    );
  }

  /// Evaluates tangent vector on a cubic Bezier curve at parameter u.
  Offset _cubicTangent(Offset p0, Offset p1, Offset p2, Offset p3, double u) {
    final omt = 1.0 - u;
    final omt2 = omt * omt;
    final u2 = u * u;
    return Offset(
      3 * omt2 * (p1.dx - p0.dx) + 6 * omt * u * (p2.dx - p1.dx) + 3 * u2 * (p3.dx - p2.dx),
      3 * omt2 * (p1.dy - p0.dy) + 6 * omt * u * (p2.dy - p1.dy) + 3 * u2 * (p3.dy - p2.dy),
    );
  }

  /// Draws a stem with 2.5D perspective extrusion and cylindrical highlight.
  void _drawStem(
    Canvas canvas,
    Offset p0,
    Offset p1,
    Offset p2,
    Offset p3,
    double radius,
    int layer,
  ) {
    final stemThickness = (radius * 0.14).clamp(3.0, 6.5);
    final stemPath = Path()
      ..moveTo(p0.dx, p0.dy)
      ..cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, p3.dx, p3.dy);

    // 2.5D bottom-right extrusion rim (offset 2.0px, 2.5px)
    final shadowColor = isDark
        ? const Color(0xFF142410).withValues(alpha: layer == 0 ? 0.75 : 0.95)
        : const Color(0xFF223E16).withValues(alpha: layer == 0 ? 0.65 : 0.90);
    final shadowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stemThickness
      ..strokeCap = StrokeCap.round
      ..color = shadowColor;
    canvas.drawPath(stemPath.shift(const Offset(2.0, 2.5)), shadowPaint);

    // Main stem body in rich olive-spring green
    final mainColor = isDark
        ? (layer == 0 ? const Color(0xFF33531F) : const Color(0xFF3D6325))
        : (layer == 0 ? const Color(0xFF5D853A) : const Color(0xFF4F7A2C));
    final mainPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stemThickness
      ..strokeCap = StrokeCap.round
      ..color = mainColor;
    canvas.drawPath(stemPath, mainPaint);

    // Subtle top-left cylindrical sheen
    final highlightColor = isDark
        ? const Color(0xFF6B9B45).withValues(alpha: 0.35)
        : const Color(0xFF88BD55).withValues(alpha: 0.55);
    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stemThickness * 0.32
      ..strokeCap = StrokeCap.round
      ..color = highlightColor;
    canvas.drawPath(stemPath.shift(const Offset(-0.8, -0.6)), highlightPaint);
  }

  /// Draws 2.5D leaves with perspective extrusion and leaf veins.
  void _drawLeaves(
    Canvas canvas,
    Offset p0,
    Offset p1,
    Offset p2,
    Offset p3,
    List<_LeafSpec> leaves,
    double t,
    double spatialPhase,
    double scale,
    int layer,
  ) {
    for (final leaf in leaves) {
      final leafPt = _cubicPoint(p0, p1, p2, p3, leaf.u);
      final tangent = _cubicTangent(p0, p1, p2, p3, leaf.u);
      final stemAngle = math.atan2(tangent.dy, tangent.dx);
      final sideAngle = leaf.isLeft ? -leaf.angle : leaf.angle;
      // Wind flutter on leaf tip
      final leafFlutter =
          math.sin(t * 2 * math.pi * 1.6 + spatialPhase + leaf.u * 4.0) * 0.08;
      final finalAngle = stemAngle + sideAngle + leafFlutter;

      final leafLen = leaf.length * scale;
      final leafW = leaf.width * scale;

      canvas.save();
      canvas.translate(leafPt.dx, leafPt.dy);
      canvas.rotate(finalAngle);

      // Leaf contour
      final leafPath = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(leafLen * 0.45, -leafW * 0.55, leafLen, leafLen * 0.16)
        ..quadraticBezierTo(leafLen * 0.55, leafW * 0.65, 0, 0);

      // 1. 2.5D bottom-right perspective edge shadow
      final leafShadowColor = isDark
          ? const Color(0xFF13230F).withValues(alpha: layer == 0 ? 0.70 : 0.95)
          : const Color(0xFF1F3B14).withValues(alpha: layer == 0 ? 0.60 : 0.88);
      canvas.drawPath(
        leafPath.shift(const Offset(2.2, 2.5)),
        Paint()..color = leafShadowColor,
      );

      // 2. Main leaf body
      final leafBodyColor = isDark
          ? (layer == 0 ? const Color(0xFF2E4C1C) : const Color(0xFF385E22))
          : (layer == 0 ? const Color(0xFF5A8437) : const Color(0xFF4C7B2A));
      canvas.drawPath(leafPath, Paint()..color = leafBodyColor);

      // 3. Central leaf vein
      final veinPath = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(leafLen * 0.50, leafLen * 0.06, leafLen * 0.90, leafLen * 0.14);
      final veinColor = isDark
          ? const Color(0xFF6B9C45).withValues(alpha: 0.50)
          : const Color(0xFF8DC458).withValues(alpha: 0.65);
      canvas.drawPath(
        veinPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..strokeCap = StrokeCap.round
          ..color = veinColor,
      );

      // 4. Lateral leaf veins
      final sideVeinPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..strokeCap = StrokeCap.round
        ..color = veinColor.withValues(alpha: isDark ? 0.35 : 0.45);

      canvas.drawLine(
        Offset(leafLen * 0.32, leafLen * 0.03),
        Offset(leafLen * 0.48, -leafW * 0.22),
        sideVeinPaint,
      );
      canvas.drawLine(
        Offset(leafLen * 0.42, leafLen * 0.05),
        Offset(leafLen * 0.58, leafW * 0.26),
        sideVeinPaint,
      );

      canvas.restore();
    }
  }

  /// Draws the complete 2.5D sunflower head with layered crowns, 2.5D extrusion rims,
  /// perspective-tilted disk, and Fibonacci seed core.
  void _drawFlowerHead(
    Canvas canvas,
    Offset headPt,
    double tiltAngle,
    double radius,
    int layer,
  ) {
    canvas.save();
    canvas.translate(headPt.dx, headPt.dy);
    canvas.rotate(tiltAngle);

    // 2.5D tilted perspective squash: view angle tilted slightly downward
    canvas.scale(1.0, 0.88);

    // Soft ambient twilight bloom for foreground hero sunflowers in Dark mode
    if (isDark && layer == 2) {
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFF9C74F).withValues(alpha: 0.15),
            const Color(0xFFE09624).withValues(alpha: 0.05),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius * 1.55));
      canvas.drawCircle(Offset.zero, radius * 1.55, glowPaint);
    }

    final diskR = radius * 0.44;
    final backPetalLen = radius * 0.94;
    final backPetalW = radius * 0.28;
    final frontPetalLen = radius * 1.05;
    final frontPetalW = radius * 0.31;

    // --- 1. Multi-layered 2.5D Petals: Back Crown (16 golden-ochre petals) ---
    final backPetalPath = _buildPetalPath(diskR * 0.85, backPetalLen, backPetalW);

    final backEdgeColor = isDark
        ? const Color(0xFF8A4607).withValues(alpha: layer == 0 ? 0.70 : 0.95)
        : const Color(0xFFC87D18).withValues(alpha: layer == 0 ? 0.65 : 0.95);
    final backEdgePaint = Paint()..color = backEdgeColor;

    final backBodyColor = isDark
        ? (layer == 0 ? const Color(0xFFB0680F) : const Color(0xFFCC7B14))
        : (layer == 0 ? const Color(0xFFD9881A) : const Color(0xFFE09624));
    final backBodyPaint = Paint()..color = backBodyColor;

    const backPetalCount = 16;
    for (int i = 0; i < backPetalCount; i++) {
      final theta = i * (2 * math.pi / backPetalCount);
      canvas.save();
      canvas.rotate(theta);
      // 2.5D extrusion rim offset
      canvas.drawPath(backPetalPath.shift(const Offset(1.8, 2.2)), backEdgePaint);
      // Back petal body
      canvas.drawPath(backPetalPath, backBodyPaint);
      canvas.restore();
    }

    // --- 2. Multi-layered 2.5D Petals: Front Crown (16 vibrant yellow petals, interleaved) ---
    final frontPetalPath = _buildPetalPath(diskR * 0.90, frontPetalLen, frontPetalW);

    final frontEdgeColor = isDark
        ? const Color(0xFFA66408).withValues(alpha: layer == 0 ? 0.70 : 0.95)
        : const Color(0xFFD48B16).withValues(alpha: layer == 0 ? 0.65 : 0.95);
    final frontEdgePaint = Paint()..color = frontEdgeColor;

    final frontBodyColor = isDark
        ? (layer == 0 ? const Color(0xFFD69822) : const Color(0xFFF4B42A))
        : (layer == 0 ? const Color(0xFFF6BC36) : const Color(0xFFF9C74F));
    final frontBodyPaint = Paint()..color = frontBodyColor;

    final frontSpineColor = isDark
        ? const Color(0xFFB87814).withValues(alpha: 0.40)
        : const Color(0xFFE09624).withValues(alpha: 0.50);
    final frontSpinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..color = frontSpineColor;

    const frontPetalCount = 16;
    for (int i = 0; i < frontPetalCount; i++) {
      final theta = (i + 0.5) * (2 * math.pi / frontPetalCount);
      canvas.save();
      canvas.rotate(theta);
      // 2.5D extrusion rim
      canvas.drawPath(frontPetalPath.shift(const Offset(1.8, 2.2)), frontEdgePaint);
      // Front petal body
      canvas.drawPath(frontPetalPath, frontBodyPaint);
      // Delicate petal center spine
      canvas.drawLine(
        Offset(0, diskR * 0.95),
        Offset(0, diskR + frontPetalLen * 0.80),
        frontSpinePaint,
      );
      canvas.restore();
    }

    // --- 3. Rich 2.5D Seed Disk Center ---
    // A. 2.5D bottom-right depth rim / extrusion (offset 2.5px, 3.2px)
    final diskShadowColor = isDark ? const Color(0xFF1E0E06) : const Color(0xFF2C160B);
    canvas.drawOval(
      Rect.fromCircle(center: const Offset(2.5, 3.2), radius: diskR),
      Paint()..color = diskShadowColor,
    );

    // B. Outer Calyx ring (#4A2C1D)
    canvas.drawCircle(
      Offset.zero,
      diskR,
      Paint()..color = const Color(0xFF4A2C1D),
    );

    // C. Concentric inner core gradient (#361E12)
    final coreGradient = RadialGradient(
      center: const Alignment(-0.25, -0.25),
      radius: 0.95,
      colors: [
        const Color(0xFF5A3520),
        const Color(0xFF361E12),
        const Color(0xFF26130A),
      ],
      stops: const [0.0, 0.65, 1.0],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: diskR * 0.95));
    canvas.drawCircle(Offset.zero, diskR * 0.95, Paint()..shader = coreGradient);

    // D. Fibonacci spiral seed dot pattern (Fermat's spiral phyllotaxis)
    final floretCount = layer == 2 ? 46 : (layer == 1 ? 34 : 22);
    final amberPaint = Paint()..color = const Color(0xFFD49B35).withValues(alpha: 0.88);
    final goldPaint = Paint()..color = const Color(0xFFF4B42A).withValues(alpha: 0.82);
    final caramelPaint = Paint()..color = const Color(0xFFB37D28).withValues(alpha: 0.78);
    final darkFloretPaint = Paint()..color = const Color(0xFF6B3E1C).withValues(alpha: 0.90);

    for (int n = 1; n <= floretCount; n++) {
      final r = diskR * 0.85 * math.sqrt(n / floretCount);
      final theta = n * 2.3999632; // 137.507764 degrees (Golden Angle)
      final fx = r * math.cos(theta);
      final fy = r * math.sin(theta);
      final fRadius = 0.8 + (r / diskR) * 0.9;

      final Paint chosenPaint;
      final mod = n % 4;
      if (mod == 0) {
        chosenPaint = amberPaint;
      } else if (mod == 1) {
        chosenPaint = goldPaint;
      } else if (mod == 2) {
        chosenPaint = caramelPaint;
      } else {
        chosenPaint = darkFloretPaint;
      }

      canvas.drawCircle(Offset(fx, fy), fRadius, chosenPaint);
    }

    // E. Outer golden floret bud ring
    const rimFloretCount = 18;
    final rimBudPaint = Paint()..color = const Color(0xFFE8AB36).withValues(alpha: 0.90);
    for (int j = 0; j < rimFloretCount; j++) {
      final angle = j * (2 * math.pi / rimFloretCount);
      canvas.drawCircle(
        Offset(diskR * 0.88 * math.cos(angle), diskR * 0.88 * math.sin(angle)),
        1.25,
        rimBudPaint,
      );
    }

    // F. Top-left 2.5D specular rim highlight arc
    final specularArcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: isDark ? 0.25 : 0.38);
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: diskR * 0.94),
      -math.pi * 0.88,
      math.pi * 0.65,
      false,
      specularArcPaint,
    );

    canvas.restore();
  }

  /// Builds an organic sunflower petal contour.
  Path _buildPetalPath(double startR, double length, double width) {
    return Path()
      ..moveTo(0, startR)
      ..cubicTo(
        -width * 0.52,
        startR + length * 0.38,
        -width * 0.36,
        startR + length * 0.82,
        0,
        startR + length,
      )
      ..cubicTo(
        width * 0.36,
        startR + length * 0.82,
        width * 0.52,
        startR + length * 0.38,
        0,
        startR,
      );
  }

  /// Draws the back rolling meadow hill.
  void _drawBackHill(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(0, h)
      ..lineTo(0, h - 36)
      ..quadraticBezierTo(w * 0.28, h - 50, w * 0.55, h - 38)
      ..quadraticBezierTo(w * 0.80, h - 26, w, h - 42)
      ..lineTo(w, h)
      ..close();

    final hillColor = isDark
        ? const Color(0xFF1E281C).withValues(alpha: 0.88)
        : const Color(0xFF8FA876).withValues(alpha: 0.38);
    canvas.drawPath(path, Paint()..color = hillColor);
  }

  /// Draws the mid rolling meadow hill with a 2.5D perspective rim.
  void _drawMidHill(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(0, h)
      ..lineTo(0, h - 25)
      ..quadraticBezierTo(w * 0.32, h - 16, w * 0.62, h - 32)
      ..quadraticBezierTo(w * 0.85, h - 38, w, h - 22)
      ..lineTo(w, h)
      ..close();

    // 2.5D bottom-right edge shadow
    final edgeColor = isDark
        ? const Color(0xFF121B11)
        : const Color(0xFF385227).withValues(alpha: 0.40);
    canvas.drawPath(
      path.shift(const Offset(2.0, 2.5)),
      Paint()..color = edgeColor,
    );

    final hillColor = isDark
        ? const Color(0xFF1A2619)
        : const Color(0xFF5B8049).withValues(alpha: 0.72);
    canvas.drawPath(path, Paint()..color = hillColor);
  }

  /// Draws the foreground meadow turf with grass tufts and 2.5D extrusion.
  void _drawForegroundTurf(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(0, h)
      ..lineTo(0, h - 14)
      ..quadraticBezierTo(w * 0.24, h - 22, w * 0.50, h - 13)
      ..quadraticBezierTo(w * 0.76, h - 19, w, h - 11)
      ..lineTo(w, h)
      ..close();

    // 2.5D bottom-right edge shadow
    final edgeColor = isDark
        ? const Color(0xFF0D140C)
        : const Color(0xFF2B3F1D).withValues(alpha: 0.55);
    canvas.drawPath(
      path.shift(const Offset(2.0, 2.5)),
      Paint()..color = edgeColor,
    );

    final turfColor = isDark ? const Color(0xFF141E13) : const Color(0xFF476937);
    canvas.drawPath(path, Paint()..color = turfColor);

    // Stylized grass blades swaying along the turf
    _drawGrassBlades(canvas, size, t);
  }

  /// Draws subtle grass blades along the foreground edge.
  void _drawGrassBlades(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;

    final bladeColor = isDark ? const Color(0xFF325224) : const Color(0xFF659247);
    final bladeEdgeColor = isDark ? const Color(0xFF15220F) : const Color(0xFF2E4B1C);

    final bladePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = bladeColor;

    final bladeEdgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = bladeEdgeColor;

    const bladePositions = [0.04, 0.16, 0.26, 0.42, 0.58, 0.72, 0.84, 0.96];
    for (int i = 0; i < bladePositions.length; i++) {
      final bx = bladePositions[i] * w;
      final by = h - 10.0;
      final bladeH = 14.0 + (i % 3) * 5.0;
      final sway = math.sin(t * 2 * math.pi * 1.5 + i * 0.9) * 5.0;

      final grassPath = Path()
        ..moveTo(bx, by)
        ..quadraticBezierTo(bx + sway * 0.4, by - bladeH * 0.55, bx + sway, by - bladeH);

      canvas.drawPath(grassPath.shift(const Offset(1.5, 1.8)), bladeEdgePaint);
      canvas.drawPath(grassPath, bladePaint);
    }
  }

  /// Draws floating golden pollen motes drifting on the wind.
  void _drawPollenMotes(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;

    for (final p in _pollenParticles) {
      // Drift horizontally across the width
      final px = ((p.xRatio + t * p.speedX) % 1.0) * w;
      // Sinusoidal bobbing in the wind
      final py = (p.yRatio * h) +
          math.sin(t * 2 * math.pi * p.bobFreq + p.phase) * p.bobAmp +
          math.sin(t * 4 * math.pi * 0.8 + p.phase * 1.4) * 4.0;

      // Gentle shimmering pulse
      final pulse = 0.40 + 0.60 * math.sin(t * 2 * math.pi * 2.0 + p.phase).abs();
      final alpha = (isDark ? 0.55 : 0.42) * pulse;

      // Soft ambient aura
      final auraPaint = Paint()
        ..color = const Color(0xFFF9C74F).withValues(alpha: alpha * 0.35);
      canvas.drawCircle(Offset(px, py), p.size * 2.2, auraPaint);

      // Bright core mote
      final coreColor = isDark ? const Color(0xFFFFF1C2) : const Color(0xFFEAA620);
      final corePaint = Paint()..color = coreColor.withValues(alpha: alpha);
      canvas.drawCircle(Offset(px, py), p.size, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SunflowerWindPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.isDark != isDark ||
        oldDelegate.emergeFromBottom != emergeFromBottom ||
        oldDelegate.bubbleSize != bubbleSize;
  }
}
