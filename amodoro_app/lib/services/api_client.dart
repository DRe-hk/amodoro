import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/amodoro_models.dart';

class AmodoroApiClient {
  static const String defaultBaseUrl = 'http://68.211.73.23';
  static const String _prefBaseUrl = 'amodoro_base_url';
  static const String _prefToken = 'amodoro_session_token';

  String _baseUrl = defaultBaseUrl;
  String? _token;

  String get baseUrl => _baseUrl;
  String? get token => _token;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_prefBaseUrl);
    if (savedUrl != null && savedUrl.trim().isNotEmpty) {
      _baseUrl = savedUrl.trim().replaceAll(RegExp(r'/+$'), '');
    }
    _token = prefs.getString(_prefToken);
  }

  Future<void> setBaseUrl(String url) async {
    final clean = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (clean.isEmpty) return;
    _baseUrl = clean;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefBaseUrl, _baseUrl);
  }

  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null || token.isEmpty) {
      await prefs.remove(_prefToken);
    } else {
      await prefs.setString(_prefToken, token);
    }
  }

  Future<void> logout() async {
    await setToken(null);
  }

  Map<String, String> _headers() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  String resolveMediaUrl(String? mediaUrl) {
    if (mediaUrl == null || mediaUrl.isEmpty) return '';
    if (mediaUrl.startsWith('data:') || mediaUrl.startsWith('http')) {
      return mediaUrl;
    }
    return '$_baseUrl$mediaUrl';
  }

  Future<List<AuthProfileOption>> fetchAuthProfiles() async {
    final res = await http
        .get(Uri.parse('$_baseUrl/api/v1/auth'), headers: _headers())
        .timeout(const Duration(seconds: 12));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final raw = body['profiles'];
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(AuthProfileOption.fromJson)
          .toList();
    }
    return const [];
  }

  Future<void> loginPassword(String username, String password) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/api/v1/auth'),
          headers: _headers(),
          body: jsonEncode({
            'mode': 'password',
            'username': username.trim(),
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || body['ok'] != true) {
      throw Exception(body['error'] ?? 'Credenciales inválidas');
    }
    await setToken(body['token']?.toString());
  }

  Future<void> loginInviteCode(String code) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/api/v1/auth'),
          headers: _headers(),
          body: jsonEncode({
            'mode': 'code',
            'code': code.trim().toUpperCase(),
          }),
        )
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || body['ok'] != true) {
      throw Exception(body['error'] ?? 'Código inválido');
    }
    await setToken(body['token']?.toString());
  }

  Future<void> loginQuick(int userId) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/api/v1/auth'),
          headers: _headers(),
          body: jsonEncode({
            'mode': 'quick',
            'userId': userId,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || body['ok'] != true) {
      throw Exception(body['error'] ?? 'No se pudo iniciar sesión');
    }
    await setToken(body['token']?.toString());
  }

  Future<SyncPayload> fetchSync() async {
    final res = await http
        .get(Uri.parse('$_baseUrl/api/v1/sync'), headers: _headers())
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 401) {
      await logout();
      throw Exception('Sesión expirada. Vuelve a iniciar sesión.');
    }
    if (res.statusCode >= 400 || body['ok'] != true) {
      throw Exception(body['error'] ?? 'Error al sincronizar con el servidor');
    }
    return SyncPayload.fromJson(body);
  }

  Future<void> createHomeCard({
    required String textContent,
    required String bgColor,
    required String fontFamily,
    required String fontSize,
    required String mediaType,
    String? mediaDataUrl,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/api/v1/home'),
          headers: _headers(),
          body: jsonEncode({
            'action': 'create_card',
            'textContent': textContent,
            'bgColor': bgColor,
            'fontFamily': fontFamily,
            'fontSize': fontSize,
            'mediaType': mediaType,
            'mediaDataUrl': mediaDataUrl ?? '',
          }),
        )
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || body['ok'] != true) {
      throw Exception(body['error'] ?? 'Error al enviar tarjeta');
    }
  }

  Future<void> reactToCard({
    required String cardId,
    String? emoji,
    String? presetText,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/api/v1/home'),
          headers: _headers(),
          body: jsonEncode({
            'action': 'react',
            'cardId': cardId,
            'emoji': emoji,
            'presetText': presetText,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || body['ok'] != true) {
      throw Exception(body['error'] ?? 'Error al reaccionar');
    }
  }

  Future<void> createBoard({
    required String title,
    required String icon,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/api/v1/boards'),
          headers: _headers(),
          body: jsonEncode({
            'action': 'create_board',
            'title': title,
            'icon': icon,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || body['ok'] != true) {
      throw Exception(body['error'] ?? 'Error al crear tablero');
    }
  }

  Future<void> addBoardItem({
    required String boardId,
    required String title,
    String notes = '',
    String emoji = '✨',
    String bgColor = '#FFDAD6',
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/api/v1/boards'),
          headers: _headers(),
          body: jsonEncode({
            'action': 'add_item',
            'boardId': boardId,
            'title': title,
            'notes': notes,
            'emoji': emoji,
            'bgColor': bgColor,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || body['ok'] != true) {
      throw Exception(body['error'] ?? 'Error al agregar ítem');
    }
  }

  Future<void> copyToActividades(String itemId) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/api/v1/boards'),
          headers: _headers(),
          body: jsonEncode({
            'action': 'copy_to_actividades',
            'itemId': itemId,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || body['ok'] != true) {
      throw Exception(body['error'] ?? 'Error al copiar a Actividades');
    }
  }

  Future<void> completeItem(String itemId) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/api/v1/boards'),
          headers: _headers(),
          body: jsonEncode({
            'action': 'complete_item',
            'itemId': itemId,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || body['ok'] != true) {
      throw Exception(body['error'] ?? 'Error al completar actividad');
    }
  }

  Future<Map<String, dynamic>> spinRoulette() async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/api/v1/decision'),
          headers: _headers(),
          body: jsonEncode({'action': 'roulette'}),
        )
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || body['ok'] != true) {
      throw Exception(body['error'] ?? 'Error en la ruleta');
    }
    return (body['result'] as Map<String, dynamic>?) ?? body;
  }

  Future<Map<String, dynamic>> startVoting() async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/api/v1/decision'),
          headers: _headers(),
          body: jsonEncode({'action': 'start_voting'}),
        )
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || body['ok'] != true) {
      throw Exception(body['error'] ?? 'Error al iniciar votación');
    }
    return (body['result'] as Map<String, dynamic>?) ?? body;
  }

  Future<Map<String, dynamic>> submitVotes(
    String sessionId,
    Map<String, bool> votes,
  ) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/api/v1/decision'),
          headers: _headers(),
          body: jsonEncode({
            'action': 'submit_votes',
            'sessionId': sessionId,
            'votes': votes,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || body['ok'] != true) {
      throw Exception(body['error'] ?? 'Error al registrar votos');
    }
    return (body['result'] as Map<String, dynamic>?) ?? body;
  }

  Future<void> updateSettings({
    required String partnerNickname,
    required String themeMode,
    required String accentPalette,
    required List<String> quickReplies,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/api/v1/settings'),
          headers: _headers(),
          body: jsonEncode({
            'action': 'update_settings',
            'partnerNickname': partnerNickname,
            'themeMode': themeMode,
            'accentPalette': accentPalette,
            'quickReplies': quickReplies,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || body['ok'] != true) {
      throw Exception(body['error'] ?? 'Error al guardar ajustes');
    }
  }

  Future<String> createInviteCode() async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/api/v1/settings'),
          headers: _headers(),
          body: jsonEncode({'action': 'create_invite'}),
        )
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || body['ok'] != true) {
      throw Exception(body['error'] ?? 'Error al generar código');
    }
    return (body['code'] ?? '').toString();
  }
}
