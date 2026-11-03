import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/amodoro_models.dart';
import '../services/api_client.dart';
import '../theme/amodoro_theme.dart';
import '../widgets/flat_avatar.dart';
import '../widgets/fullscreen_media_viewer.dart';
import '../widgets/glass_bubble_background.dart';
import '../widgets/link_preview_card.dart';
import '../widgets/pressable_button.dart';
import 'create_card_screen.dart';
import 'sent_history_screen.dart';

class HomeScreen extends StatelessWidget {
  final SyncPayload sync;
  final AmodoroApiClient api;
  final Future<void> Function() onRefresh;
  final Future<void> Function(
    String cardId, {
    String? emoji,
    String? presetText,
  })? onReact;

  const HomeScreen({
    super.key,
    required this.sync,
    required this.api,
    required this.onRefresh,
    this.onReact,
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
      if (onReact != null) {
        await onReact!(cardId, emoji: emoji, presetText: presetText);
      } else {
        await api.reactToCard(
          cardId: cardId,
          emoji: emoji,
          presetText: presetText,
        );
        await onRefresh();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al reaccionar: $e')),
        );
      }
    }
  }

  Widget _buildFlatAvatarBorderOnly(String avatarId, {double size = 38}) {
    return FlatAvatarBadge(
      avatarId: avatarId,
      size: size,
      borderWidth: 2.0,
    );
  }

  Widget _buildDailySummaryBanner(BuildContext context, bool isDark) {
    final summary = sync.dailySummary;
    if (summary == null) return const SizedBox.shrink();

    final inkColor = isDark ? AmodoroTheme.darkInk : AmodoroTheme.lightInk;
    final borderColor =
        isDark ? const Color(0xFF383232) : const Color(0xFFE9E4DC);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: AmodoroTheme.cardOutlineBox(
            color: isDark ? AmodoroTheme.darkContainer : Colors.white,
            radius: 999,
            borderColor: borderColor,
            borderWidth: 1.5,
            subtleShadow: false,
          ),
          child: Text(
            '✨ ${summary.pendingCount} pendientes · ${summary.completedTogetherCount} hechas juntos',
            textAlign: TextAlign.center,
            style: AmodoroTheme.googleSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: inkColor,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openQuickReplySheet(
    BuildContext context,
    HomeCardItem card,
  ) async {
    final replies = sync.quickReplies.isNotEmpty
        ? sync.quickReplies
        : const ['Te amo', 'Me alegraste el día', 'Qué bonito'];

    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
        final surface =
            isDark ? AmodoroTheme.darkBackground : AmodoroTheme.lightBackground;
        final ink = isDark ? AmodoroTheme.darkInk : AmodoroTheme.lightInk;
        final muted = isDark ? AmodoroTheme.darkMuted : AmodoroTheme.lightMuted;
        final sheetBorder =
            isDark ? const Color(0xFF383232) : const Color(0xFFE9E4DC);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              decoration: AmodoroTheme.cardOutlineBox(
                color: surface,
                radius: 28,
                borderColor: sheetBorder,
                borderWidth: 2.5,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'RESPUESTA RÁPIDA',
                        style: AmodoroTheme.googleSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: muted,
                        ),
                      ),
                      AmodoroPressableButton(
                        onTap: () => Navigator.of(sheetCtx).pop(),
                        width: 34,
                        height: 34,
                        radius: 12,
                        color: isDark
                            ? AmodoroTheme.darkContainer
                            : Colors.white,
                        borderColor: sheetBorder,
                        borderWidth: 1.5,
                        lipColor: isDark
                            ? const Color(0xFF141111)
                            : const Color(0xFFDFD8CE),
                        lipHeight: 2.2,
                        child: AmodoroTheme.sysIcon(
                          Symbols.close,
                          size: 18,
                          color: ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ...replies.map((reply) {
                    final isMineSelected = card.reactions.any(
                      (r) => r.userId == sync.me.id && r.presetText == reply,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AmodoroPressableButton(
                        onTap: () => Navigator.of(sheetCtx).pop(reply),
                        height: 44,
                        radius: 16,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        color: isMineSelected
                            ? const Color(0xFFFFDAD6)
                            : (isDark
                                ? AmodoroTheme.darkContainer
                                : Colors.white),
                        borderColor: isMineSelected
                            ? AmodoroTheme.coralPillLight
                            : sheetBorder,
                        borderWidth: isMineSelected ? 2.0 : 1.5,
                        lipColor: isMineSelected
                            ? AmodoroTheme.coralPillBorderLight
                            : (isDark
                                ? const Color(0xFF141111)
                                : const Color(0xFFDFD8CE)),
                        lipHeight: 2.5,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                reply,
                                style: AmodoroTheme.googleSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: isMineSelected
                                      ? AmodoroTheme.lightInk
                                      : ink,
                                ),
                              ),
                            ),
                            if (isMineSelected)
                              Text(
                                'ACTIVA · TOCA PARA QUITAR',
                                style: AmodoroTheme.googleSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: AmodoroTheme.coralPillBorderLight,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (chosen != null && chosen.trim().isNotEmpty && context.mounted) {
      await _react(context, cardId: card.id, presetText: chosen.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allCards = sync.receivedHistory;
    final latest =
        allCards.isNotEmpty ? allCards.first : sync.latestPartnerCard;
    final previousCards = allCards.length > 1
        ? allCards.sublist(1)
        : const <HomeCardItem>[];

    final partnerName = sync.partner?.myGivenNickname ??
        (sync.me.partnerNicknameGiven.isNotEmpty
            ? sync.me.partnerNicknameGiven
            : (sync.partner?.displayName ?? 'Pareja'));

    final bottomInk = isDark ? AmodoroTheme.darkInk : AmodoroTheme.lightInk;

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
                      if (sync.dailySummary != null)
                        _buildDailySummaryBanner(context, isDark),
                      _buildPartnerCard(context, latest, isFeatured: true),
                      if (previousCards.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'DÍAS ANTERIORES',
                            style: AmodoroTheme.googleSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                              color: isDark
                                  ? AmodoroTheme.darkMuted
                                  : AmodoroTheme.lightMuted,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ...previousCards.map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: _buildPartnerCard(
                              context,
                              c,
                              isFeatured: false,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),

        // Bottom Action Bar (ENVIADOS + + CREAR) matching Neo-Pastel Mockup
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 20, 14),
          child: Row(
            children: [
              Expanded(
                child: AmodoroPressableButton(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SentHistoryScreen(
                          sentCards: sync.sentHistory,
                          api: api,
                          onRefresh: onRefresh,
                          partnerNickname: partnerName,
                        ),
                      ),
                    );
                  },
                  color: isDark
                      ? AmodoroTheme.darkContainer
                      : const Color(0xFFF6EFE6),
                  borderColor: isDark
                      ? const Color(0xFF3A3333)
                      : const Color(0xFFE5DEC9),
                  borderWidth: 1.5,
                  lipColor: isDark
                      ? const Color(0xFF141111)
                      : const Color(0xFFE0D4C3),
                  lipHeight: 3.5,
                  radius: 18,
                  height: 52,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AmodoroTheme.sysIcon(
                        Symbols.send,
                        size: 19,
                        color: bottomInk,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ENVIADOS',
                        style: AmodoroTheme.googleSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: bottomInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: AmodoroPressableButton(
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
                  color: isDark
                      ? AmodoroTheme.coralPillDark
                      : AmodoroTheme.coralPillLight,
                  lipColor: isDark
                      ? AmodoroTheme.coralPillBorderDark
                      : AmodoroTheme.coralPillBorderLight,
                  lipHeight: 4.0,
                  radius: 18,
                  height: 52,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AmodoroTheme.sysIcon(
                        Symbols.add,
                        size: 20,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'CREAR',
                        style: AmodoroTheme.googleSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

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
              if (sync.dailySummary != null)
                _buildDailySummaryBanner(context, isDark),
              Text(
                'amodoro',
                style: AmodoroTheme.logoStyle(fontSize: 42, isDark: isDark),
              ),
              const SizedBox(height: 14),
              Text(
                'Aún no hay tarjetas en tu lienzo.\nSorprende a $partnerName creando la primera nota de hoy.',
                textAlign: TextAlign.center,
                style: AmodoroTheme.googleSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
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

  Widget _buildPartnerCard(
    BuildContext context,
    HomeCardItem card, {
    required bool isFeatured,
  }) {
    final cardColor = AmodoroTheme.parseHexColor(card.bgColor);
    final inkColor = AmodoroTheme.getContrastingInk(cardColor);
    final mutedInk = AmodoroTheme.getContrastingMutedInk(cardColor);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final emojis = sync.reactionEmojis.isNotEmpty
        ? sync.reactionEmojis
        : _defaultReactionEmojis;

    final myPresetReaction = card.reactions
        .where(
          (r) =>
              r.userId == sync.me.id &&
              r.presetText != null &&
              r.presetText!.trim().isNotEmpty,
        )
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Partner Card Container: Border-only (NO 3D bottom lip)
        Container(
          padding: const EdgeInsets.all(22),
          decoration: AmodoroTheme.cardOutlineBox(
            color: cardColor,
            radius: 32,
            borderColor: AmodoroTheme.darkenForPerspective(cardColor, 0.12),
            borderWidth: 3.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author Header inside the Card
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _buildFlatAvatarBorderOnly(
                        card.authorAvatarId,
                        size: 38,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        card.authorLabel,
                        style: AmodoroTheme.googleSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: inkColor,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    card.dateHeader.toUpperCase(),
                    style: AmodoroTheme.googleSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: mutedInk,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Inner Media (link or 1:1 image/drawing)
              if (card.mediaType == 'link' &&
                  card.linkUrl != null &&
                  card.linkUrl!.isNotEmpty) ...[
                LinkPreviewCard(
                  url: card.linkUrl!,
                  title: card.linkTitle,
                  thumbnail: card.linkThumbnail,
                  platform: card.linkPlatform,
                  cardBgColor: cardColor,
                ),
                if (card.textContent.isNotEmpty) const SizedBox(height: 16),
              ] else if (card.mediaType != 'none' &&
                  card.mediaUrl != null &&
                  card.mediaUrl!.isNotEmpty) ...[
                GestureDetector(
                  onTap: () {
                    final resolvedUrl = api.resolveMediaUrl(card.mediaUrl);
                    final heroTag = 'home_media_${card.id}';
                    FullscreenMediaViewer.open(
                      context,
                      imageUrl: resolvedUrl,
                      heroTag: heroTag,
                    );
                  },
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.65),
                          width: 2.0,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Hero(
                          tag: 'home_media_${card.id}',
                          child: _buildMediaWidget(
                            api.resolveMediaUrl(card.mediaUrl),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (card.altText != null &&
                    card.altText!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    card.altText!.trim(),
                    style: AmodoroTheme.googleSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: mutedInk,
                    ),
                  ),
                ],
                if (card.textContent.isNotEmpty) const SizedBox(height: 16),
              ],

              // Card Text Content
              if (card.textContent.isNotEmpty)
                Text(
                  card.textContent,
                  style: AmodoroTheme.getCardTextStyle(
                    fontFamily: card.fontFamily,
                    color: inkColor,
                    fontSizePx: card.fontSizePx,
                    fontSizeKey: card.fontSize,
                  ),
                ),

              // Reactions displayed on the card (interactive for own reactions)
              if (card.reactions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: card.reactions.map((r) {
                    final isMine = r.userId == sync.me.id;
                    final label = [
                      if (r.emoji != null && r.emoji!.isNotEmpty) r.emoji!,
                      if (r.presetText != null && r.presetText!.isNotEmpty)
                        r.presetText!,
                    ].join(' ');

                    final chipChild = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FlatAvatarBadge(
                          avatarId: r.authorAvatarId,
                          size: 18,
                          showPerspectiveBorder: false,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${r.authorLabel}: $label',
                          style: AmodoroTheme.googleSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AmodoroTheme.lightInk,
                          ),
                        ),
                        if (isMine) ...[
                          const SizedBox(width: 4),
                          AmodoroTheme.sysIcon(
                            Symbols.close,
                            size: 13,
                            color: AmodoroTheme.coralPillBorderLight,
                          ),
                        ],
                      ],
                    );

                    if (isMine) {
                      return AmodoroPressableButton(
                        onTap: () => _react(
                          context,
                          cardId: card.id,
                          emoji: r.emoji,
                          presetText: r.presetText,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        radius: 999,
                        color: const Color(0xFFFFDAD6),
                        borderColor: AmodoroTheme.coralPillLight,
                        borderWidth: 1.5,
                        lipColor: AmodoroTheme.coralPillBorderLight,
                        lipHeight: 2.0,
                        child: chipChild,
                      );
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: AmodoroTheme.cardOutlineBox(
                        color: Colors.white.withValues(alpha: 0.65),
                        radius: 999,
                        borderColor: AmodoroTheme.darkenForPerspective(
                          cardColor,
                          0.14,
                        ),
                        borderWidth: 1.5,
                        subtleShadow: false,
                      ),
                      child: chipChild,
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Reaction Bar below the card matching Neo-Pastel Mockup
        Row(
          children: [
            // Left: Quick-reply capsule button
            AmodoroPressableButton(
              onTap: () => _openQuickReplySheet(context, card),
              radius: 16,
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              color: myPresetReaction != null
                  ? const Color(0xFFFFDAD6)
                  : (isDark ? AmodoroTheme.darkContainer : Colors.white),
              borderColor: myPresetReaction != null
                  ? AmodoroTheme.coralPillLight
                  : const Color(0xFFE9E4DC),
              borderWidth: myPresetReaction != null ? 2.0 : 1.5,
              lipColor: myPresetReaction != null
                  ? AmodoroTheme.coralPillBorderLight
                  : const Color(0xFFDFD8CE),
              lipHeight: 2.5,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AmodoroTheme.sysIcon(
                    Symbols.chat_bubble,
                    size: 16,
                    color: myPresetReaction != null
                        ? AmodoroTheme.lightInk
                        : (isDark ? AmodoroTheme.darkInk : AmodoroTheme.lightInk),
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 110),
                    child: Text(
                      myPresetReaction?.presetText ?? 'RESPONDER',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AmodoroTheme.googleSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: myPresetReaction != null
                            ? AmodoroTheme.lightInk
                            : (isDark
                                ? AmodoroTheme.darkInk
                                : AmodoroTheme.lightInk),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Right: Horizontal row of emoji buttons (38x38, radius: 16)
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: emojis.map((emoji) {
                    final hasReactedWithEmoji = card.reactions.any(
                      (r) => r.userId == sync.me.id && r.emoji == emoji,
                    );

                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: AmodoroPressableButton(
                        onTap: () => _react(
                          context,
                          cardId: card.id,
                          emoji: emoji,
                        ),
                        width: 38,
                        height: 38,
                        radius: 16,
                        color: hasReactedWithEmoji
                            ? const Color(0xFFFFDAD6)
                            : (isDark
                                ? AmodoroTheme.darkContainer
                                : Colors.white),
                        borderColor: hasReactedWithEmoji
                            ? AmodoroTheme.coralPillLight
                            : const Color(0xFFE9E4DC),
                        borderWidth: hasReactedWithEmoji ? 2.0 : 1.5,
                        lipColor: hasReactedWithEmoji
                            ? AmodoroTheme.coralPillBorderLight
                            : const Color(0xFFDFD8CE),
                        lipHeight: 2.5,
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
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
