import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/amodoro_models.dart';
import '../services/api_client.dart';
import '../theme/amodoro_theme.dart';
import '../widgets/drawing_canvas.dart';
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
    final emojis = sync.reactionEmojis.isNotEmpty
        ? sync.reactionEmojis
        : _defaultReactionEmojis;

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
                      _PartnerCardWithReplyBox(
                        key: ValueKey('home_card_${latest.id}'),
                        card: latest,
                        sync: sync,
                        api: api,
                        partnerName: partnerName,
                        reactionEmojis: emojis,
                        onRefresh: onRefresh,
                        onReactEmoji: (emoji) =>
                            _react(context, cardId: latest.id, emoji: emoji),
                      ),
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
                            child: _PartnerCardWithReplyBox(
                              key: ValueKey('home_card_${c.id}'),
                              card: c,
                              sync: sync,
                              api: api,
                              partnerName: partnerName,
                              reactionEmojis: emojis,
                              onRefresh: onRefresh,
                              onReactEmoji: (emoji) =>
                                  _react(context, cardId: c.id, emoji: emoji),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),

        // Bottom Action Bar (ENVIADOS + + CREAR) with full circular pill radius
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
                  radius: 999,
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
                  radius: 999,
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
      child: Align(
        alignment: const Alignment(0.0, -0.62),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
}

class _PartnerCardWithReplyBox extends StatefulWidget {
  final HomeCardItem card;
  final SyncPayload sync;
  final AmodoroApiClient api;
  final String partnerName;
  final List<String> reactionEmojis;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String emoji) onReactEmoji;

  const _PartnerCardWithReplyBox({
    super.key,
    required this.card,
    required this.sync,
    required this.api,
    required this.partnerName,
    required this.reactionEmojis,
    required this.onRefresh,
    required this.onReactEmoji,
  });

  @override
  State<_PartnerCardWithReplyBox> createState() =>
      _PartnerCardWithReplyBoxState();
}

