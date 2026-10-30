import 'package:flutter/material.dart';
import '../theme/amodoro_theme.dart';

/// Predefined avatar configuration for flat illustrations.
class FlatAvatarOption {
  final String id;
  final String label;
  final Color background;
  final Color primary;

  const FlatAvatarOption({
    required this.id,
    required this.label,
    required this.background,
    required this.primary,
  });
}

/// Alias for [FlatAvatarOption].
typedef AvatarOption = FlatAvatarOption;

/// The 5 predefined flat animal avatars in Amodoro.
const List<FlatAvatarOption> kFlatAvatars = [
  FlatAvatarOption(
    id: 'cat',
    label: 'Gato',
    background: Color(0xFFF5E0B5),
    primary: Color(0xFF232328),
  ),
  FlatAvatarOption(
    id: 'hippo',
    label: 'Hipopótamo',
    background: Color(0xFFE8DEF8),
    primary: Color(0xFF8C7AA9),
  ),
  FlatAvatarOption(
    id: 'dog',
    label: 'Perro',
    background: Color(0xFFE6E1D6),
    primary: Color(0xFFA97852),
  ),
  FlatAvatarOption(
    id: 'rabbit',
    label: 'Conejo',
    background: Color(0xFFFFD8E4),
    primary: Color(0xFFE899AD),
  ),
  FlatAvatarOption(
    id: 'gray_kitten',
    label: 'Gatito gris',
    background: Color(0xFFD3E4FF),
    primary: Color(0xFF8D99AE),
  ),
];

/// Helper to look up a [FlatAvatarOption] by its identifier.
FlatAvatarOption flatAvatarFor(String id) {
  return kFlatAvatars.firstWhere(
    (a) => a.id == id,
    orElse: () => kFlatAvatars.first,
  );
}

/// A circular badge displaying an unmistakable flat vector animal illustration.
class FlatAvatarBadge extends StatelessWidget {
  final String avatarId;
  final double size;
  final bool showPerspectiveBorder;

  const FlatAvatarBadge({
    super.key,
    required this.avatarId,
    this.size = 48.0,
    this.showPerspectiveBorder = false,
  });

  /// The list of predefined avatar presets.
  static List<FlatAvatarOption> get presets => kFlatAvatars;

  @override
  Widget build(BuildContext context) {
    final option = flatAvatarFor(avatarId);
    final bgColor = option.background;

    final decoration = showPerspectiveBorder
        ? AmodoroTheme.floatingPerspectiveBox(
            color: bgColor,
            radius: size,
            thickness: 2.0,
          )
        : BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          );

    return Container(
      width: size,
      height: size,
      decoration: decoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size),
        child: CustomPaint(
          size: Size(size, size),
          painter: _FlatAnimalPainter(
            avatarId: option.id,
            primaryColor: option.primary,
            backgroundColor: bgColor,
          ),
        ),
      ),
    );
  }
}

/// Primary avatar widget component for [FlatAvatarBadge].
class FlatAvatar extends FlatAvatarBadge {
  const FlatAvatar({
    super.key,
    required super.avatarId,
    super.size = 48.0,
    super.showPerspectiveBorder = false,
  });
}

/// Horizontal selector row for picking one of the 5 flat avatars.
class FlatAvatarSelector extends StatelessWidget {
  final String selectedAvatarId;
  final ValueChanged<String> onSelect;
  final double avatarSize;
  final bool showLabels;

