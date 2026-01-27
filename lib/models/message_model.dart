class ChatMessage {
  final String id;
  final String text;
  final DateTime timestamp;
  final bool isMe;
  final String? senderName;
  final String? senderAvatar;

  ChatMessage({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.isMe,
    this.senderName,
    this.senderAvatar,
  });

  ChatMessage copyWith({
    String? id,
    String? text,
    DateTime? timestamp,
    bool? isMe,
    String? senderName,
    String? senderAvatar,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isMe: isMe ?? this.isMe,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
    );
  }
}
