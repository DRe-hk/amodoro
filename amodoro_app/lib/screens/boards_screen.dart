import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/amodoro_models.dart';
import '../services/api_client.dart';
import '../theme/amodoro_theme.dart';
import '../widgets/amodoro_image.dart';
import '../widgets/decide_sheet.dart';
import '../widgets/flat_avatar.dart';
import '../widgets/fullscreen_media_viewer.dart';
import '../widgets/link_preview_card.dart';
import '../widgets/pressable_button.dart';
import 'completed_history_screen.dart';

class BoardsScreen extends StatefulWidget {
  final SyncPayload sync;
  final AmodoroApiClient api;
  final Future<void> Function() onRefresh;

  const BoardsScreen({
    super.key,
    required this.sync,
    required this.api,
    required this.onRefresh,
  });

  @override
  State<BoardsScreen> createState() => _BoardsScreenState();
}

class _BoardsScreenState extends State<BoardsScreen> {
  String? _selectedBoardId;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _searchController = TextEditingController();
  bool _showSearch = false;
  String _searchQuery = '';

  static const List<String> _defaultEmojis = [
    '❤️',
    '🥰',
    '🥺',
    '✨',
    '🔥',
    '🫶',
  ];

  static const List<Map<String, dynamic>> _boardIconOptions = [
    {'key': 'schedule', 'icon': Symbols.schedule, 'label': 'Reloj'},
    {'key': 'album', 'icon': Symbols.album, 'label': 'Música'},
    {'key': 'movie', 'icon': Symbols.movie, 'label': 'Cine'},
    {'key': 'tv', 'icon': Symbols.tv, 'label': 'Series'},
    {'key': 'sports_esports', 'icon': Symbols.sports_esports, 'label': 'Juegos'},
    {'key': 'favorite', 'icon': Symbols.favorite, 'label': 'Favorito'},
    {'key': 'restaurant', 'icon': Symbols.restaurant, 'label': 'Comida'},
    {'key': 'flight', 'icon': Symbols.flight, 'label': 'Viaje'},
    {'key': 'bookmark', 'icon': Symbols.bookmark, 'label': 'Lista'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  BoardModel? get _activeBoard {
    final boards = widget.sync.boards;
    if (boards.isEmpty) return null;
    if (_selectedBoardId != null) {
      for (final b in boards) {
        if (b.id == _selectedBoardId) return b;
      }
    }
    return boards.first;
  }

  /// Resolves the vibrant Neo-Pastel color for a board pill & button.
  Color _resolveBoardVibrantColor(BoardModel board) {
    switch (board.slug.trim().toLowerCase()) {
      case 'actividades':
        return const Color(0xFFF27166); // Salmon
      case 'musica':
        return const Color(0xFFA855F7); // Purple
      case 'pelis':
        return const Color(0xFFF97316); // Orange/Amber
      case 'series':
        return const Color(0xFF3B82F6); // Blue
      case 'juegos':
        return const Color(0xFF10B981); // Emerald
    }
    final parsed = AmodoroTheme.parseHexColor(
      board.bgColor,
      fallback: const Color(0xFFF27166),
    );
    if (parsed.computeLuminance() > 0.72) {
      final hsl = HSLColor.fromColor(parsed);
      return hsl
          .withLightness(0.55)
          .withSaturation((hsl.saturation + 0.28).clamp(0.45, 0.92))
          .toColor();
    }
    return parsed;
  }

  /// Resolves the vibrant border/accent color for a board item card.
  Color _resolveItemVibrantColor(BoardCardItem item, BoardModel board) {
    final parsed = AmodoroTheme.parseHexColor(
      item.bgColor,
      fallback: const Color(0xFFF27166),
    );
    // If the item has a vibrant custom color already, use it
    if (item.bgColor.trim().isNotEmpty &&
        item.bgColor.toUpperCase() != '#FFDAD6' &&
        parsed.computeLuminance() <= 0.72) {
      return parsed;
    }

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

    if (parsed.computeLuminance() > 0.72 &&
        item.bgColor.toUpperCase() != '#FFDAD6') {
      final hsl = HSLColor.fromColor(parsed);
      return hsl
          .withLightness(0.55)
          .withSaturation((hsl.saturation + 0.28).clamp(0.45, 0.92))
          .toColor();
    }
    return _resolveBoardVibrantColor(board);
  }

  bool _containsEmojiChar(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    return trimmed.runes.any((r) => r > 127);
  }

  Widget _buildBoardPillLeadingIcon(
    BoardModel board, {
    required Color tintColor,
  }) {
    if (_containsEmojiChar(board.icon)) {
      return ColorFiltered(
        colorFilter: ColorFilter.mode(tintColor, BlendMode.srcIn),
        child: Text(
          board.icon.trim(),
          style: const TextStyle(fontSize: 14, height: 1.0),
        ),
      );
    }
    return AmodoroTheme.sysIcon(
      AmodoroTheme.boardIconFromName(board.icon, board.slug),
      size: 16,
      color: tintColor,
    );
  }

  void _openDecideModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DecideSheet(
        sync: widget.sync,
        api: widget.api,
        onRefresh: widget.onRefresh,
      ),
    );
  }

