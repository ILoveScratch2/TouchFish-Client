import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/models/settings_service.dart';
import 'package:touchfish_client/services/media_proxy_service_native.dart';

/// 模拟一个慢速分片的远端媒体服务器（支持 Range）。
Future<HttpServer> startSlowSource({
  required int totalBytes,
  required int chunkBytes,
  required Duration chunkDelay,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final response = request.response;
    response.headers.contentType = ContentType('video', 'mp4');
    response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    final range = request.headers.value(HttpHeaders.rangeHeader);
    if (range != null) {
      final m = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(range)!;
      final start = int.parse(m.group(1)!);
      final end = m.group(2)!.isEmpty ? totalBytes - 1 : int.parse(m.group(2)!);
      response.statusCode = HttpStatus.partialContent;
      response.headers.contentLength = end - start + 1;
      response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-$end/$totalBytes',
      );
      response.add(List.filled(end - start + 1, 0x42));
      await response.close();
      return;
    }
    response.statusCode = HttpStatus.ok;
    response.headers.contentLength = totalBytes;
    var sent = 0;
    while (sent < totalBytes) {
      response.add(List.filled(chunkBytes, 0x41));
      sent += chunkBytes;
      await response.flush();
      await Future<void>.delayed(chunkDelay);
    }
    await response.close();
  }, onError: (Object e, StackTrace st) {});
  return server;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // flutter_test 默认把 HttpOverrides 换成 mock（所有 HttpClient 请求返回
    // 400），这里恢复真实网络；path_provider 走 method channel 需 mock 缓存目录。
    HttpOverrides.global = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async =>
              '${Directory.systemTemp.path}/media_proxy_test',
        );
    SharedPreferences.setMockInitialValues({'mediaProxyEnabled': true});
    await SettingsService.instance.init();
  });

  tearDown(() async {
    await MediaProxyService.instance.stop();
  });

  group('MediaProxyService.resolveUrl', () {
    test('wraps http and https URLs into the local proxy', () async {
      final wrapped = await MediaProxyService.instance
          .resolveUrl('https://example.com/video.mp4');
      final uri = Uri.parse(wrapped);
      expect(uri.scheme, 'http');
      expect(uri.host, '127.0.0.1');
      expect(uri.path, '/media');
      expect(
        uri.queryParameters['url'],
        'https://example.com/video.mp4',
      );
    });

    test('passes through local paths, hashes and empty strings', () async {
      final proxy = MediaProxyService.instance;
      expect(
        await proxy.resolveUrl(r'C:\Users\me\video.mp4'),
        r'C:\Users\me\video.mp4',
      );
      expect(
        await proxy.resolveUrl('/data/user/0/me/video.mp4'),
        '/data/user/0/me/video.mp4',
      );
      expect(await proxy.resolveUrl('abc123filehash'), 'abc123filehash');
      expect(await proxy.resolveUrl(''), '');
    });

    test('returns unchanged when proxy is disabled', () async {
      await SettingsService.instance.setValue('mediaProxyEnabled', false);
      expect(
        await MediaProxyService.instance
            .resolveUrl('https://example.com/video.mp4'),
        'https://example.com/video.mp4',
      );
      await SettingsService.instance.setValue('mediaProxyEnabled', true);
    });
  });

  group('MediaProxyService streaming', () {
    test('first byte reaches the client before the full download finishes',
        () async {
      const totalBytes = 16 * 1024 * 1024; // 16MB @ 32 x 40ms ≈ 1.3s
      final source = await startSlowSource(
        totalBytes: totalBytes,
        chunkBytes: 512 * 1024,
        chunkDelay: const Duration(milliseconds: 40),
      );
      addTearDown(() => source.close(force: true));

      final proxyUrl = await MediaProxyService.instance
          .resolveUrl('http://127.0.0.1:${source.port}/video.mp4');
      final client = HttpClient();
      addTearDown(() => client.close(force: true));

      final stopwatch = Stopwatch()..start();
      final request = await client.getUrl(Uri.parse(proxyUrl));
      final response = await request.close();
      expect(response.statusCode, HttpStatus.ok);

      var firstByteMs = -1;
      var received = 0;
      await for (final chunk in response) {
        if (firstByteMs < 0) firstByteMs = stopwatch.elapsedMilliseconds;
        received += chunk.length;
        if (received >= 512 * 1024) break;
      }

      expect(firstByteMs, greaterThanOrEqualTo(0));
      // 流式下首字节应远早于全量下载完成（≈1.3s）。
      expect(firstByteMs, lessThan(300));
    });
  });

  group('MediaProxyService concurrency', () {
    test('a slow download does not block other requests', () async {
      const totalBytes = 16 * 1024 * 1024; // 16MB @ 32 x 40ms ≈ 1.3s
      final source = await startSlowSource(
        totalBytes: totalBytes,
        chunkBytes: 512 * 1024,
        chunkDelay: const Duration(milliseconds: 40),
      );
      addTearDown(() => source.close(force: true));

      final proxyUrl = await MediaProxyService.instance
          .resolveUrl('http://127.0.0.1:${source.port}/video.mp4');
      final proxyBase = Uri.parse(proxyUrl).replace(path: '/health');
      final client = HttpClient();
      addTearDown(() => client.close(force: true));

      // 先发起慢速全量下载（不等待），再发 health 探测。
      final slowSw = Stopwatch()..start();
      final slowFuture = () async {
        final request = await client.getUrl(Uri.parse(proxyUrl));
        final response = await request.close();
        await response.drain<void>();
        return slowSw.elapsedMilliseconds;
      }();

      final healthSw = Stopwatch()..start();
      final healthRequest = await client.getUrl(proxyBase);
      final healthResponse = await healthRequest.close();
      expect(healthResponse.statusCode, HttpStatus.ok);
      expect(await healthResponse.transform(utf8.decoder).join(), 'OK');
      final healthMs = healthSw.elapsedMilliseconds;
      final slowMs = await slowFuture;

      // 并发下 health 应立即响应；若回归为串行 forEach 会被阻塞到下载完成。
      expect(healthMs, lessThan(500));
      expect(healthMs, lessThan(slowMs));
    });

    test('a stalled probe request does not block concurrent range requests',
        () async {
      // 回归用例：播放器先发 Range: bytes=0- 探测并因等待索引而停止读取
      // （TCP 背压），随后发尾部 Range 读取 moov。旧实现把同一 URL 的请求
      // 串行排队，尾部请求永远等不到 → 视频卡 0:00。
      const totalBytes = 16 * 1024 * 1024;
      final source = await startSlowSource(
        totalBytes: totalBytes,
        chunkBytes: 512 * 1024,
        chunkDelay: const Duration(milliseconds: 10),
      );
      addTearDown(() => source.close(force: true));

      final proxyUrl = await MediaProxyService.instance
          .resolveUrl('http://127.0.0.1:${source.port}/video.mp4');
      final client = HttpClient();
      addTearDown(() => client.close(force: true));

      // A：探测请求，收到响应头后立即 pause（连接保持打开、不再读数据），
      // 制造背压让代理的下载挂起。
      final aRequest = await client.getUrl(Uri.parse(proxyUrl));
      aRequest.headers.set(HttpHeaders.rangeHeader, 'bytes=0-');
      final aResponse = await aRequest.close();
      expect(aResponse.statusCode, HttpStatus.partialContent);
      final aSub = aResponse.listen((_) {});
      aSub.pause();
      addTearDown(() => aSub.cancel());

      // B：并发请求文件尾部 64KB（ffmpeg 读取 moov 索引的典型请求）。
      final bStart = totalBytes - 64 * 1024;
      final bSw = Stopwatch()..start();
      final bFuture = () async {
        final bRequest = await client.getUrl(Uri.parse(proxyUrl));
        bRequest.headers.set(HttpHeaders.rangeHeader, 'bytes=$bStart-');
        final bResponse = await bRequest.close();
        expect(bResponse.statusCode, HttpStatus.partialContent);
        final received = await bResponse.fold<int>(
          0,
          (sum, chunk) => sum + chunk.length,
        );
        expect(received, 64 * 1024);
        return bSw.elapsedMilliseconds;
      }();
      final bMs = await bFuture.timeout(const Duration(seconds: 15));
      // 若被 A 的串行链阻塞，B 会在超时后失败；正常并发下应瞬时完成。
      expect(bMs, lessThan(5000));
    });
  });
}
