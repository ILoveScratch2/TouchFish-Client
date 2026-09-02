import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/settings_service.dart';
import '../utils/talker.dart';

/// 文件缓存
/// cache = 擦车！
class FileCacheService {
  static FileCacheService? _instance;
  static FileCacheService get instance => _instance ??= FileCacheService._();
  FileCacheService._();

  static const String _cacheKey = 'touchfish_file_cache';

  CacheManager? _cacheManager;
  Future<CacheManager?>? _initFuture;

  /// 默认缓存大小限制（字节）：500MB
  static const int defaultMaxCacheSize = 500 * 1024 * 1024;

  /// 默认缓存对象保留时长：30 天
  static const Duration defaultMaxAge = Duration(days: 30);

  /// 获取缓存大小限制（字节），0 表示无限制
  int get maxCacheSizeBytes =>
      SettingsService.instance.getValue<int>(
        'fileCacheMaxSizeBytes',
        defaultMaxCacheSize,
      );

  /// 是否启用缓存大小限制
  bool get isCacheLimitEnabled => maxCacheSizeBytes > 0;

  /// 设置缓存大小限制（字节），0 表示无限制
  Future<void> setMaxCacheSize(int bytes) async {
    await SettingsService.instance.setValue('fileCacheMaxSizeBytes', bytes);
    await _enforceSizeLimit();
  }

  /// 懒初始化缓存管理器（单例）。web / 无 path_provider 环境下返回 null，
  /// 调用方应回退到默认图片加载路径（浏览器 HTTP 缓存）。
  Future<CacheManager?> _ensureCacheManager() async {
    if (_cacheManager != null) return _cacheManager;
    if (_initFuture != null) return _initFuture;
    if (kIsWeb) return null;

    _initFuture = () async {
      try {
        final maxObjects = 100000;
        final manager = CacheManager(
          Config(
            _cacheKey,
            stalePeriod: defaultMaxAge,
            maxNrOfCacheObjects: maxObjects,
          ),
        );
        _cacheManager = manager;
        talker.info(
          'FileCacheService initialized: '
          'limit=${isCacheLimitEnabled ? _formatBytes(maxCacheSizeBytes) : 'unlimited'} '
          'objects=$maxObjects',
        );
        return manager;
      } catch (e, stack) {
        talker.error('Failed to initialize FileCacheService', e, stack);
        return null;
      }
    }();
    return _initFuture;
  }

  Future<CacheManager?> getCacheManager() => _ensureCacheManager();

  /// 启动预热：初始化缓存管理器并执行容量检查
  Future<void> warmup() async {
    final manager = await _ensureCacheManager();
    if (manager == null) return;
    await _enforceSizeLimit();
  }

  /// 从 URL 获取文件；未命中缓存时自动下载并写入磁盘缓存。
  Future<File?> getFile(String url, {Map<String, String>? headers}) async {
    final manager = await _ensureCacheManager();
    if (manager == null) return null;
    try {
      final file = await manager.getSingleFile(url, headers: headers);
      await _enforceSizeLimit();
      return file;
    } catch (e, stack) {
      talker.error('Failed to get cached file: $url', e, stack);
      return null;
    }
  }

  /// 仅从缓存读取文件（不触发网络请求），离线时用于检测可用性。
  Future<File?> getFileFromCache(String url) async {
    final manager = await _ensureCacheManager();
    if (manager == null) return null;
    try {
      final fileInfo = await manager.getFileFromCache(url);
      return fileInfo?.file;
    } catch (e, stack) {
      talker.error('Failed to read cached file: $url', e, stack);
      return null;
    }
  }

  /// 预下载文件到磁盘缓存（如图片缩略图、自动预览）。
  Future<void> preloadFile(String url, {Map<String, String>? headers}) async {
    final manager = await _ensureCacheManager();
    if (manager == null) return;
    try {
      await manager.downloadFile(url, authHeaders: headers);
      await _enforceSizeLimit();
      talker.debug('Preloaded file into cache: $url');
    } catch (e, stack) {
      talker.error('Failed to preload file: $url', e, stack);
    }
  }

  /// 移除指定 URL 的缓存
  Future<void> removeFile(String url) async {
    final manager = await _ensureCacheManager();
    if (manager == null) return;
    try {
      await manager.removeFile(url);
    } catch (e, stack) {
      talker.error('Failed to remove cached file: $url', e, stack);
    }
  }

  /// 清空全部文件缓存
  Future<void> clearCache() async {
    final manager = await _ensureCacheManager();
    if (manager == null) return;
    try {
      await manager.emptyCache();
      talker.info('FileCacheService: cache cleared');
    } catch (e, stack) {
      talker.error('Failed to clear file cache', e, stack);
    }
  }

