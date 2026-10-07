import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/models/settings_service.dart';
import 'package:touchfish_client/services/image_compression_service.dart';

/// 确定性噪点图。噪点是为了让编码器压不下去
img.Image _noiseImage(int width, int height, {int channels = 3}) {
  final image = img.Image(
    width: width,
    height: height,
    numChannels: channels,
  );
  var seed = 0x2545F491;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
      final r = seed & 0xFF;
      final g = (seed >> 8) & 0xFF;
      final b = (seed >> 16) & 0xFF;
      if (channels == 4) {
        image.setPixelRgba(x, y, r, g, b, 255);
      } else {
        image.setPixelRgb(x, y, r, g, b);
      }
    }
  }
  return image;
}

void main() {
  late Uint8List bigJpeg; // 最长边 2400，触发缩放
  late Uint8List opaquePng;
  late Uint8List transparentPng;
  late Uint8List animatedGif;
  late Uint8List tinyJpeg;
  late Uint8List notAnImage;

  setUpAll(() {
    bigJpeg = img.encodeJpg(_noiseImage(2400, 1800), quality: 100);
    opaquePng = img.encodePng(_noiseImage(800, 600));
    final transparent = _noiseImage(800, 600, channels: 4);
    transparent.setPixelRgba(0, 0, 0, 0, 0, 0);
    transparentPng = img.encodePng(transparent);
    final gif = _noiseImage(800, 600);
    gif.addFrame(_noiseImage(800, 600));
    animatedGif = img.encodeGif(gif, singleFrame: false);
    tinyJpeg = img.encodeJpg(_noiseImage(120, 90), quality: 80);
    notAnImage = Uint8List.fromList(
      List<int>.generate(200 * 1024, (i) => (i * 7) & 0xFF),
    );
  });

  group('ImageCompressionService.prepareForUpload', () {
    test('fixtures are large enough to pass the size gate', () {
      // 否则下面的"跳过"用例会因为体积门槛而假通过。
      expect(bigJpeg.length, greaterThan(100 * 1024));
      expect(opaquePng.length, greaterThan(100 * 1024));
      expect(transparentPng.length, greaterThan(100 * 1024));
      expect(animatedGif.length, greaterThan(100 * 1024));
      expect(tinyJpeg.length, lessThan(100 * 1024));
    });

    test('compresses a large JPEG and gives it the right extension', () async {
      final prepared = await ImageCompressionService.instance.prepareForUpload(
        bytes: bigJpeg,
        fileName: 'clipboard_1700000000',
      );

      expect(prepared, isNotNull);
      expect(prepared!.bytes.length, lessThan(bigJpeg.length));
      expect(prepared.fileName, 'clipboard_1700000000.jpg');
      // 缩放后最长边正好是 1920（纯 Dart 回退路径在 Windows/CI 上必然走到）。
      final decoded = img.decodeImage(prepared.bytes)!;
      expect(decoded.width, 1920);
      expect(decoded.height, 1440);

      // 名字里已经是 JPEG 扩展名时不该被改动。
      final kept = await ImageCompressionService.instance.prepareForUpload(
        bytes: bigJpeg,
        fileName: 'IMG_0001.JPEG',
      );
      expect(kept!.fileName, 'IMG_0001.JPEG');
    });

    test('re-encodes an opaque PNG as JPEG', () async {
      final prepared = await ImageCompressionService.instance.prepareForUpload(
        bytes: opaquePng,
        fileName: 'screenshot.png',
      );

      expect(prepared, isNotNull);
      expect(prepared!.bytes.length, lessThan(opaquePng.length));
      expect(prepared.fileName, 'screenshot.jpg');
      expect(img.findDecoderForData(prepared.bytes), isNotNull);
    });

    test('lower quality produces a smaller file', () async {
      final low = await ImageCompressionService.instance.prepareForUpload(
        bytes: bigJpeg,
        fileName: 'photo.jpg',
        quality: 30,
      );
      final high = await ImageCompressionService.instance.prepareForUpload(
        bytes: bigJpeg,
        fileName: 'photo.jpg',
        quality: 90,
      );

      expect(low, isNotNull);
      expect(high, isNotNull);
      expect(low!.bytes.length, lessThan(high!.bytes.length));
    });

    test('returns null when compression is disabled', () async {
      final prepared = await ImageCompressionService.instance.prepareForUpload(
        bytes: bigJpeg,
        fileName: 'photo.jpg',
        enabled: false,
      );

      expect(prepared, isNull);
    });

    test('skips animated GIFs to keep the animation', () async {
      final prepared = await ImageCompressionService.instance.prepareForUpload(
        bytes: animatedGif,
        fileName: 'animation.gif',
      );

      expect(prepared, isNull);
    });

    test('skips images with transparent pixels', () async {
      final prepared = await ImageCompressionService.instance.prepareForUpload(
        bytes: transparentPng,
        fileName: 'sticker.png',
      );

      expect(prepared, isNull);
    });

    test('skips bytes that are not an image', () async {
      final prepared = await ImageCompressionService.instance.prepareForUpload(
        bytes: notAnImage,
        fileName: 'archive.bin',
      );

      expect(prepared, isNull);
    });

    test('skips images below the minimum size', () async {
      final prepared = await ImageCompressionService.instance.prepareForUpload(
        bytes: tinyJpeg,
        fileName: 'avatar.jpg',
      );

      expect(prepared, isNull);
    });

    // 必须放在最后：这一条会把 SettingsService 初始化成固定值。
    test('falls back to the configured quality setting', () async {
      SharedPreferences.setMockInitialValues({
        'imageCompressionEnabled': true,
        'imageCompressionQuality': 0.1,
      });
      await SettingsService.instance.init();

      final viaSetting = await ImageCompressionService.instance
          .prepareForUpload(bytes: bigJpeg, fileName: 'photo.jpg');
      final explicit = await ImageCompressionService.instance.prepareForUpload(
        bytes: bigJpeg,
        fileName: 'photo.jpg',
        quality: 10,
      );

      expect(viaSetting, isNotNull);
      expect(explicit, isNotNull);
      // 同样的确定性编码器，读到 0.1 就应该和显式 quality: 10 一模一样。
      expect(viaSetting!.bytes.length, explicit!.bytes.length);
    });
  });
}
