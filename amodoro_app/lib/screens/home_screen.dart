import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/amodoro_models.dart';
import '../services/api_client.dart';
import '../theme/amodoro_theme.dart';
import 'create_card_screen.dart';
import 'sent_history_screen.dart';

class HomeScreen extends StatelessWidget {
  final SyncPayload sync;
  final AmodoroApiClient api;
  final Future<void> Function() onRefresh;

  const HomeScreen({
    super.key,
    required this.sync,
    required this.api,
    required this.onRefresh,
  });

  static const List<String> _reactionEmojis = ['❤️', '🥰', '✨', '🔥', '😂', '🙌'];

  Future<void> _react(
    BuildContext context, {
    required String cardId,
    String? emoji,
    String? presetText,
  }) async {
    try {
      await api.reactToCard(
        cardId: cardId,
        emoji: emoji,
        presetText: presetText,
      );
      await onRefresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al reaccionar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final latest = sync.latestPartnerCard ??
        (sync.receivedHistory.isNotEmpty ? sync.receivedHistory.first : null);
    final previousCards = sync.receivedHistory.length > 1
        ? sync.receivedHistory.sublist(1)
        : const <HomeCardItem>[];
    final partnerName =
        sync.partner?.myGivenNickname ?? sync.me.partnerNicknameGiven;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              children: [
                if (latest != null) ...[
                  _buildCardBlock(context, latest, isFeatured: true),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFDAD6),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          partnerName.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: Color(0xFF1F1B18),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Aún no hay tarjetas recibidas hoy. ¡Envía la primera tocando + CREAR abajo!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F1B18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (previousCards.isNotEmpty) ...[
                  const SizedBox(height: 26),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'HISTORIAL DE DÍAS ANTERIORES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...previousCards.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: _buildCardBlock(context, c, isFeatured: false),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Barra inferior fija: 🕒 ENVIADOS y + CREAR
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SentHistoryScreen(
                          sentCards: sync.sentHistory,
                          api: api,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history_rounded, size: 18),
                  label: Text(
                    'ENVIADOS (${sync.sentHistory.length})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AmodoroTheme.coralPillLight,
                    foregroundColor: AmodoroTheme.coralPillTextLight,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: () async {
                    final created = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => CreateCardScreen(
                          api: api,
                          partnerNickname: partnerName,
                        ),
                      ),
                    );
                    if (created == true) {
                      await onRefresh();
                    }
                  },
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text(
                    'CREAR',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCardBlock(
    BuildContext context,
    HomeCardItem card, {
    required bool isFeatured,
  }) {
    final bg = AmodoroTheme.parseHexColor(card.bgColor);
    final ink = AmodoroTheme.getContrastingInk(bg);
    final muted = AmodoroTheme.getContrastingMutedInk(bg);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Encabezado con apodo de la pareja y fecha en español
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AmodoroTheme.coralPillLight.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      card.authorLabel.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (isFeatured) ...[
                    const SizedBox(width: 8),
                    const Text(
                      '· BIENVENIDA',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                card.dateHeader,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        // Tarjeta flotante redondeada (28px)
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Foto o dibujo arriba; si es solo texto, NO muestra recuadro arriba
              if (card.mediaType != 'none' &&
                  card.mediaUrl != null &&
                  card.mediaUrl!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _buildMediaWidget(api.resolveMediaUrl(card.mediaUrl)),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                card.textContent,
                style: AmodoroTheme.getCardTextStyle(
                  fontFamily: card.fontFamily,
                  fontSize: card.fontSize,
                  color: ink,
                ),
              ),
              if (card.reactions.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: card.reactions.map((r) {
                    final label = [
                      if (r.emoji != null && r.emoji!.isNotEmpty) r.emoji!,
                      if (r.presetText != null && r.presetText!.isNotEmpty)
                        r.presetText!,
                    ].join(' ');
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: ink.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${r.authorLabel}: $label',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: ink,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Barra de reacciones con emoji + textos predeterminados
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ..._reactionEmojis.map((emoji) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => _react(context, cardId: card.id, emoji: emoji),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 15)),
                    ),
                  ),
                );
              }),
              ...sync.quickReplies.map((reply) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () =>
                        _react(context, cardId: card.id, presetText: reply),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        reply,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: muted == ink
                              ? null
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMediaWidget(String url) {
    if (url.startsWith('data:image/')) {
      final comma = url.indexOf(',');
      if (comma != -1) {
        try {
          final bytes = base64Decode(url.substring(comma + 1));
          return Image.memory(
            bytes,
            height: 210,
            width: double.infinity,
            fit: BoxFit.cover,
          );
        } catch (_) {}
      }
    }
    return Image.network(
      url,
      height: 210,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}
