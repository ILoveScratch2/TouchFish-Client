import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/sticker_model.dart';
import '../../providers/sticker/sticker_provider.dart';
import 'sticker_image.dart';

/// Sticker 自动补全
/// 
/// 打广告：https://www.luogu.com.cn/article/8o5kwvgy
class StickerAutocompleteOverlay extends ConsumerWidget {
  final String query;
  final Function(String stickerText) onSelect;

  const StickerAutocompleteOverlay({
    super.key,
    required this.query,
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

        final colorScheme = Theme.of(context).colorScheme;
        return Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          color: colorScheme.surfaceContainerHigh,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 300),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: matches.length,
                itemBuilder: (context, index) {
                  final match = matches[index];
                  final text = ':${match.pack.prefix}+${match.sticker.slug}:';
                  return _StickerMatchTile(
                    match: match,
                    text: text,
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

/// Sticker 自动补全候选
class _StickerMatchTile extends StatelessWidget {
  final StickerMatch match;
  final String text;
  final VoidCallback onTap;

  const _StickerMatchTile({
    required this.match,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: StickerImage(
                hash: match.sticker.fileHash,
                fileType: match.sticker.fileType,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text,
                    style: textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (match.sticker.name?.isNotEmpty == true)
                    Text(
                      match.sticker.name!,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sticker 输入助手：监听文本变化与焦点，在输入框上方显示自动补全浮层。
///
/// 定位锚点 [layerLink] 由外部共享，委屈委屈 @ 了
class StickerInputHelper extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final LayerLink layerLink;
  final Function(String) onStickerSelected;

  const StickerInputHelper({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.layerLink,
    required this.onStickerSelected,
  });

  @override
  State<StickerInputHelper> createState() => _StickerInputHelperState();
}

class _StickerInputHelperState extends State<StickerInputHelper> {
  OverlayEntry? _overlayEntry;
  String? _currentQuery;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _disposed = true;
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChanged() {
    // 失焦收浮层（稍延时，允许点击候选条目时的焦点转移先完成）
    if (!widget.focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!_disposed) _hideAutocomplete();
      });
    }
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final cursorPos = widget.controller.selection.baseOffset;

    if (cursorPos < 0 || !widget.focusNode.hasFocus) {
      _hideAutocomplete();
      return;
    }
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

    // 与 @ 提及一致
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: 0,
        top: 0,
        child: CompositedTransformFollower(
          link: widget.layerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.topLeft,
          followerAnchor: Alignment.bottomLeft,
          offset: const Offset(0, -4),
          child: StickerAutocompleteOverlay(
            query: query,
            onSelect: (stickerText) {
              _insertSticker(stickerText);
              _hideAutocomplete();
            },
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

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







/// 兄弟兄弟，真有人看代码吗？
/// 如果你看到了这一行……那么………………
/// 去给我的文章点赞！
/// https://www.luogu.com.cn/article/8o5kwvgy
/// 
/// by YWD2023