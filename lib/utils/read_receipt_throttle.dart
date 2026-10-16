/// 已读回执补查节流器
class ReadReceiptThrottle {
  ReadReceiptThrottle({
    this.cooldown = const Duration(seconds: 3),
    this.timeout = const Duration(seconds: 15),
  });

  final Duration cooldown;

  /// 一次查询超过该时长仍未回调 [done] 就当作已经结束
  final Duration timeout;

  bool _inFlight = false;
  int? _mid;
  DateTime? _queriedAt;
  DateTime? _startedAt;

  bool shouldQuery(int mid, DateTime now) {
    if (_inFlight) {
      final startedAt = _startedAt;
      if (startedAt == null || now.difference(startedAt) >= timeout) {
        _inFlight = false;
      } else {
        return false;
      }
    }
    final queriedAt = _queriedAt;
    if (mid == _mid &&
        queriedAt != null &&
        now.difference(queriedAt) < cooldown) {
      return false;
    }
    _mid = mid;
    _queriedAt = now;
    _startedAt = now;
    _inFlight = true;
    return true;
  }

  /// 查询结束（成功或失败）后调用。
  void done() {
    _inFlight = false;
    _startedAt = null;
  }

  /// 换房间时调用：旧房间的节流状态不该跳过新房间的首次查询。
  void reset() {
    _inFlight = false;
    _mid = null;
    _queriedAt = null;
    _startedAt = null;
  }
}
