class NotificationInfo {
  final int id;
  final double timeStamp;
  final double? readAt;
  final String event;
  final String title;
  final String content;
  final String? senderRaw; // raw server format: "U123" or "G456U123"
  final Map<String, dynamic> meta;
  final int? mid; // message ID
  final String? clientMid; // client message
  final String? roomId; // explicit room id
  final String? fileHash; // file hash
  final int? groupId; // group ID
  final List<int> mentionedUids;
  final bool mentionsMe;
  final bool? shouldAlert;
  final int? quoteMid;
  final Map<String, dynamic>? quotePreview;
  final int? forwardedMid;
  final Map<String, dynamic>? forwardPreview;
  final Map<String, dynamic>? fileMetadata;
  final int? recalledMid;
  final int? deletedBy;
  final DateTime? deletedAt;

  const NotificationInfo({
    this.id = -1,
    required this.timeStamp,
    this.readAt,
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
    this.mentionedUids = const [],
    this.mentionsMe = false,
    this.shouldAlert,
    this.quoteMid,
    this.quotePreview,
    this.forwardedMid,
    this.forwardPreview,
    this.fileMetadata,
    this.recalledMid,
    this.deletedBy,
    this.deletedAt,
  });

  NotificationInfo withReadAt(double value) => NotificationInfo(
    id: id,
    timeStamp: timeStamp,
    readAt: value,
    event: event,
    title: title,
    content: content,
    senderRaw: senderRaw,
    meta: meta,
    mid: mid,
    clientMid: clientMid,
    roomId: roomId,
    fileHash: fileHash,
    groupId: groupId,
    mentionedUids: mentionedUids,
    mentionsMe: mentionsMe,
    shouldAlert: shouldAlert,
    quoteMid: quoteMid,
    quotePreview: quotePreview,
    forwardedMid: forwardedMid,
    forwardPreview: forwardPreview,
    fileMetadata: fileMetadata,
    recalledMid: recalledMid,
    deletedBy: deletedBy,
    deletedAt: deletedAt,
  );

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
    final rawMeta = info['meta'];
    final rawQuote = info['quote'] ?? (rawMeta is num ? rawMeta : null);
    final preview =
        info['quote_preview'] ??
        info['reply_preview'] ??
        info['quoted_message'];
    final rawForwarded = info['forwarded'] ?? info['forwarded_message_id'];
    final forwardPreview = info['forward_preview'] ?? info['forwarded_message'];
    return NotificationInfo(
      id: _notificationInt(json['id']) ?? -1,
      timeStamp:
          (json['time_stamp'] as num?)?.toDouble() ??
          (outerInfo['time_stamp'] as num?)?.toDouble() ??
          0.0,
      readAt: _notificationDouble(json['read_at']),
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
      mentionedUids: (info['mentioned_uids'] as List<dynamic>? ?? const [])
          .map((uid) => (uid as num).toInt())
          .toList(),
      mentionsMe: info['mentions_me'] as bool? ?? false,
      shouldAlert: info['should_alert'] as bool?,
      quoteMid: rawQuote is num
          ? rawQuote.toInt()
          : (rawQuote is String ? int.tryParse(rawQuote) : null),
      quotePreview: preview is Map
          ? Map<String, dynamic>.from(preview)
          : rawQuote is Map
          ? Map<String, dynamic>.from(rawQuote)
          : null,
      forwardedMid: _notificationInt(rawForwarded),
      forwardPreview: forwardPreview is Map
          ? Map<String, dynamic>.from(forwardPreview)
          : null,
      fileMetadata: info['file'] is Map
          ? Map<String, dynamic>.from(info['file'] as Map)
          : null,
      recalledMid: _notificationInt(
        info['recalled_mid'] ?? info['message_mid'] ?? info['mid'],
      ),
      deletedBy: _notificationInt(info['deleted_by']),
      deletedAt: _notificationDateTime(info['deleted_at']),
    );
  }

  /// 解析服务端 MESSAGE.NEW / MESSAGE.RECALLED 的 message（旧 info）。
  factory NotificationInfo.fromServerMessageInfo(Map<String, dynamic> json) {
    final rawQuote = json['quote'];
    final preview =
        json['quote_preview'] ??
        json['reply_preview'] ??
        json['quoted_message'];
    return NotificationInfo(
      timeStamp: (json['time_stamp'] as num?)?.toDouble() ?? 0.0,
      event: json['event'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      senderRaw: json['sender']?.toString(),
      meta: json['meta'] is Map<String, dynamic>
          ? json['meta'] as Map<String, dynamic>
          : {},
      mid: _notificationInt(json['mid']),
      clientMid: json['client_mid'] as String?,
      roomId: json['room_id'] as String?,
      fileHash: json['file_hash'] as String?,
      groupId: _notificationInt(json['group_id']),
      mentionedUids: (json['mentioned_uids'] as List<dynamic>? ?? const [])
          .map((uid) => (uid as num).toInt())
          .toList(),
      mentionsMe: json['mentions_me'] as bool? ?? false,
      shouldAlert: json['should_alert'] as bool?,
      quoteMid: rawQuote is num
          ? rawQuote.toInt()
          : (rawQuote is String ? int.tryParse(rawQuote) : null),
      quotePreview: preview is Map
          ? Map<String, dynamic>.from(preview)
          : rawQuote is Map
          ? Map<String, dynamic>.from(rawQuote)
          : null,
      forwardedMid: _notificationInt(json['forwarded']),
      forwardPreview: json['forward_preview'] is Map
          ? Map<String, dynamic>.from(json['forward_preview'] as Map)
          : null,
      fileMetadata: json['file'] is Map
          ? Map<String, dynamic>.from(json['file'] as Map)
          : null,
      recalledMid: _notificationInt(json['recalled_mid'] ?? json['mid']),
      deletedBy: _notificationInt(json['deleted_by']),
      deletedAt: _notificationDateTime(json['deleted_at']),
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
  bool get isInviteEvent =>
      isFriendEvent ||
      event == 'group.invited' ||
      event == 'group.join.request' ||
      event == 'group.join.approved';
  int? get groupEventGid => (meta['gid'] as num?)?.toInt();
  int? get groupRequestRid => (meta['rid'] as num?)?.toInt();

  String get identityKey => [
    timeStamp,
    event,
    senderRaw ?? '',
    mid ?? '',
    clientMid ?? '',
    content,
  ].join('|');
}

int? _notificationInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? _notificationDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

DateTime? _notificationDateTime(dynamic value) {
  if (value == null) return null;
  if (value is num) {
    final number = value.toDouble();
    return DateTime.fromMillisecondsSinceEpoch(
      (number > 100000000000 ? number : number * 1000).toInt(),
    );
  }
  return DateTime.tryParse(value.toString());
}
