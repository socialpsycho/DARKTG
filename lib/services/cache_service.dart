import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Shared image cache for remote thumbnails used by DARKTG UI.
/// TDLib file paths are rendered from their local file path; URLs use
/// CachedNetworkImage's persistent disk cache.
class CacheService {
  CacheService._();
  static final CacheService instance = CacheService._();

  Widget avatar({
    required String? imageUrl,
    String? localPath,
    required String fallbackText,
    double radius = 27,
  }) {
    final path = localPath;
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        return CircleAvatar(
          radius: radius,
          backgroundImage: FileImage(file),
        );
      }
    }

    final url = imageUrl?.trim() ?? '';
    if (url.startsWith('https://') || url.startsWith('http://')) {
      return CachedNetworkImage(
        imageUrl: url,
        cacheKey: url,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 120),
        placeholder: (_, __) => _fallback(fallbackText, radius),
        errorWidget: (_, __, ___) => _fallback(fallbackText, radius),
        imageBuilder: (context, provider) => CircleAvatar(
          radius: radius,
          backgroundImage: provider,
        ),
      );
    }
    return _fallback(fallbackText, radius);
  }

  Widget _fallback(String text, double radius) => CircleAvatar(
    radius: radius,
    backgroundColor: const Color(0xFF229ED9).withValues(alpha: .18),
    child: Text(
      text.isNotEmpty ? text.characters.first.toUpperCase() : 'D',
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  String? imageUrlFromChat(Map<String, dynamic> chat) {
    final photo = chat['photo'];
    if (photo is! Map) return null;
    final small = photo['small'];
    if (small is Map) {
      final url = small['url'] ?? small['uri'];
      if (url is String) return url;
      final remote = small['remote'];
      if (remote is Map && remote['url'] is String) {
        return remote['url'] as String;
      }
    }
    return null;
  }

  String? localPathFromChat(Map<String, dynamic> chat) {
    final photo = chat['photo'];
    if (photo is! Map) return null;
    final small = photo['small'];
    if (small is Map) {
      final local = small['local'];
      if (local is Map && local['path'] is String) {
        final path = local['path'] as String;
        if (path.isNotEmpty) return path;
      }
    }
    return null;
  }
}
