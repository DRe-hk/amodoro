import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/amodoro_models.dart';
import '../services/api_client.dart';
import '../theme/amodoro_theme.dart';
import '../widgets/flat_avatar.dart';
import '../widgets/fullscreen_media_viewer.dart';
import '../widgets/pressable_button.dart';

class CompletedHistoryScreen extends StatefulWidget {
  final AmodoroApiClient api;
  final SyncPayload sync;
  final Future<void> Function() onRefresh;

  const CompletedHistoryScreen({
    super.key,
    required this.api,
    required this.sync,
    required this.onRefresh,
  });

  @override
  State<CompletedHistoryScreen> createState() => _CompletedHistoryScreenState();
}

class _CompletedHistoryScreenState extends State<CompletedHistoryScreen> {
  late SyncPayload _sync;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _reactingItemId;

  static const List<String> _defaultEmojis = [
    '❤️',
    '🥰',
    '🥺',
    '✨',
    '🔥',
    '🫶',
  ];

  @override
  void initState() {
    super.initState();
    _sync = widget.sync;
  }

  @override
  void didUpdateWidget(covariant CompletedHistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sync != widget.sync) {
      _sync = widget.sync;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reloadHistory() async {
    try {
      await widget.onRefresh();
      final fresh = await widget.api.fetchSync();
      if (mounted) {
        setState(() {
          _sync = fresh;
        });
      }
    } catch (_) {
      // Keep current state if offline
    }
  }

  Color _resolveItemAccentColor(CompletedActivityItem item) {
    final tag = item.categoryTag.trim().toLowerCase();
    if (tag.contains('música') || tag.contains('musica')) {
      return const Color(0xFFA855F7);
    }
    if (tag.contains('peli')) {
      return const Color(0xFFF97316);
    }
    if (tag.contains('serie')) {
      return const Color(0xFF3B82F6);
    }
    if (tag.contains('juego')) {
      return const Color(0xFF10B981);
    }
    if (tag.contains('pendiente') || tag.contains('actividad')) {
      return const Color(0xFFF27166);
    }

    final parsed = AmodoroTheme.parseHexColor(
      item.bgColor,
      fallback: const Color(0xFF10B981),
    );
    if (parsed.computeLuminance() > 0.72) {
      final hsl = HSLColor.fromColor(parsed);
      return hsl
          .withLightness(0.54)
          .withSaturation((hsl.saturation + 0.28).clamp(0.45, 0.92))
          .toColor();
    }
    return parsed;
  }

  List<CompletedActivityItem> get _filteredItems {
    final all = _sync.completedHistory;
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((item) {
      final titleMatch = item.title.toLowerCase().contains(q);
      final catMatch = item.categoryTag.toLowerCase().contains(q);
      final notesMatch = item.notes.toLowerCase().contains(q);
      final memoryMatch =
          (item.completionText ?? '').toLowerCase().contains(q);
      final byMatch = item.completedByLabel.toLowerCase().contains(q);
      return titleMatch || catMatch || notesMatch || memoryMatch || byMatch;
    }).toList();
  }

  Future<void> _toggleReaction(
    CompletedActivityItem item,
    String emoji,
  ) async {
    if (_reactingItemId != null) return;
    setState(() => _reactingItemId = '${item.id}_$emoji');
    try {
      await widget.api.reactToBoardItem(
        itemId: item.id,
        emoji: emoji,
      );
      await _reloadHistory();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _reactingItemId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AmodoroTheme.darkBackground : AmodoroTheme.lightBackground;
    final ink = isDark ? AmodoroTheme.darkInk : AmodoroTheme.lightInk;
    final muted = isDark ? AmodoroTheme.darkMuted : AmodoroTheme.lightMuted;
    final allItems = _sync.completedHistory;
    final items = _filteredItems;
    final emojis = _sync.reactionEmojis.isNotEmpty
        ? _sync.reactionEmojis
        : _defaultEmojis;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
              child: Row(
                children: [
                  AmodoroPressableButton(
                    onTap: () => Navigator.of(context).pop(),
                    width: 48,
                    height: 48,
                    radius: 999,
                    color: isDark ? AmodoroTheme.darkContainer : Colors.white,
                    borderColor: isDark
                        ? const Color(0xFF383232)
                        : const Color(0xFFE9E4DC),
                    borderWidth: 1.5,
                    lipColor: isDark
                        ? const Color(0xFF282323)
                        : const Color(0xFFDFD8CE),
                    lipHeight: 3.0,
                    child: AmodoroTheme.sysIcon(
                      Symbols.arrow_back,
                      size: 22,
                      color: ink,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HISTORIAL JUNTOS',
                          style: AmodoroTheme.googleSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: ink,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${allItems.length} ${allItems.length == 1 ? 'actividad completada' : 'actividades completadas'}',
                          style: AmodoroTheme.googleSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: AmodoroTheme.cardOutlineBox(
                      color: const Color(0xFF10B981).withValues(alpha: 0.14),
                      radius: 999,
                      borderColor: const Color(0xFF10B981),
                      borderWidth: 1.8,
                      subtleShadow: false,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AmodoroTheme.sysIcon(
                          Symbols.auto_awesome,
                          size: 16,
                          color: const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${allItems.length}',
                          style: AmodoroTheme.googleSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar (Requirement F6 - border-only container)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                decoration: AmodoroTheme.cardOutlineBox(
                  color: isDark ? AmodoroTheme.darkContainer : Colors.white,
                  radius: 999,
                  borderColor: isDark
                      ? const Color(0xFF383232)
                      : const Color(0xFFE9E4DC),
                  borderWidth: 1.5,
                  subtleShadow: false,
                ),
                child: Row(
                  children: [
                    AmodoroTheme.sysIcon(
                      Symbols.search,
                      size: 20,
                      color: muted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() => _searchQuery = value);
                        },
                        style: AmodoroTheme.googleSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: ink,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText:
                              'Buscar por actividad, categoría o recuerdo...',
                          hintStyle: AmodoroTheme.googleSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: muted,
                          ),
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: AmodoroTheme.sysIcon(
                            Symbols.close,
                            size: 18,
                            color: muted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Completed Activity Cards List
            Expanded(
              child: RefreshIndicator(
                onRefresh: _reloadHistory,
                color: const Color(0xFF10B981),
                child: items.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: AmodoroTheme.cardOutlineBox(
                              color: isDark
                                  ? AmodoroTheme.darkContainer
                                  : Colors.white,
                              radius: 28,
                              borderColor: isDark
                                  ? const Color(0xFF383232)
                                  : const Color(0xFFE9E4DC),
                              borderWidth: 2.0,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981)
                                        .withValues(alpha: 0.14),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: AmodoroTheme.sysIcon(
                                    Symbols.photo_library,
                                    size: 30,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.trim().isNotEmpty
                                      ? 'SIN RESULTADOS EN SU HISTORIAL'
                                      : 'AÚN NO HAY ACTIVIDADES COMPLETADAS',
                                  textAlign: TextAlign.center,
                                  style: AmodoroTheme.googleSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: ink,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _searchQuery.trim().isNotEmpty
                                      ? 'Prueba buscando con otra palabra clave.'
                                      : 'Cuando marquen una actividad como completada con una foto, imagen o mensaje de recuerdo, aparecerá aquí para siempre.',
                                  textAlign: TextAlign.center,
                                  style: AmodoroTheme.googleSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: muted,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: _buildCompletedActivityCard(
                              context,
                              item: item,
                              emojis: emojis,
                              isDark: isDark,
                              ink: ink,
                              muted: muted,
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

  Widget _buildCompletedActivityCard(
    BuildContext context, {
    required CompletedActivityItem item,
    required List<String> emojis,
    required bool isDark,
    required Color ink,
    required Color muted,
  }) {
    final itemAccentColor = _resolveItemAccentColor(item);
    final rawMedia = (item.completionMediaUrl != null &&
            item.completionMediaUrl!.isNotEmpty)
        ? item.completionMediaUrl
        : item.mediaUrl;
    final resolvedMediaUrl =
        rawMedia != null && rawMedia.isNotEmpty
            ? widget.api.resolveMediaUrl(rawMedia)
            : '';
    final hasMemoryText =
        item.completionText != null && item.completionText!.trim().isNotEmpty;
    final myReaction = item.reactions
        .where((r) =>
            r.userId == _sync.me.id && r.emoji != null && r.emoji!.isNotEmpty)
        .firstOrNull;
    final partnerReaction = item.reactions
        .where((r) =>
            r.userId != _sync.me.id && r.emoji != null && r.emoji!.isNotEmpty)
        .firstOrNull;

    return Container(
      padding: const EdgeInsets.all(20),
      // Strict Button vs Non-Button Rule: Border-only container, NO 3D bottom lip!
      decoration: AmodoroTheme.cardOutlineBox(
        color: isDark ? AmodoroTheme.darkContainer : Colors.white,
        radius: 36,
        borderColor: itemAccentColor,
        borderWidth: 3.0,
        subtleShadow: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top row: Category pill in vibrant color + completedDateHeader on the right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: itemAccentColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: itemAccentColor.withValues(alpha: 0.55),
                      width: 1.4,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AmodoroTheme.sysIcon(
                        Symbols.check_circle,
                        size: 14,
                        color: itemAccentColor,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          item.categoryTag.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AmodoroTheme.googleSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: itemAccentColor,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                item.completedDateHeader.toUpperCase(),
                style: AmodoroTheme.googleSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: muted,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Activity Title (FontWeight.w800, 18sp) + original item.notes if non-empty
          Text(
            item.emoji.isNotEmpty
                ? '${item.title} ${item.emoji}'.trim()
                : item.title,
            style: AmodoroTheme.googleSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: ink,
              height: 1.26,
            ),
          ),
          if (item.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.notes.trim(),
              style: AmodoroTheme.googleSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: muted,
                height: 1.38,
              ),
            ),
          ],

          // 3. Memory Photo / Image (1:1 square, radius 28, tappable for FullscreenMediaViewer)
          if (resolvedMediaUrl.isNotEmpty) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => FullscreenMediaViewer.open(
                context,
                imageUrl: resolvedMediaUrl,
                heroTag: 'completed_history_media_${item.id}',
              ),
              child: Hero(
                tag: 'completed_history_media_${item.id}',
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: _buildMediaImage(resolvedMediaUrl),
                  ),
                ),
              ),
            ),
          ],

          // 4. Memory Message in warm cream/pastel border-only box with quote styling
          if (hasMemoryText) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: AmodoroTheme.cardOutlineBox(
                color: isDark
                    ? const Color(0xFF2D2727)
                    : const Color(0xFFFAF6F0),
                radius: 22,
                borderColor: itemAccentColor.withValues(alpha: 0.45),
                borderWidth: 1.5,
                subtleShadow: false,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AmodoroTheme.sysIcon(
                    Symbols.format_quote,
                    size: 20,
                    color: itemAccentColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.completionText!.trim(),
                      style: AmodoroTheme.googleSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ink,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // 5. Completer & Reactions Footer
          Row(
            children: [
              FlatAvatarBadge(
                avatarId: item.completedByAvatarId,
                size: 28,
                borderWidth: 1.5,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Completado por ${item.completedByLabel}',
                      style: AmodoroTheme.googleSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    if (item.authorLabel.isNotEmpty)
                      Text(
                        'Propuesto por ${item.authorLabel}',
                        style: AmodoroTheme.googleSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: muted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Emoji Reaction Dock (Before me reacts -> circular dock of reactionEmojis at fontSize 22; After me reacts -> only chosen emoji at fontSize 23) + partner's reaction
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (myReaction == null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: AmodoroTheme.cardOutlineBox(
                    color: isDark
                        ? const Color(0xFF2D2727)
                        : const Color(0xFFFAF6F0),
                    radius: 999,
                    borderColor: itemAccentColor.withValues(alpha: 0.5),
                    borderWidth: 1.5,
                    subtleShadow: false,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: emojis.map((emoji) {
                        final isBusy = _reactingItemId == '${item.id}_$emoji';
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: AmodoroPressableButton(
                            onTap: isBusy
                                ? null
                                : () => _toggleReaction(item, emoji),
                            width: 38,
                            height: 38,
                            radius: 999,
                            color: isDark
                                ? AmodoroTheme.darkContainer
                                : Colors.white,
                            borderColor: isDark
                                ? const Color(0xFF3E3636)
                                : const Color(0xFFE2DCD3),
                            borderWidth: 1.2,
                            lipColor: isDark
                                ? const Color(0xFF221D1D)
                                : const Color(0xFFD5CEC4),
                            lipHeight: 2.2,
                            child: Text(
                              emoji,
                              style: const TextStyle(
                                fontSize: 22,
                                height: 1.05,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                )
              else
                AmodoroPressableButton(
                  onTap: _reactingItemId != null
                      ? null
                      : () => _toggleReaction(item, myReaction.emoji!),
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  radius: 999,
                  color: itemAccentColor.withValues(alpha: 0.16),
                  borderColor: itemAccentColor,
                  borderWidth: 2.0,
                  lipColor: itemAccentColor,
                  lipHeight: 2.6,
                  child: Text(
                    myReaction.emoji!,
                    style: const TextStyle(
                      fontSize: 23,
                      height: 1.05,
                    ),
                  ),
                ),
              if (partnerReaction != null)
                Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: AmodoroTheme.cardOutlineBox(
                    color: isDark
                        ? const Color(0xFF2D2727)
                        : const Color(0xFFF6EFE6),
                    radius: 999,
                    borderColor: isDark
                        ? const Color(0xFF3E3636)
                        : const Color(0xFFE5DDD3),
                    borderWidth: 1.4,
                    subtleShadow: false,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FlatAvatarBadge(
                        avatarId: partnerReaction.authorAvatarId,
                        size: 20,
                        borderWidth: 1.2,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        partnerReaction.emoji!,
                        style: const TextStyle(
                          fontSize: 20,
                          height: 1.05,
                        ),
                      ),
                      if (partnerReaction.authorLabel.isNotEmpty) ...[
                        const SizedBox(width: 5),
                        Text(
                          partnerReaction.authorLabel,
                          style: AmodoroTheme.googleSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMediaImage(String url) {
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
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFFF3EFEA),
        alignment: Alignment.center,
        child: AmodoroTheme.sysIcon(
          Symbols.broken_image,
          size: 32,
          color: AmodoroTheme.lightMuted,
        ),
      ),
    );
  }
}
