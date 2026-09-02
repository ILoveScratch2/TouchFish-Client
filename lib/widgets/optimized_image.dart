import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../services/file_cache_service.dart';

/// 计算图片解码的缓存！
({int? width, int? height}) imageDecodeSize(
  double devicePixelRatio, {
  double? width,
  double? height,
}) {
  if (kIsWeb) return (width: null, height: null);
  return (
    width:
        width != null && width > 0 ? (width * devicePixelRatio).round() : null,
    height: height != null && height > 0
        ? (height * devicePixelRatio).round()
        : null,
  );
}


ImageProvider resizedImageProvider(
  ImageProvider provider,
  double devicePixelRatio, {
  double? width,
  double? height,
}) {
  if (kIsWeb) return provider;
  final size = imageDecodeSize(devicePixelRatio, width: width, height: height);
  if (size.width == null && size.height == null) return provider;
  return ResizeImage(
    provider,
    width: size.width,
    height: size.height,
    policy: ResizeImagePolicy.fit,
  );
}

/// 按实际渲染尺寸下采样解码的图片。
///
/// 网络图片通过磁盘缓存（FileCacheService）加载，支持离线查看。
class OptimizedImage extends StatelessWidget {
  final ImageProvider provider;
  final BoxFit fit;
  final bool gaplessPlayback;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageFrameBuilder? frameBuilder;

  const OptimizedImage({
    super.key,
    required this.provider,
    this.fit = BoxFit.contain,
    this.gaplessPlayback = false,
    this.errorBuilder,
    this.frameBuilder,
  });

  Widget _placeholder(BuildContext context) => Container(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const Center(
      child: SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );

  Widget _broken(BuildContext context) => Container(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Icon(
      Icons.broken_image,
      color: Theme.of(context).colorScheme.onErrorContainer,
    ),
  );

  Widget _error(BuildContext context, Object error) => errorBuilder != null
      ? errorBuilder!(context, error, StackTrace.current)
      : _broken(context);

  @override
  Widget build(BuildContext context) {
    // 网络图片走磁盘缓存
    if (provider is NetworkImage) {
      final networkImage = provider as NetworkImage;
      return LayoutBuilder(
        builder: (context, constraints) {
          final size = imageDecodeSize(
            MediaQuery.of(context).devicePixelRatio,
            width: constraints.hasBoundedWidth ? constraints.maxWidth : null,
            height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
          );

          return FutureBuilder<CacheManager?>(
            future: FileCacheService.instance.getCacheManager(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                // 缓存管理器初始化中
                return _placeholder(context);
              }
              return CachedNetworkImage(
                imageUrl: networkImage.url,
                // web/无 path_provider 环境为 null，使用包默认缓存实现
                cacheManager: snapshot.data,
                fit: fit,
                memCacheWidth: size.width,
                memCacheHeight: size.height,
                placeholder: (context, url) => _placeholder(context),
                errorWidget: (context, url, error) => _error(context, error),
              );
            },
          );
        },
      );
    }

    // 本地/内存/其他 ImageProvider：按实际渲染尺寸下采样解码
    return LayoutBuilder(
      builder: (context, constraints) {
        var imageProvider = provider;
        if (!kIsWeb) {
          final size = imageDecodeSize(
            MediaQuery.of(context).devicePixelRatio,
            width: constraints.hasBoundedWidth ? constraints.maxWidth : null,
            height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
          );
          if (size.width != null || size.height != null) {
            imageProvider = ResizeImage(
              provider,
              width: size.width,
              height: size.height,
              policy: ResizeImagePolicy.fit,
            );
          }
        }
        return Image(
          image: imageProvider,
          fit: fit,
          gaplessPlayback: gaplessPlayback,
          errorBuilder: errorBuilder,
          frameBuilder: frameBuilder,
        );
      },
    );
  }
}
