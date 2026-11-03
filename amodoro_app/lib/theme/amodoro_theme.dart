import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';

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

class AmodoroTheme {
  // --- Neo-Pastel Palette (v1.5 Mockup) ---
  static const Color lightBackground = Color(0xFFFAF8F5);
  static const Color lightContainer = Color(0xFFF6EFE6);
  static const Color lightInk = Color(0xFF473A3A);
  static const Color lightMuted = Color(0xFF9B8E8E);

  static const Color darkBackground = Color(0xFF171515);
  static const Color darkContainer = Color(0xFF242020);
  static const Color darkInk = Color(0xFFF7F3EE);
  static const Color darkMuted = Color(0xFFA89C9C);

  // --- Píldora Salmón / Coral Uniforme ---
  static const Color coralPillLight = Color(0xFFF27166);
  static const Color coralPillBorderLight = Color(0xFFD6574D);
  static const Color coralPillTextLight = Colors.white;

  static const Color coralPillDark = Color(0xFFE06358);
  static const Color coralPillBorderDark = Color(0xFFA83E35);
  static const Color coralPillTextDark = Colors.white;

  static const List<String> _googleSansFallback = [
    'Google Sans',
    'Product Sans',
    'sans-serif',
  ];

  /// Devuelve el color de texto para cualquier elemento con fondo Coral.
  static Color coralText(bool isDark) => Colors.white;

  /// Estilo de texto Google Sans / Plus Jakarta Sans Bold para elementos activos.
  static TextStyle activeElementTextStyle({
    required double fontSize,
    required Color color,
    double letterSpacing = 0.9,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: color,
      letterSpacing: letterSpacing,
    ).copyWith(
      fontFamilyFallback: _googleSansFallback,
    );
  }

  /// Estilo base Google Sans / Plus Jakarta Sans con fallback.
  static TextStyle googleSans({
    double? fontSize,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    ).copyWith(
      fontFamilyFallback: _googleSansFallback,
    );
  }

  // --- 8 Colores Pastel para Tarjetas de HOME ---
  static const List<PastelPreset> pastelPresets = [
    PastelPreset(
      id: 'mint',
      name: 'Menta',
      hex: '#C8E7D1',
      color: Color(0xFFC8E7D1),
    ),
    PastelPreset(
      id: 'coral',
      name: 'Coral',
      hex: '#FFDAD6',
      color: Color(0xFFFFDAD6),
    ),
    PastelPreset(
      id: 'lavender',
      name: 'Lavanda',
      hex: '#EADCF8',
      color: Color(0xFFEADCF8),
    ),
    PastelPreset(
      id: 'sky',
      name: 'Cielo',
      hex: '#D4EBFA',
      color: Color(0xFFD4EBFA),
    ),
    PastelPreset(
      id: 'peach',
      name: 'Miel',
      hex: '#FFF5DC',
      color: Color(0xFFFFF5DC),
    ),
    PastelPreset(
      id: 'sage',
      name: 'Salvia',
      hex: '#C8E6C9',
      color: Color(0xFFC8E6C9),
    ),
    PastelPreset(
      id: 'rose',
      name: 'Rosa',
      hex: '#FFD8E4',
      color: Color(0xFFFFD8E4),
    ),
    PastelPreset(
      id: 'sand',
      name: 'Arena',
      hex: '#E6E1D6',
      color: Color(0xFFE6E1D6),
    ),
  ];

  // --- 8 Colores Vibrantes para Tableros y Categorías (Mockup BOARDS) ---
  static const List<PastelPreset> vibrantBoardPresets = [
    PastelPreset(
      id: 'salmon',
      name: 'Salmón',
      hex: '#F27166',
      color: Color(0xFFF27166),
    ),
    PastelPreset(
      id: 'purple',
      name: 'Púrpura',
      hex: '#A855F7',
      color: Color(0xFFA855F7),
    ),
    PastelPreset(
      id: 'amber',
      name: 'Ámbar',
      hex: '#F97316',
      color: Color(0xFF397316 + 0x00C00000), // #F97316
    ),
    PastelPreset(
      id: 'blue',
      name: 'Azul',
      hex: '#3B82F6',
      color: Color(0xFF3B82F6),
    ),
    PastelPreset(
      id: 'emerald',
      name: 'Esmeralda',
      hex: '#10B981',
      color: Color(0xFF10B981),
    ),
    PastelPreset(
      id: 'pink',
      name: 'Rosa',
      hex: '#EC4899',
      color: Color(0xFFEC4899),
    ),
    PastelPreset(
      id: 'indigo',
      name: 'Índigo',
      hex: '#6366F1',
      color: Color(0xFF6366F1),
    ),
    PastelPreset(
      id: 'teal',
      name: 'Turquesa',
      hex: '#14B8A6',
      color: Color(0xFF14B8A6),
    ),
  ];

