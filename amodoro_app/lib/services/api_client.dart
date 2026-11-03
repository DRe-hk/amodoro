import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/amodoro_models.dart';

class AmodoroApiException implements Exception {
  final String message;

  const AmodoroApiException(this.message);

  @override
  String toString() => message;
}

class AmodoroApiClient {
  static const String defaultBaseUrl = 'https://amodoro.drehk.dev';
  static const String _prefToken = 'amodoro_session_token';
  static const String _prefRememberedUser = 'amodoro_remembered_user_json';
  static const String _prefCachedSync = 'amodoro_cached_sync_json';

  final String _baseUrl = defaultBaseUrl;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _token;
  UserProfile? _rememberedUser;
  bool isPinUnlocked = false;

  String get baseUrl => _baseUrl;
  String? get token => _token;
  UserProfile? get rememberedUser => _rememberedUser;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  Future<String?> _readSecureOrPrefs(String key) async {
    try {
      final val = await _secureStorage.read(key: key);
      if (val != null && val.isNotEmpty) {
        return val;
      }
    } catch (_) {
      // Fallback to SharedPreferences on unsupported platforms or tests
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeSecureAndPrefs(String key, String? value) async {
    try {
      if (value == null || value.isEmpty) {
        await _secureStorage.delete(key: key);
      } else {
        await _secureStorage.write(key: key, value: value);
      }
    } catch (_) {
      // Fallback to SharedPreferences
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value == null || value.isEmpty) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, value);
      }
    } catch (_) {}
  }

  Future<void> init() async {
    _token = await _readSecureOrPrefs(_prefToken);
    final rawRemembered = await _readSecureOrPrefs(_prefRememberedUser);
    if (rawRemembered != null && rawRemembered.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawRemembered);
        if (decoded is Map<String, dynamic>) {
          _rememberedUser = UserProfile.fromJson(decoded);
        }
      } catch (_) {}
    }
  }

  Future<void> setToken(String? token) async {
    _token = token;
    await _writeSecureAndPrefs(_prefToken, token);
  }

  Future<void> setRememberedUser(UserProfile? user) async {
    _rememberedUser = user;
    if (user == null) {
      await _writeSecureAndPrefs(_prefRememberedUser, null);
    } else {
      await _writeSecureAndPrefs(_prefRememberedUser, jsonEncode(user.toJson()));
    }
  }

  Future<void> clearRememberedUser() async {
    await setRememberedUser(null);
  }

  Future<void> logout({bool clearRememberedAccount = false}) async {
    if (_token != null && _token!.isNotEmpty) {
      try {
        await http
            .post(
              Uri.parse('$_baseUrl/api/v1/auth'),
              headers: _headers(),
              body: jsonEncode({'mode': 'logout'}),
            )
            .timeout(const Duration(seconds: 6));
      } catch (_) {
        // Ignore network errors during logout
      }
    }
    isPinUnlocked = false;
    await setToken(null);
    if (clearRememberedAccount) {
      await clearRememberedUser();
    }
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

  String _cleanError(Object error, [String fallback = 'Ocurrió un error inesperado.']) {
    if (error is AmodoroApiException) return error.message;
    if (error is TimeoutException) {
      return 'El servidor tardó demasiado en responder. Revisa tu conexión.';
    }
    final raw = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
    if (raw.contains('SocketException') ||
        raw.contains('ClientException') ||
        raw.contains('Failed host lookup') ||
        raw.contains('Connection refused') ||
        raw.contains('Network is unreachable')) {
      return 'Sin conexión al servidor. Revisa tu internet.';
    }
    return raw.isNotEmpty ? raw : fallback;
  }

  String resolveMediaUrl(String? mediaUrl) {
    if (mediaUrl == null || mediaUrl.isEmpty) return '';
    if (mediaUrl.startsWith('data:')) {
      return mediaUrl;
    }
    String resolved = mediaUrl.startsWith('http')
        ? mediaUrl
        : '$_baseUrl${mediaUrl.startsWith('/') ? '' : '/'}$mediaUrl';

    if ((mediaUrl.startsWith('/api/media/') ||
            resolved.contains('/api/media/')) &&
        _token != null &&
        _token!.isNotEmpty) {
      final separator = resolved.contains('?') ? '&' : '?';
      if (!resolved.contains('t=')) {
        resolved = '$resolved${separator}t=${Uri.encodeQueryComponent(_token!)}';
      }
    }
    return resolved;
  }

  Future<void> _saveUserFromAuthBody(Map<String, dynamic> body) async {
    final rawUser = body['user'];
    if (rawUser is Map<String, dynamic>) {
      final profile = UserProfile.fromJson(rawUser);
      await setRememberedUser(profile);
    }
  }

  Future<AuthStatusResponse> fetchAuthStatus() async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/api/v1/auth'),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 12));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final status = AuthStatusResponse.fromJson(body);
      if (status.authenticatedUser != null) {
        await setRememberedUser(status.authenticatedUser);
      }
      return status;
    } catch (e) {
      throw AmodoroApiException(
        _cleanError(e, 'No se pudo verificar el estado del servidor.'),
      );
    }
  }

  Future<Map<String, dynamic>> registerWithPin({
    required String displayName,
    required String avatarId,
    required String pin,
    String? code,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/auth'),
            headers: _headers(),
            body: jsonEncode({
              'mode': 'register',
              'displayName': displayName.trim(),
              'username': displayName.trim(),
              'avatarId': avatarId,
              'pin': pin.trim(),
              'password': pin.trim(),
              if (code != null && code.trim().isNotEmpty)
                'code': code.trim().toUpperCase(),
            }),
          )
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 400 || body['ok'] != true) {
        throw AmodoroApiException(
          (body['error'] ?? 'No se pudo completar el registro.').toString(),
        );
      }
      await setToken(body['token']?.toString());
      await _saveUserFromAuthBody(body);
      isPinUnlocked = true;
      return body;
    } catch (e) {
      throw AmodoroApiException(
        _cleanError(e, 'No se pudo completar el registro.'),
      );
    }
  }

  Future<Map<String, dynamic>> verifyPin(
    String pin, {
    int? userId,
    String? username,
  }) async {
    try {
      final targetUserId = userId ?? _rememberedUser?.id;
      final targetUsername = username ?? _rememberedUser?.username;
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/auth'),
            headers: _headers(),
            body: jsonEncode({
              'mode': 'verify_pin',
              'pin': pin.trim(),
              if (targetUserId != null && targetUserId > 0)
                'userId': targetUserId,
              if (targetUsername != null && targetUsername.isNotEmpty)
                'username': targetUsername,
            }),
          )
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 400 || body['ok'] != true) {
        throw AmodoroApiException(
          (body['error'] ?? 'PIN incorrecto.').toString(),
        );
      }
      if (body['token'] != null) {
        await setToken(body['token']?.toString());
      }
      await _saveUserFromAuthBody(body);
      isPinUnlocked = true;
      return body;
    } catch (e) {
      throw AmodoroApiException(_cleanError(e, 'PIN incorrecto.'));
    }
  }

  Future<Map<String, dynamic>> changePin({
    String? currentPin,
    required String newPin,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/auth'),
            headers: _headers(),
            body: jsonEncode({
              'mode': 'change_pin',
              if (currentPin != null && currentPin.isNotEmpty)
                'currentPin': currentPin.trim(),
              'newPin': newPin.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 400 || body['ok'] != true) {
        throw AmodoroApiException(
          (body['error'] ?? 'No se pudo actualizar el PIN.').toString(),
        );
      }
      if (body['token'] != null) {
        await setToken(body['token']?.toString());
      }
      await _saveUserFromAuthBody(body);
      isPinUnlocked = true;
      return body;
    } catch (e) {
      throw AmodoroApiException(_cleanError(e, 'No se pudo actualizar el PIN.'));
    }
  }

  Future<Map<String, dynamic>> recoverPin({
    required String recoveryCode,
    required String newPin,
    int? userId,
    String? username,
  }) async {
    try {
      final targetUserId = userId ?? _rememberedUser?.id;
      final targetUsername = username ?? _rememberedUser?.username;
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/auth'),
            headers: _headers(),
            body: jsonEncode({
              'mode': 'recover_pin',
              'recoveryCode': recoveryCode.trim().toUpperCase(),
              'newPin': newPin.trim(),
              if (targetUserId != null && targetUserId > 0)
                'userId': targetUserId,
              if (targetUsername != null && targetUsername.isNotEmpty)
                'username': targetUsername,
            }),
          )
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 400 || body['ok'] != true) {
        throw AmodoroApiException(
          (body['error'] ?? 'Código de recuperación no válido.').toString(),
        );
      }
      if (body['token'] != null) {
        await setToken(body['token']?.toString());
      }
      await _saveUserFromAuthBody(body);
      isPinUnlocked = true;
      return body;
    } catch (e) {
      throw AmodoroApiException(
        _cleanError(e, 'Código de recuperación no válido.'),
      );
    }
  }

  Future<Map<String, dynamic>> loginPassword(
    String username,
    String password,
  ) async {
    try {
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
        throw AmodoroApiException(
          (body['error'] ?? 'Credenciales no válidas.').toString(),
        );
      }
      await setToken(body['token']?.toString());
      await _saveUserFromAuthBody(body);
      isPinUnlocked = true;
      return body;
    } catch (e) {
      throw AmodoroApiException(_cleanError(e, 'Credenciales no válidas.'));
    }
  }

  Future<Map<String, dynamic>> registerAccount({
    required String displayName,
    required String avatarId,
    required String password,
    String? username,
    String? pin,
    String? code,
  }) async {
    final resolvedPin =
        (pin != null && pin.trim().length == 4) ? pin.trim() : password.trim();
    return registerWithPin(
      displayName: displayName,
      avatarId: avatarId,
      pin: resolvedPin.length == 4 ? resolvedPin : '0000',
      code: code,
    );
  }

  Future<Map<String, dynamic>> pairWithCode(String code) async {
    try {
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
        throw AmodoroApiException(
          (body['error'] ?? 'Código de emparejamiento no válido.').toString(),
        );
      }
      if (body['token'] != null) {
        await setToken(body['token']?.toString());
      }
      await _saveUserFromAuthBody(body);
      return body;
    } catch (e) {
      throw AmodoroApiException(
        _cleanError(e, 'Código de emparejamiento no válido.'),
      );
    }
  }

  Future<SyncPayload?> _loadCachedSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefCachedSync);
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        return SyncPayload.fromJson(map, isOffline: true);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _saveCachedSync(Map<String, dynamic> body) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefCachedSync, jsonEncode(body));
    } catch (_) {}
  }

  Future<SyncPayload> fetchSync() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/v1/sync'), headers: _headers())
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 401) {
        await logout();
        throw const AmodoroApiException('Sesión expirada. Ingresa tu PIN.');
      }
      if (res.statusCode >= 400 || body['ok'] != true) {
        throw AmodoroApiException(
          (body['error'] ?? 'Error al sincronizar datos.').toString(),
        );
      }
      await _saveCachedSync(body);
      final payload = SyncPayload.fromJson(body, isOffline: false);
      await setRememberedUser(payload.me);
      return payload;
    } catch (e) {
      if (e is AmodoroApiException && e.message.contains('Sesión expirada')) {
        rethrow;
      }
      final cached = await _loadCachedSync();
      if (cached != null) {
        return cached;
      }
      throw AmodoroApiException(
        _cleanError(
          e,
          'Sin conexión al servidor. Mostrando datos guardados.',
        ),
      );
    }
  }

  Future<LinkPreviewModel> fetchLinkPreview(String url) async {
    try {
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
    } catch (_) {
      return LinkPreviewModel(
        url: url.trim(),
        title: url.trim(),
        platform: 'Web',
      );
    }
  }

  Future<void> createHomeCard({
    required String textContent,
    required String bgColor,
    required String fontFamily,
    required String fontSize,
    required int fontSizePx,
    required String mediaType,
    String? mediaDataUrl,
    String? altText,
    String? linkUrl,
    String? linkTitle,
    String? linkThumbnail,
    String? linkPlatform,
  }) async {
    try {
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
              if (altText != null) 'altText': altText,
              'linkUrl': linkUrl ?? '',
              'linkTitle': linkTitle ?? '',
              'linkThumbnail': linkThumbnail ?? '',
              'linkPlatform': linkPlatform ?? '',
            }),
          )
          .timeout(const Duration(seconds: 25));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 400 || body['ok'] != true) {
        throw AmodoroApiException(
          (body['error'] ?? 'No se pudo enviar la tarjeta.').toString(),
        );
      }
    } catch (e) {
      throw AmodoroApiException(_cleanError(e, 'No se pudo enviar la tarjeta.'));
    }
  }

  Future<void> updateHomeCard({
    required String cardId,
    required String textContent,
    required String bgColor,
    required String fontFamily,
    required String fontSize,
    required int fontSizePx,
    required String mediaType,
    bool keepExistingMedia = false,
    String? mediaDataUrl,
    String? altText,
    String? linkUrl,
    String? linkTitle,
    String? linkThumbnail,
    String? linkPlatform,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/home'),
            headers: _headers(),
            body: jsonEncode({
              'action': 'update_card',
              'cardId': cardId,
              'body': textContent,
              'textContent': textContent,
              'bgColor': bgColor,
              'fontFamily': fontFamily,
              'fontSize': fontSize,
              'fontSizePx': fontSizePx,
              'mediaType': mediaType,
              'keepExistingMedia': keepExistingMedia,
              'imageBase64': mediaDataUrl ?? '',
              'mediaDataUrl': mediaDataUrl ?? '',
              'mediaKind': mediaType == 'drawing' ? 'drawing' : 'image',
              if (altText != null) 'altText': altText,
              'linkUrl': linkUrl ?? '',
              'linkTitle': linkTitle ?? '',
              'linkThumbnail': linkThumbnail ?? '',
              'linkPlatform': linkPlatform ?? '',
            }),
          )
          .timeout(const Duration(seconds: 25));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 400 || body['ok'] != true) {
        throw AmodoroApiException(
          (body['error'] ?? 'No se pudo actualizar la tarjeta.').toString(),
        );
      }
    } catch (e) {
      throw AmodoroApiException(
        _cleanError(e, 'No se pudo actualizar la tarjeta.'),
      );
    }
  }

  Future<void> deleteHomeCard(String cardId) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/home'),
            headers: _headers(),
            body: jsonEncode({
              'action': 'delete_card',
              'cardId': cardId,
            }),
          )
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 400 || body['ok'] != true) {
        throw AmodoroApiException(
          (body['error'] ?? 'No se pudo eliminar la tarjeta.').toString(),
        );
      }
    } catch (e) {
      throw AmodoroApiException(
        _cleanError(e, 'No se pudo eliminar la tarjeta.'),
      );
    }
  }

  Future<void> reactToCard({
    required String cardId,
    String? emoji,
    String? presetText,
  }) async {
    try {
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
        throw AmodoroApiException(
          (body['error'] ?? 'No se pudo enviar la reacción.').toString(),
        );
      }
    } catch (e) {
      throw AmodoroApiException(
        _cleanError(e, 'No se pudo enviar la reacción.'),
      );
    }
  }

  Future<void> replyToHomeCard({
    required String cardId,
    String textContent = '',
    String mediaType = 'none',
    String? mediaDataUrl,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/home'),
            headers: _headers(),
            body: jsonEncode({
              'action': 'reply_card',
              'cardId': cardId,
              'textContent': textContent.trim(),
              'mediaType': mediaType,
              'mediaDataUrl': mediaDataUrl ?? '',
              'imageBase64': mediaDataUrl ?? '',
            }),
          )
          .timeout(const Duration(seconds: 25));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 400 || body['ok'] != true) {
        throw AmodoroApiException(
          (body['error'] ?? 'No se pudo enviar la respuesta.').toString(),
        );
      }
    } catch (e) {
      throw AmodoroApiException(
        _cleanError(e, 'No se pudo enviar la respuesta.'),
      );
    }
  }

  Future<void> createBoard({
    required String title,
    required String icon,
    String bgColor = '#F27166',
  }) async {
    try {
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
        throw AmodoroApiException(
          (body['error'] ?? 'No se pudo crear la lista.').toString(),
        );
      }
    } catch (e) {
      throw AmodoroApiException(_cleanError(e, 'No se pudo crear la lista.'));
    }
  }

  Future<void> updateBoard({
    required String boardId,
    String? title,
    String? icon,
    String? bgColor,
  }) async {
    try {
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
        throw AmodoroApiException(
          (body['error'] ?? 'No se pudo actualizar la lista.').toString(),
        );
      }
    } catch (e) {
      throw AmodoroApiException(
        _cleanError(e, 'No se pudo actualizar la lista.'),
      );
    }
  }

  Future<void> deleteBoard(String boardId) async {
    try {
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
        throw AmodoroApiException(
          (body['error'] ?? 'No se pudo eliminar la lista.').toString(),
        );
      }
    } catch (e) {
      throw AmodoroApiException(
        _cleanError(e, 'No se pudo eliminar la lista.'),
      );
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
    String? dueDate,
    String? altText,
  }) async {
    try {
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
              if (dueDate != null) 'dueDate': dueDate,
              if (altText != null) 'altText': altText,
            }),
          )
          .timeout(const Duration(seconds: 20));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 400 || body['ok'] != true) {
        throw AmodoroApiException(
          (body['error'] ?? 'No se pudo agregar el elemento.').toString(),
        );
      }
    } catch (e) {
      throw AmodoroApiException(
        _cleanError(e, 'No se pudo agregar el elemento.'),
      );
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
    String? dueDate,
    String? altText,
  }) async {
    try {
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
              if (dueDate != null) 'dueDate': dueDate,
              if (altText != null) 'altText': altText,
            }),
          )
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 400 || body['ok'] != true) {
        throw AmodoroApiException(
          (body['error'] ?? 'No se pudo actualizar el elemento.').toString(),
        );
      }
    } catch (e) {
      throw AmodoroApiException(
        _cleanError(e, 'No se pudo actualizar el elemento.'),
      );
    }
  }

  Future<void> copyToActividades(String itemId) async {
    try {
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
        throw AmodoroApiException(
          (body['error'] ?? 'No se pudo pasar a Pendientes.').toString(),
        );
      }
    } catch (e) {
      throw AmodoroApiException(
        _cleanError(e, 'No se pudo pasar a Pendientes.'),
      );
    }
  }

  Future<void> completeBoardItem({
    required String itemId,
    String? completionText,
    String? mediaDataUrl,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/boards'),
            headers: _headers(),
            body: jsonEncode({
              'action': 'complete_item',
              'itemId': itemId,
              if (completionText != null) 'completionText': completionText,
              if (mediaDataUrl != null) 'mediaDataUrl': mediaDataUrl,
              if (mediaDataUrl != null) 'imageBase64': mediaDataUrl,
            }),
          )
          .timeout(const Duration(seconds: 20));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 400 || body['ok'] != true) {
        throw AmodoroApiException(
          (body['error'] ?? 'No se pudo completar la actividad.').toString(),
        );
      }
    } catch (e) {
      throw AmodoroApiException(
        _cleanError(e, 'No se pudo completar la actividad.'),
      );
    }
  }

  Future<void> reactToBoardItem({
    required String itemId,
    String? emoji,
    String? presetText,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/boards'),
            headers: _headers(),
            body: jsonEncode({
              'action': 'react_item',
              'itemId': itemId,
              if (emoji != null) 'emoji': emoji,
              if (presetText != null) 'presetText': presetText,
            }),
          )
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 400 || body['ok'] != true) {
        throw AmodoroApiException(
          (body['error'] ?? 'No se pudo enviar la reacción.').toString(),
        );
      }
    } catch (e) {
      throw AmodoroApiException(
        _cleanError(e, 'No se pudo enviar la reacción.'),
      );
    }
  }

  Future<void> reorderBoards(List<String> boardIds) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/boards'),
            headers: _headers(),
            body: jsonEncode({
              'action': 'reorder_boards',
              'boardIds': boardIds,
            }),
          )
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 400 || body['ok'] != true) {
        throw AmodoroApiException(
          (body['error'] ?? 'No se pudo reordenar las listas.').toString(),
        );
      }
    } catch (e) {
      throw AmodoroApiException(
        _cleanError(e, 'No se pudo reordenar las listas.'),
      );
    }
  }

  Future<void> reorderBoardItems(List<String> itemIds) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/boards'),
            headers: _headers(),
            body: jsonEncode({
              'action': 'reorder_items',
              'itemIds': itemIds,
            }),
          )
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 400 || body['ok'] != true) {
        throw AmodoroApiException(
          (body['error'] ?? 'No se pudo reordenar los elementos.').toString(),
        );
      }
    } catch (e) {
      throw AmodoroApiException(
        _cleanError(e, 'No se pudo reordenar los elementos.'),
      );
    }
  }

  Future<void> deleteOrCompleteItem(String itemId) async {
    try {
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
        throw AmodoroApiException(
          (body['error'] ?? 'No se pudo eliminar el elemento.').toString(),
        );
      }
    } catch (e) {
      throw AmodoroApiException(
        _cleanError(e, 'No se pudo eliminar el elemento.'),
      );
    }
  }

  Future<Map<String, dynamic>> spinRoulette() async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/decision'),
            headers: _headers(),
            body: jsonEncode({'action': 'roulette'}),
          )
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 400 || body['ok'] != true) {
        throw AmodoroApiException(
          (body['error'] ?? 'No se pudo girar la ruleta.').toString(),
        );
      }
      return (body['result'] as Map<String, dynamic>?) ?? body;
    } catch (e) {
      throw AmodoroApiException(_cleanError(e, 'No se pudo girar la ruleta.'));
    }
  }

  Future<Map<String, dynamic>> startVoting() async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/decision'),
            headers: _headers(),
            body: jsonEncode({'action': 'start_voting'}),
          )
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 400 || body['ok'] != true) {
        throw AmodoroApiException(
          (body['error'] ?? 'No se pudo iniciar la votación.').toString(),
        );
      }
      return (body['result'] as Map<String, dynamic>?) ?? body;
    } catch (e) {
      throw AmodoroApiException(
        _cleanError(e, 'No se pudo iniciar la votación.'),
      );
    }
  }

  Future<Map<String, dynamic>> submitVotes(
    String sessionId,
    Map<String, bool> votes,
  ) async {
    try {
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
        throw AmodoroApiException(
          (body['error'] ?? 'No se pudieron registrar los votos.').toString(),
        );
      }
      return (body['result'] as Map<String, dynamic>?) ?? body;
    } catch (e) {
      throw AmodoroApiException(
        _cleanError(e, 'No se pudieron registrar los votos.'),
      );
    }
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
    try {
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
        throw AmodoroApiException(
          (body['error'] ?? 'No se pudieron guardar los ajustes.').toString(),
        );
      }
    } catch (e) {
      throw AmodoroApiException(
        _cleanError(e, 'No se pudieron guardar los ajustes.'),
      );
    }
  }

  Future<String> createInviteCode() async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/settings'),
            headers: _headers(),
            body: jsonEncode({'action': 'create_invite'}),
          )
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 400 || body['ok'] != true) {
        throw AmodoroApiException(
          (body['error'] ?? 'No se pudo generar el código.').toString(),
        );
      }
      return (body['code'] ?? '').toString();
    } catch (e) {
      throw AmodoroApiException(
        _cleanError(e, 'No se pudo generar el código.'),
      );
    }
  }

  Future<String> generatePartnerPinResetCode() async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/settings'),
            headers: _headers(),
            body: jsonEncode({'action': 'generate_partner_pin_reset'}),
          )
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 400 || body['ok'] != true) {
        throw AmodoroApiException(
          (body['error'] ?? 'No se pudo generar el código de recuperación.')
              .toString(),
        );
      }
      return (body['code'] ?? '').toString();
    } catch (e) {
      throw AmodoroApiException(
        _cleanError(e, 'No se pudo generar el código de recuperación.'),
      );
    }
  }

  Future<Map<String, dynamic>> exportMyData() async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/settings'),
            headers: _headers(),
            body: jsonEncode({'action': 'export_data'}),
          )
          .timeout(const Duration(seconds: 20));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 400 || body['ok'] != true) {
        throw AmodoroApiException(
          (body['error'] ?? 'No se pudieron exportar tus datos.').toString(),
        );
      }
      return (body['export'] as Map<String, dynamic>?) ?? body;
    } catch (e) {
      throw AmodoroApiException(
        _cleanError(e, 'No se pudieron exportar tus datos.'),
      );
    }
  }

  Future<void> registerFcmToken(String fcmToken) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/settings'),
            headers: _headers(),
            body: jsonEncode({
              'action': 'register_fcm_token',
              'fcmToken': fcmToken,
            }),
          )
          .timeout(const Duration(seconds: 12));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 400 || body['ok'] != true) {
        throw AmodoroApiException(
          (body['error'] ?? 'No se pudo registrar el token de notificaciones.')
              .toString(),
        );
      }
    } catch (_) {
      // Silently ignore push token registration errors when offline
    }
  }
}
