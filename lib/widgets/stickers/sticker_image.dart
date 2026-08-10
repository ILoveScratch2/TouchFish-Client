import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';

import '../../models/settings_service.dart';
import '../../services/api/tf_api_client.dart';
import '../../models/sticker_model.dart';
import '../../utils/file_type_detector.dart';
import '../../utils/sticker_cache.dart';

class StickerImage extends StatefulWidget {
  final String hash;
  final String fileType;
  final BoxFit fit;
  final Widget? error;

  const StickerImage({
    super.key,
    required this.hash,
    required this.fileType,
    this.fit = BoxFit.contain,
    this.error,
  });

  @override
  State<StickerImage> createState() => _StickerImageState();
}

class _StickerImageState extends State<StickerImage> {
  static int _activeDownloads = 0;
  static const int _maxConcurrentDownloads = 2;
  static final List<Completer<void>> _downloadQueue = [];

  Future<_StickerPayload>? _payload;
  bool _loading = false;

  bool get _autoLoad {
    return SettingsService.instance.getValue<bool>('autoLoadingStickers', true);
  }

  @override
  void initState() {
    super.initState();
    if (_autoLoad) _payload = _load();
  }

  @override
  void didUpdateWidget(covariant StickerImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hash != widget.hash || oldWidget.fileType != widget.fileType) {
      _payload = _autoLoad ? _load() : null;
      _loading = false;
    }
  }

  static Future<void> _acquireDownloadSlot() async {
    if (_activeDownloads < _maxConcurrentDownloads) {
      _activeDownloads++;
      return;
    }
    final completer = Completer<void>();
    _downloadQueue.add(completer);
    await completer.future;
  }

  static void _releaseDownloadSlot() {
    _activeDownloads--;
    if (_downloadQueue.isNotEmpty) {
      _activeDownloads++;
      _downloadQueue.removeAt(0).complete();
    }
  }

  Future<_StickerPayload> _load() async {
    // Check disk cache first
    final cached = await StickerCache.instance.get(widget.hash);
    if (cached != null) {
      final bytes = await File(cached).readAsBytes();
      return _StickerPayload(bytes, detectFileType(bytes));
    }

    await _acquireDownloadSlot();
    try {
      final url = await TfApiClient.instance.getFileUrl(widget.hash);
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Sticker unavailable');
      }
      final bytes = response.bodyBytes;
      unawaited(StickerCache.instance.put(widget.hash, bytes));
      return _StickerPayload(bytes, detectFileType(bytes));
    } finally {
      _releaseDownloadSlot();
    }
  }

  void _tapToLoad() {
    if (_autoLoad || _loading) return;
    setState(() => _loading = true);
    _payload = _load().then((payload) {
      if (mounted) setState(() => _loading = false);
      return payload;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_autoLoad && _payload == null) {
      return GestureDetector(
        onTap: _tapToLoad,
        child: _buildPlaceholder(context),
      );
    }

    return FutureBuilder<_StickerPayload>(
      future: _payload,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.hasError) {
            return widget.error ??
                const Center(child: Icon(Icons.broken_image_outlined));
          }
          return const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final payload = snapshot.data!;
        switch (payload.type) {
          case DetectedFileType.svg:
            return SvgPicture.memory(payload.bytes, fit: widget.fit);
          case DetectedFileType.tgs:
            return Lottie.memory(
              Uint8List.fromList(GZipDecoder().decodeBytes(payload.bytes)),
              fit: widget.fit,
              repeat: true,
            );
          case DetectedFileType.png:
          case DetectedFileType.jpg:
          case DetectedFileType.gif:
          case DetectedFileType.bmp:
          case DetectedFileType.webp:
          case DetectedFileType.unknown:
            return Image.memory(
              payload.bytes,
              fit: widget.fit,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) =>
                  widget.error ?? const Icon(Icons.broken_image_outlined),
            );
        }
      },
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(
          Icons.download_outlined,
          size: 20,
          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _StickerPayload {
  final Uint8List bytes;
  final DetectedFileType type;
  const _StickerPayload(this.bytes, this.type);
}

class StickerTile extends StatelessWidget {
  final StickerItem sticker;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const StickerTile({
    super.key,
    required this.sticker,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message:
          sticker.name?.isNotEmpty == true ? sticker.name! : sticker.slug,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: StickerImage(
              hash: sticker.fileHash,
              fileType: sticker.fileType,
            ),
          ),
        ),
      ),
    );
  }
}
