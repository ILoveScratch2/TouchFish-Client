import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/file_task.dart';
import '../models/upload_session.dart';
import '../providers/task/task_manager_provider.dart';
import '../services/api/tf_api_client.dart';
import '../utils/talker.dart';

/// 分块上传的每块大小（字节）。服务端单块上限 10MB，这里取 5MB 以
/// 平衡进度粒度与请求次数，同时避免单块过大导致加密后内存峰值过高。
const int kUploadChunkSize = 5 * 1024 * 1024;

/// 小文件（<= 该值）直接走标准单请求上传，避免分块开销。
const int kStandardUploadThreshold = 5 * 1024 * 1024;

/// 上传会话本地存储键前缀。
const String _kSessionKeyPrefix = 'upload_session_';

/// 文件上传/下载服务。
///
/// 负责：
/// - 分块上传（含断点续传、SHA256 完整性校验、小文件自动回退标准上传）
/// - 文件下载（Dio，字节级进度回调）
/// - 通过 `TaskManagerProvider` 广播进度给 UI。
class FileService {
  FileService._();
  static final FileService instance = FileService._();

  final Dio _downloadDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(minutes: 30),
    ),
  );

  /// 上传文件并返回服务端文件哈希；失败时返回 null。
  ///
  /// [ref] 用于读取/写入任务状态。任务进度通过 [TaskManager] 暴露。
  Future<String?> uploadFile({
    required int uid,
    required String password,
    required String fileName,
    required List<int> bytes,
    String? filePath,
    String? clientMid,
    String? roomId,
    required TaskManager taskManager,
  }) async {
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final taskId = taskManager.addTask(
      FileTask(
        id: generateFileTaskId('upload'),
        type: FileTaskType.upload,
        status: FileTaskStatus.preparing,
        fileName: fileName,
        fileSize: data.length,
        clientMid: clientMid,
        roomId: roomId,
        createdAt: DateTime.now(),
      ),
    );

    try {
      final hash = await _uploadInternal(
        uid: uid,
        password: password,
        fileName: fileName,
        bytes: data,
        filePath: filePath,
        onProgress: (transferred) {
          taskManager.updateTask(
            taskId,
            status: FileTaskStatus.transferring,
            bytesTransferred: transferred,
          );
        },
      );

      if (hash == null) {
        taskManager.updateTask(
          taskId,
          status: FileTaskStatus.failed,
          errorMessage: 'upload_failed',
        );
        return null;
      }

      taskManager.updateTask(
        taskId,
        status: FileTaskStatus.completed,
        bytesTransferred: data.length,
        fileHash: hash,
      );
      return hash;
    } catch (e) {
      talker.error('FileService.uploadFile failed', e);
      taskManager.updateTask(
        taskId,
        status: FileTaskStatus.failed,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  Future<String?> _uploadInternal({
    required int uid,
    required String password,
    required String fileName,
    required Uint8List bytes,
    String? filePath,
    required void Function(int transferred) onProgress,
  }) async {
    // 小文件直接走标准上传（一次请求，无进度粒度需求）。
    if (bytes.length <= kStandardUploadThreshold) {
      onProgress(0);
      final base64 = base64Encode(bytes);
      final result = await TfApiClient.instance.uploadFile(
        uid,
        password,
        fileName,
        base64,
      );
      onProgress(bytes.length);
      return result?['hash'] as String?;
    }

    return _chunkedUpload(
      uid: uid,
      password: password,
      fileName: fileName,
      bytes: bytes,
      filePath: filePath,
      onProgress: onProgress,
    );
  }

  Future<String?> _chunkedUpload({
    required int uid,
    required String password,
    required String fileName,
    required Uint8List bytes,
    String? filePath,
    required void Function(int transferred) onProgress,
  }) async {
    final totalChunks = (bytes.length / kUploadChunkSize).ceil();
    final expectedHash = await computeSha256(bytes);

    // 秒传预检：服务端已存在同内容时直接返回哈希，跳过逐块上传。
    final instant = await TfApiClient.instance.instantUpload(
      uid,
      password,
      fileName,
      expectedHash,
    );
    if (instant != null && instant['instant'] == true) {
      final hash = (instant['file_hash'] ?? instant['hash']) as String?;
      if (hash != null) {
        if (filePath != null) await _clearSession(filePath);
        onProgress(bytes.length);
        return hash;
      }
    }

    // 尝试恢复断点续传会话。
    UploadSession? session;
    if (filePath != null) {
      session = await _loadSession(filePath);
    }

    String? fileId = session?.sessionId;
    final uploadedChunks = <int>{...?session?.uploadedChunks};
    var transferredBase = uploadedChunks.length * kUploadChunkSize;

    for (var i = 0; i < totalChunks; i++) {
      if (uploadedChunks.contains(i)) continue;

      final start = i * kUploadChunkSize;
      final end = (i + 1) * kUploadChunkSize > bytes.length
          ? bytes.length
          : (i + 1) * kUploadChunkSize;
      final chunkBytes = bytes.sublist(start, end);
      final chunkBase64 = base64Encode(chunkBytes);

      // 分块内进度：当前块已传输字节 + 已完成块字节。
      final result = await TfApiClient.instance.uploadChunk(
        uid: uid,
        password: password,
        fileName: fileName,
        chunkIndex: i,
        chunkTotal: totalChunks,
        chunkData: chunkBase64,
        fileId: fileId,
        expectedHash: expectedHash,
        onProgress: (sent, total) {
          final withinChunk = total > 0 ? (sent / total) * chunkBytes.length : 0;
          onProgress(
            (transferredBase + withinChunk).clamp(0, bytes.length).toInt(),
          );
        },
      );

      if (result == null) {
        // 传输失败：保留已成功分块记录，等待下次续传。
        if (filePath != null && fileId != null) {
          await _saveSession(
            UploadSession(
              sessionId: fileId,
              filePath: filePath,
              fileName: fileName,
              fileSize: bytes.length,
              chunkSize: kUploadChunkSize,
              totalChunks: totalChunks,
              uploadedChunks: uploadedChunks,
              expectedHash: expectedHash,
              createdAt: session?.createdAt ?? DateTime.now(),
              expiresAt: session?.expiresAt ??
                  DateTime.now().add(const Duration(hours: 1)),
            ),
          );
        }
        return null;
      }

      // 首次分块：服务端返回 file_id（会话 ID）。
      final returnedFileId = result['file_id'] as String?;
      if (returnedFileId != null) {
        fileId = returnedFileId;
      }

      uploadedChunks.add(i);
      transferredBase = uploadedChunks.length * kUploadChunkSize;
      onProgress(transferredBase.clamp(0, bytes.length).toInt());

      // 持久化会话（用于断点续传）。
      if (filePath != null && fileId != null) {
        await _saveSession(
          UploadSession(
            sessionId: fileId,
            filePath: filePath,
            fileName: fileName,
            fileSize: bytes.length,
            chunkSize: kUploadChunkSize,
            totalChunks: totalChunks,
            uploadedChunks: uploadedChunks,
            expectedHash: expectedHash,
            createdAt: session?.createdAt ?? DateTime.now(),
            expiresAt: session?.expiresAt ??
                DateTime.now().add(const Duration(hours: 1)),
          ),
        );
      }

      // 最后一个分块：返回 file_hash。
      if (i == totalChunks - 1) {
        final hash = result['file_hash'] as String? ?? result['hash'] as String?;
        if (hash != null) {
          await _clearSession(filePath);
          return hash;
        }
      }
    }

    return null;
  }

  /// 下载文件到本地路径，返回保存路径与任务 ID；失败时 savedPath 为 null。
  Future<({String? savedPath, String taskId})> downloadFile({
    required String url,
    required String fileName,
    required String savePath,
    String? clientMid,
    required TaskManager taskManager,
    int expectedSize = -1,
  }) async {
    final taskId = taskManager.addTask(
      FileTask(
        id: generateFileTaskId('download'),
        type: FileTaskType.download,
        status: FileTaskStatus.preparing,
        fileName: fileName,
        fileSize: expectedSize,
        clientMid: clientMid,
        createdAt: DateTime.now(),
      ),
    );

    try {
      taskManager.updateTask(taskId, status: FileTaskStatus.transferring);

      // `.download()` 的 response.data 是 ResponseBody（无 length），不能拿它当字节数；
      // 用进度回调累计的 received 作为真实已传输字节。
      var receivedBytes = 0;
      final response = await _downloadDio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          receivedBytes = received;
          taskManager.updateTask(
            taskId,
            status: FileTaskStatus.transferring,
            bytesTransferred: received,
          );
        },
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );

      final statusCode = response.statusCode ?? 0;
      if (statusCode < 200 || statusCode >= 300) {
        taskManager.updateTask(
          taskId,
          status: FileTaskStatus.failed,
          errorMessage: 'http_$statusCode',
        );
        return (savedPath: null, taskId: taskId);
      }

      taskManager.updateTask(
        taskId,
        status: FileTaskStatus.completed,
        savePath: savePath,
        bytesTransferred: expectedSize > 0 ? expectedSize : receivedBytes,
      );
      return (savedPath: savePath, taskId: taskId);
    } catch (e) {
      talker.error('FileService.downloadFile failed', e);
      taskManager.updateTask(
        taskId,
        status: FileTaskStatus.failed,
        errorMessage: e.toString(),
      );
      return (savedPath: null, taskId: taskId);
    }
  }

  // --- SHA256 ---

  /// 计算字节的 SHA256（十六进制字符串）。
  Future<String> computeSha256(List<int> bytes) {
    // 大文件哈希在 isolate 中计算，避免阻塞 UI。
    return compute(
      _sha256Isolate,
      Uint8List.fromList(bytes),
    );
  }

  static String _sha256Isolate(Uint8List bytes) {
    return sha256.convert(bytes).toString();
  }

  // --- 会话持久化 ---

  Future<UploadSession?> _loadSession(String filePath) async {
    final prefs = await SharedPreferences.getInstance();
    return UploadSession.decode(prefs.getString('$_kSessionKeyPrefix$filePath'));
  }

  Future<void> _saveSession(UploadSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_kSessionKeyPrefix${session.filePath}',
      session.encode(),
    );
  }

  Future<void> _clearSession(String? filePath) async {
    if (filePath == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_kSessionKeyPrefix$filePath');
  }
}

/// 供 `compute` 使用的顶层入口。
String sha256OfBytes(Uint8List bytes) => FileService._sha256Isolate(bytes);
