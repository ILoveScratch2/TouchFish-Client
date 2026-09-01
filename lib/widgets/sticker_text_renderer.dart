import 'package:flutter/material.dart';
import '../models/sticker_model.dart';
import '../services/api/tf_api_client.dart';
import 'stickers/sticker_image.dart';

final _stickerPattern = RegExp(r':([A-Za-z0-9_]+)\+([A-Za-z0-9_-]+):');

class StickerTextRenderer extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Color? textColor;
  final double stickerSize;

  const StickerTextRenderer({
    super.key,
    required this.text,
    this.style,
    this.textColor,
    this.stickerSize = 96,
  });

  @override
  Widget build(BuildContext context) {
    final matches = _stickerPattern.allMatches(text).toList();
    if (matches.isEmpty) {
      return Text(text, style: style);
    }

    final spans = <InlineSpan>[];
    var lastEnd = 0;
    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: style,
        ));
      }
      final identifier = '${match.group(1)}+${match.group(2)}';
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _InlineSticker(
          key: ValueKey(identifier),
          identifier: identifier,
          size: stickerSize,
          fallback: match.group(0)!,
          style: style,
        ),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: style));
    }

    return RichText(text: TextSpan(children: spans, style: style));
  }
}

class _InlineSticker extends StatefulWidget {
  final String identifier;
  final double size;
  final String fallback;
  final TextStyle? style;
  const _InlineSticker({
    super.key,
    required this.identifier,
    required this.size,
    required this.fallback,
    this.style,
  });
  @override
  State<_InlineSticker> createState() => _InlineStickerState();
}

class _InlineStickerState extends State<_InlineSticker> {
  static final Map<String, StickerItem?> _lookupCache = {};
  StickerItem? _item;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _lookup();
  }

  Future<void> _lookup() async {
    // 做干净的奥赛
    if (_lookupCache.containsKey(widget.identifier)) {
      _item = _lookupCache[widget.identifier];
      _loading = false;
      return;
    }
    try {
      final item = await TfApiClient.instance.lookupSticker(widget.identifier);
      _lookupCache[widget.identifier] = item;
      if (mounted) setState(() { _item = item; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showEnlarged(BuildContext context) {
    final item = _item;
    if (item == null) return;
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    final shadow = [
      Shadow(
        color: Colors.black54,
        blurRadius: 5.0,
        offset: const Offset(1.0, 1.0),
      ),
    ];
    entry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => entry.remove(),
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.black.withValues(alpha: 0.85)),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 256,
                  height: 256,
                  child: StickerImage(
                    hash: item.fileHash,
                    fileType: item.fileType,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  ':${widget.identifier}:',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 4.0,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 16,
            right: 12,
            child: IconButton(
              onPressed: () => entry.remove(),
              icon: Icon(Icons.close, color: Colors.white70, shadows: shadow),
            ),
          ),
        ],
      ),
    );
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
      width: widget.size,
      height: widget.size,
      child: const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
    );
    }
    final item = _item;
    if (item == null) return Text(widget.fallback, style: widget.style);
    return GestureDetector(
      onTap: () => _showEnlarged(context),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: StickerImage(
          key: ValueKey('${item.fileHash}_${item.fileType}'),
          hash: item.fileHash,
          fileType: item.fileType,
        ),
      ),
    );
  }
}
