import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/settings_service.dart';
import '../utils/talker.dart';

class MediaProxyService {
  static final MediaProxyService instance = MediaProxyService._();
  MediaProxyService._();

  static const _maxCacheBytes = 2 * 1024 * 1024 * 1024;
  HttpServer? _server;
  final HttpClient _client = HttpClient();
  Future<void>? _starting;
  final Map<String, _ChunkCache> _chunkCaches = {};
  final Map<String, Future<void>> _writeChains = {};

  bool get isSupported => true;
  bool get isRunning => _server != null;

  Future<String> resolveUrl(String remoteUrl) async {
    if (!SettingsService.instance.getValue<bool>('mediaProxyEnabled', true)) {
      return remoteUrl;
    }
    try {
      await _ensureStarted();
      final server = _server;
      if (server == null) return remoteUrl;
      return Uri(
        scheme: 'http',
        host: InternetAddress.loopbackIPv4.address,
        port: server.port,
        path: '/media',
        queryParameters: {'url': remoteUrl},
      ).toString();
    } catch (error, stackTrace) {
      talker.error('Media proxy failed to start', error, stackTrace);
      return remoteUrl;
    }
  }

  Future<void> _ensureStarted() async {
    if (_server != null) return;
    final starting = _starting ??= _start();
    try {
      await starting;
    } finally {
      _starting = null;
    }
  }

