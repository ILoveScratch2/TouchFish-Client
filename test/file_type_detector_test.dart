import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/utils/file_type_detector.dart';

void main() {
  final pngBytes = Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG magic
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  ]);
  final jpgBytes = Uint8List.fromList(const [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
  final webpBytes = Uint8List.fromList(const [
    0x52, 0x49, 0x46, 0x46, // "RIFF"
    0x24, 0x00, 0x00, 0x00,
    0x57, 0x45, 0x42, 0x50, // "WEBP"
    0x56, 0x50, 0x38, 0x20,
  ]);
  final unknownBytes = Uint8List.fromList(const [0x00, 0x01, 0x02, 0x03]);

  group('detectFileType', () {
    test('detects PNG from byte signature', () {
      expect(detectFileType(pngBytes), DetectedFileType.png);
    });

    test('detects JPEG from byte signature', () {
      expect(detectFileType(jpgBytes), DetectedFileType.jpg);
    });

    test('detects GIF from byte signature', () {
      expect(
        detectFileType(
          Uint8List.fromList(const [0x47, 0x49, 0x46, 0x38, 0x39, 0x61]),
        ),
        DetectedFileType.gif,
      );
    });

    test('detects BMP from byte signature', () {
      expect(
        detectFileType(Uint8List.fromList(const [0x42, 0x4D, 0x36, 0x00])),
        DetectedFileType.bmp,
      );
    });

    test('detects WebP from byte signature', () {
      expect(detectFileType(webpBytes), DetectedFileType.webp);
    });

    test('detects SVG from content', () {
      final svg = Uint8List.fromList(
        '<svg xmlns="http://www.w3.org/2000/svg"></svg>'.codeUnits,
      );
      expect(detectFileType(svg), DetectedFileType.svg);
    });

    test('returns unknown for garbage bytes', () {
      expect(detectFileType(unknownBytes), DetectedFileType.unknown);
    });

    test('falls back to the extension when bytes are ambiguous', () {
      expect(
        detectFileType(unknownBytes, fallbackName: 'image.png'),
        DetectedFileType.png,
      );
      expect(
        detectFileType(unknownBytes, fallbackName: 'clip.webp'),
        DetectedFileType.webp,
      );
    });
  });

  group('DetectedFileType.fileExtension', () {
    test('maps every detected type to its canonical extension', () {
      expect(DetectedFileType.png.fileExtension, 'png');
      expect(DetectedFileType.jpg.fileExtension, 'jpg');
      expect(DetectedFileType.gif.fileExtension, 'gif');
      expect(DetectedFileType.bmp.fileExtension, 'bmp');
      expect(DetectedFileType.svg.fileExtension, 'svg');
      expect(DetectedFileType.tgs.fileExtension, 'tgs');
      expect(DetectedFileType.webp.fileExtension, 'webp');
      expect(DetectedFileType.unknown.fileExtension, isEmpty);
    });
  });

  group('ensureFileExtension', () {
    test('appends an extension when the name has none (the clipboard bug)', () {
      expect(ensureFileExtension('clipboard_file', pngBytes), 'clipboard_file.png');
      expect(ensureFileExtension('clipboard_file', jpgBytes), 'clipboard_file.jpg');
      expect(ensureFileExtension('image', webpBytes), 'image.webp');
    });

    test('keeps a name whose extension already matches', () {
      expect(ensureFileExtension('photo.png', pngBytes), 'photo.png');
      expect(ensureFileExtension('photo.PNG', pngBytes), 'photo.PNG');
      expect(ensureFileExtension('photo.jpeg', jpgBytes), 'photo.jpeg');
    });

    test('replaces a wrong extension with the detected one', () {
      expect(ensureFileExtension('photo.jpg', pngBytes), 'photo.png');
      expect(ensureFileExtension('photo.png', webpBytes), 'photo.webp');
    });

    test('leaves unrecognized content untouched', () {
      expect(ensureFileExtension('clipboard_file', unknownBytes), 'clipboard_file');
      expect(ensureFileExtension('archive.bin', unknownBytes), 'archive.bin');
    });
  });
}
