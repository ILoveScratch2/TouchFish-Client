class TypingStatus {
  final int uid;
  final String scope; // 'typing' | 'uploading'
  final DateTime updatedAt; // TTL 判断
  final DateTime timestamp; // 来自服务端 ts，用于乱序保护
  final double? progress; // uploading 进度，0~1 或 null

  const TypingStatus({
    required this.uid,
    required this.scope,
    required this.updatedAt,
    required this.timestamp,
    this.progress,
  });

  /// 复合键（显然一个用户可以一起用）
  String get compositeKey => '$uid:$scope';
}