  const FlatAvatarSelector({
    super.key,
    required this.selectedAvatarId,
    required this.onSelect,
    this.avatarSize = 52.0,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14.0,
      runSpacing: 10.0,
      children: kFlatAvatars.map((option) {
        final isSelected = option.id == selectedAvatarId;

        return Semantics(
          button: true,
          label: option.label,
          selected: isSelected,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelect(option.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Active highlight ring when selected
                      if (isSelected)
                        Container(
                          width: avatarSize + 8,
                          height: avatarSize + 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AmodoroTheme.coralPillLight,
                              width: 2.0,
                            ),
                          ),
                        ),
                      FlatAvatarBadge(
                        avatarId: option.id,
                        size: avatarSize,
                        showPerspectiveBorder: isSelected,
                      ),
                    ],
                  ),
                  if (showLabels) ...[
                    const SizedBox(height: 6),
                    Text(
                      option.label,
                      style: TextStyle(
                        fontFamily: theme.textTheme.bodySmall?.fontFamily,
                        fontSize: 11.5,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? ink
                            : ink.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Custom painter rendering flat geometric vector faces for all 5 animals.
class _FlatAnimalPainter extends CustomPainter {
  final String avatarId;
  final Color primaryColor;
  final Color backgroundColor;

  const _FlatAnimalPainter({
    required this.avatarId,
    required this.primaryColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    switch (avatarId) {
      case 'hippo':
        _paintHippo(canvas, w, h);
        break;
      case 'dog':
        _paintDog(canvas, w, h);
        break;
      case 'rabbit':
        _paintRabbit(canvas, w, h);
        break;
      case 'gray_kitten':
        _paintGrayKitten(canvas, w, h);
        break;
      case 'cat':
      default:
        _paintCat(canvas, w, h);
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // 1. CAT (Gato - Black Cat!)
  // ---------------------------------------------------------------------------
  void _paintCat(Canvas canvas, double w, double h) {
    final catBlack = Paint()..color = const Color(0xFF232328);
    final innerEarPaint = Paint()..color = const Color(0xFF3A3A44);
    final muzzlePaint = Paint()..color = const Color(0xFF2D2D34);
    final amberEyePaint = Paint()..color = const Color(0xFFF5C542);
    final pupilPaint = Paint()..color = const Color(0xFF141418);
    final nosePaint = Paint()..color = const Color(0xFF4A4A57);
    final mouthStroke = Paint()
      ..color = const Color(0xFF4A4A57)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.024
      ..strokeCap = StrokeCap.round;
    final shinePaint = Paint()..color = Colors.white;

    // Ears
    final leftEar = Path()
      ..moveTo(w * 0.22, h * 0.44)
      ..lineTo(w * 0.20, h * 0.16)
      ..lineTo(w * 0.44, h * 0.30)
      ..close();
    canvas.drawPath(leftEar, catBlack);

    final leftInner = Path()
      ..moveTo(w * 0.25, h * 0.40)
      ..lineTo(w * 0.23, h * 0.22)
      ..lineTo(w * 0.39, h * 0.32)
      ..close();
    canvas.drawPath(leftInner, innerEarPaint);

    final rightEar = Path()
      ..moveTo(w * 0.56, h * 0.30)
      ..lineTo(w * 0.80, h * 0.16)
      ..lineTo(w * 0.78, h * 0.44)
      ..close();
    canvas.drawPath(rightEar, catBlack);

    final rightInner = Path()
      ..moveTo(w * 0.61, h * 0.32)
      ..lineTo(w * 0.77, h * 0.22)
      ..lineTo(w * 0.75, h * 0.40)
      ..close();
    canvas.drawPath(rightInner, innerEarPaint);

    // Head
    canvas.drawCircle(Offset(w * 0.5, h * 0.56), w * 0.33, catBlack);

    // Subtle dark muzzle patch for volumetric form
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.66),
        width: w * 0.38,
        height: h * 0.22,
      ),
      muzzlePaint,
    );

    // Expressive golden-amber cat eyes!
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.37, h * 0.53),
        width: w * 0.12,
        height: h * 0.14,
      ),
      amberEyePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.63, h * 0.53),
        width: w * 0.12,
        height: h * 0.14,
      ),
      amberEyePaint,
    );

    // Pupils (soft vertical oval for feline gaze)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.37, h * 0.53),
        width: w * 0.065,
        height: h * 0.11,
      ),
      pupilPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.63, h * 0.53),
        width: w * 0.065,
        height: h * 0.11,
      ),
      pupilPaint,
    );

    // Catchlights (sparkle)
    canvas.drawCircle(Offset(w * 0.385, h * 0.505), w * 0.020, shinePaint);
    canvas.drawCircle(Offset(w * 0.355, h * 0.550), w * 0.010, shinePaint);
    canvas.drawCircle(Offset(w * 0.645, h * 0.505), w * 0.020, shinePaint);
    canvas.drawCircle(Offset(w * 0.615, h * 0.550), w * 0.010, shinePaint);

    // Dark slate nose
    final nosePath = Path()
      ..moveTo(w * 0.46, h * 0.61)
      ..lineTo(w * 0.54, h * 0.61)
      ..lineTo(w * 0.50, h * 0.65)
      ..close();
    canvas.drawPath(nosePath, nosePaint);

    // Subtle dark muzzle line / smile
    final mouthPath = Path()
      ..moveTo(w * 0.42, h * 0.68)
      ..quadraticBezierTo(w * 0.46, h * 0.70, w * 0.50, h * 0.655)
      ..quadraticBezierTo(w * 0.54, h * 0.70, w * 0.58, h * 0.68);
    canvas.drawPath(mouthPath, mouthStroke);

    // Crisp white/light whiskers (stand out gracefully on black fur)
    final whiskerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.02
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
        Offset(w * 0.28, h * 0.63), Offset(w * 0.11, h * 0.60), whiskerPaint);
    canvas.drawLine(
        Offset(w * 0.28, h * 0.68), Offset(w * 0.11, h * 0.71), whiskerPaint);

    canvas.drawLine(
        Offset(w * 0.72, h * 0.63), Offset(w * 0.89, h * 0.60), whiskerPaint);
    canvas.drawLine(
        Offset(w * 0.72, h * 0.68), Offset(w * 0.89, h * 0.71), whiskerPaint);
  }

  // ---------------------------------------------------------------------------
  // 2. HIPPO (Hipopótamo)
  // ---------------------------------------------------------------------------
  void _paintHippo(Canvas canvas, double w, double h) {
    final primary = Paint()..color = primaryColor;
    final snoutPaint = Paint()..color = const Color(0xFF9D8BB9);
    final innerEarPaint = Paint()..color = const Color(0xFFE8B4C8);
    final darkPaint = Paint()..color = const Color(0xFF2E243A);
    final nostrilPaint = Paint()..color = const Color(0xFF4B3C61);
    final toothPaint = Paint()..color = Colors.white;
    final shinePaint = Paint()..color = Colors.white;

    // Small rounded ears
    canvas.drawCircle(Offset(w * 0.24, h * 0.32), w * 0.10, primary);
    canvas.drawCircle(Offset(w * 0.24, h * 0.32), w * 0.058, innerEarPaint);

    canvas.drawCircle(Offset(w * 0.76, h * 0.32), w * 0.10, primary);
    canvas.drawCircle(Offset(w * 0.76, h * 0.32), w * 0.058, innerEarPaint);

    // Upper head dome
    canvas.drawCircle(Offset(w * 0.5, h * 0.44), w * 0.30, primary);

    // Iconic wide hippo snout
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.68),
          width: w * 0.76,
          height: h * 0.44,
        ),
        Radius.circular(w * 0.22),
      ),
      snoutPaint,
    );

    // Nostrils
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.39, h * 0.62),
        width: w * 0.09,
        height: h * 0.07,
      ),
      nostrilPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.61, h * 0.62),
        width: w * 0.09,
        height: h * 0.07,
      ),
      nostrilPaint,
    );

    // Eyes (sitting just atop the snout)
    canvas.drawCircle(Offset(w * 0.35, h * 0.42), w * 0.045, darkPaint);
    canvas.drawCircle(Offset(w * 0.65, h * 0.42), w * 0.045, darkPaint);

    // Catchlights
    canvas.drawCircle(Offset(w * 0.365, h * 0.405), w * 0.016, shinePaint);
    canvas.drawCircle(Offset(w * 0.665, h * 0.405), w * 0.016, shinePaint);

    // Little cute teeth peeking out bottom
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.42, h * 0.86),
          width: w * 0.065,
          height: h * 0.06,
        ),
        Radius.circular(w * 0.02),
      ),
      toothPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.58, h * 0.86),
          width: w * 0.065,
          height: h * 0.06,
        ),
        Radius.circular(w * 0.02),
      ),
      toothPaint,
    );
  }

  // ---------------------------------------------------------------------------
  // 3. DOG (Perro)
  // ---------------------------------------------------------------------------
  void _paintDog(Canvas canvas, double w, double h) {
    final primary = Paint()..color = primaryColor;
    final headPaint = Paint()..color = const Color(0xFFF7F2EC);
    final muzzlePaint = Paint()..color = Colors.white;
    final darkPaint = Paint()..color = const Color(0xFF2C221D);
    final tonguePaint = Paint()..color = const Color(0xFFFF8DA1);
    final shinePaint = Paint()..color = Colors.white;

    // Floppy ears on the sides
    final leftEar = Path()
      ..moveTo(w * 0.28, h * 0.28)
      ..cubicTo(w * 0.08, h * 0.34, w * 0.08, h * 0.68, w * 0.20, h * 0.72)
      ..cubicTo(w * 0.28, h * 0.74, w * 0.32, h * 0.56, w * 0.30, h * 0.38)
      ..close();
    canvas.drawPath(leftEar, primary);

    final rightEar = Path()
      ..moveTo(w * 0.72, h * 0.28)
      ..cubicTo(w * 0.92, h * 0.34, w * 0.92, h * 0.68, w * 0.80, h * 0.72)
      ..cubicTo(w * 0.72, h * 0.74, w * 0.68, h * 0.56, w * 0.70, h * 0.38)
      ..close();
    canvas.drawPath(rightEar, primary);

    // Head base
    canvas.drawCircle(Offset(w * 0.5, h * 0.54), w * 0.33, headPaint);

    // Characteristic dog eye-patch over left eye
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.38, h * 0.48),
        width: w * 0.26,
        height: h * 0.28,
      ),
      primary,
    );

    // Muzzle
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.67),
        width: w * 0.38,
        height: h * 0.24,
      ),
      muzzlePaint,
    );

    // Tongue sticking out happily
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.76),
          width: w * 0.09,
          height: h * 0.08,
        ),
        Radius.circular(w * 0.045),
      ),
      tonguePaint,
    );

    // Broad puppy nose
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.62),
          width: w * 0.13,
          height: h * 0.09,
        ),
        Radius.circular(w * 0.04),
      ),
      darkPaint,
    );

    // Eyes
    canvas.drawCircle(Offset(w * 0.38, h * 0.48), w * 0.044, darkPaint);
    canvas.drawCircle(Offset(w * 0.62, h * 0.48), w * 0.044, darkPaint);

    // Specular shine
    canvas.drawCircle(Offset(w * 0.395, h * 0.465), w * 0.015, shinePaint);
    canvas.drawCircle(Offset(w * 0.635, h * 0.465), w * 0.015, shinePaint);
  }

  // ---------------------------------------------------------------------------
  // 4. RABBIT (Conejo)
  // ---------------------------------------------------------------------------
  void _paintRabbit(Canvas canvas, double w, double h) {
    final primary = Paint()..color = primaryColor;
    final whitePaint = Paint()..color = const Color(0xFFFFFDFC);
    final innerEarPaint = Paint()..color = const Color(0xFFFFAEC5);
    final darkPaint = Paint()..color = const Color(0xFF2B1D24);
    final nosePaint = Paint()..color = const Color(0xFFE06D8A);
    final blushPaint = Paint()..color = const Color(0x35FF7A9E);
    final shinePaint = Paint()..color = Colors.white;

    // Tall vertical bunny ears
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.36, h * 0.25),
        width: w * 0.17,
        height: h * 0.42,
      ),
      whitePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.36, h * 0.25),
        width: w * 0.09,
        height: h * 0.30,
      ),
      innerEarPaint,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.64, h * 0.25),
        width: w * 0.17,
        height: h * 0.42,
      ),
      whitePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.64, h * 0.25),
        width: w * 0.09,
        height: h * 0.30,
      ),
      innerEarPaint,
    );

    // Head
    canvas.drawCircle(Offset(w * 0.5, h * 0.60), w * 0.32, whitePaint);

    // Puffy cheeks
    canvas.drawCircle(Offset(w * 0.44, h * 0.68), w * 0.09, whitePaint);
    canvas.drawCircle(Offset(w * 0.56, h * 0.68), w * 0.09, whitePaint);

    // Large shiny eyes
    canvas.drawCircle(Offset(w * 0.35, h * 0.55), w * 0.046, darkPaint);
    canvas.drawCircle(Offset(w * 0.65, h * 0.55), w * 0.046, darkPaint);

    // Eye catchlights
    canvas.drawCircle(Offset(w * 0.365, h * 0.535), w * 0.017, shinePaint);
    canvas.drawCircle(Offset(w * 0.665, h * 0.535), w * 0.017, shinePaint);

    // Tiny heart-shaped pink nose
    final nosePath = Path()
      ..moveTo(w * 0.47, h * 0.62)
      ..lineTo(w * 0.53, h * 0.62)
      ..lineTo(w * 0.50, h * 0.66)
      ..close();
    canvas.drawPath(nosePath, nosePaint);

    // Delicate bunny smile
    final mouthStroke = Paint()
      ..color = const Color(0xFFC07086)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.02
      ..strokeCap = StrokeCap.round;

    final mouthPath = Path()
      ..moveTo(w * 0.44, h * 0.69)
      ..quadraticBezierTo(w * 0.47, h * 0.71, w * 0.50, h * 0.67)
      ..quadraticBezierTo(w * 0.53, h * 0.71, w * 0.56, h * 0.69);
    canvas.drawPath(mouthPath, mouthStroke);

    // Whiskers
    final whiskerPaint = Paint()
      ..color = primary.color.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.018
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
        Offset(w * 0.28, h * 0.65), Offset(w * 0.12, h * 0.63), whiskerPaint);
    canvas.drawLine(
        Offset(w * 0.28, h * 0.69), Offset(w * 0.12, h * 0.71), whiskerPaint);

    canvas.drawLine(
        Offset(w * 0.72, h * 0.65), Offset(w * 0.88, h * 0.63), whiskerPaint);
    canvas.drawLine(
        Offset(w * 0.72, h * 0.69), Offset(w * 0.88, h * 0.71), whiskerPaint);

    // Rosy cheeks
    canvas.drawCircle(Offset(w * 0.27, h * 0.62), w * 0.05, blushPaint);
    canvas.drawCircle(Offset(w * 0.73, h * 0.62), w * 0.05, blushPaint);
  }

  // ---------------------------------------------------------------------------
  // 5. GRAY KITTEN (Gatito gris - almost entirely monochromatic gray!)
  // ---------------------------------------------------------------------------
  void _paintGrayKitten(Canvas canvas, double w, double h) {
    final primary = Paint()..color = primaryColor;
    final darkStripe = Paint()
      ..color = const Color(0xFF5A667A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.024
      ..strokeCap = StrokeCap.round;
    // Soft monochromatic gray inner ears (not pink!)
    final innerEarPaint = Paint()..color = const Color(0xFFB0BAC7);
    // Cool pale silver-gray muzzle (tonal gray!)
    final muzzlePaint = Paint()..color = const Color(0xFFDCE2EC);
    final darkPaint = Paint()..color = const Color(0xFF1B2028);
    // Slate gray nose (not pink!)
    final grayNose = Paint()..color = const Color(0xFF6E737B);
    final mouthStroke = Paint()
      ..color = const Color(0xFF5A667A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.02
      ..strokeCap = StrokeCap.round;
    // Monochromatic subtle cool gray cheek tint
    final grayCheekPaint = Paint()
      ..color = const Color(0xFF6E737B).withValues(alpha: 0.14);
    final shinePaint = Paint()..color = Colors.white;

    // Kitten pointed ears
    final leftEar = Path()
      ..moveTo(w * 0.22, h * 0.42)
      ..lineTo(w * 0.20, h * 0.18)
      ..lineTo(w * 0.42, h * 0.32)
      ..close();
    canvas.drawPath(leftEar, primary);

    final leftInner = Path()
      ..moveTo(w * 0.25, h * 0.38)
      ..lineTo(w * 0.23, h * 0.24)
      ..lineTo(w * 0.38, h * 0.33)
      ..close();
    canvas.drawPath(leftInner, innerEarPaint);

    final rightEar = Path()
      ..moveTo(w * 0.58, h * 0.32)
      ..lineTo(w * 0.80, h * 0.18)
      ..lineTo(w * 0.78, h * 0.42)
      ..close();
    canvas.drawPath(rightEar, primary);

    final rightInner = Path()
      ..moveTo(w * 0.62, h * 0.33)
      ..lineTo(w * 0.77, h * 0.24)
      ..lineTo(w * 0.75, h * 0.38)
      ..close();
    canvas.drawPath(rightInner, innerEarPaint);

    // Baby chubby round head (wider proportions)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.58),
        width: w * 0.68,
        height: h * 0.56,
      ),
      primary,
    );

    // Tabby forehead kitten stripes in slate gray
    canvas.drawLine(
        Offset(w * 0.5, h * 0.38), Offset(w * 0.5, h * 0.45), darkStripe);
    canvas.drawLine(
        Offset(w * 0.43, h * 0.39), Offset(w * 0.44, h * 0.45), darkStripe);
    canvas.drawLine(
        Offset(w * 0.57, h * 0.39), Offset(w * 0.56, h * 0.45), darkStripe);

    // Baby muzzle patch in pale silver-gray
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.69),
        width: w * 0.32,
        height: h * 0.18,
      ),
      muzzlePaint,
    );

    // DISTINCTIVE BIG BABY KITTEN EYES (kawaii oversized proportions!)
    canvas.drawCircle(Offset(w * 0.35, h * 0.55), w * 0.064, darkPaint);
    canvas.drawCircle(Offset(w * 0.65, h * 0.55), w * 0.064, darkPaint);

    // Double anime sparkle in baby eyes
    // Left eye highlights
    canvas.drawCircle(Offset(w * 0.37, h * 0.53), w * 0.024, shinePaint);
    canvas.drawCircle(Offset(w * 0.33, h * 0.58), w * 0.012, shinePaint);

    // Right eye highlights
    canvas.drawCircle(Offset(w * 0.67, h * 0.53), w * 0.024, shinePaint);
    canvas.drawCircle(Offset(w * 0.63, h * 0.58), w * 0.012, shinePaint);

    // Tiny button nose in slate gray (almost totally gray!)
    final nosePath = Path()
      ..moveTo(w * 0.47, h * 0.65)
      ..lineTo(w * 0.53, h * 0.65)
      ..lineTo(w * 0.50, h * 0.68)
      ..close();
    canvas.drawPath(nosePath, grayNose);

    // Tiny baby 'w' smile in slate gray
    final mouthPath = Path()
      ..moveTo(w * 0.44, h * 0.71)
      ..quadraticBezierTo(w * 0.47, h * 0.73, w * 0.50, h * 0.69)
      ..quadraticBezierTo(w * 0.53, h * 0.73, w * 0.56, h * 0.71);
    canvas.drawPath(mouthPath, mouthStroke);

    // Delicate kitten whiskers in crisp soft white
    final whiskerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.018
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
        Offset(w * 0.28, h * 0.66), Offset(w * 0.12, h * 0.64), whiskerPaint);
    canvas.drawLine(
        Offset(w * 0.28, h * 0.70), Offset(w * 0.12, h * 0.72), whiskerPaint);

    canvas.drawLine(
        Offset(w * 0.72, h * 0.66), Offset(w * 0.88, h * 0.64), whiskerPaint);
    canvas.drawLine(
        Offset(w * 0.72, h * 0.70), Offset(w * 0.88, h * 0.72), whiskerPaint);

    // Subtle cool gray cheek shading (pure monochromatic)
    canvas.drawCircle(Offset(w * 0.25, h * 0.64), w * 0.05, grayCheekPaint);
    canvas.drawCircle(Offset(w * 0.75, h * 0.64), w * 0.05, grayCheekPaint);
  }

  @override
  bool shouldRepaint(covariant _FlatAnimalPainter oldDelegate) {
    return oldDelegate.avatarId != avatarId ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