  Future<void> _openCompletedHistoryScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CompletedHistoryScreen(
          api: widget.api,
          sync: widget.sync,
          onRefresh: widget.onRefresh,
        ),
      ),
    );
    if (mounted) {
      await widget.onRefresh();
    }
  }

  /// Modal bottom sheet to reorder boards (Requirement F7) and edit custom boards.
  Future<void> _showReorderBoardsSheet() async {
    final ordered = List<BoardModel>.from(widget.sync.boards);
    bool saving = false;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final surface =
            isDark ? AmodoroTheme.darkContainer : AmodoroTheme.lightBackground;
        final ink = isDark ? AmodoroTheme.darkInk : AmodoroTheme.lightInk;
        final muted = isDark ? AmodoroTheme.darkMuted : AmodoroTheme.lightMuted;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                  decoration: AmodoroTheme.cardOutlineBox(
                    color: surface,
                    radius: 28,
                    borderColor: isDark
                        ? const Color(0xFF383232)
                        : const Color(0xFFE9E4DC),
                    borderWidth: 2.2,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'ORDENAR Y GESTIONAR LISTAS',
                            style: AmodoroTheme.googleSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: ink,
                              letterSpacing: 0.8,
                            ),
                          ),
                          AmodoroPressableButton(
                            onTap: () => Navigator.of(ctx).pop(false),
                            width: 36,
                            height: 36,
                            radius: 999,
                            color: isDark
                                ? const Color(0xFF2D2727)
                                : Colors.white,
                            borderColor: isDark
                                ? const Color(0xFF3E3636)
                                : const Color(0xFFE9E4DC),
                            borderWidth: 1.5,
                            lipColor: isDark
                                ? const Color(0xFF221D1D)
                                : const Color(0xFFDFD8CE),
                            lipHeight: 2.5,
                            child: AmodoroTheme.sysIcon(
                              Symbols.close,
                              size: 18,
                              color: ink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Usa las flechas para cambiar el orden de tus listas o toca el lápiz para editarlas.',
                        style: AmodoroTheme.googleSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: ordered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            final b = ordered[index];
                            final bColor = _resolveBoardVibrantColor(b);
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: AmodoroTheme.cardOutlineBox(
                                color: isDark
                                    ? const Color(0xFF2D2727)
                                    : Colors.white,
                                radius: 999,
                                borderColor: bColor,
                                borderWidth: 2.0,
                                subtleShadow: false,
                              ),
                              child: Row(
                                children: [
                                  _buildBoardPillLeadingIcon(
                                    b,
                                    tintColor: bColor,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      b.title.toUpperCase(),
                                      style: AmodoroTheme.googleSans(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: ink,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ),
                                  AmodoroPressableButton(
                                    onTap: () {
                                      Navigator.of(ctx).pop(false);
                                      _showBoardSubmenu(existing: b);
                                    },
                                    width: 34,
                                    height: 34,
                                    radius: 999,
                                    color: isDark
                                        ? AmodoroTheme.darkContainer
                                        : const Color(0xFFF6EFE6),
                                    lipHeight: 2.2,
                                    child: AmodoroTheme.sysIcon(
                                      Symbols.edit,
                                      size: 16,
                                      color: ink,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  AmodoroPressableButton(
                                    onTap: index > 0
                                        ? () {
                                            setModalState(() {
                                              final item =
                                                  ordered.removeAt(index);
                                              ordered.insert(index - 1, item);
                                            });
                                          }
                                        : null,
                                    width: 34,
                                    height: 34,
                                    radius: 999,
                                    color: isDark
                                        ? AmodoroTheme.darkContainer
                                        : const Color(0xFFF6EFE6),
                                    lipHeight: 2.2,
                                    child: AmodoroTheme.sysIcon(
                                      Symbols.keyboard_arrow_up,
                                      size: 18,
                                      color: index > 0
                                          ? ink
                                          : muted.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  AmodoroPressableButton(
                                    onTap: index < ordered.length - 1
                                        ? () {
                                            setModalState(() {
                                              final item =
                                                  ordered.removeAt(index);
                                              ordered.insert(index + 1, item);
                                            });
                                          }
                                        : null,
                                    width: 34,
                                    height: 34,
                                    radius: 999,
                                    color: isDark
                                        ? AmodoroTheme.darkContainer
                                        : const Color(0xFFF6EFE6),
                                    lipHeight: 2.2,
                                    child: AmodoroTheme.sysIcon(
                                      Symbols.keyboard_arrow_down,
                                      size: 18,
                                      color: index < ordered.length - 1
                                          ? ink
                                          : muted.withValues(alpha: 0.4),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      AmodoroPressableButton(
                        onTap: saving
                            ? null
                            : () async {
                                setModalState(() => saving = true);
                                try {
                                  await widget.api.reorderBoards(
                                    ordered.map((b) => b.id).toList(),
                                  );
                                  if (ctx.mounted) {
                                    Navigator.of(ctx).pop(true);
                                  }
                                } catch (e) {
                                  if (ctx.mounted) {
                                    setModalState(() => saving = false);
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          e.toString().replaceFirst(
                                                'Exception: ',
                                                '',
                                              ),
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                        height: 48,
                        radius: 999,
                        color: AmodoroTheme.coralPillLight,
                        lipColor: AmodoroTheme.coralPillBorderLight,
                        lipHeight: 3.5,
                        child: Text(
                          saving ? 'GUARDANDO ORDEN...' : 'GUARDAR ORDEN',
                          style: AmodoroTheme.googleSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.9,
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
      },
    );

    if (saved == true) {
      await widget.onRefresh();
    }
  }

  /// Submenú para crear o editar un tablero usando AmodoroTheme.vibrantBoardPresets
  Future<void> _showBoardSubmenu({BoardModel? existing}) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    String selectedIcon = existing?.icon ?? 'bookmark';
    String selectedColor = existing?.bgColor ?? '#F27166';
    final isDefaultPendientes = existing?.slug == 'actividades';

    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final surface =
            isDark ? AmodoroTheme.darkContainer : AmodoroTheme.lightBackground;
        final boxSurface = isDark ? const Color(0xFF2D2727) : Colors.white;
        final ink = isDark ? AmodoroTheme.darkInk : AmodoroTheme.lightInk;
        final muted = isDark ? AmodoroTheme.darkMuted : AmodoroTheme.lightMuted;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                0,
                14,
                MediaQuery.of(ctx).viewInsets.bottom + 14,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                decoration: AmodoroTheme.cardOutlineBox(
                  color: surface,
                  radius: 30,
                  borderColor: AmodoroTheme.parseHexColor(
                    selectedColor,
                    fallback: AmodoroTheme.coralPillLight,
                  ),
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
                          Expanded(
                            child: Text(
                              existing == null
                                  ? 'NUEVA LISTA COMPARTIDA'
                                  : 'EDITAR LISTA · ${existing.title.toUpperCase()}',
                              style: AmodoroTheme.googleSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: ink,
                                letterSpacing: 0.9,
                              ),
                            ),
                          ),
                          AmodoroPressableButton(
                            onTap: () => Navigator.of(ctx).pop(false),
                            width: 36,
                            height: 36,
                            radius: 999,
                            color: boxSurface,
                            borderColor: isDark
                                ? const Color(0xFF3E3636)
                                : const Color(0xFFE9E4DC),
                            borderWidth: 1.5,
                            lipHeight: 2.5,
                            child: AmodoroTheme.sysIcon(
                              Symbols.close,
                              size: 18,
                              color: ink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: AmodoroTheme.cardOutlineBox(
                          color: boxSurface,
                          radius: 999,
                          borderColor: isDark
                              ? const Color(0xFF3E3636)
                              : const Color(0xFFE9E4DC),
                          borderWidth: 1.5,
                          subtleShadow: false,
                        ),
                        child: TextField(
                          controller: titleCtrl,
                          style: AmodoroTheme.googleSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            labelText: 'NOMBRE DE LA LISTA',
                            labelStyle: AmodoroTheme.googleSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: muted,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'ICONO DE LA LISTA',
                        style: AmodoroTheme.googleSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: muted,
                          letterSpacing: 0.9,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _boardIconOptions.map((opt) {
                          final key = opt['key'] as String;
                          final iconData = opt['icon'] as IconData;
                          final sel = selectedIcon == key;
                          final activeColor = AmodoroTheme.parseHexColor(
                            selectedColor,
                            fallback: AmodoroTheme.coralPillLight,
                          );
                          return AmodoroPressableButton(
                            onTap: () =>
                                setModalState(() => selectedIcon = key),
                            width: 44,
                            height: 44,
                            radius: 999,
                            color: sel ? activeColor : boxSurface,
                            borderColor: sel
                                ? null
                                : (isDark
                                    ? const Color(0xFF3E3636)
                                    : const Color(0xFFE9E4DC)),
                            borderWidth: sel ? 0 : 1.5,
                            lipColor: sel
                                ? AmodoroTheme.darkenForPerspective(
                                    activeColor,
                                    0.18,
                                  )
                                : null,
                            lipHeight: 2.8,
                            child: AmodoroTheme.sysIcon(
                              iconData,
                              size: 20,
                              color: sel ? Colors.white : ink,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'COLOR VIBRANTE DE LA PÍLDORA Y BORDE',
                        style: AmodoroTheme.googleSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: muted,
                          letterSpacing: 0.9,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: AmodoroTheme.vibrantBoardPresets.map((p) {
                          final sel = selectedColor.toUpperCase() ==
                              p.hex.toUpperCase();
                          return AmodoroPressableButton(
                            onTap: () =>
                                setModalState(() => selectedColor = p.hex),
                            width: 38,
                            height: 38,
                            radius: 999,
                            color: p.color,
                            borderColor: sel ? ink : null,
                            borderWidth: sel ? 2.2 : 0,
                            lipColor: AmodoroTheme.darkenForPerspective(
                              p.color,
                              0.20,
                            ),
                            lipHeight: 2.8,
                            child: sel
                                ? AmodoroTheme.sysIcon(
                                    Symbols.check,
                                    size: 18,
                                    color: Colors.white,
                                  )
                                : const SizedBox.shrink(),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 22),
                      AmodoroPressableButton(
                        onTap: () async {
                          if (titleCtrl.text.trim().isEmpty) return;
                          if (existing == null) {
                            await widget.api.createBoard(
                              title: titleCtrl.text.trim(),
                              icon: selectedIcon,
                              bgColor: selectedColor,
                            );
                          } else {
                            await widget.api.updateBoard(
                              boardId: existing.id,
                              title: titleCtrl.text.trim(),
                              icon: selectedIcon,
                              bgColor: selectedColor,
                            );
                          }
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        },
                        height: 48,
                        radius: 999,
                        color: AmodoroTheme.parseHexColor(
                          selectedColor,
                          fallback: AmodoroTheme.coralPillLight,
                        ),
                        lipColor: AmodoroTheme.darkenForPerspective(
                          AmodoroTheme.parseHexColor(
                            selectedColor,
                            fallback: AmodoroTheme.coralPillLight,
                          ),
                          0.18,
                        ),
                        lipHeight: 3.5,
                        child: Text(
                          existing == null ? 'CREAR LISTA' : 'GUARDAR CAMBIOS',
                          style: AmodoroTheme.googleSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (existing != null && !isDefaultPendientes) ...[
                        const SizedBox(height: 12),
                        AmodoroPressableButton(
                          onTap: () async {
                            await widget.api.deleteBoard(existing.id);
                            if (_selectedBoardId == existing.id) {
                              _selectedBoardId = null;
                            }
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          },
                          height: 46,
                          radius: 999,
                          color: const Color(0xFFFFDAD6),
                          lipColor: const Color(0xFFE59890),
                          lipHeight: 3.0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AmodoroTheme.sysIcon(
                                Symbols.delete,
                                size: 18,
                                color: const Color(0xFF3B0D09),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'ELIMINAR LISTA',
                                style: AmodoroTheme.googleSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.9,
                                  color: const Color(0xFF3B0D09),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (changed == true) {
      await widget.onRefresh();
    }
  }

  /// Complete Activity Flow with Required Photo, Image, or Message (Section 2c)
  Future<void> _showCompleteActivitySheet(BoardCardItem item) async {
    final completionTextCtrl = TextEditingController();
    String? completionMediaDataUrl;
    String? validationError;
    bool saving = false;

    final completed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final surface =
            isDark ? AmodoroTheme.darkContainer : AmodoroTheme.lightBackground;
        final boxSurface = isDark ? const Color(0xFF2D2727) : Colors.white;
        final ink = isDark ? AmodoroTheme.darkInk : AmodoroTheme.lightInk;
        final muted = isDark ? AmodoroTheme.darkMuted : AmodoroTheme.lightMuted;

        Future<void> pickCompletionMedia(ImageSource source, StateSetter setModalState) async {
          try {
            final picked = await _picker.pickImage(
              source: source,
              maxWidth: 1440,
              maxHeight: 1440,
              imageQuality: 82,
            );
            if (picked != null) {
              final bytes = await picked.readAsBytes();
              setModalState(() {
                completionMediaDataUrl =
                    'data:image/jpeg;base64,${base64Encode(bytes)}';
                validationError = null;
              });
            }
          } catch (e) {
            setModalState(() {
              validationError = 'No se pudo abrir la cámara o galería.';
            });
          }
        }

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                0,
                14,
                MediaQuery.of(ctx).viewInsets.bottom + 14,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                // Border-only modal sheet (Strict Button vs Non-Button Rule)
                decoration: AmodoroTheme.cardOutlineBox(
                  color: surface,
                  radius: 30,
                  borderColor: const Color(0xFF10B981),
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
                          Expanded(
                            child: Text(
                              '¡COMPLETAR ACTIVIDAD JUNTOS! ✨',
                              style: AmodoroTheme.googleSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: ink,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          AmodoroPressableButton(
                            onTap: () => Navigator.of(ctx).pop(false),
                            width: 36,
                            height: 36,
                            radius: 999,
                            color: boxSurface,
                            borderColor: isDark
                                ? const Color(0xFF3E3636)
                                : const Color(0xFFE9E4DC),
                            borderWidth: 1.5,
                            lipHeight: 2.5,
                            child: AmodoroTheme.sysIcon(
                              Symbols.close,
                              size: 18,
                              color: ink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Para mover «${item.title}» al Historial juntos, sube una foto, imagen o escribe un mensaje de recuerdo.',
                        style: AmodoroTheme.googleSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: muted,
                          height: 1.38,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Two AmodoroPressableButton media buttons: TOMAR FOTO & SUBIR IMAGEN
                      Row(
                        children: [
                          Expanded(
                            child: AmodoroPressableButton(
                              onTap: () => pickCompletionMedia(
                                ImageSource.camera,
                                setModalState,
                              ),
                              height: 46,
                              radius: 999,
                              color: boxSurface,
                              borderColor: const Color(0xFF10B981),
                              borderWidth: 2.0,
                              lipColor: const Color(0xFF10B981),
                              lipHeight: 3.0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AmodoroTheme.sysIcon(
                                    Symbols.photo_camera,
                                    size: 18,
                                    color: const Color(0xFF10B981),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    'TOMAR FOTO',
                                    style: AmodoroTheme.googleSans(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: ink,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AmodoroPressableButton(
                              onTap: () => pickCompletionMedia(
                                ImageSource.gallery,
                                setModalState,
                              ),
                              height: 46,
                              radius: 999,
                              color: boxSurface,
                              borderColor: const Color(0xFF10B981),
                              borderWidth: 2.0,
                              lipColor: const Color(0xFF10B981),
                              lipHeight: 3.0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AmodoroTheme.sysIcon(
                                    Symbols.image,
                                    size: 18,
                                    color: const Color(0xFF10B981),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    'SUBIR IMAGEN',
                                    style: AmodoroTheme.googleSans(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: ink,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // 1:1 square preview if an image is selected
                      if (completionMediaDataUrl != null) ...[
                        const SizedBox(height: 14),
                        Stack(
                          children: [
                            AspectRatio(
                              aspectRatio: 1.0,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: _buildBoardItemMedia(
                                  completionMediaDataUrl!,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: AmodoroPressableButton(
                                onTap: () => setModalState(
                                  () => completionMediaDataUrl = null,
                                ),
                                width: 36,
                                height: 36,
                                radius: 999,
                                color: Colors.white,
                                lipColor: const Color(0xFFDFD8CE),
                                lipHeight: 2.5,
                                child: AmodoroTheme.sysIcon(
                                  Symbols.delete,
                                  size: 18,
                                  color: const Color(0xFFBA1A1A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 14),

                      // Multiline text input (border-only) for memory message
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: AmodoroTheme.cardOutlineBox(
                          color: boxSurface,
                          radius: 24,
                          borderColor: isDark
                              ? const Color(0xFF3E3636)
                              : const Color(0xFFE9E4DC),
                          borderWidth: 1.5,
                          subtleShadow: false,
                        ),
                        child: TextField(
                          controller: completionTextCtrl,
                          minLines: 3,
                          maxLines: 5,
                          onChanged: (_) {
                            if (validationError != null) {
                              setModalState(() => validationError = null);
                            }
                          },
                          style: AmodoroTheme.googleSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: ink,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText:
                                'Mensaje o recuerdo de la actividad... (ej. ¡Nos encantó el final!)',
                            hintStyle: AmodoroTheme.googleSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: muted,
                            ),
                          ),
                        ),
                      ),

                      if (validationError != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: AmodoroTheme.cardOutlineBox(
                            color: const Color(0xFFFFDAD6),
                            radius: 18,
                            borderColor: const Color(0xFFD6574D),
                            borderWidth: 1.5,
                            subtleShadow: false,
                          ),
                          child: Text(
                            validationError!,
                            style: AmodoroTheme.googleSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF3B0D09),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 18),

                      // Primary button GUARDAR EN HISTORIAL JUNTOS
                      AmodoroPressableButton(
                        onTap: saving
                            ? null
                            : () async {
                                final text = completionTextCtrl.text.trim();
                                if (completionMediaDataUrl == null &&
                                    text.isEmpty) {
                                  setModalState(() {
                                    validationError =
                                        'Sube una foto/imagen o escribe un mensaje para completar la actividad.';
                                  });
                                  return;
                                }
                                setModalState(() {
                                  saving = true;
                                  validationError = null;
                                });
                                try {
                                  await widget.api.completeBoardItem(
                                    itemId: item.id,
                                    completionText: text,
                                    mediaDataUrl: completionMediaDataUrl,
                                  );
                                  if (ctx.mounted) {
                                    Navigator.of(ctx).pop(true);
                                  }
                                } catch (e) {
                                  if (ctx.mounted) {
                                    setModalState(() {
                                      saving = false;
                                      validationError = e
                                          .toString()
                                          .replaceFirst('Exception: ', '');
                                    });
                                  }
                                }
                              },
                        height: 50,
                        radius: 999,
                        color: const Color(0xFF10B981),
                        lipColor: const Color(0xFF059669),
                        lipHeight: 3.5,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AmodoroTheme.sysIcon(
                              Symbols.check_circle,
                              size: 20,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              saving
                                  ? 'GUARDANDO EN HISTORIAL...'
                                  : 'GUARDAR EN HISTORIAL JUNTOS',
                              style: AmodoroTheme.googleSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.8,
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
      },
    );

    if (completed == true) {
      await widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Actividad guardada en su Historial juntos! ✨'),
          ),
        );
      }
    }
  }

  /// Quick options sheet when tapping the 3-dots button on any board item card.
  Future<void> _showItemQuickActionsMenu({
    required BoardModel board,
    required BoardCardItem item,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface =
        isDark ? AmodoroTheme.darkContainer : AmodoroTheme.lightBackground;
    final ink = isDark ? AmodoroTheme.darkInk : AmodoroTheme.lightInk;
    final muted = isDark ? AmodoroTheme.darkMuted : AmodoroTheme.lightMuted;
    final itemColor = _resolveItemVibrantColor(item, board);

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
              decoration: AmodoroTheme.cardOutlineBox(
                color: surface,
                radius: 30,
                borderColor: itemColor,
                borderWidth: 2.5,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AmodoroTheme.googleSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: ink,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                      AmodoroPressableButton(
                        onTap: () => Navigator.of(sheetCtx).pop(),
                        width: 34,
                        height: 34,
                        radius: 999,
                        color: isDark ? const Color(0xFF2D2727) : Colors.white,
                        borderColor: isDark
                            ? const Color(0xFF3E3636)
                            : const Color(0xFFE9E4DC),
                        borderWidth: 1.5,
                        lipHeight: 2.2,
                        child: AmodoroTheme.sysIcon(
                          Symbols.close,
                          size: 18,
                          color: ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Opciones de actividad',
                    style: AmodoroTheme.googleSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: muted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  AmodoroPressableButton(
                    onTap: () => Navigator.of(sheetCtx).pop('complete'),
                    height: 48,
                    radius: 999,
                    color: const Color(0xFF10B981),
                    lipColor: const Color(0xFF059669),
                    lipHeight: 3.5,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AmodoroTheme.sysIcon(
                          Symbols.check_circle,
                          size: 19,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'COMPLETAR JUNTOS ✨',
                          style: AmodoroTheme.googleSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  AmodoroPressableButton(
                    onTap: () => Navigator.of(sheetCtx).pop('edit'),
                    height: 46,
                    radius: 999,
                    color: isDark ? const Color(0xFF2D2727) : Colors.white,
                    borderColor: itemColor,
                    borderWidth: 2.0,
                    lipColor: itemColor,
                    lipHeight: 3.0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AmodoroTheme.sysIcon(
                          Symbols.edit,
                          size: 18,
                          color: itemColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'EDITAR ELEMENTO',
                          style: AmodoroTheme.googleSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: ink,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (board.slug != 'actividades') ...[
                    const SizedBox(height: 10),
                    AmodoroPressableButton(
                      onTap: () => Navigator.of(sheetCtx).pop('copy_pendientes'),
                      height: 46,
                      radius: 999,
                      color: isDark ? const Color(0xFF2D2727) : Colors.white,
                      borderColor: const Color(0xFFF27166),
                      borderWidth: 2.0,
                      lipColor: const Color(0xFFF27166),
                      lipHeight: 3.0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AmodoroTheme.sysIcon(
                            Symbols.schedule,
                            size: 18,
                            color: const Color(0xFFF27166),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'PASAR A PENDIENTES',
                            style: AmodoroTheme.googleSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: ink,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  AmodoroPressableButton(
                    onTap: () => Navigator.of(sheetCtx).pop('delete'),
                    height: 46,
                    radius: 999,
                    color: const Color(0xFFFFDAD6),
                    lipColor: const Color(0xFFE59890),
                    lipHeight: 3.0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AmodoroTheme.sysIcon(
                          Symbols.delete,
                          size: 18,
                          color: const Color(0xFF3B0D09),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ELIMINAR ELEMENTO',
                          style: AmodoroTheme.googleSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF3B0D09),
                            letterSpacing: 0.8,
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
    if (action == 'complete') {
      await _showCompleteActivitySheet(item);
    } else if (action == 'edit') {
      await _showItemSubmenu(board: board, existing: item);
    } else if (action == 'copy_pendientes') {
      await widget.api.copyToActividades(item.id);
      await widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pasado al tablero PENDIENTES')),
        );
      }
    } else if (action == 'delete') {
      await widget.api.deleteOrCompleteItem(item.id);
      await widget.onRefresh();
    }
  }

  /// Submenú para añadir o editar un elemento (con dueDate, selectores circulares e imagen 1440px)
  Future<void> _showItemSubmenu({
    required BoardModel board,
    BoardCardItem? existing,
  }) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final emojiCtrl = TextEditingController(text: existing?.emoji ?? '');
    final linkCtrl = TextEditingController(text: existing?.url ?? '');

    final categoryOptions = <String>{
      for (final b in widget.sync.boards) b.title.toUpperCase(),
    }.toList();
    if (categoryOptions.isEmpty) {
      categoryOptions.add('PENDIENTES');
    }

    String initialCat = (existing?.categoryTag ??
            (board.slug == 'actividades'
                ? (categoryOptions.length > 1
                    ? categoryOptions[1]
                    : categoryOptions.first)
                : board.title))
        .toUpperCase();
    if (!categoryOptions.contains(initialCat)) {
      categoryOptions.insert(0, initialCat);
    }
    String selectedCategory = initialCat;

    final defaultBoardHex =
        '#${_resolveBoardVibrantColor(board).value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    String bgColor = existing?.bgColor ?? defaultBoardHex;
    String? dueDate = existing?.dueDate;
    String? imageDataUrl;
    bool saving = false;

    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final surface =
            isDark ? AmodoroTheme.darkContainer : AmodoroTheme.lightBackground;
        final boxSurface = isDark ? const Color(0xFF2D2727) : Colors.white;
        final ink = isDark ? AmodoroTheme.darkInk : AmodoroTheme.lightInk;
        final muted = isDark ? AmodoroTheme.darkMuted : AmodoroTheme.lightMuted;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final boardButtonColor = _resolveBoardVibrantColor(board);

            return Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                0,
                14,
                MediaQuery.of(ctx).viewInsets.bottom + 14,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                decoration: AmodoroTheme.cardOutlineBox(
                  color: surface,
                  radius: 30,
                  borderColor: boardButtonColor,
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
                          Expanded(
                            child: Text(
                              existing == null
                                  ? 'AÑADIR A ${board.title.toUpperCase()}'
                                  : 'EDITAR ELEMENTO',
                              style: AmodoroTheme.googleSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: ink,
                                letterSpacing: 0.9,
                              ),
                            ),
                          ),
                          AmodoroPressableButton(
                            onTap: () => Navigator.of(ctx).pop(false),
                            width: 36,
                            height: 36,
                            radius: 999,
                            color: boxSurface,
                            borderColor: isDark
                                ? const Color(0xFF3E3636)
                                : const Color(0xFFE9E4DC),
                            borderWidth: 1.5,
                            lipHeight: 2.5,
                            child: AmodoroTheme.sysIcon(
                              Symbols.close,
                              size: 18,
                              color: ink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Container(
                              height: 48,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              decoration: AmodoroTheme.cardOutlineBox(
                                color: boxSurface,
                                radius: 999,
                                borderColor: isDark
                                    ? const Color(0xFF3E3636)
                                    : const Color(0xFFE9E4DC),
                                borderWidth: 1.5,
                                subtleShadow: false,
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedCategory,
                                  isExpanded: true,
                                  borderRadius: BorderRadius.circular(24),
                                  icon: AmodoroTheme.sysIcon(
                                    Symbols.expand_more,
                                    size: 18,
                                    color: ink,
                                  ),
                                  items: categoryOptions.map((cat) {
                                    return DropdownMenuItem<String>(
                                      value: cat,
                                      child: Text(
                                        cat,
                                        overflow: TextOverflow.ellipsis,
                                        style: AmodoroTheme.googleSans(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: ink,
                                          letterSpacing: 0.7,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setModalState(
                                          () => selectedCategory = val);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: Container(
                              height: 48,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              decoration: AmodoroTheme.cardOutlineBox(
                                color: boxSurface,
                                radius: 999,
                                borderColor: isDark
                                    ? const Color(0xFF3E3636)
                                    : const Color(0xFFE9E4DC),
                                borderWidth: 1.5,
                                subtleShadow: false,
                              ),
                              child: Center(
                                child: TextField(
                                  controller: emojiCtrl,
                                  style: AmodoroTheme.googleSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: ink,
                                  ),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'EMOJI OPC.',
                                    hintStyle: AmodoroTheme.googleSans(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: muted,
                                    ),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: AmodoroTheme.cardOutlineBox(
                          color: boxSurface,
                          radius: 999,
                          borderColor: isDark
                              ? const Color(0xFF3E3636)
                              : const Color(0xFFE9E4DC),
                          borderWidth: 1.5,
                          subtleShadow: false,
                        ),
                        child: TextField(
                          controller: titleCtrl,
                          style: AmodoroTheme.googleSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            labelText:
                                'TÍTULO (EJ. VER SNOOPY, JUGAR MINECRAFT)',
                            labelStyle: AmodoroTheme.googleSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: muted,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: AmodoroTheme.cardOutlineBox(
                          color: boxSurface,
                          radius: 999,
                          borderColor: isDark
                              ? const Color(0xFF3E3636)
                              : const Color(0xFFE9E4DC),
                          borderWidth: 1.5,
                          subtleShadow: false,
                        ),
                        child: TextField(
                          controller: notesCtrl,
                          style: AmodoroTheme.googleSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: ink,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            labelText: 'NOTAS OPCIONALES',
                            labelStyle: AmodoroTheme.googleSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: muted,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Link embebido e Imagen adjunta
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              decoration: AmodoroTheme.cardOutlineBox(
                                color: boxSurface,
                                radius: 999,
                                borderColor: isDark
                                    ? const Color(0xFF3E3636)
                                    : const Color(0xFFE9E4DC),
                                borderWidth: 1.5,
                                subtleShadow: false,
                              ),
                              child: TextField(
                                controller: linkCtrl,
                                style: AmodoroTheme.googleSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: ink,
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Link (Spotify, YT, IG...)',
                                  hintStyle: AmodoroTheme.googleSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: muted,
                                  ),
                                  icon: AmodoroTheme.sysIcon(
                                    Symbols.link,
                                    size: 18,
                                    color: muted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (existing == null) ...[
                            const SizedBox(width: 10),
                            AmodoroPressableButton(
                              onTap: () async {
                                final picked = await _picker.pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 1440,
                                  maxHeight: 1440,
                                  imageQuality: 82,
                                );
                                if (picked != null) {
                                  final bytes = await picked.readAsBytes();
                                  setModalState(() {
                                    imageDataUrl =
                                        'data:image/jpeg;base64,${base64Encode(bytes)}';
                                  });
                                }
                              },
                              height: 48,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              radius: 999,
                              color: imageDataUrl != null
                                  ? const Color(0xFF10B981)
                                  : boxSurface,
                              borderColor: imageDataUrl != null
                                  ? null
                                  : boardButtonColor,
                              borderWidth: imageDataUrl != null ? 0 : 2.0,
                              lipColor: imageDataUrl != null
                                  ? const Color(0xFF059669)
                                  : boardButtonColor,
                              lipHeight: 3.0,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AmodoroTheme.sysIcon(
                                    Symbols.image,
                                    size: 18,
                                    color: imageDataUrl != null
                                        ? Colors.white
                                        : boardButtonColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    imageDataUrl != null ? 'LISTA' : 'IMAGEN',
                                    style: AmodoroTheme.googleSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.7,
                                      color: imageDataUrl != null
                                          ? Colors.white
                                          : ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Optional FECHA / RECORDATORIO button (Requirement F8 / Section E)
                      Row(
                        children: [
                          Expanded(
                            child: AmodoroPressableButton(
                              onTap: () async {
                                final now = DateTime.now();
                                final pickedDate = await showDatePicker(
                                  context: ctx,
                                  initialDate: now,
                                  firstDate:
                                      now.subtract(const Duration(days: 365)),
                                  lastDate:
                                      now.add(const Duration(days: 365 * 5)),
                                );
                                if (pickedDate != null) {
                                  final formatted =
                                      '${pickedDate.year.toString().padLeft(4, '0')}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';
                                  setModalState(() => dueDate = formatted);
                                }
                              },
                              height: 44,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              radius: 999,
                              color: boxSurface,
                              borderColor: dueDate != null && dueDate!.isNotEmpty
                                  ? boardButtonColor
                                  : (isDark
                                      ? const Color(0xFF3E3636)
                                      : const Color(0xFFE9E4DC)),
                              borderWidth:
                                  dueDate != null && dueDate!.isNotEmpty
                                      ? 2.0
                                      : 1.5,
                              lipColor: dueDate != null && dueDate!.isNotEmpty
                                  ? boardButtonColor
                                  : (isDark
                                      ? const Color(0xFF221D1D)
                                      : const Color(0xFFDFD8CE)),
                              lipHeight: 2.8,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AmodoroTheme.sysIcon(
                                    Symbols.calendar_month,
                                    size: 18,
                                    color: boardButtonColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    dueDate != null && dueDate!.isNotEmpty
                                        ? 'FECHA: $dueDate'
                                        : 'FECHA / RECORDATORIO (OPCIONAL)',
                                    style: AmodoroTheme.googleSans(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: ink,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (dueDate != null && dueDate!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            AmodoroPressableButton(
                              onTap: () => setModalState(() => dueDate = ''),
                              width: 44,
                              height: 44,
                              radius: 999,
                              color: boxSurface,
                              borderColor: isDark
                                  ? const Color(0xFF3E3636)
                                  : const Color(0xFFE9E4DC),
                              borderWidth: 1.5,
                              lipHeight: 2.5,
                              child: AmodoroTheme.sysIcon(
                                Symbols.close,
                                size: 18,
                                color: muted,
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 14),
                      Text(
                        'COLOR DEL BORDE',
                        style: AmodoroTheme.googleSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: muted,
                          letterSpacing: 0.9,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: AmodoroTheme.vibrantBoardPresets.map((p) {
                          final sel =
                              bgColor.toUpperCase() == p.hex.toUpperCase();
                          return AmodoroPressableButton(
                            onTap: () => setModalState(() => bgColor = p.hex),
                            width: 34,
                            height: 34,
                            radius: 999,
                            color: p.color,
                            borderColor: sel ? ink : null,
                            borderWidth: sel ? 2.0 : 0,
                            lipColor: AmodoroTheme.darkenForPerspective(
                              p.color,
                              0.20,
                            ),
                            lipHeight: 2.6,
                            child: sel
                                ? AmodoroTheme.sysIcon(
                                    Symbols.check,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : const SizedBox.shrink(),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      AmodoroPressableButton(
                        onTap: saving
                            ? null
                            : () async {
                                if (titleCtrl.text.trim().isEmpty &&
                                    linkCtrl.text.trim().isEmpty) {
                                  return;
                                }
                                setModalState(() => saving = true);
                                if (existing == null) {
                                  await widget.api.addBoardItem(
                                    boardId: board.id,
                                    title: titleCtrl.text.trim(),
                                    notes: notesCtrl.text.trim(),
                                    categoryTag: selectedCategory,
                                    emoji: emojiCtrl.text.trim(),
                                    bgColor: bgColor,
                                    mediaDataUrl: imageDataUrl,
                                    linkUrl: linkCtrl.text.trim(),
                                    dueDate: dueDate,
                                  );
                                } else {
                                  await widget.api.updateBoardItem(
                                    itemId: existing.id,
                                    title: titleCtrl.text.trim(),
                                    notes: notesCtrl.text.trim(),
                                    categoryTag: selectedCategory,
                                    emoji: emojiCtrl.text.trim(),
                                    bgColor: bgColor,
                                    linkUrl: linkCtrl.text.trim(),
                                    dueDate: dueDate,
                                  );
                                }
                                if (ctx.mounted) Navigator.pop(ctx, true);
                              },
                        height: 48,
                        radius: 999,
                        color: boardButtonColor,
                        lipColor: AmodoroTheme.darkenForPerspective(
                          boardButtonColor,
                          0.18,
                        ),
                        lipHeight: 3.5,
                        child: Text(
                          saving
                              ? 'GUARDANDO...'
                              : (existing == null
                                  ? 'GUARDAR EN ${board.title.toUpperCase()}'
                                  : 'GUARDAR CAMBIOS'),
                          style: AmodoroTheme.googleSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.9,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      if (existing != null) ...[
                        const SizedBox(height: 10),
                        AmodoroPressableButton(
                          onTap: () {
                            Navigator.of(ctx).pop(false);
                            _showCompleteActivitySheet(existing);
                          },
                          height: 46,
                          radius: 999,
                          color: const Color(0xFF10B981),
                          lipColor: const Color(0xFF059669),
                          lipHeight: 3.2,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AmodoroTheme.sysIcon(
                                Symbols.check_circle,
                                size: 18,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'COMPLETAR JUNTOS ✨',
                                style: AmodoroTheme.googleSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (board.slug != 'actividades') ...[
                          const SizedBox(height: 10),
                          AmodoroPressableButton(
                            onTap: () async {
                              await widget.api.copyToActividades(existing.id);
                              if (ctx.mounted) Navigator.pop(ctx, true);
                            },
                            height: 44,
                            radius: 999,
                            color: boxSurface,
                            borderColor: const Color(0xFFF27166),
                            borderWidth: 2.0,
                            lipColor: const Color(0xFFF27166),
                            lipHeight: 2.8,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AmodoroTheme.sysIcon(
                                  Symbols.schedule,
                                  size: 18,
                                  color: const Color(0xFFF27166),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'PASAR A PENDIENTES',
                                  style: AmodoroTheme.googleSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.9,
                                    color: ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        AmodoroPressableButton(
                          onTap: () async {
                            await widget.api.deleteOrCompleteItem(existing.id);
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          },
                          height: 44,
                          radius: 999,
                          color: const Color(0xFFFFDAD6),
                          lipColor: const Color(0xFFE59890),
                          lipHeight: 2.8,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AmodoroTheme.sysIcon(
                                Symbols.delete,
                                size: 18,
                                color: const Color(0xFF3B0D09),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'ELIMINAR ELEMENTO',
                                style: AmodoroTheme.googleSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.9,
                                  color: const Color(0xFF3B0D09),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (changed == true) {
      await widget.onRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeBoard = _activeBoard;
    if (activeBoard == null) {
      return const Center(child: Text('Sin tableros'));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AmodoroTheme.darkInk : AmodoroTheme.lightInk;
    final muted = isDark ? AmodoroTheme.darkMuted : AmodoroTheme.lightMuted;
    final isPendientes = activeBoard.slug == 'actividades';

    // Filter items by _searchQuery (Requirement F6)
    final q = _searchQuery.trim().toLowerCase();
    final filteredItems = q.isEmpty
        ? activeBoard.items
        : activeBoard.items.where((item) {
            return item.title.toLowerCase().contains(q) ||
                item.notes.toLowerCase().contains(q) ||
                item.categoryTag.toLowerCase().contains(q);
          }).toList();

    // Build 2-column grid
    final col1 = <Widget>[];
    final col2 = <Widget>[];

    for (int i = 0; i < filteredItems.length; i++) {
      final item = filteredItems[i];
      final cardWidget = Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _buildBoardItemCard(
          context,
          board: activeBoard,
          item: item,
          isPendientes: isPendientes,
          isDark: isDark,
        ),
      );
      if (i.isEven) {
        col1.add(cardWidget);
      } else {
        col2.add(cardWidget);
      }
    }

    final addButtonColor = _resolveBoardVibrantColor(activeBoard);

    return Column(
      children: [
        // A. Horizontal Board Filter Pills (Mockup Section 5.2)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
          child: Row(
            children: [
              ...widget.sync.boards.map((board) {
                final isSelected = board.id == activeBoard.id;
                final boardColor = _resolveBoardVibrantColor(board);
                final displayTitle = board.title.trim().isEmpty
                    ? 'PENDIENTES'
                    : board.title.trim();
                final int itemCount = board.items.length;

                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: AmodoroPressableButton(
                    onTap: () => setState(() => _selectedBoardId = board.id),
                    onLongPress: () => _showBoardSubmenu(existing: board),
                    radius: 999,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    constraints: const BoxConstraints(minHeight: 42),
                    color: isSelected
                        ? boardColor
                        : (isDark ? AmodoroTheme.darkContainer : Colors.white),
                    borderColor: isSelected ? null : boardColor,
                    borderWidth: isSelected ? 0 : 2.0,
                    lipColor: isSelected
                        ? AmodoroTheme.darkenForPerspective(boardColor, 0.18)
                        : boardColor,
                    lipHeight: isSelected ? 3.5 : 3.0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildBoardPillLeadingIcon(
                          board,
                          tintColor: isSelected ? Colors.white : boardColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          displayTitle.toUpperCase(),
                          style: AmodoroTheme.googleSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.7,
                            color: isSelected ? Colors.white : ink,
                          ),
                        ),
                        if (itemCount > 0) ...[
                          const SizedBox(width: 5),
                          Text(
                            '$itemCount',
                            style: AmodoroTheme.googleSans(
                              fontSize: 10.0,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.72)
                                  : muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),

              // + LISTA button
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AmodoroPressableButton(
                  onTap: () => _showBoardSubmenu(),
                  radius: 999,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 9,
                  ),
                  constraints: const BoxConstraints(minHeight: 42),
                  color: isDark ? AmodoroTheme.darkContainer : Colors.white,
                  borderColor: isDark
                      ? const Color(0xFF383232)
                      : const Color(0xFFD8D0C5),
                  borderWidth: 2.0,
                  lipColor: isDark
                      ? const Color(0xFF282323)
                      : const Color(0xFFC8BFB3),
                  lipHeight: 3.0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AmodoroTheme.sysIcon(
                        Symbols.add,
                        size: 16,
                        color: ink,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'LISTA',
                        style: AmodoroTheme.googleSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                          color: ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ORDENAR icon button (Requirement F7)
              AmodoroPressableButton(
                onTap: _showReorderBoardsSheet,
                width: 42,
                height: 42,
                radius: 999,
                color: isDark ? AmodoroTheme.darkContainer : Colors.white,
                borderColor: isDark
                    ? const Color(0xFF383232)
                    : const Color(0xFFD8D0C5),
                borderWidth: 2.0,
                lipColor: isDark
                    ? const Color(0xFF282323)
                    : const Color(0xFFC8BFB3),
                lipHeight: 3.0,
                child: AmodoroTheme.sysIcon(
                  Symbols.swap_vert,
                  size: 18,
                  color: ink,
                ),
              ),
            ],
          ),
        ),

        // B. Action Row Below Board Pills (DECIDIR + HISTORIAL + Search/Filter)
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
          child: Row(
            children: [
              // DECIDIR button
              Expanded(
                child: AmodoroPressableButton(
                  onTap: _openDecideModal,
                  color: const Color(0xFFF2827A),
                  lipColor: const Color(0xFFD6574D),
                  lipHeight: 3.5,
                  radius: 999,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AmodoroTheme.sysIcon(
                        Symbols.casino,
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          'DECIDIR',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AmodoroTheme.googleSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.9,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // HISTORIAL button
              Expanded(
                child: AmodoroPressableButton(
                  onTap: _openCompletedHistoryScreen,
                  color: isDark ? AmodoroTheme.darkContainer : Colors.white,
                  borderColor: const Color(0xFF10B981),
                  borderWidth: 2.0,
                  lipColor: const Color(0xFF10B981),
                  lipHeight: 3.0,
                  radius: 999,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AmodoroTheme.sysIcon(
                        Symbols.photo_library,
                        size: 17,
                        color: const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'HISTORIAL',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AmodoroTheme.googleSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: ink,
                          ),
                        ),
                      ),
                      if (widget.sync.completedHistory.isNotEmpty) ...[
                        const SizedBox(width: 5),
                        Text(
                          '${widget.sync.completedHistory.length}',
                          style: AmodoroTheme.googleSans(
                            fontSize: 10.0,
                            fontWeight: FontWeight.w700,
                            color: muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Search toggle button
              AmodoroPressableButton(
                onTap: () {
                  setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) {
                      _searchController.clear();
                      _searchQuery = '';
                    }
                  });
                },
                width: 44,
                height: 42,
                radius: 999,
                color: _showSearch
                    ? addButtonColor
                    : (isDark ? AmodoroTheme.darkContainer : Colors.white),
                borderColor: _showSearch
                    ? null
                    : (isDark
                        ? const Color(0xFF383232)
                        : const Color(0xFFD8D0C5)),
                borderWidth: _showSearch ? 0 : 2.0,
                lipColor: _showSearch
                    ? AmodoroTheme.darkenForPerspective(addButtonColor, 0.18)
                    : (isDark
                        ? const Color(0xFF282323)
                        : const Color(0xFFC8BFB3)),
                lipHeight: 3.0,
                child: AmodoroTheme.sysIcon(
                  _showSearch ? Symbols.close : Symbols.search,
                  size: 19,
                  color: _showSearch ? Colors.white : ink,
                ),
              ),
            ],
          ),
        ),

        // Inline Search Bar when toggled (Requirement F6 - border-only container)
        if (_showSearch)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              decoration: AmodoroTheme.cardOutlineBox(
                color: isDark ? AmodoroTheme.darkContainer : Colors.white,
                radius: 999,
                borderColor: addButtonColor,
                borderWidth: 1.8,
                subtleShadow: false,
              ),
              child: Row(
                children: [
                  AmodoroTheme.sysIcon(
                    Symbols.search,
                    size: 19,
                    color: addButtonColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: AmodoroTheme.googleSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: ink,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText:
                            'Buscar en ${activeBoard.title.toLowerCase()}...',
                        hintStyle: AmodoroTheme.googleSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: muted,
                        ),
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      child: AmodoroTheme.sysIcon(
                        Symbols.close,
                        size: 18,
                        color: muted,
                      ),
                    ),
                ],
              ),
            ),
          ),

        // C. 2-Column Masonry Grid of Board Item Cards
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            color: addButtonColor,
            child: filteredItems.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(22, 36, 22, 24),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(26),
                        decoration: AmodoroTheme.cardOutlineBox(
                          color:
                              isDark ? AmodoroTheme.darkContainer : Colors.white,
                          radius: 30,
                          borderColor: addButtonColor.withValues(alpha: 0.55),
                          borderWidth: 2.5,
                        ),
                        child: Column(
                          children: [
                            AmodoroTheme.sysIcon(
                              AmodoroTheme.boardIconFromName(
                                activeBoard.icon,
                                activeBoard.slug,
                              ),
                              size: 32,
                              color: addButtonColor,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              q.isNotEmpty
                                  ? 'SIN RESULTADOS EN ${activeBoard.title.toUpperCase()}'
                                  : 'TU LISTA ${activeBoard.title.toUpperCase()} ESTÁ VACÍA',
                              textAlign: TextAlign.center,
                              style: AmodoroTheme.googleSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: ink,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              q.isNotEmpty
                                  ? 'Prueba buscando con otro término.'
                                  : 'Añade planes, canciones, pelis, series o juegos para disfrutar juntos.',
                              textAlign: TextAlign.center,
                              style: AmodoroTheme.googleSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: muted,
                                height: 1.38,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Column(children: col1)),
                          const SizedBox(width: 14),
                          Expanded(child: Column(children: col2)),
                        ],
                      ),
                    ],
                  ),
          ),
        ),

        // Bottom Add Item Button (AmodoroPressableButton in active board's vibrant color)
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
          child: AmodoroPressableButton(
            onTap: () => _showItemSubmenu(board: activeBoard),
            height: 48,
            radius: 999,
            color: addButtonColor,
            lipColor: AmodoroTheme.darkenForPerspective(addButtonColor, 0.20),
            lipHeight: 3.5,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AmodoroTheme.sysIcon(
                  Symbols.add,
                  size: 20,
                  color: Colors.white,
                ),
                const SizedBox(width: 7),
                Text(
                  'AÑADIR A ${activeBoard.title.toUpperCase()}',
                  style: AmodoroTheme.googleSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Board Item Card in 2-Column Grid — BORDER ONLY, NO 3D LIP (Section 5.4)
  Widget _buildBoardItemCard(
    BuildContext context, {
    required BoardModel board,
    required BoardCardItem item,
    required bool isPendientes,
    required bool isDark,
  }) {
    final itemVibrantColor = _resolveItemVibrantColor(item, board);
    final ink = isDark ? AmodoroTheme.darkInk : AmodoroTheme.lightInk;
    final muted = isDark ? AmodoroTheme.darkMuted : AmodoroTheme.lightMuted;
    final cardSurface = isDark ? AmodoroTheme.darkContainer : Colors.white;
    final emojis = widget.sync.reactionEmojis.isNotEmpty
        ? widget.sync.reactionEmojis
        : _defaultEmojis;
    final myReaction = item.reactions
        .where((r) =>
            r.userId == widget.sync.me.id &&
            r.emoji != null &&
            r.emoji!.isNotEmpty)
        .firstOrNull;
    final partnerReaction = item.reactions
        .where((r) =>
            r.userId != widget.sync.me.id &&
            r.emoji != null &&
            r.emoji!.isNotEmpty)
        .firstOrNull;

    return GestureDetector(
      onTap: () => _showItemDetailModal(board: board, item: item),
      onLongPress: () => _showItemQuickActionsMenu(board: board, item: item),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        // STRICT RULE: Border-only card, NO 3D bottom lip!
        decoration: AmodoroTheme.cardOutlineBox(
          color: cardSurface,
          radius: 30,
          borderColor: itemVibrantColor,
          borderWidth: 2.5,
          subtleShadow: true,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Category pill + 3-dots AmodoroPressableButton
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: itemVibrantColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.categoryTag.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AmodoroTheme.googleSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: itemVibrantColor,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                AmodoroPressableButton(
                  onTap: () =>
                      _showItemQuickActionsMenu(board: board, item: item),
                  width: 34,
                  height: 34,
                  radius: 999,
                  color: isDark
                      ? const Color(0xFF2D2727)
                      : const Color(0xFFF6EFE6),
                  borderColor: isDark
                      ? const Color(0xFF3E3636)
                      : const Color(0xFFE6DFD5),
                  borderWidth: 1.2,
                  lipColor: isDark
                      ? const Color(0xFF201C1C)
                      : const Color(0xFFD6CEC2),
                  lipHeight: 2.2,
                  child: AmodoroTheme.sysIcon(
                    Symbols.more_horiz,
                    size: 17,
                    color: ink,
                  ),
                ),
              ],
            ),

            // Optional dueDate badge (Requirement F8)
            if (item.dueDate != null && item.dueDate!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2D2727)
                      : const Color(0xFFFAF6F0),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: itemVibrantColor.withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                ),
                child: Text(
                  '📅 ${item.dueDate!.trim()}',
                  style: AmodoroTheme.googleSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 10),

            // Optional 1:1 square image (tappable for FullscreenMediaViewer)
            if (item.mediaUrl != null && item.mediaUrl!.isNotEmpty) ...[
              Builder(
                builder: (_) {
                  final resolvedUrl = widget.api.resolveMediaUrl(item.mediaUrl);
                  final heroTag = 'board_card_media_${item.id}';
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
                          borderRadius: BorderRadius.circular(24),
                          child: _buildBoardItemMedia(resolvedUrl),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],

            // Optional LinkPreviewCard
            if (item.url != null && item.url!.isNotEmpty) ...[
              LinkPreviewCard(
                url: item.url!,
                title: item.linkTitle ?? item.title,
                thumbnail: item.linkThumbnail,
                platform: item.linkPlatform,
                cardBgColor: cardSurface,
              ),
              const SizedBox(height: 10),
            ],

            // Title (FontWeight.w800, 15sp)
            Text(
              item.emoji.isNotEmpty
                  ? '${item.title} ${item.emoji}'.trim()
                  : item.title,
              style: AmodoroTheme.googleSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: ink,
                height: 1.26,
              ),
            ),

            // Notes preview (maxLines: 2, FontWeight.w600)
            if (item.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                item.notes.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AmodoroTheme.googleSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: muted,
                  height: 1.32,
                ),
              ),
            ],
            const SizedBox(height: 10),

            // Author row
            Row(
              children: [
                FlatAvatarBadge(
                  avatarId: item.authorAvatarId,
                  size: 20,
                  borderWidth: 1.5,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    item.authorLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AmodoroTheme.googleSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: muted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Emoji Reaction Dock (Before reacting -> dock of emojis; After reacting -> only chosen emoji) + partner's reaction
            Row(
              children: [
                if (myReaction == null)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: AmodoroTheme.cardOutlineBox(
                        color: isDark
                            ? const Color(0xFF2D2727)
                            : const Color(0xFFFAF6F0),
                        radius: 999,
                        borderColor: itemVibrantColor.withValues(alpha: 0.45),
                        borderWidth: 1.4,
                        subtleShadow: false,
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: emojis.map((emoji) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              child: AmodoroPressableButton(
                                onTap: () async {
                                  try {
                                    await widget.api.reactToBoardItem(
                                      itemId: item.id,
                                      emoji: emoji,
                                    );
                                    await widget.onRefresh();
                                  } catch (_) {}
                                },
                                width: 32,
                                height: 32,
                                radius: 999,
                                color: isDark
                                    ? AmodoroTheme.darkContainer
                                    : Colors.white,
                                borderColor: isDark
                                    ? const Color(0xFF3E3636)
                                    : const Color(0xFFE6DFD5),
                                borderWidth: 1.0,
                                lipHeight: 1.8,
                                child: Text(
                                  emoji,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    height: 1.05,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  )
                else
                  AmodoroPressableButton(
                    onTap: () async {
                      try {
                        await widget.api.reactToBoardItem(
                          itemId: item.id,
                          emoji: myReaction.emoji,
                        );
                        await widget.onRefresh();
                      } catch (_) {}
                    },
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    radius: 999,
                    color: itemVibrantColor.withValues(alpha: 0.16),
                    borderColor: itemVibrantColor,
                    borderWidth: 1.8,
                    lipColor: itemVibrantColor,
                    lipHeight: 2.4,
                    child: Text(
                      myReaction.emoji!,
                      style: const TextStyle(
                        fontSize: 22,
                        height: 1.05,
                      ),
                    ),
                  ),
                if (partnerReaction != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    decoration: AmodoroTheme.cardOutlineBox(
                      color: isDark
                          ? const Color(0xFF2D2727)
                          : const Color(0xFFF6EFE6),
                      radius: 999,
                      borderColor: isDark
                          ? const Color(0xFF3E3636)
                          : const Color(0xFFE6DFD5),
                      borderWidth: 1.4,
                      subtleShadow: false,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FlatAvatarBadge(
                          avatarId: partnerReaction.authorAvatarId,
                          size: 18,
                          borderWidth: 1.2,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          partnerReaction.emoji!,
                          style: const TextStyle(
                            fontSize: 20,
                            height: 1.05,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Expanded Board Item Detail Modal (wired with COMPLETAR JUNTOS ✨, EDITAR, ELIMINAR & reactions)
  Future<void> _showItemDetailModal({
    required BoardModel board,
    required BoardCardItem item,
  }) async {
    bool busy = false;
    final emojis = widget.sync.reactionEmojis.isNotEmpty
        ? widget.sync.reactionEmojis
        : _defaultEmojis;

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final cardSurface = isDark ? AmodoroTheme.darkContainer : Colors.white;
        final itemVibrantColor = _resolveItemVibrantColor(item, board);
        final ink = isDark ? AmodoroTheme.darkInk : AmodoroTheme.lightInk;
        final muted = isDark ? AmodoroTheme.darkMuted : AmodoroTheme.lightMuted;
        final pillFill =
            isDark ? const Color(0xFF2D2727) : const Color(0xFFF6EFE6);

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final myReaction = item.reactions
                .where((r) =>
                    r.userId == widget.sync.me.id &&
                    r.emoji != null &&
                    r.emoji!.isNotEmpty)
                .firstOrNull;
            final partnerReaction = item.reactions
                .where((r) =>
                    r.userId != widget.sync.me.id &&
                    r.emoji != null &&
                    r.emoji!.isNotEmpty)
                .firstOrNull;

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.86,
                ),
                padding: const EdgeInsets.all(20),
                // Border-only modal container
                decoration: AmodoroTheme.cardOutlineBox(
                  color: cardSurface,
                  radius: 30,
                  borderColor: itemVibrantColor,
                  borderWidth: 2.5,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row: Category · Board title + Edit & Close buttons
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${item.categoryTag.toUpperCase()} · ${board.title.toUpperCase()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AmodoroTheme.googleSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.9,
                              color: itemVibrantColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AmodoroPressableButton(
                          onTap: () => Navigator.of(ctx).pop('edit'),
                          width: 36,
                          height: 36,
                          radius: 999,
                          color: pillFill,
                          borderColor: isDark
                              ? const Color(0xFF3E3636)
                              : const Color(0xFFE2DDD4),
                          borderWidth: 1.5,
                          lipHeight: 2.2,
                          child: AmodoroTheme.sysIcon(
                            Symbols.edit,
                            size: 18,
                            color: ink,
                          ),
                        ),
                        const SizedBox(width: 8),
                        AmodoroPressableButton(
                          onTap: () => Navigator.of(ctx).pop(),
                          width: 36,
                          height: 36,
                          radius: 999,
                          color: pillFill,
                          borderColor: isDark
                              ? const Color(0xFF3E3636)
                              : const Color(0xFFE2DDD4),
                          borderWidth: 1.5,
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

                    // Scrollable content
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.dueDate != null &&
                                item.dueDate!.trim().isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: pillFill,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color:
                                        itemVibrantColor.withValues(alpha: 0.5),
                                    width: 1.4,
                                  ),
                                ),
                                child: Text(
                                  '📅 Fecha: ${item.dueDate!.trim()}',
                                  style: AmodoroTheme.googleSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: ink,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (item.mediaUrl != null &&
                                item.mediaUrl!.isNotEmpty) ...[
                              Builder(
                                builder: (_) {
                                  final resolvedUrl =
                                      widget.api.resolveMediaUrl(item.mediaUrl);
                                  final heroTag =
                                      'board_detail_media_${item.id}';
                                  return GestureDetector(
                                    onTap: () => FullscreenMediaViewer.open(
                                      ctx,
                                      imageUrl: resolvedUrl,
                                      heroTag: heroTag,
                                    ),
                                    child: Hero(
                                      tag: heroTag,
                                      child: AspectRatio(
                                        aspectRatio: 1.0,
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(24),
                                          child: _buildBoardItemMedia(
                                            resolvedUrl,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 14),
                            ],
                            if (item.url != null && item.url!.isNotEmpty) ...[
                              LinkPreviewCard(
                                url: item.url!,
                                title: item.linkTitle ?? item.title,
                                thumbnail: item.linkThumbnail,
                                platform: item.linkPlatform,
                                cardBgColor: cardSurface,
                              ),
                              const SizedBox(height: 14),
                            ],
                            if (item.title.isNotEmpty || item.emoji.isNotEmpty)
                              Text(
                                item.emoji.isNotEmpty
                                    ? '${item.title} ${item.emoji}'.trim()
                                    : item.title,
                                style: AmodoroTheme.googleSans(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: ink,
                                  height: 1.28,
                                ),
                              ),
                            if (item.notes.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              SelectableText(
                                item.notes,
                                style: AmodoroTheme.googleSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: ink.withValues(alpha: 0.85),
                                  height: 1.45,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),

                            // Emoji Reaction Dock inside detail modal (Dock before reacting -> Chosen emoji after reacting + partner reaction)
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
                                      color: pillFill,
                                      radius: 999,
                                      borderColor: itemVibrantColor.withValues(
                                        alpha: 0.5,
                                      ),
                                      borderWidth: 1.5,
                                      subtleShadow: false,
                                    ),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: emojis.map((emoji) {
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 3,
                                            ),
                                            child: AmodoroPressableButton(
                                              onTap: busy
                                                  ? null
                                                  : () async {
                                                      setModalState(
                                                        () => busy = true,
                                                      );
                                                      try {
                                                        await widget.api
                                                            .reactToBoardItem(
                                                          itemId: item.id,
                                                          emoji: emoji,
                                                        );
                                                        await widget
                                                            .onRefresh();
                                                        if (ctx.mounted) {
                                                          Navigator.of(ctx)
                                                              .pop('reacted');
                                                        }
                                                      } catch (_) {
                                                        if (ctx.mounted) {
                                                          setModalState(
                                                            () => busy = false,
                                                          );
                                                        }
                                                      }
                                                    },
                                              width: 38,
                                              height: 38,
                                              radius: 999,
                                              color: cardSurface,
                                              borderColor: isDark
                                                  ? const Color(0xFF3E3636)
                                                  : const Color(0xFFE2DDD4),
                                              borderWidth: 1.2,
                                              lipHeight: 2.2,
                                              child: Text(
                                                emoji,
                                                style: const TextStyle(
                                                  fontSize: 21,
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
                                    onTap: busy
                                        ? null
                                        : () async {
                                            setModalState(() => busy = true);
                                            try {
                                              await widget.api.reactToBoardItem(
                                                itemId: item.id,
                                                emoji: myReaction.emoji,
                                              );
                                              await widget.onRefresh();
                                              if (ctx.mounted) {
                                                Navigator.of(ctx)
                                                    .pop('reacted');
                                              }
                                            } catch (_) {
                                              if (ctx.mounted) {
                                                setModalState(
                                                  () => busy = false,
                                                );
                                              }
                                            }
                                          },
                                    height: 40,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 13,
                                    ),
                                    radius: 999,
                                    color: itemVibrantColor.withValues(
                                      alpha: 0.16,
                                    ),
                                    borderColor: itemVibrantColor,
                                    borderWidth: 2.0,
                                    lipColor: itemVibrantColor,
                                    lipHeight: 2.5,
                                    child: Text(
                                      myReaction.emoji!,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        height: 1.05,
                                      ),
                                    ),
                                  ),
                                if (partnerReaction != null)
                                  Container(
                                    height: 40,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 11,
                                    ),
                                    decoration: AmodoroTheme.cardOutlineBox(
                                      color: pillFill,
                                      radius: 999,
                                      borderColor: isDark
                                          ? const Color(0xFF3E3636)
                                          : const Color(0xFFE2DDD4),
                                      borderWidth: 1.5,
                                      subtleShadow: false,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        FlatAvatarBadge(
                                          avatarId:
                                              partnerReaction.authorAvatarId,
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
                                        if (partnerReaction
                                            .authorLabel.isNotEmpty) ...[
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
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Author row + Delete button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              FlatAvatarBadge(
                                avatarId: item.authorAvatarId,
                                size: 26,
                                borderWidth: 1.5,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Añadido por ${item.authorLabel}',
                                  overflow: TextOverflow.ellipsis,
                                  style: AmodoroTheme.googleSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        AmodoroPressableButton(
                          onTap: () => Navigator.of(ctx).pop('delete'),
                          height: 34,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          radius: 999,
                          color: const Color(0xFFFFDAD6),
                          lipColor: const Color(0xFFE59890),
                          lipHeight: 2.2,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AmodoroTheme.sysIcon(
                                Symbols.delete,
                                size: 15,
                                color: const Color(0xFF3B0D09),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'ELIMINAR',
                                style: AmodoroTheme.googleSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF3B0D09),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Primary Action: COMPLETAR JUNTOS ✨ (+ optional PASAR A PENDIENTES)
                    Row(
                      children: [
                        if (board.slug != 'actividades') ...[
                          Expanded(
                            child: AmodoroPressableButton(
                              onTap: busy
                                  ? null
                                  : () async {
                                      setModalState(() => busy = true);
                                      try {
                                        await widget.api
                                            .copyToActividades(item.id);
                                        await widget.onRefresh();
                                        if (ctx.mounted) {
                                          Navigator.of(ctx).pop('copied');
                                        }
                                      } catch (_) {
                                        if (ctx.mounted) {
                                          setModalState(() => busy = false);
                                        }
                                      }
                                    },
                              height: 44,
                              radius: 999,
                              color: pillFill,
                              borderColor: const Color(0xFFF27166),
                              borderWidth: 2.0,
                              lipColor: const Color(0xFFF27166),
                              lipHeight: 2.8,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AmodoroTheme.sysIcon(
                                    Symbols.schedule,
                                    size: 16,
                                    color: const Color(0xFFF27166),
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      'A PENDIENTES',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AmodoroTheme.googleSans(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: ink,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          flex: 2,
                          child: AmodoroPressableButton(
                            onTap: () => Navigator.of(ctx).pop('complete'),
                            height: 44,
                            radius: 999,
                            color: const Color(0xFF10B981),
                            lipColor: const Color(0xFF059669),
                            lipHeight: 3.2,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AmodoroTheme.sysIcon(
                                  Symbols.check_circle,
                                  size: 17,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'COMPLETAR JUNTOS ✨',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AmodoroTheme.googleSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                              ],
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
      },
    );

    if (!mounted || action == null) return;
    if (action == 'edit') {
      await _showItemSubmenu(board: board, existing: item);
    } else if (action == 'complete') {
      await _showCompleteActivitySheet(item);
    } else if (action == 'delete') {
      await widget.api.deleteOrCompleteItem(item.id);
      await widget.onRefresh();
    } else if (action == 'copied') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pasado al tablero PENDIENTES'),
        ),
      );
    }
  }

  Widget _buildBoardItemMedia(String url) {
    return AmodoroImage(
      imageUrl: url,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorPlaceholder: const SizedBox.shrink(),
    );
  }
}
