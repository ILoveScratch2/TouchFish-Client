import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/models/settings_service.dart';
import 'package:touchfish_client/services/media_proxy_service_native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MediaProxyService proxy;
  late Directory temp;
  late HttpServer source;
  late HttpClient player;
  late Uri playback;
  late int requests;
  late String policy;
  late String version;

  Future<List<int>> get(
    String? range, {
    Uri? url,
    int status = HttpStatus.ok,
  }) async {
    final request = await player.getUrl(url ?? playback);
    if (range != null) request.headers.set(HttpHeaders.rangeHeader, range);
    final response = await request.close();
    expect(response.statusCode, status);
    return response.fold<List<int>>([], (bytes, part) => bytes..addAll(part));
  }

  Future<void> waitForMetadata(bool complete) async {
    final dir = Directory(
      '${(await getTemporaryDirectory()).path}/touchfish_media_proxy',
    );
    for (var i = 0; i < 200; i++) {
      if (await dir.exists()) {
        await for (final entry in dir.list()) {
          if (entry is File && entry.path.endsWith('.cache.meta')) {
            try {
              if (jsonDecode(await entry.readAsString())['complete'] ==
                  complete) {
                return;
              }
            } on FormatException {
              continue;
            }
          }
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('Expected committed cache metadata (complete=$complete)');
  }

  setUp(() async {
    HttpOverrides.global = null;
    proxy = MediaProxyService.instance;
    temp = await Directory.systemTemp.createTemp('tf-media-cache-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => temp.path,
        );
    SharedPreferences.setMockInitialValues({'mediaProxyEnabled': true});
    await SettingsService.instance.init();
    await proxy.clearCache();
    requests = 0;
    version = '"v1"';
    policy = 'public, max-age=600';
    source = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    source.listen((request) async {
      requests++;
      final headers = request.response.headers;
      headers.contentType = ContentType('video', 'mp4');
      headers.set('cache-control', policy);
      headers.set('etag', version);
      headers.add('vary', 'accept-encoding');
      headers.add('vary', 'accept-language');
      final bytes = version == '"v1"'
          ? [1, 2, 3, 4, 5, 6]
          : [7, 8, 9, 10, 11, 12];
      final raw = request.headers.value('range');
      if (raw == null) {
        request.response.add(bytes);
      } else {
        final match = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(raw)!;
        final start = int.parse(match[1]!);
        final end = int.tryParse(match[2]!) ?? bytes.length - 1;
        request.response.statusCode = 206;
        headers.set('content-range', 'bytes $start-$end/${bytes.length}');
        headers.contentLength = end - start + 1;
        request.response.add(bytes.sublist(start, end + 1));
      }
      await request.response.close();
    });
    player = HttpClient();
    playback = Uri.parse(
      await proxy.resolveUrl('http://127.0.0.1:${source.port}/test'),
    );
  });

  tearDown(() async {
    player.close(force: true);
    await proxy.stop();
    await proxy.clearCache();
    await source.close(force: true);
    await temp.delete(recursive: true);
  });

  test(
    'issued links bind the exact destination and expire on restart',
    () async {
      final alternate = playback.replace(
        queryParameters: {
          ...playback.queryParameters,
          'url': '${playback.queryParameters['url']}?revision=2',
        },
      );
      await get(null, url: alternate, status: 403);
      expect(requests, 0);
      await proxy.stop();
      final fresh = Uri.parse(
        await proxy.resolveUrl(playback.queryParameters['url']!),
      );
      await get(
        null,
        url: fresh.replace(queryParameters: playback.queryParameters),
        status: 403,
      );
      expect(requests, 0);
      expect(await get(null, url: fresh), [1, 2, 3, 4, 5, 6]);
    },
  );

  test('matching validated ranges form a correct cache hit', () async {
    expect(await get('bytes=0-2', status: 206), [1, 2, 3]);
    await waitForMetadata(false);
    expect(await get('bytes=3-', status: 206), [4, 5, 6]);
    await waitForMetadata(true);
    expect(await get('bytes=2-4', status: 206), [3, 4, 5]);
    expect(await get(null), [1, 2, 3, 4, 5, 6]);
    expect(requests, 2);
  });

  test(
    'new representation and stale or private replies are fetched fresh',
    () async {
      expect(await get('bytes=0-2', status: 206), [1, 2, 3]);
      await waitForMetadata(false);
      version = '"v2"';
      expect(await get('bytes=3-', status: 206), [10, 11, 12]);
      expect(await get(null), [7, 8, 9, 10, 11, 12]);
      expect(requests, 3);

      policy = 'private, max-age=60';
      await proxy.clearCache();
      expect(await get('bytes=0-2', status: 206), [7, 8, 9]);
      await waitForMetadata(false);
      expect(await get('bytes=3-', status: 206), [10, 11, 12]);
      await waitForMetadata(true);
      var before = requests;
      expect(await get(null), [7, 8, 9, 10, 11, 12]);
      expect(requests, before);

      policy = 'no-store';
      await proxy.clearCache();
      before = requests;
      expect(await get('bytes=0-2', status: 206), [7, 8, 9]);
      expect(await get('bytes=3-', status: 206), [10, 11, 12]);
      expect(await get(null), [7, 8, 9, 10, 11, 12]);
      expect(requests, before + 3);

      policy = 'max-age=0';
      await proxy.clearCache();
      before = requests;
      expect(await get('bytes=0-2', status: 206), [7, 8, 9]);
      expect(await get('bytes=3-', status: 206), [10, 11, 12]);
      expect(await get(null), [7, 8, 9, 10, 11, 12]);
      expect(requests, before + 3);
    },
  );
}
