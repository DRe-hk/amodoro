import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/amodoro_theme.dart';

/// A dynamic Apple Glass refractive bubble background.
///
/// Smoothly animates a large organic glass bubble (260dp–320dp diameter)
/// that drifts behind the UI with optical refraction, soft warm
/// coral/peach/lavender glow gradients, ImageFilter blur (sigma 18),
/// and a refractive specular rim highlight.
class GlassBubbleBackground extends StatefulWidget {
  final Widget child;
  final bool emergeFromBottom;

  const GlassBubbleBackground({
    super.key,
    required this.child,
    this.emergeFromBottom = false,
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

                  // Organic bubble breathing diameter (260dp–320dp)
                  final bubbleDiameter = 290.0 + 25.0 * math.sin(phi);

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
                      // 1. Soft warm ambient glow aura casting light behind the glass
                      Positioned(
                        left: left - (bubbleDiameter * 0.18),
                        top: top - (bubbleDiameter * 0.18),
                        width: bubbleDiameter * 1.36,
                        height: bubbleDiameter * 1.36,
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  (isDark
                                          ? AmodoroTheme.coralPillDark
                                          : AmodoroTheme.coralPillLight)
                                      .withOpacity(isDark ? 0.22 : 0.32),
                                  const Color(0xFFF5E0B5)
                                      .withOpacity(isDark ? 0.18 : 0.26),
                                  const Color(0xFFE8DEF8)
                                      .withOpacity(isDark ? 0.20 : 0.28),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.40, 0.70, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 2. The Apple Glass bubble with optical blur & refraction
                      Positioned(
                        left: left,
                        top: top,
                        width: bubbleDiameter,
                        height: bubbleDiameter,
                        child: IgnorePointer(
                          child: ClipOval(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: 18.0,
                                sigmaY: 18.0,
                              ),
                              child: Container(
                                width: bubbleDiameter,
                                height: bubbleDiameter,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    center: const Alignment(-0.35, -0.35),
                                    radius: 0.95,
                                    colors: [
                                      Colors.white
                                          .withOpacity(isDark ? 0.22 : 0.42),
                                      const Color(0xFFFFDAD6)
                                          .withOpacity(isDark ? 0.14 : 0.24),
                                      const Color(0xFFF5E0B5)
                                          .withOpacity(isDark ? 0.10 : 0.18),
                                      const Color(0xFFE8DEF8)
                                          .withOpacity(isDark ? 0.16 : 0.26),
                                      Colors.white
                                          .withOpacity(isDark ? 0.08 : 0.14),
                                    ],
                                    stops: const [0.0, 0.35, 0.60, 0.85, 1.0],
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

/// Custom painter for the Apple Glass refractive perimeter rim and specular highlights.
class _GlassRefractiveRimPainter extends CustomPainter {
  final bool isDark;

  const _GlassRefractiveRimPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 1.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 1. Refractive glass border highlight (LinearGradient from top-left light to bottom-right rim)
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(isDark ? 0.65 : 0.80),
          Colors.white.withOpacity(isDark ? 0.20 : 0.35),
          const Color(0xFFE8DEF8).withOpacity(isDark ? 0.25 : 0.40),
          Colors.white.withOpacity(isDark ? 0.35 : 0.55),
        ],
        stops: const [0.0, 0.40, 0.70, 1.0],
      ).createShader(rect);

    canvas.drawCircle(center, radius, rimPaint);

    // 2. Primary top-left specular glint arc (simulates glass surface reflection)
    final specularPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        center: FractionalOffset.center,
        startAngle: -math.pi * 0.85,
        endAngle: -math.pi * 0.15,
        colors: [
          Colors.transparent,
          Colors.white.withOpacity(isDark ? 0.50 : 0.75),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);

    canvas.drawArc(
      rect.deflate(1.2),
      -math.pi * 0.85,
      math.pi * 0.70,
      false,
      specularPaint,
    );

    // 3. Subtle secondary Fresnel bounce highlight along bottom-right edge
    final bouncePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        center: FractionalOffset.center,
        startAngle: math.pi * 0.18,
        endAngle: math.pi * 0.65,
        colors: [
          Colors.transparent,
          const Color(0xFFE8DEF8).withOpacity(isDark ? 0.35 : 0.50),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);

    canvas.drawArc(
      rect.deflate(1.2),
      math.pi * 0.18,
      math.pi * 0.47,
      false,
      bouncePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GlassRefractiveRimPainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}
