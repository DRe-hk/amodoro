import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/amodoro_models.dart';
import '../services/api_client.dart';
import '../theme/amodoro_theme.dart';
import 'boards_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  final AmodoroApiClient api;
  final SyncPayload sync;
  final Future<void> Function() onRefresh;
  final VoidCallback onLogout;

  const MainShell({
    super.key,
    required this.api,
    required this.sync,
    required this.onRefresh,
    required this.onLogout,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const List<String> _tabs = ['HOME', 'BOARDS', 'SETTINGS'];
  late final PageController _pageController;
  double _pageProgress = 0.0;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _pageController.addListener(_onPageScroll);
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      widget.onRefresh();
    });
  }

  void _onPageScroll() {
    final page = _pageController.page;
    if (page != null && mounted) {
      setState(() {
        _pageProgress = page.clamp(0.0, 2.0);
      });
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    super.dispose();
  }

  void _jumpToTab(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coralPillBg =
        isDark ? AmodoroTheme.coralPillDark : AmodoroTheme.coralPillLight;
    final coralPillEdge = isDark
        ? AmodoroTheme.coralPillBorderDark
        : AmodoroTheme.coralPillBorderLight;
    final coralPillInk = isDark
        ? AmodoroTheme.coralPillTextDark
        : AmodoroTheme.coralPillTextLight;
    final inactiveInk =
        isDark ? const Color(0xFFA59E96) : const Color(0xFF4E453E);

    final activeIndex = _pageProgress.round().clamp(0, 2);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Barra Superior directamente sobre el lienzo (sin píldora contenedora exterior).
            // Únicamente se mueve la píldora activa Coral con borde inferior y derecho de 2px.
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final innerWidth = constraints.maxWidth;
                  final pillWidth = innerWidth / 3.0;
                  final leftOffset = _pageProgress * pillWidth;
                  final textScale = MediaQuery.textScalerOf(context).scale(1.0);
                  final pillHeight = (22.0 * textScale).clamp(22.0, 34.0);

                  return SizedBox(
                    height: pillHeight + 4,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.centerLeft,
                      children: [
                        Positioned(
                          left: leftOffset,
                          top: 0,
                          width: pillWidth,
                          height: pillHeight,
                          child: DecoratedBox(
                            decoration: AmodoroTheme.floatingPerspectiveBox(
                              color: coralPillBg,
                              radius: 999,
                              thickness: 2.0,
                              perspectiveEdgeColor: coralPillEdge,
                            ),
                          ),
                        ),
                        Row(
                          children: List.generate(_tabs.length, (i) {
                            final isSelected = i == activeIndex;
                            return Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _jumpToTab(i),
                                child: SizedBox(
                                  height: pillHeight,
                                  child: Center(
                                    child: Text(
                                      _tabs[i],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: isSelected
                                          ? AmodoroTheme.activeElementTextStyle(
                                              fontSize: 11.5,
                                              color: coralPillInk,
                                              letterSpacing: 1.6,
                                            ).copyWith(height: 1.0)
                                          : GoogleFonts.raleway(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w400,
                                              letterSpacing: 1.6,
                                              height: 1.0,
                                              color: inactiveInk,
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                children: [
                  HomeScreen(
                    sync: widget.sync,
                    api: widget.api,
                    onRefresh: widget.onRefresh,
                  ),
                  BoardsScreen(
                    sync: widget.sync,
                    api: widget.api,
                    onRefresh: widget.onRefresh,
                  ),
                  SettingsScreen(
                    sync: widget.sync,
                    api: widget.api,
                    onRefresh: widget.onRefresh,
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
