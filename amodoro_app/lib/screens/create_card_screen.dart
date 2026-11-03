import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/amodoro_models.dart';
import '../services/api_client.dart';
import '../theme/amodoro_theme.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/link_preview_card.dart';
import '../widgets/pressable_button.dart';

class CreateCardScreen extends StatefulWidget {
  final AmodoroApiClient api;
  final String partnerNickname;
  final HomeCardItem? existingCard;
  final HomeCardItem? editingCard;
  final String? initialSharedUrl;

  const CreateCardScreen({
    super.key,
    required this.api,
    this.partnerNickname = 'Pareja',
    this.existingCard,
    this.editingCard,
    this.initialSharedUrl,
  });

  @override
  State<CreateCardScreen> createState() => _CreateCardScreenState();
}

class _CreateCardScreenState extends State<CreateCardScreen> {
  final TextEditingController _textController = TextEditingController();
  late final TextEditingController _altTextController;
  final TextEditingController _linkController = TextEditingController();
  final DrawingCanvasController _drawingController = DrawingCanvasController();
  final ImagePicker _picker = ImagePicker();

  // 'none' = cuadrícula de 4 opciones
  // 'image' = foto tomada o imagen elegida (nueva o existente)
  // 'drawing' = lienzo de dibujo activo (nuevo o existente)
  // 'link' = link embebido con vista previa
  String _mediaType = 'none';
  String? _imageDataUrl;
  String? _existingRemoteMediaUrl;
  String _existingRemoteMediaType = 'image';
  LinkPreviewModel? _linkPreview;

  String _bgColor = '#FFDAD6';
  String _fontFamily = 'sans';
  int _fontSizePx = 18;
  bool _sending = false;
  bool _loadingLink = false;

  static const List<Map<String, String>> _fontOptions = [
    {'key': 'sans', 'label': 'FUENTE · SANS'},
    {'key': 'serif', 'label': 'FUENTE · SERIF'},
    {'key': 'hand', 'label': 'FUENTE · CALIGRAFÍA'},
    {'key': 'mono', 'label': 'FUENTE · MONO'},
  ];

  static const List<int> _sizeOptions = [14, 18, 22, 26, 32];

  HomeCardItem? get _targetEditingCard =>
      widget.editingCard ?? widget.existingCard;

