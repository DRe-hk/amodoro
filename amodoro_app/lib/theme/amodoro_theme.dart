import 'package:flutter/material.dart';

/// Preset de color pastel cálido de Material Design 3 para tarjetas y tableros.
class PastelPreset {
  final String id;
  final String name;
  final String hex;
  final Color color;

  const PastelPreset({
    required this.id,
    required this.name,
    required this.hex,
    required this.color,
  });
}

/// Sistema de diseño Material Design 3 de Amodoro ("Higuera y Salvia").
class AmodoroTheme {
  // --- Colores Fundacionales Light Mode ---
  static const Color lightBackground = Color(0xFFFCF9F5);
  static const Color lightContainer = Color(0xFFF4EFE8);
  static const Color lightInk = Color(0xFF1F1B18);
  static const Color lightMuted = Color(0xFF6E655E);

  // --- Colores Fundacionales Dark Mode ---
  static const Color darkBackground = Color(0xFF151816);
  static const Color darkContainer = Color(0xFF1F2421);
  static const Color darkInk = Color(0xFFF2EDE7);
  static const Color darkMuted = Color(0xFFA59E96);

  // --- Uniform Coral Active Indicator Pill ---
  static const Color coralPillLight = Color(0xFFF08076);
  static const Color coralPillTextLight = Color(0xFF3B0D09);
  static const Color coralPillDark = Color(0xFFD96B62);
  static const Color coralPillTextDark = Color(0xFFFFF5F4);

  // --- 8 M3 Pastel Presets ---
  static const List<PastelPreset> pastelPresets = [
    PastelPreset(
      id: 'coral',
      name: 'Coral suave',
      hex: '#FFDAD6',
      color: Color(0xFFFFDAD6),
    ),
    PastelPreset(
      id: 'peach',
      name: 'Miel tibia',
      hex: '#F5E0B5',
      color: Color(0xFFF5E0B5),
    ),
    PastelPreset(
      id: 'lavender',
      name: 'Lavanda pálido',
      hex: '#E8DEF8',
      color: Color(0xFFE8DEF8),
    ),
    PastelPreset(
      id: 'sage',
      name: 'Salvia claro',
      hex: '#C8E6C9',
      color: Color(0xFFC8E6C9),
    ),
    PastelPreset(
      id: 'sky',
      name: 'Cielo sereno',
      hex: '#D3E4FF',
      color: Color(0xFFD3E4FF),
    ),
    PastelPreset(
      id: 'rose',
      name: 'Rosa empolvado',
      hex: '#FFD8E4',
      color: Color(0xFFFFD8E4),
    ),
    PastelPreset(
      id: 'sand',
      name: 'Arena suave',
      hex: '#E6E1D6',
      color: Color(0xFFE6E1D6),
    ),
    PastelPreset(
      id: 'mint',
      name: 'Menta pastel',
      hex: '#C4EED0',
      color: Color(0xFFC4EED0),
    ),
  ];

  /// Parsea una cadena hexadecimal (#RRGGBB o #AARRGGBB) a un objeto [Color].
  static Color parseHexColor(
    String hex, {
    Color fallback = const Color(0xFFFFDAD6),
  }) {
    String cleanHex = hex.trim().replaceFirst('#', '');
    if (cleanHex.length == 6) {
      cleanHex = 'FF$cleanHex';
    }
    if (cleanHex.length != 8) {
      return fallback;
    }
    final int? value = int.tryParse(cleanHex, radix: 16);
    if (value == null) {
      return fallback;
    }
    return Color(value);
  }

  /// Retorna tinta de alto contraste según la luminancia del fondo:
  /// `Color(0xFF1F1B18)` si bg.computeLuminance() > 0.36 sino `Color(0xFFFDF8F5)`.
  static Color getContrastingInk(Color bg) {
    return bg.computeLuminance() > 0.36
        ? const Color(0xFF1F1B18)
        : const Color(0xFFFDF8F5);
  }

