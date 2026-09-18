import 'package:mime/mime.dart';

class FileAttachment {
  final String hash;
  final String fileName;
  final int? fileSize;
  final String? mimeType;

  final int? width;
  final int? height;

  final String? blurhash;
  final bool hasThumb;

  const FileAttachment({
    required this.hash,
    required this.fileName,
    this.fileSize,
    this.mimeType,
    this.width,
    this.height,
    this.blurhash,
    this.hasThumb = false,
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
    final hasThumb =
        json['has_thumb'] == true ||
        (json['thumb_url'] is String && (json['thumb_url'] as String).isNotEmpty);
    return FileAttachment(
      hash: hash,
      fileName: fileName,
      fileSize: _asInt(json['size'] ?? json['file_size']),
      mimeType: mimeType,
      width: _asInt(json['width']),
      height: _asInt(json['height']),
      blurhash: json['blurhash']?.toString(),
      hasThumb: hasThumb,
    );
  }

  FileAttachment copyWith({
    String? fileName,
    int? fileSize,
    String? mimeType,
    int? width,
    int? height,
    String? blurhash,
    bool? hasThumb,
  }) {
    return FileAttachment(
      hash: hash,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      width: width ?? this.width,
      height: height ?? this.height,
      blurhash: blurhash ?? this.blurhash,
      hasThumb: hasThumb ?? this.hasThumb,
    );
  }

  double? get aspectRatio {
    final w = width;
    final h = height;
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return w / h;
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
  static const _textExtensions = {
    '.txt', '.log', '.md', '.markdown', '.csv', '.tsv',
    '.json', '.xml', '.yaml', '.yml', '.toml', '.ini',
    '.cfg', '.conf', '.properties', '.env',
    '.html', '.htm', '.css', '.js', '.ts', '.jsx', '.tsx',
    '.dart', '.py', '.rb', '.go', '.rs', '.c', '.cpp', '.h',
    '.java', '.kt', '.swift', '.sh', '.bat', '.ps1',
    '.sql', '.r', '.m', '.lua', '.php', '.pl', '.scala',
    '.gradle', '.cmake', '.makefile',
  };

  bool get isText {
    if (resolvedMimeType.startsWith('text/')) return true;
    if (fileName.contains('.')) {
      if (_textExtensions.contains(fileName.substring(fileName.lastIndexOf('.')).toLowerCase())) {
        return true;
      }
    }
    return false;
  }
  bool get isPreviewable => isImage || isVideo || isAudio || isText || isPdf;

  static int? _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
