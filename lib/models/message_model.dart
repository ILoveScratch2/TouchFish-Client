enum MessageType {
  text,
  image,
  video,
  audio,
  file,
}

class MessageMedia {
  final String path; // file path or URL
  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  final double? aspectRatio; // images and videos
  final Duration? duration; // audio and video
  final List<int>? bytes; // fix web

  const MessageMedia({
    required this.path,
    this.fileName,
    this.fileSize,
    this.mimeType,
    this.aspectRatio,
    this.duration,
    this.bytes,
  });
}

class ChatMessage {
  final String id;
  final String text;
  final DateTime timestamp;
  final bool isMe;
  final String? senderName;
  final String? senderAvatar;
  final MessageType type;
  final MessageMedia? media;

  ChatMessage({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.isMe,
    this.senderName,
    this.senderAvatar,
    this.type = MessageType.text,
    this.media,
  });

  ChatMessage copyWith({
    String? id,
    String? text,
    DateTime? timestamp,
    bool? isMe,
    String? senderName,
    String? senderAvatar,
    MessageType? type,
    MessageMedia? media,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isMe: isMe ?? this.isMe,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      type: type ?? this.type,
      media: media ?? this.media,
    );
  }
}
