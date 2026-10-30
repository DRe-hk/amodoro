import 'package:flutter/material.dart';
import '../models/amodoro_models.dart';
import '../services/api_client.dart';
import '../theme/amodoro_theme.dart';
import '../widgets/decide_sheet.dart';

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

  Future<void> _showCreateBoardDialog() async {
    final titleCtrl = TextEditingController();
    String selectedEmoji = '✨';
    const emojis = ['✨', '🍷', '✈️', '📚', '🎮', '🍰', '🌿', '🏖️'];

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Nuevo tablero compartido'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre (ej. Viajes, Restaurantes)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Icono emoji:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: emojis.map((e) {
                      return ChoiceChip(
                        label: Text(e),
                        selected: selectedEmoji == e,
                        onSelected: (_) =>
                            setDialogState(() => selectedEmoji = e),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    await widget.api.createBoard(
                      title: titleCtrl.text.trim(),
                      icon: selectedEmoji,
                    );
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  },
                  child: const Text('Crear'),
                ),
              ],
            );
          },
        );
      },
    );

    if (created == true) {
      await widget.onRefresh();
    }
  }

  Future<void> _showAddItemDialog(BoardModel board) async {
    final titleCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String emoji = board.icon;
    String bgColor = '#FFDAD6';
    const emojis = ['✨', '🍕', '🎬', '🎵', '🌿', '🍷', '🎮', '🏖️', '🍿', '🎨'];

    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Agregar a ${board.icon} ${board.title}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Título (admite emojis)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Notas o detalles opcionales',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Emoji:',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: emojis.map((e) {
                        return ChoiceChip(
                          label: Text(e),
                          selected: emoji == e,
                          onSelected: (_) => setModalState(() => emoji = e),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Color pastel M3:',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: AmodoroTheme.pastelPresets.map((p) {
                        final sel =
                            bgColor.toUpperCase() == p.hex.toUpperCase();
                        return GestureDetector(
                          onTap: () => setModalState(() => bgColor = p.hex),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: p.color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: sel ? Colors.black : Colors.black26,
                                width: sel ? 2.5 : 1,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AmodoroTheme.coralPillLight,
                        foregroundColor: AmodoroTheme.coralPillTextLight,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () async {
                        if (titleCtrl.text.trim().isEmpty) return;
                        await widget.api.addBoardItem(
                          boardId: board.id,
                          title: titleCtrl.text.trim(),
                          notes: notesCtrl.text.trim(),
                          emoji: emoji,
                          bgColor: bgColor,
                        );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      },
                      child: const Text(
                        'Guardar Tarjeta',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (added == true) {
      await widget.onRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeBoard = _activeBoard;
    if (activeBoard == null) {
      return const Center(child: Text('Sin tableros disponibles'));
    }

    final isActividades = activeBoard.slug == 'actividades';

    // Construcción de las 2 columnas tipo masonry:
    // En Actividades, el PRIMER slot arriba a la izquierda de la columna 1 es el botón compacto DECIDIR.
    final col1 = <Widget>[];
    final col2 = <Widget>[];

    if (isActividades) {
      col1.add(_buildDecidirCompactButton(context));
    }

    for (int i = 0; i < activeBoard.items.length; i++) {
      final item = activeBoard.items[i];
      final cardWidget = Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildBoardItemCard(context, item, isActividades: isActividades),
      );
      if (isActividades) {
        // Como col1 ya tiene el botón DECIDIR en el primer lugar, balanceamos empezando por col2
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
        // Selector superior de Tableros: Actividades (unificado con Pendientes), Música, Pelis, personalizados y +
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Row(
            children: [
              ...widget.sync.boards.map((b) {
                final selected = b.id == activeBoard.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      '${b.icon} ${b.title} (${b.items.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: selected
                            ? AmodoroTheme.coralPillTextLight
                            : null,
                      ),
                    ),
                    selected: selected,
                    selectedColor: AmodoroTheme.coralPillLight,
                    onSelected: (_) => setState(() => _selectedBoardId = b.id),
                  ),
                );
              }),
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 16),
                label: const Text(
                  'Tablero',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
                onPressed: _showCreateBoardDialog,
              ),
            ],
          ),
        ),

        // Grid Masonry de 2 columnas
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Column(children: col1)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(children: col2)),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Botón inferior para agregar tarjeta al tablero actual
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AmodoroTheme.coralPillLight,
              foregroundColor: AmodoroTheme.coralPillTextLight,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            onPressed: () => _showAddItemDialog(activeBoard),
            icon: const Icon(Icons.add_rounded),
            label: Text(
              'Agregar a ${activeBoard.title}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDecidirCompactButton(BuildContext context) {
    final hasActiveVote = widget.sync.activeVoting != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: _openDecideModal,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AmodoroTheme.coralPillLight,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AmodoroTheme.coralPillLight.withValues(alpha: 0.32),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('🎲', style: TextStyle(fontSize: 22)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      hasActiveVote ? 'VOTACIÓN ACTIVA' : '2 MODOS',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: AmodoroTheme.coralPillTextLight,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'DECIDIR',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                  color: AmodoroTheme.coralPillTextLight,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Ruleta o Votación 4–5 al azar',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AmodoroTheme.coralPillTextLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBoardItemCard(
    BuildContext context,
    BoardCardItem item, {
    required bool isActividades,
  }) {
    final bg = AmodoroTheme.parseHexColor(item.bgColor);
    final ink = AmodoroTheme.getContrastingInk(bg);
    final muted = AmodoroTheme.getContrastingMutedInk(bg);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(item.emoji, style: const TextStyle(fontSize: 22)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ink.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.authorLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: ink,
              height: 1.25,
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
          if (isActividades)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: ink,
                  side: BorderSide(color: ink.withValues(alpha: 0.25)),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () async {
                  await widget.api.completeItem(item.id);
                  await widget.onRefresh();
                },
                icon: const Icon(Icons.check_rounded, size: 15),
                label: const Text(
                  'Completar',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: ink,
                  side: BorderSide(color: ink.withValues(alpha: 0.25)),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () async {
                  await widget.api.copyToActividades(item.id);
                  await widget.onRefresh();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copiado al tablero Actividades ✨'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.add_task_rounded, size: 15),
                label: const Text(
                  'A Actividades',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
