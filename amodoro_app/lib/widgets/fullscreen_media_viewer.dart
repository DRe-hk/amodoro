import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/amodoro_theme.dart';

class FullscreenMediaViewer extends StatelessWidget {
  final String imageUrl;
  final String? heroTag;

  const FullscreenMediaViewer({
    super.key,
    required this.imageUrl,
    this.heroTag,
  });

  static Future<void> open(
    BuildContext context, {
    required String imageUrl,
    String? heroTag,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.90),
        pageBuilder: (_, __, ___) => FullscreenMediaViewer(
          imageUrl: imageUrl,
          heroTag: heroTag,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Widget _buildImageContent() {
    if (imageUrl.startsWith('data:image/')) {
      final comma = imageUrl.indexOf(',');
      if (comma != -1) {
        try {
          final bytes = base64Decode(imageUrl.substring(comma + 1));
          return Image.memory(
            bytes,
            fit: BoxFit.contain,
          );
        } catch (_) {}
      }
    }
    return Image.network(
      imageUrl,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(
          child: SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AmodoroTheme.sysIcon(
                Symbols.broken_image,
                size: 44,
                color: Colors.white60,
              ),
              const SizedBox(height: 8),
              const Text(
                'No se pudo cargar la imagen',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = _buildImageContent();
    if (heroTag != null && heroTag!.isNotEmpty) {
      imageWidget = Hero(
        tag: heroTag!,
        child: imageWidget,
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Tapping the empty background dismisses
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: const SizedBox.expand(),
            ),
          ),
          Center(
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.5,
              clipBehavior: Clip.none,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {}, // Absorb taps on image so empty background dismiss is not triggered
                child: imageWidget,
              ),
            ),
          ),
          // Top-right floating close button inside SafeArea
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: AmodoroTheme.floatingPerspectiveBox(
                      color: const Color(0xFFFEFEFC),
                      radius: 999,
                      thickness: 2.2,
                    ),
                    alignment: Alignment.center,
                    child: AmodoroTheme.sysIcon(
                      Symbols.close,
                      size: 20,
                      color: const Color(0xFF1F1B18),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
