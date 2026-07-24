class FileDownloadResult {
  final bool succeeded;
  final String? savedPath;

  const FileDownloadResult(this.succeeded, {this.savedPath});
}

Future<FileDownloadResult> downloadFile(String url, String fileName) async =>
    const FileDownloadResult(false);
