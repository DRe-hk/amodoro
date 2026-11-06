import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/amodoro_models.dart';

/// Función de nivel superior ejecutada en un Isolate secundario mediante [compute]
/// para deserializar el JSON de sincronización sin bloquear el hilo principal de UI.
SyncPayload _parseSyncPayloadIsolate(String jsonString) {
  final map = jsonDecode(jsonString) as Map<String, dynamic>;
  return SyncPayload.fromJson(map, isOffline: true);
}

/// Almacén offline persistente en disco para el payload de sincronización de amodoro.
///
/// Características:
/// - Guarda el JSON completo en un archivo persistente en el sistema de archivos
///   de la app (`getApplicationDocumentsDirectory()`), liberando SharedPreferences.
/// - Deserialización en Isolate secundario con [compute] para eliminar cualquier
///   micro-tirón o congelamiento de frames en la UI.
/// - Gestión de ETag para peticiones condicionales HTTP (`If-None-Match`).
/// - Migración automática y transparente desde versiones anteriores que usaban SharedPreferences.
class OfflineStore {
  static const String _syncFileName = 'amodoro_sync_cache.json';
  static const String _etagFileName = 'amodoro_sync_etag.txt';
  static const String _legacyPrefKey = 'amodoro_cached_sync_json';

  File? _cachedFile;
  File? _cachedEtagFile;
  String? _inMemoryEtag;

  Future<File> _getFile() async {
    if (_cachedFile != null) return _cachedFile!;
    final dir = await getApplicationDocumentsDirectory();
    _cachedFile = File('${dir.path}/$_syncFileName');
    return _cachedFile!;
  }

  Future<File> _getEtagFile() async {
    if (_cachedEtagFile != null) return _cachedEtagFile!;
    final dir = await getApplicationDocumentsDirectory();
    _cachedEtagFile = File('${dir.path}/$_etagFileName');
    return _cachedEtagFile!;
  }

  /// Guarda el JSON de sincronización recibido en disco de forma atómica y actualiza el ETag.
  Future<void> saveSyncJson(String jsonString, {String? etag}) async {
    try {
      final file = await _getFile();
      // Escritura atómica a través de un archivo temporal para evitar corrupción
      final tempFile = File('${file.path}.tmp');
      await tempFile.writeAsString(jsonString, flush: true);
      await tempFile.rename(file.path);

      if (etag != null && etag.isNotEmpty) {
        await setSavedETag(etag);
      }
    } catch (_) {}
  }

  /// Retorna el último ETag guardado para enviar en cabecera `If-None-Match`.
  Future<String?> getSavedETag() async {
    if (_inMemoryEtag != null && _inMemoryEtag!.isNotEmpty) {
      return _inMemoryEtag;
    }
    try {
      final etagFile = await _getEtagFile();
      if (await etagFile.exists()) {
        final content = await etagFile.readAsString();
        _inMemoryEtag = content.trim();
        return _inMemoryEtag;
      }
    } catch (_) {}
    return null;
  }

  /// Guarda el nuevo ETag devuelto por el servidor.
  Future<void> setSavedETag(String etag) async {
    _inMemoryEtag = etag.trim();
    try {
      final etagFile = await _getEtagFile();
      await etagFile.writeAsString(_inMemoryEtag!, flush: true);
    } catch (_) {}
  }

  /// Carga y deserializa el último estado sincronizado desde disco usando [compute].
  /// Si aún no existe archivo en disco, intenta migrar datos previos de SharedPreferences.
  Future<SyncPayload?> loadCachedSync() async {
    try {
      final file = await _getFile();
      String? jsonContent;

      if (await file.exists()) {
        jsonContent = await file.readAsString();
      } else {
        // Migración transparente desde SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final legacyJson = prefs.getString(_legacyPrefKey);
        if (legacyJson != null && legacyJson.isNotEmpty) {
          jsonContent = legacyJson;
          // Guardar en archivo y limpiar SharedPreferences
          await file.writeAsString(legacyJson, flush: true);
          await prefs.remove(_legacyPrefKey);
        }
      }

      if (jsonContent != null && jsonContent.trim().isNotEmpty) {
        // Deserialización fuera del hilo de UI en un Isolate secundario
        final payload = await compute(_parseSyncPayloadIsolate, jsonContent);
        return payload;
      }
    } catch (e) {
      debugPrint('Error al cargar caché offline de sincronización: $e');
    }
    return null;
  }

  /// Elimina los archivos de caché y el ETag local.
  Future<void> clear() async {
    _inMemoryEtag = null;
    try {
      final file = await _getFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
    try {
      final etagFile = await _getEtagFile();
      if (await etagFile.exists()) {
        await etagFile.delete();
      }
    } catch (_) {}
  }
}
