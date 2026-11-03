import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/amodoro_theme.dart';
import 'pressable_button.dart';

class LinkPreviewCard extends StatelessWidget {
  final String url;
  final String? title;
  final String? thumbnail;
  final String? platform;
  final Color cardBgColor;
  final VoidCallback? onRemove;
  final bool isSquare;

  const LinkPreviewCard({
    super.key,
    required this.url,
    this.title,
    this.thumbnail,
    this.platform,
    this.cardBgColor = const Color(0xFFFFDAD6),
    this.onRemove,
    this.isSquare = true,
  });

  String _detectPlatformLabel() {
    if (platform != null && platform!.trim().isNotEmpty) {
      return platform!.trim().toUpperCase();
    }
    final lower = url.toLowerCase();
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      return 'YOUTUBE';
    }
    if (lower.contains('spotify.com')) {
      return 'SPOTIFY';
    }
    if (lower.contains('instagram.com')) {
      return 'INSTAGRAM';
    }
    return 'ENLACE WEB';
  }

  IconData _platformIcon() {
    final p = _detectPlatformLabel();
    if (p.contains('YOUTUBE')) return Symbols.smart_display;
    if (p.contains('SPOTIFY')) return Symbols.album;
    if (p.contains('INSTAGRAM')) return Symbols.photo_camera;
    return Symbols.link;
  }

  Future<void> _openExternal() async {
    final raw = url.trim();
    if (raw.isEmpty) return;
    final uri = Uri.tryParse(raw.startsWith('http') ? raw : 'https://$raw');
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = Colors.white.withValues(alpha: 0.85);
    final borderColor = AmodoroTheme.darkenForPerspective(cardBgColor, 0.16);
    const ink = Color(0xFF1F1B18);
    const muted = Color(0xFF5A524C);
    final platformName = _detectPlatformLabel();
    final displayTitle =
        (title != null && title!.trim().isNotEmpty) ? title!.trim() : url;

    final content = GestureDetector(
      onTap: _openExternal,
      child: Container(
        decoration: AmodoroTheme.cardOutlineBox(
          color: cardBg,
          radius: 22,
          borderColor: borderColor,
          borderWidth: 2.0,
          subtleShadow: false,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: isSquare ? StackFit.expand : StackFit.loose,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: isSquare ? MainAxisSize.max : MainAxisSize.min,
              children: [
                if (isSquare)
                  Expanded(
                    child: (thumbnail != null && thumbnail!.trim().isNotEmpty)
                        ? Image.network(
                            thumbnail!.trim(),
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: cardBgColor.withValues(alpha: 0.45),
                              child: Center(
                                child: AmodoroTheme.sysIcon(
                                  _platformIcon(),
                                  size: 40,
                                  color: ink,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            color: cardBgColor.withValues(alpha: 0.35),
                            child: Center(
                              child: AmodoroTheme.sysIcon(
                                _platformIcon(),
                                size: 44,
                                color: ink,
                              ),
                            ),
                          ),
                  )
                else if (thumbnail != null && thumbnail!.trim().isNotEmpty)
                  SizedBox(
                    height: 135,
                    width: double.infinity,
                    child: Image.network(
                      thumbnail!.trim(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 90,
                        color: cardBgColor.withValues(alpha: 0.45),
                        child: Center(
                          child: AmodoroTheme.sysIcon(
                            _platformIcon(),
                            size: 32,
                            color: ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: AmodoroTheme.sysIcon(
                            _platformIcon(),
                            size: 18,
                            color: ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              platformName,
                              style: AmodoroTheme.googleSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: muted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              displayTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AmodoroTheme.googleSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: ink,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      AmodoroPressableButton(
                        onTap: _openExternal,
                        color: AmodoroTheme.coralPillLight,
                        lipColor: AmodoroTheme.coralPillBorderLight,
                        lipHeight: 3.0,
                        radius: 14,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ABRIR ENLACE',
                              style: AmodoroTheme.googleSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            AmodoroTheme.sysIcon(
                              Symbols.open_in_new,
                              size: 14,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (onRemove != null)
              Positioned(
                top: 8,
                right: 8,
                child: AmodoroPressableButton(
                  onTap: onRemove,
                  color: const Color(0xFFFCF9F5),
                  lipColor: const Color(0xFFDCD6CE),
                  lipHeight: 2.0,
                  radius: 99,
                  width: 32,
                  height: 32,
                  child: Center(
                    child: AmodoroTheme.sysIcon(
                      Symbols.close,
                      size: 16,
                      color: ink,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (isSquare) {
      return AspectRatio(
        aspectRatio: 1.0,
        child: content,
      );
    }
    return content;
  }
}
