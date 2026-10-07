enum FileDownloadStatus { succeeded, cancelled, failed }

class FileDownloadResult {
  final FileDownloadStatus status;
  final String? savedPath;

  /// 关联的任务 ID（走 FileService 下载时）；web/stub 无任务时为 null。
  final String? taskId;

  const FileDownloadResult(this.status, {this.savedPath, this.taskId});

  bool get succeeded => status == FileDownloadStatus.succeeded;
  bool get cancelled => status == FileDownloadStatus.cancelled;
}
