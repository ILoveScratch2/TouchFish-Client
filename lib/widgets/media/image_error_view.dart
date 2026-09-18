import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';

import '../../utils/blurhash_utils.dart';

/// 图片加载失败😭
/// 
/// - 按 HTTP 状态码分级图标（401/403 锁、404 破损图、5xx 错误）
class ImageErrorView extends StatelessWidget {
  final String? blurhash;
  final Object? error;
  final BoxFit fit;

  const ImageErrorView({
    super.key,
    this.blurhash,
    this.error,
    this.fit = BoxFit.cover,
  });

  /// flutter_cache_manager / http 抛出的 `Invalid statusCode: 500` 形式。
  static final RegExp _statusPattern = RegExp(r'Invalid statusCode: (\d+)');

  int? get _statusCode {
    final match = _statusPattern.firstMatch('${error ?? ''}');
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  IconData get _icon {
    switch (_statusCode) {
      case 401:
      case 403:
        return Icons.lock_rounded;
      case 404:
        return Icons.broken_image_rounded;
      case 500:
      case 502:
      case 503:
        return Icons.error_rounded;
      default:
        return Icons.broken_image_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasBlur = isValidBlurHash(blurhash);
    final statusCode = _statusCode;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasBlur)
          BlurHash(
            hash: blurhash!,
            imageFit: fit,
            duration: Duration.zero,
          )
        else
          ColoredBox(color: scheme.surfaceContainerHighest),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _icon,
                size: 32,
                color: hasBlur ? Colors.white : scheme.onSurfaceVariant,
                shadows: hasBlur
                    ? const [
                        Shadow(color: Colors.black54, blurRadius: 6),
                      ]
                    : null,
              ),
              if (statusCode != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$statusCode',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
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
