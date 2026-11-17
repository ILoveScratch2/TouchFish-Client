import 'package:intl/intl.dart';

/// 数值与时间统一格式化

/// 十进制
const List<String> _decimalUnits = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];

/// 二进制
const List<String> _binaryUnits = ['B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB'];

/// 将字节数格式化
String formatBytes(int bytes, {bool binary = false}) {
  if (bytes < 0) return '—';
  if (bytes < 1024) return '$bytes B';

  final units = binary ? _binaryUnits : _decimalUnits;
  var value = bytes / 1024;
  var unitIndex = 1;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  return '${value.toStringAsFixed(1)} ${units[unitIndex]}';
}

/// 默认的绝对时间格式
final DateFormat _defaultDateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');

String formatDateTime(DateTime time, {String? pattern}) {
  final format = pattern == null
      ? _defaultDateTimeFormat
      : DateFormat(pattern);
  return format.format(time);
}

/// 将秒时间戳格式化
String formatTimestamp(num? seconds, {String? pattern}) {
  if (seconds == null) return '—';
  final value = seconds.toInt();
  if (value <= 0) return '—';
  return formatDateTime(
    DateTime.fromMillisecondsSinceEpoch(value * 1000),
    pattern: pattern,
  );
}

/// 将通话时长格式化
String formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) return '$hours:$mm:$ss';
  return '$mm:$ss';
}
