import 'package:flutter/material.dart';
import 'models/amodoro_models.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'services/api_client.dart';
import 'theme/amodoro_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = AmodoroApiClient();
  await api.init();
  runApp(AmodoroApp(api: api));
}

class AmodoroApp extends StatefulWidget {
  final AmodoroApiClient api;

  const AmodoroApp({super.key, required this.api});

  @override
  State<AmodoroApp> createState() => _AmodoroAppState();
}

class _AmodoroAppState extends State<AmodoroApp> {
  SyncPayload? _sync;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.api.isAuthenticated) {
      _loadSync();
    }
  }

  Future<void> _loadSync() async {
    if (!widget.api.isAuthenticated) return;
    if (_sync == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await widget.api.fetchSync();
      if (mounted) {
        setState(() {
          _sync = data;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    await widget.api.logout();
    if (mounted) {
      setState(() {
        _sync = null;
        _error = null;
      });
    }
  }

  ThemeMode _resolveThemeMode() {
    final mode = _sync?.me.themeMode ?? 'light';
    if (mode == 'dark') return ThemeMode.dark;
    if (mode == 'auto') return ThemeMode.system;
    return ThemeMode.light;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Amodoro',
      debugShowCheckedModeBanner: false,
      theme: AmodoroTheme.lightTheme(),
      darkTheme: AmodoroTheme.darkTheme(),
      themeMode: _resolveThemeMode(),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (!widget.api.isAuthenticated) {
      return LoginScreen(
        api: widget.api,
        onLoggedIn: _loadSync,
      );
    }

    if (_loading && _sync == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: AmodoroTheme.coralPillLight,
              ),
              const SizedBox(height: 16),
              Text(
                'Sincronizando con Amodoro VPS...',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null && _sync == null) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 48,
                    color: AmodoroTheme.coralPillLight,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No se pudo conectar con el servidor',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: _handleLogout,
                        child: const Text('Cambiar cuenta / servidor'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AmodoroTheme.coralPillLight,
                          foregroundColor: AmodoroTheme.coralPillTextLight,
                        ),
                        onPressed: _loadSync,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return MainShell(
      api: widget.api,
      sync: _sync!,
      onRefresh: _loadSync,
      onLogout: _handleLogout,
    );
  }
}
