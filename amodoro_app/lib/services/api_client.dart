import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/amodoro_models.dart';

class AmodoroApiClient {
  static const String defaultBaseUrl = 'http://68.211.73.23';
  static const String _prefToken = 'amodoro_session_token';

  final String _baseUrl = defaultBaseUrl;
  String? _token;

  String get baseUrl => _baseUrl;
  String? get token => _token;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_prefToken);
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

  Future<Map<String, dynamic>> loginPassword(
    String username,
    String password,
  ) async {
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
    return body;
  }

  Future<Map<String, dynamic>> registerAccount({
    required String displayName,
    required String avatarId,
    required String password,
    String? username,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/api/v1/auth'),
          headers: _headers(),
          body: jsonEncode({
            'mode': 'register',
            'displayName': displayName.trim(),
            'username': (username ?? displayName).trim(),
            'avatarId': avatarId,
            'password': password.trim().isEmpty ? 'amodoro2025' : password,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || body['ok'] != true) {
      throw Exception(body['error'] ?? 'No se pudo completar el registro');
    }
    await setToken(body['token']?.toString());
    return body;
  }

  Future<Map<String, dynamic>> pairWithCode(String code) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/api/v1/auth'),
          headers: _headers(),
          body: jsonEncode({
            'mode': isAuthenticated ? 'pair' : 'code',
            'code': code.trim().toUpperCase(),
          }),
        )
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || body['ok'] != true) {
      throw Exception(body['error'] ?? 'Código de emparejamiento inválido');
    }
    if (body['token'] != null) {
      await setToken(body['token']?.toString());
    }
    return body;
  }

  Future<SyncPayload> fetchSync() async {
    final res = await http
        .get(Uri.parse('$_baseUrl/api/v1/sync'), headers: _headers())
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 401) {
      await logout();
      throw Exception('Sesión expirada.');
    }
    if (res.statusCode >= 400 || body['ok'] != true) {
      throw Exception(body['error'] ?? 'Error al sincronizar');
    }
    return SyncPayload.fromJson(body);
  }

  Future<LinkPreviewModel> fetchLinkPreview(String url) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/api/v1/link-preview'),
          headers: _headers(),
          body: jsonEncode({'url': url.trim()}),
        )
        .timeout(const Duration(seconds: 10));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || body['ok'] != true) {
      return LinkPreviewModel(
        url: url.trim(),
        title: url.trim(),
        platform: 'Web',
      );
    }
    final previewMap = (body['preview'] as Map<String, dynamic>?) ?? {};
    return LinkPreviewModel.fromJson(previewMap);
  }

  Future<void> createHomeCard({
    required String textContent,
    required String bgColor,
    required String fontFamily,
    required String fontSize,
    required int fontSizePx,
    required String mediaType,
    String? mediaDataUrl,
    String? linkUrl,
    String? linkTitle,
    String? linkThumbnail,
    String? linkPlatform,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/api/v1/home'),
          headers: _headers(),
          body: jsonEncode({
            'action': 'create_card',
            'body': textContent,
            'textContent': textContent,
            'bgColor': bgColor,
            'fontFamily': fontFamily,
            'fontSize': fontSize,
            'fontSizePx': fontSizePx,
            'mediaType': mediaType,
            'imageBase64': mediaDataUrl ?? '',
            'mediaDataUrl': mediaDataUrl ?? '',
            'mediaKind': mediaType == 'drawing' ? 'drawing' : 'image',
            'linkUrl': linkUrl ?? '',
            'linkTitle': linkTitle ?? '',
            'linkThumbnail': linkThumbnail ?? '',
            'linkPlatform': linkPlatform ?? '',
          }),
        )
        .timeout(const Duration(seconds: 25));
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
    String bgColor = '#F4EFE8',
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/api/v1/boards'),
          headers: _headers(),
          body: jsonEncode({
            'action': 'create_board',
            'title': title,
            'icon': icon,
            'bgColor': bgColor,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || body['ok'] != true) {
      throw Exception(body['error'] ?? 'Error al crear tablero');
    }
  }

  Future<void> updateBoard({
    required String boardId,
    String? title,
    String? icon,
    String? bgColor,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/api/v1/boards'),
          headers: _headers(),
          body: jsonEncode({
            'action': 'update_board',
            'boardId': boardId,
            'title': title,
            'icon': icon,
            'bgColor': bgColor,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || body['ok'] != true) {
      throw Exception(body['error'] ?? 'Error al editar tablero');
    }
  }

  Future<void> deleteBoard(String boardId) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/api/v1/boards'),
          headers: _headers(),
          body: jsonEncode({
            'action': 'delete_board',
            'boardId': boardId,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || body['ok'] != true) {
      throw Exception(body['error'] ?? 'Error al eliminar tablero');
    }
  }

  Future<void> addBoardItem({
    required String boardId,
    required String title,
    String notes = '',
    String categoryTag = '',
    String emoji = '',
    String bgColor = '#FFDAD6',
    String? mediaDataUrl,
    String? linkUrl,
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
            'categoryTag': categoryTag,
            'emoji': emoji,
            'bgColor': bgColor,
            'imageBase64': mediaDataUrl ?? '',
            'linkUrl': linkUrl ?? '',
          }),
        )
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || body['ok'] != true) {
      throw Exception(body['error'] ?? 'Error al agregar elemento');
    }
  }

  Future<void> updateBoardItem({
    required String itemId,
    String? title,
    String? notes,
    String? categoryTag,
    String? bgColor,
    String? emoji,
    String? linkUrl,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/api/v1/boards'),
          headers: _headers(),
          body: jsonEncode({
            'action': 'update_item',
            'itemId': itemId,
            'title': title,
            'notes': notes,
            'categoryTag': categoryTag,
            'bgColor': bgColor,
            'emoji': emoji,
            'linkUrl': linkUrl,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || body['ok'] != true) {
      throw Exception(body['error'] ?? 'Error al actualizar elemento');
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
      throw Exception(body['error'] ?? 'Error al pasar a Pendientes');
    }
  }

  Future<void> deleteOrCompleteItem(String itemId) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/api/v1/boards'),
          headers: _headers(),
          body: jsonEncode({
            'action': 'delete_item',
            'itemId': itemId,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || body['ok'] != true) {
      throw Exception(body['error'] ?? 'Error al eliminar elemento');
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
    String? displayName,
    String? avatarId,
    required String partnerNickname,
    required String themeMode,
    required String accentPalette,
    required List<String> quickReplies,
    List<String>? reactionEmojis,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/api/v1/settings'),
          headers: _headers(),
          body: jsonEncode({
            'action': 'update_settings',
            'displayName': displayName,
            'avatarId': avatarId,
            'partnerNickname': partnerNickname,
            'themeMode': themeMode,
            'accentPalette': accentPalette,
            'quickReplies': quickReplies,
            if (reactionEmojis != null) 'reactionEmojis': reactionEmojis,
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
