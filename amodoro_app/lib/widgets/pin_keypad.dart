import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/amodoro_theme.dart';
import 'pressable_button.dart';

class PinKeypadWidget extends StatefulWidget {
  final ValueChanged<String> onPinCompleted;
  final String? subtitle;
  final String? errorText;
  final bool busy;
  final VoidCallback? onForgotPin;

  const PinKeypadWidget({
    super.key,
    required this.onPinCompleted,
    this.subtitle,
    this.errorText,
    this.busy = false,
    this.onForgotPin,
  });

  @override
  State<PinKeypadWidget> createState() => PinKeypadWidgetState();
}

class PinKeypadWidgetState extends State<PinKeypadWidget> {
  String _pin = '';

  void clear() {
    if (!mounted) return;
    setState(() {
      _pin = '';
    });
  }

  @override
  void didUpdateWidget(covariant PinKeypadWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorText != null &&
        widget.errorText!.isNotEmpty &&
        widget.errorText != oldWidget.errorText) {
      _pin = '';
    }
  }

  void _onDigitPressed(String digit) {
    if (widget.busy || _pin.length >= 4) return;
    final nextPin = '$_pin$digit';
    setState(() {
      _pin = nextPin;
    });
    if (nextPin.length == 4) {
      widget.onPinCompleted(nextPin);
    }
  }

  void _onBackspacePressed() {
    if (widget.busy || _pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  Widget _buildDigitKey({
    required String digit,
    required bool isDark,
  }) {
    final keyColor = isDark ? AmodoroTheme.darkContainer : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF383232) : const Color(0xFFE9E4DC);
    final lipColor =
        isDark ? const Color(0xFF100E0E) : const Color(0xFFDFD8CE);
    final inkColor = isDark ? AmodoroTheme.darkInk : AmodoroTheme.lightInk;

    return Expanded(
      child: AmodoroPressableButton(
        onTap: widget.busy ? null : () => _onDigitPressed(digit),
        color: keyColor,
        borderColor: borderColor,
        borderWidth: 1.5,
        lipColor: lipColor,
        lipHeight: 3.0,
        radius: 20,
        height: 54,
        child: Text(
          digit,
          style: AmodoroTheme.googleSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: inkColor,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeDotColor =
        isDark ? AmodoroTheme.coralPillDark : AmodoroTheme.coralPillLight;
    final emptyDotBorder =
        isDark ? const Color(0xFF524949) : const Color(0xFFD2C8BE);
    final keyColor = isDark ? AmodoroTheme.darkContainer : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF383232) : const Color(0xFFE9E4DC);
    final lipColor =
        isDark ? const Color(0xFF100E0E) : const Color(0xFFDFD8CE);
    final inkColor = isDark ? AmodoroTheme.darkInk : AmodoroTheme.lightInk;
    final mutedColor =
        isDark ? AmodoroTheme.darkMuted : AmodoroTheme.lightMuted;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 310),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
            Text(
              widget.subtitle!.toUpperCase(),
              textAlign: TextAlign.center,
              style: AmodoroTheme.googleSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: mutedColor,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 4 PIN Indicator Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final isFilled = index < _pin.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.symmetric(horizontal: 9),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: isFilled ? activeDotColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isFilled ? activeDotColor : emptyDotBorder,
                    width: 2.0,
                  ),
                ),
              );
            }),
          ),

          if (widget.errorText != null && widget.errorText!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              widget.errorText!,
              textAlign: TextAlign.center,
              style: AmodoroTheme.googleSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: activeDotColor,
              ),
            ),
          ] else
            const SizedBox(height: 20),

          if (widget.errorText != null && widget.errorText!.isNotEmpty)
            const SizedBox(height: 12),

          // Row 1: 1 2 3
          Row(
            children: [
              _buildDigitKey(digit: '1', isDark: isDark),
              const SizedBox(width: 12),
              _buildDigitKey(digit: '2', isDark: isDark),
              const SizedBox(width: 12),
              _buildDigitKey(digit: '3', isDark: isDark),
            ],
          ),
          const SizedBox(height: 12),

          // Row 2: 4 5 6
          Row(
            children: [
              _buildDigitKey(digit: '4', isDark: isDark),
              const SizedBox(width: 12),
              _buildDigitKey(digit: '5', isDark: isDark),
              const SizedBox(width: 12),
              _buildDigitKey(digit: '6', isDark: isDark),
            ],
          ),
          const SizedBox(height: 12),

          // Row 3: 7 8 9
          Row(
            children: [
              _buildDigitKey(digit: '7', isDark: isDark),
              const SizedBox(width: 12),
              _buildDigitKey(digit: '8', isDark: isDark),
              const SizedBox(width: 12),
              _buildDigitKey(digit: '9', isDark: isDark),
            ],
          ),
          const SizedBox(height: 12),

          // Row 4: [OLVIDÉ PIN] | 0 | [Backspace]
          Row(
            children: [
              Expanded(
                child: widget.onForgotPin != null
                    ? AmodoroPressableButton(
                        onTap: widget.busy ? null : widget.onForgotPin,
                        color: keyColor,
                        borderColor: borderColor,
                        borderWidth: 1.5,
                        lipColor: lipColor,
                        lipHeight: 3.0,
                        radius: 20,
                        height: 54,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'OLVIDÉ\nPIN',
                          textAlign: TextAlign.center,
                          style: AmodoroTheme.googleSans(
                            fontSize: 10.0,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            height: 1.15,
                            color: mutedColor,
                          ),
                        ),
                      )
                    : const SizedBox(height: 54),
              ),
              const SizedBox(width: 12),
              _buildDigitKey(digit: '0', isDark: isDark),
              const SizedBox(width: 12),
              Expanded(
                child: AmodoroPressableButton(
                  onTap: widget.busy ? null : _onBackspacePressed,
                  onLongPress: widget.busy ? null : clear,
                  color: keyColor,
                  borderColor: borderColor,
                  borderWidth: 1.5,
                  lipColor: lipColor,
                  lipHeight: 3.0,
                  radius: 20,
                  height: 54,
                  child: AmodoroTheme.sysIcon(
                    Symbols.backspace,
                    size: 22,
                    color: inkColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
