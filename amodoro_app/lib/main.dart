import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'services/api_client.dart';
import 'theme/amodoro_theme.dart';

typedef AmodoroApp = AmodoroRootApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Allows running in unit/widget tests or environments without google-services.json
  }
  final apiClient = AmodoroApiClient();
  await apiClient.init();
  runApp(AmodoroRootApp(api: apiClient));
}

class AmodoroRootApp extends StatefulWidget {
  final AmodoroApiClient api;

  const AmodoroRootApp({super.key, required this.api});

  @override
  State<AmodoroRootApp> createState() => _AmodoroRootAppState();
}

class _AmodoroRootAppState extends State<AmodoroRootApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = _parseThemeMode(widget.api.rememberedUser?.themeMode);
  }

  ThemeMode _parseThemeMode(String? mode) {
    switch (mode?.toLowerCase().trim()) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      case 'system':
      case 'auto':
      default:
        return ThemeMode.system;
    }
  }

  void _updateThemeMode(String mode) {
    final nextMode = _parseThemeMode(mode);
    if (mounted && _themeMode != nextMode) {
      setState(() {
        _themeMode = nextMode;
      });
    }
  }

  bool get _authenticated =>
      widget.api.isAuthenticated && widget.api.isPinUnlocked;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'amodoro',
      debugShowCheckedModeBanner: false,
      theme: AmodoroTheme.lightTheme(),
      darkTheme: AmodoroTheme.darkTheme(),
      themeMode: _themeMode,
      home: _authenticated
          ? MainShell(
              api: widget.api,
              onThemeChanged: _updateThemeMode,
              onLogout: () => setState(() {
                widget.api.isPinUnlocked = false;
              }),
            )
          : LoginScreen(
              api: widget.api,
              onAuthenticated: () => setState(() {
                widget.api.isPinUnlocked = true;
                final rememberedMode = widget.api.rememberedUser?.themeMode;
                if (rememberedMode != null) {
                  _themeMode = _parseThemeMode(rememberedMode);
                }
              }),
            ),
    );
  }
}
