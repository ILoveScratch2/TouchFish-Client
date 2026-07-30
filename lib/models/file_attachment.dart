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
    final rawMime = (json['mime_type'] ?? json['content_type'])?.toString();
    final fileType = json['file_type']?.toString();
    // Prefer file_type over generic/octet-stream, fall back to extension.
    final mimeType = (fileType != null ? _mimeFromFileType(fileType) : null)
        ?? (rawMime != null && rawMime != 'application/octet-stream' ? rawMime : null)
        ?? lookupMimeType(fileName);
    return FileAttachment(
      hash: hash,
      fileName: fileName,
      fileSize: _asInt(json['size'] ?? json['file_size']),
      mimeType: mimeType,
    );
  }

  static String? _mimeFromFileType(String? fileType) {
    if (fileType == null) return null;
    return switch (fileType.toLowerCase()) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'bmp' => 'image/bmp',
      'svg' => 'image/svg+xml',
      'tgs' || 'webp' => 'image/webp',
      'mp4' => 'video/mp4',
      'webm' => 'video/webm',
      'mp3' || 'mpeg' => 'audio/mpeg',
      'wav' => 'audio/wav',
      'ogg' => 'audio/ogg',
      _ => null,
    };
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
      }.contains(resolvedMimeType) ||
      fileName.toLowerCase().endsWith('.log');
  bool get isPreviewable => isImage || isVideo || isAudio || isText || isPdf;

  static int? _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
