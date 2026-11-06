import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/amodoro_models.dart';
import '../services/api_client.dart';
import '../theme/amodoro_theme.dart';
import '../widgets/pressable_button.dart';

enum StickerShape {
  circle,
  roundedRect,
  square,
}

class StickerEditorScreen extends StatefulWidget {
  final AmodoroApiClient api;
  final SyncPayload? sync;

  const StickerEditorScreen({
    super.key,
    required this.api,
    this.sync,
  });

  @override
  State<StickerEditorScreen> createState() => _StickerEditorScreenState();
}

class _StickerEditorScreenState extends State<StickerEditorScreen> {
  static const double _cropInnerSize = 264.0;
  static const double _borderThickness = 8.0;

  StickerShape _selectedShape = StickerShape.circle;
  ui.Image? _decodedImage;
  double _childWidth = _cropInnerSize;
  double _childHeight = _cropInnerSize;
  final TransformationController _transformController =
      TransformationController();
  bool _loadingImage = false;
  bool _saving = false;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 94,
      );
      if (picked == null) return;

      setState(() => _loadingImage = true);

      final bytes = await picked.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final double imgW = image.width.toDouble();
      final double imgH = image.height.toDouble();

      double childW;
      double childH;
      if (imgW >= imgH) {
        childH = _cropInnerSize;
        childW = _cropInnerSize * (imgW / imgH);
      } else {
        childW = _cropInnerSize;
        childH = _cropInnerSize * (imgH / imgW);
      }

      final double tx = (_cropInnerSize - childW) / 2.0;
      final double ty = (_cropInnerSize - childH) / 2.0;

      _transformController.value = Matrix4.identity()..translate(tx, ty);

      setState(() {
        _decodedImage = image;
        _childWidth = childW;
        _childHeight = childH;
        _loadingImage = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: $e')),
        );
      }
    }
  }

  Future<Uint8List> _generateStickerBytes() async {
    final source = _decodedImage;
    if (source == null) {
      throw Exception('No hay ninguna imagen cargada.');
    }

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, const Rect.fromLTWH(0, 0, 512, 512));

    const double borderWidth = 14.0;
    const double margin = 6.0;
    const double innerCanvasSize = 512.0 - 2 * (borderWidth + margin);

    final innerRect = Rect.fromLTWH(
      borderWidth + margin,
      borderWidth + margin,
      innerCanvasSize,
      innerCanvasSize,
    );
    final outerRect = Rect.fromLTWH(
      margin,
      margin,
      512.0 - 2 * margin,
      512.0 - 2 * margin,
    );

    Path innerPath;
    Path outerPath;

    switch (_selectedShape) {
      case StickerShape.circle:
        innerPath = Path()..addOval(innerRect);
        outerPath = Path()..addOval(outerRect);
        break;
      case StickerShape.roundedRect:
        innerPath = Path()
          ..addRRect(
            RRect.fromRectAndRadius(innerRect, const Radius.circular(56)),
          );
        outerPath = Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              outerRect,
              const Radius.circular(56 + borderWidth),
            ),
          );
        break;
      case StickerShape.square:
        innerPath = Path()
          ..addRRect(
            RRect.fromRectAndRadius(innerRect, const Radius.circular(24)),
          );
        outerPath = Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              outerRect,
              const Radius.circular(24 + borderWidth),
            ),
          );
        break;
    }

    // 1. Dibuja el borde exterior blanco nítido y grueso estilo calcomanía
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(outerPath, whitePaint);

    // 2. Recorta por la máscara interna y renderiza la foto ajustada
    canvas.save();
    canvas.clipPath(innerPath, doAntiAlias: true);

    final double scaleFactor = innerCanvasSize / _cropInnerSize;
    canvas.translate(borderWidth + margin, borderWidth + margin);
    canvas.scale(scaleFactor, scaleFactor);
    canvas.transform(_transformController.value.storage);

    final paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;

    canvas.drawImageRect(
      source,
      Rect.fromLTWH(
        0,
        0,
        source.width.toDouble(),
        source.height.toDouble(),
      ),
      Rect.fromLTWH(0, 0, _childWidth, _childHeight),
      paint,
    );

    canvas.restore();

    final picture = recorder.endRecording();
    final finalImage = await picture.toImage(512, 512);
    final byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Error al codificar imagen PNG del sticker.');
    }
    return byteData.buffer.asUint8List();
  }

  Future<void> _handleSaveSticker() async {
    if (_decodedImage == null || _saving) return;

    setState(() => _saving = true);
    try {
      final pngBytes = await _generateStickerBytes();
      await widget.api.createSticker(bytes: pngBytes, mime: 'image/png');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Sticker guardado exitosamente!')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar el sticker: $e')),
      );
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
                    child: Text(
                      'CREAR STICKER',
                      style: AmodoroTheme.googleSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: inkColor,
                      ),
                    ),
                  ),
                  if (_decodedImage != null)
                    AmodoroPressableButton(
                      onTap: () => _pickImage(ImageSource.gallery),
                      width: 44,
                      height: 44,
                      radius: 999,
                      color: cardBg,
                      borderColor: borderColor,
                      borderWidth: 1.5,
                      lipColor: borderColor,
                      lipHeight: 2.5,
                      child: AmodoroTheme.sysIcon(
                        Symbols.photo_library,
                        size: 20,
                        color: inkColor,
                      ),
                    ),
                ],
              ),
            ),

            // Contenido principal
            Expanded(
              child: _loadingImage
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : _decodedImage == null
                      ? _buildEmptyState(
                          cardBg: cardBg,
                          borderColor: borderColor,
                          inkColor: inkColor,
                          mutedColor: mutedColor,
                          coralBg: coralBg,
                          coralLip: coralLip,
                        )
                      : _buildEditorView(
                          cardBg: cardBg,
                          borderColor: borderColor,
                          inkColor: inkColor,
                          mutedColor: mutedColor,
                          coralBg: coralBg,
                          coralLip: coralLip,
                        ),
            ),

            // Botón inferior para guardar
            if (_decodedImage != null)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                child: AmodoroPressableButton(
                  onTap: _saving ? null : _handleSaveSticker,
                  height: 52,
                  radius: 999,
                  color: coralBg,
                  lipColor: coralLip,
                  lipHeight: 3.5,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AmodoroTheme.sysIcon(
                              Symbols.add,
                              size: 20,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'GUARDAR STICKER',
                              style: AmodoroTheme.googleSans(
                                fontSize: 13.5,
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
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required Color cardBg,
    required Color borderColor,
    required Color inkColor,
    required Color mutedColor,
    required Color coralBg,
    required Color coralLip,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFFFDAD6),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFF27166),
                  width: 3.0,
                ),
              ),
              child: Center(
                child: AmodoroTheme.sysIcon(
                  Symbols.sentiment_satisfied,
                  size: 52,
                  color: const Color(0xFF8B2B24),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Crea un sticker para tu pareja',
              textAlign: TextAlign.center,
              style: AmodoroTheme.googleSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: inkColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Elige una foto de la galería o toma una nueva. Podrás recortarla en círculo o rectángulo y añadirle un borde calcomanía.',
              textAlign: TextAlign.center,
              style: AmodoroTheme.googleSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: mutedColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            AmodoroPressableButton(
              onTap: () => _pickImage(ImageSource.gallery),
              height: 50,
              radius: 999,
              color: coralBg,
              lipColor: coralLip,
              lipHeight: 3.5,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AmodoroTheme.sysIcon(
                    Symbols.photo_library,
                    size: 20,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'ELEGIR DE LA GALERÍA',
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
            const SizedBox(height: 14),
            AmodoroPressableButton(
              onTap: () => _pickImage(ImageSource.camera),
              height: 50,
              radius: 999,
              color: cardBg,
              borderColor: borderColor,
              borderWidth: 1.5,
              lipColor: borderColor,
              lipHeight: 3.0,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AmodoroTheme.sysIcon(
                    Symbols.photo_camera,
                    size: 20,
                    color: inkColor,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'TOMAR FOTO CON CÁMARA',
                    style: AmodoroTheme.googleSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.9,
                      color: inkColor,
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

  Widget _buildEditorView({
    required Color cardBg,
    required Color borderColor,
    required Color inkColor,
    required Color mutedColor,
    required Color coralBg,
    required Color coralLip,
  }) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        children: [
          // Área de encuadre con fondo tipo patrón de transparencia
          Container(
            padding: const EdgeInsets.all(18),
            decoration: AmodoroTheme.cardOutlineBox(
              color: cardBg,
              radius: 32,
              borderColor: borderColor,
              borderWidth: 2.0,
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: _cropInnerSize + 2 * _borderThickness,
                    height: _cropInnerSize + 2 * _borderThickness,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3ECE0),
                      borderRadius: BorderRadius.circular(
                        _selectedShape == StickerShape.circle
                            ? 999
                            : (_selectedShape == StickerShape.roundedRect
                                ? 44
                                : 26),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          _selectedShape == StickerShape.circle
                              ? 999
                              : (_selectedShape == StickerShape.roundedRect
                                  ? 44
                                  : 26),
                        ),
                      ),
                      padding: const EdgeInsets.all(_borderThickness),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          _selectedShape == StickerShape.circle
                              ? 999
                              : (_selectedShape == StickerShape.roundedRect
                                  ? 36
                                  : 18),
                        ),
                        child: SizedBox(
                          width: _cropInnerSize,
                          height: _cropInnerSize,
                          child: InteractiveViewer(
                            transformationController: _transformController,
                            minScale: 0.5,
                            maxScale: 4.0,
                            boundaryMargin: const EdgeInsets.all(180),
                            clipBehavior: Clip.none,
                            child: SizedBox(
                              width: _childWidth,
                              height: _childHeight,
                              child: RawImage(
                                image: _decodedImage,
                                width: _childWidth,
                                height: _childHeight,
                                fit: BoxFit.fill,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AmodoroTheme.sysIcon(
                      Symbols.pinch,
                      size: 16,
                      color: mutedColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Pellizca para zoom o arrastra para encuadrar',
                      style: AmodoroTheme.googleSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: mutedColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Selector de forma de sticker
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AmodoroTheme.cardOutlineBox(
              color: cardBg,
              radius: 28,
              borderColor: borderColor,
              borderWidth: 2.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FORMA DEL STICKER',
                  style: AmodoroTheme.googleSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: inkColor,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildShapeOption(
                        shape: StickerShape.circle,
                        label: 'Círculo',
                        icon: Symbols.circle,
                        coralBg: coralBg,
                        coralLip: coralLip,
                        borderColor: borderColor,
                        inkColor: inkColor,
                        mutedColor: mutedColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildShapeOption(
                        shape: StickerShape.roundedRect,
                        label: 'Redondeado',
                        icon: Symbols.crop_square_rounded,
                        coralBg: coralBg,
                        coralLip: coralLip,
                        borderColor: borderColor,
                        inkColor: inkColor,
                        mutedColor: mutedColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildShapeOption(
                        shape: StickerShape.square,
                        label: 'Cuadrado',
                        icon: Symbols.square,
                        coralBg: coralBg,
                        coralLip: coralLip,
                        borderColor: borderColor,
                        inkColor: inkColor,
                        mutedColor: mutedColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Botones para cambiar imagen
          Row(
            children: [
              Expanded(
                child: AmodoroPressableButton(
                  onTap: () => _pickImage(ImageSource.gallery),
                  height: 44,
                  radius: 999,
                  color: cardBg,
                  borderColor: borderColor,
                  borderWidth: 1.5,
                  lipColor: borderColor,
                  lipHeight: 2.5,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AmodoroTheme.sysIcon(
                        Symbols.photo_library,
                        size: 18,
                        color: inkColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'GALERÍA',
                        style: AmodoroTheme.googleSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.9,
                          color: inkColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AmodoroPressableButton(
                  onTap: () => _pickImage(ImageSource.camera),
                  height: 44,
                  radius: 999,
                  color: cardBg,
                  borderColor: borderColor,
                  borderWidth: 1.5,
                  lipColor: borderColor,
                  lipHeight: 2.5,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AmodoroTheme.sysIcon(
                        Symbols.photo_camera,
                        size: 18,
                        color: inkColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'CÁMARA',
                        style: AmodoroTheme.googleSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.9,
                          color: inkColor,
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
    );
  }

  Widget _buildShapeOption({
    required StickerShape shape,
    required String label,
    required IconData icon,
    required Color coralBg,
    required Color coralLip,
    required Color borderColor,
    required Color inkColor,
    required Color mutedColor,
  }) {
    final isSelected = _selectedShape == shape;
    return AmodoroPressableButton(
      onTap: () => setState(() => _selectedShape = shape),
      height: 44,
      radius: 16,
      color: isSelected ? coralBg : const Color(0xFFF6EFE6),
      borderColor: isSelected ? coralLip : borderColor,
      borderWidth: 1.5,
      lipColor: isSelected ? coralLip : borderColor,
      lipHeight: 2.5,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AmodoroTheme.sysIcon(
            icon,
            size: 18,
            color: isSelected ? Colors.white : inkColor,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AmodoroTheme.googleSans(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                color: isSelected ? Colors.white : inkColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
