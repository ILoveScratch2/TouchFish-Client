import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../l10n/app_localizations.dart';
import '../models/file_task.dart';
import '../providers/task/task_manager_provider.dart';
import 'custom_title_bar.dart';
import 'sheet_scaffold.dart';

/// 全局文件传输
///
/// 当存在进行中的上传/下载任务时，在标题栏下方显示一条精简进度
class TaskOverlay extends ConsumerStatefulWidget {
  final BuildContext? Function()? navigatorContextProvider;

  const TaskOverlay({super.key, this.navigatorContextProvider});

  @override
  ConsumerState<TaskOverlay> createState() => _TaskOverlayState();
}

bool _isActive(FileTask t) =>
    t.status == FileTaskStatus.preparing ||
    t.status == FileTaskStatus.transferring;

bool _isFinished(FileTask t) =>
    t.status == FileTaskStatus.completed ||
    t.status == FileTaskStatus.failed;

/// 进度值：准备中或大小未知（下载）时返回 null，表示不确定进度。
double? _taskProgress(FileTask t) {
  if (t.status == FileTaskStatus.preparing) return null;
  if (t.status == FileTaskStatus.failed) return t.progress;
  final p = t.progress;
  if (p == null) return null;
  return p.clamp(0.0, 1.0);
}

Color _statusColor(ColorScheme cs, FileTask t) {
  switch (t.status) {
    case FileTaskStatus.completed:
      return Colors.green;
    case FileTaskStatus.failed:
      return cs.error;
    case FileTaskStatus.preparing:
    case FileTaskStatus.transferring:
      return cs.primary;
  }
}

IconData _statusIcon(FileTask t) {
  switch (t.status) {
    case FileTaskStatus.preparing:
      return Symbols.sync;
    case FileTaskStatus.transferring:
      return t.type == FileTaskType.upload
          ? Symbols.upload
          : Symbols.download;
    case FileTaskStatus.completed:
      return Symbols.check_circle;
    case FileTaskStatus.failed:
      return Symbols.error;
  }
}

String _statusLabel(AppLocalizations l10n, FileTask t) {
  switch (t.status) {
    case FileTaskStatus.preparing:
      return l10n.taskStatusPreparing;
    case FileTaskStatus.transferring:
      return t.type == FileTaskType.upload
          ? l10n.taskStatusUploading
          : l10n.taskStatusDownloading;
    case FileTaskStatus.completed:
      return l10n.taskStatusCompleted;
    case FileTaskStatus.failed:
      return l10n.taskStatusFailed;
  }
}

class _TaskOverlayState extends ConsumerState<TaskOverlay> {
  Timer? _pruneTimer;
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    // 每 3 秒清理一次已完成/失败超过 8 秒的任务
    _pruneTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      ref.read(taskManagerProvider.notifier).pruneCompleted();
    });
  }

  @override
  void dispose() {
    _pruneTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskManagerProvider);
    final active = tasks.where(_isActive).toList()..sort((a, b) {
      return a.createdAt.compareTo(b.createdAt);
    });

    final isDesktop =
        !kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    // 桌面端内容从自定义标题栏下方开始，浮层也要让开那 40px；
    // 移动端则从 SafeArea 下方开始。
    final topInset =
        MediaQuery.paddingOf(context).top +
        (isDesktop ? CustomTitleBar.height + 8 : 8);

    return Positioned(
      top: topInset,
      left: 0,
      right: 0,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.3),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
        child: active.isEmpty
            ? const SizedBox.shrink(key: ValueKey('task-overlay-hidden'))
            : Align(
                key: const ValueKey('task-overlay-visible'),
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _TaskOverlayPill(
                      task: active.first,
                      totalCount: active.length,
                      onTap: _showDetails,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _showDetails() async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    try {
      final navigator = widget.navigatorContextProvider?.call();
      final ctx = (navigator != null && navigator.mounted) ? navigator : context;
      await showModalBottomSheet<void>(
        context: ctx,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (_) => const _TasksSheet(),
      );
    } finally {
      _sheetOpen = false;
    }
  }
}

class _TaskOverlayPill extends ConsumerWidget {
  final FileTask task;
  final int totalCount;
  final VoidCallback onTap;

