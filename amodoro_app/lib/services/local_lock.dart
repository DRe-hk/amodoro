import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Servicio de seguridad, identidad de dispositivo y bloqueo local por PIN.
///
/// Gestiona:
/// - Generación y persistencia de `deviceId` (UUID v4) y `deviceName`.
/// - Hashing de PIN de alta seguridad mediante PBKDF2-HMAC-SHA256 con salt de 16 bytes
///   y 50.000 iteraciones usando el paquete `crypto`.
/// - Sincronización de versión de PIN (`pinVersion`).
/// - Bloqueo escalonado persistente en `FlutterSecureStorage` ante intentos fallidos.
class LocalLockService {
  static const String _keyDeviceId = 'amodoro_device_id';
  static const String _keyDeviceName = 'amodoro_device_name';
  static const String _keyPinSalt = 'amodoro_pin_salt';
  static const String _keyPinHash = 'amodoro_pin_hash';
  static const String _keyPinVersion = 'amodoro_pin_version';
  static const String _keyFailedAttempts = 'amodoro_lock_failed_attempts';
  static const String _keyLockoutUntil = 'amodoro_lockout_until';

  static const int _pbkdf2Iterations = 50000;
  static const int _keyLengthBytes = 32; // 256 bits

  final FlutterSecureStorage _storage;

  LocalLockService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  String? _cachedDeviceId;
  String? _cachedDeviceName;

  /// Inicializa y asegura que `deviceId` y `deviceName` estén configurados.
  Future<void> init() async {
    await getDeviceId();
    await getDeviceName();
  }

  /// Retorna o genera un UUID v4 persistente para identificar este dispositivo.
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    try {
      final existing = await _storage.read(key: _keyDeviceId);
      if (existing != null && existing.trim().isNotEmpty) {
        _cachedDeviceId = existing.trim();
        return _cachedDeviceId!;
      }
    } catch (_) {}

