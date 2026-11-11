import 'package:flutter/material.dart';

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
  /// 用户是否已手动点按加载（本会话内，不随 widget 复用携带到新 URL）
  bool _requested = false;

  /// 磁盘缓存命中与否；null = 尚未探测
  bool? _cached;

  @override
  void initState() {
    super.initState();
    _checkCache();
  }

  @override
  void didUpdateWidget(covariant DataSavingImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      // 旧 URL 的手动加载意图不随 widget 复用带到新 URL
      _requested = false;
      _cached = null;
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
    return OptimizedImage(
      provider: NetworkImage(widget.url),
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
    );
  }
}
