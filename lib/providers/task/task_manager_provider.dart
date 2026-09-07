import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/file_task.dart';

part 'task_manager_provider.g.dart';

/// 全局文件传输任务管理器。
///
/// 维护所有进行中/刚完成的上传、下载任务，供全局浮层与消息气泡
/// 响应式读取。完成或失败的任务由调用方决定何时移除（浮层会自动清理）。
@riverpod
class TaskManager extends _$TaskManager {
  @override
  List<FileTask> build() => [];

  /// 添加任务并返回其 ID。
  String addTask(FileTask task) {
    state = [...state, task];
    return task.id;
  }

  /// 更新任务字段（只更新非空字段）。状态转为 completed/failed 时记录结束时间。
  void updateTask(
    String id, {
    FileTaskStatus? status,
    int? bytesTransferred,
    String? errorMessage,
    String? fileHash,
    String? savePath,
  }) {
    final now = DateTime.now();
    state = state.map((t) {
      if (t.id != id) return t;
      final nextStatus = status ?? t.status;
      final finished = nextStatus == FileTaskStatus.completed ||
          nextStatus == FileTaskStatus.failed;
      return t.copyWith(
        status: nextStatus,
        bytesTransferred: bytesTransferred ?? t.bytesTransferred,
        errorMessage: errorMessage ?? t.errorMessage,
        fileHash: fileHash ?? t.fileHash,
        savePath: savePath ?? t.savePath,
        finishedAt: finished
            ? (t.finishedAt ?? now)
            : null,
      );
    }).toList();
  }

  void removeTask(String id) {
    state = state.where((t) => t.id != id).toList();
  }

  /// 移除所有已完成/失败任务。
  void clearCompleted() {
    state = state
        .where(
          (t) =>
              t.status != FileTaskStatus.completed &&
              t.status != FileTaskStatus.failed,
        )
        .toList();
  }

  /// 清空所有任务。
  void clearAll() {
    state = [];
  }

  /// 按 clientMid 查找上传任务（消息气泡据此显示进度）。
  FileTask? byClientMid(String? clientMid) {
    if (clientMid == null) return null;
    for (final t in state) {
      if (t.clientMid == clientMid) return t;
    }
    return null;
  }

  /// 清理已完成或失败超过指定时长的任务。按 [FileTask.finishedAt]（无则
  /// 回退 createdAt）判龄，保证长任务完成后还能在详情面板停留一段可见时间。
  void pruneCompleted({Duration maxAge = const Duration(seconds: 8)}) {
    final now = DateTime.now();
    state = state.where((t) {
      if (t.status != FileTaskStatus.completed &&
          t.status != FileTaskStatus.failed) {
        return true;
      }
      return now.difference(t.finishedAt ?? t.createdAt) < maxAge;
    }).toList();
  }
}
