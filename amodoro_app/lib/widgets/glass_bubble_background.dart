import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/amodoro_theme.dart';

/// A dynamic Apple Glass refractive bubble background.
///
/// Smoothly animates a large organic glass bubble (280dp–340dp diameter)
/// that drifts behind the UI with multi-layered optical refraction,
/// rich backdrop blur (sigma 28), warm luminous ambient glow,
/// internal curved glass lens sheen, and iridescent specular rim highlights.
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

class _GlassBubbleBackgroundState extends State<GlassBubbleBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
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
            // Optical glass bubble layer behind UI
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final t = _controller.value;
                  final phi = t * 2 * math.pi;

                  // Organic bubble breathing diameter based on bubbleSize
                  final baseSize = widget.bubbleSize;
                  final bubbleDiameter =
                      baseSize + (baseSize * 0.08) * math.sin(phi);

                  // Position trajectory
                  final double cx;
                  final double cy;

                  if (widget.emergeFromBottom) {
                    // Emerges gently from the bottom edge towards lower-middle
                    cx = (screenWidth * 0.5) +
                        math.sin(phi) * (screenWidth * 0.15);
                    cy = (screenHeight * 0.76) +
                        math.cos(phi) * (screenHeight * 0.08) -
                        math.sin(phi * 0.5).abs() * 20.0;
                  } else {
                    // Gentle figure-8 / Lissajous floating drift around upper-middle
                    cx = (screenWidth * 0.5) +
                        math.sin(phi) * (screenWidth * 0.18) +
                        math.cos(phi * 2) * 12.0;
                    cy = (screenHeight * 0.38) +
                        math.cos(phi) * (screenHeight * 0.10) +
                        math.sin(phi * 2) * 16.0;
                  }

                  final left = cx - bubbleDiameter / 2;
                  final top = cy - bubbleDiameter / 2;

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // 1. Secondary ambient glass halo behind the sphere
                      Positioned(
                        left: left - (bubbleDiameter * 0.22),
                        top: top - (bubbleDiameter * 0.22),
                        width: bubbleDiameter * 1.44,
                        height: bubbleDiameter * 1.44,
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  (isDark
                                          ? AmodoroTheme.coralPillDark
                                          : AmodoroTheme.coralPillLight)
                                      .withValues(alpha: isDark ? 0.26 : 0.36),
                                  const Color(0xFFF5E0B5)
                                      .withValues(alpha: isDark ? 0.20 : 0.28),
                                  const Color(0xFFE8DEF8)
                                      .withValues(alpha: isDark ? 0.22 : 0.30),
                                  const Color(0xFFD3E4FF)
                                      .withValues(alpha: isDark ? 0.12 : 0.18),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.35, 0.62, 0.82, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 2. The Apple Glass bubble with optical blur & multi-layered refraction
                      Positioned(
                        left: left,
                        top: top,
                        width: bubbleDiameter,
                        height: bubbleDiameter,
                        child: IgnorePointer(
                          child: ClipOval(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: 28.0,
                                sigmaY: 28.0,
                              ),
                              child: Container(
                                width: bubbleDiameter,
                                height: bubbleDiameter,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    center: const Alignment(-0.35, -0.35),
                                    radius: 0.98,
                                    colors: [
                                      Colors.white
                                          .withValues(alpha: isDark ? 0.32 : 0.52),
                                      const Color(0xFFFFECE8)
                                          .withValues(alpha: isDark ? 0.18 : 0.28),
                                      const Color(0xFFF5E0B5)
                                          .withValues(alpha: isDark ? 0.10 : 0.16),
                                      const Color(0xFFE8DEF8)
                                          .withValues(alpha: isDark ? 0.16 : 0.24),
                                      Colors.white
                                          .withValues(alpha: isDark ? 0.18 : 0.30),
                                    ],
                                    stops: const [0.0, 0.32, 0.58, 0.82, 1.0],
                                  ),
                                ),
                                child: CustomPaint(
                                  size: Size(bubbleDiameter, bubbleDiameter),
                                  painter: _GlassRefractiveRimPainter(
                                    isDark: isDark,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Foreground child on top
            widget.child,
          ],
        );
      },
    );
  }
}

/// Custom painter for the Apple Glass refractive lens sheen, caustic glow, and specular highlights.
class _GlassRefractiveRimPainter extends CustomPainter {
  final bool isDark;

