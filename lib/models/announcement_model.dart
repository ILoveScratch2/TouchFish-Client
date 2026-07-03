class Announcement {
  final String timeStamp;
  final int sender;
  final String content;
  final String? senderName;

  Announcement({
    required this.timeStamp,
    required this.sender,
    required this.content,
    this.senderName,
  });

  factory Announcement.fromJson(String timeStamp, Map<String, dynamic> json) {
    return Announcement(
      timeStamp: timeStamp,
      sender: (json['sender'] as num).toInt(),
      content: json['content'] as String,
    );
  }

  Announcement copyWith({String? senderName}) {
    return Announcement(
      timeStamp: timeStamp,
      sender: sender,
      content: content,
      senderName: senderName ?? this.senderName,
    );
  }

  DateTime get dateTime {
    final ts = double.tryParse(timeStamp) ?? 0;
    return DateTime.fromMillisecondsSinceEpoch((ts * 1000).toInt());
  }
}
