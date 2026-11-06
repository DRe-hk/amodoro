import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Componente unificado y optimizado de imagen para amodoro.
///
/// Características principales:
/// - Basado en [CachedNetworkImage] con almacenamiento local en disco y memoria.
/// - Inyección automática y persistente de la cabecera `Authorization: Bearer <token>`.
/// - Adaptación inteligente de `memCacheWidth` y `memCacheHeight` según el tamaño
///   de visualización para no saturar memoria RAM ni GPU con resoluciones excesivas.
/// - `fadeInDuration: Duration.zero` para evitar transiciones con parpadeo y mantener
///   paridad visual idéntica con el anterior `Image.network`.
/// - Decodificación directa y fluida de URIs `data:image/...;base64,...` y archivos locales.
/// - Fallbacks y placeholders configurables idénticos al comportamiento original.
class AmodoroImage extends StatelessWidget {
  /// Token global persistente para peticiones de imágenes autenticadas.
  static String? defaultAuthToken;

  /// URL de la imagen (remota http/https, base64 data:, o archivo local).
  final String imageUrl;

  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final Widget? placeholderWidget;
  final Widget? errorPlaceholder;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;
  final Map<String, String>? httpHeaders;
  final String? token;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final Color? color;
  final BlendMode? colorBlendMode;

  const AmodoroImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.placeholderWidget,
    this.errorPlaceholder,
    this.placeholder,
    this.errorWidget,
    this.httpHeaders,
    this.token,
    this.memCacheWidth,
    this.memCacheHeight,
    this.color,
    this.colorBlendMode,
  });

  /// Configura el token de autenticación global usado por las instancias de [AmodoroImage].
  static void setAuthToken(String? token) {
    defaultAuthToken = token;
  }

  @override
  Widget build(BuildContext context) {
    final cleanUrl = imageUrl.trim();
    if (cleanUrl.isEmpty) {
      return errorPlaceholder ?? const SizedBox.shrink();
    }

    // 1. Manejo de URLs embebidas base64 (data:image/...)
    if (cleanUrl.startsWith('data:image/')) {
      final commaIndex = cleanUrl.indexOf(',');
      if (commaIndex != -1) {
        try {
          final bytes = base64Decode(cleanUrl.substring(commaIndex + 1));
          return Image.memory(
            bytes,
            width: width,
            height: height,
            fit: fit,
            alignment: alignment,
            color: color,
            colorBlendMode: colorBlendMode,
            errorBuilder: (_, __, ___) =>
                errorPlaceholder ?? const SizedBox.shrink(),
          );
        } catch (_) {
          return errorPlaceholder ?? const SizedBox.shrink();
        }
      }
    }

    // 2. Manejo de archivos locales (file:// o ruta absoluta en disco)
    if (cleanUrl.startsWith('file://')) {
      return Image.file(
        File(cleanUrl.replaceFirst('file://', '')),
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        color: color,
        colorBlendMode: colorBlendMode,
        errorBuilder: (_, __, ___) =>
            errorPlaceholder ?? const SizedBox.shrink(),
      );
    } else if (cleanUrl.startsWith('/data/') || cleanUrl.startsWith('/storage/')) {
      return Image.file(
        File(cleanUrl),
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        color: color,
        colorBlendMode: colorBlendMode,
        errorBuilder: (_, __, ___) =>
            errorPlaceholder ?? const SizedBox.shrink(),
      );
    }

    // 3. Resolución de cabeceras de autorización
    final effectiveToken = token ?? defaultAuthToken;
    final headers = <String, String>{};
    if (httpHeaders != null) {
      headers.addAll(httpHeaders!);
    }
    if (effectiveToken != null &&
        effectiveToken.isNotEmpty &&
        !headers.containsKey('Authorization')) {
      headers['Authorization'] = 'Bearer $effectiveToken';
    }

    // 4. Adaptación del tamaño de caché en memoria (memCacheWidth / memCacheHeight)
    // Para miniaturas y vistas normales, evita decodificar resoluciones enormes a 4K en GPU.
    int? resolvedMemWidth = memCacheWidth;
    int? resolvedMemHeight = memCacheHeight;

    if (resolvedMemWidth == null && width != null && width!.isFinite && width! > 0) {
      resolvedMemWidth = (width! * 2.0).round();
    }
    if (resolvedMemHeight == null && height != null && height!.isFinite && height! > 0) {
      resolvedMemHeight = (height! * 2.0).round();
    }

    // 5. Renderizado con CachedNetworkImage
    return CachedNetworkImage(
      imageUrl: cleanUrl,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      httpHeaders: headers.isNotEmpty ? headers : null,
      memCacheWidth: resolvedMemWidth,
      memCacheHeight: resolvedMemHeight,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      color: color,
      colorBlendMode: colorBlendMode,
      placeholder: placeholder ??
          (placeholderWidget != null ? (_, __) => placeholderWidget! : null),
      errorWidget: errorWidget ??
          (_, __, ___) => errorPlaceholder ?? const SizedBox.shrink(),
    );
  }
}
