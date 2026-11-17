import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../utils/talker.dart';
import '../widgets/app_alert_dialog.dart';
import '../widgets/markdown_renderer.dart';
import 'app_update_service.dart';

class AppUpdateFlow {
  AppUpdateFlow._();
  static final AppUpdateFlow instance = AppUpdateFlow._();

  bool _running = false;

  /// 只做一次静默检查
  Future<VersionCheckResult?> checkQuietly() async {
    try {
      return await AppUpdateService.instance.checkForUpdate();
    } catch (error, stackTrace) {
      talker.error('Manual update check failed', error, stackTrace);
      return null;
    }
  }

  /// 把检查结果反馈给用户
  Future<void> presentResult(
    BuildContext context,
    VersionCheckResult result,
  ) async {
    if (!context.mounted) return;

    if (result.hasUpdate) {
      await promptIfNeeded(
        context,
        remoteVersion: result.remoteVersion,
        currentVersion: result.currentVersion,
        changes: result.changes,
      );
      return;
    }

    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.error != null
              ? (l10n?.aboutUpdateCheckFailed ?? 'Cannot reach update server')
              : (l10n?.aboutUpdateUpToDate ?? 'Already up to date'),
        ),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 16,
          left: 16,
          right: 16,
        ),
      ),
    );
  }

  /// 检查一次结果反馈
  Future<VersionCheckResult?> checkManually(BuildContext context) async {
    if (!context.mounted) return null;
    final result = await checkQuietly();
    if (result == null || !context.mounted) return result;
    await presentResult(context, result);
    return result;
  }

  /// 展示更新提示
  Future<void> promptIfNeeded(
    BuildContext context, {
    required String? remoteVersion,
    required String? currentVersion,
    List<String> changes = const [],
    bool force = false,
  }) async {
    if (_running || !context.mounted) return;
    // 非强制场景下必须知道远端版本
    if (!force && remoteVersion == null) return;
    _running = true;
    try {
      final l10n = AppLocalizations.of(context);
      final targetVersion = remoteVersion ?? currentVersion ?? '';

      String? changelog;
      if (changes.isEmpty) {
        try {
          changelog = await AppUpdateService.instance.fetchChangelog();
        } catch (_) {
          changelog = null;
        }
        if (!context.mounted) return;
      }

      final message = l10n?.updateAvailableMessage(
            currentVersion ?? '',
            targetVersion,
          ) ??
          'Current: $currentVersion\nLatest: $targetVersion';

      final shouldUpdate = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          return buildTouchFishInfoDialog(
            dialogContext,
            title: l10n?.updateAvailableTitle,
            icon: Icons.system_update_alt_rounded,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                if (changes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Text(
                    l10n?.updateChangelogTitle ?? 'Changelog',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final change in changes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('•  ', style: Theme.of(context).textTheme.bodyMedium),
                          Expanded(
                            child: Text(
                              change,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                ] else if (changelog != null && changelog.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Text(
                    l10n?.updateChangelogTitle ?? 'Changelog',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          dialogContext,
                        ).colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(
                            dialogContext,
                          ).colorScheme.outlineVariant,
                        ),
                      ),
                      child: MarkdownRenderer(data: changelog),
                    ),
                  ),
                ],
              ],
            ),
            actionWidgets: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n?.updateLater ?? 'Later'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n?.updateNow ?? 'Update now'),
              ),
            ],
          );
        },
      );

      if (shouldUpdate == true && context.mounted) {
        await _performUpdateFlow(context, targetVersion);
      }
    } finally {
      _running = false;
    }
  }

  /// 强制完整更新流程
  Future<void> forceUpdateFlow(BuildContext context, {String? version}) async {
    if (!context.mounted) return;
    final service = AppUpdateService.instance;
    final result = await service.forceUpdateCheck();
    if (!context.mounted) return;
    final target = version ?? result.remoteVersion ?? await service.currentVersion();
    if (target == null || !context.mounted) return;
    await promptIfNeeded(
      context,
      remoteVersion: target,
      currentVersion: result.currentVersion,
      changes: result.changes,
      force: true,
    );
  }

  Future<void> _performUpdateFlow(
    BuildContext context,
    String remoteVersion,
  ) async {
    if (remoteVersion.isEmpty) return;
    final service = AppUpdateService.instance;
    final target = await AppUpdateService.resolveUpdateTarget(remoteVersion);
    if (!context.mounted) return;

    switch (target.delivery) {
      case UpdateDelivery.installer:
        await _runDownloadThenExit(context, target.downloadUrl!, onComplete: () async {
          return service.downloadUpdate(target.downloadUrl!);
        }, afterDownload: (path) async {
          await service.launchFile(path!);
          exit(0);
        });
      case UpdateDelivery.diskImage:
        await _runDownloadThenExit(context, target.downloadUrl!, onComplete: () async {
          return service.downloadUpdate(target.downloadUrl!);
        }, afterDownload: (path) async {
          // 打开 DMG 会挂载卷，用户在 Finder 里把应用拖进「应用程序」即完成替换。
          await service.revealFile(path!);
          if (context.mounted) {
            final l10n = AppLocalizations.of(context);
            await showTouchFishInfoDialog<void>(
              context,
              title: l10n?.updateDownloadedTitle,
              message: l10n?.updateDmgHint ??
                  'The disk image is mounted. Drag the app into Applications '
                      'to finish updating.',
              actions: [
                TouchFishDialogAction(label: l10n?.commonOk ?? 'OK'),
              ],
            );
          }
          exit(0);
        });
      case UpdateDelivery.apk:
        await _performAndroidUpdateFlow(context, target.downloadUrl!);
      case UpdateDelivery.external:
        await _openExternalUpdatePage(context, target);
    }
  }
  Future<void> _openExternalUpdatePage(
    BuildContext context,
    UpdateTarget target,
  ) async {
    final l10n = AppLocalizations.of(context);
    final pageUrl = target.pageUrl.toString();
    final confirmed = await showTouchFishInfoDialog<bool>(
      context,
      title: l10n?.updateManualTitle ?? 'Get the update manually',
      message:
          l10n?.updateManualMessage(pageUrl) ??
          'This platform is managed by its package manager, so the app will '
              'not replace its own files.\n\nPlease download the new version '
              'from:\n$pageUrl',
      actions: [
        TouchFishDialogAction(
          label: l10n?.updateLater ?? 'Later',
          result: false,
        ),
        TouchFishDialogAction(
          label: l10n?.updateOpenReleasePage ?? 'Open release page',
          result: true,
          isPrimary: true,
        ),
      ],
    );
    if (confirmed != true) return;

    try {
      final opened = await launchUrl(
        target.pageUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        talker.warning('Failed to open release page at $pageUrl');
      }
    } catch (error, stackTrace) {
      talker.error('Failed to open release page', error, stackTrace);
    }
  }

  /// Android 更新流程：
  /// 1. 先弹确认框，展示 APK 将保存的位置；
  /// 2. 用户确认后才开始下载；
  /// 3. 下载完成后直接运行 APK（触发系统安装器），进程不自杀。
  Future<void> _performAndroidUpdateFlow(
    BuildContext context,
    String downloadUrl,
  ) async {
    final service = AppUpdateService.instance;
    final l10n = AppLocalizations.of(context);
    if (!context.mounted) return;

    // 预计算 APK 保存路径（供确认框展示）。
    final String apkPath;
    try {
      apkPath = await AppUpdateService.downloadPathFor(downloadUrl);
    } catch (error, stackTrace) {
      talker.error('Failed to compute APK path', error, stackTrace);
      if (context.mounted) {
        await showTouchFishErrorDialog<void>(
          context,
          title: l10n?.updateDownloadFailedTitle,
          message: l10n?.updateDownloadFailedMessage ??
              'Update download failed. Please check your network and try again.',
        );
      }
      return;
    }
    if (!context.mounted) return;

    // 第一步：确认下载提示框，展示 APK 将保存的位置。
    final confirmed = await showTouchFishInfoDialog<bool>(
      context,
      title: l10n?.updateDownloadStartTitle ?? 'Start download',
      message: l10n?.updateApkSaveHint(apkPath) ??
          'The APK will be downloaded to:\n$apkPath',
      actions: [
        TouchFishDialogAction(
          label: l10n?.updateLater ?? 'Later',
          result: false,
        ),
        TouchFishDialogAction(
          label: l10n?.updateNow ?? 'Download now',
          result: true,
          isPrimary: true,
        ),
      ],
    );
    if (confirmed != true || !context.mounted) return;

    // 第二步：用户确认后开始下载（显示下载中对话框）。
    String? path;
    final l10nDownload = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Text(
                l10nDownload?.updateDownloading ?? 'Downloading update...',
              ),
            ),
          ],
        ),
      ),
    );
    path = await service.downloadUpdate(downloadUrl);
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (path == null) {
      if (context.mounted) {
        final l10nError = AppLocalizations.of(context);
        await showTouchFishErrorDialog<void>(
          context,
          title: l10nError?.updateDownloadFailedTitle,
          message: l10nError?.updateDownloadFailedMessage ??
              'Update download failed. Please check your network and try again.',
        );
      }
      return;
    }

    // 第三步：下载完成，直接打开 APK 触发系统安装器。
    // 注意：Android 端进程不自杀退出。
    if (context.mounted) {
      await service.revealFile(path);
    }
  }

  Future<void> _runDownloadThenExit(
    BuildContext context,
    String downloadUrl, {
    required Future<String?> Function() onComplete,
    required Future<void> Function(String? path) afterDownload,
  }) async {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Text(l10n?.updateDownloading ?? 'Downloading update...'),
            ),
          ],
        ),
      ),
    );
    final path = await onComplete();
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (path == null) {
      if (context.mounted) {
        final l10nError = AppLocalizations.of(context);
        await showTouchFishErrorDialog<void>(
          context,
          title: l10nError?.updateDownloadFailedTitle,
          message: l10nError?.updateDownloadFailedMessage ?? 'Update download failed.',
        );
      }
      return;
    }
    await afterDownload(path);
  }
}