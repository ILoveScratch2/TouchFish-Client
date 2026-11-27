import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/settings_service.dart';
import '../utils/talker.dart';

const _defaultFreshnessMs = 3600 * 1000;

class MediaProxyService {
  static final MediaProxyService instance = MediaProxyService._();
  MediaProxyService._();

  static const _maxCacheBytes = 2 * 1024 * 1024 * 1024;
  static const _timeout = Duration(seconds: 60);
  static final _rangePattern = RegExp(r'^bytes=(\d+)-(\d*)$');
  static final _contentRangePattern = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$');
  static final _secure = Random.secure();

  HttpServer? _server;
  Hmac? _signer;
  HttpClient _client = _newClient();
  Future<void>? _starting;
  final _writers = <String, _CacheWriter>{};
  Future<void>? _clearing;
  Future<void>? _trimming;
  bool _trimAgain = false;
  int _generation = 0;

  bool get isSupported => true;
  bool get isRunning => _server != null;

  static HttpClient _newClient() => HttpClient()
    ..connectionTimeout = const Duration(seconds: 30)
    ..autoUncompress = false;

  void rebuildHttpClient() {
    _client.close(force: true);
    _client = _newClient();
  }

  Future<String> resolveUrl(String remoteUrl) async {
    if (!SettingsService.instance.getValue<bool>('mediaProxyEnabled', true)) {
      return remoteUrl;
    }
    final uri = Uri.tryParse(remoteUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        !{'http', 'https'}.contains(uri.scheme)) {
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
        queryParameters: {'url': remoteUrl, 'sig': _signature(remoteUrl)},
      ).toString();
    } catch (error, stackTrace) {
      talker.error('Media proxy failed to start', error, stackTrace);
      return remoteUrl;
    }
  }

  String _signature(String url) =>
      _signer!.convert(utf8.encode(url)).toString();

  bool _accepts(String url, String? signature) {
    if (_signer == null || signature == null || signature.length != 64) {
      return false;
    }
    final expected = _signature(url);
    var difference = 0;
    for (var i = 0; i < expected.length; i++) {
      difference |= expected.codeUnitAt(i) ^ signature.codeUnitAt(i);
    }
    return difference == 0;
  }

  Future<void> _ensureStarted() async {
    if (_server != null) return;
    await (_starting ??= _start().whenComplete(() => _starting = null));
  }

  Future<void> _start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _signer = Hmac(sha256, List.generate(32, (_) => _secure.nextInt(256)));
    _server = server;
    server.listen(
      (request) => unawaited(_handle(request)),
      onError: (Object error) {
        talker.error('Media proxy listener error', error);
      },
    );
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    response.headers.set('X-Content-Type-Options', 'nosniff');
    response.headers.set('Referrer-Policy', 'no-referrer');
    response.headers.set(
      'Content-Security-Policy',
      "sandbox; default-src 'none'",
    );
    response.headers.set(HttpHeaders.cacheControlHeader, 'private, no-store');
    try {
      if (request.uri.path == '/health') {
        response.write('OK');
        return;
      }
      final raw = request.uri.queryParameters['url'];
      if (request.uri.path != '/media' || raw == null) {
        response.statusCode = HttpStatus.badRequest;
        return;
      }
      if (!_accepts(raw, request.uri.queryParameters['sig'])) {
        response.statusCode = HttpStatus.forbidden;
        return;
      }
      final method = request.method;
      if (method != 'GET' && method != 'HEAD') {
        response.statusCode = HttpStatus.methodNotAllowed;
        response.headers.set('Allow', 'GET, HEAD');
        return;
      }
      final header = request.headers.value(HttpHeaders.rangeHeader);
      final match = header == null ? null : _rangePattern.firstMatch(header);
      final start = match == null ? null : int.tryParse(match[1]!);
      final end = match == null ? null : int.tryParse(match[2]!);
      if (header != null &&
          (match == null ||
              start == null ||
              (match[2]!.isNotEmpty && (end == null || end < start)))) {
        response.statusCode = HttpStatus.badRequest;
        return;
      }

      final generation = _generation;
      final key = sha256.convert(utf8.encode(raw)).toString();
      File? file;
      _CacheEntry? entry;
      try {
        final directory = await _cacheDirectory();
        file = File(p.join(directory.path, '$key.cache'));
        entry = await _readEntry(file);
      } on Exception {
        file = null;
      }
      if (file != null &&
          entry != null &&
          entry.complete &&
          await _serveCached(request, file, entry, start, end)) {
        return;
      }
      final outbound = await _client
          .openUrl(method, Uri.parse(raw))
          .timeout(_timeout);
      outbound.followRedirects = false;
      outbound.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      if (header != null) outbound.headers.set(HttpHeaders.rangeHeader, header);
      final remote = await outbound.close().timeout(
        _timeout,
        onTimeout: () {
          outbound.abort();
          throw TimeoutException('Media response headers timed out');
        },
      );
      response.statusCode = remote.statusCode;
      for (final name in const [
        HttpHeaders.contentTypeHeader,
        HttpHeaders.contentLengthHeader,
        HttpHeaders.contentRangeHeader,
        HttpHeaders.acceptRangesHeader,
        HttpHeaders.contentEncodingHeader,
        HttpHeaders.etagHeader,
        HttpHeaders.lastModifiedHeader,
        HttpHeaders.locationHeader,
      ]) {
        final value = remote.headers.value(name);
        if (value != null) {
          response.headers.set(
            name,
            name == HttpHeaders.locationHeader
                ? Uri.parse(raw).resolve(value).toString()
                : value,
          );
        }
      }

      final body = remote.timeout(_timeout);
      _CacheEntry? candidate;
      try {
        candidate = _CacheEntry.fromResponse(remote, start, end);
      } on Exception catch (_) {
      }
      final segment = candidate;
      if (method != 'GET' ||
          file == null ||
          segment == null ||
          generation != _generation ||
          _writers.containsKey(key) ||
          _clearing != null) {
        await response.addStream(body);
        return;
      }
      final writer = _CacheWriter();
      _writers[key] = writer;
      try {
        await writer.perform(() async {
          if (start == 0) {
            final current = await _readEntry(file!);
            if (current != null &&
                current.complete &&
                await file.exists() &&
                await file.length() == current.total) {
              return;
            }
            await _deleteIfPresent(File('${file.path}.meta'));
            await _deleteIfPresent(file);
            writer.handle = await file.open(mode: FileMode.write);
          } else {
            final prefix = await _readEntry(file!);
            if (prefix != null &&
                !prefix.complete &&
                segment.validator != null &&
                prefix.validator == segment.validator &&
                prefix.total == segment.total &&
                await file.length() == start) {
              writer.handle = await file.open(mode: FileMode.append);
            }
          }
        });
        if (writer.handle == null) {
          _writers.remove(key);
          await response.addStream(body);
          return;
        }
        var written = 0;
        await response.addStream(
          body.asyncMap((chunk) async {
            await writer.perform(() async {
              await writer.handle!.writeFrom(chunk);
              written += chunk.length;
            });
            return chunk;
          }),
        );
        await writer.perform(() async {
          await writer.closeHandle();
          if (written != remote.contentLength) return;
          final complete = start! + written == segment.total;
          await File('${file!.path}.meta').writeAsString(
            jsonEncode({
              'expires': segment.expires,
              'total': segment.total,
              'complete': complete,
              'validator': segment.validator,
              'contentType': segment.contentType,
            }),
            flush: true,
          );
        });
      } finally {
        await writer.cancel();
        if (identical(_writers[key], writer)) {
          _writers.remove(key);
          _scheduleTrim();
        }
      }
    } catch (error) {
      talker.debug('Media proxy request failed (${error.runtimeType})');
      try {
        response.statusCode = HttpStatus.badGateway;
      } catch (_) {}
    } finally {
      try {
        await response.close();
      } catch (_) {}
    }
  }

  Future<bool> _serveCached(
    HttpRequest request,
    File file,
    _CacheEntry entry,
    int? start,
    int? end,
  ) async {
    late final RandomAccessFile reader;
    try {
      reader = await file.open();
    } on FileSystemException {
      return false;
    }
    try {
      if (await reader.length() != entry.total) return false;
      final response = request.response;
      final first = start ?? 0;
      final last = min(end ?? entry.total - 1, entry.total - 1);
      if (first > last) {
        response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes */${entry.total}',
        );
        return true;
      }
      if (start != null) {
        response.statusCode = HttpStatus.partialContent;
        response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $first-$last/${entry.total}',
        );
      }
      response.headers.contentType = ContentType.parse(entry.contentType);
      response.headers.contentLength = last - first + 1;
      response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      if (request.method != 'HEAD') {
        await reader.setPosition(first);
        await response.addStream(_readBytes(reader, last - first + 1));
      }
      return true;
    } finally {
      await reader.close();
    }
  }

  static Stream<List<int>> _readBytes(
    RandomAccessFile file,
    int remaining,
  ) async* {
    while (remaining > 0) {
      final data = await file.read(min(64 * 1024, remaining));
      if (data.isEmpty) {
        throw const FileSystemException('Cached media ended early');
      }
      remaining -= data.length;
      yield data;
    }
  }

  Future<Directory> _cacheDirectory() async {
    final temp = await getTemporaryDirectory();
    final directory = Directory(p.join(temp.path, 'touchfish_media_proxy'));
    await directory.create(recursive: true);
    return directory;
  }

  Future<_CacheEntry?> _readEntry(File file) async {
    try {
      final data = jsonDecode(await File('${file.path}.meta').readAsString());
      if (data is Map &&
          data['total'] is int &&
          data['total'] > 0 &&
          data['expires'] is int &&
          data['expires'] > DateTime.now().millisecondsSinceEpoch &&
          data['complete'] is bool &&
          data['contentType'] is String &&
          (data['validator'] == null || data['validator'] is String)) {
        return _CacheEntry(
          data['total'],
          data['complete'],
          data['contentType'],
          data['validator'],
          data['expires'],
        );
      }
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
    return null;
  }

  static Future<void> _deleteIfPresent(File file) async {
    if (await file.exists()) await file.delete();
  }

  void _scheduleTrim() {
    if (_clearing != null) return;
    _trimAgain = true;
    _trimming ??= _trimCache().whenComplete(() => _trimming = null);
  }

  Future<void> _trimCache() async {
    try {
      while (_trimAgain && _clearing == null) {
        _trimAgain = false;
        final directory = await _cacheDirectory();
        final entries = <({File file, int size, DateTime modified})>[];
        var total = 0;
        await for (final file
            in directory
                .list()
                .where((f) => f is File && f.path.endsWith('.cache'))
                .cast<File>()) {
          final stat = await file.stat();
          if (stat.type != FileSystemEntityType.file) continue;
          entries.add((file: file, size: stat.size, modified: stat.modified));
          total += stat.size;
        }
        if (total <= _maxCacheBytes) continue;
        entries.sort((a, b) => a.modified.compareTo(b.modified));
        for (final entry in entries) {
          if (total <= _maxCacheBytes) break;
          final key = p.basenameWithoutExtension(entry.file.path);
          if (_writers.containsKey(key)) continue;
          final reservation = _CacheWriter();
          _writers[key] = reservation;
          try {
            await _deleteIfPresent(File('${entry.file.path}.meta'));
            await _deleteIfPresent(
              File(p.setExtension(entry.file.path, '.meta')),
            );
            await _deleteIfPresent(entry.file);
            total -= entry.size;
          } finally {
            _writers.remove(key);
          }
        }
      }
    } on FileSystemException catch (error) {
      talker.debug('Media cache maintenance failed (${error.runtimeType})');
    }
  }

  Future<int> cacheSize() async {
    final directory = await _cacheDirectory();
    var total = 0;
    await for (final entry in directory.list()) {
      if (entry is File && entry.path.endsWith('.cache')) {
        total += max(0, (await entry.stat()).size);
      }
    }
    return total;
  }

  Future<void> clearCache() =>
      _clearing ??= _clear().whenComplete(() => _clearing = null);

  Future<void> _clear() async {
    _generation++;
    await Future.wait(_writers.values.toList().map((w) => w.cancel()));
    await _trimming;
    final directory = await _cacheDirectory();
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<void> stop() async {
    await _starting;
    final server = _server;
    _server = null;
    _signer = null;
    _generation++;
    await server?.close(force: true);
    await Future.wait(_writers.values.toList().map((w) => w.cancel()));
  }
}

class _CacheWriter {
  RandomAccessFile? handle;
  Future<void>? _pending;
  bool _cancelled = false;

  Future<void> perform(Future<void> Function() action) async {
    if (_cancelled) return;
    try {
      await (_pending = action());
    } on FileSystemException {
      _cancelled = true;
      await closeHandle();
    }
  }

  Future<void> closeHandle() async {
    final file = handle;
    handle = null;
    try {
      await file?.close();
    } on FileSystemException {
      _cancelled = true;
    }
  }

  Future<void> cancel() async {
    _cancelled = true;
    try {
      await _pending;
    } on FileSystemException catch (_) {
    }
    await closeHandle();
  }
}

class _CacheEntry {
  final int total;
  final bool complete;
  final String contentType;
  final String? validator;
  final int expires;
  const _CacheEntry(
    this.total,
    this.complete,
    this.contentType,
    this.validator,
    this.expires,
  );

  static _CacheEntry? fromResponse(
    HttpClientResponse remote,
    int? start,
    int? end,
  ) {
    if (start == null || remote.statusCode != HttpStatus.partialContent) {
      return null;
    }
    final headers = remote.headers;
    final type = headers.contentType?.mimeType ?? '';
    if (!type.startsWith('video/') && !type.startsWith('audio/')) return null;
    final cacheControl = (headers[HttpHeaders.cacheControlHeader] ?? [])
        .join(',')
        .toLowerCase();
    if (RegExp(r'(?:^|,)\s*no-store(?:\s|,|=|$)').hasMatch(cacheControl)) {
      return null;
    }
    if (headers.value(HttpHeaders.contentEncodingHeader) case final encoding?
        when encoding != 'identity') {
      return null;
    }
    final match = MediaProxyService._contentRangePattern.firstMatch(
      headers.value(HttpHeaders.contentRangeHeader) ?? '',
    );
    if (match == null) return null;
    final first = int.tryParse(match[1]!);
    final last = int.tryParse(match[2]!);
    final total = int.tryParse(match[3]!);
    if (first != start ||
        last == null ||
        total == null ||
        total <= 0 ||
        total > MediaProxyService._maxCacheBytes ||
        last != min(end ?? total - 1, total - 1) ||
        last < start ||
        last - start + 1 != remote.contentLength) {
      return null;
    }
    final lifespan = RegExp(
      r'(?:^|,)\s*max-age=(\d+)\s*(?=,|$)',
    ).firstMatch(cacheControl);
    final seconds = int.tryParse(lifespan?.group(1) ?? '');
    final now = DateTime.now().millisecondsSinceEpoch;
    int? expires;
    try {
      final date = headers.date?.millisecondsSinceEpoch ?? now;
      final age = int.tryParse(headers.value('age') ?? '0');
      if (age == null || age < 0) return null;
      final originTime = min(date, now - min(age, 2147483647) * 1000);
      if (seconds != null) {
        expires = originTime + min(seconds, 2147483647) * 1000;
      } else if (headers.expires case final expiry?) {
        expires = originTime + expiry.millisecondsSinceEpoch - date;
      }
    } on FormatException {
      return null;
    } on HttpException {
      return null;
    }
    expires ??= now + _defaultFreshnessMs;
    if (expires <= now ||
        (headers['vary'] ?? [])
            .expand((v) => v.split(','))
            .any((v) => v.trim() == '*')) {
      return null;
    }
    final tag = headers.value(HttpHeaders.etagHeader);
    final validator = tag != null && tag.startsWith('"') && tag.endsWith('"')
        ? tag
        : null;
    return _CacheEntry(
      total,
      false,
      headers.contentType!.value,
      validator,
      expires,
    );
  }
}
