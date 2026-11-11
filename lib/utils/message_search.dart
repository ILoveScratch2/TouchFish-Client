/// 关键词命中摘要
library;

class SearchExcerpt {
  /// 摘要正文（可能带前导/尾随省略号）
  final String text;

  /// 命中词在 [text] 中的起始下标；-1 表示未命中（或不可见区域）
  final int matchStart;

  /// 命中词长度（可能大于原文剩余长度）
  final int matchLength;

  const SearchExcerpt({
    required this.text,
    this.matchStart = -1,
    this.matchLength = 0,
  });

  bool get hasMatch => matchStart >= 0 && matchLength > 0;
}

/// 生成命中摘要
///
/// - [radius]：命中词左右各保留的字符数
/// - 未命中时返回开头 [radius] * 2 个字符
SearchExcerpt buildSearchExcerpt(
  String source,
  String query, {
  int radius = 48,
}) {
  final normalizedQuery = query.trim();
  if (source.isEmpty) {
    return const SearchExcerpt(text: '');
  }
  if (normalizedQuery.isEmpty) {
    return SearchExcerpt(text: _truncateTail(source, radius * 2));
  }

  final index = source.toLowerCase().indexOf(normalizedQuery.toLowerCase());
  if (index < 0) {
    return SearchExcerpt(text: _truncateTail(source, radius * 2));
  }

  final start = (index - radius).clamp(0, source.length);
  final end = (index + normalizedQuery.length + radius).clamp(0, source.length);

  final leadingEllipsis = start > 0 ? '…' : '';
  final trailingEllipsis = end < source.length ? '…' : '';
  final body = source.substring(start, end).replaceAll('\n', ' ');

  return SearchExcerpt(
    text: '$leadingEllipsis$body$trailingEllipsis',
    matchStart: leadingEllipsis.length + (index - start),
    // 摘要里的换行被替换成空格后长度不变，直接沿用查询词长度即可。
    matchLength: normalizedQuery.length,
  );
}

String _truncateTail(String source, int limit) {
  if (source.length <= limit) return source;
  return '${source.substring(0, limit).replaceAll('\n', ' ')}…';
}
