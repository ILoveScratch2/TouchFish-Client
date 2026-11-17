import 'dart:math' as math;

import '../utils/format.dart';

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

/// 一个文件上传/下载任务
class FileTask {
  final String id;

  /// 任务类型：上传或下载。
  final FileTaskType type;

  /// 当前状态
  final FileTaskStatus status;

  /// 文件名
  final String fileName;

  /// 文件总大小（字节）。下载时可能未知（-1）
  final int fileSize;

  /// 已传输字节数。
  final int bytesTransferred;

  /// 上传任务关联的 pending 消息 clientMid
  final String? clientMid;

  /// 上传任务关联的房间 ID
  final String? roomId;

  /// 失败原因
  final String? errorMessage;

  /// 上传完成后的服务端文件哈希
  final String? fileHash;

  /// 下载完成后的本地保存路径
  final String? savePath;

  /// 任务创建时间
  final DateTime createdAt;

  /// 结束时间（completed/failed
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

  double? get progress {
    if (fileSize <= 0) return null;
    return (bytesTransferred / fileSize).clamp(0.0, 1.0);
  }

  /// 百分数字符串
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
  String get sizeFormatted => formatBytes(fileSize);

  static String formatFileSize(int bytes) => formatBytes(bytes);

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

/// 生成一个简单的时间戳 ID
String generateFileTaskId(String prefix) {
  final micros = DateTime.now().microsecondsSinceEpoch;
  final rand = math.Random().nextInt(0xffffff);
  return '${prefix}_${micros}_${rand.toRadixString(16)}';
}
