import 'dart:async';
import 'package:flutter/material.dart';
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
    final coralPillInk = isDark
        ? AmodoroTheme.coralPillTextDark
        : AmodoroTheme.coralPillTextLight;
    final inactiveInk =
        isDark ? const Color(0xFFA59E96) : const Color(0xFF6E655E);
    final barSurface =
        isDark ? const Color(0xFF1F2421) : const Color(0xFFF4EFE8);
    final barBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.07);

    final activeIndex = _pageProgress.round().clamp(0, 2);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Barra Superior con Píldora Coral Deslizante (1/3 ancho interno, 22dp alto, márgenes laterales)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: barSurface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: barBorder),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final innerWidth = constraints.maxWidth;
                    final pillWidth = innerWidth / 3.0;
                    final leftOffset = _pageProgress * pillWidth;

                    return SizedBox(
                      height: 22,
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Positioned(
                            left: leftOffset,
                            width: pillWidth,
                            height: 22,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: coralPillBg,
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: [
                                  BoxShadow(
                                    color: coralPillBg.withValues(alpha: 0.28),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
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
                                    height: 22,
                                    child: Center(
                                      child: Text(
                                        _tabs[i],
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.3,
                                          height: 1.0,
                                          color: isSelected
                                              ? coralPillInk
                                              : inactiveInk,
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
            ),

            // Contenido con gesto swipe horizontal sincronizado en tiempo real
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
