import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/amodoro_models.dart';
import '../services/api_client.dart';
import '../theme/amodoro_theme.dart';
import '../widgets/decide_sheet.dart';
import '../widgets/flat_avatar.dart';
import '../widgets/link_preview_card.dart';

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

  /// Submenú para crear o editar un tablero (nombre, icono, color pastel y opción de eliminar)
  Future<void> _showBoardSubmenu({BoardModel? existing}) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    String selectedIcon = existing?.icon ?? 'bookmark';
    String selectedColor = existing?.bgColor ?? '#F4EFE8';
    final isDefaultPendientes = existing?.slug == 'actividades';

    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final surface = Theme.of(ctx).scaffoldBackgroundColor;
        final boxSurface = Theme.of(ctx).colorScheme.surfaceContainer;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                22,
                18,
                22,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: AmodoroTheme.floatingPerspectiveBox(
                color: surface,
                radius: 30,
                thickness: 2.5,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      existing == null
                          ? 'NUEVA LISTA COMPARTIDA'
                          : 'OPCIONES DE LISTA · ${existing.title}',
                      style:
                          const TextStyle(fontSize: 12, letterSpacing: 1.4),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: AmodoroTheme.floatingPerspectiveBox(
                        color: boxSurface,
                        radius: 18,
                        thickness: 2.0,
                      ),
                      child: TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          labelText: 'NOMBRE DE LA LISTA',
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'ICONO',
                      style: TextStyle(fontSize: 11, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _boardIconOptions.map((opt) {
                        final key = opt['key'] as String;
                        final iconData = opt['icon'] as IconData;
                        final sel = selectedIcon == key;
                        return GestureDetector(
                          onTap: () =>
                              setModalState(() => selectedIcon = key),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: AmodoroTheme.floatingPerspectiveBox(
                              color: sel
                                  ? AmodoroTheme.coralPillLight
                                  : boxSurface,
                              radius: 14,
                              thickness: sel ? 2.5 : 1.8,
                            ),
                            child: Center(
                              child: AmodoroTheme.sysIcon(
                                iconData,
                                size: 20,
                                color: sel
                                    ? AmodoroTheme.coralPillTextLight
                                    : null,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'COLOR DEL TABLERO',
                      style: TextStyle(fontSize: 11, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: AmodoroTheme.pastelPresets.map((p) {
                        final sel = selectedColor.toUpperCase() ==
                            p.hex.toUpperCase();
                        return GestureDetector(
                          onTap: () =>
                              setModalState(() => selectedColor = p.hex),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: AmodoroTheme.floatingPerspectiveBox(
                              color: p.color,
                              radius: 99,
                              thickness: sel ? 3.0 : 1.8,
                            ),
                            child: sel
                                ? Center(
                                    child: AmodoroTheme.sysIcon(
                                      Symbols.check,
                                      size: 16,
                                      color: const Color(0xFF1F1B18),
                                    ),
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
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
                      child: Container(
                        height: 46,
                        decoration: AmodoroTheme.floatingPerspectiveBox(
                          color: AmodoroTheme.coralPillLight,
                          radius: 999,
                          thickness: 2.5,
                        ),
                        child: Center(
                          child: Text(
                            existing == null
                                ? 'CREAR LISTA'
                                : 'GUARDAR CAMBIOS',
                            style: const TextStyle(
                              fontSize: 12,
                              letterSpacing: 1.4,
                              color: AmodoroTheme.coralPillTextLight,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (existing != null && !isDefaultPendientes) ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () async {
                          await widget.api.deleteBoard(existing.id);
                          if (_selectedBoardId == existing.id) {
                            _selectedBoardId = null;
                          }
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        },
                        child: Container(
                          height: 44,
                          decoration: AmodoroTheme.floatingPerspectiveBox(
                            color: const Color(0xFFFFDAD6),
                            radius: 999,
                            thickness: 2.0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AmodoroTheme.sysIcon(
                                Symbols.delete,
                                size: 18,
                                color: const Color(0xFF3B0D09),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'ELIMINAR TABLERO',
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
                  ],
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

  /// Submenú para añadir o editar un elemento (título, notas, categoría, emoji, color, imagen, link y eliminar)
  Future<void> _showItemSubmenu({
    required BoardModel board,
    BoardCardItem? existing,
  }) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final categoryCtrl = TextEditingController(
      text: existing?.categoryTag ??
          (board.slug == 'actividades' ? 'PENDIENTE' : board.title),
    );
    final emojiCtrl = TextEditingController(text: existing?.emoji ?? '');
    final linkCtrl = TextEditingController(text: existing?.url ?? '');
    String bgColor = existing?.bgColor ?? '#FFDAD6';
    String? imageDataUrl;
    bool saving = false;

    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final surface = Theme.of(ctx).scaffoldBackgroundColor;
        final boxSurface = Theme.of(ctx).colorScheme.surfaceContainer;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                22,
                18,
                22,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: AmodoroTheme.floatingPerspectiveBox(
                color: surface,
                radius: 30,
                thickness: 2.5,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      existing == null
                          ? 'AÑADIR A ${board.title.toUpperCase()}'
                          : 'EDITAR ELEMENTO',
                      style:
                          const TextStyle(fontSize: 12, letterSpacing: 1.4),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 14),
                            decoration: AmodoroTheme.floatingPerspectiveBox(
                              color: boxSurface,
                              radius: 16,
                              thickness: 2.0,
                            ),
                            child: TextField(
                              controller: categoryCtrl,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                labelText: 'CATEGORÍA (EJ. PELÍCULA, JUEGO)',
                                labelStyle: TextStyle(fontSize: 10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 14),
                            decoration: AmodoroTheme.floatingPerspectiveBox(
                              color: boxSurface,
                              radius: 16,
                              thickness: 2.0,
                            ),
                            child: TextField(
                              controller: emojiCtrl,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                labelText: 'EMOJI OPC.',
                                labelStyle: TextStyle(fontSize: 10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: AmodoroTheme.floatingPerspectiveBox(
                        color: boxSurface,
                        radius: 16,
                        thickness: 2.0,
                      ),
                      child: TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          labelText: 'TÍTULO (EJ. VER SNOOPY, JUGAR MINECRAFT)',
                          labelStyle: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: AmodoroTheme.floatingPerspectiveBox(
                        color: boxSurface,
                        radius: 16,
                        thickness: 2.0,
                      ),
                      child: TextField(
                        controller: notesCtrl,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          labelText: 'NOTAS OPCIONALES',
                          labelStyle: TextStyle(fontSize: 11),
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
                                const EdgeInsets.symmetric(horizontal: 12),
                            decoration: AmodoroTheme.floatingPerspectiveBox(
                              color: boxSurface,
                              radius: 16,
                              thickness: 2.0,
                            ),
                            child: TextField(
                              controller: linkCtrl,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Link (Spotify, YT, IG...)',
                                icon: AmodoroTheme.sysIcon(
                                  Symbols.link,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (existing == null) ...[
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () async {
                              final picked = await _picker.pickImage(
                                source: ImageSource.gallery,
                                maxWidth: 1024,
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
                            child: Container(
                              height: 46,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              decoration:
                                  AmodoroTheme.floatingPerspectiveBox(
                                color: imageDataUrl != null
                                    ? const Color(0xFFC8E6C9)
                                    : boxSurface,
                                radius: 16,
                                thickness: 2.0,
                              ),
                              child: Row(
                                children: [
                                  AmodoroTheme.sysIcon(
                                    Symbols.image,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    imageDataUrl != null ? 'LISTA' : 'IMAGEN',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),

                    const Text(
                      'COLOR',
                      style: TextStyle(fontSize: 11, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: AmodoroTheme.pastelPresets.map((p) {
                        final sel =
                            bgColor.toUpperCase() == p.hex.toUpperCase();
                        return GestureDetector(
                          onTap: () => setModalState(() => bgColor = p.hex),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: AmodoroTheme.floatingPerspectiveBox(
                              color: p.color,
                              radius: 99,
                              thickness: sel ? 2.8 : 1.6,
                            ),
                            child: sel
                                ? Center(
                                    child: AmodoroTheme.sysIcon(
                                      Symbols.check,
                                      size: 15,
                                      color: const Color(0xFF1F1B18),
                                    ),
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    GestureDetector(
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
                                  categoryTag: categoryCtrl.text.trim(),
                                  emoji: emojiCtrl.text.trim(),
                                  bgColor: bgColor,
                                  mediaDataUrl: imageDataUrl,
                                  linkUrl: linkCtrl.text.trim(),
                                );
                              } else {
                                await widget.api.updateBoardItem(
                                  itemId: existing.id,
                                  title: titleCtrl.text.trim(),
                                  notes: notesCtrl.text.trim(),
                                  categoryTag: categoryCtrl.text.trim(),
                                  emoji: emojiCtrl.text.trim(),
                                  bgColor: bgColor,
                                  linkUrl: linkCtrl.text.trim(),
                                );
                              }
                              if (ctx.mounted) Navigator.pop(ctx, true);
                            },
                      child: Container(
                        height: 46,
                        decoration: AmodoroTheme.floatingPerspectiveBox(
                          color: AmodoroTheme.coralPillLight,
                          radius: 999,
                          thickness: 2.5,
                        ),
                        child: Center(
                          child: Text(
                            saving
                                ? 'GUARDANDO...'
                                : (existing == null
                                    ? 'GUARDAR EN ${board.title.toUpperCase()}'
                                    : 'GUARDAR CAMBIOS'),
                            style: const TextStyle(
                              fontSize: 12,
                              letterSpacing: 1.4,
                              color: AmodoroTheme.coralPillTextLight,
                            ),
                          ),
                        ),
                      ),
                    ),

                    if (existing != null) ...[
                      if (board.slug != 'actividades') ...[
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () async {
                            await widget.api.copyToActividades(existing.id);
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          },
                          child: Container(
                            height: 44,
                            decoration: AmodoroTheme.floatingPerspectiveBox(
                              color: const Color(0xFFC8E6C9),
                              radius: 999,
                              thickness: 2.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AmodoroTheme.sysIcon(
                                  Symbols.schedule,
                                  size: 18,
                                  color: const Color(0xFF1F1B18),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'PASAR A PENDIENTES',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    letterSpacing: 1.3,
                                    color: Color(0xFF1F1B18),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () async {
                          await widget.api.deleteOrCompleteItem(existing.id);
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        },
                        child: Container(
                          height: 44,
                          decoration: AmodoroTheme.floatingPerspectiveBox(
                            color: const Color(0xFFFFDAD6),
                            radius: 999,
                            thickness: 2.0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AmodoroTheme.sysIcon(
                                Symbols.delete,
                                size: 18,
                                color: const Color(0xFF3B0D09),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'ELIMINAR ELEMENTO',
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
                  ],
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
    final isPendientes = activeBoard.slug == 'actividades';

    // Construcción de las 2 columnas estilo masonry según el boceto:
    // En PENDIENTES, el primer elemento arriba a la izquierda de la columna 1 es el botón compacto DECIDIR.
    final col1 = <Widget>[];
    final col2 = <Widget>[];

    if (isPendientes) {
      col1.add(_buildDecidirCompactButton(context, isDark));
    }

    for (int i = 0; i < activeBoard.items.length; i++) {
      final item = activeBoard.items[i];
      final cardWidget = Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _buildBoardItemCard(
          context,
          board: activeBoard,
          item: item,
          isPendientes: isPendientes,
        ),
      );
      if (isPendientes) {
        if (i.isEven) {
          col2.add(cardWidget);
        } else {
          col1.add(cardWidget);
        }
      } else {
        if (i.isEven) {
          col1.add(cardWidget);
        } else {
          col2.add(cardWidget);
        }
      }
    }

    return Column(
      children: [
        // Fila superior de tableros (PENDIENTES, MÚSICA, PELIS, SERIES, JUEGOS...) + botón [+]
        // Tal como en el boceto: tarjetas con icono arriba y título abajo, borde en perspectiva
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: Row(
            children: [
              ...widget.sync.boards.map((b) {
                final selected = b.id == activeBoard.id;
                final tileBg = selected
                    ? (isDark
                        ? AmodoroTheme.coralPillDark
                        : AmodoroTheme.coralPillLight)
                    : AmodoroTheme.parseHexColor(b.bgColor);
                final tileInk = selected
                    ? (isDark
                        ? AmodoroTheme.coralPillTextDark
                        : AmodoroTheme.coralPillTextLight)
                    : AmodoroTheme.getContrastingInk(tileBg);

                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedBoardId = b.id),
                    onLongPress: () => _showBoardSubmenu(existing: b),
                    child: Container(
                      width: 96,
                      height: 62,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: AmodoroTheme.floatingPerspectiveBox(
                        color: tileBg,
                        radius: 18,
                        thickness: selected ? 3.0 : 2.2,
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AmodoroTheme.sysIcon(
                                  AmodoroTheme.boardIconFromName(
                                    b.icon,
                                    b.slug,
                                  ),
                                  size: 20,
                                  color: tileInk,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  b.title.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    letterSpacing: 1.1,
                                    color: tileInk,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _showBoardSubmenu(existing: b),
                              child: AmodoroTheme.sysIcon(
                                Symbols.more_horiz,
                                size: 14,
                                color: tileInk.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              // Botón [+] a la derecha como en el boceto
              GestureDetector(
                onTap: () => _showBoardSubmenu(),
                child: Container(
                  width: 58,
                  height: 62,
                  decoration: AmodoroTheme.floatingPerspectiveBox(
                    color: isDark
                        ? const Color(0xFF1F2421)
                        : const Color(0xFFF4EFE8),
                    radius: 18,
                    thickness: 2.5,
                  ),
                  child: Center(
                    child: AmodoroTheme.sysIcon(Symbols.add, size: 24),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Grid Masonry de 2 columnas
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 6, 20, 20),
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

        // Botón inferior flotante en MAYÚSCULAS para agregar tarjeta a la lista actual
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 20, 14),
          child: GestureDetector(
            onTap: () => _showItemSubmenu(board: activeBoard),
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
                    'AÑADIR A ${activeBoard.title.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 11.5,
                      letterSpacing: 1.4,
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
    );
  }

  /// Botón compacto DECIDIR en el primer espacio arriba a la izquierda de PENDIENTES
  Widget _buildDecidirCompactButton(BuildContext context, bool isDark) {
    final surface = isDark
        ? AmodoroTheme.coralPillDark
        : AmodoroTheme.coralPillLight;
    final ink = isDark
        ? AmodoroTheme.coralPillTextDark
        : AmodoroTheme.coralPillTextLight;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: _openDecideModal,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: AmodoroTheme.floatingPerspectiveBox(
            color: surface,
            radius: 18,
            thickness: 2.5,
            perspectiveEdgeColor: isDark
                ? AmodoroTheme.coralPillBorderDark
                : AmodoroTheme.coralPillBorderLight,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AmodoroTheme.sysIcon(Symbols.casino, size: 22, color: ink),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'DECIDIR',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    letterSpacing: 1.6,
                    color: ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBoardItemCard(
    BuildContext context, {
    required BoardModel board,
    required BoardCardItem item,
    required bool isPendientes,
  }) {
    final bg = AmodoroTheme.parseHexColor(item.bgColor);
    final ink = AmodoroTheme.getContrastingInk(bg);
    final muted = AmodoroTheme.getContrastingMutedInk(bg);

    return GestureDetector(
      onLongPress: () => _showItemSubmenu(board: board, existing: item),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: AmodoroTheme.floatingPerspectiveBox(
          color: bg,
          radius: 24,
          thickness: 2.5,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fila superior: Etiqueta de categoría (ej. PELÍCULAS, JUEGO, SERIE) + Submenú
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.categoryTag.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.2,
                      color: muted,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _showItemSubmenu(board: board, existing: item),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: AmodoroTheme.sysIcon(
                      Symbols.more_horiz,
                      size: 18,
                      color: ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Imagen adjunta si existe
            if (item.mediaUrl != null && item.mediaUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  widget.api.resolveMediaUrl(item.mediaUrl),
                  height: 115,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Link con vista previa si existe
            if (item.url != null && item.url!.isNotEmpty) ...[
              LinkPreviewCard(
                url: item.url!,
                title: item.linkTitle ?? item.title,
                thumbnail: item.linkThumbnail,
                platform: item.linkPlatform,
                cardBgColor: bg,
              ),
              const SizedBox(height: 10),
            ],

            // Título principal
            Text(
              item.emoji.isNotEmpty
                  ? '${item.title} ${item.emoji}'
                  : item.title,
              style: TextStyle(
                fontSize: 15,
                color: ink,
                height: 1.28,
              ),
            ),

            if (item.notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                item.notes,
                style: TextStyle(
                  fontSize: 12,
                  color: muted,
                  height: 1.3,
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Pie de tarjeta: Avatar Flat de quien añadió el elemento + botón rápido para pasar a PENDIENTES
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FlatAvatarBadge(
                      avatarId: item.authorAvatarId,
                      size: 24,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.authorLabel,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: muted,
                      ),
                    ),
                  ],
                ),
                if (!isPendientes)
                  GestureDetector(
                    onTap: () async {
                      await widget.api.copyToActividades(item.id);
                      await widget.onRefresh();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Pasado al tablero PENDIENTES'),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: AmodoroTheme.floatingPerspectiveBox(
                        color: Colors.white.withValues(alpha: 0.55),
                        radius: 999,
                        thickness: 1.6,
                        perspectiveEdgeColor:
                            AmodoroTheme.darkenForPerspective(bg, 0.25),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AmodoroTheme.sysIcon(
                            Symbols.schedule,
                            size: 13,
                            color: const Color(0xFF1F1B18),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'PENDIENTES',
                            style: TextStyle(
                              fontSize: 9,
                              letterSpacing: 0.8,
                              color: Color(0xFF1F1B18),
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
  }
}
