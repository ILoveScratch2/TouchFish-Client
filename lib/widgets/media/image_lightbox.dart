import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../l10n/app_localizations.dart';
import '../../models/message_model.dart';
import '../../services/api/tf_api_client.dart';
import '../../utils/talker.dart';
import 'exif_info_overlay.dart';

/// 画廊中的一张图片：由消息气泡收集，聊天详情页按时间序传入。
class LightboxImageItem {
  final String messageId;
  final MessageMedia media;
  final Uint8List? bytes;

  const LightboxImageItem({
    required this.messageId,
    required this.media,
    this.bytes,
  });
}

/// 图片灯箱：单图体验优化 + 多图画廊。
///
/// 设计参照 Solian 的 cloud_file_lightbox.dart：
/// - 双击缩放（photo_view 内置）、点击切换控制栏、3s 自动隐藏
/// - 加载进度（spinner 或百分比）
/// - 上下渐变 scrim、键盘方向键/Esc
/// - 不用下滑关闭（与 PhotoView 垂直平移冲突），关闭走按钮/Esc
///
/// 旧构造（imagePath/imageBytes/heroTag）保留，内部包装为单条目画廊。
class ImageLightbox extends StatefulWidget {
  final String imagePath;
  final Uint8List? imageBytes;
  final String heroTag;
  final Map<String, dynamic>? exifData;

  /// 多图模式：按时间序的图片列表；为 null 时用单图构造。
  final List<LightboxImageItem>? items;

  /// 初始显示第几张（多图模式）。
  final int initialIndex;

  /// 把文件 hash 解析为可访问 URL；默认走 [TfApiClient.getFileUrl]。
  final Future<String> Function(String hash)? resolveUrl;

  const ImageLightbox({
    super.key,
    required this.imagePath,
    this.imageBytes,
    required this.heroTag,
    this.exifData,
    this.items,
    this.initialIndex = 0,
    this.resolveUrl,
  });

  @override
  State<ImageLightbox> createState() => _ImageLightboxState();
}

class _ImageLightboxState extends State<ImageLightbox> {
  static const double _minScale = 0.1;
  static const double _maxScale = 10.0;

  late final List<LightboxImageItem> _items;
  late final List<PhotoViewController> _controllers;
  late final PageController _pageController;
  late final Map<int, Future<String>> _urlFutures = {};
  late final FocusNode _focusNode;

  late int _currentIndex;
  late bool _showExif;
  bool _showControls = true;
  bool _controlsVisible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    final items = widget.items;
    _items = (items == null || items.isEmpty)
        ? [_legacyItem(widget.imagePath, widget.imageBytes)]
        : items;
    _currentIndex = widget.initialIndex.clamp(0, _items.length - 1);
    _controllers = List.generate(
      _items.length,
      (_) => PhotoViewController(),
    );
    _pageController = PageController(initialPage: _currentIndex);
    _focusNode = FocusNode();
    _showExif = widget.exifData != null && widget.exifData!.isNotEmpty;
    _restartHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _focusNode.dispose();
    _pageController.dispose();
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  LightboxImageItem _legacyItem(String imagePath, Uint8List? imageBytes) {
    return LightboxImageItem(
      messageId: 'legacy',
      media: MessageMedia(
        path: imagePath,
        fileName: imagePath.split('/').last,
      ),
      bytes: imageBytes,
    );
  }

  Future<String> _resolveUrl(String hash) {
    final resolver = widget.resolveUrl ?? TfApiClient.instance.getFileUrl;
    return resolver(hash);
  }

