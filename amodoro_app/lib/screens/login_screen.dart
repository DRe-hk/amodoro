import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/amodoro_models.dart';
import '../services/api_client.dart';
import '../theme/amodoro_theme.dart';
import '../widgets/flat_avatar.dart';
import '../widgets/glass_bubble_background.dart';
import '../widgets/pin_keypad.dart';
import '../widgets/pressable_button.dart';

class LoginScreen extends StatefulWidget {
  final AmodoroApiClient api;
  final VoidCallback? onAuthenticated;
  final VoidCallback? onLoggedIn;

  const LoginScreen({
    super.key,
    required this.api,
    this.onAuthenticated,
    this.onLoggedIn,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const List<Map<String, String>> _avatarCatalog = [
    {'id': 'cat', 'label': 'Gato'},
    {'id': 'dog', 'label': 'Perro'},
    {'id': 'rabbit', 'label': 'Conejo'},
    {'id': 'bear', 'label': 'Oso'},
    {'id': 'fox', 'label': 'Zorro'},
    {'id': 'panda', 'label': 'Panda'},
    {'id': 'chick', 'label': 'Pollito'},
    {'id': 'gray_kitten', 'label': 'Gatito gris'},
  ];

  bool _forceAccountSetup = false;
  bool _busy = false;
  String? _pinError;
  String? _formError;

  // Server status for Flow B
  int _serverUserCount = 0;
  bool _maxUsersReached = false;
  String _flowBMode = 'register'; // 'register' | 'existing'

  // Flow B - Register state
  int _registerStep = 1; // 1: Perfil, 2: Crear PIN, 3: Códigos importantes
  String _selectedAvatarId = 'cat';
  bool _hasPartnerCodeToggle = false;
  String? _firstPin;
  String? _generatedRecoveryCode;
  String? _generatedInviteCode;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _inviteCodeController = TextEditingController();
  final TextEditingController _existingNameController = TextEditingController();

  final GlobalKey<PinKeypadWidgetState> _unlockPinKey =
      GlobalKey<PinKeypadWidgetState>();
  final GlobalKey<PinKeypadWidgetState> _registerPinKey =
      GlobalKey<PinKeypadWidgetState>();
  final GlobalKey<PinKeypadWidgetState> _existingPinKey =
      GlobalKey<PinKeypadWidgetState>();

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
    _checkServerAuthStatus();
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _inviteCodeController.dispose();
    _existingNameController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _notifyAuthenticated() {
    widget.onAuthenticated?.call();
    widget.onLoggedIn?.call();
  }

  Future<void> _checkServerAuthStatus() async {
    try {
      final status = await widget.api.fetchAuthStatus();
      if (!mounted) return;
      setState(() {
        _serverUserCount = status.serverUserCount;
        _maxUsersReached = status.maxUsersReached;
        if (status.serverUserCount == 1) {
          _hasPartnerCodeToggle = true;
        }
        if (status.maxUsersReached) {
          _flowBMode = 'existing';
        }
      });
    } catch (_) {
      // Offline or first load: allow manual interaction
    }
  }

  bool get _isZafiroEasterEgg =>
      _nameController.text.trim().toLowerCase() == 'zafiro' &&
      _selectedAvatarId == 'gray_kitten';

  void _onSelectAvatar(String avatarId) {
    setState(() {
      _selectedAvatarId = avatarId;
      if (avatarId == 'gray_kitten' && _nameController.text.trim().isEmpty) {
        _nameController.text = 'zafiro';
        _nameController.selection = TextSelection.fromPosition(
          TextPosition(offset: _nameController.text.length),
        );
      }
    });
  }

  Future<void> _handleUnlockWithPin(String pin) async {
    final user = widget.api.rememberedUser;
    if (user == null) return;

    setState(() {
      _busy = true;
      _pinError = null;
    });

    try {
      await widget.api.verifyPin(
        pin,
        userId: user.id,
        username: user.username,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      _notifyAuthenticated();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _pinError = e.toString().replaceFirst('Exception: ', '');
      });
      _unlockPinKey.currentState?.clear();
    }
  }

  void _continueToCreatePin() {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      setState(() {
        _formError = 'Ingresa tu nombre (mínimo 2 caracteres).';
      });
      return;
    }
    setState(() {
      _formError = null;
      _pinError = null;
      _firstPin = null;
      _registerStep = 2;
    });
  }

