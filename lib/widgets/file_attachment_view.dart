import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../services/browser_service.dart'; // 现在我们用内置浏览器看了
import '../l10n/app_localizations.dart';
import '../models/file_attachment.dart';
import '../models/settings_service.dart';
import '../services/api/tf_api_client.dart';
import '../services/file_download_service.dart';
import '../services/snackbar_service.dart';
import 'media/audio_player.dart';
import 'media/image_lightbox.dart';
import 'media/video_viewer.dart';
import 'optimized_image.dart';
import 'sheet_scaffold.dart';

class FileAttachmentView extends StatefulWidget {
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
  State<FileAttachmentView> createState() => _FileAttachmentViewState();
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

class _FileAttachmentViewState extends State<FileAttachmentView> {
  bool _previewRequested = false;
  bool _downloading = false;
  late FileAttachment _attachment;
  late Future<String> _urlFuture;

  @override
  void initState() {
    super.initState();
    _attachment = widget.attachment;
    _urlFuture = _previewUrl();
    if (_attachment.hash.isNotEmpty &&
        (_attachment.fileSize == null ||
            _attachment.mimeType == null ||
            _attachment.fileName == _attachment.hash)) {
      _resolveMetadata();
    }
  }

  Future<void> _resolveMetadata() async {
    final resolved = await TfApiClient.instance.getFileMetadata(
      _attachment.hash,
    );
    if (resolved != null && mounted) setState(() => _attachment = resolved);
  }

  bool get _shouldPreview {
    if (!_attachment.isPreviewable || _attachment.isPdf) {
      return false;
    }
    if (_previewRequested) return true;
    if (widget.compact) return false;
    if (!widget.allowAutomaticPreview) return false;
    if (SettingsService.instance.getValue<bool>('dataSavingMode', false)) {
      return false;
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
      final result = await downloadFile(await _url(), _attachment.fileName);
      if (!mounted) return;
      if (result.cancelled) return;
      TouchFishSnackbarService.instance.show(result.succeeded ? result.savedPath == null ? l10n.fileDownloadStarted : l10n.fileDownloadSaved(result.savedPath!) : l10n.fileDownloadFailed);
    } catch (_) {
      if (mounted) {
        TouchFishSnackbarService.instance.show(l10n.fileDownloadFailed);
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
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
              icon: _downloading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Symbols.download),
              tooltip: _downloading ? l10n.fileDownloading : l10n.fileDownload,
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: urlFuture,
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
        Widget preview;
        if (attachment.isImage) {
          preview = GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ImageLightbox(
                  imagePath: url,
                  imageBytes: bytes,
                  heroTag: 'attachment_${attachment.hash}',
                  items: galleryItems,
                  initialIndex: galleryIndex,
                ),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: OptimizedImage(
                provider: bytes == null
                    ? NetworkImage(url)
                    : MemoryImage(bytes!),
                fit: BoxFit.contain,
                errorBuilder: bytes == null
                    ? (_, _, _) => _error(context)
                    : null,
              ),
            ),
          );
        } else if (attachment.isVideo) {
          preview = AspectRatio(
            aspectRatio: 16 / 9,
            child: VideoViewer(videoPath: url, videoBytes: bytes),
          );
        } else if (attachment.isAudio) {
          preview = AudioPlayer(
            audioPath: url,
            audioBytes: bytes,
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
                onDownload: onDownload,
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
            if (onDownload != null)
              Positioned(
                top: 4,
                right: 4,
                child: IconButton.filledTonal(
                  onPressed: onDownload,
                  icon: const Icon(Symbols.download),
                  tooltip: AppLocalizations.of(context)!.fileDownload,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _error(BuildContext context) =>
      Center(child: Text(AppLocalizations.of(context)!.filePreviewFailed));
}

class _TextAttachmentPreview extends StatefulWidget {
  final FileAttachment attachment;
  final String url;
  final Uint8List? bytes;
  final VoidCallback? onDownload;

  const _TextAttachmentPreview({
    required this.attachment,
    required this.url,
    this.bytes,
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
    if (oldWidget.url != widget.url || oldWidget.bytes != widget.bytes) {
      _contentFuture = _loadContent();
    }
  }

  Future<String> _loadContent() async {
    final bytes = widget.bytes;
    if (bytes != null) return utf8.decode(bytes, allowMalformed: true);
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