class _PartnerCardWithReplyBoxState extends State<_PartnerCardWithReplyBox> {
  final TextEditingController _replyController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  String? _pendingMediaDataUrl;
  String _pendingMediaType = 'none';
  bool _sendingReply = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _pickReplyImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 82,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final ext = picked.path.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
      if (mounted) {
        setState(() {
          _pendingMediaDataUrl = 'data:image/$ext;base64,${base64Encode(bytes)}';
          _pendingMediaType = 'image';
        });
      }
    } catch (_) {}
  }

  Future<void> _openReplyDrawingSheet() async {
    final drawingController = DrawingCanvasController();
    final String? dataUrl = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
        final surface =
            isDark ? AmodoroTheme.darkBackground : AmodoroTheme.lightBackground;
        final ink = isDark ? AmodoroTheme.darkInk : AmodoroTheme.lightInk;
        final muted = isDark ? AmodoroTheme.darkMuted : AmodoroTheme.lightMuted;
        final borderCol =
            isDark ? const Color(0xFF383232) : const Color(0xFFE9E4DC);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              decoration: AmodoroTheme.cardOutlineBox(
                color: surface,
                radius: 36,
                borderColor: borderCol,
                borderWidth: 2.5,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'RESPONDER CON DIBUJO',
                          style: AmodoroTheme.googleSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: muted,
                          ),
                        ),
                        AmodoroPressableButton(
                          onTap: () => Navigator.of(sheetCtx).pop(),
                          width: 36,
                          height: 36,
                          radius: 999,
                          color: isDark
                              ? AmodoroTheme.darkContainer
                              : Colors.white,
                          borderColor: borderCol,
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
                    const SizedBox(height: 12),
                    InteractiveDrawingPad(controller: drawingController),
                    const SizedBox(height: 14),
                    AmodoroPressableButton(
                      onTap: () async {
                        if (drawingController.isEmpty) {
                          Navigator.of(sheetCtx).pop();
                          return;
                        }
                        final exported = await drawingController.toPngDataUrl();
                        if (sheetCtx.mounted) {
                          Navigator.of(sheetCtx).pop(exported);
                        }
                      },
                      height: 48,
                      radius: 999,
                      color: isDark
                          ? AmodoroTheme.coralPillDark
                          : AmodoroTheme.coralPillLight,
                      lipColor: isDark
                          ? AmodoroTheme.coralPillBorderDark
                          : AmodoroTheme.coralPillBorderLight,
                      lipHeight: 3.2,
                      child: Text(
                        'LISTO',
                        style: AmodoroTheme.googleSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (dataUrl != null && dataUrl.isNotEmpty && mounted) {
      setState(() {
        _pendingMediaDataUrl = dataUrl;
        _pendingMediaType = 'drawing';
      });
    }
  }

  Future<void> _submitReply() async {
    if (_sendingReply) return;
    final text = _replyController.text.trim();
    if (text.isEmpty && _pendingMediaDataUrl == null) return;

    setState(() => _sendingReply = true);
    try {
      await widget.api.replyToHomeCard(
        cardId: widget.card.id,
        textContent: text,
        mediaType: _pendingMediaDataUrl != null ? _pendingMediaType : 'none',
        mediaDataUrl: _pendingMediaDataUrl,
      );
      if (mounted) {
        setState(() {
          _replyController.clear();
          _pendingMediaDataUrl = null;
          _pendingMediaType = 'none';
          _sendingReply = false;
        });
      }
      await widget.onRefresh();
    } catch (e) {
      if (mounted) {
        setState(() => _sendingReply = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al enviar respuesta: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
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

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final sync = widget.sync;
    final cardColor = AmodoroTheme.parseHexColor(card.bgColor);
    final inkColor = AmodoroTheme.getContrastingInk(cardColor);
    final mutedInk = AmodoroTheme.getContrastingMutedInk(cardColor);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenInk = isDark ? AmodoroTheme.darkInk : AmodoroTheme.lightInk;
    final cardBorderColor = AmodoroTheme.darkenForPerspective(cardColor, 0.12);

    final myEmojiReaction = card.reactions
        .where(
          (r) =>
              r.userId == sync.me.id &&
              r.emoji != null &&
              r.emoji!.trim().isNotEmpty,
        )
        .firstOrNull;

    final partnerEmojiReaction = card.reactions
        .where(
          (r) =>
              r.userId != sync.me.id &&
              r.emoji != null &&
              r.emoji!.trim().isNotEmpty,
        )
        .firstOrNull;

    final bool hasContent =
        _replyController.text.trim().isNotEmpty || _pendingMediaDataUrl != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Partner Card Container: radius 36, borderWidth 3.0
        Container(
          padding: const EdgeInsets.all(22),
          decoration: AmodoroTheme.cardOutlineBox(
            color: cardColor,
            radius: 36,
            borderColor: cardBorderColor,
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

              // Inner Media (link or 1:1 image/drawing with radius 28)
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
                    final resolvedUrl = widget.api.resolveMediaUrl(card.mediaUrl);
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
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.65),
                          width: 2.0,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: Hero(
                          tag: 'home_media_${card.id}',
                          child: _buildMediaWidget(
                            widget.api.resolveMediaUrl(card.mediaUrl),
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

              const SizedBox(height: 16),

              // Emoji Reaction Dock (before reacting) OR Chosen Emoji Badge (after reacting) INSIDE the card
              _buildEmojiReactionSection(
                cardColor: cardColor,
                cardBorderColor: cardBorderColor,
                myEmojiReaction: myEmojiReaction,
                partnerEmojiReaction: partnerEmojiReaction,
              ),

              const SizedBox(height: 12),

              // Pending Media Preview (96x96 square) before sending reply
              if (_pendingMediaDataUrl != null) ...[
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: cardBorderColor,
                            width: 2.0,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: _buildMediaWidget(_pendingMediaDataUrl!),
                        ),
                      ),
                      Positioned(
                        top: -8,
                        right: -8,
                        child: AmodoroPressableButton(
                          onTap: () {
                            setState(() {
                              _pendingMediaDataUrl = null;
                              _pendingMediaType = 'none';
                            });
                          },
                          width: 28,
                          height: 28,
                          radius: 999,
                          color: AmodoroTheme.coralPillLight,
                          lipColor: AmodoroTheme.coralPillBorderLight,
                          lipHeight: 2.0,
                          child: AmodoroTheme.sysIcon(
                            Symbols.close,
                            size: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Inline Reply Input Pill INSIDE the card
              Container(
                padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
                decoration: AmodoroTheme.cardOutlineBox(
                  color: Colors.white.withValues(alpha: 0.88),
                  radius: 999,
                  borderColor: cardBorderColor,
                  borderWidth: 2.0,
                  subtleShadow: false,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _replyController,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _submitReply(),
                        style: AmodoroTheme.googleSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AmodoroTheme.lightInk,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Escribir algo...',
                          hintStyle: AmodoroTheme.googleSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AmodoroTheme.lightMuted,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (!hasContent) ...[
                      _buildReplyMediaIconButton(
                        icon: Symbols.photo_camera,
                        borderColor: cardBorderColor,
                        onTap: () => _pickReplyImage(ImageSource.camera),
                      ),
                      const SizedBox(width: 5),
                      _buildReplyMediaIconButton(
                        icon: Symbols.image,
                        borderColor: cardBorderColor,
                        onTap: () => _pickReplyImage(ImageSource.gallery),
                      ),
                      const SizedBox(width: 5),
                      _buildReplyMediaIconButton(
                        icon: Symbols.edit,
                        borderColor: cardBorderColor,
                        onTap: _openReplyDrawingSheet,
                      ),
                    ] else
                      AmodoroPressableButton(
                        onTap: _sendingReply ? null : _submitReply,
                        width: 38,
                        height: 38,
                        radius: 999,
                        color: AmodoroTheme.coralPillLight,
                        lipColor: AmodoroTheme.coralPillBorderLight,
                        lipHeight: 2.5,
                        child: _sendingReply
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : AmodoroTheme.sysIcon(
                                Symbols.send,
                                size: 18,
                                color: Colors.white,
                              ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Replies displayed OUTSIDE the card, directly on the background
        if (card.replies.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...card.replies.map(
            (reply) => _buildOutsideReplyItem(
              context,
              reply: reply,
              screenInk: screenInk,
              isDark: isDark,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmojiReactionSection({
    required Color cardColor,
    required Color cardBorderColor,
    required ReactionItem? myEmojiReaction,
    required ReactionItem? partnerEmojiReaction,
  }) {
    final partnerBadge = partnerEmojiReaction != null
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: AmodoroTheme.cardOutlineBox(
              color: Colors.white.withValues(alpha: 0.78),
              radius: 999,
              borderColor: cardBorderColor,
              borderWidth: 1.5,
              subtleShadow: false,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FlatAvatarBadge(
                  avatarId: partnerEmojiReaction.authorAvatarId,
                  size: 20,
                  showPerspectiveBorder: false,
                ),
                const SizedBox(width: 6),
                Text(
                  partnerEmojiReaction.emoji!,
                  style: const TextStyle(fontSize: 22),
                ),
              ],
            ),
          )
        : null;

    if (myEmojiReaction != null) {
      // Chosen emoji state: show ONLY the chosen emoji inside the card
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          AmodoroPressableButton(
            onTap: () => widget.onReactEmoji(myEmojiReaction.emoji!),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            radius: 999,
            color: Colors.white.withValues(alpha: 0.88),
            borderColor: cardBorderColor,
            borderWidth: 2.0,
            lipColor: AmodoroTheme.darkenForPerspective(cardColor, 0.20),
            lipHeight: 2.5,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FlatAvatarBadge(
                  avatarId: widget.sync.me.avatarId,
                  size: 20,
                  showPerspectiveBorder: false,
                ),
                const SizedBox(width: 6),
                Text(
                  myEmojiReaction.emoji!,
                  style: const TextStyle(fontSize: 24),
                ),
              ],
            ),
          ),
          if (partnerBadge != null) partnerBadge,
        ],
      );
    }

    // Unreacted state: show the Emoji Reaction Dock inside the card
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (partnerBadge != null) ...[
          partnerBadge,
          const SizedBox(height: 8),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: AmodoroTheme.cardOutlineBox(
            color: Colors.white.withValues(alpha: 0.72),
            radius: 999,
            borderColor: cardBorderColor,
            borderWidth: 1.8,
            subtleShadow: false,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: widget.reactionEmojis.map((emoji) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: AmodoroPressableButton(
                    onTap: () => widget.onReactEmoji(emoji),
                    width: 44,
                    height: 44,
                    radius: 999,
                    color: Colors.white,
                    borderColor: cardBorderColor.withValues(alpha: 0.65),
                    borderWidth: 1.5,
                    lipColor: AmodoroTheme.darkenForPerspective(
                      cardColor,
                      0.18,
                    ),
                    lipHeight: 2.2,
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 23),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReplyMediaIconButton({
    required IconData icon,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return AmodoroPressableButton(
      onTap: onTap,
      width: 36,
      height: 36,
      radius: 999,
      color: const Color(0xFFF6EFE6),
      borderColor: borderColor.withValues(alpha: 0.6),
      borderWidth: 1.5,
      lipColor: const Color(0xFFE0D4C3),
      lipHeight: 2.0,
      child: AmodoroTheme.sysIcon(
        icon,
        size: 18,
        color: AmodoroTheme.lightInk,
      ),
    );
  }

  Widget _buildOutsideReplyItem(
    BuildContext context, {
    required CardReplyItem reply,
    required Color screenInk,
    required bool isDark,
  }) {
    final String speaker =
        (reply.isMine || reply.userId == widget.sync.me.id)
            ? 'Yo'
            : (reply.authorLabel.isNotEmpty
                ? reply.authorLabel
                : widget.partnerName);
    final String text = reply.textContent.trim();
    final bool hasMedia =
        reply.mediaUrl != null && reply.mediaUrl!.trim().isNotEmpty;
    final Color borderColor =
        isDark ? const Color(0xFF383232) : const Color(0xFFE5DEC9);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 8, right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (text.isNotEmpty || hasMedia)
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: AmodoroTheme.googleSans(
                  fontSize: 14.5,
                  color: screenInk,
                  height: 1.35,
                ),
                children: [
                  TextSpan(
                    text: text.isNotEmpty ? '$speaker: ' : '$speaker:',
                    style: AmodoroTheme.googleSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: screenInk,
                    ),
                  ),
                  if (text.isNotEmpty)
                    TextSpan(
                      text: '"$text"',
                      style: AmodoroTheme.googleSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: screenInk,
                      ),
                    ),
                ],
              ),
            ),
          if (hasMedia) ...[
            const SizedBox(height: 8),
            Center(
              child: Builder(
                builder: (context) {
                  final resolvedUrl = widget.api.resolveMediaUrl(reply.mediaUrl);
                  final heroTag = 'reply_${reply.id}';
                  return GestureDetector(
                    onTap: () => FullscreenMediaViewer.open(
                      context,
                      imageUrl: resolvedUrl,
                      heroTag: heroTag,
                    ),
                    child: Container(
                      width: 152,
                      height: 152,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: borderColor,
                          width: 2.0,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Hero(
                          tag: heroTag,
                          child: _buildMediaWidget(resolvedUrl),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
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
