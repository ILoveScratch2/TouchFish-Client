import '../l10n/app_localizations.dart';

/// 将时间戳转换为相对时间
String formatTimeAgo(AppLocalizations l10n, int timestampSeconds) {
  if (timestampSeconds <= 0) return '—';

  final now = DateTime.now();
  final time = DateTime.fromMillisecondsSinceEpoch(timestampSeconds * 1000);
  final difference = now.difference(time);

  if (difference.isNegative) {
    return l10n.timeAgoJustNow;
  }

  final seconds = difference.inSeconds;
  final minutes = difference.inMinutes;
  final hours = difference.inHours;
  final days = difference.inDays;

  if (seconds < 60) {
    // 少于1分钟
    return l10n.timeAgoJustNow;
  } else if (minutes < 60) {
    // 1-59分钟
    return l10n.timeAgoMinutes(minutes);
  } else if (hours < 24) {
    // 1-23小时
    return l10n.timeAgoHours(hours);
  } else if (days < 7) {
    // 1-6天
    return l10n.timeAgoDays(days);
  } else if (days < 30) {
    // 1-4周
    final weeks = (days / 7).floor();
    return l10n.timeAgoWeeks(weeks);
  } else if (days < 365) {
    // 1-11个月
    final months = (days / 30).floor();
    return l10n.timeAgoMonths(months);
  } else {
    // 1年以上
    final years = (days / 365).floor();
    return l10n.timeAgoYears(years);
  }
}
