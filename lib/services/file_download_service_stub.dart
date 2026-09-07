import 'file_download_result.dart';
import '../providers/task/task_manager_provider.dart';

Future<FileDownloadResult> downloadFile(
  String url,
  String fileName, {
  TaskManager? taskManager,
}) async =>
    const FileDownloadResult(FileDownloadStatus.failed);