  /// 同步可得的 ImageProvider；拿不到（纯 hash）返回 null，由 FutureBuilder 异步解析。
  ImageProvider? _resolveProviderSync(LightboxImageItem item) {
    final bytes = item.bytes ?? (item.media.bytes != null
        ? Uint8List.fromList(item.media.bytes!)
        : null);
    if (bytes != null && bytes.isNotEmpty) {
      return MemoryImage(bytes);
    }
    final path = item.media.path;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return NetworkImage(path);
    }
    final fileHash = item.media.fileHash;
    if (fileHash == null || fileHash.isEmpty) {
      if (kIsWeb) return null;
      final file = File(path);
      if (file.existsSync()) return FileImage(file);
    }
    return null;
  }

  PhotoViewGalleryPageOptions _pageOptions(int index) {
    final item = _items[index];
    final isHero = index == widget.initialIndex && widget.heroTag.isNotEmpty;
    final syncProvider = _resolveProviderSync(item);
    final controller = _controllers[index];

    if (syncProvider != null) {
      return PhotoViewGalleryPageOptions(
        imageProvider: syncProvider,
        controller: controller,
        heroAttributes: isHero
            ? PhotoViewHeroAttributes(tag: widget.heroTag)
            : null,
        basePosition: Alignment.center,
        minScale: PhotoViewComputedScale.contained * 0.9,
        maxScale: PhotoViewComputedScale.covered * 3,
        initialScale: PhotoViewComputedScale.contained,
        onTapUp: (context, details, value) => _toggleControls(),
      );
    }

    // 纯 hash 的远程图片：先解析 URL 再渲染（收到消息的 media.path 是裸 hash）。
    return PhotoViewGalleryPageOptions.customChild(
      child: FutureBuilder<String>(
        future: _urlFutures.putIfAbsent(
          index,
          () => _resolveUrl(item.media.fileHash ?? item.media.path),
        ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white54,
                ),
              ),
            );
          }
          return PhotoView(
            imageProvider: NetworkImage(snapshot.data!),
            controller: controller,
            basePosition: Alignment.center,
            minScale: PhotoViewComputedScale.contained * 0.9,
            maxScale: PhotoViewComputedScale.covered * 3,
            initialScale: PhotoViewComputedScale.contained,
            onTapUp: (context, details, value) => _toggleControls(),
            enableRotation: true,
          );
        },
      ),
      disableGestures: true,
    );
  }

  void _revealControls() {
    if (_showControls && _controlsVisible) return;
    setState(() {
      _showControls = true;
      _controlsVisible = true;
    });
    _restartHideTimer();
  }

  void _toggleControls() {
    if (_showControls && _controlsVisible) {
      _hideTimer?.cancel();
      setState(() {
        _controlsVisible = false;
        _showControls = false;
      });
    } else {
      _revealControls();
    }
  }

  void _restartHideTimer() {
    _hideTimer?.cancel();
    if (!_showControls || !_controlsVisible) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  bool get _controlsShown => _showControls && _controlsVisible;

  PhotoViewController get _currentController => _controllers[_currentIndex];

  void _goToPage(int index) {
    if (index < 0 || index >= _items.length) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _zoomBy(double delta) {
    final controller = _currentController;
    final currentScale = controller.scale ?? 1.0;
    controller.scale = (currentScale + delta).clamp(_minScale, _maxScale);
    _revealControls();
  }

  void _rotateBy(double radians) {
    final controller = _currentController;
    controller.rotation = controller.rotation + radians;
    _revealControls();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _goToPage(_currentIndex - 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _goToPage(_currentIndex + 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isGallery = _items.length > 1;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Material(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Listener(
              onPointerSignal: (pointerSignal) {
                try {
                  final delta = (pointerSignal as dynamic).scrollDelta.dy
                      as double?;
                  if (delta != null && delta != 0) {
                    final currentScale = _currentController.scale ?? 1.0;
                    final newScale = delta > 0
                        ? currentScale * 0.9
                        : currentScale * 1.1;
                    _currentController.scale = newScale.clamp(
                      _minScale,
                      _maxScale,
                    );
                  }
                } catch (e) {
                  talker.error(
                    'Failed to handle scroll event in image lightbox',
                    e,
                  );
                }
              },
              child: PhotoViewGallery.builder(
                key: ValueKey(_items.length),
                pageController: _pageController,
                itemCount: _items.length,
                scrollPhysics: isGallery
                    ? const BouncingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                  _revealControls();
                },
                builder: (context, index) => _pageOptions(index),
                loadingBuilder: (context, event) {
                  if (event == null || event.expectedTotalBytes == null) {
                    return const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white54,
                        ),
                      ),
                    );
                  }
                  final progress =
                      event.cumulativeBytesLoaded / event.expectedTotalBytes!;
                  return Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                backgroundDecoration: const BoxDecoration(
                  color: Colors.black,
                ),
                gaplessPlayback: true,
                enableRotation: true,
              ),
            ),

            // EXIF 信息（仅初始图：点击时已由气泡读出）。
            if (_showExif && widget.exifData != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 0,
                child: IgnorePointer(
                  child: AnimatedPadding(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.only(
                      bottom: mediaQuery.padding.bottom +
                          (_controlsShown ? 88 : 24),
                    ),
                    child: ExifInfoOverlay(exifData: widget.exifData!),
                  ),
                ),
              ),

            // 控制栏 chrome：上下渐变 + 顶栏 + 底栏 + 左右箭头。
            AnimatedOpacity(
              opacity: _controlsShown ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: IgnorePointer(
                ignoring: !_controlsShown,
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: mediaQuery.padding.top + 72,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.65),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: mediaQuery.padding.bottom + 96,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.65),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: mediaQuery.padding.top + 4,
                      left: 4,
                      right: 4,
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                            ),
                            tooltip: MaterialLocalizations.of(
                              context,
                            ).closeButtonTooltip,
                          ),
                          Expanded(
                            child: Text(
                              _items[_currentIndex].media.fileName ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (isGallery)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                '${_currentIndex + 1} / ${_items.length}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: mediaQuery.padding.bottom + 12,
                      left: 16,
                      right: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _iconButton(
                            icon: Icons.remove,
                            tooltip: AppLocalizations.of(
                              context,
                            )!.imageZoomOut,
                            onPressed: () => _zoomBy(-0.15),
                          ),
                          _iconButton(
                            icon: Icons.add,
                            tooltip: AppLocalizations.of(context)!.imageZoomIn,
                            onPressed: () => _zoomBy(0.15),
                          ),
                          const SizedBox(width: 8),
                          _iconButton(
                            icon: Icons.rotate_left,
                            tooltip: AppLocalizations.of(
                              context,
                            )!.imageRotateLeft,
                            onPressed: () => _rotateBy(-math.pi / 2),
                          ),
                          _iconButton(
                            icon: Icons.rotate_right,
                            tooltip: AppLocalizations.of(
                              context,
                            )!.imageRotateRight,
                            onPressed: () => _rotateBy(math.pi / 2),
                          ),
                          if (widget.exifData != null &&
                              widget.exifData!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            _iconButton(
                              icon: _showExif
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              tooltip: AppLocalizations.of(context)!.imageExif,
                              onPressed: () {
                                setState(() => _showExif = !_showExif);
                                _revealControls();
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isGallery) ...[
                      Positioned(
                        left: 8,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: _iconButton(
                            icon: Icons.chevron_left,
                            tooltip: MaterialLocalizations.of(
                              context,
                            ).previousPageTooltip,
                            onPressed: _currentIndex > 0
                                ? () => _goToPage(_currentIndex - 1)
                                : null,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: _iconButton(
                            icon: Icons.chevron_right,
                            tooltip: MaterialLocalizations.of(
                              context,
                            ).nextPageTooltip,
                            onPressed: _currentIndex < _items.length - 1
                                ? () => _goToPage(_currentIndex + 1)
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      tooltip: tooltip,
    );
  }
}