  Future<void> _start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    unawaited(
      server.forEach((request) async {
        try {
          await _handle(request);
        } catch (error, stackTrace) {
          talker.error('Media proxy request failed', error, stackTrace);
          try {
            request.response.statusCode = HttpStatus.badGateway;
            await request.response.close();
          } catch (_) {}
        }
      }),
    );
  }

  Future<void> _handle(HttpRequest request) async {
    if (request.uri.path == '/health') {
      request.response.write('OK');
      await request.response.close();
      return;
    }
    final rawUrl = request.uri.queryParameters['url'];
    final remoteUri = rawUrl == null ? null : Uri.tryParse(rawUrl);
    if (request.uri.path != '/media' ||
        remoteUri == null ||
        !const {'http', 'https'}.contains(remoteUri.scheme)) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    final range = request.headers.value(HttpHeaders.rangeHeader);
    if (range == null) {
      await _handleFullRequest(request, remoteUri);
    } else {
      await _handleRangeRequest(request, remoteUri, range);
    }
  }

  Future<void> _handleFullRequest(HttpRequest request, Uri remoteUri) async {
    final cacheKey = _cacheKeyFor(remoteUri);
    await _serializeWrite(cacheKey, () async {
      final cache = await _getOrCreateChunkCache(cacheKey);
      if (cache.isComplete && cache.cachedFilePath != null) {
        final file = File(cache.cachedFilePath!);
        if (await file.exists()) {
          final fileSize = await file.length();
          final response = request.response;
          response.headers.contentType = ContentType.parse(
            cache.contentType ?? 'application/octet-stream',
          );
          response.headers.contentLength = fileSize;
          response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
          response.headers.set(
            HttpHeaders.cacheControlHeader,
            'public, max-age=31536000',
          );
          await response.addStream(file.openRead());
          await response.close();
          return;
        }
      }
      await _streamAndCacheFull(request, remoteUri, cacheKey);
    });
  }

  Future<void> _streamAndCacheFull(
    HttpRequest request,
    Uri remoteUri,
    String cacheKey,
  ) async {
    final cache = await _getOrCreateChunkCache(cacheKey);
    final outbound = await _client.openUrl(request.method, remoteUri);
    final remote = await outbound.close();
    final response = request.response;
    response.statusCode = remote.statusCode;
    for (final header in const [
      HttpHeaders.contentTypeHeader,
      HttpHeaders.contentLengthHeader,
      HttpHeaders.contentRangeHeader,
      HttpHeaders.acceptRangesHeader,
      HttpHeaders.etagHeader,
      HttpHeaders.lastModifiedHeader,
    ]) {
      final value = remote.headers.value(header);
      if (value != null) response.headers.set(header, value);
    }

    final shouldCache = remote.statusCode == HttpStatus.ok &&
        remote.contentLength > 0 &&
        remote.contentLength <= _maxCacheBytes &&
        _isMedia(remote.headers.contentType);

    if (!shouldCache) {
      await response.addStream(remote);
      await response.close();
      return;
    }

    final file = File(cache.cachedFilePath!);
    final sink = file.openWrite();
    var receivedLength = 0;
    try {
      await for (final chunk in remote) {
        sink.add(chunk);
        receivedLength += chunk.length;
      }
      await sink.close();
      cache.contentType = remote.headers.contentType?.value;
      cache.totalSize = receivedLength;
      cache.markComplete();
      await _writeMeta(cacheKey, cache);
      unawaited(_trimCache());
    } catch (e) {
      await sink.close();
      talker.error('Media proxy cache full write failed', e);
      try {
        response.statusCode = HttpStatus.internalServerError;
      } catch (_) {}
      await response.close();
      return;
    }

    await response.addStream(File(cache.cachedFilePath!).openRead());
    await response.close();
  }

  Future<void> _handleRangeRequest(
    HttpRequest request,
    Uri remoteUri,
    String rangeHeader,
  ) async {
    final range = _parseRangeHeader(rangeHeader);
    if (range == null) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    final cacheKey = _cacheKeyFor(remoteUri);
    await _serializeWrite(cacheKey, () async {
      final cache = await _getOrCreateChunkCache(cacheKey);
      if (cache.isComplete && cache.cachedFilePath != null) {
        final file = File(cache.cachedFilePath!);
        if (await file.exists()) {
          await _serveSlice(request, cache, file, range);
          return;
        }
      }
      await _fetchRangeAndCache(request, remoteUri, cacheKey, range);
    });
  }

  Future<void> _fetchRangeAndCache(
    HttpRequest request,
    Uri remoteUri,
    String cacheKey,
    _Range range,
  ) async {
    final cache = await _getOrCreateChunkCache(cacheKey);
    final outbound = await _client.openUrl('GET', remoteUri);
    outbound.headers.set(
      HttpHeaders.rangeHeader,
      'bytes=${range.start}-${range.end ?? ""}',
    );
    final remote = await outbound.close();
    final response = request.response;
    response.statusCode = remote.statusCode;
    for (final header in const [
      HttpHeaders.contentTypeHeader,
      HttpHeaders.contentLengthHeader,
      HttpHeaders.contentRangeHeader,
      HttpHeaders.acceptRangesHeader,
      HttpHeaders.etagHeader,
      HttpHeaders.lastModifiedHeader,
    ]) {
      final value = remote.headers.value(header);
      if (value != null) response.headers.set(header, value);
    }

    final contentLength = remote.headers.contentLength;
    final contentRange = remote.headers.value(HttpHeaders.contentRangeHeader);
    final totalSize = _parseContentRangeTotal(contentRange);
    final shouldCache = remote.statusCode == HttpStatus.partialContent &&
        contentLength > 0 &&
        totalSize != null &&
        totalSize > 0 &&
        totalSize <= _maxCacheBytes &&
        _isMedia(remote.headers.contentType) &&
        cache.cachedFilePath != null;

    if (!shouldCache) {
      await response.addStream(remote);
      await response.close();
      return;
    }

    final bodyBytes = <int>[];
    final file = File(cache.cachedFilePath!);
    var shouldCacheThis = true;
    try {
      if (!await file.exists()) {
        await file.create(recursive: true);
        cache.totalSize = totalSize;
      } else if (await file.length() != range.start) {
        // 非连续分块不写入缓存
        shouldCacheThis = false;
      }
      if (shouldCacheThis) {
        final raf = await file.open(mode: FileMode.append);
        try {
          await for (final chunk in remote) {
            await raf.writeFrom(chunk);
            bodyBytes.addAll(chunk);
          }
          cache.contentType = remote.headers.contentType?.value;
          cache.downloadedSize = await raf.length();
          if (cache.downloadedSize >= totalSize) {
            cache.markComplete();
            await _writeMeta(cacheKey, cache);
          }
        } finally {
          await raf.close();
        }
        unawaited(_trimCache());
      }
    } catch (e) {
      talker.error('Media proxy range cache write failed', e);
      shouldCacheThis = false;
    }

    if (shouldCacheThis) {
      response.statusCode = HttpStatus.partialContent;
      response.headers.contentLength = bodyBytes.length;
      if (contentRange != null) {
        response.headers.set(HttpHeaders.contentRangeHeader, contentRange);
      }
      response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      response.add(bodyBytes);
      await response.close();
      return;
    }

    await response.addStream(remote);
    await response.close();
  }

  Future<void> _serveSlice(
    HttpRequest request,
    _ChunkCache cache,
    File file,
    _Range range,
  ) async {
    final fileSize = await file.length();
    final end = (range.end == null || range.end! >= fileSize)
        ? fileSize - 1
        : range.end!;
    if (range.start >= fileSize || range.start > end) {
      request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      request.response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes */$fileSize',
      );
      await request.response.close();
      return;
    }

    final length = end - range.start + 1;
    final raf = await file.open();
    try {
      await raf.setPosition(range.start);
      final bytes = await raf.read(length);
      final response = request.response;
      response.statusCode = HttpStatus.partialContent;
      response.headers.contentType = ContentType.parse(
        cache.contentType ?? 'application/octet-stream',
      );
      response.headers.contentLength = bytes.length;
      response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes ${range.start}-$end/$fileSize',
      );
      response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      response.headers.set(
        HttpHeaders.cacheControlHeader,
        'public, max-age=31536000',
      );
      response.add(bytes);
      await response.close();
    } finally {
      await raf.close();
    }
  }

  _Range? _parseRangeHeader(String header) {
    final match = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(header);
    if (match == null) return null;
    final start = int.parse(match.group(1)!);
    final endStr = match.group(2);
    final end = endStr != null && endStr.isNotEmpty ? int.parse(endStr) : null;
    return _Range(start, end);
  }

  int? _parseContentRangeTotal(String? contentRange) {
    if (contentRange == null) return null;
    final match = RegExp(r'/(\d+)$').firstMatch(contentRange);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  bool _isMedia(ContentType? contentType) {
    if (contentType == null) return false;
    final mime = contentType.mimeType;
    return mime.startsWith('video/') || mime.startsWith('audio/');
  }

  Future<Directory> _cacheDirectory() async {
    final temp = await getTemporaryDirectory();
    final directory = Directory(p.join(temp.path, 'touchfish_media_proxy'));
    await directory.create(recursive: true);
    return directory;
  }

  String _cacheKeyFor(Uri uri) {
    final hash = uri.toString().codeUnits.fold<int>(
      0x811c9dc5,
      (hash, byte) => ((hash ^ byte) * 0x01000193) & 0x7fffffff,
    );
    return hash.toRadixString(16);
  }

  Future<_ChunkCache> _getOrCreateChunkCache(String cacheKey) async {
    final existing = _chunkCaches[cacheKey];
    if (existing != null) return existing;

    final directory = await _cacheDirectory();
    final filePath = p.join(directory.path, '$cacheKey.cache');
    final file = File(filePath);
    final meta = await _readMeta(cacheKey);

    if (meta != null && await file.exists()) {
      final fileSize = await file.length();
      final cache = _ChunkCache(
        cachedFilePath: filePath,
        totalSize: meta.total,
        downloadedSize: fileSize,
        contentType: meta.contentType,
      );
      if (meta.complete && fileSize == meta.total) {
        cache.markComplete();
      } else {
        await file.delete();
        await File(p.join(directory.path, '$cacheKey.meta')).delete();
        _chunkCaches[cacheKey] = _ChunkCache(cachedFilePath: filePath);
        return _chunkCaches[cacheKey]!;
      }
      _chunkCaches[cacheKey] = cache;
      return cache;
    }

    final cache = _ChunkCache(cachedFilePath: filePath);
    _chunkCaches[cacheKey] = cache;
    return cache;
  }

  Future<_MetaInfo?> _readMeta(String cacheKey) async {
    try {
      final directory = await _cacheDirectory();
      final file = File(p.join(directory.path, '$cacheKey.meta'));
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      final total = decoded['total'];
      final complete = decoded['complete'];
      if (total is! int || complete is! bool) return null;
      return _MetaInfo(
        total: total,
        complete: complete,
        contentType: decoded['contentType'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeMeta(String cacheKey, _ChunkCache cache) async {
    try {
      final directory = await _cacheDirectory();
      final file = File(p.join(directory.path, '$cacheKey.meta'));
      await file.writeAsString(
        jsonEncode({
          'total': cache.totalSize,
          'complete': cache.isComplete,
          'contentType': cache.contentType,
        }),
        flush: true,
      );
    } catch (_) {}
  }

  Future<void> _trimCache() async {
    final directory = await _cacheDirectory();
    final files = await directory
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.cache'))
        .cast<File>()
        .toList();
    final entries = <({File file, int size, DateTime modified})>[];
    var total = 0;
    for (final file in files) {
      final stat = await file.stat();
      total += stat.size;
      entries.add((file: file, size: stat.size, modified: stat.modified));
    }
    entries.sort((a, b) => a.modified.compareTo(b.modified));
    for (final entry in entries) {
      if (total <= _maxCacheBytes) break;
      try {
        final meta = File(
          p.join(
            entry.file.parent.path,
            '${p.basenameWithoutExtension(entry.file.path)}.meta',
          ),
        );
        if (await meta.exists()) await meta.delete();
      } catch (_) {}
      try {
        await entry.file.delete();
      } catch (_) {}
      total -= entry.size;
    }
  }

  Future<void> _serializeWrite(
    String key,
    Future<void> Function() task,
  ) async {
    final previous = _writeChains[key];
    final chained = (previous ?? Future<void>.value())
        .then((_) => task())
        .onError((error, stackTrace) {
      talker.error('Media proxy cache write failed', error, stackTrace);
    });
    _writeChains[key] = chained;
    try {
      await chained;
    } finally {
      if (identical(_writeChains[key], chained)) {
        _writeChains.remove(key);
      }
    }
  }

  Future<int> cacheSize() async {
    final directory = await _cacheDirectory();
    var total = 0;
    await for (final entity in directory.list()) {
      if (entity is File && entity.path.endsWith('.cache')) {
        total += await entity.length();
      }
    }
    return total;
  }

  Future<void> clearCache() async {
    _chunkCaches.clear();
    _writeChains.clear();
    final directory = await _cacheDirectory();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _chunkCaches.clear();
    _writeChains.clear();
    await server?.close(force: true);
  }
}

class _ChunkCache {
  final String? cachedFilePath;
  int totalSize;
  int downloadedSize;
  String? contentType;
  bool _isComplete;

  _ChunkCache({
    this.cachedFilePath,
    this.totalSize = 0,
    this.downloadedSize = 0,
    this.contentType,
  }) : _isComplete = false;

  bool get isComplete => _isComplete;

  void markComplete() {
    _isComplete = true;
    downloadedSize = totalSize;
  }
}

class _Range {
  final int start;
  final int? end;

  _Range(this.start, this.end);
}

class _MetaInfo {
  final int total;
  final bool complete;
  final String? contentType;

  _MetaInfo({required this.total, required this.complete, this.contentType});
}
