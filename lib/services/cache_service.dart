import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'tdlib_service.dart';

/// TDLib-backed file cache shared by chat avatars and media thumbnails.
class CacheService {
  CacheService._();
  static final CacheService instance = CacheService._();

  final Map<int, Future<String?>> _pathCache = <int, Future<String?>>{};

  int? fileIdFromChat(Map<String, dynamic> chat) {
    final photo = chat['photo'];
    if (photo is! Map) return null;
    final small = photo['small'];
    if (small is! Map) return null;
    final id = small['id'];
    return id is int ? id : int.tryParse(id?.toString() ?? '');
  }

  String? localPathFromChat(Map<String, dynamic> chat) {
    final photo = chat['photo'];
    if (photo is! Map) return null;
    final small = photo['small'];
    if (small is! Map) return null;
    final local = small['local'];
    if (local is Map && local['path'] is String) {
      final path = local['path'] as String;
      if (path.isNotEmpty) return path;
    }
    return null;
  }

  String? imageUrlFromChat(Map<String, dynamic> chat) {
    final photo = chat['photo'];
    if (photo is! Map) return null;
    final small = photo['small'];
    if (small is! Map) return null;
    final remote = small['remote'];
    if (remote is Map && remote['url'] is String) {
      return remote['url'] as String;
    }
    final url = small['url'] ?? small['uri'];
    return url is String ? url : null;
  }

  /// Requests TDLib GetFile and starts a download when the file is not local.
  /// The resolved path is memoized for the lifetime of this service.
  Future<String?> resolveFilePath(int fileId) {
    return _pathCache.putIfAbsent(fileId, () => _loadFilePath(fileId));
  }

  Future<String?> _loadFilePath(int fileId) async {
    if (!TdlibService.instance.isReady) return null;

    Map<String, dynamic> file = await TdlibService.instance.requestRaw({
      '@type': 'getFile',
      'file_id': fileId,
    });

    for (var attempt = 0; attempt < 25; attempt++) {
      final local = file['local'];
      if (local is Map) {
        final path = local['path']?.toString() ?? '';
        final completed = local['is_downloading_completed'] == true;
        if (completed && path.isNotEmpty && await File(path).exists()) {
          return path;
        }
        if (local['is_downloading_active'] != true) {
          try {
            await TdlibService.instance.requestRaw({
              '@type': 'downloadFile',
              'file_id': fileId,
              'priority': 1,
              'offset': 0,
              'limit': 0,
              'synchronous': false,
            });
          } catch (_) {
            // TDLib may report that this file is already being downloaded.
          }
        }
      }

      await Future<void>.delayed(const Duration(milliseconds: 500));
      try {
        file = await TdlibService.instance.requestRaw({
          '@type': 'getFile',
          'file_id': fileId,
        });
      } catch (_) {
        break;
      }
    }
    return null;
  }

  Widget avatar({
    required String fallbackText,
    int? fileId,
    String? imageUrl,
    String? localPath,
    double radius = 27,
  }) {
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (file.existsSync()) {
        return CircleAvatar(radius: radius, backgroundImage: FileImage(file));
      }
    }

    if (fileId != null && fileId > 0) {
      return FutureBuilder<String?>(
        future: resolveFilePath(fileId),
        builder: (context, snapshot) {
          final path = snapshot.data;
          if (path != null && path.isNotEmpty) {
            return CircleAvatar(
              radius: radius,
              backgroundImage: FileImage(File(path)),
            );
          }
          return _networkOrFallback(
            imageUrl,
            fallbackText,
            radius,
          );
        },
      );
    }

    return _networkOrFallback(imageUrl, fallbackText, radius);
  }

  Widget media({
    required int fileId,
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
  }) {
    return FutureBuilder<String?>(
      future: resolveFilePath(fileId),
      builder: (context, snapshot) {
        final path = snapshot.data;
        if (path == null || path.isEmpty) {
          return SizedBox(
            width: width,
            height: height,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        return Image.file(
          File(path),
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
        );
      },
    );
  }

  Widget _networkOrFallback(
    String? imageUrl,
    String text,
    double radius,
  ) {
    final url = imageUrl?.trim() ?? '';
    if (url.startsWith('https://') || url.startsWith('http://')) {
      return CachedNetworkImage(
        imageUrl: url,
        cacheKey: url,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        placeholder: (_, __) => _fallback(text, radius),
        errorWidget: (_, __, ___) => _fallback(text, radius),
        imageBuilder: (_, provider) => CircleAvatar(
          radius: radius,
          backgroundImage: provider,
        ),
      );
    }
    return _fallback(text, radius);
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
}
