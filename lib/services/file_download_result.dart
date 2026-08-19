enum FileDownloadStatus { succeeded, cancelled, failed }

class FileDownloadResult {
  final FileDownloadStatus status;
  final String? savedPath;

  const FileDownloadResult(this.status, {this.savedPath});

  bool get succeeded => status == FileDownloadStatus.succeeded;
  bool get cancelled => status == FileDownloadStatus.cancelled;
}
