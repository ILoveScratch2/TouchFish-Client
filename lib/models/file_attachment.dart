import 'package:mime/mime.dart';

class FileAttachment {
  final String hash;
  final String fileName;
  final int? fileSize;
  final String? mimeType;

  const FileAttachment({
    required this.hash,
    required this.fileName,
    this.fileSize,
    this.mimeType,
  });

  factory FileAttachment.fromMap(Map<String, dynamic> json) {
    final hash = (json['hash'] ?? json['file_hash'] ?? '').toString();
    final rawFileName = json['file_name'] ?? json['name'] ?? json['filename'];
    final fileName = rawFileName == null || rawFileName.toString().isEmpty
        ? hash
        : rawFileName.toString();
    return FileAttachment(
      hash: hash,
      fileName: fileName,
      fileSize: _asInt(json['size'] ?? json['file_size']),
      mimeType:
          (json['mime_type'] ?? json['content_type'])?.toString() ??
          lookupMimeType(fileName),
    );
  }

  String get resolvedMimeType => mimeType ?? lookupMimeType(fileName) ?? '';

  bool get isImage => resolvedMimeType.startsWith('image/');
  bool get isVideo => resolvedMimeType.startsWith('video/');
  bool get isAudio => resolvedMimeType.startsWith('audio/');
  bool get isPdf =>
      resolvedMimeType == 'application/pdf' ||
      fileName.toLowerCase().endsWith('.pdf');
  bool get isText =>
      resolvedMimeType.startsWith('text/') ||
      const {
        'application/json',
        'application/xml',
        'application/javascript',
      }.contains(resolvedMimeType);
  bool get isPreviewable => isImage || isVideo || isAudio || isText || isPdf;

  static int? _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
