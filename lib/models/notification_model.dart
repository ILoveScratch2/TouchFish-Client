class NotificationInfo {
  final double timeStamp;
  final String event;
  final String title;
  final String content;
  final int? sender;
  final Map<String, dynamic> meta;

  const NotificationInfo({
    required this.timeStamp,
    required this.event,
    required this.title,
    required this.content,
    this.sender,
    this.meta = const {},
  });

  factory NotificationInfo.fromServerJson(Map<String, dynamic> json) {
    final info = json['info'] as Map<String, dynamic>? ?? {};
    return NotificationInfo(
      timeStamp: (json['time_stamp'] as num?)?.toDouble() ?? 0.0,
      event: info['event'] as String? ?? '',
      title: info['title'] as String? ?? '',
      content: info['content'] as String? ?? '',
      sender: (info['sender'] as num?)?.toInt(),
      meta: info['meta'] is Map<String, dynamic>
          ? info['meta'] as Map<String, dynamic>
          : {},
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
