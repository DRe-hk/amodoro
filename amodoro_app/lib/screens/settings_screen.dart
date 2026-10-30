import 'package:flutter/material.dart';
import '../models/amodoro_models.dart';
import '../services/api_client.dart';
import '../theme/amodoro_theme.dart';

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
  late final TextEditingController _partnerNicknameCtrl;
  late final TextEditingController _quickRepliesCtrl;
  late String _themeMode;
  late String _accentPalette;
  bool _saving = false;
  String? _generatedInvite;

  @override
  void initState() {
    super.initState();
    _partnerNicknameCtrl =
        TextEditingController(text: widget.sync.me.partnerNicknameGiven);
    _quickRepliesCtrl = TextEditingController(
      text: widget.sync.me.quickReplies.join('\n'),
    );
    _themeMode = widget.sync.me.themeMode;
    _accentPalette = widget.sync.me.accentPalette;
  }

  @override
  void dispose() {
    _partnerNicknameCtrl.dispose();
    _quickRepliesCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    try {
      final replies = _quickRepliesCtrl.text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      await widget.api.updateSettings(
        partnerNickname: _partnerNicknameCtrl.text.trim(),
        themeMode: _themeMode,
        accentPalette: _accentPalette,
        quickReplies: replies,
      );
      await widget.onRefresh();
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ajustes guardados y sincronizados ✨')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
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
          SnackBar(content: Text('Error al generar código: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.sync.me;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        // Tarjeta 1: Regla de apodos cruzados (YO vs Apodo de tu pareja)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFDAD6),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'IDENTIDAD CRUZADA · REGLA YO / APODO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                  color: Color(0xFF3B0D09),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Apodo que tu pareja te puso: "${me.nicknameByPartner}"',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1F1B18),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Cada persona elige el apodo del otro. En tu pantalla, todas tus propias tarjetas e ítems siempre muestran "YO", mientras que tu pareja los ve con el apodo que te asignó.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF4E453E),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Tarjeta 2: Editar el apodo que le das a tu pareja
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Apodo que tú le das a tu pareja',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _partnerNicknameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Apodo de tu pareja (ej. Mi Cielo, Amor)',
                  prefixIcon: Icon(Icons.favorite_border_rounded),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tema visual Material Design 3',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'light', label: Text('☀️ Claro')),
                  ButtonSegment(value: 'dark', label: Text('🌙 Oscuro')),
                  ButtonSegment(value: 'auto', label: Text('⚡ Auto')),
                ],
                selected: {_themeMode},
                onSelectionChanged: (s) {
                  setState(() => _themeMode = s.first);
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Textos predeterminados de respuesta rápida (1 por línea)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _quickRepliesCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Te amo ❤️\n¡Qué lindo! 🥰\n¡Sí, hagámoslo! ✨',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AmodoroTheme.coralPillLight,
                  foregroundColor: AmodoroTheme.coralPillTextLight,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: _saving ? null : _saveSettings,
                icon: const Icon(Icons.save_rounded),
                label: Text(
                  _saving ? 'Guardando...' : 'Guardar Ajustes',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Tarjeta 3: Código de Invitación y Sesión VPS
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Vínculo de Pareja y Servidor VPS',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Conectado a: ${widget.api.baseUrl} · Usuario: @${me.username}',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _generateInvite,
                icon: const Icon(Icons.vpn_key_rounded, size: 18),
                label: const Text('Generar código de invitación (8 caracteres)'),
              ),
              if (_generatedInvite != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AmodoroTheme.coralPillLight.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: SelectableText(
                      _generatedInvite!,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout_rounded),
                label: const Text(
                  'Cerrar sesión',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
