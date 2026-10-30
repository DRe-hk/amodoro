import 'package:flutter/material.dart';
import '../models/amodoro_models.dart';
import '../services/api_client.dart';
import '../theme/amodoro_theme.dart';

class LoginScreen extends StatefulWidget {
  final AmodoroApiClient api;
  final VoidCallback onLoggedIn;

  const LoginScreen({
    super.key,
    required this.api,
    required this.onLoggedIn,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  int _modeIndex = 0; // 0: 1-Toque, 1: Usuario/Clave, 2: Código
  bool _loading = false;
  String? _error;
  bool _editingServer = false;

  late final TextEditingController _serverController;
  final TextEditingController _usernameController =
      TextEditingController(text: 'drehk');
  final TextEditingController _passwordController =
      TextEditingController(text: 'amodoro2025');
  final TextEditingController _codeController = TextEditingController();

  List<AuthProfileOption> _profiles = const [
    AuthProfileOption(id: 1, username: 'drehk', partnerNickname: 'Rey'),
    AuthProfileOption(id: 2, username: 'pareja', partnerNickname: 'Cielo'),
  ];

  @override
  void initState() {
    super.initState();
    _serverController = TextEditingController(text: widget.api.baseUrl);
    _fetchProfiles();
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfiles() async {
    try {
      final list = await widget.api.fetchAuthProfiles();
      if (mounted && list.isNotEmpty) {
        setState(() {
          _profiles = list;
        });
      }
    } catch (_) {
      // Usa perfiles predeterminados si aún no responde
    }
  }

  Future<void> _loginQuick(int userId) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.api.loginQuick(userId);
      widget.onLoggedIn();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _loginPassword() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.api.loginPassword(
        _usernameController.text,
        _passwordController.text,
      );
      widget.onLoggedIn();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _loginCode() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.api.loginInviteCode(_codeController.text);
      widget.onLoggedIn();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveServerUrl() async {
    await widget.api.setBaseUrl(_serverController.text);
    setState(() {
      _editingServer = false;
    });
    await _fetchProfiles();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coralBg =
        isDark ? AmodoroTheme.coralPillDark : AmodoroTheme.coralPillLight;
    final coralInk = isDark
        ? AmodoroTheme.coralPillTextDark
        : AmodoroTheme.coralPillTextLight;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabecera Amodoro
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDAD6),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AmodoroTheme.coralPillLight,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'AMODORO · ESPACIO COMPARTIDO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          color: AmodoroTheme.coralPillTextLight,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Nuestro rincón privado',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1F1B18),
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tarjetas diarias con foto o dibujo, tableros compartidos y decisión en pareja sin fricción. Tus propios mensajes siempre dicen YO.',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF4E453E),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Barra de conexión al servidor VPS Azure
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.cloud_done_rounded,
                            size: 18, color: coralBg),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'VPS Azure: ${widget.api.baseUrl}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _editingServer = !_editingServer;
                            });
                          },
                          icon: const Icon(Icons.tune_rounded, size: 15),
                          label: Text(_editingServer ? 'Cerrar' : 'Cambiar'),
                        ),
                      ],
                    ),
                    if (_editingServer) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _serverController,
                              decoration: const InputDecoration(
                                labelText: 'URL del Servidor VPS',
                                hintText: 'http://68.211.73.23',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _saveServerUrl,
                            child: const Text('Guardar'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Selector de método de ingreso
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    _buildModeTab(0, '✨ 1-Toque', coralBg, coralInk),
                    _buildModeTab(1, '🔑 Clave', coralBg, coralInk),
                    _buildModeTab(2, '💌 Código', coralBg, coralInk),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],

              // Contenido según modo
              if (_modeIndex == 0) ...[
                const Text(
                  'Elige tu perfil para entrar con 1 toque:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                ..._profiles.map((p) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: _loading ? null : () => _loginQuick(p.id),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: coralBg.withValues(alpha: 0.45),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: coralBg,
                              child: Text(
                                p.username.isNotEmpty
                                    ? p.username[0].toUpperCase()
                                    : 'A',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: coralInk,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Entrar como @${p.username}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Apodo que te dio tu pareja: "${p.partnerNickname}" · Tus tarjetas dirán YO',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_rounded, color: coralBg),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ] else if (_modeIndex == 1) ...[
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Usuario (ej. drehk o pareja)',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña (por defecto: amodoro2025)',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: coralBg,
                    foregroundColor: coralInk,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: _loading ? null : _loginPassword,
                  icon: const Icon(Icons.login_rounded),
                  label: Text(
                    _loading ? 'Entrando...' : 'Iniciar Sesión',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Código de invitación (ej. K7M2-9QXP)',
                    prefixIcon: Icon(Icons.vpn_key_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: coralBg,
                    foregroundColor: coralInk,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: _loading ? null : _loginCode,
                  icon: const Icon(Icons.favorite_rounded),
                  label: Text(
                    _loading ? 'Verificando...' : 'Canjear Código y Entrar',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeTab(int index, String label, Color coralBg, Color coralInk) {
    final active = _modeIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _modeIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? coralBg : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: active
                    ? coralInk
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
