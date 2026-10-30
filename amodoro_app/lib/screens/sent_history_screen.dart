import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/amodoro_models.dart';
import '../services/api_client.dart';
import '../theme/amodoro_theme.dart';
import '../widgets/flat_avatar.dart';
import '../widgets/link_preview_card.dart';

class SentHistoryScreen extends StatelessWidget {
  final List<HomeCardItem> sentCards;
  final AmodoroApiClient api;

  const SentHistoryScreen({
    super.key,
    required this.sentCards,
    required this.api,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: AmodoroTheme.sysIcon(Symbols.arrow_back, size: 22),
        ),
        title: const Text(
          'ENVIADOS POR YO',
          style: TextStyle(fontSize: 14, letterSpacing: 1.5),
        ),
      ),
      body: sentCards.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aún no has enviado tarjetas.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 12, 20, 24),
              itemCount: sentCards.length,
              separatorBuilder: (_, __) => const SizedBox(height: 18),
              itemBuilder: (context, index) {
                final card = sentCards[index];
                final bg = AmodoroTheme.parseHexColor(card.bgColor);
                final ink = AmodoroTheme.getContrastingInk(bg);
                final muted = AmodoroTheme.getContrastingMutedInk(bg);

                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AmodoroTheme.floatingPerspectiveBox(
                    color: bg,
                    radius: 28,
                    thickness: 3.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              FlatAvatarBadge(
                                avatarId: card.authorAvatarId,
                                size: 26,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'YO',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  letterSpacing: 1.3,
                                  color: ink,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            card.dateHeader,
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.0,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                      if (card.mediaType == 'link' &&
                          card.linkUrl != null &&
                          card.linkUrl!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        LinkPreviewCard(
                          url: card.linkUrl!,
                          title: card.linkTitle,
                          thumbnail: card.linkThumbnail,
                          platform: card.linkPlatform,
                          cardBgColor: bg,
                        ),
                      ] else if (card.mediaType != 'none' &&
                          card.mediaUrl != null &&
                          card.mediaUrl!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: _buildCardMedia(
                            api.resolveMediaUrl(card.mediaUrl),
                          ),
                        ),
                      ],
                      if (card.textContent.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          card.textContent,
                          style: AmodoroTheme.getCardTextStyle(
                            fontFamily: card.fontFamily,
                            color: ink,
                            fontSizePx: card.fontSizePx,
                            fontSizeKey: card.fontSize,
                          ),
                        ),
                      ],
                      if (card.reactions.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: card.reactions.map((r) {
                            final text = [
                              if (r.emoji != null && r.emoji!.isNotEmpty)
                                r.emoji!,
                              if (r.presetText != null &&
                                  r.presetText!.isNotEmpty)
                                r.presetText!,
                            ].join(' ');
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: AmodoroTheme.floatingPerspectiveBox(
                                color: Colors.white.withValues(alpha: 0.48),
                                radius: 999,
                                thickness: 1.8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FlatAvatarBadge(
                                    avatarId: r.authorAvatarId,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${r.authorLabel}: $text',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF1F1B18),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildCardMedia(String url) {
    if (url.startsWith('data:image/')) {
      final comma = url.indexOf(',');
      if (comma != -1) {
        try {
          final bytes = base64Decode(url.substring(comma + 1));
          return Image.memory(
            bytes,
            height: 190,
            width: double.infinity,
            fit: BoxFit.cover,
          );
        } catch (_) {}
      }
    }
    return Image.network(
      url,
      height: 190,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}