  static const List<PastelPreset> boardColorPresets = vibrantBoardPresets;

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

  /// Oscurece un color para generar su borde físico en perspectiva inferior.
  static Color darkenForPerspective(Color base, [double amount = 0.16]) {
    final hsl = HSLColor.fromColor(base);
    final darkerLightness = (hsl.lightness - amount).clamp(0.06, 0.92);
    final boostedSat = (hsl.saturation + 0.08).clamp(0.0, 1.0);
    return hsl
        .withLightness(darkerLightness)
        .withSaturation(boostedSat)
        .toColor();
  }

  /// Decoración flotante en perspectiva (SOLO borde inferior Offset(0, thickness)):
  /// - Usada para botones, píldoras interactivas y selectores con perspectiva física inferior.
  static BoxDecoration floatingPerspectiveBox({
    required Color color,
    double radius = 22,
    double thickness = 3.0,
    Color? perspectiveEdgeColor,
    Color? fullBorderColor,
    double fullBorderWidth = 1.5,
  }) {
    final edge = perspectiveEdgeColor ?? darkenForPerspective(color, 0.16);
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: fullBorderColor != null
          ? Border.all(color: fullBorderColor, width: fullBorderWidth)
          : null,
      boxShadow: thickness > 0
          ? [
              BoxShadow(
                color: edge,
                offset: Offset(0, thickness),
                blurRadius: 0,
                spreadRadius: 0,
              ),
            ]
          : const [],
    );
  }

  /// Decoración para tarjetas y contenedores NO interactivos (HOME, ENVIADOS, HISTORIAL, BOARDS items, inputs, modales):
  /// - Usa únicamente borde completo uniforme (`Border.all`) sin labio inferior duro.
  static BoxDecoration cardOutlineBox({
    required Color color,
    double radius = 28,
    Color? borderColor,
    double borderWidth = 3.0,
    bool subtleShadow = true,
  }) {
    final resolvedBorder = borderColor ?? darkenForPerspective(color, 0.10);
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: resolvedBorder, width: borderWidth),
      boxShadow: subtleShadow
          ? const [
              BoxShadow(
                color: Color(0x0A000000),
                offset: Offset(0, 4),
                blurRadius: 12,
              ),
            ]
          : const [],
    );
  }

  /// Decoración para las píldoras de tableros (`PENDIENTES`, `MÚSICA`, `PELIS`, `SERIES`, `JUEGOS`) según el mockup.
  static BoxDecoration boardPillDecoration({
    required Color boardColor,
    required bool isSelected,
    required bool isDark,
  }) {
    if (isSelected) {
      return BoxDecoration(
        color: boardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: darkenForPerspective(boardColor, 0.18),
            offset: const Offset(0, 3.5),
            blurRadius: 0,
          ),
        ],
      );
    }
    return BoxDecoration(
      color: isDark ? darkContainer : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: boardColor, width: 2.0),
      boxShadow: [
        BoxShadow(
          color: boardColor,
          offset: const Offset(0, 3.0),
          blurRadius: 0,
        ),
      ],
    );
  }

  static Color getContrastingInk(Color bg) {
    return bg.computeLuminance() > 0.36
        ? lightInk
        : const Color(0xFFFDF8F5);
  }

  static Color getContrastingMutedInk(Color bg) {
    return bg.computeLuminance() > 0.36
        ? const Color(0xFF6B5B5B)
        : const Color(0xFFE5DDD5);
  }

  /// Icono de Material Design 3 con weight 300 para claridad WCAG AA y fidelidad al mockup.
  static Widget sysIcon(
    IconData iconData, {
    double size = 20,
    Color? color,
  }) {
    return Icon(
      iconData,
      size: size,
      color: color,
      weight: 300,
      grade: 0,
      opticalSize: 24,
    );
  }

  /// Mapea el nombre de icono de un tablero a un icono Material Symbols.
  static IconData boardIconFromName(String iconName, String slug) {
    final key = iconName.toLowerCase().trim();
    if (slug == 'actividades' || key == 'schedule' || key == 'clock') {
      return Symbols.schedule;
    }
    if (slug == 'musica' || key == 'album' || key == 'disc' || key == 'music') {
      return Symbols.album;
    }
    if (slug == 'pelis' || key == 'movie' || key == 'film') {
      return Symbols.movie;
    }
    if (slug == 'series' || key == 'tv') {
      return Symbols.tv;
    }
    if (slug == 'juegos' || key == 'sports_esports' || key == 'gamepad') {
      return Symbols.sports_esports;
    }
    switch (key) {
      case 'favorite':
      case 'heart':
        return Symbols.favorite;
      case 'restaurant':
      case 'food':
        return Symbols.restaurant;
      case 'flight':
      case 'travel':
        return Symbols.flight;
      case 'menu_book':
      case 'book':
        return Symbols.menu_book;
      case 'palette':
        return Symbols.palette;
      default:
        return Symbols.bookmark;
    }
  }

  /// Estilo del logo "amodoro" en fuente caligráfica Playwrite NL Regular en color Coral.
  static TextStyle logoStyle({
    double fontSize = 38,
    bool isDark = false,
  }) {
    final color = isDark ? coralPillDark : coralPillLight;
    return GoogleFonts.playwriteNl(
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      color: color,
      height: 1.2,
    );
  }

  /// Estilo para el texto de las tarjetas de HOME (soporta px exactos y familia).
  static TextStyle getCardTextStyle({
    required String fontFamily,
    required Color color,
    int fontSizePx = 18,
    String fontSizeKey = 'md',
  }) {
    final double px = fontSizePx > 0
        ? fontSizePx.toDouble()
        : (fontSizeKey == 'sm'
            ? 14.0
            : fontSizeKey == 'lg'
                ? 22.0
                : fontSizeKey == 'xl'
                    ? 28.0
                    : 18.0);

    switch (fontFamily.toLowerCase().trim()) {
      case 'serif':
        return GoogleFonts.playfairDisplay(
          fontSize: px,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1.36,
        );
      case 'mono':
        return GoogleFonts.spaceMono(
          fontSize: px,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1.36,
        );
      case 'hand':
        return GoogleFonts.caveat(
          fontSize: (px + 6).clamp(18.0, 38.0),
          fontWeight: FontWeight.w700,
          color: color,
          height: 1.2,
        );
      case 'sans':
      default:
        return GoogleFonts.plusJakartaSans(
          fontSize: px,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1.36,
        ).copyWith(
          fontFamilyFallback: _googleSansFallback,
        );
    }
  }

  static TextTheme _buildGoogleSansTextTheme(Color inkColor) {
    final base = GoogleFonts.plusJakartaSansTextTheme();
    TextStyle gs(FontWeight weight, {double? letterSpacing}) {
      return GoogleFonts.plusJakartaSans(
        fontWeight: weight,
        color: inkColor,
        letterSpacing: letterSpacing,
      ).copyWith(
        fontFamilyFallback: _googleSansFallback,
      );
    }

    return base.copyWith(
      displayLarge: gs(FontWeight.w800),
      displayMedium: gs(FontWeight.w800),
      displaySmall: gs(FontWeight.w800),
      headlineLarge: gs(FontWeight.w800),
      headlineMedium: gs(FontWeight.w800),
      headlineSmall: gs(FontWeight.w800),
      titleLarge: gs(FontWeight.w700),
      titleMedium: gs(FontWeight.w700),
      titleSmall: gs(FontWeight.w700),
      bodyLarge: gs(FontWeight.w600),
      bodyMedium: gs(FontWeight.w600),
      bodySmall: gs(FontWeight.w600),
      labelLarge: gs(FontWeight.w700, letterSpacing: 0.9),
      labelMedium: gs(FontWeight.w700),
      labelSmall: gs(FontWeight.w700),
    );
  }

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
      outline: Color(0xFFE9E4DC),
      outlineVariant: Color(0xFFF0ECE4),
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
      textTheme: _buildGoogleSansTextTheme(lightInk),
      iconTheme: const IconThemeData(
        color: lightInk,
        weight: 300,
        opticalSize: 24,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: lightBackground,
        foregroundColor: lightInk,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: googleSans(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: lightInk,
        ),
      ),
    );
  }

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
      outline: Color(0xFF383232),
      outlineVariant: Color(0xFF2D2828),
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
      textTheme: _buildGoogleSansTextTheme(darkInk),
      iconTheme: const IconThemeData(
        color: darkInk,
        weight: 300,
        opticalSize: 24,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: darkInk,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: googleSans(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: darkInk,
        ),
      ),
    );
  }
}
