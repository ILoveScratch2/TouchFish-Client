import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
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

  /// 上传字节并返回服务端文件哈希（失败返回 null）。
  ///
  /// ≤ [kStandardUploadThreshold] 走单请求，更大的自动分块；供不方便接入
  /// [TaskManager] 的页面使用（论坛附件、存储管理）。聊天消息仍走
  /// [uploadFile] 以便在传输面板里展示进度。不传 [filePath] 就不做断点续传
  /// 会话持久化（避免不同文件复用同一个会话键）。
  Future<String?> uploadBytes({
    required int uid,
    required String password,
    required String fileName,
    required List<int> bytes,
    String? filePath,
    void Function(int transferred)? onProgress,
  }) async {
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    try {
      return await _uploadInternal(
        uid: uid,
        password: password,
        fileName: fileName,
        bytes: data,
        filePath: filePath,
        onProgress: onProgress ?? (_) {},
      );
    } catch (e) {
      talker.error('FileService.uploadBytes failed', e);
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
    final baseUrl = filePath == null
        ? null
        : await TfApiClient.instance.getBaseUrl();
    final sessionKey = filePath == null
        ? null
        : '$_kSessionKeyPrefix${jsonEncode([baseUrl, uid, filePath, expectedHash, fileName])}';
    final prefs = sessionKey == null
        ? null
        : await SharedPreferences.getInstance();

    // 秒传预检：服务端已存在同内容时直接返回哈希，跳过逐块上传。
    final instant = await TfApiClient.instance.instantUpload(
      uid,
      password,
      fileName,
      expectedHash,
    );
    final instantHash = instant?['file_hash'] ?? instant?['hash'];
    if (instant?['instant'] == true && instantHash == expectedHash) {
      if (prefs != null && sessionKey != null) await prefs.remove(sessionKey);
      onProgress(bytes.length);
      return expectedHash;
    }

    var session = prefs == null || sessionKey == null
        ? null
        : UploadSession.decode(prefs.getString(sessionKey));
    if (session != null &&
        !session.canResume(
          hash: expectedHash,
          name: fileName,
          size: bytes.length,
          bytesPerChunk: kUploadChunkSize,
          chunks: totalChunks,
        )) {
      session = null;
      await prefs!.remove(sessionKey!);
    }

    var retryFromStart = session != null;
    String fileId = session?.sessionId ?? _newUploadId();
    final uploadedChunks = <int>{...?session?.uploadedChunks};
    var transferredBase = uploadedChunks.length * kUploadChunkSize;

    Future<void> persistSession() async {
      if (prefs == null || sessionKey == null || filePath == null) return;
      final now = DateTime.now();
      final updated = UploadSession(
        sessionId: fileId,
        filePath: filePath,
        fileName: fileName,
        fileSize: bytes.length,
        chunkSize: kUploadChunkSize,
        totalChunks: totalChunks,
        uploadedChunks: uploadedChunks,
        expectedHash: expectedHash,
        createdAt: session?.createdAt ?? now,
        expiresAt: now.add(const Duration(hours: 1)),
      );
      session = updated;
      await prefs.setString(sessionKey, updated.encode());
    }

    if (session == null) await persistSession();
    for (var i = 0; i < totalChunks; i++) {
      if (uploadedChunks.contains(i)) continue;

      final start = i * kUploadChunkSize;
      final end = (start + kUploadChunkSize).clamp(0, bytes.length);
      final chunkBytes = bytes.sublist(start, end);
      final result = await TfApiClient.instance.uploadChunk(
        uid: uid,
        password: password,
        fileName: fileName,
        chunkIndex: i,
        chunkTotal: totalChunks,
        chunkData: base64Encode(chunkBytes),
        fileId: fileId,
        expectedHash: expectedHash,
        onProgress: (sent, total) {
          final withinChunk = total > 0
              ? (sent / total) * chunkBytes.length
              : 0;
          onProgress(
            (transferredBase + withinChunk).clamp(0, bytes.length).toInt(),
          );
        },
      );

      if (result == null) return null;
      final error = result['error'];
      if (result['success'] == false || error != null) {
        final invalidSession = switch (error) {
          'FILE_INVALID_FILE_ID' ||
          'FILE_NAME_MISMATCH' ||
          'FILE_CHUNK_TOTAL_MISMATCH' ||
          'FILE_HASH_MISMATCH' ||
          'FILE_HASH_VERIFICATION_FAILED' ||
          'FILE_MISSING_CHUNK' => true,
          _ => false,
        };
        if (invalidSession && prefs != null && sessionKey != null) {
          await prefs.remove(sessionKey);
        }
        if (!invalidSession || !retryFromStart) return null;
        retryFromStart = false;
        session = null;
        fileId = _newUploadId();
        uploadedChunks.clear();
        transferredBase = 0;
        onProgress(0);
        await persistSession();
        i = -1;
        continue;
      }

      final hash = result['file_hash'] ?? result['hash'];
      if (hash == expectedHash) {
        if (prefs != null && sessionKey != null) await prefs.remove(sessionKey);
        onProgress(bytes.length);
        return expectedHash;
      }

      if (i == totalChunks - 1) return null;
      final uploadId = result['file_id'];
      if (uploadId is! String || uploadId.isEmpty) return null;
      fileId = uploadId;
      uploadedChunks.add(i);
      transferredBase += chunkBytes.length;
      onProgress(transferredBase);

      await persistSession();
    }

    return null;
  }

  String _newUploadId() {
    final random = Random.secure();
    return sha256
        .convert(List.generate(32, (_) => random.nextInt(256)))
        .toString();
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
      await writeDownloadAtomically(savePath, (temporaryPath) async {
        await _downloadDio.download(
          url,
          temporaryPath,
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
      });

      taskManager.updateTask(
        taskId,
        status: FileTaskStatus.completed,
        savePath: savePath,
        bytesTransferred: receivedBytes,
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
    return compute(_sha256Isolate, Uint8List.fromList(bytes));
  }

  static String _sha256Isolate(Uint8List bytes) {
    return sha256.convert(bytes).toString();
  }
}

Future<void> writeDownloadAtomically(
  String savePath,
  Future<void> Function(String temporaryPath) write,
) async {
  final destination = File(savePath).absolute;
  final temporaryDirectory = await destination.parent.createTemp(
    '.touchfish-download-',
  );
  try {
    final temporaryFile = File(p.join(temporaryDirectory.path, 'download'));
    await write(temporaryFile.path);
    await temporaryFile.rename(destination.path);
  } finally {
    try {
      await temporaryDirectory.delete(recursive: true);
    } on FileSystemException catch (error) {
      talker.warning('Failed to clean up temporary download', error);
    }
  }
}

/// 供 `compute` 使用的顶层入口。
String sha256OfBytes(Uint8List bytes) => FileService._sha256Isolate(bytes);