  Future<void> _handleRegisterPinStep(String pin) async {
    if (_firstPin == null) {
      setState(() {
        _firstPin = pin;
        _pinError = null;
      });
      _registerPinKey.currentState?.clear();
      return;
    }

    if (_firstPin != pin) {
      setState(() {
        _firstPin = null;
        _pinError = 'Los PIN no coinciden. Inténtalo de nuevo.';
      });
      _registerPinKey.currentState?.clear();
      return;
    }

    setState(() {
      _busy = true;
      _pinError = null;
      _formError = null;
    });

    try {
      final code = _inviteCodeController.text.trim();
      final res = await widget.api.registerWithPin(
        displayName: _nameController.text.trim(),
        avatarId: _selectedAvatarId,
        pin: pin,
        code: code.isNotEmpty ? code : null,
      );

      final recoveryCode = res['recoveryCode']?.toString();
      String? inviteCode;
      final userMap = res['user'] as Map<String, dynamic>?;
      final isPaired = userMap?['isPaired'] == true || res['isPaired'] == true;

      if (!isPaired && code.isEmpty) {
        try {
          inviteCode = await widget.api.createInviteCode();
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _busy = false;
        _generatedRecoveryCode = recoveryCode;
        _generatedInviteCode = inviteCode;
        _registerStep = 3;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _firstPin = null;
        _pinError = e.toString().replaceFirst('Exception: ', '');
      });
      _registerPinKey.currentState?.clear();
    }
  }

