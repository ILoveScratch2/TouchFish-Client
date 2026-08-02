import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/services/clipboard_attachment_service.dart';

void main() {
  group('ClipboardAttachmentService', () {
    test('isAvailable returns a boolean', () {
      final service = ClipboardAttachmentService.instance;
      expect(service.isAvailable, isA<bool>());
    });

    test('instance is a singleton', () {
      final a = ClipboardAttachmentService.instance;
      final b = ClipboardAttachmentService.instance;
      expect(identical(a, b), true);
    });

    test('hasFiles returns false when clipboard is unavailable', () async {
      // In test environment SystemClipboard.instance is null on desktop,
      // so hasFiles should return false gracefully.
      final service = ClipboardAttachmentService.instance;
      final result = await service.hasFiles();
      expect(result, false);
    });

    test('checkAndReadFiles returns empty list gracefully', () async {
      final service = ClipboardAttachmentService.instance;
      final files = await service.checkAndReadFiles();
      expect(files, isEmpty);
    });

    test('readClipboardFiles returns empty list gracefully', () async {
      final service = ClipboardAttachmentService.instance;
      final files = await service.readClipboardFiles();
      expect(files, isEmpty);
    });

    test('ClipboardFileData can be constructed', () {
      final data = ClipboardFileData(
        fileName: 'test.png',
        fileSize: 1024,
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      expect(data.fileName, 'test.png');
      expect(data.fileSize, 1024);
      expect(data.bytes, [1, 2, 3]);
    });
  });
}
