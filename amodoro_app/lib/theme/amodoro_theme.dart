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
  // --- Lienzo de Fondo (Light & Dark) ---
  static const Color lightBackground = Color(0xFFFCF9F5);
  static const Color lightContainer = Color(0xFFF4EFE8);
  static const Color lightInk = Color(0xFF1F1B18);
  static const Color lightMuted = Color(0xFF6E655E);

  static const Color darkBackground = Color(0xFF151816);
  static const Color darkContainer = Color(0xFF1F2421);
  static const Color darkInk = Color(0xFFF2EDE7);
  static const Color darkMuted = Color(0xFFA59E96);

  // --- Píldora Coral Uniforme ---
  static const Color coralPillLight = Color(0xFFF08076);
  static const Color coralPillBorderLight = Color(0xFFB54E45);
  static const Color coralPillTextLight = Color(0xFF3B0D09);

  static const Color coralPillDark = Color(0xFFD96B62);
  static const Color coralPillBorderDark = Color(0xFF8E3932);
  static const Color coralPillTextDark = Color(0xFFFFF5F4);

  // --- 8 Colores Pastel para Tarjetas y Tableros ---
  static const List<PastelPreset> pastelPresets = [
    PastelPreset(
      id: 'coral',
      name: 'Coral',
      hex: '#FFDAD6',
      color: Color(0xFFFFDAD6),
    ),
    PastelPreset(
      id: 'peach',
      name: 'Miel',
      hex: '#F5E0B5',
      color: Color(0xFFF5E0B5),
    ),
    PastelPreset(
      id: 'lavender',
      name: 'Lavanda',
      hex: '#E8DEF8',
      color: Color(0xFFE8DEF8),
    ),
    PastelPreset(
      id: 'sage',
      name: 'Salvia',
      hex: '#C8E6C9',
      color: Color(0xFFC8E6C9),
    ),
    PastelPreset(
      id: 'sky',
      name: 'Cielo',
      hex: '#D3E4FF',
      color: Color(0xFFD3E4FF),
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
    PastelPreset(
      id: 'mint',
      name: 'Menta',
      hex: '#C4EED0',
      color: Color(0xFFC4EED0),
    ),
  ];

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

  /// Oscurece un color para generar su borde físico en perspectiva (inferior y derecho).
  static Color darkenForPerspective(Color base, [double amount = 0.22]) {
    final hsl = HSLColor.fromColor(base);
    final darkerLightness = (hsl.lightness - amount).clamp(0.06, 0.92);
    final boostedSat = (hsl.saturation + 0.06).clamp(0.0, 1.0);
    return hsl
        .withLightness(darkerLightness)
        .withSaturation(boostedSat)
        .toColor();
  }

  /// Decoración flotante en perspectiva:
  /// - Sin borde superior ni izquierdo (0px).
  /// - Solo borde inferior y derecho visible de [thickness] px (por defecto 2.5px, o 2.0px en la píldora superior)
  ///   en un tono más oscuro, sin difuminado (blurRadius: 0).
  static BoxDecoration floatingPerspectiveBox({
    required Color color,
    double radius = 22,
    double thickness = 2.5,
    Color? perspectiveEdgeColor,
  }) {
    final edge = perspectiveEdgeColor ?? darkenForPerspective(color, 0.22);
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: edge,
          offset: Offset(thickness, thickness),
          blurRadius: 0,
          spreadRadius: 0,
        ),
      ],
    );
  }

  static Color getContrastingInk(Color bg) {
    return bg.computeLuminance() > 0.36
        ? const Color(0xFF1F1B18)
        : const Color(0xFFFDF8F5);
  }

  static Color getContrastingMutedInk(Color bg) {
    return bg.computeLuminance() > 0.36
        ? const Color(0xFF4E453E)
        : const Color(0xFFE5DDD5);
  }

  /// Icono de Material Design 3 con weight 100 obligatorio en toda la aplicación.
  static Widget sysIcon(
    IconData iconData, {
    double size = 20,
    Color? color,
  }) {
    return Icon(
      iconData,
      size: size,
      color: color,
      weight: 100,
      grade: 0,
      opticalSize: 24,
    );
  }

  /// Mapea el nombre de icono de un tablero a un icono Material Symbols weight 100.
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
      case 'Menu_book':
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
          fontWeight: FontWeight.w400,
          color: color,
          height: 1.38,
        );
      case 'mono':
        return GoogleFonts.spaceMono(
          fontSize: px,
          fontWeight: FontWeight.w400,
          color: color,
          height: 1.38,
        );
      case 'hand':
        return GoogleFonts.playwriteNl(
          fontSize: (px - 2).clamp(12.0, 30.0),
          fontWeight: FontWeight.w400,
          color: color,
          height: 1.45,
        );
      case 'sans':
      default:
        return GoogleFonts.raleway(
          fontSize: px,
          fontWeight: FontWeight.w300,
          color: color,
          height: 1.38,
        );
    }
  }

  static TextTheme _buildRalewayLightTextTheme(Color inkColor) {
    final base = GoogleFonts.ralewayTextTheme();
    return base.copyWith(
      displayLarge: GoogleFonts.raleway(
          fontWeight: FontWeight.w300, color: inkColor),
      displayMedium: GoogleFonts.raleway(
          fontWeight: FontWeight.w300, color: inkColor),
      displaySmall: GoogleFonts.raleway(
          fontWeight: FontWeight.w300, color: inkColor),
      headlineLarge: GoogleFonts.raleway(
          fontWeight: FontWeight.w300, color: inkColor),
      headlineMedium: GoogleFonts.raleway(
          fontWeight: FontWeight.w300, color: inkColor),
      headlineSmall: GoogleFonts.raleway(
          fontWeight: FontWeight.w300, color: inkColor),
      titleLarge: GoogleFonts.raleway(
          fontWeight: FontWeight.w300, color: inkColor),
      titleMedium: GoogleFonts.raleway(
          fontWeight: FontWeight.w300, color: inkColor),
      titleSmall: GoogleFonts.raleway(
          fontWeight: FontWeight.w300, color: inkColor),
      bodyLarge: GoogleFonts.raleway(
          fontWeight: FontWeight.w300, color: inkColor),
      bodyMedium: GoogleFonts.raleway(
          fontWeight: FontWeight.w300, color: inkColor),
      bodySmall: GoogleFonts.raleway(
          fontWeight: FontWeight.w300, color: inkColor),
      labelLarge: GoogleFonts.raleway(
          fontWeight: FontWeight.w300, color: inkColor, letterSpacing: 1.1),
      labelMedium: GoogleFonts.raleway(
          fontWeight: FontWeight.w300, color: inkColor),
      labelSmall: GoogleFonts.raleway(
          fontWeight: FontWeight.w300, color: inkColor),
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
      textTheme: _buildRalewayLightTextTheme(lightInk),
      iconTheme: const IconThemeData(
        color: lightInk,
        weight: 100,
        opticalSize: 24,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: lightBackground,
        foregroundColor: lightInk,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.raleway(
          fontSize: 17,
          fontWeight: FontWeight.w300,
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
      textTheme: _buildRalewayLightTextTheme(darkInk),
      iconTheme: const IconThemeData(
        color: darkInk,
        weight: 100,
        opticalSize: 24,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: darkInk,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.raleway(
          fontSize: 17,
          fontWeight: FontWeight.w300,
          color: darkInk,
        ),
      ),
    );
  }
}
