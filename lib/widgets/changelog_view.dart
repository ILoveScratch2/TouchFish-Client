import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_alert_dialog.dart';
import 'markdown_renderer.dart';

/// 更新日志在弹窗中占用的高度上限
/// 
double changelogBoxHeight(BuildContext context) {
  final height = MediaQuery.sizeOf(context).height;
  return (height * 0.45).clamp(160.0, 440.0);
}

/// 把 Markdown 切成若干段，逐段渲染
List<String> splitMarkdownIntoChunks(
  String source, {
  int targetChars = 900,
  int maxListItemRun = 10,
}) {
  final lines = source.split('\n');
  final chunks = <String>[];
  final buffer = <String>[];
  var bufferChars = 0;
  var listRun = 0;
  var inFence = false;

  void flush() {
    if (buffer.isEmpty) return;
    final text = buffer.join('\n').trimRight();
    if (text.trim().isNotEmpty) chunks.add(text);
    buffer.clear();
    bufferChars = 0;
    listRun = 0;
  }

  for (final line in lines) {
    final trimmedLeft = line.trimLeft();
    final isFenceMarker =
        trimmedLeft.startsWith('```') || trimmedLeft.startsWith('~~~');
    buffer.add(line);
    bufferChars += line.length + 1;

    if (isFenceMarker) {
      inFence = !inFence;
      continue;
    }
    if (inFence) continue;

    final isListItem = _listItemPattern.hasMatch(line);
    listRun = isListItem ? listRun + 1 : 0;

    final atBlockBoundary = line.trim().isEmpty;
    final atListBoundary = isListItem && listRun >= maxListItemRun;
    if (bufferChars >= targetChars && (atBlockBoundary || atListBoundary)) {
      flush();
    }
  }
  flush();

  if (chunks.isEmpty) return const <String>[];
  return chunks;
}

final RegExp _listItemPattern = RegExp(r'^\s{0,3}([-*+]|\d+[.)])\s+');

/// 上游更新日志的渲染视图
class ChangelogView extends StatefulWidget {
  const ChangelogView({
    super.key,
    required this.markdown,
    this.maxHeight = 320,
    this.scrollable = true,
    this.previewChars = 700,
    this.padding = const EdgeInsets.all(12),
  });

  final String markdown;

  /// 高度上限
  /// 内容超出后由内部滚动
  final double maxHeight;

  /// 是否允许滚动
  final bool scrollable;

  final int previewChars;

  final EdgeInsetsGeometry padding;

  @override
  State<ChangelogView> createState() => _ChangelogViewState();
}

class _ChangelogViewState extends State<ChangelogView> {
  /// 首屏构建的分块数
  static const int _firstBatch = 2;

  /// 每次追加的分块数
  static const int _nextBatch = 3;

  /// 距离底部多远开始追加
  static const double _appendThreshold = 320;

  final ScrollController _controller = ScrollController();

  List<String> _chunks = const <String>[];
  int _built = 0;
  bool _fillScheduled = false;

  @override
  void initState() {
    super.initState();
    _reset();
    _controller.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(covariant ChangelogView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.markdown != widget.markdown) {
      _reset();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleScroll);
    _controller.dispose();
    super.dispose();
  }

  void _reset() {
    _chunks = splitMarkdownIntoChunks(widget.markdown);
    _built = math.min(_firstBatch, _chunks.length);
  }

  void _handleScroll() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    if (position.pixels >= position.maxScrollExtent - _appendThreshold) {
      _appendMore();
    }
  }

  void _appendMore() {
    if (_built >= _chunks.length) return;
    setState(() => _built = math.min(_chunks.length, _built + _nextBatch));
  }

  /// 否则根本没有滚动事件
  void _scheduleFillViewport() {
    if (_fillScheduled || _built >= _chunks.length || !widget.scrollable) {
      return;
    }
    _fillScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fillScheduled = false;
      if (!mounted || _built >= _chunks.length) return;
      final position = _controller.hasClients ? _controller.position : null;
      final notScrollable = position == null || position.maxScrollExtent <= 0;
      if (notScrollable ||
          position.pixels >= position.maxScrollExtent - _appendThreshold) {
        _appendMore();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Widget body;
    if (widget.scrollable) {
      _scheduleFillViewport();
      body = Scrollbar(
        controller: _controller,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _controller,
          padding: widget.padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < _built; i++)
                MarkdownRenderer(data: _chunks[i]),
            ],
          ),
        ),
      );
    } else {
      // 预览
      body = SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: widget.padding,
        child: MarkdownRenderer(data: _previewText()),
      );
    }

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: body,
    );
  }

  /// 取开头若干段拼成预览文本
  String _previewText() {
    final buffer = StringBuffer();
    for (final chunk in _chunks) {
      buffer.writeln(chunk);
      if (buffer.length >= widget.previewChars) break;
    }
    return buffer.toString().trimRight();
  }
}

/// 以弹窗形式展示完整更新日志
Future<void> showChangelogDialog(
  BuildContext context, {
  required String markdown,
  String? title,
  String? subtitle,
}) {
  return showTouchFishInfoDialog<void>(
    context,
    title: title,
    message: '',
    icon: Icons.article_outlined,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (subtitle != null && subtitle.isNotEmpty) ...[
          Text(subtitle),
          const SizedBox(height: 12),
        ],
        // 固定高度
        SizedBox(
          height: changelogBoxHeight(context),
          child: ChangelogView(
            markdown: markdown,
            maxHeight: changelogBoxHeight(context),
          ),
        ),
      ],
    ),
  );
}
