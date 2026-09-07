import 'package:url_launcher/url_launcher.dart';

import 'file_download_result.dart';
import '../providers/task/task_manager_provider.dart';

Future<FileDownloadResult> downloadFile(
  String url,
  String fileName, {
  TaskManager? taskManager,
}) async {
  final opened = await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
  return FileDownloadResult(
    opened ? FileDownloadStatus.succeeded : FileDownloadStatus.failed,
  );
}
