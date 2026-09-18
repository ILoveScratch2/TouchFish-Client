import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../services/browser_service.dart'; // 现在我们用内置浏览器看了
import '../l10n/app_localizations.dart';
import '../models/file_attachment.dart';
import '../models/settings_service.dart';
import '../providers/task/task_manager_provider.dart';
import '../services/api/tf_api_client.dart';
import '../services/file_download_service.dart';
import '../services/snackbar_service.dart';
import '../services/file_cache_service.dart';
import '../utils/blurhash_utils.dart';
import '../utils/talker.dart';
import 'media/audio_player.dart';
import 'media/image_error_view.dart';
import 'media/image_lightbox.dart';
import 'media/video_viewer.dart';
import 'optimized_image.dart';
import 'sheet_scaffold.dart';

class FileAttachmentView extends ConsumerStatefulWidget {
  final FileAttachment attachment;
  final String? sourceUrl;
  final Uint8List? bytes;
  final bool allowAutomaticPreview;
  final bool compact;

  /// 多图灯箱画廊条目（由聊天详情页收集）；为 null 时单图模式。
  final List<LightboxImageItem>? galleryItems;
  final int galleryIndex;

  const FileAttachmentView({
    super.key,
    required this.attachment,
    this.sourceUrl,
    this.bytes,
    this.allowAutomaticPreview = true,
    this.compact = false,
    this.galleryItems,
    this.galleryIndex = 0,
  });

  @override
  ConsumerState<FileAttachmentView> createState() => _FileAttachmentViewState();
}

bool shouldAutomaticallyPreviewFile({
  required FileAttachment attachment,
  required int limitMiB,
}) {
  final size = attachment.fileSize;
  return attachment.isPreviewable &&
      !attachment.isPdf &&
      limitMiB > 0 &&
      size != null &&
      size <= limitMiB * 1024 * 1024;
}

class _FileAttachmentViewState extends ConsumerState<FileAttachmentView> {
  bool _previewRequested = false;
  bool _downloading = false;

  /// 磁盘缓存里已有该文件：省流量模式下也直接展示（零流量）。
  bool _cachedLocally = false;

  /// 当前正在进行的下载任务 ID（用于行内显示真实进度）。
  String? _activeTaskId;
  late FileAttachment _attachment;
  late Future<String> _urlFuture;

  @override
  void initState() {
    super.initState();
    _attachment = widget.attachment;
    _urlFuture = _previewUrl();
    if (_attachment.hash.isNotEmpty && _needsMetadata) {
      _resolveMetadata();
    }
    _checkLocalCache();
  }

  /// 基础信息（大小/mime/文件名）或图片媒体元数据缺失时补
  ///
  /// 省流量模式blurhash底图预览需要 hasThumb 与宽高，
  /// 向服务端,补齐!
  bool get _needsMetadata {
    if (_attachment.fileSize == null ||
        _attachment.mimeType == null ||
        _attachment.fileName == _attachment.hash) {
      return true;
    }
    return _attachment.isImage &&
        (_attachment.blurhash == null ||
            !_attachment.hasThumb ||
            _attachment.aspectRatio == null);
  }

  @override
  void didUpdateWidget(covariant FileAttachmentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.attachment;
    final hasNewMetadata =
        (incoming.blurhash != null && incoming.blurhash != _attachment.blurhash) ||
        (incoming.hasThumb && !_attachment.hasThumb) ||
        (incoming.width != null && incoming.width != _attachment.width) ||
        (incoming.height != null && incoming.height != _attachment.height);
    if (!hasNewMetadata) return;
    setState(() {
      _attachment = _attachment.copyWith(
        blurhash: incoming.blurhash,
        hasThumb: incoming.hasThumb ? true : null,
        width: incoming.width,
        height: incoming.height,
      );
    });
  }

