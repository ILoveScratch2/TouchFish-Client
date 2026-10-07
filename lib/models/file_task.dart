import 'dart:math' as math;

/// 文件传输任务类型。
enum FileTaskType { upload, download }

/// 文件传输任务状态。
enum FileTaskStatus {
  /// 准备中（计算哈希、建立上传会话等）。
  preparing,

  /// 传输中（上传或下载）。
  transferring,

  /// 已完成。
  completed,

  /// 失败。
  failed,
}

/// 一个文件上传/下载任务。
///
/// 任务由 [FileService] 创建并托管在 `TaskManagerProvider` 中，
/// UI（全局浮层、消息气泡）通过 taskId 或 clientMid 查询并响应式刷新。
class FileTask {
  final String id;

  /// 任务类型：上传或下载。
  final FileTaskType type;

  /// 当前状态。
  final FileTaskStatus status;

  /// 文件名（用于展示）。
  final String fileName;

  /// 文件总大小（字节）。下载时可能未知（-1），此时进度为不确定态。
  final int fileSize;

  /// 已传输字节数。
  final int bytesTransferred;

  /// 上传任务关联的 pending 消息 clientMid（用于气泡内显示进度）。
  final String? clientMid;

  /// 上传任务关联的房间 ID。
  final String? roomId;

  /// 失败原因。
  final String? errorMessage;

  /// 上传完成后的服务端文件哈希。
  final String? fileHash;

  /// 下载完成后的本地保存路径。
  final String? savePath;

  /// 任务创建时间（用于计算平均速度）。
  final DateTime createdAt;

  /// 结束时间（completed/failed 的时刻）；未结束时为 null。用于按
  /// "结束后多久"清理，避免长任务完成后立刻被误清。
  final DateTime? finishedAt;

  const FileTask({
    required this.id,
    required this.type,
    required this.status,
    required this.fileName,
    required this.fileSize,
    this.bytesTransferred = 0,
    this.clientMid,
    this.roomId,
    this.errorMessage,
    this.fileHash,
    this.savePath,
    required this.createdAt,
    this.finishedAt,
  });

  /// 0.0 ~ 1.0；文件大小未知时返回 null（表示不确定进度）。
  double? get progress {
    if (fileSize <= 0) return null;
    return (bytesTransferred / fileSize).clamp(0.0, 1.0);
  }

  /// 百分数字符串，例如 `"42%"`。
  String get progressLabel {
    final p = progress;
    if (p == null) return '…';
    return '${(p * 100).round()}%';
  }

  /// 平均传输速度（字节/秒）。
  double get speedBytesPerSecond {
    final elapsed = DateTime.now().difference(createdAt).inMilliseconds / 1000;
    if (elapsed <= 0) return 0;
    return bytesTransferred / elapsed;
  }

  /// 人类可读的速度，例如 `"1.2 MB/s"`。
  String get speedFormatted {
    final speed = speedBytesPerSecond;
    if (speed < 1024) return '${speed.toStringAsFixed(0)} B/s';
    if (speed < 1024 * 1024) {
      return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    }
    if (speed < 1024 * 1024 * 1024) {
      return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    return '${(speed / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB/s';
  }

  /// 人类可读的文件大小。
  String get sizeFormatted => formatFileSize(fileSize);

  static String formatFileSize(int bytes) {
    if (bytes < 0) return '—';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  FileTask copyWith({
    String? id,
    FileTaskType? type,
    FileTaskStatus? status,
    String? fileName,
    int? fileSize,
    int? bytesTransferred,
    String? clientMid,
    String? roomId,
    String? errorMessage,
    String? fileHash,
    String? savePath,
    DateTime? createdAt,
    DateTime? finishedAt,
  }) {
    return FileTask(
      id: id ?? this.id,
      type: type ?? this.type,
      status: status ?? this.status,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      clientMid: clientMid ?? this.clientMid,
      roomId: roomId ?? this.roomId,
      errorMessage: errorMessage ?? this.errorMessage,
      fileHash: fileHash ?? this.fileHash,
      savePath: savePath ?? this.savePath,
      createdAt: createdAt ?? this.createdAt,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FileTask &&
      other.id == id &&
      other.type == type &&
      other.status == status &&
      other.fileName == fileName &&
      other.fileSize == fileSize &&
      other.bytesTransferred == bytesTransferred &&
      other.clientMid == clientMid &&
      other.roomId == roomId &&
      other.errorMessage == errorMessage &&
      other.fileHash == fileHash &&
      other.savePath == savePath &&
      other.createdAt == createdAt &&
      other.finishedAt == finishedAt;

  @override
  int get hashCode => Object.hash(
    id,
    type,
    status,
    fileName,
    fileSize,
    bytesTransferred,
    clientMid,
    roomId,
    errorMessage,
    fileHash,
    savePath,
    createdAt,
    finishedAt,
  );
}

/// 生成一个简单的时间戳 ID（避免引入额外 uuid 依赖）。
String generateFileTaskId(String prefix) {
  final micros = DateTime.now().microsecondsSinceEpoch;
  final rand = math.Random().nextInt(0xffffff);
  return '${prefix}_${micros}_${rand.toRadixString(16)}';
}
