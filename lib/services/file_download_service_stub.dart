import 'file_download_result.dart';

Future<FileDownloadResult> downloadFile(String url, String fileName) async =>
    const FileDownloadResult(FileDownloadStatus.failed);
