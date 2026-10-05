import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'app_alert_dialog.dart';

/// 管理后台通用页面
class AdminPageScaffold extends StatelessWidget {
  const AdminPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.maxWidth = 640,
    this.actions,
    this.bottomNavigationBar,
    this.floatingActionButton,
  });

  final String title;
  final Widget body;
  final double maxWidth;
  final List<Widget>? actions;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: body,
        ),
      ),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}

/// 带图标徽章的分区标题：图标容器 + 标题 + 可选描述。
class AdminSectionHeader extends StatelessWidget {
  const AdminSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.description,
  });

  final IconData icon;
  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final description = this.description;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: colorScheme.onPrimaryContainer),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (description != null) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 空态占位：图标 + 文案 + 可选操作。
///
/// 内部自带可滚动壳（minHeight 铺满），可直接放进 RefreshIndicator。
class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return _AdminStatusView(icon: icon, message: message, action: action);
  }
}

/// 加载失败占位：泛化文案 + 重试按钮（不要传原始异常串）。
class AdminErrorState extends StatelessWidget {
  const AdminErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.icon = Icons.error_outline_rounded,
  });

  final String message;
  final VoidCallback onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _AdminStatusView(
      icon: icon,
      message: message,
      action: FilledButton.tonalIcon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: Text(l10n.retry),
      ),
    );
  }
}

class _AdminStatusView extends StatelessWidget {
  const _AdminStatusView({
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final action = this.action;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 56, color: colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (action != null) ...[
                    const SizedBox(height: 20),
                    action,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 管理后台搜索框：与服务器设置页同款的填充圆角样式。
class AdminSearchField extends StatelessWidget {
  const AdminSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        autofocus: autofocus,
        keyboardType: keyboardType,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  tooltip: l10n.cancel,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    controller.clear();
                    onChanged?.call('');
                  },
                ),
          isDense: true,
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

/// 管理员确认对话框：统一语气与按钮样式。
///
/// [destructive] 为 true 时用警示图标与危险色确认按钮（删除/封禁等）。
Future<bool> showAdminConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  Widget? content,
  IconData? icon,
  bool destructive = false,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showTouchFishInfoDialog<bool>(
    context,
    title: title,
    message: message,
    content: content,
    icon:
        icon ??
        (destructive
            ? Icons.warning_amber_rounded
            : Icons.help_outline_rounded),
    actions: [
      TouchFishDialogAction<bool>(label: l10n.cancel),
      TouchFishDialogAction<bool>(
        label: confirmLabel,
        result: true,
        isPrimary: true,
        isDestructive: destructive,
      ),
    ],
  );
  return confirmed == true;
}