  @override
  void initState() {
    super.initState();
    final card = _targetEditingCard;
    _altTextController = TextEditingController(text: card?.altText ?? '');

    if (card != null) {
      _textController.text = card.textContent;
      _bgColor = card.bgColor;
      for (final preset in AmodoroTheme.pastelPresets) {
        if (preset.hex.toUpperCase() == card.bgColor.trim().toUpperCase()) {
          _bgColor = preset.hex;
          break;
        }
      }
      _fontFamily = _fontOptions.any((o) => o['key'] == card.fontFamily)
          ? card.fontFamily
          : 'sans';
      _fontSizePx =
          _sizeOptions.contains(card.fontSizePx) ? card.fontSizePx : 18;
      if (card.mediaType == 'link' &&
          card.linkUrl != null &&
          card.linkUrl!.isNotEmpty) {
        _mediaType = 'link';
        _linkController.text = card.linkUrl!;
        _linkPreview = LinkPreviewModel(
          url: card.linkUrl!,
          title: (card.linkTitle != null && card.linkTitle!.isNotEmpty)
              ? card.linkTitle!
              : card.linkUrl!,
          thumbnail: card.linkThumbnail,
          platform: card.linkPlatform ?? 'Web',
        );
      } else if (card.mediaType != 'none' &&
          card.mediaUrl != null &&
          card.mediaUrl!.isNotEmpty) {
        _existingRemoteMediaUrl = widget.api.resolveMediaUrl(card.mediaUrl);
        _existingRemoteMediaType =
            card.mediaType == 'drawing' ? 'drawing' : 'image';
        _mediaType = _existingRemoteMediaType;
      }
    } else if (widget.initialSharedUrl != null &&
        widget.initialSharedUrl!.trim().isNotEmpty) {
      final sharedUrl = widget.initialSharedUrl!.trim();
      _mediaType = 'link';
      _linkController.text = sharedUrl;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchLinkPreviewForUrl(sharedUrl);
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _altTextController.dispose();
    _linkController.dispose();
    _drawingController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1440,
        maxHeight: 1440,
        imageQuality: 82,
      );
      if (picked == null) {
        return;
      }
      final bytes = await picked.readAsBytes();
      final ext = picked.path.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
      if (mounted) {
        setState(() {
          _imageDataUrl = 'data:image/$ext;base64,${base64Encode(bytes)}';
          _mediaType = 'image';
          _linkPreview = null;
          _existingRemoteMediaUrl = null;
        });
      }
    } catch (_) {}
  }

  void _openDrawingMode() {
    setState(() {
      _mediaType = 'drawing';
      _imageDataUrl = null;
      _linkPreview = null;
      _existingRemoteMediaUrl = null;
    });
  }

  void _cancelMediaSelection() {
    _drawingController.clear();
    setState(() {
      _mediaType = 'none';
      _imageDataUrl = null;
      _linkPreview = null;
      _existingRemoteMediaUrl = null;
    });
  }

  Future<void> _fetchLinkPreviewForUrl(String rawUrl) async {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _loadingLink = true;
      _mediaType = 'link';
    });
    try {
      final preview = await widget.api.fetchLinkPreview(trimmed);
      if (mounted) {
        setState(() {
          _loadingLink = false;
          _linkPreview = preview;
          _mediaType = 'link';
          _imageDataUrl = null;
          _existingRemoteMediaUrl = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingLink = false;
          _linkPreview = LinkPreviewModel(
            url: trimmed,
            title: trimmed,
            platform: 'Web',
          );
          _mediaType = 'link';
          _imageDataUrl = null;
          _existingRemoteMediaUrl = null;
        });
      }
    }
  }

  Future<void> _openLinkDialog() async {
    final linkCtrl = TextEditingController(text: _linkController.text);
    final rawUrl = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bg =
            isDark ? AmodoroTheme.darkBackground : AmodoroTheme.lightBackground;
        final boxSurface =
            isDark ? AmodoroTheme.darkContainer : Colors.white;
        final ink = isDark ? AmodoroTheme.darkInk : AmodoroTheme.lightInk;
        final borderCol =
            isDark ? const Color(0xFF383232) : const Color(0xFFE9E4DC);

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: AmodoroTheme.cardOutlineBox(
              color: bg,
              radius: 26,
              borderColor: borderCol,
              borderWidth: 2.5,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'INSERTAR LINK EMBEBIDO',
                  style: AmodoroTheme.googleSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: AmodoroTheme.cardOutlineBox(
                    color: boxSurface,
                    radius: 16,
                    borderColor: borderCol,
                    borderWidth: 1.5,
                    subtleShadow: false,
                  ),
                  child: TextField(
                    controller: linkCtrl,
                    autofocus: true,
                    style: AmodoroTheme.googleSans(
                      fontSize: 13.5,
                      color: ink,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Link de Instagram, YouTube, Spotify...',
                      icon: AmodoroTheme.sysIcon(
                        Symbols.link,
                        size: 18,
                        color: ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AmodoroPressableButton(
                        onTap: () => Navigator.pop(ctx, null),
                        height: 44,
                        radius: 16,
                        color: boxSurface,
                        borderColor: borderCol,
                        borderWidth: 1.5,
                        lipColor: isDark
                            ? const Color(0xFF141111)
                            : const Color(0xFFDFD8CE),
                        lipHeight: 2.5,
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
                        onTap: () => Navigator.pop(ctx, linkCtrl.text.trim()),
                        height: 44,
                        radius: 16,
                        color: isDark
                            ? AmodoroTheme.coralPillDark
                            : AmodoroTheme.coralPillLight,
                        lipColor: isDark
                            ? AmodoroTheme.coralPillBorderDark
                            : AmodoroTheme.coralPillBorderLight,
                        lipHeight: 2.8,
                        child: Text(
                          'AÑADIR LINK',
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

    if (rawUrl == null || rawUrl.trim().isEmpty) {
      return;
    }

    _linkController.text = rawUrl.trim();
    await _fetchLinkPreviewForUrl(rawUrl.trim());
  }

  String _sizeKeyFromPx(int px) {
    if (px <= 14) return 'sm';
    if (px <= 18) return 'md';
    if (px <= 22) return 'lg';
    return 'xl';
  }

  Future<void> _submitCard() async {
    final editingCard = _targetEditingCard;
    final text = _textController.text.trim();
    final altTextVal = _altTextController.text.trim();

    String finalMediaType = 'none';
    String? finalMediaDataUrl;
    String? linkUrl;
    String? linkTitle;
    String? linkThumbnail;
    String? linkPlatform;

    final keepExisting = editingCard != null &&
        _existingRemoteMediaUrl != null &&
        _imageDataUrl == null &&
        (_mediaType == 'image' || _mediaType == 'drawing');

    if (keepExisting) {
      finalMediaType = _existingRemoteMediaType;
    } else if (_mediaType == 'image' && _imageDataUrl != null) {
      finalMediaType = 'image';
      finalMediaDataUrl = _imageDataUrl;
    } else if (_mediaType == 'drawing' && !_drawingController.isEmpty) {
      finalMediaDataUrl = await _drawingController.toPngDataUrl();
      if (finalMediaDataUrl != null) {
        finalMediaType = 'drawing';
      }
    } else if (_mediaType == 'link' && _linkPreview != null) {
      finalMediaType = 'link';
      linkUrl = _linkPreview!.url;
      linkTitle = _linkPreview!.title;
      linkThumbnail = _linkPreview!.thumbnail;
      linkPlatform = _linkPreview!.platform;
    }

    if (!(text.isNotEmpty ||
        finalMediaDataUrl != null ||
        finalMediaType == 'link' ||
        keepExisting)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escribe aquí tu mensaje o añade una opción arriba.'),
        ),
      );
      return;
    }

    final fontSizeKey = _sizeKeyFromPx(_fontSizePx);
    final effectiveAltText =
        (finalMediaType == 'image' || finalMediaType == 'drawing')
            ? altTextVal
            : '';

    setState(() => _sending = true);
    try {
      if (editingCard != null) {
        await widget.api.updateHomeCard(
          cardId: editingCard.id,
          textContent: text,
          bgColor: _bgColor,
          fontFamily: _fontFamily,
          fontSize: fontSizeKey,
          fontSizePx: _fontSizePx,
          mediaType: keepExisting ? _existingRemoteMediaType : finalMediaType,
          keepExistingMedia: keepExisting,
          mediaDataUrl: finalMediaDataUrl,
          altText: effectiveAltText,
          linkUrl: finalMediaType == 'link' ? _linkPreview?.url : null,
          linkTitle: finalMediaType == 'link' ? _linkPreview?.title : null,
          linkThumbnail:
              finalMediaType == 'link' ? _linkPreview?.thumbnail : null,
          linkPlatform:
              finalMediaType == 'link' ? _linkPreview?.platform : null,
        );
      } else {
        await widget.api.createHomeCard(
          textContent: text,
          bgColor: _bgColor,
          fontFamily: _fontFamily,
          fontSize: fontSizeKey,
          fontSizePx: _fontSizePx,
          mediaType: finalMediaType,
          mediaDataUrl: finalMediaDataUrl,
          altText: effectiveAltText,
          linkUrl: linkUrl,
          linkTitle: linkTitle,
          linkThumbnail: linkThumbnail,
          linkPlatform: linkPlatform,
        );
      }
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
    final isEditing = _targetEditingCard != null;
    final selectedBgColor = AmodoroTheme.parseHexColor(_bgColor);
    final cardInk = AmodoroTheme.getContrastingInk(selectedBgColor);
    final cardMuted = AmodoroTheme.getContrastingMutedInk(selectedBgColor);
    final capsuleSurface =
        isDark ? AmodoroTheme.darkContainer : const Color(0xFFF6EFE6);
    final capsuleBorder =
        isDark ? const Color(0xFF3A3333) : const Color(0xFFE5DEC9);
    final capsuleLip =
        isDark ? const Color(0xFF141111) : const Color(0xFFE0D4C3);
    final screenInk = isDark ? AmodoroTheme.darkInk : AmodoroTheme.lightInk;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Back / Close Pressable Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AmodoroPressableButton(
                    onTap: () => Navigator.of(context).pop(false),
                    width: 44,
                    height: 40,
                    radius: 14,
                    color: capsuleSurface,
                    borderColor: capsuleBorder,
                    borderWidth: 1.5,
                    lipColor: capsuleLip,
                    lipHeight: 2.8,
                    child: AmodoroTheme.sysIcon(
                      Symbols.arrow_back,
                      size: 20,
                      color: screenInk,
                    ),
                  ),
                  Text(
                    isEditing ? 'EDITAR TARJETA' : 'NUEVA TARJETA',
                    style: AmodoroTheme.googleSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
              const SizedBox(height: 16),

              // Main Card Preview Container: Border-only (NO 3D bottom lip)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AmodoroTheme.cardOutlineBox(
                  color: selectedBgColor,
                  radius: 32,
                  borderColor: AmodoroTheme.darkenForPerspective(
                    selectedBgColor,
                    0.12,
                  ),
                  borderWidth: 3.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Media Section (2x2 Pressable Grid or Selected Media)
                    _buildTopMediaSection(selectedBgColor, cardInk),

                    // Optional Alt Text / Image Note when _mediaType == 'image' || _mediaType == 'drawing'
                    if (_mediaType == 'image' || _mediaType == 'drawing') ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 2,
                        ),
                        decoration: AmodoroTheme.cardOutlineBox(
                          color: Colors.white.withValues(alpha: 0.65),
                          radius: 16,
                          borderColor: AmodoroTheme.darkenForPerspective(
                            selectedBgColor,
                            0.14,
                          ),
                          borderWidth: 1.5,
                          subtleShadow: false,
                        ),
                        child: TextField(
                          controller: _altTextController,
                          maxLines: 2,
                          minLines: 1,
                          style: AmodoroTheme.googleSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AmodoroTheme.lightInk,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 10),
                            hintText:
                                'Nota o descripción de la imagen (opcional)...',
                            hintStyle: AmodoroTheme.googleSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AmodoroTheme.lightMuted,
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),

                    // Direct text editor inside the card
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

              // 3 Typography Dropdown Capsules using AmodoroPressableButton
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: _buildFontDropdownCapsule(
                      capsuleSurface,
                      capsuleBorder,
                      capsuleLip,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: _buildSizeDropdownCapsule(
                      capsuleSurface,
                      capsuleBorder,
                      capsuleLip,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: _buildColorDropdownCapsule(
                      capsuleSurface,
                      capsuleBorder,
                      capsuleLip,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Bottom Submit Button using AmodoroPressableButton
              AmodoroPressableButton(
                onTap: _sending ? null : _submitCard,
                height: 52,
                radius: 18,
                color: isDark
                    ? AmodoroTheme.coralPillDark
                    : AmodoroTheme.coralPillLight,
                lipColor: isDark
                    ? AmodoroTheme.coralPillBorderDark
                    : AmodoroTheme.coralPillBorderLight,
                lipHeight: 4.0,
                child: Text(
                  isEditing
                      ? (_sending ? 'GUARDANDO...' : 'GUARDAR CAMBIOS')
                      : (_sending
                          ? 'PUBLICANDO...'
                          : 'ENVIAR A ${widget.partnerNickname.toUpperCase()}'),
                  style: AmodoroTheme.googleSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExistingMediaPreview(String url) {
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
      isDark ? 0.14 : 0.16,
    );
    final containerBorder = AmodoroTheme.darkenForPerspective(
      cardColor,
      0.14,
    );

    if (_loadingLink) {
      return AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          decoration: AmodoroTheme.cardOutlineBox(
            color: canvasOuterColor,
            radius: 24,
            borderColor: containerBorder,
            borderWidth: 2.0,
            subtleShadow: false,
          ),
          child: Center(
            child: Text(
              'CARGANDO VISTA PREVIA DEL LINK...',
              textAlign: TextAlign.center,
              style: AmodoroTheme.googleSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: canvasInk,
              ),
            ),
          ),
        ),
      );
    }

    if (_existingRemoteMediaUrl != null &&
        _imageDataUrl == null &&
        (_mediaType == 'image' || _mediaType == 'drawing')) {
      return AspectRatio(
        aspectRatio: 1.0,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.65),
                  width: 2.0,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  color: canvasOuterColor,
                  child: _buildExistingMediaPreview(_existingRemoteMediaUrl!),
                ),
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

    if (_mediaType == 'image' && _imageDataUrl != null) {
      final comma = _imageDataUrl!.indexOf(',');
      final bytes = base64Decode(_imageDataUrl!.substring(comma + 1));
      return AspectRatio(
        aspectRatio: 1.0,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.65),
                  width: 2.0,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.memory(
                  bytes,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                ),
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

    if (_mediaType == 'drawing') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: AmodoroTheme.cardOutlineBox(
          color: canvasOuterColor,
          radius: 24,
          borderColor: containerBorder,
          borderWidth: 2.0,
          subtleShadow: false,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'LIENZO DE DIBUJO',
                  style: AmodoroTheme.googleSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
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

    if (_mediaType == 'link' && _linkPreview != null) {
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

    // Default 2x2 media selector grid inside a border-only container
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AmodoroTheme.cardOutlineBox(
          color: canvasOuterColor,
          radius: 26,
          borderColor: containerBorder,
          borderWidth: 2.0,
          subtleShadow: false,
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
                      onTap: () => _pickImage(ImageSource.camera),
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
                      onTap: () => _pickImage(ImageSource.gallery),
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
    return AmodoroPressableButton(
      onTap: onTap,
      color: tileColor,
      borderColor: edgeColor.withValues(alpha: 0.45),
      borderWidth: 1.5,
      lipColor: edgeColor,
      lipHeight: 3.2,
      radius: 20,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AmodoroTheme.sysIcon(icon, size: 28, color: inkColor),
          const SizedBox(height: 8),
          Text(
            label,
            style: AmodoroTheme.googleSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: inkColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelMediaChip() {
    return AmodoroPressableButton(
      onTap: _cancelMediaSelection,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: const Color(0xFFFCF9F5),
      borderColor: const Color(0xFFE5DEC9),
      borderWidth: 1.5,
      lipColor: const Color(0xFFD8CCB8),
      lipHeight: 2.2,
      radius: 999,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AmodoroTheme.sysIcon(
            Symbols.close,
            size: 15,
            color: const Color(0xFF1F1B18),
          ),
          const SizedBox(width: 4),
          Text(
            'SOLO TEXTO',
            style: AmodoroTheme.googleSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: const Color(0xFF1F1B18),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFontPicker() async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final surface =
            isDark ? AmodoroTheme.darkBackground : AmodoroTheme.lightBackground;
        final ink = isDark ? AmodoroTheme.darkInk : AmodoroTheme.lightInk;
        final borderCol =
            isDark ? const Color(0xFF383232) : const Color(0xFFE9E4DC);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: AmodoroTheme.cardOutlineBox(
                color: surface,
                radius: 28,
                borderColor: borderCol,
                borderWidth: 2.5,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _fontOptions.map((opt) {
                  final key = opt['key']!;
                  final selected = key == _fontFamily;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AmodoroPressableButton(
                      onTap: () => Navigator.of(ctx).pop(key),
                      height: 44,
                      radius: 14,
                      color: selected
                          ? (isDark
                              ? AmodoroTheme.coralPillDark
                              : AmodoroTheme.coralPillLight)
                          : (isDark
                              ? AmodoroTheme.darkContainer
                              : Colors.white),
                      borderColor: selected ? null : borderCol,
                      borderWidth: selected ? 0.0 : 1.5,
                      lipColor: selected
                          ? (isDark
                              ? AmodoroTheme.coralPillBorderDark
                              : AmodoroTheme.coralPillBorderLight)
                          : (isDark
                              ? const Color(0xFF141111)
                              : const Color(0xFFDFD8CE)),
                      lipHeight: 2.5,
                      child: Text(
                        opt['label']!,
                        style: AmodoroTheme.googleSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: selected ? Colors.white : ink,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
    if (chosen != null && mounted) {
      setState(() => _fontFamily = chosen);
    }
  }

  Future<void> _showSizePicker() async {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final surface =
            isDark ? AmodoroTheme.darkBackground : AmodoroTheme.lightBackground;
        final ink = isDark ? AmodoroTheme.darkInk : AmodoroTheme.lightInk;
        final borderCol =
            isDark ? const Color(0xFF383232) : const Color(0xFFE9E4DC);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: AmodoroTheme.cardOutlineBox(
                color: surface,
                radius: 28,
                borderColor: borderCol,
                borderWidth: 2.5,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _sizeOptions.map((px) {
                  final selected = px == _fontSizePx;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AmodoroPressableButton(
                      onTap: () => Navigator.of(ctx).pop(px),
                      height: 44,
                      radius: 14,
                      color: selected
                          ? (isDark
                              ? AmodoroTheme.coralPillDark
                              : AmodoroTheme.coralPillLight)
                          : (isDark
                              ? AmodoroTheme.darkContainer
                              : Colors.white),
                      borderColor: selected ? null : borderCol,
                      borderWidth: selected ? 0.0 : 1.5,
                      lipColor: selected
                          ? (isDark
                              ? AmodoroTheme.coralPillBorderDark
                              : AmodoroTheme.coralPillBorderLight)
                          : (isDark
                              ? const Color(0xFF141111)
                              : const Color(0xFFDFD8CE)),
                      lipHeight: 2.5,
                      child: Text(
                        '$px PX',
                        style: AmodoroTheme.googleSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: selected ? Colors.white : ink,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
    if (chosen != null && mounted) {
      setState(() => _fontSizePx = chosen);
    }
  }

  Future<void> _showColorPicker() async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final surface =
            isDark ? AmodoroTheme.darkBackground : AmodoroTheme.lightBackground;
        final ink = isDark ? AmodoroTheme.darkInk : AmodoroTheme.lightInk;
        final borderCol =
            isDark ? const Color(0xFF383232) : const Color(0xFFE9E4DC);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: AmodoroTheme.cardOutlineBox(
                color: surface,
                radius: 28,
                borderColor: borderCol,
                borderWidth: 2.5,
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: AmodoroTheme.pastelPresets.map((preset) {
                  final selected =
                      preset.hex.toUpperCase() == _bgColor.toUpperCase();
                  return AmodoroPressableButton(
                    onTap: () => Navigator.of(ctx).pop(preset.hex),
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    radius: 14,
                    color: preset.color,
                    borderColor: selected
                        ? AmodoroTheme.coralPillLight
                        : AmodoroTheme.darkenForPerspective(preset.color, 0.14),
                    borderWidth: selected ? 2.5 : 1.5,
                    lipColor: AmodoroTheme.darkenForPerspective(
                      preset.color,
                      0.18,
                    ),
                    lipHeight: 2.8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          preset.name.toUpperCase(),
                          style: AmodoroTheme.googleSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: ink,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
    if (chosen != null && mounted) {
      setState(() => _bgColor = chosen);
    }
  }

  Widget _buildFontDropdownCapsule(
    Color surface,
    Color borderCol,
    Color lipCol,
  ) {
    final currentLabel = _fontOptions.firstWhere(
      (o) => o['key'] == _fontFamily,
      orElse: () => _fontOptions.first,
    )['label']!;
    final ink = Theme.of(context).colorScheme.onSurface;

    return AmodoroPressableButton(
      onTap: _showFontPicker,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: surface,
      borderColor: borderCol,
      borderWidth: 1.5,
      lipColor: lipCol,
      lipHeight: 2.8,
      radius: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              currentLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AmodoroTheme.googleSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: ink,
              ),
            ),
          ),
          AmodoroTheme.sysIcon(Symbols.expand_more, size: 18, color: ink),
        ],
      ),
    );
  }

  Widget _buildSizeDropdownCapsule(
    Color surface,
    Color borderCol,
    Color lipCol,
  ) {
    final ink = Theme.of(context).colorScheme.onSurface;

    return AmodoroPressableButton(
      onTap: _showSizePicker,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      color: surface,
      borderColor: borderCol,
      borderWidth: 1.5,
      lipColor: lipCol,
      lipHeight: 2.8,
      radius: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              '$_fontSizePx PX',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AmodoroTheme.googleSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: ink,
              ),
            ),
          ),
          AmodoroTheme.sysIcon(Symbols.expand_more, size: 18, color: ink),
        ],
      ),
    );
  }

  Widget _buildColorDropdownCapsule(
    Color surface,
    Color borderCol,
    Color lipCol,
  ) {
    final preset = AmodoroTheme.pastelPresets.firstWhere(
      (p) => p.hex.toUpperCase() == _bgColor.toUpperCase(),
      orElse: () => PastelPreset(
        id: 'custom',
        name: 'COLOR',
        hex: _bgColor,
        color: AmodoroTheme.parseHexColor(_bgColor),
      ),
    );
    final ink = Theme.of(context).colorScheme.onSurface;

    return AmodoroPressableButton(
      onTap: _showColorPicker,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      color: surface,
      borderColor: borderCol,
      borderWidth: 1.5,
      lipColor: lipCol,
      lipHeight: 2.8,
      radius: 16,
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: preset.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: AmodoroTheme.darkenForPerspective(preset.color, 0.16),
                width: 1.2,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              preset.name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AmodoroTheme.googleSans(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: ink,
              ),
            ),
          ),
          AmodoroTheme.sysIcon(Symbols.expand_more, size: 18, color: ink),
        ],
      ),
    );
  }
}
