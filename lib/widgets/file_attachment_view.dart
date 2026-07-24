import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../models/file_attachment.dart';
import '../models/settings_service.dart';
import '../services/api/tf_api_client.dart';
import '../services/file_download_service.dart';
import 'media/audio_player.dart';
import 'media/image_lightbox.dart';
import 'media/video_viewer.dart';
import 'sheet_scaffold.dart';

class FileAttachmentView extends StatefulWidget {
  final FileAttachment attachment;
  final String? sourceUrl;
  final Uint8List? bytes;
  final bool allowAutomaticPreview;
  final bool compact;

  const FileAttachmentView({
    super.key,
    required this.attachment,
    this.sourceUrl,
    this.bytes,
    this.allowAutomaticPreview = true,
    this.compact = false,
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

  @override
  void initState() {
    super.initState();
    _attachment = widget.attachment;
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
    if (!widget.allowAutomaticPreview) return false;
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

  Future<void> _download() async {
    if (_downloading) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _downloading = true);
    try {
      final result = await downloadFile(await _url(), _attachment.fileName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.succeeded
                ? result.savedPath == null
                      ? l10n.fileDownloadStarted
                      : l10n.fileDownloadSaved(result.savedPath!)
                : l10n.fileDownloadFailed,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.fileDownloadFailed)));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _preview() async {
    if (!_attachment.isPreviewable) return;
    if (_attachment.isPdf) {
      final opened = await launchUrl(
        Uri.parse(await _url()),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.filePreviewFailed),
          ),
        );
      }
      return;
    }
    if (widget.allowAutomaticPreview) {
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
            urlFuture: _url(),
            bytes: widget.bytes,
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
        urlFuture: _url(),
        bytes: widget.bytes,
        onDownload: _download,
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

  const _AttachmentPreview({
    required this.attachment,
    required this.urlFuture,
    this.bytes,
    this.onDownload,
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
                ),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: bytes == null
                  ? Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _error(context),
                    )
                  : Image.memory(bytes!, fit: BoxFit.contain),
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
          preview = FutureBuilder<http.Response>(
            future: http.get(Uri.parse(url)),
            builder: (context, textSnapshot) {
              if (textSnapshot.hasError) return _error(context);
              if (!textSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final response = textSnapshot.data!;
              if (response.statusCode < 200 || response.statusCode >= 300) {
                return _error(context);
              }
              return SingleChildScrollView(
                child: SelectableText(response.body),
              );
            },
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

String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
