import 'package:url_launcher/url_launcher.dart';

import 'file_download_result.dart';

Future<FileDownloadResult> downloadFile(String url, String fileName) async {
  final opened = await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
  return FileDownloadResult(
    opened ? FileDownloadStatus.succeeded : FileDownloadStatus.failed,
  );
}
