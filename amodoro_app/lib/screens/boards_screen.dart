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

  /// Devuelve un tono más saturado/intenso del color elegido para el botón de añadir (con texto blanco)
  /// y para que los bordes elegidos se distingan claramente.
  Color _accentFromHex(String hex) {
    final base = AmodoroTheme.parseHexColor(
      hex,
      fallback: AmodoroTheme.coralPillLight,
    );
    final hsl = HSLColor.fromColor(base);
    if (hsl.lightness > 0.72) {
      return hsl
          .withLightness(0.56)
          .withSaturation((hsl.saturation + 0.22).clamp(0.35, 0.90))
          .toColor();
    }
    return base;
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

  /// Submenú para crear o editar un tablero (nombre, icono, color de borde/botón y opción de eliminar)
  Future<void> _showBoardSubmenu({BoardModel? existing}) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    String selectedIcon = existing?.icon ?? 'bookmark';
    String selectedColor = existing?.bgColor ?? '#FFDAD6';
    final isDefaultPendientes = existing?.slug == 'actividades';

    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
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
                                    ? AmodoroTheme.coralText(isDark)
                                    : null,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'COLOR DE BORDE Y BOTÓN DE LA LISTA',
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
                          color: isDark
                              ? AmodoroTheme.coralPillDark
                              : AmodoroTheme.coralPillLight,
                          radius: 999,
                          thickness: 2.5,
                        ),
                        child: Center(
                          child: Text(
                            existing == null
                                ? 'CREAR LISTA'
                                : 'GUARDAR CAMBIOS',
                            style: TextStyle(
                              fontSize: 12,
                              letterSpacing: 1.4,
                              color: AmodoroTheme.coralText(isDark),
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

  /// Submenú para añadir o editar un elemento:
  /// - La categoría es un menú desplegable con las listas existentes.
  /// - El color elegido se aplica al borde del elemento.
  Future<void> _showItemSubmenu({
    required BoardModel board,
    BoardCardItem? existing,
  }) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final emojiCtrl = TextEditingController(text: existing?.emoji ?? '');
    final linkCtrl = TextEditingController(text: existing?.url ?? '');

    // Construir opciones del desplegable de Categoría a partir de las listas existentes
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

    String bgColor = existing?.bgColor ?? board.bgColor;
    String? imageDataUrl;
    bool saving = false;

    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final surface = Theme.of(ctx).scaffoldBackgroundColor;
        final boxSurface = Theme.of(ctx).colorScheme.surfaceContainer;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final boardButtonColor = _accentFromHex(board.bgColor);
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
                        // Menú desplegable de Categoría con las listas existentes
                        Expanded(
                          flex: 3,
                          child: Container(
                            height: 48,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 14),
                            decoration: AmodoroTheme.floatingPerspectiveBox(
                              color: boxSurface,
                              radius: 16,
                              thickness: 2.0,
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedCategory,
                                isExpanded: true,
                                icon: AmodoroTheme.sysIcon(
                                  Symbols.expand_more,
                                  size: 18,
                                ),
                                items: categoryOptions.map((cat) {
                                  return DropdownMenuItem<String>(
                                    value: cat,
                                    child: Text(
                                      cat,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        letterSpacing: 1.1,
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
                                const EdgeInsets.symmetric(horizontal: 14),
                            decoration: AmodoroTheme.floatingPerspectiveBox(
                              color: boxSurface,
                              radius: 16,
                              thickness: 2.0,
                            ),
                            child: Center(
                              child: TextField(
                                controller: emojiCtrl,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'EMOJI OPC.',
                                  hintStyle: TextStyle(fontSize: 10.5),
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
                      'COLOR DEL BORDE',
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
                                  categoryTag: selectedCategory,
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
                                  categoryTag: selectedCategory,
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
                          color: boardButtonColor,
                          radius: 999,
                          thickness: 2.5,
                          perspectiveEdgeColor:
                              AmodoroTheme.darkenForPerspective(
                                  boardButtonColor, 0.20),
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
                              color: Colors.white,
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
                              color: isDark
                                  ? AmodoroTheme.darkContainer
                                  : AmodoroTheme.lightContainer,
                              radius: 999,
                              thickness: 2.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AmodoroTheme.sysIcon(
                                  Symbols.schedule,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'PASAR A PENDIENTES',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    letterSpacing: 1.3,
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
    final neutralCardFill =
        isDark ? AmodoroTheme.darkContainer : AmodoroTheme.lightContainer;
    final neutralCardOutline =
        isDark ? const Color(0xFF383E3A) : const Color(0xFFE2DDD4);

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
          neutralCardFill: neutralCardFill,
          neutralCardOutline: neutralCardOutline,
          isDark: isDark,
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

    final addButtonColor = _accentFromHex(activeBoard.bgColor);

    return Column(
      children: [
        // Fila superior de tableros (PENDIENTES, MÚSICA, PELIS, SERIES, JUEGOS...) + botón [+]
        // Más pequeñas verticalmente y adaptables al tamaño de texto del sistema.
        // Si está activa: su relleno es del MISMO color que el botón inferior de esa lista (el color del board), con texto/icono blanco y weight 450.
        // Si está inactiva: fondo neutro con borde completo de 1px + borde en perspectiva del color elegido de esa lista.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
          child: Row(
            children: [
              ...widget.sync.boards.map((b) {
                final selected = b.id == activeBoard.id;
                final boardChosenColor = _accentFromHex(b.bgColor);
                final tileBg = selected ? boardChosenColor : neutralCardFill;
                final tileInk = selected
                    ? Colors.white
                    : (isDark ? AmodoroTheme.darkInk : AmodoroTheme.lightInk);

                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedBoardId = b.id),
                    onLongPress: () => _showBoardSubmenu(existing: b),
                    child: Container(
                      width: 96,
                      constraints: const BoxConstraints(minHeight: 46),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: AmodoroTheme.floatingPerspectiveBox(
                        color: tileBg,
                        radius: 15,
                        thickness: selected ? 2.6 : 2.2,
                        fullBorderColor: selected ? null : neutralCardOutline,
                        fullBorderWidth: 1.0,
                        perspectiveEdgeColor: selected
                            ? AmodoroTheme.darkenForPerspective(
                                boardChosenColor,
                                0.22,
                              )
                            : boardChosenColor,
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AmodoroTheme.sysIcon(
                                  AmodoroTheme.boardIconFromName(
                                    b.icon,
                                    b.slug,
                                  ),
                                  size: 16,
                                  color: tileInk,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  b.title.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: selected
                                      ? AmodoroTheme.activeElementTextStyle(
                                          fontSize: 9.5,
                                          color: tileInk,
                                          letterSpacing: 1.0,
                                        )
                                      : TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w400,
                                          letterSpacing: 1.0,
                                          color: tileInk,
                                        ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: -2,
                            right: -2,
                            child: GestureDetector(
                              onTap: () => _showBoardSubmenu(existing: b),
                              child: AmodoroTheme.sysIcon(
                                Symbols.more_horiz,
                                size: 13,
                                color: tileInk.withValues(alpha: 0.78),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              // Botón [+] a la derecha compacto
              GestureDetector(
                onTap: () => _showBoardSubmenu(),
                child: Container(
                  width: 48,
                  constraints: const BoxConstraints(minHeight: 46),
                  decoration: AmodoroTheme.floatingPerspectiveBox(
                    color: neutralCardFill,
                    radius: 15,
                    thickness: 2.2,
                    fullBorderColor: neutralCardOutline,
                    fullBorderWidth: 1.0,
                  ),
                  child: Center(
                    child: AmodoroTheme.sysIcon(Symbols.add, size: 21),
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

        // Botón inferior flotante de cada lista: cambia todo el botón de acuerdo al color de esa lista y su texto es blanco
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 20, 14),
          child: GestureDetector(
            onTap: () => _showItemSubmenu(board: activeBoard),
            child: Container(
              height: 46,
              decoration: AmodoroTheme.floatingPerspectiveBox(
                color: addButtonColor,
                radius: 999,
                thickness: 2.5,
                perspectiveEdgeColor: AmodoroTheme.darkenForPerspective(
                  addButtonColor,
                  0.22,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AmodoroTheme.sysIcon(
                    Symbols.add,
                    size: 19,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'AÑADIR A ${activeBoard.title.toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 1.4,
                      color: Colors.white,
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
    final ink = AmodoroTheme.coralText(isDark);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: _openDecideModal,
        child: Container(
          height: 48,
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
              AmodoroTheme.sysIcon(Symbols.casino, size: 20, color: ink),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'DECIDIR',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
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

  /// Tarjeta de elemento en BOARDS:
  /// - Superficie en color neutro con borde completo de 1px para no perderse en el fondo.
  /// - Borde en perspectiva inferior y derecho del color elegido para el elemento.
  Widget _buildBoardItemCard(
    BuildContext context, {
    required BoardModel board,
    required BoardCardItem item,
    required bool isPendientes,
    required Color neutralCardFill,
    required Color neutralCardOutline,
    required bool isDark,
  }) {
    final chosenEdgeColor = _accentFromHex(item.bgColor);
    final ink = isDark ? AmodoroTheme.darkInk : AmodoroTheme.lightInk;
    final muted = isDark ? AmodoroTheme.darkMuted : AmodoroTheme.lightMuted;

    return GestureDetector(
      onLongPress: () => _showItemSubmenu(board: board, existing: item),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: AmodoroTheme.floatingPerspectiveBox(
          color: neutralCardFill,
          radius: 22,
          thickness: 2.8,
          fullBorderColor: neutralCardOutline,
          fullBorderWidth: 1.0,
          perspectiveEdgeColor: chosenEdgeColor,
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
                cardBgColor: neutralCardFill,
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
                        color: isDark
                            ? AmodoroTheme.darkBackground
                            : AmodoroTheme.lightBackground,
                        radius: 999,
                        thickness: 1.8,
                        fullBorderColor: neutralCardOutline,
                        perspectiveEdgeColor: chosenEdgeColor,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AmodoroTheme.sysIcon(
                            Symbols.schedule,
                            size: 13,
                            color: ink,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'PENDIENTES',
                            style: TextStyle(
                              fontSize: 9,
                              letterSpacing: 0.8,
                              color: ink,
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
