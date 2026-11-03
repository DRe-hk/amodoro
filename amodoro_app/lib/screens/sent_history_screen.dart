import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/amodoro_models.dart';
import '../services/api_client.dart';
import '../theme/amodoro_theme.dart';
import '../widgets/flat_avatar.dart';
import '../widgets/fullscreen_media_viewer.dart';
import '../widgets/link_preview_card.dart';
import '../widgets/pressable_button.dart';
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'TODAS';

  static const List<String> _filters = [
    'TODAS',
    'FOTOS',
    'DIBUJOS',
    'LINKS',
    'CON REACCIÓN',
  ];

  @override
  void initState() {
    super.initState();
    _cards = List<HomeCardItem>.from(widget.sentCards);
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.trim();
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant SentHistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sentCards != widget.sentCards) {
      _cards = List<HomeCardItem>.from(widget.sentCards);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<HomeCardItem> get _filteredCards {
    return _cards.where((card) {
      // Filter chip match
      switch (_selectedFilter) {
        case 'FOTOS':
          if (card.mediaType != 'image' && card.mediaType != 'photo') {
            return false;
          }
          break;
        case 'DIBUJOS':
          if (card.mediaType != 'drawing') return false;
          break;
        case 'LINKS':
          if (card.mediaType != 'link' &&
              (card.linkUrl == null || card.linkUrl!.isEmpty)) {
            return false;
          }
          break;
        case 'CON REACCIÓN':
          if (card.reactions.isEmpty) return false;
          break;
        case 'TODAS':
        default:
          break;
      }

      // Search query match
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesText = card.textContent.toLowerCase().contains(q);
        final matchesAlt = (card.altText ?? '').toLowerCase().contains(q);
        final matchesLink = (card.linkTitle ?? '').toLowerCase().contains(q) ||
            (card.linkUrl ?? '').toLowerCase().contains(q);
        final matchesDate = card.dateHeader.toLowerCase().contains(q);
        if (!matchesText && !matchesAlt && !matchesLink && !matchesDate) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Widget _buildFlatAvatarBorderOnly(String avatarId, {double size = 34}) {
    return FlatAvatarBadge(
      avatarId: avatarId,
      size: size,
      borderWidth: 2.0,
    );
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
        final surface =
            isDark ? AmodoroTheme.darkBackground : AmodoroTheme.lightBackground;
        final boxSurface =
            isDark ? AmodoroTheme.darkContainer : const Color(0xFFF6EFE6);
        final ink = isDark ? AmodoroTheme.darkInk : AmodoroTheme.lightInk;
        final muted = isDark ? AmodoroTheme.darkMuted : AmodoroTheme.lightMuted;
        final borderCol =
            isDark ? const Color(0xFF383232) : const Color(0xFFE9E4DC);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 18, 18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              decoration: AmodoroTheme.cardOutlineBox(
                color: surface,
                radius: 28,
                borderColor: borderCol,
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
                        'OPCIONES DE TARJETA',
                        style: AmodoroTheme.googleSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          color: muted,
                        ),
                      ),
                      AmodoroPressableButton(
                        onTap: () => Navigator.of(sheetCtx).pop(),
                        width: 34,
                        height: 34,
                        radius: 12,
                        color: boxSurface,
                        borderColor: borderCol,
                        borderWidth: 1.5,
                        lipColor: isDark
                            ? const Color(0xFF141111)
                            : const Color(0xFFE0D4C3),
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
                  AmodoroPressableButton(
                    onTap: () => Navigator.of(sheetCtx).pop('edit'),
                    height: 48,
                    radius: 16,
                    color: boxSurface,
                    borderColor: borderCol,
                    borderWidth: 1.5,
                    lipColor: isDark
                        ? const Color(0xFF141111)
                        : const Color(0xFFE0D4C3),
                    lipHeight: 3.0,
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
                          style: AmodoroTheme.googleSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  AmodoroPressableButton(
                    onTap: () => Navigator.of(sheetCtx).pop('delete'),
                    height: 48,
                    radius: 16,
                    color: const Color(0xFFFFDAD6),
                    borderColor: AmodoroTheme.coralPillLight,
                    borderWidth: 1.5,
                    lipColor: AmodoroTheme.coralPillBorderLight,
                    lipHeight: 3.0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AmodoroTheme.sysIcon(
                          Symbols.delete,
                          size: 19,
                          color: const Color(0xFF3B0D09),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ELIMINAR TARJETA',
                          style: AmodoroTheme.googleSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: const Color(0xFF3B0D09),
                          ),
                        ),
                      ],
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
            editingCard: card,
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
        final surface =
            isDark ? AmodoroTheme.darkBackground : AmodoroTheme.lightBackground;
        final boxSurface =
            isDark ? AmodoroTheme.darkContainer : const Color(0xFFF6EFE6);
        final ink = isDark ? AmodoroTheme.darkInk : AmodoroTheme.lightInk;
        final borderCol =
            isDark ? const Color(0xFF383232) : const Color(0xFFE9E4DC);

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: AmodoroTheme.cardOutlineBox(
              color: surface,
              radius: 28,
              borderColor: borderCol,
              borderWidth: 2.5,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '¿Eliminar esta tarjeta enviada?',
                  textAlign: TextAlign.center,
                  style: AmodoroTheme.googleSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ink,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: AmodoroPressableButton(
                        onTap: () => Navigator.of(dialogCtx).pop(false),
                        height: 46,
                        radius: 16,
                        color: boxSurface,
                        borderColor: borderCol,
                        borderWidth: 1.5,
                        lipColor: isDark
                            ? const Color(0xFF141111)
                            : const Color(0xFFE0D4C3),
                        lipHeight: 2.8,
                        child: Text(
                          'CANCELAR',
                          style: AmodoroTheme.googleSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: ink,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AmodoroPressableButton(
                        onTap: () => Navigator.of(dialogCtx).pop(true),
                        height: 46,
                        radius: 16,
                        color: isDark
                            ? AmodoroTheme.coralPillDark
                            : AmodoroTheme.coralPillLight,
                        lipColor: isDark
                            ? AmodoroTheme.coralPillBorderDark
                            : AmodoroTheme.coralPillBorderLight,
                        lipHeight: 3.0,
                        child: Text(
                          'ELIMINAR',
                          style: AmodoroTheme.googleSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: Colors.white,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenInk = isDark ? AmodoroTheme.darkInk : AmodoroTheme.lightInk;
    final mutedInk = isDark ? AmodoroTheme.darkMuted : AmodoroTheme.lightMuted;
    final boxSurface = isDark ? AmodoroTheme.darkContainer : Colors.white;
    final borderCol =
        isDark ? const Color(0xFF383232) : const Color(0xFFE9E4DC);
    final lipCol = isDark ? const Color(0xFF141111) : const Color(0xFFDFD8CE);
    final filtered = _filteredCards;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header with AmodoroPressableButton back button
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 20, 8),
              child: Row(
                children: [
                  AmodoroPressableButton(
                    onTap: () => Navigator.of(context).pop(),
                    width: 42,
                    height: 40,
                    radius: 14,
                    color: isDark
                        ? AmodoroTheme.darkContainer
                        : const Color(0xFFF6EFE6),
                    borderColor: borderCol,
                    borderWidth: 1.5,
                    lipColor: lipCol,
                    lipHeight: 2.8,
                    child: AmodoroTheme.sysIcon(
                      Symbols.arrow_back,
                      size: 20,
                      color: screenInk,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'ENVIADOS (${_cards.length})',
                      style: AmodoroTheme.googleSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: screenInk,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search & Filter Bar (Requirement F6)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 20, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: AmodoroTheme.cardOutlineBox(
                  color: boxSurface,
                  radius: 18,
                  borderColor: borderCol,
                  borderWidth: 2.0,
                  subtleShadow: false,
                ),
                child: Row(
                  children: [
                    AmodoroTheme.sysIcon(
                      Symbols.search,
                      size: 19,
                      color: mutedInk,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: AmodoroTheme.googleSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: screenInk,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Buscar en enviados...',
                          hintStyle: AmodoroTheme.googleSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: mutedInk,
                          ),
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () => _searchController.clear(),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: AmodoroTheme.sysIcon(
                            Symbols.close,
                            size: 17,
                            color: mutedInk,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Horizontal Filter Chips using AmodoroPressableButton
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(18, 2, 20, 12),
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AmodoroPressableButton(
                      onTap: () => setState(() => _selectedFilter = filter),
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      radius: 14,
                      color: isSelected
                          ? (isDark
                              ? AmodoroTheme.coralPillDark
                              : AmodoroTheme.coralPillLight)
                          : boxSurface,
                      borderColor: isSelected ? null : borderCol,
                      borderWidth: isSelected ? 0.0 : 1.5,
                      lipColor: isSelected
                          ? (isDark
                              ? AmodoroTheme.coralPillBorderDark
                              : AmodoroTheme.coralPillBorderLight)
                          : lipCol,
                      lipHeight: 2.6,
                      child: Text(
                        filter,
                        style: AmodoroTheme.googleSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.9,
                          color: isSelected ? Colors.white : screenInk,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Sent Cards List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _cards.isEmpty
                              ? 'Aún no has enviado tarjetas.'
                              : 'No se encontraron tarjetas con ese filtro.',
                          textAlign: TextAlign.center,
                          style: AmodoroTheme.googleSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: mutedInk,
                          ),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _reloadCards,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 6, 20, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 18),
                        itemBuilder: (context, index) {
                          final card = filtered[index];
                          final cardColor =
                              AmodoroTheme.parseHexColor(card.bgColor);
                          final ink =
                              AmodoroTheme.getContrastingInk(cardColor);
                          final muted =
                              AmodoroTheme.getContrastingMutedInk(cardColor);

                          // Sent Card is a container: AmodoroTheme.cardOutlineBox (NO 3D bottom lip)
                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: AmodoroTheme.cardOutlineBox(
                              color: cardColor,
                              radius: 28,
                              borderColor: AmodoroTheme.darkenForPerspective(
                                cardColor,
                                0.12,
                              ),
                              borderWidth: 2.5,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        _buildFlatAvatarBorderOnly(
                                          card.authorAvatarId,
                                          size: 34,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'YO',
                                          style: AmodoroTheme.googleSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.6,
                                            color: ink,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          card.dateHeader.toUpperCase(),
                                          style: AmodoroTheme.googleSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.8,
                                            color: muted,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        AmodoroPressableButton(
                                          onTap: () => _openCardSubmenu(card),
                                          width: 34,
                                          height: 32,
                                          radius: 12,
                                          color: Colors.white.withValues(
                                            alpha: 0.72,
                                          ),
                                          borderColor: AmodoroTheme
                                              .darkenForPerspective(
                                            cardColor,
                                            0.14,
                                          ),
                                          borderWidth: 1.5,
                                          lipColor: AmodoroTheme
                                              .darkenForPerspective(
                                            cardColor,
                                            0.22,
                                          ),
                                          lipHeight: 2.2,
                                          child: AmodoroTheme.sysIcon(
                                            Symbols.more_horiz,
                                            size: 19,
                                            color: AmodoroTheme.lightInk,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (card.mediaType == 'link' &&
                                    card.linkUrl != null &&
                                    card.linkUrl!.isNotEmpty) ...[
                                  const SizedBox(height: 14),
                                  LinkPreviewCard(
                                    url: card.linkUrl!,
                                    title: card.linkTitle,
                                    thumbnail: card.linkThumbnail,
                                    platform: card.linkPlatform,
                                    cardBgColor: cardColor,
                                  ),
                                ] else if (card.mediaType != 'none' &&
                                    card.mediaUrl != null &&
                                    card.mediaUrl!.isNotEmpty) ...[
                                  const SizedBox(height: 14),
                                  Builder(
                                    builder: (context) {
                                      final resolvedUrl = widget.api
                                          .resolveMediaUrl(card.mediaUrl);
                                      final heroTag = 'sent_media_${card.id}';
                                      return GestureDetector(
                                        onTap: () =>
                                            FullscreenMediaViewer.open(
                                          context,
                                          imageUrl: resolvedUrl,
                                          heroTag: heroTag,
                                        ),
                                        child: AspectRatio(
                                          aspectRatio: 1.0,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(24),
                                              border: Border.all(
                                                color: Colors.white.withValues(
                                                  alpha: 0.65,
                                                ),
                                                width: 2.0,
                                              ),
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(22),
                                              child: Hero(
                                                tag: heroTag,
                                                child: _buildCardMedia(
                                                  resolvedUrl,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  if (card.altText != null &&
                                      card.altText!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      card.altText!.trim(),
                                      style: AmodoroTheme.googleSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: muted,
                                      ),
                                    ),
                                  ],
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
                                        if (r.emoji != null &&
                                            r.emoji!.isNotEmpty)
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
                                        decoration: AmodoroTheme.cardOutlineBox(
                                          color: Colors.white.withValues(
                                            alpha: 0.65,
                                          ),
                                          radius: 999,
                                          borderColor: AmodoroTheme
                                              .darkenForPerspective(
                                            cardColor,
                                            0.14,
                                          ),
                                          borderWidth: 1.5,
                                          subtleShadow: false,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            FlatAvatarBadge(
                                              avatarId: r.authorAvatarId,
                                              size: 18,
                                              showPerspectiveBorder: false,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${r.authorLabel}: $text',
                                              style: AmodoroTheme.googleSans(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                color: AmodoroTheme.lightInk,
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
            ),
          ],
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
