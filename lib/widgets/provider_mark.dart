import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 内置识别的第三方平台标识
const Map<String, String> _providerAssets = {
  'github': 'assets/provider_icons/github.svg',
  'google': 'assets/provider_icons/google.svg',
  'apple': 'assets/provider_icons/apple.svg',
  'microsoft': 'assets/provider_icons/microsoft.svg',
  'discord': 'assets/provider_icons/discord.svg',
};

/// 多色 logo（Google 的四色 G、微软的四格）保持原色
const Set<String> _keepOriginalColors = {'google', 'microsoft'};


String normalizeProviderId(String raw) =>
    raw.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// 平台是否内置了品牌图标。false 时调用方应显示名称而不是图标。
bool hasProviderIcon(String providerId) =>
    _providerAssets.containsKey(normalizeProviderId(providerId));

/// 第三方平台的品牌图标
class ProviderMark extends StatelessWidget {
  const ProviderMark({
    super.key,
    required this.providerId,
    this.size = 20,
    this.color,
  });

  final String providerId;
  final double size;

  /// 单色标使用的颜色
  /// 多色标忽略此值
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final key = normalizeProviderId(providerId);
    final asset = _providerAssets[key];
    final tintColor = color ?? Theme.of(context).colorScheme.onSurfaceVariant;

    if (asset == null) {
      return Icon(Icons.login, size: size, color: tintColor);
    }

    final tint = _keepOriginalColors.contains(key)
        ? null
        : ColorFilter.mode(tintColor, BlendMode.srcIn);

    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: tint,
      errorBuilder: (context, _, _) =>
          Icon(Icons.login, size: size, color: tintColor),
      placeholderBuilder: (_) => SizedBox(width: size, height: size),
    );
  }
}
