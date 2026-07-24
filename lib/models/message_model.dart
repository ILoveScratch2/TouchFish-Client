import 'notification_model.dart';
import 'file_attachment.dart';

enum MessageType { text, image, video, audio, file }

enum MessageStatus { pending, sent, delivered, failed }

class MessageMedia {
  final String path; // file path, URL, or file hash
  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  final double? aspectRatio;
  final Duration? duration;
  final List<int>? bytes;
  final String? fileHash; // server-side file hash for download

  const MessageMedia({
    required this.path,
    this.fileName,
    this.fileSize,
    this.mimeType,
    this.aspectRatio,
    this.duration,
    this.bytes,
    this.fileHash,
  });
}

class QuotedMessagePreview {
  final int? mid;
  final int? senderUid;
  final String? senderName;
  final String content;
  final String contentType;
  final String? fileHash;
  final String? fileName;
  final bool isDeleted;
  final bool isMissing;

  const QuotedMessagePreview({
    this.mid,
    this.senderUid,
    this.senderName,
    this.content = '',
    this.contentType = 'plain',
    this.fileHash,
    this.fileName,
    this.isDeleted = false,
    this.isMissing = false,
  });

  factory QuotedMessagePreview.fromMap(
    Map<String, dynamic> json, {
    int? fallbackMid,
  }) {
    return QuotedMessagePreview(
      mid: _asInt(json['mid'] ?? json['message_id']) ?? fallbackMid,
      senderUid: _asInt(json['sender_uid'] ?? json['uid']),
      senderName: (json['sender_name'] ?? json['username'])?.toString(),
      content: (json['content'] ?? json['text'] ?? '').toString(),
      contentType: (json['content_type'] ?? json['type'] ?? 'plain').toString(),
      fileHash: json['file_hash']?.toString(),
      fileName: json['file_name']?.toString(),
      isDeleted: json['deleted'] == true || json['deleted_at'] != null,
      isMissing: json['missing'] == true || json['not_found'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'mid': mid,
    'senderUid': senderUid,
    'senderName': senderName,
    'content': content,
    'contentType': contentType,
    'fileHash': fileHash,
    'fileName': fileName,
    'isDeleted': isDeleted,
    'isMissing': isMissing,
  };

  factory QuotedMessagePreview.fromJson(Map<String, dynamic> json) {
    return QuotedMessagePreview(
      mid: _asInt(json['mid']),
      senderUid: _asInt(json['senderUid']),
      senderName: json['senderName'] as String?,
      content: json['content'] as String? ?? '',
      contentType: json['contentType'] as String? ?? 'plain',
      fileHash: json['fileHash'] as String?,
      fileName: json['fileName'] as String?,
      isDeleted: json['isDeleted'] as bool? ?? false,
      isMissing: json['isMissing'] as bool? ?? false,
    );
  }

  QuotedMessagePreview asRecalled() => QuotedMessagePreview(
    mid: mid,
    senderUid: senderUid,
    senderName: senderName,
    contentType: 'plain',
    isDeleted: true,
  );

  QuotedMessagePreview copyWith({String? senderName}) => QuotedMessagePreview(
    mid: mid,
    senderUid: senderUid,
    senderName: senderName ?? this.senderName,
    content: content,
    contentType: contentType,
    fileHash: fileHash,
    fileName: fileName,
    isDeleted: isDeleted,
    isMissing: isMissing,
  );
}

class ChatMessage {
  final String id;
  final int? mid;
  final String? clientMid;
  final int? senderUid;
  final MessageStatus status;
  final String text;
  final DateTime timestamp;
  final bool isMe;
  final String? senderName;
  final String? senderAvatar;
  final MessageType type;
  final MessageMedia? media;
  final String? ackError;
  final List<int> mentionedUids;
  final bool mentionsMe;
  final bool? shouldAlert;
  final int? quoteMid;
  final QuotedMessagePreview? quotePreview;
  final int? forwardedMid;
  final QuotedMessagePreview? forwardPreview;
  final bool isDeleted;
  final DateTime? deletedAt;
  final int? deletedBy;

  ChatMessage({
    required this.id,
    this.mid,
    this.clientMid,
    this.senderUid,
    this.status = MessageStatus.sent,
    required this.text,
    required this.timestamp,
    required this.isMe,
    this.senderName,
    this.senderAvatar,
    this.type = MessageType.text,
    this.media,
    this.ackError,
    this.mentionedUids = const [],
    this.mentionsMe = false,
    this.shouldAlert,
    this.quoteMid,
    this.quotePreview,
    this.forwardedMid,
    this.forwardPreview,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
  });

  ChatMessage copyWith({
    String? id,
    int? mid,
    String? clientMid,
    int? senderUid,
    MessageStatus? status,
    String? text,
    DateTime? timestamp,
    bool? isMe,
    String? senderName,
    String? senderAvatar,
    MessageType? type,
    MessageMedia? media,
    String? ackError,
    bool clearAckError = false,
    List<int>? mentionedUids,
    bool? mentionsMe,
    bool? shouldAlert,
    int? quoteMid,
    QuotedMessagePreview? quotePreview,
    int? forwardedMid,
    QuotedMessagePreview? forwardPreview,
    bool? isDeleted,
    DateTime? deletedAt,
    int? deletedBy,
    bool clearMedia = false,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      mid: mid ?? this.mid,
      clientMid: clientMid ?? this.clientMid,
      senderUid: senderUid ?? this.senderUid,
      status: status ?? this.status,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isMe: isMe ?? this.isMe,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      type: type ?? this.type,
      media: clearMedia ? null : media ?? this.media,
      ackError: clearAckError ? null : ackError ?? this.ackError,
      mentionedUids: mentionedUids ?? this.mentionedUids,
      mentionsMe: mentionsMe ?? this.mentionsMe,
      shouldAlert: shouldAlert ?? this.shouldAlert,
      quoteMid: quoteMid ?? this.quoteMid,
      quotePreview: quotePreview ?? this.quotePreview,
      forwardedMid: forwardedMid ?? this.forwardedMid,
      forwardPreview: forwardPreview ?? this.forwardPreview,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
    );
  }

  /// Create from a server notification event (WebSocket push or polling).
  factory ChatMessage.fromNotification({
    required NotificationInfo notification,
    required int myUid,
    String? senderName,
    String? senderAvatar,
  }) {
    final event = notification.event;
    final content = notification.content;
    final clientMid = notification.clientMid;
    final rawSenderUid = notification.senderUid;
    final senderUid = rawSenderUid ?? 0;
    final serverMid = notification.mid;

    final isMe = senderUid == myUid;
    final dt = notification.dateTime;
    final id = serverMid?.toString() ?? notification.timeStamp.toString();
    final suid = rawSenderUid;
    final resolvedName = isMe ? null : (senderName ?? 'User $senderUid');

    if (event == 'message.file') {
      final fileHash = notification.fileHash ?? content;
      final attachment = FileAttachment.fromMap({
        ...?notification.fileMetadata,
        'file_hash': fileHash,
      });
      return ChatMessage(
        id: id,
        mid: serverMid,
        clientMid: clientMid,
        senderUid: suid,
        text: '[FILE]',
        timestamp: dt,
        isMe: isMe,
        senderName: resolvedName,
        senderAvatar: senderAvatar,
        type: MessageType.file,
        media: MessageMedia(
          path: fileHash,
          fileName: attachment.fileName,
          fileSize: attachment.fileSize,
          mimeType: attachment.mimeType,
          fileHash: fileHash,
        ),
        mentionedUids: notification.mentionedUids,
        mentionsMe: notification.mentionsMe,
        shouldAlert: notification.shouldAlert,
        quoteMid:
            notification.quoteMid ??
            _quotePreview(notification.quotePreview, null)?.mid,
        quotePreview: _quotePreview(
          notification.quotePreview,
          notification.quoteMid,
        ),
        forwardedMid: notification.forwardedMid,
        forwardPreview: _quotePreview(
          notification.forwardPreview,
          notification.forwardedMid,
        ),
      );
    }

    return ChatMessage(
      id: id,
      mid: serverMid,
      clientMid: clientMid,
      senderUid: suid,
      text: content,
      timestamp: dt,
      isMe: isMe,
      senderName: resolvedName,
      senderAvatar: senderAvatar,
      type: MessageType.text,
      mentionedUids: notification.mentionedUids,
      mentionsMe: notification.mentionsMe,
      shouldAlert: notification.shouldAlert,
      quoteMid:
          notification.quoteMid ??
          _quotePreview(notification.quotePreview, null)?.mid,
      quotePreview: _quotePreview(
        notification.quotePreview,
        notification.quoteMid,
      ),
      forwardedMid: notification.forwardedMid,
      forwardPreview: _quotePreview(
        notification.forwardPreview,
        notification.forwardedMid,
      ),
    );
  }

  /// Create from a /message/history record (direct DB row).
  factory ChatMessage.fromMessageRecord(Map<String, dynamic> json, int myUid) {
    final mid = (json['mid'] as num?)?.toInt();
    final clientMid = json['client_mid'] as String?;
    final senderUid = (json['sender_uid'] as num?)?.toInt() ?? 0;
    final content = json['content'] as String? ?? '';
    final contentType = json['content_type'] as String? ?? 'plain';
    final sendTime = (json['send_time'] as num?)?.toDouble() ?? 0.0;
    final deleted = json['deleted'] == true || json['deleted_at'] != null;
    final quoteMid = _asInt(json['quote']);
    final quoteRaw =
        json['quote_preview'] ??
        json['reply_preview'] ??
        json['quoted_message'] ??
        (json['quote'] is Map ? json['quote'] : null);
    final quotePreview = _quotePreview(quoteRaw, quoteMid);
    final forwardedMid = _asInt(json['forwarded']);
    final forwardPreview = _quotePreview(
      json['forward_preview'] ?? json['forwarded_message'],
      forwardedMid,
    );
    final mentionedUids = (json['mentioned_uids'] as List<dynamic>? ?? const [])
        .map((uid) => (uid as num).toInt())
        .toList();

    final isMe = senderUid == myUid;
    final dt = DateTime.fromMillisecondsSinceEpoch((sendTime * 1000).toInt());
    final deletedAt = _dateTimeFromServer(json['deleted_at']);

    if (deleted) {
      return ChatMessage(
        id: mid?.toString() ?? sendTime.toString(),
        mid: mid,
        clientMid: clientMid,
        senderUid: senderUid,
        text: '',
        timestamp: dt,
        isMe: isMe,
        isDeleted: true,
        deletedAt: deletedAt,
        deletedBy: _asInt(json['deleted_by']),
        quoteMid: quoteMid,
        quotePreview: quotePreview,
        forwardedMid: forwardedMid,
        forwardPreview: forwardPreview,
      );
    }

    if (contentType == 'file') {
      final fileHash = json['file_hash'] as String? ?? content;
      final nestedMetadata = json['file_metadata'] is Map
          ? Map<String, dynamic>.from(json['file_metadata'] as Map)
          : json['file'] is Map
          ? Map<String, dynamic>.from(json['file'] as Map)
          : const <String, dynamic>{};
      final attachment = FileAttachment.fromMap({
        ...nestedMetadata,
        ...json,
        'file_hash': fileHash,
      });
      return ChatMessage(
        id: mid?.toString() ?? sendTime.toString(),
        mid: mid,
        clientMid: clientMid,
        senderUid: senderUid,
        text: '[FILE]',
        timestamp: dt,
        isMe: isMe,
        type: MessageType.file,
        media: MessageMedia(
          path: fileHash,
          fileName: attachment.fileName,
          fileSize: attachment.fileSize,
          mimeType: attachment.mimeType,
          fileHash: fileHash,
        ),
        mentionedUids: mentionedUids,
        mentionsMe: mentionedUids.contains(myUid),
        quoteMid: quoteMid,
        quotePreview: quotePreview,
        forwardedMid: forwardedMid,
        forwardPreview: forwardPreview,
      );
    }

    return ChatMessage(
      id: mid?.toString() ?? sendTime.toString(),
      mid: mid,
      clientMid: clientMid,
      senderUid: senderUid,
      text: content,
      timestamp: dt,
      isMe: isMe,
      type: MessageType.text,
      mentionedUids: mentionedUids,
      mentionsMe: mentionedUids.contains(myUid),
      quoteMid: quoteMid,
      quotePreview: quotePreview,
      forwardedMid: forwardedMid,
      forwardPreview: forwardPreview,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mid': mid,
      'clientMid': clientMid,
      'senderUid': senderUid,
      'status': status.index,
      'text': text,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isMe': isMe,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'type': type.index,
      'ackError': ackError,
      'mentionedUids': mentionedUids,
      'mentionsMe': mentionsMe,
      'shouldAlert': shouldAlert,
      'quoteMid': quoteMid,
      if (quotePreview != null) 'quotePreview': quotePreview!.toJson(),
      'forwardedMid': forwardedMid,
      if (forwardPreview != null) 'forwardPreview': forwardPreview!.toJson(),
      'isDeleted': isDeleted,
      if (deletedAt != null) 'deletedAt': deletedAt!.millisecondsSinceEpoch,
      'deletedBy': deletedBy,
      if (media != null)
        'media': {
          'path': media!.path,
          'fileName': media!.fileName,
          'fileSize': media!.fileSize,
          'mimeType': media!.mimeType,
          'fileHash': media!.fileHash,
        },
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json, {int? activeUid}) {
    MessageMedia? media;
    if (json['media'] is Map) {
      final m = json['media'] as Map<String, dynamic>;
      media = MessageMedia(
        path: m['path'] as String? ?? '',
        fileName: m['fileName'] as String?,
        fileSize: m['fileSize'] as int?,
        mimeType: m['mimeType'] as String?,
        fileHash: m['fileHash'] as String?,
      );
    }
    final rawStatus =
        (json['status'] as num?)?.toInt() ?? MessageStatus.sent.index;
    final rawType = (json['type'] as num?)?.toInt() ?? MessageType.text.index;
    final status = rawStatus >= 0 && rawStatus < MessageStatus.values.length
        ? MessageStatus.values[rawStatus]
        : MessageStatus.sent;
    final type = rawType >= 0 && rawType < MessageType.values.length
        ? MessageType.values[rawType]
        : MessageType.text;
    var senderUid = (json['senderUid'] as num?)?.toInt();
    final legacyIsMe = json['isMe'] as bool? ?? false;
    if (senderUid == null && activeUid != null && legacyIsMe) {
      senderUid = activeUid;
    }
    return ChatMessage(
      id: json['id'] as String? ?? '',
      mid: (json['mid'] as num?)?.toInt(),
      clientMid: json['clientMid'] as String?,
      senderUid: senderUid,
      status: status,
      text: json['text'] as String? ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (json['timestamp'] as int?) ?? 0,
      ),
      isMe: activeUid != null && senderUid != null
          ? senderUid == activeUid
          : legacyIsMe,
      senderName: json['senderName'] as String?,
      senderAvatar: json['senderAvatar'] as String?,
      type: type,
      media: media,
      ackError: json['ackError'] as String?,
      mentionedUids: (json['mentionedUids'] as List<dynamic>? ?? const [])
          .map((uid) => (uid as num).toInt())
          .toList(),
      mentionsMe: json['mentionsMe'] as bool? ?? false,
      shouldAlert: json['shouldAlert'] as bool?,
      quoteMid: _asInt(json['quoteMid']),
      quotePreview: json['quotePreview'] is Map
          ? QuotedMessagePreview.fromJson(
              Map<String, dynamic>.from(json['quotePreview'] as Map),
            )
          : null,
      forwardedMid: _asInt(json['forwardedMid']),
      forwardPreview: json['forwardPreview'] is Map
          ? QuotedMessagePreview.fromJson(
              Map<String, dynamic>.from(json['forwardPreview'] as Map),
            )
          : null,
      isDeleted: json['isDeleted'] as bool? ?? false,
      deletedAt: json['deletedAt'] is num
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['deletedAt'] as num).toInt(),
            )
          : null,
      deletedBy: _asInt(json['deletedBy']),
    );
  }

  ChatMessage asTombstone({DateTime? at, int? by}) => copyWith(
    text: '',
    type: MessageType.text,
    clearMedia: true,
    isDeleted: true,
    deletedAt: at ?? DateTime.now(),
    deletedBy: by,
  );
}

int? _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

DateTime? _dateTimeFromServer(dynamic value) {
  if (value == null) return null;
  if (value is num) {
    final raw = value.toDouble();
    return DateTime.fromMillisecondsSinceEpoch(
      (raw > 100000000000 ? raw : raw * 1000).toInt(),
    );
  }
  return DateTime.tryParse(value.toString());
}

QuotedMessagePreview? _quotePreview(dynamic raw, int? fallbackMid) {
  if (raw is Map) {
    return QuotedMessagePreview.fromMap(
      Map<String, dynamic>.from(raw),
      fallbackMid: fallbackMid,
    );
  }
  if (fallbackMid != null && fallbackMid >= 0) {
    return QuotedMessagePreview(mid: fallbackMid, isMissing: true);
  }
  return null;
}
