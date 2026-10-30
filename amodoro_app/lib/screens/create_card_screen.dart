import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/amodoro_models.dart';
import '../services/api_client.dart';
import '../theme/amodoro_theme.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/link_preview_card.dart';

class CreateCardScreen extends StatefulWidget {
  final AmodoroApiClient api;
  final String partnerNickname;

  const CreateCardScreen({
    super.key,
    required this.api,
    required this.partnerNickname,
  });

  @override
  State<CreateCardScreen> createState() => _CreateCardScreenState();
}

class _CreateCardScreenState extends State<CreateCardScreen> {
  final TextEditingController _textController = TextEditingController();
  final DrawingCanvasController _drawingController = DrawingCanvasController();
  final ImagePicker _picker = ImagePicker();

  // 'none' = cuadrícula de 4 opciones (si no elige ninguna o cancela, se envía solo texto)
  // 'photo' = foto tomada o imagen elegida
  // 'drawing' = lienzo de dibujo activo
  // 'link' = link embebido con vista previa
  String _mediaMode = 'none';
  String? _imageDataUrl;
  LinkPreviewModel? _linkPreview;

  String _bgColor = '#FFDAD6';
  String _fontFamily = 'sans';
  int _fontSizePx = 18;
  bool _sending = false;
  bool _loadingLink = false;

  static const List<Map<String, String>> _fontOptions = [
    {'key': 'sans', 'label': 'FUENTE · RALEWAY'},
    {'key': 'serif', 'label': 'FUENTE · SERIF'},
    {'key': 'hand', 'label': 'FUENTE · CALIGRAFÍA'},
    {'key': 'mono', 'label': 'FUENTE · MONO'},
  ];

  @override
  void dispose() {
    _textController.dispose();
    _drawingController.dispose();
    super.dispose();
  }

