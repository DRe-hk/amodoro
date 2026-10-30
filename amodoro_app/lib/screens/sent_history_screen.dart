import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/amodoro_models.dart';
import '../services/api_client.dart';
import '../theme/amodoro_theme.dart';

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
        title: const Text(
          '🕒 Enviados por YO',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: sentCards.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aún no has enviado tarjetas. Usa el botón + CREAR en HOME para sorprender a tu pareja.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sentCards.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final card = sentCards[index];
                final bg = AmodoroTheme.parseHexColor(card.bgColor);
                final ink = AmodoroTheme.getContrastingInk(bg);
                final muted = AmodoroTheme.getContrastingMutedInk(bg);

                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: ink.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'YO',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: ink,
                              ),
                            ),
                          ),
                          Text(
                            card.dateHeader,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                      if (card.mediaType != 'none' &&
                          card.mediaUrl != null &&
                          card.mediaUrl!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: _buildCardMedia(api.resolveMediaUrl(card.mediaUrl)),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Text(
                        card.textContent,
                        style: AmodoroTheme.getCardTextStyle(
                          fontFamily: card.fontFamily,
                          fontSize: card.fontSize,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Divider(color: ink.withValues(alpha: 0.15)),
                      const SizedBox(height: 6),
                      Text(
                        'Reacciones y respuestas recibidas:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (card.reactions.isEmpty)
                        Text(
                          'Tu pareja aún no ha reaccionado a esta tarjeta.',
                          style: TextStyle(fontSize: 12, color: muted),
                        )
                      else
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
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: ink.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${r.authorLabel}: $text',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: ink,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
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
