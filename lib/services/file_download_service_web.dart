import 'package:url_launcher/url_launcher.dart';

class FileDownloadResult {
  final bool succeeded;
  final String? savedPath;

  const FileDownloadResult(this.succeeded, {this.savedPath});
}

Future<FileDownloadResult> downloadFile(String url, String fileName) async {
  final opened = await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
  return FileDownloadResult(opened);
}
