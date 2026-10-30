import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../services/api_client.dart';
import '../theme/amodoro_theme.dart';
import '../widgets/flat_avatar.dart';
import '../widgets/glass_bubble_background.dart';

class LoginScreen extends StatefulWidget {
  final AmodoroApiClient api;
  final VoidCallback onLoggedIn;
  final int initialStep; // 0: Bienvenida/Login, 1: Registro (Avatar+Nombre), 2: Emparejar

  const LoginScreen({
    super.key,
    required this.api,
    required this.onLoggedIn,
    this.initialStep = 0,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late int _step; // 0: Login/Bienvenida, 1: Registro (Avatar y Nombre), 2: Código de Emparejamiento
  bool _loading = false;
  String? _error;

  bool _showLoginPassword = false;
  bool _showRegisterPassword = false;

  // Login controllers
  final TextEditingController _loginUserCtrl = TextEditingController();
  final TextEditingController _loginPassCtrl = TextEditingController();

  // Register controllers (Paso 1: Avatar + Nombre)
  String _selectedAvatarId = 'cat';
  final TextEditingController _registerNameCtrl = TextEditingController();
  final TextEditingController _registerPassCtrl = TextEditingController();

  // Pairing controllers (Paso 2: Código de emparejamiento)
  final TextEditingController _pairCodeCtrl = TextEditingController();
  String? _myInviteCode;

  @override
  void initState() {
    super.initState();
    _step = widget.initialStep;
  }

  @override
  void dispose() {
    _loginUserCtrl.dispose();
    _loginPassCtrl.dispose();
    _registerNameCtrl.dispose();
    _registerPassCtrl.dispose();
    _pairCodeCtrl.dispose();
    super.dispose();
  }

  void _onSelectRegisterAvatar(String avatarId) {
    setState(() {
      _selectedAvatarId = avatarId;
      // Easter egg: si el avatar elegido es el gatito gris bebé ('gray_kitten'),
      // el campo de nombre cambia automáticamente a "zafiro" (editable y sin guardarse solo).
      if (avatarId == 'gray_kitten') {
        _registerNameCtrl.text = 'zafiro';
        _registerNameCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: _registerNameCtrl.text.length),
        );
      }
    });
  }

