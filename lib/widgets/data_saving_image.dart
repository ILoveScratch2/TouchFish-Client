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
  Future<CacheManager?>? _cacheManagerFuture;

  @override
  void initState() {
    super.initState();
    _cacheManagerFuture = FileCacheService.instance.getCacheManager();
    _checkCache();
  }

  @override
  void didUpdateWidget(covariant DataSavingImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _cached = null;
      _checkCache();
    }
  }

  Future<void> _checkCache() async {
    final cached = await FileCacheService.instance.getFileFromCache(widget.url);
    if (mounted && _cached != true) {
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
      final decodeSize = imageDecodeSize(
        dpr,
        width: widget.width,
        height: widget.height,
      );
      return FutureBuilder<CacheManager?>(
        future: _cacheManagerFuture,
        builder: (context, snapshot) {
          return CachedNetworkImage(
            key: ValueKey(widget.url),
            imageUrl: widget.url,
            cacheManager: snapshot.data,
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
            memCacheWidth: decodeSize.width,
            memCacheHeight: decodeSize.height,
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
        },
      );
    }
    return OptimizedImage(provider: NetworkImage(widget.url), fit: widget.fit);
  }
}
