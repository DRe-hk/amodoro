import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/amodoro_models.dart';
import '../services/api_client.dart';
import '../theme/amodoro_theme.dart';
import '../widgets/flat_avatar.dart';
import '../widgets/pin_keypad.dart';
import '../widgets/pressable_button.dart';

class SettingsScreen extends StatefulWidget {
  final SyncPayload sync;
  final AmodoroApiClient api;
  final Future<void> Function() onRefresh;
  final ValueChanged<String>? onThemeChanged;
  final VoidCallback onLogout;

  const SettingsScreen({
    super.key,
    required this.sync,
    required this.api,
    required this.onRefresh,
    this.onThemeChanged,
    required this.onLogout,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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

  static const List<String> _defaultEmojis = [
    '❤️', '🥰', '🥺', '✨', '🔥', '🫶',
  ];

  static const List<String> _suggestedEmojis = [
    '❤️', '🥰', '🥺', '✨', '🔥', '🫶', '😍', '😂', '🤍', '🌸', '🌻', '🎉',
  ];

  late String _avatarId;
  late final TextEditingController _myDisplayNameCtrl;
  late final TextEditingController _partnerNicknameCtrl;
  late final TextEditingController _pairCodeCtrl;
  late String _themeMode;
  late List<String> _reactionEmojis;

  bool _saving = false;
  bool _pairingBusy = false;
  bool _exportingBusy = false;

  String? _generatedInvite;
  String? _generatedPartnerResetCode;
  String? _updatedRecoveryCode;

  @override
  void initState() {
    super.initState();
    _avatarId = widget.sync.me.avatarId;
    _myDisplayNameCtrl =
        TextEditingController(text: widget.sync.me.displayName);
    _myDisplayNameCtrl.addListener(_onDisplayNameChanged);
    _partnerNicknameCtrl =
        TextEditingController(text: widget.sync.me.partnerNicknameGiven);
    _pairCodeCtrl = TextEditingController();
    _themeMode = widget.sync.me.themeMode == 'auto'
        ? 'system'
        : widget.sync.me.themeMode;
    if (!['light', 'dark', 'system'].contains(_themeMode)) {
      _themeMode = 'system';
    }
    _reactionEmojis = List<String>.from(widget.sync.me.reactionEmojis);
    if (_reactionEmojis.isEmpty) {
      _reactionEmojis = List<String>.from(_defaultEmojis);
    }
  }

  @override
  void dispose() {
    _myDisplayNameCtrl.removeListener(_onDisplayNameChanged);
    _myDisplayNameCtrl.dispose();
    _partnerNicknameCtrl.dispose();
    _pairCodeCtrl.dispose();
    super.dispose();
  }

  void _onDisplayNameChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _isZafiroEasterEgg =>
      _myDisplayNameCtrl.text.trim().toLowerCase() == 'zafiro' &&
      _avatarId == 'gray_kitten';

  void _onSelectAvatar(String id) {
    setState(() {
      _avatarId = id;
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
        quickReplies: widget.sync.me.quickReplies,
        reactionEmojis: _reactionEmojis,
      );
      widget.onThemeChanged?.call(_themeMode);
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

  void _toggleReactionEmoji(String emo) {
    setState(() {
      if (_reactionEmojis.contains(emo)) {
        if (_reactionEmojis.length > 1) {
          _reactionEmojis.remove(emo);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Debes mantener al menos 1 emoji')),
          );
        }
      } else {
        _reactionEmojis.add(emo);
      }
    });
  }

  void _addReactionEmoji(String emo) {
    final clean = emo.trim();
    if (clean.isEmpty) return;
    if (!_reactionEmojis.contains(clean)) {
      setState(() {
        _reactionEmojis.add(clean);
      });
    }
  }

  void _removeEmojiAt(int index) {
    if (_reactionEmojis.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes mantener al menos 1 emoji')),
      );
      return;
    }
    setState(() {
      _reactionEmojis.removeAt(index);
    });
  }

  void _restoreDefaultEmojis() {
    setState(() {
      _reactionEmojis = List<String>.from(_defaultEmojis);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Emojis predeterminados restaurados')),
    );
  }

  Future<void> _showAddEmojiModal(BuildContext context) async {
    final customCtrl = TextEditingController();
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
        final coralBg =
            isDark ? AmodoroTheme.coralPillDark : AmodoroTheme.coralPillLight;
        final coralLip = isDark
            ? AmodoroTheme.coralPillBorderDark
            : AmodoroTheme.coralPillBorderLight;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'AÑADIR EMOJI AL DOCK',
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
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            decoration: AmodoroTheme.cardOutlineBox(
                              color: fieldBg,
                              radius: 999,
                              borderColor: borderColor,
                              borderWidth: 2.5,
                              subtleShadow: false,
                            ),
                            child: TextField(
                              controller: customCtrl,
                              autofocus: true,
                              style: const TextStyle(fontSize: 20),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Escribe cualquier emoji...',
                                isDense: true,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 12),
                              ),
                              onSubmitted: (txt) {
                                if (txt.trim().isNotEmpty) {
                                  _addReactionEmoji(txt.trim());
                                  Navigator.of(sheetCtx).pop();
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        AmodoroPressableButton(
                          onTap: () {
                            if (customCtrl.text.trim().isNotEmpty) {
                              _addReactionEmoji(customCtrl.text.trim());
                              Navigator.of(sheetCtx).pop();
                            }
                          },
                          color: coralBg,
                          lipColor: coralLip,
                          lipHeight: 3.0,
                          radius: 999,
                          width: 48,
                          height: 48,
                          child: AmodoroTheme.sysIcon(
                            Symbols.check,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'O SELECCIONA UNO:',
                      style: AmodoroTheme.googleSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: isDark
                            ? AmodoroTheme.darkMuted
                            : AmodoroTheme.lightMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: _suggestedEmojis.map((emo) {
                        final isSelected = _reactionEmojis.contains(emo);
                        return AmodoroPressableButton(
                          onTap: () {
                            _toggleReactionEmoji(emo);
                            setModalState(() {});
                          },
                          color: isSelected
                              ? coralBg.withValues(alpha: 0.15)
                              : fieldBg,
                          borderColor: isSelected ? coralBg : borderColor,
                          borderWidth: isSelected ? 2.0 : 1.5,
                          lipColor: isSelected ? coralLip : borderColor,
                          lipHeight: 2.0,
                          radius: 999,
                          width: 48,
                          height: 48,
                          child: Center(
                            child: Text(
                              emo,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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

  Future<void> _pairWithPartnerCode() async {
    final code = _pairCodeCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() => _pairingBusy = true);
    try {
      await widget.api.pairWithCode(code);
      _pairCodeCtrl.clear();
      await widget.onRefresh();
      if (mounted) {
        setState(() => _pairingBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Vinculado con tu pareja!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _pairingBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _showChangePinSheet() async {
    String? currentPin;
    String? sheetError;
    bool sheetBusy = false;
    final keypadKey = GlobalKey<PinKeypadWidgetState>();

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

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> onPinEntered(String pin) async {
              if (currentPin == null) {
                setModalState(() {
                  currentPin = pin;
                  sheetError = null;
                });
                keypadKey.currentState?.clear();
                return;
              }

              setModalState(() {
                sheetBusy = true;
                sheetError = null;
              });

              try {
                final res = await widget.api.changePin(
                  currentPin: currentPin,
                  newPin: pin,
                );
                final newRecovery = res['recoveryCode']?.toString();
                if (sheetCtx.mounted) {
                  Navigator.of(sheetCtx).pop();
                }
                if (mounted) {
                  setState(() {
                    if (newRecovery != null && newRecovery.isNotEmpty) {
                      _updatedRecoveryCode = newRecovery;
                    }
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('PIN de 4 dígitos actualizado correctamente'),
                    ),
                  );
                }
              } catch (e) {
                setModalState(() {
                  sheetBusy = false;
                  currentPin = null;
                  sheetError = e.toString().replaceFirst('Exception: ', '');
                });
                keypadKey.currentState?.clear();
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
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
                          'CAMBIAR PIN DE 4 DÍGITOS',
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
                    const SizedBox(height: 16),
                    PinKeypadWidget(
                      key: keypadKey,
                      subtitle: currentPin == null
                          ? 'PASO 1 · INGRESA TU PIN ACTUAL'
                          : 'PASO 2 · INGRESA TU NUEVO PIN DE 4 DÍGITOS',
                      errorText: sheetError,
                      busy: sheetBusy,
                      onPinCompleted: onPinEntered,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _generatePartnerResetCode() async {
    try {
      final code = await widget.api.generatePartnerPinResetCode();
      if (mounted) {
        setState(() {
          _generatedPartnerResetCode = code;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _exportMyDataJson() async {
    setState(() => _exportingBusy = true);
    try {
      final data = await widget.api.exportMyData();
      final formattedJson = const JsonEncoder.withIndent('  ').convert(data);
      await Clipboard.setData(ClipboardData(text: formattedJson));
      if (!mounted) return;
      setState(() => _exportingBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tus datos se copiaron al portapapeles en formato JSON'),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _exportingBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _lockAppWithPin() {
    widget.api.isPinUnlocked = false;
    widget.onLogout();
  }

  Future<void> _unlinkDevice() async {
    await widget.api.logout(clearRememberedAccount: true);
    widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AmodoroTheme.darkContainer : Colors.white;
    final fieldBg =
        isDark ? const Color(0xFF1B1818) : AmodoroTheme.lightContainer;
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
    final me = widget.sync.me;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      children: [
        // ---------------------------------------------------------------------
        // SECCIÓN 1: Perfil y Avatar (Non-button container uses cardOutlineBox)
        // ---------------------------------------------------------------------
        Container(
          padding: const EdgeInsets.all(20),
          decoration: AmodoroTheme.cardOutlineBox(
            color: cardBg,
            radius: 34,
            borderColor: borderColor,
            borderWidth: 2.5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: FlatAvatarBadge(
                  avatarId: _avatarId,
                  size: 88,
                  borderWidth: 2.5,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: _avatarCatalog.map((entry) {
                  final id = entry['id']!;
                  final label = entry['label']!;
                  final isSelected = id == _avatarId;
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
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isSelected ? inkColor : mutedColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

              if (_isZafiroEasterEgg) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
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
              ],
              const SizedBox(height: 16),

              // Input Tu nombre (cardOutlineBox borderWidth: 2.5, NO 3D lip)
              Center(
                child: SizedBox(
                  width: 240,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: AmodoroTheme.cardOutlineBox(
                      color: fieldBg,
                      radius: 999,
                      borderColor: borderColor,
                      borderWidth: 2.5,
                      subtleShadow: false,
                    ),
                    child: TextField(
                      controller: _myDisplayNameCtrl,
                      textAlign: TextAlign.center,
                      style: AmodoroTheme.googleSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: inkColor,
                      ),
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

              Center(
                child: Text(
                  me.nicknameByPartner,
                  style: AmodoroTheme.googleSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: mutedColor,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Apodo que tú le pones a tu pareja (cardOutlineBox borderWidth: 2.5)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                decoration: AmodoroTheme.cardOutlineBox(
                  color: fieldBg,
                  radius: 999,
                  borderColor: borderColor,
                  borderWidth: 2.5,
                  subtleShadow: false,
                ),
                child: TextField(
                  controller: _partnerNicknameCtrl,
                  style: AmodoroTheme.googleSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: inkColor,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    labelText: 'APODO DE TU PAREJA',
                    labelStyle: AmodoroTheme.googleSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: mutedColor,
                    ),
                    icon: AmodoroTheme.sysIcon(
                      Symbols.favorite,
                      size: 20,
                      color: coralBg,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Selector de Tema (Theme mode pills using AmodoroPressableButton)
              Text(
                'MODO DE TEMA',
                style: AmodoroTheme.googleSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: mutedColor,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildThemePill(
                    mode: 'system',
                    label: 'AUTO',
                    icon: Symbols.contrast,
                    fieldBg: fieldBg,
                    borderColor: borderColor,
                    coralBg: coralBg,
                    coralLip: coralLip,
                    inkColor: inkColor,
                  ),
                  const SizedBox(width: 8),
                  _buildThemePill(
                    mode: 'light',
                    label: 'CLARO',
                    icon: Symbols.light_mode,
                    fieldBg: fieldBg,
                    borderColor: borderColor,
                    coralBg: coralBg,
                    coralLip: coralLip,
                    inkColor: inkColor,
                  ),
                  const SizedBox(width: 8),
                  _buildThemePill(
                    mode: 'dark',
                    label: 'OSCURO',
                    icon: Symbols.dark_mode,
                    fieldBg: fieldBg,
                    borderColor: borderColor,
                    coralBg: coralBg,
                    coralLip: coralLip,
                    inkColor: inkColor,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // ---------------------------------------------------------------------
        // ---------------------------------------------------------------------
        // SECCIÓN 2: Dock de Emojis de Reacción (Estilo Instagram)
        // ---------------------------------------------------------------------
        Container(
          padding: const EdgeInsets.all(20),
          decoration: AmodoroTheme.cardOutlineBox(
            color: cardBg,
            radius: 34,
            borderColor: borderColor,
            borderWidth: 2.5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'DOCK DE EMOJIS DE REACCIÓN',
                      style: AmodoroTheme.googleSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: inkColor,
                      ),
                    ),
                  ),
                  AmodoroPressableButton(
                    onTap: () => _showAddEmojiModal(context),
                    color: fieldBg,
                    borderColor: borderColor,
                    borderWidth: 1.5,
                    lipColor: borderColor,
                    lipHeight: 2.5,
                    radius: 999,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Text(
                      '+ AÑADIR',
                      style: AmodoroTheme.googleSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: inkColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Personaliza los emojis que aparecen al reaccionar (toca para quitar o pulsa + para añadir):',
                style: AmodoroTheme.googleSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: mutedColor,
                ),
              ),
              const SizedBox(height: 14),

              // Instagram-style rounded dock container
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: AmodoroTheme.cardOutlineBox(
                    color: fieldBg,
                    radius: 999,
                    borderColor: borderColor,
                    borderWidth: 2.0,
                    subtleShadow: false,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ..._reactionEmojis.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final emo = entry.value;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                AmodoroPressableButton(
                                  onTap: () => _removeEmojiAt(idx),
                                  color: cardBg,
                                  borderColor: borderColor,
                                  borderWidth: 1.5,
                                  lipColor: borderColor,
                                  lipHeight: 2.0,
                                  radius: 999,
                                  width: 48,
                                  height: 48,
                                  child: Center(
                                    child: Text(
                                      emo,
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                  ),
                                ),
                                if (_reactionEmojis.length > 1)
                                  Positioned(
                                    top: -2,
                                    right: -2,
                                    child: GestureDetector(
                                      onTap: () => _removeEmojiAt(idx),
                                      child: Container(
                                        width: 18,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          color: coralBg,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.close,
                                            size: 11,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: AmodoroPressableButton(
                            onTap: () => _showAddEmojiModal(context),
                            color: coralBg,
                            lipColor: coralLip,
                            lipHeight: 2.5,
                            radius: 999,
                            width: 48,
                            height: 48,
                            child: const Center(
                              child: Icon(
                                Icons.add,
                                size: 24,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Popular suggested emojis quick grid
              Text(
                'EMOJIS SUGERIDOS (TOCA PARA AÑADIR O QUITAR)',
                style: AmodoroTheme.googleSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: mutedColor,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: _suggestedEmojis.map((emo) {
                  final isSelected = _reactionEmojis.contains(emo);
                  return AmodoroPressableButton(
                    onTap: () => _toggleReactionEmoji(emo),
                    color: isSelected
                        ? coralBg.withValues(alpha: 0.15)
                        : fieldBg,
                    borderColor: isSelected ? coralBg : borderColor,
                    borderWidth: isSelected ? 2.0 : 1.5,
                    lipColor: isSelected ? coralLip : borderColor,
                    lipHeight: 2.0,
                    radius: 999,
                    width: 48,
                    height: 48,
                    child: Center(
                      child: Text(
                        emo,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              Center(
                child: AmodoroPressableButton(
                  onTap: _restoreDefaultEmojis,
                  color: fieldBg,
                  borderColor: borderColor,
                  borderWidth: 1.5,
                  lipColor: borderColor,
                  lipHeight: 2.5,
                  radius: 999,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AmodoroTheme.sysIcon(
                        Symbols.restart_alt,
                        size: 16,
                        color: mutedColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'RESTAURAR PREDETERMINADOS',
                        style: AmodoroTheme.googleSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: inkColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Botón GUARDAR CAMBIOS (radius: 999)
              AmodoroPressableButton(
                onTap: _saving ? null : _saveSettings,
                color: coralBg,
                lipColor: coralLip,
                lipHeight: 3.5,
                radius: 999,
                height: 50,
                child: Text(
                  _saving ? 'GUARDANDO...' : 'GUARDAR CAMBIOS',
                  style: AmodoroTheme.googleSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // ---------------------------------------------------------------------
        // SECCIÓN 3: Emparejamiento y Código de Pareja
        // ---------------------------------------------------------------------
        Container(
          padding: const EdgeInsets.all(20),
          decoration: AmodoroTheme.cardOutlineBox(
            color: cardBg,
            radius: 34,
            borderColor: borderColor,
            borderWidth: 2.5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'VINCULACIÓN EN PAREJA',
                style: AmodoroTheme.googleSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: inkColor,
                ),
              ),
              const SizedBox(height: 12),
              if (!me.isPaired) ...[
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: AmodoroTheme.cardOutlineBox(
                          color: fieldBg,
                          radius: 999,
                          borderColor: borderColor,
                          borderWidth: 2.5,
                          subtleShadow: false,
                        ),
                        child: TextField(
                          controller: _pairCodeCtrl,
                          textCapitalization: TextCapitalization.characters,
                          style: AmodoroTheme.googleSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                            color: inkColor,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Código de pareja',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    AmodoroPressableButton(
                      onTap: _pairingBusy ? null : _pairWithPartnerCode,
                      color: coralBg,
                      lipColor: coralLip,
                      lipHeight: 3.0,
                      radius: 999,
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Text(
                        _pairingBusy ? '...' : 'VINCULAR',
                        style: AmodoroTheme.googleSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              AmodoroPressableButton(
                onTap: _generateInvite,
                color: fieldBg,
                borderColor: borderColor,
                borderWidth: 1.5,
                lipColor: borderColor,
                lipHeight: 3.0,
                radius: 999,
                height: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AmodoroTheme.sysIcon(
                      Symbols.key,
                      size: 18,
                      color: inkColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'GENERAR CÓDIGO DE INVITACIÓN',
                      style: AmodoroTheme.googleSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: inkColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (_generatedInvite != null) ...[
                const SizedBox(height: 12),
                _buildCopyableCodeBox(
                  label: 'CÓDIGO DE INVITACIÓN',
                  code: _generatedInvite!,
                  bgColor: const Color(0xFFFFDAD6),
                  borderColor: const Color(0xFFD6574D),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),

        // ---------------------------------------------------------------------
        // SECCIÓN 4: Seguridad y PIN de 4 dígitos (v1.5)
        // ---------------------------------------------------------------------
        Container(
          padding: const EdgeInsets.all(20),
          decoration: AmodoroTheme.cardOutlineBox(
            color: cardBg,
            radius: 34,
            borderColor: borderColor,
            borderWidth: 2.5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'SEGURIDAD Y PIN DE 4 DÍGITOS',
                style: AmodoroTheme.googleSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: inkColor,
                ),
              ),
              const SizedBox(height: 12),
              AmodoroPressableButton(
                onTap: _showChangePinSheet,
                color: coralBg,
                lipColor: coralLip,
                lipHeight: 3.5,
                radius: 999,
                height: 50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AmodoroTheme.sysIcon(
                      Symbols.lock,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'CAMBIAR PIN DE 4 DÍGITOS',
                      style: AmodoroTheme.googleSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              if (_updatedRecoveryCode != null) ...[
                const SizedBox(height: 12),
                _buildCopyableCodeBox(
                  label: 'TU NUEVO CÓDIGO DE RECUPERACIÓN (8 CARACTERES)',
                  code: _updatedRecoveryCode!,
                  bgColor: const Color(0xFFEADCF8),
                  borderColor: const Color(0xFFB392DC),
                ),
              ],
              const SizedBox(height: 12),
              AmodoroPressableButton(
                onTap: _generatePartnerResetCode,
                color: fieldBg,
                borderColor: borderColor,
                borderWidth: 1.5,
                lipColor: borderColor,
                lipHeight: 3.0,
                radius: 999,
                constraints: const BoxConstraints(minHeight: 50),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AmodoroTheme.sysIcon(
                      Symbols.favorite,
                      size: 18,
                      color: coralBg,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'GENERAR CÓDIGO PARA RECUPERAR PIN DE MI PAREJA',
                        textAlign: TextAlign.center,
                        style: AmodoroTheme.googleSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.9,
                          color: inkColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_generatedPartnerResetCode != null) ...[
                const SizedBox(height: 12),
                _buildCopyableCodeBox(
                  label: 'CÓDIGO PARA MI PAREJA (USAR EN "OLVIDÉ PIN")',
                  code: _generatedPartnerResetCode!,
                  bgColor: const Color(0xFFC8E7D1),
                  borderColor: const Color(0xFF7BB38D),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),

        // ---------------------------------------------------------------------
        // SECCIÓN 5: Mis Datos y Privacidad (v1.5)
        // ---------------------------------------------------------------------
        Container(
          padding: const EdgeInsets.all(20),
          decoration: AmodoroTheme.cardOutlineBox(
            color: cardBg,
            radius: 34,
            borderColor: borderColor,
            borderWidth: 2.5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'MIS DATOS Y PRIVACIDAD',
                style: AmodoroTheme.googleSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: inkColor,
                ),
              ),
              const SizedBox(height: 12),
              AmodoroPressableButton(
                onTap: _exportingBusy ? null : _exportMyDataJson,
                color: fieldBg,
                borderColor: borderColor,
                borderWidth: 1.5,
                lipColor: borderColor,
                lipHeight: 3.0,
                radius: 999,
                height: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AmodoroTheme.sysIcon(
                      Symbols.download,
                      size: 18,
                      color: inkColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _exportingBusy
                          ? 'EXPORTANDO...'
                          : 'EXPORTAR MIS DATOS (JSON)',
                      style: AmodoroTheme.googleSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: inkColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AmodoroPressableButton(
                onTap: _lockAppWithPin,
                color: fieldBg,
                borderColor: borderColor,
                borderWidth: 1.5,
                lipColor: borderColor,
                lipHeight: 3.0,
                radius: 999,
                height: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AmodoroTheme.sysIcon(
                      Symbols.pin,
                      size: 18,
                      color: inkColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'BLOQUEAR APP (PEDIR PIN)',
                      style: AmodoroTheme.googleSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: inkColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AmodoroPressableButton(
                onTap: _unlinkDevice,
                color: const Color(0xFFFFDAD6),
                borderColor: const Color(0xFFD6574D),
                borderWidth: 1.5,
                lipColor: const Color(0xFFD6574D),
                lipHeight: 3.0,
                radius: 999,
                height: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AmodoroTheme.sysIcon(
                      Symbols.logout,
                      size: 18,
                      color: const Color(0xFF473A3A),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'DESVINCULAR ESTE DISPOSITIVO',
                      style: AmodoroTheme.googleSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: const Color(0xFF473A3A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemePill({
    required String mode,
    required String label,
    required IconData icon,
    required Color fieldBg,
    required Color borderColor,
    required Color coralBg,
    required Color coralLip,
    required Color inkColor,
  }) {
    final isSelected = _themeMode == mode;
    return Expanded(
      child: AmodoroPressableButton(
        onTap: () {
          setState(() {
            _themeMode = mode;
          });
          widget.onThemeChanged?.call(mode);
        },
        color: isSelected ? coralBg : fieldBg,
        borderColor: isSelected ? null : borderColor,
        borderWidth: isSelected ? 0 : 1.5,
        lipColor: isSelected ? coralLip : borderColor,
        lipHeight: 3.0,
        radius: 999,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AmodoroTheme.sysIcon(
              icon,
              size: 16,
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
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                  color: isSelected ? Colors.white : inkColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCopyableCodeBox({
    required String label,
    required String code,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
            label,
            textAlign: TextAlign.center,
            style: AmodoroTheme.googleSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: const Color(0xFF473A3A),
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            code,
            style: AmodoroTheme.googleSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.4,
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
                    letterSpacing: 1.0,
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
}
