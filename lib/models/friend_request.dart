/// 待处理的好友申请（/friend/requests 返回项）。
class FriendRequestEntry {
  final int uid;
  final String username;
  final String sign;
  final String message;
  final double requestAt;

  const FriendRequestEntry({
    required this.uid,
    required this.username,
    this.sign = '',
    this.message = '',
    this.requestAt = 0,
  });

  factory FriendRequestEntry.fromJson(Map<String, dynamic> json) {
    return FriendRequestEntry(
      uid: (json['uid'] as num?)?.toInt() ?? 0,
      username: json['username'] as String? ?? '',
      sign: json['sign'] as String? ?? '',
      message: json['message'] as String? ?? '',
      requestAt: (json['request_at'] as num?)?.toDouble() ?? 0,
    );
  }
}
