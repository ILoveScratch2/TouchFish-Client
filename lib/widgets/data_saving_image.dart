import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../models/settings_service.dart';
import '../services/file_cache_service.dart';
import 'optimized_image.dart';

/// 支持"数据节省模式"的网络图片
class DataSavingImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  const DataSavingImage({
    super.key,
    required this.url,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
  });

  @override
  State<DataSavingImage> createState() => _DataSavingImageState();
}

class _DataSavingImageState extends State<DataSavingImage> {
  bool _requested = false;
  bool? _cached;
  /// dspark
  CacheManager? _cacheManager;
  bool _cacheManagerReady = false;
  ({int? width, int? height})? _cachedDecodeSize;
  ({double? width, double? height})? _lastSize;
  double? _lastDpr;

  @override
  void initState() {
    super.initState();
    FileCacheService.instance.getCacheManager().then((manager) {
      if (mounted) {
        setState(() {
          _cacheManager = manager;
          _cacheManagerReady = true;
        });
      }
    });
    _checkCache();
  }

  @override
  void didUpdateWidget(covariant DataSavingImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      // 旧 URL 的手动 load 意图不随 widget 复用带到新 URL
      _requested = false;
      _cached = null;
      _cachedDecodeSize = null;
      _lastSize = null;
      _lastDpr = null;
      _checkCache();
    }
  }

  Future<void> _checkCache() async {
    final url = widget.url;
    final cached = await FileCacheService.instance.getFileFromCache(url);
    // 期间 URL 可能已变化，旧请求结果不得污染新 URL 的状态
    if (mounted && widget.url == url && _cached != true) {
      setState(() => _cached = cached != null);
    }
  }

  bool _getSaving() =>
      SettingsService.instance.getValue<bool>('dataSavingMode', false);

  @override
  Widget build(BuildContext context) {
    final saving = _getSaving();
    // 数据节省模式 + 未请求 + 未缓存：显示占位图标
    if (saving && !_requested && _cached != true) {
      return SizedBox(
        width: widget.width,
        height: widget.height ?? 120,
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: InkWell(
            onTap: () => setState(() => _requested = true),
            child: const Center(
              child: Icon(Icons.download_for_offline_outlined),
            ),
          ),
        ),
      );
    }

    if (widget.width != null || widget.height != null) {
      // 明确尺寸：走磁盘缓存网络图，避免超大图全尺寸解码
      final dpr = MediaQuery.of(context).devicePixelRatio;
      
      // 缓存解码尺寸
      if (_lastDpr != dpr ||
          _lastSize != (width: widget.width, height: widget.height)) {
        _lastDpr = dpr;
        _lastSize = (width: widget.width, height: widget.height);
        _cachedDecodeSize = imageDecodeSize(
          dpr,
          width: widget.width,
          height: widget.height,
        );
      }

      // 缓存管理器，启动！
      if (_cacheManagerReady) {
        return CachedNetworkImage(
          key: ValueKey(widget.url),
          imageUrl: widget.url,
          cacheManager: _cacheManager,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          memCacheWidth: _cachedDecodeSize?.width,
          memCacheHeight: _cachedDecodeSize?.height,
          placeholder: (context, url) => SizedBox(
            width: widget.width,
            height: widget.height,
            child: Center(
              child: SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        );
      }

      // 缓存管理器加载中
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: Center(
          child: SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return OptimizedImage(provider: NetworkImage(widget.url), fit: widget.fit);
  }
}
