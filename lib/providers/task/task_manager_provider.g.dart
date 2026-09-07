// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_manager_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$taskManagerHash() => r'c558c3365840f759e81945d3f95a728090d9dfbc';

/// 全局文件传输任务管理器。
///
/// 维护所有进行中/刚完成的上传、下载任务，供全局浮层与消息气泡
/// 响应式读取。完成或失败的任务由调用方决定何时移除（浮层会自动清理）。
///
/// Copied from [TaskManager].
@ProviderFor(TaskManager)
final taskManagerProvider =
    AutoDisposeNotifierProvider<TaskManager, List<FileTask>>.internal(
      TaskManager.new,
      name: r'taskManagerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$taskManagerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$TaskManager = AutoDisposeNotifier<List<FileTask>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
