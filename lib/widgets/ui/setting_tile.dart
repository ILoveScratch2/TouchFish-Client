import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// 设置类页面的行组件
class SettingNavTile extends StatelessWidget {
  const SettingNavTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  /// 覆盖默认的右箭头
  final Widget? trailing;

  /// 置灰
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final subtitle = this.subtitle;
    return ListTile(
      leading: Icon(
        icon,
        color: enabled ? null : colorScheme.onSurfaceVariant.withValues(
          alpha: 0.38,
        ),
      ),
      title: Text(
        title,
        style: enabled
            ? null
            : TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.38)),
      ),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing:
          trailing ??
          Icon(
            Icons.chevron_right_rounded,
            color: enabled
                ? null
                : colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
          ),
      enabled: enabled,
      onTap: enabled ? onTap : null,
    );
  }
}

/// 设置页的开关行
class SettingSwitchTile extends StatelessWidget {
  const SettingSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    final handler = busy ? null : onChanged;
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      value: value,
      onChanged: handler,
    );
  }
}

/// 设置页的普通行
class SettingTile extends StatelessWidget {
  const SettingTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// 危险操作
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tone = destructive ? colorScheme.error : null;
    final subtitle = this.subtitle;
    return ListTile(
      leading: Icon(icon, color: tone),
      title: Text(title, style: tone == null ? null : TextStyle(color: tone)),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

/// 设置页的分区标题
class SettingSectionHeader extends StatelessWidget {
  const SettingSectionHeader({
    super.key,
    required this.title,
    this.description,
  });

  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = this.description;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TFSpace.lg,
        TFSpace.lg,
        TFSpace.lg,
        TFSpace.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: TFSpace.xxs),
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