  /// Retorna tinta atenuada/muted con contraste adecuado:
  /// `Color(0xFF4E453E)` si bg.computeLuminance() > 0.36 sino `Color(0xFFE5DDD5)`.
  static Color getContrastingMutedInk(Color bg) {
    return bg.computeLuminance() > 0.36
        ? const Color(0xFF4E453E)
        : const Color(0xFFE5DDD5);
  }

  /// Mapea claves de tamaño ('sm', 'md', 'lg', 'xl') a píxeles.
  static double getFontSizePx(String sizeKey) {
    switch (sizeKey.toLowerCase().trim()) {
      case 'sm':
        return 15.0;
      case 'md':
        return 18.0;
      case 'lg':
        return 22.0;
      case 'xl':
        return 26.0;
      default:
        return 18.0;
    }
  }

  /// Retorna el [TextStyle] adecuado para las tarjetas según la familia tipográfica,
  /// el tamaño y el color especificado.
  /// - 'serif' -> Georgia / serif
  /// - 'mono' -> monospace
  /// - 'hand' -> cursiva manuscrita en itálica
  /// - 'sans' -> sans-serif por defecto
  static TextStyle getCardTextStyle({
    required String fontFamily,
    required String fontSize,
    required Color color,
  }) {
    final double sizePx = getFontSizePx(fontSize);
    switch (fontFamily.toLowerCase().trim()) {
      case 'serif':
        return TextStyle(
          fontFamily: 'Georgia',
          fontFamilyFallback: const ['serif'],
          fontSize: sizePx,
          color: color,
          height: 1.35,
        );
      case 'mono':
        return TextStyle(
          fontFamily: 'monospace',
          fontFamilyFallback: const ['Courier', 'Courier New'],
          fontSize: sizePx,
          color: color,
          height: 1.35,
        );
      case 'hand':
        return TextStyle(
          fontFamily: 'cursive',
          fontStyle: FontStyle.italic,
          fontSize: sizePx,
          color: color,
          height: 1.35,
        );
      case 'sans':
      default:
        return TextStyle(
          fontSize: sizePx,
          color: color,
          height: 1.35,
        );
    }
  }

  /// Configuración Material 3 para el tema claro ("Higuera y Salvia").
  static ThemeData lightTheme() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: coralPillLight,
      onPrimary: coralPillTextLight,
      secondary: lightMuted,
      onSecondary: lightBackground,
      surface: lightBackground,
      onSurface: lightInk,
      surfaceContainer: lightContainer,
      surfaceContainerHighest: lightContainer,
      onSurfaceVariant: lightMuted,
      outline: Color(0xFFD6CEC5),
      outlineVariant: Color(0xFFE8E2D9),
      error: Color(0xFFBA1A1A),
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: lightBackground,
      canvasColor: lightBackground,
      cardColor: lightContainer,
      dividerColor: const Color(0xFFE8E2D9),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        foregroundColor: lightInk,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: lightContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE8E2D9), width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD6CEC5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE8E2D9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: coralPillLight, width: 2),
        ),
      ),
    );
  }

  /// Configuración Material 3 para el tema oscuro ("Higuera y Salvia").
  static ThemeData darkTheme() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: coralPillDark,
      onPrimary: coralPillTextDark,
      secondary: darkMuted,
      onSecondary: darkBackground,
      surface: darkBackground,
      onSurface: darkInk,
      surfaceContainer: darkContainer,
      surfaceContainerHighest: darkContainer,
      onSurfaceVariant: darkMuted,
      outline: Color(0xFF383E3A),
      outlineVariant: Color(0xFF282F2B),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkBackground,
      canvasColor: darkBackground,
      cardColor: darkContainer,
      dividerColor: const Color(0xFF282F2B),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: darkInk,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: darkContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF282F2B), width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF383E3A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF282F2B)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: coralPillDark, width: 2),
        ),
      ),
    );
  }
}
