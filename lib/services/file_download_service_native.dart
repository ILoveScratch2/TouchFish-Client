import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class FileDownloadResult {
  final bool succeeded;
  final String? savedPath;

  const FileDownloadResult(this.succeeded, {this.savedPath});
}

Future<FileDownloadResult> downloadFile(String url, String fileName) async {
  if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    return FileDownloadResult(opened);
  }

  final destination = await FilePicker.platform.saveFile(fileName: fileName);
  if (destination == null) return const FileDownloadResult(false);
  final response = await http.get(Uri.parse(url));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    return const FileDownloadResult(false);
  }
  await File(destination).writeAsBytes(response.bodyBytes, flush: true);
  return FileDownloadResult(true, savedPath: destination);
}