  Future<void> _submitLogin() async {
    if (_loginUserCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Ingresa tu nombre o usuario');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.api.loginPassword(
        _loginUserCtrl.text.trim(),
        _loginPassCtrl.text.isEmpty ? 'amodoro2025' : _loginPassCtrl.text,
      );
      final isPaired = res['isPaired'] == true;
      if (isPaired) {
        widget.onLoggedIn();
      } else if (mounted) {
        setState(() {
          _loading = false;
          _step = 2;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _submitRegister() async {
    final name = _registerNameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Escribe tu nombre debajo de tu avatar');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.api.registerAccount(
        displayName: name,
        avatarId: _selectedAvatarId,
        password: _registerPassCtrl.text,
      );
      if (mounted) {
        setState(() {
          _loading = false;
          _step = 2; // Pasa a la pantalla del código de emparejamiento
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _submitPairCode() async {
    final code = _pairCodeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Introduce el código de invitación de tu pareja');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.api.pairWithCode(code);
      widget.onLoggedIn();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _generateMyPairCode() async {
    try {
      final code = await widget.api.createInviteCode();
      if (mounted) {
        setState(() => _myInviteCode = code);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coralBg =
        isDark ? AmodoroTheme.coralPillDark : AmodoroTheme.coralPillLight;
    final coralInk = AmodoroTheme.coralText(isDark);
    final secondaryBtnBg = isDark
        ? AmodoroTheme.darkContainer
        : AmodoroTheme.lightContainer;

    return Scaffold(
      body: GlassBubbleBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_step == 0) ...[
                    // Pantalla de Login: solo el logo grande en Playwrite NL Coral arriba, sin descripción debajo y sin Card contenedora detrás de los elementos.
                    Center(
                      child: Text(
                        'amodoro',
                        style: AmodoroTheme.logoStyle(
                          fontSize: 48,
                          isDark: isDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    if (_error != null) _buildErrorBanner(_error!),
                    _buildPerspectiveField(
                      controller: _loginUserCtrl,
                      hint: 'Nombre o usuario',
                      icon: Symbols.person,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 14),
                    _buildPerspectiveField(
                      controller: _loginPassCtrl,
                      hint: 'Contraseña',
                      icon: Symbols.lock,
                      obscure: !_showLoginPassword,
                      isDark: isDark,
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _showLoginPassword = !_showLoginPassword;
                          });
                        },
                        icon: AmodoroTheme.sysIcon(
                          _showLoginPassword
                              ? Symbols.visibility_off
                              : Symbols.visibility,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _buildPerspectiveButton(
                      label: _loading ? 'ENTRANDO...' : 'INICIAR SESIÓN',
                      bgColor: coralBg,
                      inkColor: coralInk,
                      onTap: _loading ? null : _submitLogin,
                    ),
                    const SizedBox(height: 12),
                    _buildPerspectiveButton(
                      label: 'CREAR CUENTA',
                      bgColor: secondaryBtnBg,
                      inkColor: Theme.of(context).colorScheme.onSurface,
                      onTap: () {
                        setState(() {
                          _error = null;
                          _step = 1;
                        });
                      },
                    ),
                  ] else if (_step == 1) ...[
                    // Paso 1 de Registro: Solo el logo más pequeño en la parte superior, sin mensaje ni Card contenedora detrás.
                    Center(
                      child: Text(
                        'amodoro',
                        style: AmodoroTheme.logoStyle(
                          fontSize: 28,
                          isDark: isDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (_error != null) _buildErrorBanner(_error!),
                    Center(
                      child: FlatAvatarBadge(
                        avatarId: _selectedAvatarId,
                        size: 88,
                        showPerspectiveBorder: true,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FlatAvatarSelector(
                      selectedAvatarId: _selectedAvatarId,
                      onSelect: _onSelectRegisterAvatar,
                    ),
                    const SizedBox(height: 22),
                    _buildPerspectiveField(
                      controller: _registerNameCtrl,
                      hint: 'Tu nombre',
                      icon: Symbols.badge,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildPerspectiveField(
                      controller: _registerPassCtrl,
                      hint: 'Contraseña (opcional)',
                      icon: Symbols.key,
                      obscure: !_showRegisterPassword,
                      isDark: isDark,
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _showRegisterPassword = !_showRegisterPassword;
                          });
                        },
                        icon: AmodoroTheme.sysIcon(
                          _showRegisterPassword
                              ? Symbols.visibility_off
                              : Symbols.visibility,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _buildPerspectiveButton(
                      label: _loading ? 'GUARDANDO...' : 'CONTINUAR',
                      bgColor: coralBg,
                      inkColor: coralInk,
                      onTap: _loading ? null : _submitRegister,
                    ),
                    const SizedBox(height: 12),
                    _buildPerspectiveButton(
                      label: 'VOLVER',
                      bgColor: secondaryBtnBg,
                      inkColor: Theme.of(context).colorScheme.onSurface,
                      onTap: () {
                        setState(() {
                          _error = null;
                          _step = 0;
                        });
                      },
                    ),
                  ] else ...[
                    // Paso 2: Pantalla de Código de Emparejamiento (sin Card detrás)
                    Center(
                      child: Text(
                        'amodoro',
                        style: AmodoroTheme.logoStyle(
                          fontSize: 36,
                          isDark: isDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (_error != null) _buildErrorBanner(_error!),
                    _buildPerspectiveField(
                      controller: _pairCodeCtrl,
                      hint: 'CÓDIGO DE PAREJA (EJ. K7M2-9QXP)',
                      icon: Symbols.link,
                      isDark: isDark,
                      uppercase: true,
                    ),
                    const SizedBox(height: 16),
                    _buildPerspectiveButton(
                      label: _loading
                          ? 'VINCULANDO...'
                          : 'VINCULAR CON CÓDIGO',
                      bgColor: coralBg,
                      inkColor: coralInk,
                      onTap: _loading ? null : _submitPairCode,
                    ),
                    const SizedBox(height: 14),
                    _buildPerspectiveButton(
                      label: 'GENERAR MI CÓDIGO DE INVITACIÓN',
                      bgColor: secondaryBtnBg,
                      inkColor: Theme.of(context).colorScheme.onSurface,
                      onTap: _generateMyPairCode,
                    ),
                    if (_myInviteCode != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: AmodoroTheme.floatingPerspectiveBox(
                          color: const Color(0xFFFFDAD6),
                          radius: 18,
                          thickness: 2.5,
                        ),
                        child: Center(
                          child: SelectableText(
                            _myInviteCode!,
                            style: const TextStyle(
                              fontSize: 22,
                              letterSpacing: 2.5,
                              color: Color(0xFF1F1B18),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _buildPerspectiveButton(
                      label: 'CONTINUAR A HOME',
                      bgColor: secondaryBtnBg,
                      inkColor: Theme.of(context).colorScheme.onSurface,
                      onTap: widget.onLoggedIn,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPerspectiveField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    bool obscure = false,
    bool uppercase = false,
    Widget? suffixIcon,
  }) {
    final bg = isDark
        ? AmodoroTheme.darkContainer
        : AmodoroTheme.lightContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: AmodoroTheme.floatingPerspectiveBox(
        color: bg,
        radius: 18,
        thickness: 2.5,
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        textCapitalization: uppercase
            ? TextCapitalization.characters
            : TextCapitalization.none,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          icon: AmodoroTheme.sysIcon(icon, size: 20),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  Widget _buildPerspectiveButton({
    required String label,
    required Color bgColor,
    required Color inkColor,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: AmodoroTheme.floatingPerspectiveBox(
          color: bgColor,
          radius: 999,
          thickness: 2.5,
        ),
        child: Center(
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              letterSpacing: 1.5,
              color: inkColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: AmodoroTheme.floatingPerspectiveBox(
          color: const Color(0xFFFFDAD6),
          radius: 16,
          thickness: 2.0,
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12.5,
            color: Color(0xFF3B0D09),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