  Future<void> _handleExistingAccountPin(String pin) async {
    final username = _existingNameController.text.trim();
    if (username.isEmpty) {
      setState(() {
        _pinError = 'Escribe tu nombre arriba antes de ingresar tu PIN.';
      });
      _existingPinKey.currentState?.clear();
      return;
    }

    setState(() {
      _busy = true;
      _pinError = null;
    });

    try {
      await widget.api.verifyPin(
        pin,
        username: username,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      _notifyAuthenticated();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _pinError = e.toString().replaceFirst('Exception: ', '');
      });
      _existingPinKey.currentState?.clear();
    }
  }

  Future<void> _showRecoverPinSheet(UserProfile? user) async {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController(
      text: user?.username ?? _existingNameController.text.trim(),
    );
    String? sheetError;
    bool sheetBusy = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
        final cardBg = isDark ? AmodoroTheme.darkContainer : Colors.white;
        final fieldBg =
            isDark ? const Color(0xFF1B1818) : AmodoroTheme.lightContainer;
        final borderColor =
            isDark ? const Color(0xFF383232) : const Color(0xFFE9E4DC);
        final inkColor = isDark ? AmodoroTheme.darkInk : AmodoroTheme.lightInk;
        final mutedColor =
            isDark ? AmodoroTheme.darkMuted : AmodoroTheme.lightMuted;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> submitRecovery(String newPin) async {
              final recCode = codeCtrl.text.trim();
              final targetName = nameCtrl.text.trim();
              if (recCode.length < 6) {
                setModalState(() {
                  sheetError =
                      'Ingresa tu código de recuperación (8 caracteres) o de pareja (6 caracteres).';
                });
                return;
              }
              if (user == null && targetName.isEmpty) {
                setModalState(() {
                  sheetError = 'Ingresa tu nombre de usuario.';
                });
                return;
              }

              setModalState(() {
                sheetBusy = true;
                sheetError = null;
              });

              try {
                await widget.api.recoverPin(
                  recoveryCode: recCode,
                  newPin: newPin,
                  userId: user?.id,
                  username: user?.username ?? targetName,
                );
                if (sheetCtx.mounted) {
                  Navigator.of(sheetCtx).pop();
                }
                if (mounted) {
                  _notifyAuthenticated();
                }
              } catch (e) {
                setModalState(() {
                  sheetBusy = false;
                  sheetError = e.toString().replaceFirst('Exception: ', '');
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
                  decoration: AmodoroTheme.cardOutlineBox(
                    color: cardBg,
                    radius: 34,
                    borderColor: borderColor,
                    borderWidth: 2.5,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'RECUPERAR PIN',
                            style: AmodoroTheme.googleSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: inkColor,
                            ),
                          ),
                          AmodoroPressableButton(
                            onTap: () => Navigator.of(sheetCtx).pop(),
                            color: fieldBg,
                            borderColor: borderColor,
                            borderWidth: 1.5,
                            lipHeight: 2.5,
                            radius: 999,
                            width: 48,
                            height: 48,
                            child: AmodoroTheme.sysIcon(
                              Symbols.close,
                              size: 20,
                              color: inkColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ingresa tu código personal de 8 caracteres o el código temporal de 6 caracteres generado por tu pareja en Ajustes, y define tu nuevo PIN.',
                        textAlign: TextAlign.center,
                        style: AmodoroTheme.googleSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: mutedColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (user == null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 2,
                          ),
                          decoration: AmodoroTheme.cardOutlineBox(
                            color: fieldBg,
                            radius: 999,
                            borderColor: borderColor,
                            borderWidth: 2.5,
                            subtleShadow: false,
                          ),
                          child: TextField(
                            controller: nameCtrl,
                            style: AmodoroTheme.googleSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: inkColor,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Tu nombre',
                              icon: AmodoroTheme.sysIcon(
                                Symbols.person,
                                size: 20,
                                color: mutedColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 2,
                        ),
                        decoration: AmodoroTheme.cardOutlineBox(
                          color: fieldBg,
                          radius: 999,
                          borderColor: borderColor,
                          borderWidth: 2.5,
                          subtleShadow: false,
                        ),
                        child: TextField(
                          controller: codeCtrl,
                          textCapitalization: TextCapitalization.characters,
                          style: AmodoroTheme.googleSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.8,
                            color: inkColor,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'CÓDIGO (8 O 6 CARACTERES)',
                            icon: AmodoroTheme.sysIcon(
                              Symbols.key,
                              size: 20,
                              color: mutedColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      PinKeypadWidget(
                        subtitle: 'NUEVO PIN DE 4 DÍGITOS',
                        errorText: sheetError,
                        busy: sheetBusy,
                        onPinCompleted: submitRecovery,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rememberedUser = widget.api.rememberedUser;
    final showWelcomePin = rememberedUser != null && !_forceAccountSetup;

    return Scaffold(
      body: GlassBubbleBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
              child: showWelcomePin
                  ? _buildWelcomePinFlow(context, rememberedUser, isDark)
                  : _buildAccountSetupFlow(context, isDark),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FLOW A: Welcome PIN Unlock Screen
  // ---------------------------------------------------------------------------
  Widget _buildWelcomePinFlow(
    BuildContext context,
    UserProfile user,
    bool isDark,
  ) {
    final inkColor = isDark ? AmodoroTheme.darkInk : AmodoroTheme.lightInk;
    final mutedColor =
        isDark ? AmodoroTheme.darkMuted : AmodoroTheme.lightMuted;
    final borderColor =
        isDark ? const Color(0xFF383232) : const Color(0xFFE9E4DC);
    final surfaceColor =
        isDark ? AmodoroTheme.darkContainer : AmodoroTheme.lightContainer;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'amodoro',
          style: AmodoroTheme.logoStyle(fontSize: 40, isDark: isDark),
        ),
        const SizedBox(height: 16),
        FlatAvatarBadge(
          avatarId: user.avatarId,
          size: 84,
          borderWidth: 2.5,
        ),
        const SizedBox(height: 12),
        Text(
          'Bienvenido, ${user.displayName}',
          textAlign: TextAlign.center,
          style: AmodoroTheme.googleSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: inkColor,
          ),
        ),
        const SizedBox(height: 20),
        PinKeypadWidget(
          key: _unlockPinKey,
          subtitle: 'INGRESA TU CLAVE PIN',
          errorText: _pinError,
          busy: _busy,
          onPinCompleted: _handleUnlockWithPin,
          onForgotPin: () => _showRecoverPinSheet(user),
        ),
        const SizedBox(height: 22),
        AmodoroPressableButton(
          onTap: _busy
              ? null
              : () {
                  setState(() {
                    _pinError = null;
                    _formError = null;
                    _forceAccountSetup = true;
                  });
                },
          color: surfaceColor.withValues(alpha: 0.85),
          borderColor: borderColor,
          borderWidth: 1.5,
          lipHeight: 2.5,
          radius: 999,
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Text(
            'Usar otra cuenta en este dispositivo',
            textAlign: TextAlign.center,
            style: AmodoroTheme.googleSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: mutedColor,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // FLOW B: First-Time Registration / Account Recovery
  // ---------------------------------------------------------------------------
  Widget _buildAccountSetupFlow(BuildContext context, bool isDark) {
    final cardBg = isDark ? AmodoroTheme.darkContainer : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF383232) : const Color(0xFFE9E4DC);
    final coralBg =
        isDark ? AmodoroTheme.coralPillDark : AmodoroTheme.coralPillLight;
    final coralLip = isDark
        ? AmodoroTheme.coralPillBorderDark
        : AmodoroTheme.coralPillBorderLight;
    final inkColor = isDark ? AmodoroTheme.darkInk : AmodoroTheme.lightInk;
    final mutedColor =
        isDark ? AmodoroTheme.darkMuted : AmodoroTheme.lightMuted;
    final fieldBg =
        isDark ? const Color(0xFF1B1818) : AmodoroTheme.lightContainer;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'amodoro',
            style: AmodoroTheme.logoStyle(fontSize: 38, isDark: isDark),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            decoration: AmodoroTheme.cardOutlineBox(
              color: cardBg,
              radius: 36,
              borderColor: borderColor,
              borderWidth: 3.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Mode Selector Tabs (hidden on Step 3 after registration succeeds)
                if (_registerStep != 3) ...[
                  Row(
                    children: [
                      if (!_maxUsersReached) ...[
                        Expanded(
                          child: AmodoroPressableButton(
                            onTap: () {
                              setState(() {
                                _flowBMode = 'register';
                                _pinError = null;
                                _formError = null;
                              });
                            },
                            color: _flowBMode == 'register' ? coralBg : fieldBg,
                            lipColor: _flowBMode == 'register'
                                ? coralLip
                                : borderColor,
                            borderColor: _flowBMode == 'register'
                                ? null
                                : borderColor,
                            borderWidth: _flowBMode == 'register' ? 0 : 1.5,
                            lipHeight: 3.0,
                            radius: 999,
                            height: 48,
                            child: Text(
                              'REGISTRARME',
                              style: AmodoroTheme.googleSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: _flowBMode == 'register'
                                    ? Colors.white
                                    : mutedColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: AmodoroPressableButton(
                          onTap: () {
                            setState(() {
                              _flowBMode = 'existing';
                              _pinError = null;
                              _formError = null;
                            });
                          },
                          color: _flowBMode == 'existing' ? coralBg : fieldBg,
                          lipColor:
                              _flowBMode == 'existing' ? coralLip : borderColor,
                          borderColor:
                              _flowBMode == 'existing' ? null : borderColor,
                          borderWidth: _flowBMode == 'existing' ? 0 : 1.5,
                          lipHeight: 3.0,
                          radius: 999,
                          height: 48,
                          child: Text(
                            'YA TENGO CUENTA',
                            style: AmodoroTheme.googleSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: _flowBMode == 'existing'
                                  ? Colors.white
                                  : mutedColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                if (_formError != null && _formError!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: AmodoroTheme.cardOutlineBox(
                      color: const Color(0xFFFFDAD6),
                      radius: 16,
                      borderColor: const Color(0xFFD6574D),
                      borderWidth: 2.0,
                      subtleShadow: false,
                    ),
                    child: Text(
                      _formError!,
                      textAlign: TextAlign.center,
                      style: AmodoroTheme.googleSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF473A3A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                if (_flowBMode == 'register' && !_maxUsersReached)
                  _buildRegisterBody(
                    isDark: isDark,
                    inkColor: inkColor,
                    mutedColor: mutedColor,
                    fieldBg: fieldBg,
                    borderColor: borderColor,
                    coralBg: coralBg,
                    coralLip: coralLip,
                  )
                else
                  _buildExistingAccountBody(
                    isDark: isDark,
                    inkColor: inkColor,
                    mutedColor: mutedColor,
                    fieldBg: fieldBg,
                    borderColor: borderColor,
                  ),
              ],
            ),
          ),
          if (widget.api.rememberedUser != null && _forceAccountSetup) ...[
            const SizedBox(height: 14),
            AmodoroPressableButton(
              onTap: () {
                setState(() {
                  _forceAccountSetup = false;
                  _pinError = null;
                  _formError = null;
                });
              },
              color: cardBg,
              borderColor: borderColor,
              borderWidth: 1.5,
              lipHeight: 2.5,
              radius: 999,
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text(
                'Volver a cuenta guardada (${widget.api.rememberedUser!.displayName})',
                style: AmodoroTheme.googleSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: inkColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRegisterBody({
    required bool isDark,
    required Color inkColor,
    required Color mutedColor,
    required Color fieldBg,
    required Color borderColor,
    required Color coralBg,
    required Color coralLip,
  }) {
    if (_registerStep == 1) {
      final showInviteInput = _serverUserCount == 1 || _hasPartnerCodeToggle;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: FlatAvatarBadge(
              avatarId: _selectedAvatarId,
              size: 76,
              borderWidth: 2.5,
            ),
          ),
          const SizedBox(height: 14),

          // Grid/Wrap of all 8 FlatAvatar options
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: _avatarCatalog.map((entry) {
              final id = entry['id']!;
              final label = entry['label']!;
              final isSelected = id == _selectedAvatarId;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _onSelectAvatar(id),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? coralBg : borderColor,
                          width: 2.5,
                        ),
                      ),
                      child: FlatAvatarBadge(
                        avatarId: id,
                        size: 46,
                        showPerspectiveBorder: false,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: AmodoroTheme.googleSans(
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? inkColor : mutedColor,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Easter Egg "zafiro" banner for BOTH Persona 1 and Persona 2
          if (_isZafiroEasterEgg) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: AmodoroTheme.cardOutlineBox(
                color: const Color(0xFFEADCF8),
                radius: 18,
                borderColor: const Color(0xFFB392DC),
                borderWidth: 2.5,
                subtleShadow: false,
              ),
              child: Text(
                '🐾 ¡Miau! Zafiro desbloqueó su gatito gris especial ✨',
                textAlign: TextAlign.center,
                style: AmodoroTheme.googleSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF473A3A),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Tu nombre input (border-only 2.5px)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
            decoration: AmodoroTheme.cardOutlineBox(
              color: fieldBg,
              radius: 999,
              borderColor: borderColor,
              borderWidth: 2.5,
              subtleShadow: false,
            ),
            child: TextField(
              controller: _nameController,
              style: AmodoroTheme.googleSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: inkColor,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Tu nombre',
                icon: AmodoroTheme.sysIcon(
                  Symbols.badge,
                  size: 20,
                  color: mutedColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          if (_serverUserCount != 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AmodoroPressableButton(
                onTap: () {
                  setState(() {
                    _hasPartnerCodeToggle = !_hasPartnerCodeToggle;
                  });
                },
                color: fieldBg,
                borderColor: borderColor,
                borderWidth: 1.5,
                lipHeight: 2.5,
                radius: 999,
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AmodoroTheme.sysIcon(
                      _hasPartnerCodeToggle
                          ? Symbols.check_circle
                          : Symbols.favorite,
                      size: 18,
                      color: _hasPartnerCodeToggle ? coralBg : mutedColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tengo un código de pareja',
                      style: AmodoroTheme.googleSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: inkColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (showInviteInput) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
              decoration: AmodoroTheme.cardOutlineBox(
                color: fieldBg,
                radius: 999,
                borderColor: borderColor,
                borderWidth: 2.5,
                subtleShadow: false,
              ),
              child: TextField(
                controller: _inviteCodeController,
                textCapitalization: TextCapitalization.characters,
                style: AmodoroTheme.googleSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: inkColor,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Código de emparejamiento (6 caracteres)',
                  icon: AmodoroTheme.sysIcon(
                    Symbols.link,
                    size: 20,
                    color: mutedColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          const SizedBox(height: 4),
          AmodoroPressableButton(
            onTap: _busy ? null : _continueToCreatePin,
            color: AmodoroTheme.coralPillLight,
            lipColor: AmodoroTheme.coralPillBorderLight,
            lipHeight: 3.5,
            radius: 999,
            height: 50,
            child: Text(
              'CONTINUAR A CREAR PIN',
              style: AmodoroTheme.googleSans(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    if (_registerStep == 2) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PinKeypadWidget(
            key: _registerPinKey,
            subtitle: _firstPin == null
                ? 'CREA TU PIN DE 4 DÍGITOS'
                : 'CONFIRMA TU PIN DE 4 DÍGITOS',
            errorText: _pinError,
            busy: _busy,
            onPinCompleted: _handleRegisterPinStep,
          ),
          const SizedBox(height: 18),
          AmodoroPressableButton(
            onTap: _busy
                ? null
                : () {
                    setState(() {
                      _firstPin = null;
                      _pinError = null;
                      _registerStep = 1;
                    });
                  },
            color: fieldBg,
            borderColor: borderColor,
            borderWidth: 1.5,
            lipHeight: 2.5,
            radius: 999,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'VOLVER A MI PERFIL',
              style: AmodoroTheme.googleSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: inkColor,
              ),
            ),
          ),
        ],
      );
    }

    // Step 3: Códigos importantes antes de entrar
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '¡CUENTA CREADA!',
          textAlign: TextAlign.center,
          style: AmodoroTheme.googleSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: inkColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Guarda estos códigos importantes antes de entrar:',
          textAlign: TextAlign.center,
          style: AmodoroTheme.googleSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: mutedColor,
          ),
        ),
        const SizedBox(height: 16),

        if (_generatedRecoveryCode != null &&
            _generatedRecoveryCode!.isNotEmpty) ...[
          _buildCodeShowcaseBox(
            title: 'CÓDIGO DE RECUPERACIÓN DE PIN',
            subtitle: 'Úsalo si olvidas tu clave PIN de 4 dígitos',
            code: _generatedRecoveryCode!,
            bgColor: const Color(0xFFEADCF8),
            borderColor: const Color(0xFFB392DC),
          ),
          const SizedBox(height: 14),
        ],

        if (_generatedInviteCode != null &&
            _generatedInviteCode!.isNotEmpty) ...[
          _buildCodeShowcaseBox(
            title: 'CÓDIGO DE INVITACIÓN PARA TU PAREJA',
            subtitle: 'Compártelo para vincular sus cuentas',
            code: _generatedInviteCode!,
            bgColor: const Color(0xFFFFDAD6),
            borderColor: const Color(0xFFD6574D),
          ),
          const SizedBox(height: 16),
        ],

        AmodoroPressableButton(
          onTap: _notifyAuthenticated,
          color: AmodoroTheme.coralPillLight,
          lipColor: AmodoroTheme.coralPillBorderLight,
          lipHeight: 3.5,
          radius: 999,
          height: 50,
          child: Text(
            'ENTRAR A AMODORO',
            style: AmodoroTheme.googleSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeShowcaseBox({
    required String title,
    required String subtitle,
    required String code,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AmodoroTheme.cardOutlineBox(
        color: bgColor,
        radius: 28,
        borderColor: borderColor,
        borderWidth: 2.5,
        subtleShadow: false,
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: AmodoroTheme.googleSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: const Color(0xFF473A3A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AmodoroTheme.googleSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B5B5B),
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            code,
            style: AmodoroTheme.googleSans(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.8,
              color: const Color(0xFF473A3A),
            ),
          ),
          const SizedBox(height: 10),
          AmodoroPressableButton(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Código $code copiado al portapapeles')),
              );
            },
            color: Colors.white,
            borderColor: borderColor,
            borderWidth: 1.5,
            lipColor: borderColor,
            lipHeight: 2.8,
            radius: 999,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AmodoroTheme.sysIcon(
                  Symbols.content_copy,
                  size: 18,
                  color: const Color(0xFF473A3A),
                ),
                const SizedBox(width: 8),
                Text(
                  'COPIAR',
                  style: AmodoroTheme.googleSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: const Color(0xFF473A3A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingAccountBody({
    required bool isDark,
    required Color inkColor,
    required Color mutedColor,
    required Color fieldBg,
    required Color borderColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
          decoration: AmodoroTheme.cardOutlineBox(
            color: fieldBg,
            radius: 999,
            borderColor: borderColor,
            borderWidth: 2.5,
            subtleShadow: false,
          ),
          child: TextField(
            controller: _existingNameController,
            style: AmodoroTheme.googleSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: inkColor,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Tu nombre',
              icon: AmodoroTheme.sysIcon(
                Symbols.person,
                size: 20,
                color: mutedColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        PinKeypadWidget(
          key: _existingPinKey,
          subtitle: 'INGRESA TU PIN DE 4 DÍGITOS',
          errorText: _pinError,
          busy: _busy,
          onPinCompleted: _handleExistingAccountPin,
          onForgotPin: () => _showRecoverPinSheet(null),
        ),
        const SizedBox(height: 14),
        AmodoroPressableButton(
          onTap: () => _showRecoverPinSheet(null),
          color: fieldBg,
          borderColor: borderColor,
          borderWidth: 1.5,
          lipHeight: 2.5,
          radius: 999,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '¿Olvidaste tu PIN?',
            style: AmodoroTheme.googleSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: mutedColor,
            ),
          ),
        ),
      ],
    );
  }
}
