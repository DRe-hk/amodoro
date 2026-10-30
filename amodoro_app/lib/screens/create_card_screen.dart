import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme/amodoro_theme.dart';
import '../widgets/drawing_canvas.dart';

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
  final TextEditingController _textController = TextEditingController(
    text: '¡Hoy pensé en ti y te dejé esta notita especial! ❤️',
  );
  final DrawingCanvasController _drawingController = DrawingCanvasController();

  String _mediaType = 'none'; // 'none' | 'drawing' | 'photo'
  String _bgColor = '#FFDAD6';
  String _fontFamily = 'sans';
  String _fontSize = 'lg';
  int _selectedPresetArt = 0;
  bool _sending = false;

  static const List<String> _emojis = [
    '❤️',
    '🥰',
    '✨',
    '🌸',
    '☕',
    '🌙',
    '🍕',
    '🎬',
    '🎵',
    '🫂'
  ];

  static const List<Map<String, String>> _artPresets = [
    {'title': 'Café Juntos ☕', 'emoji': '☕🥐', 'bg': '#F5E0B5'},
    {'title': 'Noche Estrellada 🌙', 'emoji': '🌙✨', 'bg': '#E8DEF8'},
    {'title': 'Abrazo Cálido 🫂', 'emoji': '🫂❤️', 'bg': '#FFD8E4'},
    {'title': 'Cita Sorpresa 🎟️', 'emoji': '🎬🍿', 'bg': '#C8E6C9'},
  ];

  @override
  void dispose() {
    _textController.dispose();
    _drawingController.dispose();
    super.dispose();
  }

  Future<String> _generatePresetArtPng(int index) async {
    final preset = _artPresets[index % _artPresets.length];
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 600, 360));

    final bg = AmodoroTheme.parseHexColor(preset['bg']!);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 600, 360),
      Paint()..color = bg,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: '${preset['emoji']}\n${preset['title']}',
        style: TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.w800,
          color: AmodoroTheme.getContrastingInk(bg),
          height: 1.3,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 540);

    tp.paint(
      canvas,
      Offset((600 - tp.width) / 2, (360 - tp.height) / 2),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(600, 360);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return 'data:image/png;base64,${base64Encode(bytes!.buffer.asUint8List())}';
  }

  Future<void> _submit() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un mensaje para tu tarjeta')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      String? mediaDataUrl;
      String finalMediaType = _mediaType;

      if (_mediaType == 'drawing') {
        mediaDataUrl = await _drawingController.toPngDataUrl();
        if (mediaDataUrl == null) {
          finalMediaType = 'none';
        }
      } else if (_mediaType == 'photo') {
        mediaDataUrl = await _generatePresetArtPng(_selectedPresetArt);
      }

      await widget.api.createHomeCard(
        textContent: text,
        bgColor: _bgColor,
        fontFamily: _fontFamily,
        fontSize: _fontSize,
        mediaType: finalMediaType,
        mediaDataUrl: mediaDataUrl,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = AmodoroTheme.parseHexColor(_bgColor);
    final cardInk = AmodoroTheme.getContrastingInk(cardColor);
    final cardMuted = AmodoroTheme.getContrastingMutedInk(cardColor);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Crear tarjeta para ${widget.partnerNickname}',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Selector de modo: Solo texto / Dibujo / Ilustración
            Row(
              children: [
                _buildModeButton('none', '📝 Solo texto'),
                const SizedBox(width: 8),
                _buildModeButton('drawing', '🎨 Dibujo'),
                const SizedBox(width: 8),
                _buildModeButton('photo', '📷 Postal'),
              ],
            ),
            const SizedBox(height: 14),

            if (_mediaType == 'drawing') ...[
              InteractiveDrawingPad(controller: _drawingController),
              const SizedBox(height: 14),
            ] else if (_mediaType == 'photo') ...[
              const Text(
                'Elige una postal ilustrada para acompañar tu mensaje:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_artPresets.length, (i) {
                  final p = _artPresets[i];
                  final selected = _selectedPresetArt == i;
                  return ChoiceChip(
                    label: Text(p['title']!),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedPresetArt = i),
                  );
                }),
              ),
              const SizedBox(height: 14),
            ],

            // Vista previa flotante redondeada (28dp) con auto-contraste
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: cardInk.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'DE: YO → ${widget.partnerNickname.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: cardInk,
                          ),
                        ),
                      ),
                      Text(
                        'VISTA PREVIA',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: cardMuted,
                        ),
                      ),
                    ],
                  ),
                  if (_mediaType != 'none') ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          _mediaType == 'drawing'
                              ? '🎨 Tu dibujo hecho a mano aparecerá aquí arriba'
                              : '${_artPresets[_selectedPresetArt]['emoji']} ${_artPresets[_selectedPresetArt]['title']}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1F1B18),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _textController,
                    builder: (context, val, _) {
                      return Text(
                        val.text.isEmpty ? 'Tu mensaje...' : val.text,
                        style: AmodoroTheme.getCardTextStyle(
                          fontFamily: _fontFamily,
                          fontSize: _fontSize,
                          color: cardInk,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Campo de texto + barra de emojis
            TextField(
              controller: _textController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Mensaje de la tarjeta',
                hintText: 'Escribe algo especial con emojis...',
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _emojis.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text(e, style: const TextStyle(fontSize: 16)),
                      onPressed: () {
                        _textController.text = '${_textController.text}$e';
                        _textController.selection = TextSelection.fromPosition(
                          TextPosition(offset: _textController.text.length),
                        );
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // Selector de Color Pastel M3
            const Text(
              'Color de tarjeta (contraste de texto automático):',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: AmodoroTheme.pastelPresets.map((preset) {
                final selected =
                    _bgColor.toUpperCase() == preset.hex.toUpperCase();
                return GestureDetector(
                  onTap: () => setState(() => _bgColor = preset.hex),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: preset.color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? AmodoroTheme.coralPillLight
                            : Colors.black26,
                        width: selected ? 3 : 1,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check_rounded,
                            size: 18, color: Color(0xFF1F1B18))
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Tipografía y Tamaño
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fuente:',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: [
                          _buildFontChip('sans', 'Sans'),
                          _buildFontChip('serif', 'Serif'),
                          _buildFontChip('hand', 'Carta'),
                          _buildFontChip('mono', 'Mono'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tamaño:',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      children: ['sm', 'md', 'lg', 'xl'].map((sz) {
                        return ChoiceChip(
                          label: Text(sz.toUpperCase()),
                          selected: _fontSize == sz,
                          onSelected: (_) => setState(() => _fontSize = sz),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 22),

            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AmodoroTheme.coralPillLight,
                foregroundColor: AmodoroTheme.coralPillTextLight,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: _sending ? null : _submit,
              icon: const Icon(Icons.send_rounded),
              label: Text(
                _sending
                    ? 'Enviando tarjeta...'
                    : 'Enviar a ${widget.partnerNickname}',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(String mode, String label) {
    final selected = _mediaType == mode;
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: selected
              ? AmodoroTheme.coralPillLight
              : Theme.of(context).colorScheme.surfaceContainer,
          foregroundColor: selected
              ? AmodoroTheme.coralPillTextLight
              : Theme.of(context).colorScheme.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: () => setState(() => _mediaType = mode),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _buildFontChip(String key, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _fontFamily == key,
      onSelected: (_) => setState(() => _fontFamily = key),
    );
  }
}