  Future<void> _resolveMetadata() async {
    final resolved = await TfApiClient.instance.getFileMetadata(
      _attachment.hash,
    );
    if (resolved == null || !mounted) return;
    setState(() {
      // 只补空缺
      _attachment = _attachment.copyWith(
        fileName: _attachment.fileName == _attachment.hash &&
                resolved.fileName != _attachment.hash
            ? resolved.fileName
            : null,
        fileSize: _attachment.fileSize ?? resolved.fileSize,
        mimeType: _attachment.mimeType ?? resolved.mimeType,
        blurhash: _attachment.blurhash ?? resolved.blurhash,
        width: _attachment.width ?? resolved.width,
        height: _attachment.height ?? resolved.height,
        hasThumb: _attachment.hasThumb || resolved.hasThumb,
      );
    });
  }

  /// 本地已有内容展示不产生流量，显然要展示
  bool get _hasLocalContent =>
      (widget.bytes?.isNotEmpty ?? false) || _cachedLocally;

  Future<void> _checkLocalCache() async {
    try {
      final url = await _urlFuture;
      if (url.isEmpty) return;
      final cached = await FileCacheService.instance.getFileFromCache(url);
      if (mounted && cached != null) {
        setState(() => _cachedLocally = true);
      }
    } catch (e) {
      talker.warning('check local cache failed', e);
    }
  }

  bool get _shouldPreview {
    if (!_attachment.isPreviewable || _attachment.isPdf) {
      return false;
    }
    if (_previewRequested) return true;
    if (widget.compact) return false;
    if (!widget.allowAutomaticPreview) return false;
    if (SettingsService.instance.getValue<bool>('dataSavingMode', false)) {
      return _hasLocalContent;
    }
    final limitMiB = SettingsService.instance.getValue<int>(
      'automaticPreviewMaxMiB',
      10,
    );
    return shouldAutomaticallyPreviewFile(
      attachment: _attachment,
      limitMiB: limitMiB,
    );
  }

  Future<String> _url() async {
    if (widget.sourceUrl != null && widget.sourceUrl!.isNotEmpty) {
      return widget.sourceUrl!;
    }
    return TfApiClient.instance.getFileUrl(widget.attachment.hash);
  }

  Future<String> _previewUrl() {
    if (_attachment.isText && widget.bytes != null) {
      return Future.value(widget.sourceUrl ?? '');
    }
    return _url();
  }

