import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/amodoro_theme.dart';
import 'pressable_button.dart';

class DrawingStroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  DrawingStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });
}

class DrawingCanvasController extends ChangeNotifier {
  final List<DrawingStroke> _strokes = [];
  Color _currentColor = const Color(0xFF1F1B18);
  double _currentWidth = 6.0;

  List<DrawingStroke> get strokes => _strokes;
  Color get currentColor => _currentColor;
  double get currentWidth => _currentWidth;
  bool get isEmpty => _strokes.isEmpty;

  void setColor(Color color) {
    _currentColor = color;
    notifyListeners();
  }

  void setStrokeWidth(double width) {
    _currentWidth = width;
    notifyListeners();
  }

  void startStroke(Offset point) {
    _strokes.add(
      DrawingStroke(
        points: [point],
        color: _currentColor,
        strokeWidth: _currentWidth,
      ),
    );
    notifyListeners();
  }

  void appendPoint(Offset point) {
    if (_strokes.isEmpty) return;
    _strokes.last.points.add(point);
    notifyListeners();
  }

  void undo() {
    if (_strokes.isNotEmpty) {
      _strokes.removeLast();
      notifyListeners();
    }
  }

  void clear() {
    _strokes.clear();
    notifyListeners();
  }

  Future<String?> toPngDataUrl({double width = 600, double height = 600}) async {
    if (_strokes.isEmpty) return null;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

    // Fondo crema cálido
    final bgPaint = Paint()..color = const Color(0xFFFFFDF9);
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bgPaint);

    for (final stroke in _strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.points.length == 1) {
        canvas.drawCircle(
          stroke.points.first,
          stroke.strokeWidth / 2,
          Paint()..color = stroke.color,
        );
      } else {
        final path = Path()
          ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
        for (int i = 1; i < stroke.points.length; i++) {
          path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
        }
        canvas.drawPath(path, paint);
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    final bytes = byteData.buffer.asUint8List();
    return 'data:image/png;base64,${base64Encode(bytes)}';
  }
}

class InteractiveDrawingPad extends StatelessWidget {
  final DrawingCanvasController controller;

  const InteractiveDrawingPad({super.key, required this.controller});

  static const List<Color> _palette = [
    Color(0xFF1F1B18),
    Color(0xFFD9534F),
    Color(0xFF3B7A57),
    Color(0xFF2B5B84),
    Color(0xFF8E44AD),
    Color(0xFFD9822B),
  ];

  static const List<double> _widths = [4.0, 8.0, 14.0];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ..._palette.map((c) {
                  final selected = controller.currentColor == c;
                  return AmodoroPressableButton(
                    onTap: () => controller.setColor(c),
                    color: c,
                    lipColor: AmodoroTheme.darkenForPerspective(c, 0.22),
                    lipHeight: 2.5,
                    radius: 999,
                    width: 44,
                    height: 44,
                    borderColor: selected
                        ? (isDark ? Colors.white : AmodoroTheme.lightInk)
                        : null,
                    borderWidth: selected ? 2.5 : 0.0,
                    child: selected
                        ? Icon(
                            Symbols.check,
                            size: 20,
                            color: c.computeLuminance() > 0.4
                                ? Colors.black
                                : Colors.white,
                          )
                        : const SizedBox.shrink(),
                  );
                }),
                const SizedBox(width: 4),
                ..._widths.map((w) {
                  final selected = controller.currentWidth == w;
                  return AmodoroPressableButton(
                    onTap: () => controller.setStrokeWidth(w),
                    color: selected
                        ? AmodoroTheme.coralPillLight
                        : (isDark
                            ? AmodoroTheme.darkContainer
                            : AmodoroTheme.lightContainer),
                    lipColor: selected
                        ? AmodoroTheme.coralPillBorderLight
                        : (isDark
                            ? const Color(0xFF181515)
                            : const Color(0xFFDDD5C8)),
                    lipHeight: 2.5,
                    radius: 999,
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Center(
                      child: Text(
                        '${w.toInt()}PX',
                        style: AmodoroTheme.googleSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? Colors.white
                              : (isDark ? Colors.white : AmodoroTheme.lightInk),
                        ),
                      ),
                    ),
                  );
                }),
                AmodoroPressableButton(
                  onTap: controller.strokes.isNotEmpty ? controller.undo : null,
                  color: isDark
                      ? AmodoroTheme.darkContainer
                      : AmodoroTheme.lightContainer,
                  lipColor: isDark
                      ? const Color(0xFF181515)
                      : const Color(0xFFDDD5C8),
                  lipHeight: 2.5,
                  radius: 999,
                  width: 44,
                  height: 44,
                  child: Center(
                    child: AmodoroTheme.sysIcon(
                      Symbols.undo,
                      size: 20,
                      color: controller.strokes.isNotEmpty
                          ? (isDark ? Colors.white : AmodoroTheme.lightInk)
                          : (isDark ? Colors.white38 : Colors.black26),
                    ),
                  ),
                ),
                AmodoroPressableButton(
                  onTap: controller.strokes.isNotEmpty ? controller.clear : null,
                  color: isDark
                      ? AmodoroTheme.darkContainer
                      : AmodoroTheme.lightContainer,
                  lipColor: isDark
                      ? const Color(0xFF181515)
                      : const Color(0xFFDDD5C8),
                  lipHeight: 2.5,
                  radius: 999,
                  width: 44,
                  height: 44,
                  child: Center(
                    child: AmodoroTheme.sysIcon(
                      Symbols.delete,
                      size: 20,
                      color: controller.strokes.isNotEmpty
                          ? (isDark ? Colors.white : AmodoroTheme.lightInk)
                          : (isDark ? Colors.white38 : Colors.black26),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                decoration: AmodoroTheme.cardOutlineBox(
                  color: const Color(0xFFFFFDF9),
                  radius: 28,
                  borderColor: isDark
                      ? const Color(0xFF383232)
                      : const Color(0xFFDDD5C8),
                  borderWidth: 2.5,
                  subtleShadow: false,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final scaleX = 600.0 / constraints.maxWidth;
                      final scaleY = 600.0 / constraints.maxHeight;
                      return GestureDetector(
                        onPanStart: (d) {
                          controller.startStroke(
                            Offset(
                              d.localPosition.dx * scaleX,
                              d.localPosition.dy * scaleY,
                            ),
                          );
                        },
                        onPanUpdate: (d) {
                          controller.appendPoint(
                            Offset(
                              d.localPosition.dx * scaleX,
                              d.localPosition.dy * scaleY,
                            ),
                          );
                        },
                        child: CustomPaint(
                          size: Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          ),
                          painter: _StrokePainter(
                            strokes: controller.strokes,
                            scaleX: scaleX,
                            scaleY: scaleY,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StrokePainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final double scaleX;
  final double scaleY;

  _StrokePainter({
    required this.strokes,
    required this.scaleX,
    required this.scaleY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth / ((scaleX + scaleY) / 2.0)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.points.length == 1) {
        final pt = Offset(
          stroke.points.first.dx / scaleX,
          stroke.points.first.dy / scaleY,
        );
        canvas.drawCircle(
          pt,
          paint.strokeWidth / 2,
          Paint()..color = stroke.color,
        );
      } else {
        final path = Path()
          ..moveTo(
            stroke.points.first.dx / scaleX,
            stroke.points.first.dy / scaleY,
          );
        for (int i = 1; i < stroke.points.length; i++) {
          path.lineTo(
            stroke.points[i].dx / scaleX,
            stroke.points[i].dy / scaleY,
          );
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) => true;
}
