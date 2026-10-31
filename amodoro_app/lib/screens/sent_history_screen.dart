import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/amodoro_models.dart';
import '../services/api_client.dart';
import '../theme/amodoro_theme.dart';
import '../widgets/flat_avatar.dart';
import '../widgets/fullscreen_media_viewer.dart';
import '../widgets/link_preview_card.dart';
import 'create_card_screen.dart';

class SentHistoryScreen extends StatefulWidget {
  final List<HomeCardItem> sentCards;
  final AmodoroApiClient api;
  final Future<void> Function()? onRefresh;
  final String partnerNickname;

  const SentHistoryScreen({
    super.key,
    required this.sentCards,
    required this.api,
    this.onRefresh,
    this.partnerNickname = 'Pareja',
  });

  @override
  State<SentHistoryScreen> createState() => _SentHistoryScreenState();
}

class _SentHistoryScreenState extends State<SentHistoryScreen> {
  late List<HomeCardItem> _cards;

  @override
  void initState() {
    super.initState();
    _cards = List<HomeCardItem>.from(widget.sentCards);
  }

  @override
  void didUpdateWidget(covariant SentHistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sentCards != widget.sentCards) {
      _cards = List<HomeCardItem>.from(widget.sentCards);
    }
  }

  Future<void> _reloadCards() async {
    try {
      final sync = await widget.api.fetchSync();
      if (mounted) {
        setState(() => _cards = sync.sentHistory);
      }
      if (widget.onRefresh != null) {
        await widget.onRefresh!();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  Future<void> _openCardSubmenu(HomeCardItem card) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
        final surface = Theme.of(sheetCtx).scaffoldBackgroundColor;
        final boxSurface = Theme.of(sheetCtx).colorScheme.surfaceContainer;
        final ink = isDark ? AmodoroTheme.darkInk : AmodoroTheme.lightInk;
        final muted = isDark ? AmodoroTheme.darkMuted : AmodoroTheme.lightMuted;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 18, 18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              decoration: AmodoroTheme.floatingPerspectiveBox(
                color: surface,
                radius: 28,
                thickness: 2.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'OPCIONES DE TARJETA',
                        style: TextStyle(
                          fontSize: 11.5,
                          letterSpacing: 1.4,
                          color: muted,
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(sheetCtx).pop(),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: AmodoroTheme.sysIcon(
                            Symbols.close,
                            size: 19,
                            color: ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () => Navigator.of(sheetCtx).pop('edit'),
                    child: Container(
                      height: 46,
                      decoration: AmodoroTheme.floatingPerspectiveBox(
                        color: boxSurface,
                        radius: 999,
                        thickness: 2.2,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AmodoroTheme.sysIcon(
                            Symbols.edit,
                            size: 19,
                            color: ink,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'EDITAR TARJETA',
                            style: TextStyle(
                              fontSize: 11.5,
                              letterSpacing: 1.3,
                              color: ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => Navigator.of(sheetCtx).pop('delete'),
                    child: Container(
                      height: 46,
                      decoration: AmodoroTheme.floatingPerspectiveBox(
                        color: const Color(0xFFFFDAD6),
                        radius: 999,
                        thickness: 2.2,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AmodoroTheme.sysIcon(
                            Symbols.delete,
                            size: 19,
                            color: const Color(0xFF3B0D09),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'ELIMINAR TARJETA',
                            style: TextStyle(
                              fontSize: 11.5,
                              letterSpacing: 1.3,
                              color: Color(0xFF3B0D09),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    if (action == 'edit') {
      final updated = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => CreateCardScreen(
            api: widget.api,
            partnerNickname: widget.partnerNickname,
            existingCard: card,
          ),
        ),
      );
      if (updated == true) {
        await _reloadCards();
      }
    } else if (action == 'delete') {
      await _confirmDeleteCard(card);
    }
  }

  Future<void> _confirmDeleteCard(HomeCardItem card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
        final surface = Theme.of(dialogCtx).scaffoldBackgroundColor;
        final boxSurface = Theme.of(dialogCtx).colorScheme.surfaceContainer;
        final ink = isDark ? AmodoroTheme.darkInk : AmodoroTheme.lightInk;

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: AmodoroTheme.floatingPerspectiveBox(
              color: surface,
              radius: 26,
              thickness: 2.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '¿Eliminar esta tarjeta enviada?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: ink,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.of(dialogCtx).pop(false),
                        child: Container(
                          height: 44,
                          decoration: AmodoroTheme.floatingPerspectiveBox(
                            color: boxSurface,
                            radius: 999,
                            thickness: 2.0,
                          ),
                          child: Center(
                            child: Text(
                              'CANCELAR',
                              style: TextStyle(
                                fontSize: 11.5,
                                letterSpacing: 1.2,
                                color: ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.of(dialogCtx).pop(true),
                        child: Container(
                          height: 44,
                          decoration: AmodoroTheme.floatingPerspectiveBox(
                            color: isDark
                                ? AmodoroTheme.coralPillDark
                                : AmodoroTheme.coralPillLight,
                            radius: 999,
                            thickness: 2.0,
                            perspectiveEdgeColor: isDark
                                ? AmodoroTheme.coralPillBorderDark
                                : AmodoroTheme.coralPillBorderLight,
                          ),
                          child: Center(
                            child: Text(
                              'ELIMINAR',
                              style: TextStyle(
                                fontSize: 11.5,
                                letterSpacing: 1.2,
                                color: AmodoroTheme.coralText(isDark),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await widget.api.deleteHomeCard(card.id);
      await _reloadCards();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tarjeta eliminada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

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
      body: _cards.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aún no has enviado tarjetas.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _reloadCards,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 12, 20, 24),
                itemCount: _cards.length,
                separatorBuilder: (_, __) => const SizedBox(height: 18),
                itemBuilder: (context, index) {
                  final card = _cards[index];
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
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  card.dateHeader,
                                  style: TextStyle(
                                    fontSize: 11,
                                    letterSpacing: 1.0,
                                    color: muted,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _openCardSubmenu(card),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    child: AmodoroTheme.sysIcon(
                                      Symbols.more_horiz,
                                      size: 20,
                                      color: ink,
                                    ),
                                  ),
                                ),
                              ],
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
                          Builder(
                            builder: (context) {
                              final resolvedUrl =
                                  widget.api.resolveMediaUrl(card.mediaUrl);
                              final heroTag = 'sent_media_${card.id}';
                              return GestureDetector(
                                onTap: () => FullscreenMediaViewer.open(
                                  context,
                                  imageUrl: resolvedUrl,
                                  heroTag: heroTag,
                                ),
                                child: Hero(
                                  tag: heroTag,
                                  child: AspectRatio(
                                    aspectRatio: 1.0,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: _buildCardMedia(resolvedUrl),
                                    ),
                                  ),
                                ),
                              );
                            },
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
                                decoration:
                                    AmodoroTheme.floatingPerspectiveBox(
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
