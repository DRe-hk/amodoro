import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/amodoro_models.dart';
import '../services/api_client.dart';
import '../theme/amodoro_theme.dart';
import '../widgets/amodoro_image.dart';
import '../widgets/flat_avatar.dart';
import '../widgets/fullscreen_media_viewer.dart';
import '../widgets/pressable_button.dart';
import 'sticker_editor_screen.dart';

class StickerCollectionScreen extends StatefulWidget {
  final AmodoroApiClient api;
  final SyncPayload? sync;

  const StickerCollectionScreen({
    super.key,
    required this.api,
    this.sync,
  });

  @override
  State<StickerCollectionScreen> createState() => _StickerCollectionScreenState();
}

class _StickerCollectionScreenState extends State<StickerCollectionScreen> {
  List<StickerModel> _stickers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStickers();
  }

  Future<void> _loadStickers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await widget.api.fetchStickers();
      if (!mounted) return;
      setState(() {
        _stickers = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _openCreateSticker() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StickerEditorScreen(
          api: widget.api,
          sync: widget.sync,
        ),
      ),
    );

    if (result == true) {
      _loadStickers();
    }
  }

  Future<void> _confirmDeleteSticker(StickerModel sticker) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AmodoroTheme.darkContainer : Colors.white;
    final inkColor = isDark ? AmodoroTheme.darkInk : AmodoroTheme.lightInk;
    final mutedColor =
        isDark ? AmodoroTheme.darkMuted : AmodoroTheme.lightMuted;
    final borderColor =
        isDark ? const Color(0xFF383232) : const Color(0xFFE9E4DC);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: borderColor, width: 2.0),
        ),
        title: Text(
          '¿Eliminar sticker?',
          style: AmodoroTheme.googleSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: inkColor,
          ),
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar este sticker? Ya no estará disponible para ninguno de los dos.',
          style: AmodoroTheme.googleSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: mutedColor,
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: AmodoroPressableButton(
                  onTap: () => Navigator.of(dialogCtx).pop(false),
                  height: 42,
                  radius: 999,
                  color: const Color(0xFFF6EFE6),
                  borderColor: borderColor,
                  borderWidth: 1.5,
                  lipColor: borderColor,
                  lipHeight: 2.5,
                  child: Text(
                    'CANCELAR',
                    style: AmodoroTheme.googleSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: AmodoroTheme.lightInk,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AmodoroPressableButton(
                  onTap: () => Navigator.of(dialogCtx).pop(true),
                  height: 42,
                  radius: 999,
                  color: const Color(0xFFFFDAD6),
                  borderColor: const Color(0xFFD6574D),
                  borderWidth: 1.5,
                  lipColor: const Color(0xFFD6574D),
                  lipHeight: 2.5,
                  child: Text(
                    'ELIMINAR',
                    style: AmodoroTheme.googleSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: const Color(0xFF8B2B24),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.api.deleteSticker(sticker.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sticker eliminado')),
        );
        _loadStickers();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AmodoroTheme.darkBackground : AmodoroTheme.lightBackground;
    final cardBg = isDark ? AmodoroTheme.darkContainer : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF383232) : const Color(0xFFE9E4DC);
    final inkColor = isDark ? AmodoroTheme.darkInk : AmodoroTheme.lightInk;
    final mutedColor =
        isDark ? AmodoroTheme.darkMuted : AmodoroTheme.lightMuted;
    final coralBg =
        isDark ? AmodoroTheme.coralPillDark : AmodoroTheme.coralPillLight;
    final coralLip = isDark
        ? AmodoroTheme.coralPillBorderDark
        : AmodoroTheme.coralPillBorderLight;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Barra superior
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  AmodoroPressableButton(
                    onTap: () => Navigator.of(context).pop(),
                    width: 44,
                    height: 44,
                    radius: 999,
                    color: cardBg,
                    borderColor: borderColor,
                    borderWidth: 1.5,
                    lipColor: borderColor,
                    lipHeight: 2.5,
                    child: AmodoroTheme.sysIcon(
                      Symbols.arrow_back,
                      size: 20,
                      color: inkColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          'STICKERS',
                          style: AmodoroTheme.googleSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: inkColor,
                          ),
                        ),
                        if (_stickers.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFDAD6),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${_stickers.length}',
                              style: AmodoroTheme.googleSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF8B2B24),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AmodoroPressableButton(
                    onTap: _openCreateSticker,
                    height: 40,
                    radius: 999,
                    color: coralBg,
                    lipColor: coralLip,
                    lipHeight: 2.5,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        AmodoroTheme.sysIcon(
                          Symbols.add,
                          size: 18,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'CREAR',
                          style: AmodoroTheme.googleSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Contenido con soporte pull-to-refresh
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadStickers,
                color: coralBg,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? _buildErrorView(inkColor, mutedColor, coralBg, coralLip)
                        : _stickers.isEmpty
                            ? _buildEmptyView(
                                cardBg: cardBg,
                                borderColor: borderColor,
                                inkColor: inkColor,
                                mutedColor: mutedColor,
                                coralBg: coralBg,
                                coralLip: coralLip,
                              )
                            : _buildGrid(
                                cardBg: cardBg,
                                borderColor: borderColor,
                                inkColor: inkColor,
                                mutedColor: mutedColor,
                              ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(
    Color inkColor,
    Color mutedColor,
    Color coralBg,
    Color coralLip,
  ) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AmodoroTheme.sysIcon(
              Symbols.sentiment_dissatisfied,
              size: 48,
              color: mutedColor,
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? 'No se pudieron cargar los stickers.',
              textAlign: TextAlign.center,
              style: AmodoroTheme.googleSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: inkColor,
              ),
            ),
            const SizedBox(height: 20),
            AmodoroPressableButton(
              onTap: _loadStickers,
              height: 44,
              radius: 999,
              color: coralBg,
              lipColor: coralLip,
              lipHeight: 3.0,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'REINTENTAR',
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
    );
  }

  Widget _buildEmptyView({
    required Color cardBg,
    required Color borderColor,
    required Color inkColor,
    required Color mutedColor,
    required Color coralBg,
    required Color coralLip,
  }) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFFFFDAD6),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFF27166),
                  width: 2.5,
                ),
              ),
              child: Center(
                child: AmodoroTheme.sysIcon(
                  Symbols.sentiment_satisfied,
                  size: 46,
                  color: const Color(0xFF8B2B24),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Aún no tienen stickers juntos',
              textAlign: TextAlign.center,
              style: AmodoroTheme.googleSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: inkColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '¡Crea el primer sticker de la pareja! Podrán usarlo para reaccionar a las tarjetas y dejarse sorpresas visuales.',
              textAlign: TextAlign.center,
              style: AmodoroTheme.googleSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: mutedColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 26),
            AmodoroPressableButton(
              onTap: _openCreateSticker,
              height: 48,
              radius: 999,
              color: coralBg,
              lipColor: coralLip,
              lipHeight: 3.5,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AmodoroTheme.sysIcon(
                    Symbols.add,
                    size: 18,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'CREAR PRIMER STICKER',
                    style: AmodoroTheme.googleSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.9,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid({
    required Color cardBg,
    required Color borderColor,
    required Color inkColor,
    required Color mutedColor,
  }) {
    final myId = widget.sync?.me.id;
    final myAvatar = widget.sync?.me.avatarId ?? 'cat';
    final partnerAvatar = widget.sync?.partner?.avatarId ?? 'cat';

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemCount: _stickers.length,
      itemBuilder: (context, index) {
        final sticker = _stickers[index];
        final isMine = sticker.isMine || (myId != null && sticker.ownerId == myId);
        final creatorAvatar = isMine ? myAvatar : partnerAvatar;
        final resolvedUrl = widget.api.resolveMediaUrl(sticker.mediaUrl);
        final heroTag = 'sticker_${sticker.id}';

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FullscreenMediaViewer.open(
            context,
            imageUrl: resolvedUrl,
            heroTag: heroTag,
          ),
          onLongPress: isMine ? () => _confirmDeleteSticker(sticker) : null,
          child: Container(
            decoration: AmodoroTheme.cardOutlineBox(
              color: cardBg,
              radius: 22,
              borderColor: borderColor,
              borderWidth: 1.5,
              subtleShadow: true,
            ),
            child: Stack(
              children: [
                // Imagen del sticker con BoxFit.contain
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Hero(
                      tag: heroTag,
                      child: AmodoroImage(
                        imageUrl: resolvedUrl,
                        fit: BoxFit.contain,
                        errorPlaceholder: Center(
                          child: AmodoroTheme.sysIcon(
                            Symbols.sentiment_satisfied,
                            size: 28,
                            color: mutedColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Distintivo del creador en la esquina inferior derecha
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: borderColor,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: FlatAvatarBadge(
                      avatarId: creatorAvatar,
                      size: 22,
                      showPerspectiveBorder: false,
                    ),
                  ),
                ),

                // Botón discreto de eliminar si es propio
                if (isMine)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _confirmDeleteSticker(sticker),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        child: AmodoroTheme.sysIcon(
                          Symbols.close,
                          size: 14,
                          color: mutedColor,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
