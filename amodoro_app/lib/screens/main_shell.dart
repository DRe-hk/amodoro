import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/amodoro_models.dart';
import '../services/api_client.dart';
import '../theme/amodoro_theme.dart';
import '../widgets/pressable_button.dart';
import 'boards_screen.dart';
import 'create_card_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  final AmodoroApiClient api;
  final SyncPayload? sync;
  final Future<void> Function()? onRefresh;
  final ValueChanged<String>? onThemeChanged;
  final VoidCallback onLogout;

  const MainShell({
    super.key,
    required this.api,
    this.sync,
    this.onRefresh,
    this.onThemeChanged,
    required this.onLogout,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  static const List<String> _tabs = ['HOME', 'BOARDS', 'SETTINGS'];
  static const MethodChannel _shareChannel = MethodChannel('com.amodoro/share');

  late final PageController _pageController;
  int _activeIndex = 0;
  int? _pressedNavIndex;
  SyncPayload? _sync;
  bool _loading = false;
  String? _error;

  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;
  Timer? _autoSyncTimer;
  StreamSubscription<RemoteMessage>? _fcmForegroundSub;
  StreamSubscription<RemoteMessage>? _fcmOpenedSub;
  String? _pendingSharedText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sync = widget.sync;
    _pageController = PageController(initialPage: 0);

    _loadSync(silent: _sync != null);

    _autoSyncTimer = Timer.periodic(const Duration(seconds: 35), (_) {
      if (_appLifecycleState == AppLifecycleState.resumed && !_loading) {
        _loadSync(silent: true);
      }
    });

    _setupPushNotifications();
    _setupShareIntentListener();
  }

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sync != null && widget.sync != oldWidget.sync) {
      _sync = widget.sync;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    if (state == AppLifecycleState.resumed && !_loading) {
      _loadSync(silent: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSyncTimer?.cancel();
    _fcmForegroundSub?.cancel();
    _fcmOpenedSub?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _setupPushNotifications() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null && fcmToken.trim().isNotEmpty) {
        await widget.api.registerFcmToken(fcmToken.trim());
      }
      _fcmForegroundSub = FirebaseMessaging.onMessage.listen((_) {
        _loadSync(silent: true);
      });
      _fcmOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((_) {
        _loadSync(silent: true);
      });
    } catch (_) {
      // Safe fallback when Firebase is unavailable (e.g., tests or without GMS)
    }
  }

  Future<void> _setupShareIntentListener() async {
    try {
      _shareChannel.setMethodCallHandler((call) async {
        if (call.method == 'onSharedText') {
          final text = call.arguments?.toString();
          if (text != null && text.trim().isNotEmpty) {
            _handleIncomingSharedText(text.trim());
          }
        }
      });

      final initialShared =
          await _shareChannel.invokeMethod<String>('getInitialSharedText');
      if (initialShared != null && initialShared.trim().isNotEmpty) {
        _handleIncomingSharedText(initialShared.trim());
      }
    } catch (_) {
      // Ignore on platforms where MethodChannel is not registered
    }
  }

  String? _extractFirstUrl(String text) {
    final match = RegExp(r'https?://[^\s<>"]+').firstMatch(text);
    return match?.group(0);
  }

  void _handleIncomingSharedText(String sharedRaw) {
    if (!mounted) return;
    if (_sync == null) {
      _pendingSharedText = sharedRaw;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showSharedContentSheet(sharedRaw);
      }
    });
  }

  Future<void> _showSharedContentSheet(String sharedRaw) async {
    final extractedUrl = _extractFirstUrl(sharedRaw);
    final noteCtrl = TextEditingController(
      text: extractedUrl != null
          ? sharedRaw.replaceFirst(extractedUrl, '').trim()
          : sharedRaw,
    );
    bool busy = false;

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
            Future<void> sendAsHomeCard() async {
              setModalState(() => busy = true);
              try {
                LinkPreviewModel? preview;
                if (extractedUrl != null && extractedUrl.isNotEmpty) {
                  preview = await widget.api.fetchLinkPreview(extractedUrl);
                }
                final note = noteCtrl.text.trim();
                await widget.api.createHomeCard(
                  textContent: note.isNotEmpty
                      ? note
                      : (preview?.title ?? sharedRaw),
                  bgColor: '#FFDAD6',
                  fontFamily: 'sans',
                  fontSize: 'md',
                  fontSizePx: 18,
                  mediaType: extractedUrl != null ? 'link' : 'none',
                  linkUrl: preview?.url ?? extractedUrl,
                  linkTitle: preview?.title,
                  linkThumbnail: preview?.thumbnail,
                  linkPlatform: preview?.platform,
                );
                if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                await _loadSync(silent: true);
                if (mounted) {
                  _jumpToTab(0);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enlace enviado como tarjeta de HOME'),
                    ),
                  );
                }
              } catch (e) {
                setModalState(() => busy = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            }

            Future<void> saveToPendientes() async {
              setModalState(() => busy = true);
              try {
                final boardId = _sync?.actividadesBoardId ??
                    (_sync?.boards.isNotEmpty == true
                        ? _sync!.boards.first.id
                        : '1');
                LinkPreviewModel? preview;
                if (extractedUrl != null && extractedUrl.isNotEmpty) {
                  preview = await widget.api.fetchLinkPreview(extractedUrl);
                }
                final customTitle = noteCtrl.text.trim();
                await widget.api.addBoardItem(
                  boardId: boardId,
                  title: customTitle.isNotEmpty
                      ? customTitle
                      : (preview?.title ?? sharedRaw),
                  notes: extractedUrl != null && customTitle.isNotEmpty
                      ? extractedUrl
                      : '',
                  categoryTag: 'PENDIENTE',
                  emoji: '🔗',
                  bgColor: '#FFDAD6',
                  linkUrl: extractedUrl,
                );
                if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                await _loadSync(silent: true);
                if (mounted) {
                  _jumpToTab(1);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Guardado en PENDIENTES / BOARDS'),
                    ),
                  );
                }
              } catch (e) {
                setModalState(() => busy = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Container(
                padding: const EdgeInsets.all(22),
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
                    Text(
                      'COMPARTIR EN AMODORO',
                      textAlign: TextAlign.center,
                      style: AmodoroTheme.googleSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: inkColor,
                      ),
                    ),
                    if (extractedUrl != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: AmodoroTheme.cardOutlineBox(
                          color: fieldBg,
                          radius: 14,
                          borderColor: borderColor,
                          borderWidth: 2.0,
                          subtleShadow: false,
                        ),
                        child: Text(
                          extractedUrl,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AmodoroTheme.googleSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: mutedColor,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: AmodoroTheme.cardOutlineBox(
                        color: fieldBg,
                        radius: 18,
                        borderColor: borderColor,
                        borderWidth: 2.5,
                        subtleShadow: false,
                      ),
                      child: TextField(
                        controller: noteCtrl,
                        maxLines: 2,
                        style: AmodoroTheme.googleSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: inkColor,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Título o mensaje opcional...',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AmodoroPressableButton(
                      onTap: busy ? null : sendAsHomeCard,
                      color: AmodoroTheme.coralPillLight,
                      lipColor: AmodoroTheme.coralPillBorderLight,
                      lipHeight: 3.5,
                      radius: 999,
                      height: 50,
                      child: Text(
                        busy ? 'ENVIANDO...' : 'ENVIAR COMO TARJETA DE HOME',
                        style: AmodoroTheme.googleSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AmodoroPressableButton(
                      onTap: busy ? null : saveToPendientes,
                      color: fieldBg,
                      borderColor: borderColor,
                      borderWidth: 1.5,
                      lipColor: borderColor,
                      lipHeight: 3.0,
                      radius: 999,
                      height: 50,
                      child: Text(
                        'GUARDAR EN PENDIENTES / BOARDS',
                        style: AmodoroTheme.googleSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: inkColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    AmodoroPressableButton(
                      onTap: busy
                          ? null
                          : () async {
                              Navigator.of(sheetCtx).pop();
                              if (!mounted) return;
                              final partnerNick =
                                  _sync?.partner?.myGivenNickname ?? 'Pareja';
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CreateCardScreen(
                                    api: widget.api,
                                    partnerNickname: partnerNick,
                                  ),
                                ),
                              );
                              await _loadSync(silent: true);
                            },
                      color: Colors.transparent,
                      lipHeight: 0,
                      radius: 999,
                      height: 48,
                      child: Text(
                        'ABRIR EDITOR DE TARJETA',
                        style: AmodoroTheme.googleSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.9,
                          color: mutedColor,
                        ),
                      ),
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

  Future<void> _loadSync({bool silent = false}) async {
    if (widget.onRefresh != null && widget.sync != null) {
      await widget.onRefresh!();
      return;
    }
    if (!widget.api.isAuthenticated) {
      widget.onLogout();
      return;
    }

    if (!silent && _sync == null && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      _loading = true;
    }

    try {
      final data = await widget.api.fetchSync();
      if (!mounted) return;
      setState(() {
        _sync = data;
        _loading = false;
        _error = null;
      });
      widget.onThemeChanged?.call(data.me.themeMode);

      if (_pendingSharedText != null) {
        final pending = _pendingSharedText!;
        _pendingSharedText = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showSharedContentSheet(pending);
          }
        });
      }
    } catch (e) {
      _loading = false;
      final msg = e.toString();
      if (msg.contains('Sesión expirada') || !widget.api.isAuthenticated) {
        if (mounted) {
          widget.onLogout();
        }
        return;
      }
      if (!silent && mounted) {
        setState(() {
          _error = msg.replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _jumpToTab(int index) {
    setState(() {
      _activeIndex = index;
    });
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final syncData = _sync;

    if (syncData == null) {
      if (_error != null) {
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'amodoro',
                      style: AmodoroTheme.logoStyle(
                        fontSize: 38,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: AmodoroTheme.googleSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    AmodoroPressableButton(
                      onTap: () => _loadSync(silent: false),
                      color: AmodoroTheme.coralPillLight,
                      lipColor: AmodoroTheme.coralPillBorderLight,
                      lipHeight: 3.5,
                      radius: 999,
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'REINTENTAR CONEXIÓN',
                        style: AmodoroTheme.googleSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      return Scaffold(
        body: Center(
          child: Text(
            'amodoro',
            style: AmodoroTheme.logoStyle(fontSize: 38, isDark: isDark),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Capsules (HOME, BOARDS, SETTINGS)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth;
                  final slotWidth = maxWidth / _tabs.length;

                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, _) {
                      double page = _activeIndex.toDouble();
                      if (_pageController.hasClients &&
                          _pageController.positions.length == 1 &&
                          _pageController.position.haveDimensions &&
                          _pageController.page != null) {
                        page = _pageController.page!.clamp(
                          0.0,
                          (_tabs.length - 1).toDouble(),
                        );
                      }

                      return SizedBox(
                        height: 48,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              left: page * slotWidth + 6.0,
                              top: 6.0,
                              width: slotWidth - 12.0,
                              height: 36.0,
                              child: Transform.translate(
                                offset: Offset(
                                  0,
                                  _pressedNavIndex != null ? 3.5 : 0.0,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AmodoroTheme.coralPillDark
                                        : AmodoroTheme.coralPillLight,
                                    borderRadius: BorderRadius.circular(999),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isDark
                                            ? AmodoroTheme.coralPillBorderDark
                                            : AmodoroTheme.coralPillBorderLight,
                                        offset: Offset(
                                          0,
                                          _pressedNavIndex != null ? 0.0 : 3.5,
                                        ),
                                        blurRadius: 0,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: Row(
                                children: List.generate(_tabs.length, (i) {
                                  final double selectWeight =
                                      (1.0 - (page - i).abs()).clamp(0.0, 1.0);
                                  final Color labelColor = Color.lerp(
                                    const Color(0xFF9B8E8E),
                                    Colors.white,
                                    selectWeight,
                                  )!;

                                  return Expanded(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTapDown: (_) =>
                                          setState(() => _pressedNavIndex = i),
                                      onTapUp: (_) =>
                                          setState(() => _pressedNavIndex = null),
                                      onTapCancel: () =>
                                          setState(() => _pressedNavIndex = null),
                                      onTap: () => _jumpToTab(i),
                                      child: Center(
                                        child: Text(
                                          _tabs[i],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AmodoroTheme.googleSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.3,
                                            color: labelColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Subtle Offline Banner (Requirement F3)
            if (syncData.isOffline)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: AmodoroTheme.cardOutlineBox(
                    color: isDark
                        ? AmodoroTheme.darkContainer
                        : const Color(0xFFFFF5DC),
                    radius: 999,
                    borderColor: isDark
                        ? const Color(0xFF524949)
                        : const Color(0xFFE2CFA2),
                    borderWidth: 2.0,
                    subtleShadow: false,
                  ),
                  child: Row(
                    children: [
                      AmodoroTheme.sysIcon(
                        Symbols.cloud_off,
                        size: 16,
                        color: isDark
                            ? AmodoroTheme.darkInk
                            : AmodoroTheme.lightInk,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Modo sin conexión · Mostrando datos guardados',
                          style: AmodoroTheme.googleSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AmodoroTheme.darkInk
                                : AmodoroTheme.lightInk,
                          ),
                        ),
                      ),
                      AmodoroPressableButton(
                        onTap: () => _loadSync(silent: false),
                        color: AmodoroTheme.coralPillLight,
                        lipColor: AmodoroTheme.coralPillBorderLight,
                        lipHeight: 2.5,
                        radius: 999,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        child: Text(
                          'REINTENTAR',
                          style: AmodoroTheme.googleSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) {
                  if (_activeIndex != index) {
                    setState(() {
                      _activeIndex = index;
                    });
                  }
                },
                children: [
                  HomeScreen(
                    sync: syncData,
                    api: widget.api,
                    onRefresh: () => _loadSync(silent: true),
                  ),
                  BoardsScreen(
                    sync: syncData,
                    api: widget.api,
                    onRefresh: () => _loadSync(silent: true),
                  ),
                  SettingsScreen(
                    sync: syncData,
                    api: widget.api,
                    onRefresh: () => _loadSync(silent: true),
                    onThemeChanged: widget.onThemeChanged,
                    onLogout: widget.onLogout,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
