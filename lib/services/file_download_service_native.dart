import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'file_download_result.dart';

typedef DownloadFetcher = Future<http.Response> Function(Uri uri);
typedef DownloadSaver = Future<String?> Function(
  String fileName,
  Uint8List bytes,
);

String sanitizeDownloadFileName(String fileName) {
  final sanitized = fileName
      .replaceAll(RegExp(r'[\x00-\x1f<>:"/\\|?*]'), '_')
      .trim();
  if (sanitized.isEmpty || RegExp(r'^\.+$').hasMatch(sanitized)) {
    return 'download';
  }
  return sanitized;
}

@visibleForTesting
Future<FileDownloadResult> downloadAndSaveFile({
  required String url,
  required String fileName,
  required DownloadFetcher fetch,
  required DownloadSaver save,
}) async {
  final response = await fetch(Uri.parse(url)).timeout(
    const Duration(minutes: 2),
  );
  if (response.statusCode < 200 || response.statusCode >= 300) {
    return const FileDownloadResult(FileDownloadStatus.failed);
  }

  final destination = await save(
    sanitizeDownloadFileName(fileName),
    response.bodyBytes,
  );
  if (destination == null) {
    return const FileDownloadResult(FileDownloadStatus.cancelled);
  }
  return FileDownloadResult(
    FileDownloadStatus.succeeded,
    savedPath: destination,
  );
}

Future<FileDownloadResult> downloadFile(String url, String fileName) async {
  if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
    return downloadAndSaveFile(
      url: url,
      fileName: fileName,
      fetch: http.get,
      save: (name, bytes) => FilePicker.platform.saveFile(
        fileName: name,
        bytes: bytes,
      ),
    );
  }

  final destination = await FilePicker.platform.saveFile(
    fileName: sanitizeDownloadFileName(fileName),
  );
  if (destination == null) {
    return const FileDownloadResult(FileDownloadStatus.cancelled);
  }
  final response = await http.get(
    Uri.parse(url),
  ).timeout(const Duration(minutes: 2));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    return const FileDownloadResult(FileDownloadStatus.failed);
  }
  await File(destination).writeAsBytes(response.bodyBytes, flush: true);
  return FileDownloadResult(
    FileDownloadStatus.succeeded,
    savedPath: destination,
  );
}