    final newId = _generateUuidV4();
    try {
      await _storage.write(key: _keyDeviceId, value: newId);
    } catch (_) {}
    _cachedDeviceId = newId;
    return newId;
  }

  /// Retorna o establece el nombre descriptivo del dispositivo (ej. "Android").
  Future<String> getDeviceName() async {
    if (_cachedDeviceName != null) return _cachedDeviceName!;
    try {
      final existing = await _storage.read(key: _keyDeviceName);
      if (existing != null && existing.trim().isNotEmpty) {
        _cachedDeviceName = existing.trim();
        return _cachedDeviceName!;
      }
    } catch (_) {}

    String name = 'Android';
    try {
      if (Platform.isIOS) {
        name = 'iPhone';
      } else if (Platform.isLinux) {
        name = 'Linux';
      } else if (Platform.isMacOS) {
        name = 'Mac';
      } else if (Platform.isWindows) {
        name = 'Windows';
      }
    } catch (_) {}

    try {
      await _storage.write(key: _keyDeviceName, value: name);
    } catch (_) {}
    _cachedDeviceName = name;
    return name;
  }

  /// Indica si el PIN local está configurado en el almacenamiento seguro.
  Future<bool> isPinConfigured() async {
    try {
      final hash = await _storage.read(key: _keyPinHash);
      final salt = await _storage.read(key: _keyPinSalt);
      return hash != null &&
          hash.isNotEmpty &&
          salt != null &&
          salt.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Obtiene los segundos restantes de bloqueo escalonado (0 si no está bloqueado).
  Future<int> getRemainingLockoutSeconds() async {
    try {
      final rawUntil = await _storage.read(key: _keyLockoutUntil);
      if (rawUntil == null || rawUntil.isEmpty) return 0;
      final untilMs = int.tryParse(rawUntil) ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (untilMs <= nowMs) {
        return 0;
      }
      return ((untilMs - nowMs) / 1000).ceil();
    } catch (_) {
      return 0;
    }
  }

  /// Guarda y cifra el PIN local junto a su versión con PBKDF2-HMAC-SHA256.
  Future<void> saveLocalPin(String pin, int pinVersion) async {
    final cleanPin = pin.trim();
    if (cleanPin.isEmpty) {
      throw ArgumentError('El PIN no puede estar vacío');
    }

    final saltBytes = _generateRandomSalt(16);
    final hashBytes = _pbkdf2HmacSha256(
      password: utf8.encode(cleanPin),
      salt: saltBytes,
      iterations: _pbkdf2Iterations,
      keyLength: _keyLengthBytes,
    );

    final saltHex = _bytesToHex(saltBytes);
    final hashHex = _bytesToHex(hashBytes);

    await _storage.write(key: _keyPinSalt, value: saltHex);
    await _storage.write(key: _keyPinHash, value: hashHex);
    await _storage.write(key: _keyPinVersion, value: pinVersion.toString());

    await _resetLockout();
  }

  /// Verifica si el PIN introducido coincide con el hash local guardado.
  /// Si está bloqueado por intentos fallidos, retorna `false`.
  Future<bool> verifyLocalPin(String pin) async {
    final remainingLockout = await getRemainingLockoutSeconds();
    if (remainingLockout > 0) {
      return false;
    }

    final savedHash = await _storage.read(key: _keyPinHash);
    final savedSalt = await _storage.read(key: _keyPinSalt);
    if (savedHash == null ||
        savedHash.isEmpty ||
        savedSalt == null ||
        savedSalt.isEmpty) {
      return false;
    }

    final saltBytes = _hexToBytes(savedSalt);
    final candidateHashBytes = _pbkdf2HmacSha256(
      password: utf8.encode(pin.trim()),
      salt: saltBytes,
      iterations: _pbkdf2Iterations,
      keyLength: _keyLengthBytes,
    );
    final candidateHashHex = _bytesToHex(candidateHashBytes);

    // Comparación segura en tiempo constante
    final bool match = _constantTimeEquals(candidateHashHex, savedHash);
    if (match) {
      await _resetLockout();
      return true;
    } else {
      await _recordFailedAttempt();
      return false;
    }
  }

  /// Retorna la versión del PIN local guardada.
  Future<int> getPinVersion() async {
    try {
      final raw = await _storage.read(key: _keyPinVersion);
      return int.tryParse(raw ?? '1') ?? 1;
    } catch (_) {
      return 1;
    }
  }

  /// Actualiza la versión del PIN local.
  Future<void> setPinVersion(int version) async {
    await _storage.write(key: _keyPinVersion, value: version.toString());
  }

  /// Elimina la configuración del PIN local.
  Future<void> clearPin() async {
    await _storage.delete(key: _keyPinHash);
    await _storage.delete(key: _keyPinSalt);
    await _storage.delete(key: _keyPinVersion);
    await _resetLockout();
  }

  // --- Lógica interna de bloqueo escalonado ---

  Future<void> _recordFailedAttempt() async {
    int attempts = 0;
    try {
      final raw = await _storage.read(key: _keyFailedAttempts);
      attempts = int.tryParse(raw ?? '0') ?? 0;
    } catch (_) {}

    attempts++;
    await _storage.write(key: _keyFailedAttempts, value: attempts.toString());

    int lockoutSeconds = 0;
    if (attempts >= 8) {
      lockoutSeconds = 900; // 15 minutos
    } else if (attempts == 7) {
      lockoutSeconds = 300; // 5 minutos
    } else if (attempts == 6) {
      lockoutSeconds = 120; // 2 minutos
    } else if (attempts == 5) {
      lockoutSeconds = 30; // 30 segundos
    }

    if (lockoutSeconds > 0) {
      final lockoutUntil =
          DateTime.now().millisecondsSinceEpoch + (lockoutSeconds * 1000);
      await _storage.write(
        key: _keyLockoutUntil,
        value: lockoutUntil.toString(),
      );
    }
  }

  Future<void> _resetLockout() async {
    try {
      await _storage.delete(key: _keyFailedAttempts);
      await _storage.delete(key: _keyLockoutUntil);
    } catch (_) {}
  }

  // --- Criptografía PBKDF2-HMAC-SHA256 pura en Dart ---

  static Uint8List _pbkdf2HmacSha256({
    required List<int> password,
    required Uint8List salt,
    required int iterations,
    required int keyLength,
  }) {
    final hmac = Hmac(sha256, password);
    const int hmacLen = 32; // SHA-256 genera bloques de 32 bytes
    final int blocksNeeded = (keyLength + hmacLen - 1) ~/ hmacLen;
    final Uint8List result = Uint8List(blocksNeeded * hmacLen);

    for (int block = 1; block <= blocksNeeded; block++) {
      // S || INT_32_BE(block)
      final Uint8List blockInput = Uint8List(salt.length + 4);
      blockInput.setRange(0, salt.length, salt);
      final ByteData byteData = ByteData.sublistView(blockInput, salt.length);
      byteData.setUint32(0, block, Endian.big);

      List<int> u = hmac.convert(blockInput).bytes;
      final Uint8List t = Uint8List.fromList(u);

      for (int iter = 1; iter < iterations; iter++) {
        u = hmac.convert(u).bytes;
        for (int k = 0; k < hmacLen; k++) {
          t[k] ^= u[k];
        }
      }

      result.setRange((block - 1) * hmacLen, block * hmacLen, t);
    }

    return result.sublist(0, keyLength);
  }

  static Uint8List _generateRandomSalt([int length = 16]) {
    final rnd = Random.secure();
    final salt = Uint8List(length);
    for (int i = 0; i < length; i++) {
      salt[i] = rnd.nextInt(256);
    }
    return salt;
  }

  static String _generateUuidV4() {
    final rnd = Random.secure();
    final bytes = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      bytes[i] = rnd.nextInt(256);
    }
    // RFC 4122 versión 4 (0100)
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // RFC 4122 variante (10xx)
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = _bytesToHex(bytes);
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  static String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Uint8List _hexToBytes(String hex) {
    final clean = hex.trim();
    final result = Uint8List(clean.length ~/ 2);
    for (int i = 0; i < result.length; i++) {
      result[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
