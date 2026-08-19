import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:touchfish_client/services/file_download_service_native.dart';
import 'package:touchfish_client/services/file_download_result.dart';

void main() {
  group('native file downloads', () {
    test('downloads response bytes before saving', () async {
      String? savedName;
      Uint8List? savedBytes;

      final result = await downloadAndSaveFile(
        url: 'https://example.com/file',
        fileName: 'report.txt',
        fetch: (uri) async => http.Response.bytes([1, 2, 3], 200),
        save: (fileName, bytes) async {
          savedName = fileName;
          savedBytes = bytes;
          return '/downloads/$fileName';
        },
      );

      expect(result.status, FileDownloadStatus.succeeded);
      expect(result.savedPath, '/downloads/report.txt');
      expect(savedName, 'report.txt');
      expect(savedBytes, Uint8List.fromList([1, 2, 3]));
    });

    test('does not save unsuccessful HTTP responses', () async {
      var saveCalled = false;

      final result = await downloadAndSaveFile(
        url: 'https://example.com/missing',
        fileName: 'missing.txt',
        fetch: (uri) async => http.Response('missing', 404),
        save: (fileName, bytes) async {
          saveCalled = true;
          return '/downloads/$fileName';
        },
      );

      expect(result.status, FileDownloadStatus.failed);
      expect(saveCalled, isFalse);
    });

    test('reports a cancelled save separately from failure', () async {
      final result = await downloadAndSaveFile(
        url: 'https://example.com/file',
        fileName: 'report.txt',
        fetch: (uri) async => http.Response('content', 200),
        save: (fileName, bytes) async => null,
      );

      expect(result.status, FileDownloadStatus.cancelled);
      expect(result.cancelled, isTrue);
    });

    test('sanitizes unsafe suggested file names', () {
      expect(
        sanitizeDownloadFileName(' ../folder\\report?.txt '),
        '.._folder_report_.txt',
      );
      expect(sanitizeDownloadFileName('...'), 'download');
      expect(sanitizeDownloadFileName('   '), 'download');
      expect(sanitizeDownloadFileName('报告.txt'), '报告.txt');
    });
  });
}
