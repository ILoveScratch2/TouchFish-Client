import 'dart:convert';

/// 分块上传会话
class UploadSession {
  /// 服务端返回的会话 ID（`file_id`）。
  final String sessionId;

  /// 本地文件路径（作为会话唯一键）。
  final String filePath;

  final String fileName;

  final int fileSize;

  /// 每个分块的字节数。
  final int chunkSize;

  /// 总分块数。
  final int totalChunks;

  /// 已成功上传的分块索引（升序）。
  final Set<int> uploadedChunks;

  /// 整个文件的 SHA256 十六进制字符串（用于服务端完整性校验）。
  final String? expectedHash;

  /// 会话建立时间。
  final DateTime createdAt;

  /// 服务端会话过期时间（默认 1 小时后）。
  final DateTime expiresAt;

  const UploadSession({
    required this.sessionId,
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.chunkSize,
    required this.totalChunks,
    required this.uploadedChunks,
    this.expectedHash,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  int get remainingChunks => totalChunks - uploadedChunks.length;

  bool get isComplete => uploadedChunks.length >= totalChunks;

  double get progress =>
      totalChunks <= 0 ? 0 : uploadedChunks.length / totalChunks;

  UploadSession copyWith({Set<int>? uploadedChunks, String? sessionId}) {
    return UploadSession(
      sessionId: sessionId ?? this.sessionId,
      filePath: filePath,
      fileName: fileName,
      fileSize: fileSize,
      chunkSize: chunkSize,
      totalChunks: totalChunks,
      uploadedChunks: uploadedChunks ?? this.uploadedChunks,
      expectedHash: expectedHash,
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'filePath': filePath,
    'fileName': fileName,
    'fileSize': fileSize,
    'chunkSize': chunkSize,
    'totalChunks': totalChunks,
    'uploadedChunks': uploadedChunks.toList()..sort(),
    'expectedHash': expectedHash,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'expiresAt': expiresAt.millisecondsSinceEpoch,
  };

  factory UploadSession.fromJson(Map<String, dynamic> json) {
    return UploadSession(
      sessionId: json['sessionId'] as String,
      filePath: json['filePath'] as String,
      fileName: json['fileName'] as String,
      fileSize: (json['fileSize'] as num).toInt(),
      chunkSize: (json['chunkSize'] as num).toInt(),
      totalChunks: (json['totalChunks'] as num).toInt(),
      uploadedChunks: ((json['uploadedChunks'] as List<dynamic>?) ?? const [])
          .whereType<num>()
          .map((e) => e.toInt())
          .toSet(),
      expectedHash: json['expectedHash'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['createdAt'] as num).toInt(),
      ),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        (json['expiresAt'] as num).toInt(),
      ),
    );
  }

  /// 序列化为字符串（用于 SharedPreferences）。
  String encode() => jsonEncode(toJson());

  static UploadSession? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final session = UploadSession.fromJson(map);
      return session.isExpired ? null : session;
    } catch (_) {
      return null;
    }
  }
}