  Future<void> _download() async {
    if (_downloading) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _downloading = true);
    try {
      final result = await downloadFile(
        await _url(),
        _attachment.fileName,
        taskManager: ref.read(taskManagerProvider.notifier),
      );
      if (!mounted) return;
      _activeTaskId = result.taskId;
      if (result.cancelled) return;
      TouchFishSnackbarService.instance.show(
        result.succeeded
            ? result.savedPath == null
                ? l10n.fileDownloadStarted
                : l10n.fileDownloadSaved(result.savedPath!)
            : l10n.fileDownloadFailed,
      );
    } catch (_) {
      if (mounted) {
        TouchFishSnackbarService.instance.show(l10n.fileDownloadFailed);
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _saveToLocal() async {
    if (_downloading) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _downloading = true);
    try {
      final url = await _url();
      final file = await FileCacheService.instance.saveFilePermanently(
        url,
        _attachment.fileName,
      );
      if (!mounted) return;
      if (file != null) {
        TouchFishSnackbarService.instance.show(
          l10n.fileDownloadSaved(file.path),
        );
      } else {
        TouchFishSnackbarService.instance.show(l10n.fileDownloadFailed);
      }
    } catch (e) {
      if (mounted) {
        TouchFishSnackbarService.instance.show(l10n.fileDownloadFailed);
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _showDownloadOptions() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Symbols.download),
              title: Text(l10n.fileDownload),
              onTap: () {
                Navigator.pop(context);
                _download();
              },
            ),
            ListTile(
              leading: const Icon(Symbols.save),
              title: Text(l10n.fileSaveToLocal),
              subtitle: Text(l10n.fileSaveToLocalDescription),
              onTap: () {
                Navigator.pop(context);
                _saveToLocal();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _preview() async {
    if (!_attachment.isPreviewable) return;
    if (_attachment.isPdf) {
      final url = Uri.tryParse(await _url());
      if (url == null || !mounted) return;
      await BrowserService.instance.openUri(context, url);
      return;
    }
    if (widget.allowAutomaticPreview && !widget.compact) {
      setState(() => _previewRequested = true);
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SheetScaffold(
        titleText: _attachment.fileName,
        heightFactor: 0.9,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _AttachmentPreview(
            attachment: _attachment,
            urlFuture: _urlFuture,
            bytes: widget.bytes,
            galleryItems: widget.galleryItems,
            galleryIndex: widget.galleryIndex,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_shouldPreview) {
      return _AttachmentPreview(
        attachment: _attachment,
        urlFuture: _urlFuture,
        bytes: widget.bytes,
        onDownload: _download,
        galleryItems: widget.galleryItems,
        galleryIndex: widget.galleryIndex,
      );
    }

    final l10n = AppLocalizations.of(context)!;

    // 行内下载真实进度：任务完成前 `_downloading` 一直为真，圆环数值随
    // taskManager 刷新；web/stub 无任务（_activeTaskId 为 null）时回退小转圈。
    double? downloadProgress;
    if (_downloading && _activeTaskId != null) {
      final tasks = ref.watch(taskManagerProvider);
      for (final t in tasks) {
        if (t.id == _activeTaskId) {
          final p = t.progress;
          downloadProgress = p?.clamp(0.0, 1.0);
          break;
        }
      }
    }

    // 省流量/超限等场景不自动加载图片：用本地已有的 blurhash 做零成本预览，
    // 没有 blurhash 也保留可点击的图片占位卡，点击后才真正加载
    if (!widget.compact && widget.allowAutomaticPreview && _attachment.isImage) {
      return _buildDataSavingPreview(context, l10n, downloadProgress);
    }

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.all(widget.compact ? 8 : 12),
        child: Row(
          children: [
            const Icon(Symbols.draft, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _attachment.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_attachment.fileSize != null)
                    Text(
                      formatFileSize(_attachment.fileSize!),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (_attachment.isPreviewable)
              IconButton(
                onPressed: _preview,
                icon: const Icon(Symbols.visibility),
                tooltip: l10n.filePreview,
              ),
            IconButton(
              onPressed: _downloading ? null : _download,
              onLongPress: _downloading ? null : _showDownloadOptions,
              icon: _downloading
                  ? _DownloadingIndicator(progress: downloadProgress)
                  : const Icon(Symbols.download),
              tooltip: _downloading ? l10n.fileDownloading : l10n.fileDownload,
            ),
          ],
        ),
      ),
    );
  }

  /// 数据节省预览 er
  Widget _buildDataSavingPreview(
    BuildContext context,
    AppLocalizations l10n,
    double? downloadProgress,
  ) {
    final attachment = _attachment;
    final colorScheme = Theme.of(context).colorScheme;
    final blurhash = attachment.blurhash;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 520),
        child: AspectRatio(
          aspectRatio: attachment.aspectRatio ?? 4 / 3,
          child: GestureDetector(
            onTap: _preview,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (isValidBlurHash(blurhash))
                    BlurHash(
                      hash: blurhash!,
                      imageFit: BoxFit.cover,
                      duration: Duration.zero,
                    )
                  else
                    ColoredBox(
                      color: colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: Icon(
                          Symbols.image,
                          size: 40,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Symbols.visibility,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l10n.mediaTapToLoad,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton.filledTonal(
                      onPressed: _downloading ? null : _download,
                      onLongPress: _downloading ? null : _showDownloadOptions,
                      icon: _downloading
                          ? _DownloadingIndicator(progress: downloadProgress)
                          : const Icon(Symbols.download),
                      tooltip: _downloading
                          ? l10n.fileDownloading
                          : l10n.fileDownload,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 下载行尾图标：有确定进度时显示带整数百分比的小圆环，否则转圈。
class _DownloadingIndicator extends StatelessWidget {
  final double? progress;

  const _DownloadingIndicator({this.progress});

  @override
  Widget build(BuildContext context) {
    if (progress == null) {
      return const SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 26,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress!.clamp(0.0, 1.0),
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
            backgroundColor: scheme.surfaceContainerHighest,
          ),
          Text(
            '${(progress! * 100).round()}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentPreview extends StatefulWidget {
  final FileAttachment attachment;
  final Future<String> urlFuture;
  final Uint8List? bytes;
  final VoidCallback? onDownload;
  final List<LightboxImageItem>? galleryItems;
  final int galleryIndex;

  const _AttachmentPreview({
    required this.attachment,
    required this.urlFuture,
    this.bytes,
    this.onDownload,
    this.galleryItems,
    this.galleryIndex = 0,
  });

  @override
  State<_AttachmentPreview> createState() => _AttachmentPreviewState();
}

class _AttachmentPreviewState extends State<_AttachmentPreview> {
  /// ParsedURL is loading
  String? _fileUrl;
  Future<File?>? _fileFuture;

  /// 缩略图预览加载失败（如缩略图被清理），本次展示回退原图
  bool _thumbUnavailable = false;

  /// 本实例已按原图渲染过（新图缩略图未生成等场景）；
  /// 后续元数据补齐（MEDIA_READY）时不再降级为缩略图，避免清晰度突然变差
  bool _renderedOriginal = false;

  @override
  void didUpdateWidget(covariant _AttachmentPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.urlFuture != widget.urlFuture ||
        oldWidget.bytes != widget.bytes) {
      _fileUrl = null;
      _fileFuture = null;
      _thumbUnavailable = false;
      _renderedOriginal = false;
    } else if (oldWidget.attachment.hasThumb != widget.attachment.hasThumb) {
      _thumbUnavailable = false;
    }
  }

  /// 缩略图加载失败后回退原图；不能在 build 期间 setState，延后一帧。
  void _scheduleThumbFallback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_thumbUnavailable) {
        setState(() => _thumbUnavailable = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: widget.urlFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(AppLocalizations.of(context)!.filePreviewFailed),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final url = snapshot.data!;
        // 已有字节内容时直接展示，否则优先用磁盘缓存文件，实现离线查看
        if (widget.bytes != null) {
          return _buildPreview(context, url, file: null);
        }
        if (url != _fileUrl) {
          _fileUrl = url;
          _fileFuture = FileCacheService.instance.getFile(url);
        }
        return FutureBuilder<File?>(
          future: _fileFuture,
          builder: (context, fileSnapshot) {
            if (fileSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return _buildPreview(context, url, file: fileSnapshot.data);
          },
        );
      },
    );
  }

  Widget _buildPreview(BuildContext context, String url, {File? file}) {
    final attachment = widget.attachment;
    final bytes = widget.bytes;
    Widget preview;
    if (attachment.isImage) {
      final isNetworkDisplay = file == null && bytes == null;
      final thumbUrl = isNetworkDisplay && attachment.hasThumb
          ? TfApiClient.thumbnailUrlFromFileUrl(url)
          : null;
      // 缩略图预览：气泡最终态用服务端缩略图，原图只在点开后加载（省流量）
      final preferThumb = isNetworkDisplay &&
          thumbUrl != null &&
          !_thumbUnavailable &&
          !_renderedOriginal &&
          SettingsService.instance.getValue<bool>('thumbnailPreview', true);
      if (isNetworkDisplay && !preferThumb) _renderedOriginal = true;
      // 磁盘缓存命中时直接使用本地文件（离线可看）
      final ImageProvider provider;
      if (file != null) {
        provider = FileImage(file);
      } else if (bytes != null) {
        provider = MemoryImage(bytes);
      } else if (preferThumb) {
        provider = NetworkImage(thumbUrl);
      } else {
        provider = NetworkImage(url);
      }
      Widget image = GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ImageLightbox(
              imagePath: file?.path ?? url,
              imageBytes: file != null ? null : bytes,
              heroTag: 'attachment_${attachment.hash}',
              items: widget.galleryItems,
              initialIndex: widget.galleryIndex,
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: OptimizedImage(
            provider: provider,
            fit: BoxFit.contain,
            // 网络加载时：blurhash 占位 + 服务端缩略图渐进展示
            blurhash: isNetworkDisplay ? attachment.blurhash : null,
            // 主图已是缩略图时不再重复加载缩略图层
            thumbnailUrl: isNetworkDisplay && !preferThumb ? thumbUrl : null,
            errorBuilder: isNetworkDisplay
                ? (context, error, stack) {
                    if (preferThumb) _scheduleThumbFallback();
                    return ImageErrorView(
                      blurhash: attachment.blurhash,
                      error: error,
                    );
                  }
                : null,
          ),
        ),
      );
      final ratio = attachment.aspectRatio;
      // 用元数据宽高提前占位，避免加载完成前后气泡尺寸跳动
      if (ratio != null) {
        image = AspectRatio(aspectRatio: ratio, child: image);
      }
      preview = image;
    } else if (attachment.isVideo) {
      preview = AspectRatio(
        aspectRatio: attachment.aspectRatio ?? 16 / 9,
        child: VideoViewer(
          videoPath: file?.path ?? url,
          videoBytes: file != null ? null : bytes,
        ),
      );
    } else if (attachment.isAudio) {
      preview = AudioPlayer(
        audioPath: file?.path ?? url,
        audioBytes: file != null ? null : bytes,
        filename: attachment.fileName,
      );
    } else if (attachment.isText) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _TextAttachmentPreview(
            attachment: attachment,
            url: url,
            bytes: bytes,
            file: file,
            onDownload: widget.onDownload,
          ),
        ),
      );
    } else {
      preview = _error(context);
    }
    return Stack(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 520,
              maxHeight: 520,
            ),
            child: preview,
          ),
        ),
        if (widget.onDownload != null)
          Positioned(
            top: 4,
            right: 4,
            child: IconButton.filledTonal(
              onPressed: widget.onDownload,
              icon: const Icon(Symbols.download),
              tooltip: AppLocalizations.of(context)!.fileDownload,
            ),
          ),
      ],
    );
  }

  Widget _error(BuildContext context) =>
      Center(child: Text(AppLocalizations.of(context)!.filePreviewFailed));
}

class _TextAttachmentPreview extends StatefulWidget {
  final FileAttachment attachment;
  final String url;
  final Uint8List? bytes;

  /// 磁盘缓存文件（命中缓存时优先本地读取，支持离线预览）
  final File? file;
  final VoidCallback? onDownload;

  const _TextAttachmentPreview({
    required this.attachment,
    required this.url,
    this.bytes,
    this.file,
    this.onDownload,
  });

  @override
  State<_TextAttachmentPreview> createState() => _TextAttachmentPreviewState();
}

class _TextAttachmentPreviewState extends State<_TextAttachmentPreview> {
  late Future<String> _contentFuture;

  @override
  void initState() {
    super.initState();
    _contentFuture = _loadContent();
  }

  @override
  void didUpdateWidget(covariant _TextAttachmentPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.bytes != widget.bytes ||
        oldWidget.file != widget.file) {
      _contentFuture = _loadContent();
    }
  }

  Future<String> _loadContent() async {
    final bytes = widget.bytes;
    if (bytes != null) return utf8.decode(bytes, allowMalformed: true);
    final file = widget.file;
    if (file != null) {
      try {
        final fileBytes = await file.readAsBytes();
        return utf8.decode(fileBytes, allowMalformed: true);
      } catch (e) {
        talker.error('Failed to read cached text file', e);
      }
    }
    return TfApiClient.instance.getTextFile(widget.url);
  }

  void _retry() {
    setState(() => _contentFuture = _loadContent());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      height: 400,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Positioned.fill(
              child: FutureBuilder<String>(
                future: _contentFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: FilledButton.tonal(
                        onPressed: _retry,
                        child: Text(l10n.retry),
                      ),
                    );
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 68, 20, 20),
                    child: SelectableText(
                      snapshot.data ?? '',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              right: widget.onDownload == null ? 8 : 64,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 240),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Symbols.file_present,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.attachment.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            if (widget.attachment.fileSize != null)
                              Text(
                                formatFileSize(widget.attachment.fileSize!),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.onDownload != null)
              Positioned(
                top: 8,
                right: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: widget.onDownload,
                    icon: const Icon(
                      Symbols.download,
                      color: Colors.white,
                      size: 18,
                    ),
                    tooltip: l10n.fileDownload,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
