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
    final rawMime = _asMimeType(json['mime_type']) ??
        _asMimeType(json['content_type']);
    final fileType = json['file_type']?.toString();
    final extension = json['extension']?.toString();
    // 优先级：file_type（服务端一般存扩展名）→ 显式 MIME → extension 字段 → 文件扩展名。
    // 注意：消息记录里的 content_type 是内容编码（plain / file / redirect），
    // 不是 MIME。若把它当 MIME 用，缺 file_type 映射的类型（如 m4a 语音）
    // 会得到 mimeType='file'，进而被渲染成文件卡片而不是语音气泡。
    final mimeType = _mimeFromFileType(fileType)
        ?? rawMime
        ?? _mimeFromFileType(extension)
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

  static String? _asMimeType(Object? value) {
    final text = value?.toString().trim().toLowerCase();
    if (text == null || text.isEmpty || !text.contains('/')) return null;
    if (text == 'application/octet-stream' ||
        text == 'binary/octet-stream' ||
        text == 'unknown/unknown') {
      return null;
    }
    return text;
  }
  static String? _mimeFromFileType(String? fileType) {
    final raw = fileType?.trim().toLowerCase();
    if (raw == null || raw.isEmpty) return null;
    if (raw.contains('/')) return _asMimeType(raw);
    final ext = raw.startsWith('.') ? raw.substring(1) : raw;
    return _extensionMimeTypes[ext];
  }

  static const Map<String, String> _extensionMimeTypes = {
    // 图片
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'gif': 'image/gif',
    'bmp': 'image/bmp',
    'svg': 'image/svg+xml',
    'tgs': 'image/webp',
    'webp': 'image/webp',
    // 视频
    'mp4': 'video/mp4',
    'm4v': 'video/x-m4v',
    'webm': 'video/webm',
    'mov': 'video/quicktime',
    'mkv': 'video/x-matroska',
    'avi': 'video/x-msvideo',
    '3gp': 'video/3gpp',
    // 音频
    'm4a': 'audio/mp4',
    'mp4a': 'audio/mp4',
    'aac': 'audio/aac',
    'mp3': 'audio/mpeg',
    'mpeg': 'audio/mpeg',
    'wav': 'audio/wav',
    'ogg': 'audio/ogg',
    'oga': 'audio/ogg',
    'opus': 'audio/opus',
    'weba': 'audio/webm',
    'amr': 'audio/amr',
    'flac': 'audio/x-flac',
  };

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
