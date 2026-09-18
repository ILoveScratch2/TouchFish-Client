import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../services/api/tf_api_client.dart';
import '../services/file_cache_service.dart';

// 小小缩略图！
// wyf 可能知道背后的故事……
class FileThumbnail extends StatefulWidget {
  final String hash;
  final Widget fallback;
  final double size;

  const FileThumbnail({
    super.key,
    required this.hash,
    required this.fallback,
    this.size = 44,
  });

  @override
  State<FileThumbnail> createState() => _FileThumbnailState();
}

class _FileThumbnailState extends State<FileThumbnail> {
  String? _url;

  @override
  void initState() {
    super.initState();
    TfApiClient.instance.getThumbnailUrl(widget.hash).then((url) {
      if (mounted) setState(() => _url = url);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cache = FileCacheService.instance;
    final url = _url;
    // web 上莫得缓存管理器
    if (url == null || (!kIsWeb && !cache.isManagerReady)) {
      return widget.fallback;
    }
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CachedNetworkImage(
        imageUrl: url,
        cacheManager: cache.cacheManager,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder: (context, url) => widget.fallback,
        errorWidget: (context, url, error) => widget.fallback,
      ),
    );
  }
}
