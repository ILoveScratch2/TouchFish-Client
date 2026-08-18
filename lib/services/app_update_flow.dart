import 'dart:io';

import 'package:flutter/foundation.dart';
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

  Future<void> promptIfNeeded(
    BuildContext context, {
    required String? remoteVersion,
    required String? currentVersion,
  }) async {
    if (_running || remoteVersion == null || !context.mounted) return;
    _running = true;
    try {
      final l10n = AppLocalizations.of(context);
      // Fetch changelog (rendered as Markdown) for the update dialog.
      String? changelog;
      try {
        changelog = await AppUpdateService.instance.fetchChangelog();
      } catch (_) {
        changelog = null;
      }
      if (!context.mounted) return;

      final message = l10n?.updateAvailableMessage(
            currentVersion ?? '',
            remoteVersion,
          ) ??
          'Current: $currentVersion\nLatest: $remoteVersion';

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
                if (changelog != null && changelog.trim().isNotEmpty) ...[
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
        await _performUpdateFlow(context, remoteVersion);
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _performUpdateFlow(
    BuildContext context,
    String remoteVersion,
  ) async {
    final service = AppUpdateService.instance;
    final downloadUrl = AppUpdateService.downloadUrlFor(remoteVersion);

    if (!kIsWeb && Platform.isWindows) {
      await _runDownloadThenExit(context, downloadUrl, onComplete: () async {
        final path = await service.downloadUpdate(downloadUrl);
        return path;
      }, afterDownload: (path) async {
        await service.launchFile(path!);
        exit(0);
      });
      return;
    }

    if (!kIsWeb && (Platform.isMacOS || Platform.isLinux)) {
      await _runDownloadThenExit(context, downloadUrl, onComplete: () async {
        final path = await service.downloadUpdate(downloadUrl);
        return path;
      }, afterDownload: (path) async {
        await service.revealFile(path!);
        if (context.mounted) {
          final l10n = AppLocalizations.of(context);
          await showTouchFishInfoDialog<void>(
            context,
            title: l10n?.updateDownloadedTitle,
            message: l10n?.updateExtractHint ?? 'Update downloaded. Please extract manually.',
            actions: [
              TouchFishDialogAction(label: l10n?.commonOk ?? 'OK'),
            ],
          );
        }
        exit(0);
      });
      return;
    }

    if (!kIsWeb && Platform.isAndroid) {
      await _performAndroidUpdateFlow(context, downloadUrl);
      return;
    }

    await launchUrl(Uri.parse(downloadUrl));
  }

  /// Android 更新流程：
  /// 1. 先弹「需要先卸载」确认框，并在框内展示 APK 保存位置；
  /// 2. 用户确认后才开始下载；
  /// 3. 下载完成后进程不自杀，打开文件管理器跳转到 APK 所在位置。
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

    // 第一步：确认「先卸载」的提示框，同时展示 APK 将保存的位置。
    final confirmed = await showTouchFishInfoDialog<bool>(
      context,
      title: l10n?.updateUninstallTitle,
      message: l10n?.updateUninstallMessageWithPath(apkPath) ??
          'Please uninstall the current app first.\nAPK will be saved to: $apkPath',
      actions: [
        TouchFishDialogAction(
          label: l10n?.commonCancel ?? 'Cancel',
          result: false,
        ),
        TouchFishDialogAction(
          label: l10n?.updateUninstallConfirm ?? 'Uninstall',
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

    // 第三步：下载完成，打开文件管理器跳转到 APK 所在位置。
    // 注意：Android 端进程不自杀退出，由用户自行卸载后安装。
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