import 'package:flutter/material.dart';
import '../theme/amodoro_theme.dart';

class AmodoroPressableButton extends StatefulWidget {
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color color;
  final Color? lipColor;
  final Color? borderColor;
  final double borderWidth;
  final double radius;
  final double lipHeight;
  final EdgeInsetsGeometry? padding;
  final double? height;
  final double? width;
  final BoxConstraints? constraints;
  final AlignmentGeometry alignment;
  final Widget child;

  const AmodoroPressableButton({
    super.key,
    required this.onTap,
    this.onLongPress,
    required this.color,
    this.lipColor,
    this.borderColor,
    this.borderWidth = 0.0,
    this.radius = 999.0,
    this.lipHeight = 3.2,
    this.padding,
    this.height,
    this.width,
    this.constraints,
    this.alignment = Alignment.center,
    required this.child,
  });

  @override
  State<AmodoroPressableButton> createState() => _AmodoroPressableButtonState();
}

class _AmodoroPressableButtonState extends State<AmodoroPressableButton> {
  bool _isPressed = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _handleTapDown(TapDownDetails _) {
    if (!_enabled) return;
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    if (!_enabled) return;
    setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    if (!_enabled) return;
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final resolvedLipColor =
        widget.lipColor ?? AmodoroTheme.darkenForPerspective(widget.color, 0.16);
    final effectiveLip = _isPressed ? 0.0 : widget.lipHeight;
    final yOffset = _isPressed ? widget.lipHeight : 0.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _enabled ? _handleTapDown : null,
      onTapUp: _enabled ? _handleTapUp : null,
      onTapCancel: _enabled ? _handleTapCancel : null,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 75),
        curve: Curves.easeOut,
        height: widget.height,
        width: widget.width,
        constraints: widget.constraints,
        padding: widget.padding,
        alignment: widget.alignment,
        transform: Matrix4.translationValues(0.0, yOffset, 0.0),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(widget.radius),
          border: widget.borderColor != null && widget.borderWidth > 0
              ? Border.all(
                  color: widget.borderColor!,
                  width: widget.borderWidth,
                )
              : null,
          boxShadow: effectiveLip > 0
              ? [
                  BoxShadow(
                    color: resolvedLipColor,
                    offset: Offset(0.0, effectiveLip),
                    blurRadius: 0.0,
                    spreadRadius: 0.0,
                  ),
                ]
              : const [],
        ),
        child: widget.child,
      ),
    );
  }
}