  const _GlassRefractiveRimPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = (w / 2) - 1.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 1. Secondary softer caustic glow near the bottom-right (internal light focus)
    final causticCenter = Offset(w * 0.65, h * 0.68);
    final causticRadius = radius * 0.55;
    final causticPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          (isDark ? const Color(0xFFFFB4AB) : const Color(0xFFFFDAD6))
              .withValues(alpha: isDark ? 0.32 : 0.44),
          const Color(0xFFE8DEF8).withValues(alpha: isDark ? 0.18 : 0.28),
          const Color(0xFFD3E4FF).withValues(alpha: isDark ? 0.10 : 0.16),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 0.75, 1.0],
      ).createShader(
        Rect.fromCircle(center: causticCenter, radius: causticRadius),
      );
    canvas.drawCircle(causticCenter, causticRadius, causticPaint);

    // 2. High-contrast glossy crescent reflection sheen near top-left
    // (Apple curved glass lens sheen reflection)
    canvas.save();
    canvas.translate(w * 0.34, h * 0.30);
    canvas.rotate(-math.pi / 7.0);

    final sheenWidth = w * 0.44;
    final sheenHeight = h * 0.22;
    final sheenRect = Rect.fromCenter(
      center: Offset.zero,
      width: sheenWidth,
      height: sheenHeight,
    );

    final sheenPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: isDark ? 0.65 : 0.85),
          Colors.white.withValues(alpha: isDark ? 0.28 : 0.45),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.50, 1.0],
      ).createShader(sheenRect);

    canvas.drawOval(sheenRect, sheenPaint);

    // Pin-point primary specular glint hotspot inside the sheen
    final glintPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: isDark ? 0.90 : 0.98),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(-sheenWidth * 0.18, -sheenHeight * 0.15),
          radius: w * 0.07,
        ),
      );
    canvas.drawCircle(
      Offset(-sheenWidth * 0.18, -sheenHeight * 0.15),
      w * 0.07,
      glintPaint,
    );

    canvas.restore();

    // 3. Inner refraction bevel ring (optical thickness of lens edge)
    final innerBevelRadius = radius - 3.2;
    final innerBevelPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = SweepGradient(
        center: FractionalOffset.center,
        startAngle: -math.pi * 0.9,
        endAngle: math.pi * 1.1,
        colors: [
          Colors.white.withValues(alpha: isDark ? 0.40 : 0.60),
          Colors.transparent,
          const Color(0xFFD3E4FF).withValues(alpha: isDark ? 0.25 : 0.40),
          Colors.transparent,
          Colors.white.withValues(alpha: isDark ? 0.40 : 0.60),
        ],
        stops: const [0.0, 0.35, 0.65, 0.85, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: innerBevelRadius));
    canvas.drawCircle(center, innerBevelRadius, innerBevelPaint);

    // 4. Refractive glass border highlight (outer perimeter rim)
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: isDark ? 0.75 : 0.90),
          Colors.white.withValues(alpha: isDark ? 0.22 : 0.38),
          const Color(0xFFE8DEF8).withValues(alpha: isDark ? 0.30 : 0.45),
          Colors.white.withValues(alpha: isDark ? 0.45 : 0.65),
        ],
        stops: const [0.0, 0.40, 0.70, 1.0],
      ).createShader(rect);
    canvas.drawCircle(center, radius, rimPaint);

    // 5. Crisp top-left specular rim / Fresnel arc
    final specularArcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        center: FractionalOffset.center,
        startAngle: -math.pi * 0.90,
        endAngle: -math.pi * 0.10,
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: isDark ? 0.75 : 0.92),
          Colors.transparent,
        ],
        stops: const [0.0, 0.50, 1.0],
      ).createShader(rect);

    canvas.drawArc(
      rect.deflate(1.2),
      -math.pi * 0.90,
      math.pi * 0.80,
      false,
      specularArcPaint,
    );

    // 6. Chromatic / coral-cyan refraction along the bottom-right rim
    final chromaticArcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        center: FractionalOffset.center,
        startAngle: math.pi * 0.14,
        endAngle: math.pi * 0.70,
        colors: [
          Colors.transparent,
          const Color(0xFF80D8FF).withValues(alpha: isDark ? 0.45 : 0.60),
          const Color(0xFFFFB4AB).withValues(alpha: isDark ? 0.50 : 0.65),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.70, 1.0],
      ).createShader(rect);

    canvas.drawArc(
      rect.deflate(1.2),
      math.pi * 0.14,
      math.pi * 0.56,
      false,
      chromaticArcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GlassRefractiveRimPainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}
