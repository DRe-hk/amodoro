import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/amodoro_models.dart';
import '../services/api_client.dart';
import '../theme/amodoro_theme.dart';
import '../widgets/flat_avatar.dart';

class SettingsScreen extends StatefulWidget {
  final SyncPayload sync;
  final AmodoroApiClient api;
  final Future<void> Function() onRefresh;
  final VoidCallback onLogout;

  const SettingsScreen({
    super.key,
    required this.sync,
    required this.api,
    required this.onRefresh,
    required this.onLogout,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _avatarId;
  late final TextEditingController _myDisplayNameCtrl;
  late final TextEditingController _partnerNicknameCtrl;
  late final TextEditingController _newReplyCtrl;
  late String _themeMode;
  late List<String> _quickReplies;

  bool _saving = false;
  bool _addingReply = false;
  String? _generatedInvite;

  @override
  void initState() {
    super.initState();
    _avatarId = widget.sync.me.avatarId;
    _myDisplayNameCtrl =
        TextEditingController(text: widget.sync.me.displayName);
    _partnerNicknameCtrl =
        TextEditingController(text: widget.sync.me.partnerNicknameGiven);
    _newReplyCtrl = TextEditingController();
    _themeMode = widget.sync.me.themeMode == 'auto'
        ? 'system'
        : widget.sync.me.themeMode;
    if (!['light', 'dark', 'system'].contains(_themeMode)) {
      _themeMode = 'light';
    }
    _quickReplies = List<String>.from(widget.sync.me.quickReplies);
  }

  @override
  void dispose() {
    _myDisplayNameCtrl.dispose();
    _partnerNicknameCtrl.dispose();
    _newReplyCtrl.dispose();
    super.dispose();
  }

  void _onSelectAvatar(String id) {
    setState(() {
      _avatarId = id;
      // Easter egg: si elige el gatito gris bebé ('gray_kitten'),
      // el campo de nombre cambia automáticamente a "zafiro" (sin guardarse solo, editable ahí mismo).
      if (id == 'gray_kitten') {
        _myDisplayNameCtrl.text = 'zafiro';
        _myDisplayNameCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: _myDisplayNameCtrl.text.length),
        );
      }
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    try {
      await widget.api.updateSettings(
        displayName: _myDisplayNameCtrl.text.trim(),
        avatarId: _avatarId,
        partnerNickname: _partnerNicknameCtrl.text.trim(),
        themeMode: _themeMode,
        accentPalette: widget.sync.me.accentPalette,
        quickReplies: _quickReplies,
      );
      await widget.onRefresh();
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ajustes actualizados')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _addReplyPhrase() {
    final txt = _newReplyCtrl.text.trim();
    if (txt.isEmpty) return;
    setState(() {
      _quickReplies.add(txt);
      _newReplyCtrl.clear();
      _addingReply = false;
    });
  }

  void _removeReplyAt(int index) {
    setState(() {
      _quickReplies.removeAt(index);
    });
  }

  Future<void> _generateInvite() async {
    try {
      final code = await widget.api.createInviteCode();
      if (mounted) {
        setState(() => _generatedInvite = code);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface =
        isDark ? const Color(0xFF1F2421) : const Color(0xFFF4EFE8);
    final coralBg =
        isDark ? AmodoroTheme.coralPillDark : AmodoroTheme.coralPillLight;
    final coralInk = isDark
        ? AmodoroTheme.coralPillTextDark
        : AmodoroTheme.coralPillTextLight;
    final me = widget.sync.me;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 22, 30),
      children: [
        // 1. Parte superior: Avatar predefinido en estilo Flat elegido por el usuario
        Center(
          child: FlatAvatarBadge(
            avatarId: _avatarId,
            size: 88,
            showPerspectiveBorder: true,
          ),
        ),
        const SizedBox(height: 14),
        FlatAvatarSelector(
          selectedAvatarId: _avatarId,
          onSelect: _onSelectAvatar,
        ),
        const SizedBox(height: 16),

        // 2. Debajo: El nombre que el usuario se puso a sí mismo
        Center(
          child: SizedBox(
            width: 220,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: AmodoroTheme.floatingPerspectiveBox(
                color: surface,
                radius: 999,
                thickness: 2.0,
              ),
              child: TextField(
                controller: _myDisplayNameCtrl,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, letterSpacing: 0.6),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Tu nombre',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // 3. Debajo en una sola línea: el apodo que le puso la otra persona (sin explicaciones)
        Center(
          child: Text(
            me.nicknameByPartner,
            style: TextStyle(
              fontSize: 13.5,
              letterSpacing: 1.1,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // 4. Apodo que tú le pones a tu pareja
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: AmodoroTheme.floatingPerspectiveBox(
            color: surface,
            radius: 20,
            thickness: 2.5,
          ),
          child: TextField(
            controller: _partnerNicknameCtrl,
            decoration: InputDecoration(
              border: InputBorder.none,
              labelText: 'APODO DE TU PAREJA',
              labelStyle: const TextStyle(fontSize: 11, letterSpacing: 1.2),
              icon: AmodoroTheme.sysIcon(Symbols.favorite, size: 20),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 5. Selector de Tema en menú desplegable con iconos del sistema (sin emojis ni texto Material Design 3)
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: AmodoroTheme.floatingPerspectiveBox(
            color: surface,
            radius: 999,
            thickness: 2.5,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _themeMode,
              isExpanded: true,
              icon: AmodoroTheme.sysIcon(Symbols.expand_more, size: 20),
              items: [
                DropdownMenuItem(
                  value: 'light',
                  child: Row(
                    children: [
                      AmodoroTheme.sysIcon(Symbols.light_mode, size: 18),
                      const SizedBox(width: 10),
                      const Text(
                        'TEMA CLARO',
                        style: TextStyle(fontSize: 12.5, letterSpacing: 1.2),
                      ),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'dark',
                  child: Row(
                    children: [
                      AmodoroTheme.sysIcon(Symbols.dark_mode, size: 18),
                      const SizedBox(width: 10),
                      const Text(
                        'TEMA OSCURO',
                        style: TextStyle(fontSize: 12.5, letterSpacing: 1.2),
                      ),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'system',
                  child: Row(
                    children: [
                      AmodoroTheme.sysIcon(Symbols.contrast, size: 18),
                      const SizedBox(width: 10),
                      const Text(
                        'TEMA AUTOMÁTICO',
                        style: TextStyle(fontSize: 12.5, letterSpacing: 1.2),
                      ),
                    ],
                  ),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _themeMode = val);
              },
            ),
          ),
        ),
        const SizedBox(height: 22),

        // 6. Lista de textos predeterminados con botón de añadir (*) y botón de eliminar al lado de cada frase
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'RESPUESTAS PREDETERMINADAS',
              style: TextStyle(fontSize: 11.5, letterSpacing: 1.3),
            ),
            GestureDetector(
              onTap: () => setState(() => _addingReply = !_addingReply),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: AmodoroTheme.floatingPerspectiveBox(
                  color: surface,
                  radius: 999,
                  thickness: 2.0,
                ),
                child: const Text(
                  '* AÑADIR',
                  style: TextStyle(fontSize: 11, letterSpacing: 1.2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_addingReply) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: AmodoroTheme.floatingPerspectiveBox(
                      color: surface,
                      radius: 18,
                      thickness: 2.0,
                    ),
                    child: TextField(
                      controller: _newReplyCtrl,
                      autofocus: true,
                      onSubmitted: (_) => _addReplyPhrase(),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Nueva frase...',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _addReplyPhrase,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: AmodoroTheme.floatingPerspectiveBox(
                      color: coralBg,
                      radius: 999,
                      thickness: 2.0,
                    ),
                    child: Center(
                      child: AmodoroTheme.sysIcon(
                        Symbols.check,
                        size: 20,
                        color: coralInk,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        ...List.generate(_quickReplies.length, (i) {
          final phrase = _quickReplies[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: AmodoroTheme.floatingPerspectiveBox(
                color: surface,
                radius: 18,
                thickness: 2.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      phrase,
                      style: const TextStyle(fontSize: 13.5),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _removeReplyAt(i),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: AmodoroTheme.sysIcon(
                        Symbols.delete,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 16),

        // Botón Guardar
        GestureDetector(
          onTap: _saving ? null : _saveSettings,
          child: Container(
            height: 48,
            decoration: AmodoroTheme.floatingPerspectiveBox(
              color: coralBg,
              radius: 999,
              thickness: 2.5,
              perspectiveEdgeColor: isDark
                  ? AmodoroTheme.coralPillBorderDark
                  : AmodoroTheme.coralPillBorderLight,
            ),
            child: Center(
              child: Text(
                _saving ? 'GUARDANDO...' : 'GUARDAR CAMBIOS',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.5,
                  color: coralInk,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 7. Debajo: únicamente el botón de generar código de invitación
        GestureDetector(
          onTap: _generateInvite,
          child: Container(
            height: 48,
            decoration: AmodoroTheme.floatingPerspectiveBox(
              color: surface,
              radius: 999,
              thickness: 2.5,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AmodoroTheme.sysIcon(Symbols.key, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'GENERAR CÓDIGO DE INVITACIÓN',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_generatedInvite != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            decoration: AmodoroTheme.floatingPerspectiveBox(
              color: const Color(0xFFFFDAD6),
              radius: 20,
              thickness: 2.5,
            ),
            child: Center(
              child: SelectableText(
                _generatedInvite!,
                style: const TextStyle(
                  fontSize: 22,
                  letterSpacing: 2.4,
                  color: Color(0xFF1F1B18),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        Center(
          child: GestureDetector(
            onTap: widget.onLogout,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: AmodoroTheme.sysIcon(
                Symbols.logout,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
