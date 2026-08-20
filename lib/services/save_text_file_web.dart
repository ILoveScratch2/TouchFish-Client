import 'dart:html' as html;
import 'dart:typed_data';

/// Triggers a browser download of [bytes] as [fileName].
Future<String?> saveTextFile(String fileName, Uint8List bytes) async {
  final blob = html.Blob([bytes], 'application/octet-stream');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)..download = fileName;
  anchor.click();
  html.Url.revokeObjectUrl(url);
  return fileName;
}
