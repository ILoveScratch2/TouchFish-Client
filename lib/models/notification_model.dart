class NotificationInfo {
  final double timeStamp;
  final String event;
  final String title;
  final String content;
  final String? senderRaw; // raw server format: "U123" or "G456U123"
  final Map<String, dynamic> meta;
  final int? mid;          // message ID from messages table
  final String? clientMid; // client-generated message ID for optimistic dedupe
  final String? roomId;    // explicit room identifier such as U123 or G456
  final String? fileHash;  // file hash for message.file events
  final int? groupId;      // group ID for group messages

  const NotificationInfo({
    required this.timeStamp,
    required this.event,
    required this.title,
    required this.content,
    this.senderRaw,
    this.meta = const {},
    this.mid,
    this.clientMid,
    this.roomId,
    this.fileHash,
    this.groupId,
  });

  /// Parsed sender UID from the raw sender string.
  /// "U123" -> 123, "G456U123" -> 123
  int? get senderUid {
    if (senderRaw == null) return null;
    final s = senderRaw!;
    if (s.startsWith('U')) return int.tryParse(s.substring(1));
    final idx = s.lastIndexOf('U');
    if (idx >= 0) return int.tryParse(s.substring(idx + 1));
    return int.tryParse(s);
  }

  factory NotificationInfo.fromServerJson(Map<String, dynamic> json) {
    final outerInfo = json['info'] as Map<String, dynamic>? ?? {};

    // server message.plain handler nests an extra info level:
    // {info: {time_stamp: ..., info: {event: "message.plain", ...}}}
    // while message.file uses: {info: {time_stamp: ..., event: "message.file", ...}}
    final innerInfo = outerInfo['info'];
    final info = (innerInfo is Map<String, dynamic>) ? innerInfo : outerInfo;

    // Fallback: old channel.py messages put sender at outerInfo level
    final rawSender = info['sender'] ?? outerInfo['sender'];
    return NotificationInfo(
      timeStamp: (json['time_stamp'] as num?)?.toDouble() ?? 0.0,
      event: info['event'] as String? ?? '',
      title: info['title'] as String? ?? '',
      content: info['content'] as String? ?? '',
      senderRaw: rawSender is String ? rawSender : rawSender?.toString(),
      meta: info['meta'] is Map<String, dynamic>
          ? info['meta'] as Map<String, dynamic>
          : {},
      mid: (info['mid'] as num?)?.toInt(),
      clientMid: info['client_mid'] as String?,
      roomId: info['room_id'] as String?,
      fileHash: info['file_hash'] as String?,
      groupId: (info['group_id'] as num?)?.toInt(),
    );
  }

  DateTime get dateTime =>
      DateTime.fromMillisecondsSinceEpoch((timeStamp * 1000).toInt());

  bool get isFriendEvent => event.startsWith('friend.');
  bool get isAnnouncementEvent => event.startsWith('announcement.');
  bool get isMessageEvent => event.startsWith('message.');
  bool get isForumEvent => event.startsWith('forum.');
  bool get isGroupEvent => event.startsWith('group.');
  bool get isAuthEvent => event.startsWith('auth.');
}
