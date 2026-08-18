import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CacheService {
  static final CacheService instance = CacheService._();
  CacheService._();

  /// 返回 Flutter 层缓存占用：
  /// 内存图片缓存（PaintingBinding.imageCache）+ 磁盘缓存目录。
  Future<int> getFlutterCacheSize() async {
    var total = 0;
    try {
      total += PaintingBinding.instance.imageCache.currentSizeBytes;
    } catch (_) {}
    try {
      final directory = await _getCacheDirectory();
      if (directory != null) {
        total += await _directorySize(directory);
      }
    } catch (_) {}
    return total;
  }

  /// 清空 Flutter 层缓存：内存图片缓存 + 磁盘缓存目录内容。
  Future<void> clearFlutterCache() async {
    try {
      final imageCache = PaintingBinding.instance.imageCache;
      imageCache.clear();
      imageCache.clearLiveImages();
    } catch (_) {}
    try {
      final directory = await _getCacheDirectory();
      if (directory != null && await directory.exists()) {
        await _deleteDirectoryContents(directory);
      }
    } catch (_) {}
  }

  Future<Directory?> _getCacheDirectory() async {
    if (kIsWeb) return null;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        return await getTemporaryDirectory();
      }
      final support = await getApplicationSupportDirectory();
      final cacheDir = Directory(p.join(support.path, 'cache'));
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      return cacheDir;
    } catch (_) {
      return null;
    }
  }

  Future<int> _directorySize(Directory dir) async {
    var total = 0;
    if (!await dir.exists()) return 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {}
      }
    }
    return total;
  }

  Future<void> _deleteDirectoryContents(Directory dir) async {
    if (!await dir.exists()) return;
    await for (final entity in dir.list(recursive: false, followLinks: false)) {
      try {
        if (entity is File) {
          await entity.delete();
        } else if (entity is Directory) {
          await entity.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KiB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GiB';
  }
}
