import 'dart:async';
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
          request.response.statusCode = HttpStatus.badGateway;
          await request.response.close();
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
    final cacheFile = await _cacheFileFor(remoteUri);
    if (range == null && await cacheFile.exists()) {
      request.response.headers.contentLength = await cacheFile.length();
      request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      await request.response.addStream(cacheFile.openRead());
      await request.response.close();
      return;
    }

    final outbound = await _client.openUrl(request.method, remoteUri);
    if (range != null) outbound.headers.set(HttpHeaders.rangeHeader, range);
    final remote = await outbound.close();
    request.response.statusCode = remote.statusCode;
    for (final header in const [
      HttpHeaders.contentTypeHeader,
      HttpHeaders.contentLengthHeader,
      HttpHeaders.contentRangeHeader,
      HttpHeaders.acceptRangesHeader,
      HttpHeaders.etagHeader,
      HttpHeaders.lastModifiedHeader,
    ]) {
      final value = remote.headers.value(header);
      if (value != null) request.response.headers.set(header, value);
    }

    if (range == null &&
        remote.statusCode == HttpStatus.ok &&
        remote.contentLength > 0 &&
        remote.contentLength <= _maxCacheBytes) {
      final sink = cacheFile.openWrite();
      await for (final chunk in remote) {
        request.response.add(chunk);
        sink.add(chunk);
      }
      await sink.close();
      await _trimCache();
    } else {
      await request.response.addStream(remote);
    }
    await request.response.close();
  }

  Future<Directory> _cacheDirectory() async {
    final temp = await getTemporaryDirectory();
    final directory = Directory(p.join(temp.path, 'touchfish_media_proxy'));
    await directory.create(recursive: true);
    return directory;
  }

  Future<File> _cacheFileFor(Uri uri) async {
    final directory = await _cacheDirectory();
    final key = uri.toString().codeUnits.fold<int>(
      0x811c9dc5,
      (hash, byte) => ((hash ^ byte) * 0x01000193) & 0x7fffffff,
    );
    return File(p.join(directory.path, '$key.cache'));
  }

  Future<void> _trimCache() async {
    final directory = await _cacheDirectory();
    final files = await directory
        .list()
        .where((entity) => entity is File)
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
      await entry.file.delete();
      total -= entry.size;
    }
  }

  Future<int> cacheSize() async {
    final directory = await _cacheDirectory();
    var total = 0;
    await for (final entity in directory.list()) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  Future<void> clearCache() async {
    final directory = await _cacheDirectory();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }
}
