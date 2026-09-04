import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/sticker_model.dart';
import '../../providers/sticker/sticker_provider.dart';

/// Sticker 自动补全
class StickerAutocompleteOverlay extends ConsumerWidget {
  final String query;
  final VoidCallback onDismiss;
  final Function(String stickerText) onSelect;

  const StickerAutocompleteOverlay({
    super.key,
    required this.query,
    required this.onDismiss,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packsAsync = ref.watch(myStickerPacksProvider);

    return packsAsync.when(
      data: (packs) {
        final matches = _findMatches(packs, query);

        if (matches.isEmpty) {
          return const SizedBox.shrink();
        }

        return Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 220,
              maxWidth: 320,
              minWidth: 160,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: matches.length,
              itemBuilder: (context, index) {
                final match = matches[index];
                final text = ':${match.pack.prefix}+${match.sticker.slug}:';
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.emoji_emotions, size: 20),
                  title: Text(
                    text,
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: match.sticker.name?.isNotEmpty == true
                      ? Text(
                          match.sticker.name!,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  onTap: () {
                    // 与实体选择器一致：记录最近使用（勿 await）
                    unawaited(
                      ref
                          .read(recentStickersProvider.notifier)
                          .recordUsage(match.pack, match.sticker),
                    );
                    onSelect(text);
                  },
                );
              },
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  static const int _maxMatches = 10;

  List<StickerMatch> _findMatches(
    List<OwnedStickerPack> packs,
    String query,
  ) {
    final matches = <StickerMatch>[];
    final lowerQuery = query.toLowerCase();

    // 解析查询：:prefix 或 :prefix+slug
    final parts = lowerQuery.split('+');
    final prefixQuery = parts[0];
    final slugQuery = parts.length > 1 ? parts[1] : null;

    for (final ownedPack in packs) {
      final pack = ownedPack.pack;

      if (!pack.prefix.toLowerCase().startsWith(prefixQuery)) {
        continue;
      }

      if (slugQuery != null && slugQuery.isNotEmpty) {
        for (final sticker in pack.stickers) {
          if (sticker.slug.toLowerCase().startsWith(slugQuery)) {
            matches.add(StickerMatch(pack: pack, sticker: sticker));
          }
        }
      } else {
        // 只输入了前缀：列出该包前几个贴纸供快速选择
        for (final sticker in pack.stickers.take(5)) {
          matches.add(StickerMatch(pack: pack, sticker: sticker));
        }
      }

      if (matches.length >= _maxMatches) {
        matches.removeRange(_maxMatches, matches.length);
        break;
      }
    }

    return matches;
  }
}

class StickerMatch {
  final StickerPack pack;
  final StickerItem sticker;

  StickerMatch({required this.pack, required this.sticker});
}

/// Sticker 输入助手：监听文本变化与焦点，在输入框上方显示自动补全浮层。
///
/// 需与输入框叠放
class StickerInputHelper extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(String) onStickerSelected;

  const StickerInputHelper({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onStickerSelected,
  });

  @override
  State<StickerInputHelper> createState() => _StickerInputHelperState();
}

class _StickerInputHelperState extends State<StickerInputHelper> {
  OverlayEntry? _overlayEntry;
  String? _currentQuery;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChanged() {
    // 失焦收浮层
    if (!widget.focusNode.hasFocus) {
      _hideAutocomplete();
    }
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final cursorPos = widget.controller.selection.baseOffset;

    if (cursorPos < 0) return;
    final beforeCursor = text.substring(0, cursorPos);

    // ':' 后至少一个合法字符，避免孤立的 ':' 弹出全部包slug 段允许 '-'（与消息渲染语法 :prefix+slug: 的 [A-Za-z0-9_-] 一致）否则含 '-' 的 slug 打字到一半浮层会消失。
    final match =
        RegExp(r':([A-Za-z0-9_]+(?:\+[A-Za-z0-9_-]*)?)$').firstMatch(
          beforeCursor,
        );

    if (match != null) {
      final query = match.group(1)!;
      if (query != _currentQuery) {
        _currentQuery = query;
        _showAutocomplete(query);
      }
    } else if (_currentQuery != null) {
      _hideAutocomplete();
    }
  }

  void _showAutocomplete(String query) {
    _removeOverlay();

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    if (!renderBox.hasSize) return;

    final position = renderBox.localToGlobal(Offset.zero);

    // 横向防 stack overflow：菜单宽上限 320，屏幕窄时收缩
    final screenWidth = MediaQuery.sizeOf(context).width;
    final left = position.dx.clamp(
      0.0,
      math.max(0.0, screenWidth - 320),
    ).toDouble();

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // 半透明不拦截
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _hideAutocomplete,
            ),
          ),
          Positioned(
            left: left,
            bottom: screenHeight(context) - position.dy + 8,
            child: StickerAutocompleteOverlay(
              query: query,
              onDismiss: _hideAutocomplete,
              onSelect: (stickerText) {
                _insertSticker(stickerText);
                _hideAutocomplete();
              },
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  double screenHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).height;

  void _hideAutocomplete() {
    _currentQuery = null;
    _removeOverlay();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _insertSticker(String stickerText) {
    final text = widget.controller.text;
    final cursorPos = widget.controller.selection.baseOffset;
    if (cursorPos < 0) return;

    final beforeCursor = text.substring(0, cursorPos);
    final colonIndex = beforeCursor.lastIndexOf(':');
    if (colonIndex == -1) return;

    final newText = text.substring(0, colonIndex) +
        stickerText +
        text.substring(cursorPos);

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: colonIndex + stickerText.length,
      ),
    );

    widget.onStickerSelected(stickerText);
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
