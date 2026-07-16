import 'notification_model.dart';

enum MessageType {
  text,
  image,
  video,
  audio,
  file,
}

enum MessageStatus {
  pending,
  sent,
  delivered,
  failed,
}

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
      media: media ?? this.media,
      ackError: ackError ?? this.ackError,
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
          fileName: fileHash,
          fileHash: fileHash,
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

    final isMe = senderUid == myUid;
    final dt = DateTime.fromMillisecondsSinceEpoch((sendTime * 1000).toInt());

    if (contentType == 'file') {
      final fileHash = json['file_hash'] as String? ?? content;
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
          fileName: fileHash,
          fileHash: fileHash,
        ),
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
      if (media != null) 'media': {
        'path': media!.path,
        'fileName': media!.fileName,
        'fileSize': media!.fileSize,
        'mimeType': media!.mimeType,
        'fileHash': media!.fileHash,
      },
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
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
    final rawStatus = (json['status'] as num?)?.toInt() ?? MessageStatus.sent.index;
    final rawType = (json['type'] as num?)?.toInt() ?? MessageType.text.index;
    final status = rawStatus >= 0 && rawStatus < MessageStatus.values.length
        ? MessageStatus.values[rawStatus]
        : MessageStatus.sent;
    final type = rawType >= 0 && rawType < MessageType.values.length
        ? MessageType.values[rawType]
        : MessageType.text;
    return ChatMessage(
      id: json['id'] as String? ?? '',
      mid: (json['mid'] as num?)?.toInt(),
      clientMid: json['clientMid'] as String?,
      senderUid: (json['senderUid'] as num?)?.toInt(),
      status: status,
      text: json['text'] as String? ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch((json['timestamp'] as int?) ?? 0),
      isMe: json['isMe'] as bool? ?? false,
      senderName: json['senderName'] as String?,
      senderAvatar: json['senderAvatar'] as String?,
      type: type,
      media: media,
    );
  }
}
