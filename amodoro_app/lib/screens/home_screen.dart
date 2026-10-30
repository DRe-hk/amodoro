import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/amodoro_models.dart';
import '../services/api_client.dart';
import '../theme/amodoro_theme.dart';
import '../widgets/flat_avatar.dart';
import '../widgets/glass_bubble_background.dart';
import '../widgets/link_preview_card.dart';
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

  static const List<String> _defaultReactionEmojis = [
    '❤️',
    '🥰',
    '🥺',
    '✨',
    '🔥',
    '🫶',
  ];

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allCards = sync.receivedHistory;
    final latest = allCards.isNotEmpty ? allCards.first : sync.latestPartnerCard;
    final previousCards = allCards.length > 1
        ? allCards.sublist(1)
        : const <HomeCardItem>[];

    final partnerName = sync.partner?.myGivenNickname ??
        (sync.me.partnerNicknameGiven.isNotEmpty
            ? sync.me.partnerNicknameGiven
            : (sync.partner?.displayName ?? 'Pareja'));

    return Column(
      children: [
        Expanded(
          child: latest == null
              ? _buildEmptyWelcomeVariation(context, isDark, partnerName)
              : RefreshIndicator(
                  onRefresh: onRefresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 20, 24),
                    children: [
                      _buildCardBlock(context, latest, isFeatured: true),
                      if (previousCards.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'DÍAS ANTERIORES',
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.5,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ...previousCards.map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child:
                                _buildCardBlock(context, c, isFeatured: false),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),

        // Barra inferior con botones flotantes en perspectiva (ENVIADOS y CREAR en MAYÚSCULAS)
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 20, 14),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SentHistoryScreen(
                          sentCards: sync.sentHistory,
                          api: api,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    height: 46,
                    decoration: AmodoroTheme.floatingPerspectiveBox(
                      color: isDark
                          ? const Color(0xFF1F2421)
                          : const Color(0xFFF4EFE8),
                      radius: 999,
                      thickness: 2.5,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AmodoroTheme.sysIcon(Symbols.history, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'ENVIADOS (${sync.sentHistory.length})',
                          style: const TextStyle(
                            fontSize: 11.5,
                            letterSpacing: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
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
                  child: Container(
                    height: 46,
                    decoration: AmodoroTheme.floatingPerspectiveBox(
                      color: isDark
                          ? AmodoroTheme.coralPillDark
                          : AmodoroTheme.coralPillLight,
                      radius: 999,
                      thickness: 2.5,
                      perspectiveEdgeColor: isDark
                          ? AmodoroTheme.coralPillBorderDark
                          : AmodoroTheme.coralPillBorderLight,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AmodoroTheme.sysIcon(
                          Symbols.add,
                          size: 19,
                          color: isDark
                              ? AmodoroTheme.coralPillTextDark
                              : AmodoroTheme.coralPillTextLight,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'CREAR',
                          style: TextStyle(
                            fontSize: 11.5,
                            letterSpacing: 1.5,
                            color: isDark
                                ? AmodoroTheme.coralPillTextDark
                                : AmodoroTheme.coralPillTextLight,
                          ),
                        ),
                      ],
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

  /// Si no hay ninguna tarjeta recibida, muestra una variación de la pantalla de bienvenida
  /// con el logo en Playwrite NL Coral y la burbuja Glass emergiendo desde la parte inferior.
  Widget _buildEmptyWelcomeVariation(
    BuildContext context,
    bool isDark,
    String partnerName,
  ) {
    return GlassBubbleBackground(
      emergeFromBottom: true,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'amodoro',
                style: AmodoroTheme.logoStyle(fontSize: 42, isDark: isDark),
              ),
              const SizedBox(height: 14),
              Text(
                'Aún no hay tarjetas en tu lienzo.\nSorprende a $partnerName creando la primera nota de hoy.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardBlock(
    BuildContext context,
    HomeCardItem card, {
    required bool isFeatured,
  }) {
    final bg = AmodoroTheme.parseHexColor(card.bgColor);
    final ink = AmodoroTheme.getContrastingInk(bg);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pillSurface =
        isDark ? const Color(0xFF1F2421) : const Color(0xFFF4EFE8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cabecera con Avatar Flat de quien envió la tarjeta + Apodo/Nombre + Fecha
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  FlatAvatarBadge(
                    avatarId: card.authorAvatarId,
                    size: 28,
                    showPerspectiveBorder: true,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    card.authorLabel.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.3,
                    ),
                  ),
                ],
              ),
              Text(
                card.dateHeader,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.1,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        // Tarjeta flotante con borde en perspectiva inferior y derecho (sin sombras difusas)
        Container(
          padding: const EdgeInsets.all(22),
          decoration: AmodoroTheme.floatingPerspectiveBox(
            color: bg,
            radius: 28,
            thickness: 3.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (card.mediaType == 'link' &&
                  card.linkUrl != null &&
                  card.linkUrl!.isNotEmpty) ...[
                LinkPreviewCard(
                  url: card.linkUrl!,
                  title: card.linkTitle,
                  thumbnail: card.linkThumbnail,
                  platform: card.linkPlatform,
                  cardBgColor: bg,
                ),
                if (card.textContent.isNotEmpty) const SizedBox(height: 16),
              ] else if (card.mediaType != 'none' &&
                  card.mediaUrl != null &&
                  card.mediaUrl!.isNotEmpty) ...[
                AspectRatio(
                  aspectRatio: 1.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _buildMediaWidget(api.resolveMediaUrl(card.mediaUrl)),
                  ),
                ),
                if (card.textContent.isNotEmpty) const SizedBox(height: 16),
              ],
              if (card.textContent.isNotEmpty)
                Text(
                  card.textContent,
                  style: AmodoroTheme.getCardTextStyle(
                    fontFamily: card.fontFamily,
                    color: ink,
                    fontSizePx: card.fontSizePx,
                    fontSizeKey: card.fontSize,
                  ),
                ),
              if (card.reactions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
                      decoration: AmodoroTheme.floatingPerspectiveBox(
                        color: Colors.white.withValues(alpha: 0.45),
                        radius: 999,
                        thickness: 1.8,
                        perspectiveEdgeColor:
                            AmodoroTheme.darkenForPerspective(bg, 0.24),
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
                            '${r.authorLabel}: $label',
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
        ),
        const SizedBox(height: 12),

        // Cápsulas de reacción flotantes con borde en perspectiva (emojis personalizables desde Ajustes)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...(sync.reactionEmojis.isNotEmpty
                      ? sync.reactionEmojis
                      : _defaultReactionEmojis)
                  .map((emoji) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 4),
                  child: GestureDetector(
                    onTap: () => _react(context, cardId: card.id, emoji: emoji),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: AmodoroTheme.floatingPerspectiveBox(
                        color: pillSurface,
                        radius: 999,
                        thickness: 2.0,
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 14)),
                    ),
                  ),
                );
              }),
              ...sync.quickReplies.map((reply) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 4),
                  child: GestureDetector(
                    onTap: () =>
                        _react(context, cardId: card.id, presetText: reply),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: AmodoroTheme.floatingPerspectiveBox(
                        color: pillSurface,
                        radius: 999,
                        thickness: 2.0,
                      ),
                      child: Text(
                        reply,
                        style: const TextStyle(fontSize: 12),
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
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          );
        } catch (_) {}
      }
    }
    return Image.network(
      url,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}
