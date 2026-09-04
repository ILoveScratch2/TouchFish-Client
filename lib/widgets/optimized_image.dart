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
class OptimizedImage extends StatefulWidget {
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

  @override
  State<OptimizedImage> createState() => _OptimizedImageState();
}

class _OptimizedImageState extends State<OptimizedImage> {
  /// 磁盘缓存管理器
  CacheManager? _cacheManager;
  /// loading loading loading
  bool _cacheManagerReady = false;
  ({int? width, int? height})? _cachedDecodeSize;
  Size? _lastConstraints;
  ImageProvider? _cachedImageProvider;

  @override
  void initState() {
    super.initState();
    _initCacheManager();
  }

  @override
  void didUpdateWidget(OptimizedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 只在 provider 变化时重新初始化
    if (widget.provider != oldWidget.provider) {
      _cachedDecodeSize = null;
      _lastConstraints = null;
      _cachedImageProvider = null;
      _cacheManagerReady = false;
      _initCacheManager();
    }
  }

  void _initCacheManager() {
    // 网络图片需要缓存管理器
    if (widget.provider is! NetworkImage) return;
    FileCacheService.instance.getCacheManager().then((manager) {
      if (mounted) {
        setState(() {
          _cacheManager = manager;
          _cacheManagerReady = true;
        });
      }
    });
  }

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

  Widget _error(BuildContext context, Object error) => widget.errorBuilder != null
      ? widget.errorBuilder!(context, error, StackTrace.current)
      : _broken(context);

  @override
  Widget build(BuildContext context) {
    // 网络图片走磁盘缓存
    if (widget.provider is NetworkImage) {
      final networkImage = widget.provider as NetworkImage;
      return LayoutBuilder(
        builder: (context, constraints) {
          // 缓存解码尺寸
          final currentSize = Size(constraints.maxWidth, constraints.maxHeight);
          if (_lastConstraints != currentSize) {
            _lastConstraints = currentSize;
            _cachedDecodeSize = imageDecodeSize(
              MediaQuery.of(context).devicePixelRatio,
              width: constraints.hasBoundedWidth ? constraints.maxWidth : null,
              height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
            );
          }

          // 缓存管理器!!!!!
          if (_cacheManagerReady) {
            return CachedNetworkImage(
              key: ValueKey(networkImage.url),
              imageUrl: networkImage.url,
              cacheManager: _cacheManager,
              fit: widget.fit,
              memCacheWidth: _cachedDecodeSize?.width,
              memCacheHeight: _cachedDecodeSize?.height,
              placeholder: (context, url) => _placeholder(context),
              errorWidget: (context, url, error) => _error(context, error),
            );
          }

          // 缓存管理器初始化中
          return _placeholder(context);
        },
      );
    }

    // 本地/内存/其他 ImageProvider：按实际渲染尺寸下采样解码
    return LayoutBuilder(
      builder: (context, constraints) {
        // 缓存解码尺寸和 provider
        final currentSize = Size(constraints.maxWidth, constraints.maxHeight);
        if (_lastConstraints != currentSize) {
          _lastConstraints = currentSize;
          
          var imageProvider = widget.provider;
          if (!kIsWeb) {
            final size = imageDecodeSize(
              MediaQuery.of(context).devicePixelRatio,
              width: constraints.hasBoundedWidth ? constraints.maxWidth : null,
              height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
            );
            if (size.width != null || size.height != null) {
              imageProvider = ResizeImage(
                widget.provider,
                width: size.width,
                height: size.height,
                policy: ResizeImagePolicy.fit,
              );
            }
          }
          _cachedImageProvider = imageProvider;
        }
        
        return Image(
          image: _cachedImageProvider ?? widget.provider,
          fit: widget.fit,
          gaplessPlayback: widget.gaplessPlayback,
          errorBuilder: widget.errorBuilder,
          frameBuilder: widget.frameBuilder,
        );
      },
    );
  }
}