  Future<void> _pickCameraOrGallery(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 84,
      );
      if (picked == null) {
        // Si cancela la cámara o galería, se mantiene en 'none' (solo texto)
        return;
      }
      final bytes = await picked.readAsBytes();
      final ext = picked.path.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
      if (mounted) {
        setState(() {
          _imageDataUrl = 'data:image/$ext;base64,${base64Encode(bytes)}';
          _mediaMode = 'photo';
          _linkPreview = null;
        });
      }
    } catch (_) {
      // Si el usuario cancela o no hay cámara disponible, permanece como solo texto
    }
  }

  void _openDrawingMode() {
    setState(() {
      _mediaMode = 'drawing';
      _imageDataUrl = null;
      _linkPreview = null;
    });
  }

  void _cancelMediaSelection() {
    _drawingController.clear();
    setState(() {
      _mediaMode = 'none';
      _imageDataUrl = null;
      _linkPreview = null;
    });
  }

  Future<void> _openLinkDialog() async {
    final linkCtrl = TextEditingController();
    final rawUrl = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final bg = Theme.of(ctx).scaffoldBackgroundColor;
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: AmodoroTheme.floatingPerspectiveBox(
              color: bg,
              radius: 26,
              thickness: 2.5,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'INSERTAR LINK EMBEBIDO',
                  style: TextStyle(fontSize: 12, letterSpacing: 1.4),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: AmodoroTheme.floatingPerspectiveBox(
                    color: Theme.of(ctx).colorScheme.surfaceContainer,
                    radius: 16,
                    thickness: 2.0,
                  ),
                  child: TextField(
                    controller: linkCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Link de Instagram, YouTube, Spotify...',
                      icon: AmodoroTheme.sysIcon(Symbols.link, size: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, null),
                        child: Container(
                          height: 42,
                          decoration: AmodoroTheme.floatingPerspectiveBox(
                            color: Theme.of(ctx).colorScheme.surfaceContainer,
                            radius: 999,
                            thickness: 2.0,
                          ),
                          child: const Center(
                            child: Text(
                              'CANCELAR',
                              style:
                                  TextStyle(fontSize: 11.5, letterSpacing: 1.2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, linkCtrl.text.trim()),
                        child: Container(
                          height: 42,
                          decoration: AmodoroTheme.floatingPerspectiveBox(
                            color: AmodoroTheme.coralPillLight,
                            radius: 999,
                            thickness: 2.0,
                          ),
                          child: const Center(
                            child: Text(
                              'AÑADIR LINK',
                              style: TextStyle(
                                fontSize: 11.5,
                                letterSpacing: 1.2,
                                color: AmodoroTheme.coralPillTextLight,
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

    if (rawUrl == null || rawUrl.trim().isEmpty) {
      // Si cancela el diálogo, permanece en modo 'none' (solo texto)
      return;
    }

    setState(() => _loadingLink = true);
    try {
      final preview = await widget.api.fetchLinkPreview(rawUrl.trim());
      if (mounted) {
        setState(() {
          _loadingLink = false;
          _linkPreview = preview;
          _mediaMode = 'link';
          _imageDataUrl = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingLink = false;
          _linkPreview = LinkPreviewModel(
            url: rawUrl.trim(),
            title: rawUrl.trim(),
            platform: 'Web',
          );
          _mediaMode = 'link';
        });
      }
    }
  }

  String _sizeKeyFromPx(int px) {
    if (px <= 14) return 'sm';
    if (px <= 18) return 'md';
    if (px <= 22) return 'lg';
    return 'xl';
  }

  Future<void> _submitCard() async {
    final text = _textController.text.trim();
    String finalMediaType = 'none';
    String? finalMediaDataUrl;
    String? linkUrl;
    String? linkTitle;
    String? linkThumbnail;
    String? linkPlatform;

    if (_mediaMode == 'photo' && _imageDataUrl != null) {
      finalMediaType = 'photo';
      finalMediaDataUrl = _imageDataUrl;
    } else if (_mediaMode == 'drawing' && !_drawingController.isEmpty) {
      finalMediaDataUrl = await _drawingController.toPngDataUrl();
      if (finalMediaDataUrl != null) {
        finalMediaType = 'drawing';
      }
    } else if (_mediaMode == 'link' && _linkPreview != null) {
      finalMediaType = 'link';
      linkUrl = _linkPreview!.url;
      linkTitle = _linkPreview!.title;
      linkThumbnail = _linkPreview!.thumbnail;
      linkPlatform = _linkPreview!.platform;
    }

    // Si no eligió ninguna opción (o cerró/canceló el lienzo/foto) y escribió texto, se sube solo texto
    if (text.isEmpty &&
        finalMediaDataUrl == null &&
        (linkUrl == null || linkUrl.isEmpty)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escribe aquí tu mensaje o añade una opción arriba.'),
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await widget.api.createHomeCard(
        textContent: text,
        bgColor: _bgColor,
        fontFamily: _fontFamily,
        fontSize: _sizeKeyFromPx(_fontSizePx),
        fontSizePx: _fontSizePx,
        mediaType: finalMediaType,
        mediaDataUrl: finalMediaDataUrl,
        linkUrl: linkUrl,
        linkTitle: linkTitle,
        linkThumbnail: linkThumbnail,
        linkPlatform: linkPlatform,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
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
    final cardColor = AmodoroTheme.parseHexColor(_bgColor);
    final cardInk = AmodoroTheme.getContrastingInk(cardColor);
    final cardMuted = AmodoroTheme.getContrastingMutedInk(cardColor);
    final capsuleSurface =
        isDark ? const Color(0xFF1F2421) : const Color(0xFFF4EFE8);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cápsula superior con X (como en el boceto)
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(false),
                  child: Container(
                    width: 120,
                    height: 38,
                    decoration: AmodoroTheme.floatingPerspectiveBox(
                      color: capsuleSurface,
                      radius: 999,
                      thickness: 2.5,
                    ),
                    child: Center(
                      child: AmodoroTheme.sysIcon(
                        Symbols.close,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Tarjeta principal donde se elige la opción superior y se edita el texto directamente sobre ella
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AmodoroTheme.floatingPerspectiveBox(
                  color: cardColor,
                  radius: 30,
                  thickness: 3.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Parte superior de la tarjeta: Cuadrícula 2x2 de 4 opciones (o el medio elegido con X para cancelar)
                    _buildTopMediaSection(cardColor, cardInk),

                    const SizedBox(height: 18),

                    // Edición de texto directamente sobre la misma tarjeta ("ESCRIBE AQUÍ")
                    TextField(
                      controller: _textController,
                      maxLines: null,
                      minLines: 4,
                      style: AmodoroTheme.getCardTextStyle(
                        fontFamily: _fontFamily,
                        color: cardInk,
                        fontSizePx: _fontSizePx,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'ESCRIBE AQUÍ',
                        hintStyle: AmodoroTheme.getCardTextStyle(
                          fontFamily: _fontFamily,
                          color: cardMuted.withValues(alpha: 0.65),
                          fontSizePx: _fontSizePx,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Fila inferior de 3 menús desplegables en cápsulas: FUENTE | COLOR
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: _buildFontDropdownCapsule(capsuleSurface),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: _buildColorDropdownCapsule(capsuleSurface),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Botón principal en MAYÚSCULAS con borde en perspectiva
              GestureDetector(
                onTap: _sending ? null : _submitCard,
                child: Container(
                  height: 50,
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
                  child: Center(
                    child: Text(
                      _sending
                          ? 'PUBLICANDO...'
                          : 'ENVIAR A ${widget.partnerNickname.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 12.5,
                        letterSpacing: 1.5,
                        color: isDark
                            ? AmodoroTheme.coralPillTextDark
                            : AmodoroTheme.coralPillTextLight,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopMediaSection(Color cardColor, Color cardInk) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canvasOuterColor = isDark
        ? AmodoroTheme.darkBackground
        : AmodoroTheme.lightBackground;
    final canvasTileColor = isDark
        ? AmodoroTheme.darkContainer
        : AmodoroTheme.lightContainer;
    final canvasInk = isDark ? AmodoroTheme.darkInk : AmodoroTheme.lightInk;
    final canvasEdge = AmodoroTheme.darkenForPerspective(
      canvasTileColor,
      isDark ? 0.14 : 0.18,
    );

    if (_loadingLink) {
      return AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          decoration: AmodoroTheme.floatingPerspectiveBox(
            color: canvasOuterColor,
            radius: 24,
            thickness: 2.5,
            perspectiveEdgeColor: canvasEdge,
          ),
          child: Center(
            child: Text(
              'CARGANDO VISTA PREVIA DEL LINK...',
              textAlign: TextAlign.center,
              style: TextStyle(color: canvasInk),
            ),
          ),
        ),
      );
    }

    if (_mediaMode == 'photo' && _imageDataUrl != null) {
      final comma = _imageDataUrl!.indexOf(',');
      final bytes = base64Decode(_imageDataUrl!.substring(comma + 1));
      return AspectRatio(
        aspectRatio: 1.0,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.memory(
                bytes,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: _buildCancelMediaChip(),
            ),
          ],
        ),
      );
    }

    if (_mediaMode == 'drawing') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: AmodoroTheme.floatingPerspectiveBox(
          color: canvasOuterColor,
          radius: 24,
          thickness: 2.5,
          perspectiveEdgeColor: canvasEdge,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'LIENZO DE DIBUJO',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: canvasInk,
                  ),
                ),
                _buildCancelMediaChip(),
              ],
            ),
            const SizedBox(height: 8),
            InteractiveDrawingPad(controller: _drawingController),
          ],
        ),
      );
    }

    if (_mediaMode == 'link' && _linkPreview != null) {
      return LinkPreviewCard(
        url: _linkPreview!.url,
        title: _linkPreview!.title,
        thumbnail: _linkPreview!.thumbnail,
        platform: _linkPreview!.platform,
        cardBgColor: canvasOuterColor,
        onRemove: _cancelMediaSelection,
        isSquare: true,
      );
    }

    // Por defecto: Cuadrícula 2x2 cuadrada (1:1) con colores basados en el fondo de la app
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AmodoroTheme.floatingPerspectiveBox(
          color: canvasOuterColor,
          radius: 26,
          thickness: 2.5,
          perspectiveEdgeColor: canvasEdge,
        ),
        child: Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildQuadOptionTile(
                      icon: Symbols.photo_camera,
                      label: 'CAPTURAR',
                      tileColor: canvasTileColor,
                      edgeColor: canvasEdge,
                      inkColor: canvasInk,
                      onTap: () => _pickCameraOrGallery(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuadOptionTile(
                      icon: Symbols.image,
                      label: 'IMAGEN',
                      tileColor: canvasTileColor,
                      edgeColor: canvasEdge,
                      inkColor: canvasInk,
                      onTap: () => _pickCameraOrGallery(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildQuadOptionTile(
                      icon: Symbols.edit,
                      label: 'DIBUJO',
                      tileColor: canvasTileColor,
                      edgeColor: canvasEdge,
                      inkColor: canvasInk,
                      onTap: _openDrawingMode,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuadOptionTile(
                      icon: Symbols.north_east,
                      label: 'LINK',
                      tileColor: canvasTileColor,
                      edgeColor: canvasEdge,
                      inkColor: canvasInk,
                      onTap: _openLinkDialog,
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

  Widget _buildQuadOptionTile({
    required IconData icon,
    required String label,
    required Color tileColor,
    required Color edgeColor,
    required Color inkColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: AmodoroTheme.floatingPerspectiveBox(
          color: tileColor,
          radius: 20,
          thickness: 2.5,
          perspectiveEdgeColor: edgeColor,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AmodoroTheme.sysIcon(icon, size: 28, color: inkColor),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                letterSpacing: 1.3,
                color: inkColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancelMediaChip() {
    return GestureDetector(
      onTap: _cancelMediaSelection,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: AmodoroTheme.floatingPerspectiveBox(
          color: const Color(0xFFFCF9F5),
          radius: 999,
          thickness: 2.0,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AmodoroTheme.sysIcon(
              Symbols.close,
              size: 15,
              color: const Color(0xFF1F1B18),
            ),
            const SizedBox(width: 4),
            const Text(
              'SOLO TEXTO',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.0,
                color: Color(0xFF1F1B18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFontDropdownCapsule(Color surface) {
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: AmodoroTheme.floatingPerspectiveBox(
        color: surface,
        radius: 999,
        thickness: 2.5,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _fontFamily,
          isExpanded: true,
          icon: AmodoroTheme.sysIcon(Symbols.expand_more, size: 18),
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.0,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          items: _fontOptions.map((opt) {
            return DropdownMenuItem<String>(
              value: opt['key'],
              child: Text(
                opt['label']!,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) setState(() => _fontFamily = v);
          },
        ),
      ),
    );
  }

  Widget _buildColorDropdownCapsule(Color surface) {
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: AmodoroTheme.floatingPerspectiveBox(
        color: surface,
        radius: 999,
        thickness: 2.5,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _bgColor,
          isExpanded: true,
          icon: AmodoroTheme.sysIcon(Symbols.expand_more, size: 18),
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.0,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          items: AmodoroTheme.pastelPresets.map((preset) {
            return DropdownMenuItem<String>(
              value: preset.hex,
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: preset.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      preset.name.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) setState(() => _bgColor = v);
          },
        ),
      ),
    );
  }
}