  const _TaskOverlayPill({
    required this.task,
    required this.totalCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = _statusColor(scheme, task);
    final progress = _taskProgress(task);
    final moreCount = totalCount - 1;
    final l10n = AppLocalizations.of(context)!;

    final subtitle = moreCount > 0
        ? '${task.speedFormatted} · ${l10n.taskMoreCount(moreCount)}'
        : task.speedFormatted;
    final percentText = progress == null ? '—' : task.progressLabel;

    return Semantics(
      button: true,
      label: task.fileName,
      child: Material(
        color: scheme.surfaceContainerHigh,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 10, 4),
                child: Row(
                  children: [
                    Icon(_statusIcon(task), size: 20, color: statusColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        task.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      percentText,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Symbols.expand_less,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: SizedBox(
                  height: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: _AnimatedProgressBar(
                      progress: progress,
                      color: statusColor,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 平滑到目标值的进度条：不确定进度时显示脉冲条。
class _AnimatedProgressBar extends StatelessWidget {
  final double? progress;
  final Color color;
  final Color backgroundColor;

  const _AnimatedProgressBar({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (progress == null) {
      return LinearProgressIndicator(
        value: null,
        minHeight: 3,
        color: color,
        backgroundColor: backgroundColor,
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progress!.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return LinearProgressIndicator(
          value: value,
          minHeight: 3,
          color: color,
          backgroundColor: backgroundColor,
        );
      },
    );
  }
}

class _TasksSheet extends ConsumerWidget {
  const _TasksSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final tasks = ref.watch(taskManagerProvider);
    final notifier = ref.read(taskManagerProvider.notifier);

    final sorted = [...tasks]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final hasFinished = tasks.any(_isFinished);

    return SheetScaffold(
      titleText: l10n.taskSheetTitle,
      actions: [
        IconButton(
          tooltip: l10n.taskClearFinished,
          onPressed: hasFinished ? notifier.clearCompleted : null,
          icon: const Icon(Symbols.done_all),
        ),
        IconButton(
          tooltip: l10n.taskClearAll,
          onPressed: tasks.isEmpty ? null : notifier.clearAll,
          icon: const Icon(Symbols.delete_sweep),
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.taskTotalCount(sorted.length),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            child: sorted.isEmpty
                ? _EmptyTasksState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
                    itemCount: sorted.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _TaskTile(key: ValueKey(sorted[index].id), task: sorted[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTasksState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Symbols.inbox, size: 32, color: scheme.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(
            l10n.taskNoTasks,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _StatusIcon({
    required this.icon,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(child: Icon(icon, color: color, size: size * 0.6)),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final FileTask task;

  const _TaskTile({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final statusColor = _statusColor(scheme, task);
    final progress = _taskProgress(task);

    return Semantics(
      container: true,
      child: Material(
        color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: _StatusIcon(
              icon: _statusIcon(task),
              color: statusColor,
              size: 38,
            ),
            title: Text(
              task.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              _statusLabel(AppLocalizations.of(context)!, task),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TaskProgressIndicator(progress: progress, color: statusColor),
                const SizedBox(width: 4),
                Icon(
                  Symbols.expand_more,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
            tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            shape: const RoundedRectangleBorder(),
            collapsedShape: const RoundedRectangleBorder(),
            children: [_TaskDetailsCard(task: task)],
          ),
        ),
      ),
    );
  }
}

/// 环形进度：确定进度时环心显示整数百分比；不确定时显示旋转环。
class _TaskProgressIndicator extends StatelessWidget {
  final double? progress;
  final Color color;

  const _TaskProgressIndicator({required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (progress == null) {
      return SizedBox(
        width: 42,
        height: 42,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          backgroundColor: scheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progress!.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return SizedBox(
          width: 42,
          height: 42,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: value,
                strokeWidth: 3,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
              Text(
                '${(value * 100).round()}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TaskDetailsCard extends StatelessWidget {
  final FileTask task;

  const _TaskDetailsCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final statusColor = _statusColor(scheme, task);
    final progress = _taskProgress(task);
    final isFailed = task.status == FileTaskStatus.failed;

    final percentText = progress == null
        ? '—'
        : '${(progress * 100).toStringAsFixed(1)}%';
    final transferredText = task.fileSize > 0
        ? '${FileTask.formatFileSize(task.bytesTransferred)} / ${task.sizeFormatted}'
        : FileTask.formatFileSize(task.bytesTransferred);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _statusLabel(l10n, task),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 7),
          _ProgressRow(left: percentText, right: transferredText),
          const SizedBox(height: 5),
          SizedBox(
            height: 7,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: _AnimatedProgressBar(
                progress: progress,
                color: statusColor,
                backgroundColor: scheme.surface,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            task.speedFormatted,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (isFailed && task.errorMessage != null) ...[
            const SizedBox(height: 12),
            _ErrorText(message: task.errorMessage!),
          ],
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String left;
  final String right;

  const _ProgressRow({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Row(
      children: [
        Expanded(
          child: Text(
            left,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: style?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorText extends StatelessWidget {
  final String message;

  const _ErrorText({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Symbols.error, size: 16, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