  /// 缓存目录（与 flutter_cache_manager 存储位置一致）
  Future<Directory?> _cacheDirectory() async {
    if (kIsWeb) return null;
    try {
      final baseDir = await getTemporaryDirectory();
      return Directory(path.join(baseDir.path, _cacheKey));
    } catch (e, stack) {
      talker.error('Failed to locate cache directory', e, stack);
      return null;
    }
  }

  /// 缓存统计信息
  Future<CacheStats> getCacheStats() async {
    final dir = await _cacheDirectory();
    if (dir == null || !await dir.exists()) {
      return const CacheStats(fileCount: 0, totalSize: 0);
    }
    var fileCount = 0;
    var totalSize = 0;
    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          fileCount++;
          try {
            totalSize += await entity.length();
          } catch (_) {
            // 忽略无法读取的文件
          }
        }
      }
    } catch (e, stack) {
      talker.error('Failed to scan cache directory', e, stack);
    }
    return CacheStats(fileCount: fileCount, totalSize: totalSize);
  }

  /// 字节级容量管理（LRU）：总大小超过限制时，
  /// 按最近访问时间从旧到新删除文件，直到低于限制。
  Future<void> _enforceSizeLimit() async {
    final limit = maxCacheSizeBytes;
    if (limit <= 0) return;
    final manager = _cacheManager;
    if (manager == null) return;

    try {
      final repo = manager.config.repo;
      await repo.open();
      final objects = await repo.getAllObjects();
      final total = objects.fold<int>(0, (sum, o) => sum + (o.length ?? 0));
      if (total <= limit) return;

      final entries = objects
          .map(
            (o) => (
              url: o.url,
              bytes: o.length ?? 0,
              touched: o.touched ?? DateTime(0),
            ),
          )
          .toList();
      final evictions = computeEvictions(entries: entries, limitBytes: limit);
      for (final url in evictions) {
        try {
          await manager.removeFile(url);
        } catch (_) {
          // 单个失败不阻塞整体回收
        }
      }
      if (evictions.isNotEmpty) {
        talker.info(
          'FileCacheService: size limit exceeded, evicted ${evictions.length} '
          'file(s) (${_formatBytes(limit)} limit)',
        );
      }
    } catch (e, stack) {
      talker.error('Failed to enforce cache size limit', e, stack);
    }
  }

  /// 纯函数：给定缓存条目与字节上限，返回应淘汰（LRU，最久未用优先）
  /// 的 URL 列表，使剩余总量不超过 [limitBytes]。返回顺序即淘汰顺序。
  @visibleForTesting
  static List<String> computeEvictions({
    required List<({String url, int bytes, DateTime touched})> entries,
    required int limitBytes,
  }) {
    if (limitBytes <= 0) return const [];
    final sorted = [...entries]..sort(
      (a, b) => a.touched.compareTo(b.touched),
    );
    var total = sorted.fold<int>(0, (sum, e) => sum + e.bytes);
    final evictions = <String>[];
    for (final entry in sorted) {
      if (total <= limitBytes) break;
      total -= entry.bytes;
      evictions.add(entry.url);
    }
    return evictions;
  }

  /// 保存到下载目录（"保存到本地"，不受缓存清理影响）
  Future<File?> saveFilePermanently(
    String url,
    String fileName, {
    Map<String, String>? headers,
  }) async {
    if (kIsWeb) return null;
    try {
      final cachedFile = await getFile(url, headers: headers);
      if (cachedFile == null) return null;

      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null) {
        talker.error('Downloads directory not available');
        return null;
      }

      var target = path.join(downloadsDir.path, fileName);
      if (await File(target).exists()) {
        final ext = path.extension(fileName);
        final stem = path.basenameWithoutExtension(fileName);
        var counter = 1;
        do {
          target = path.join(
            downloadsDir.path,
            '$stem ($counter)$ext',
          );
          counter++;
        } while (await File(target).exists());
      }

      await cachedFile.copy(target);
      talker.info('FileCacheService: saved permanently to $target');
      return File(target);
    } catch (e, stack) {
      talker.error('Failed to save file permanently', e, stack);
      return null;
    }
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}

/// 缓存统计信息
class CacheStats {
  final int fileCount;
  final int totalSize;

  const CacheStats({required this.fileCount, required this.totalSize});

  /// 人类可读的大小
  String get formattedSize {
    if (totalSize < 1024) return '$totalSize B';
    if (totalSize < 1024 * 1024) {
      return '${(totalSize / 1024).toStringAsFixed(1)} KB';
    }
    if (totalSize < 1024 * 1024 * 1024) {
      return '${(totalSize / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(totalSize / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}
