import 'file_attachment.dart';

/// 工单类型
enum TicketType {
  report('report'),
  consult('consult'),
  appeal('appeal');

  final String wire;
  const TicketType(this.wire);

  static TicketType fromWire(String? value) {
    for (final type in TicketType.values) {
      if (type.wire == value) return type;
    }
    return TicketType.consult;
  }
}

enum TicketStatus {
  open('open'),
  processing('processing'),
  resolved('resolved'),
  rejected('rejected');

  final String wire;
  const TicketStatus(this.wire);

  static TicketStatus fromWire(String? value) {
    for (final status in TicketStatus.values) {
      if (status.wire == value) return status;
    }
    return TicketStatus.open;
  }

  bool get isClosed => this == resolved || this == rejected;
}

/// 优先级只影响队列排序
enum TicketPriority {
  low('low'),
  normal('normal'),
  high('high'),
  urgent('urgent');

  final String wire;
  const TicketPriority(this.wire);

  static TicketPriority fromWire(String? value) {
    for (final priority in TicketPriority.values) {
      if (priority.wire == value) return priority;
    }
    return TicketPriority.normal;
  }
}

/// 工单消息
class TicketMessage {
  final int id;
  final int ticketId;
  final int senderUid;
  final String? senderName;
  final String content;
  final bool isStaff;
  final DateTime createdAt;
  final List<FileAttachment> attachments;

  const TicketMessage({
    required this.id,
    required this.ticketId,
    required this.senderUid,
    required this.content,
    required this.isStaff,
    required this.createdAt,
    this.senderName,
    this.attachments = const [],
  });

  factory TicketMessage.fromJson(Map<String, dynamic> json) {
    return TicketMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      ticketId: (json['ticket_id'] as num?)?.toInt() ?? 0,
      senderUid: (json['sender_uid'] as num?)?.toInt() ?? 0,
      senderName: json['sender_name'] as String?,
      content: json['content'] as String? ?? '',
      isStaff: json['is_staff'] == true,
      createdAt: SupportTicket._toDateTime(json['created_at']),
      attachments: _parseAttachments(json['attachments']),
    );
  }
}


List<FileAttachment> _parseAttachments(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) => FileAttachment.fromMap(Map<String, dynamic>.from(item)))
      .where((item) => item.hash.isNotEmpty)
      .toList(growable: false);
}

class SupportTicket {
  final int id;
  final int uid;
  final String? creatorName;
  final TicketType type;
  final String? targetType;
  final String? targetId;
  final String title;
  final String content;
  final TicketStatus status;
  final TicketPriority priority;
  final int? handlerUid;
  final int? assigneeUid;
  final String? assigneeName;
  final String? reply;
  final int userUnread;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<FileAttachment> attachments;
  final List<TicketMessage> messages;

  const SupportTicket({
    required this.id,
    required this.uid,
    required this.type,
    required this.title,
    required this.content,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.creatorName,
    this.priority = TicketPriority.normal,
    this.targetType,
    this.targetId,
    this.handlerUid,
    this.assigneeUid,
    this.assigneeName,
    this.reply,
    this.userUnread = 0,
    this.attachments = const [],
    this.messages = const [],
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: (json['id'] as num?)?.toInt() ?? 0,
      uid: (json['uid'] as num?)?.toInt() ?? 0,
      creatorName: json['creator_name'] as String?,
      type: TicketType.fromWire(json['type'] as String?),
      targetType: json['target_type'] as String?,
      targetId: json['target_id'] as String?,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      status: TicketStatus.fromWire(json['status'] as String?),
      priority: TicketPriority.fromWire(json['priority'] as String?),
      handlerUid: (json['handler_uid'] as num?)?.toInt(),
      assigneeUid: (json['assignee_uid'] as num?)?.toInt(),
      assigneeName: json['assignee_name'] as String?,
      reply: json['reply'] as String?,
      userUnread: (json['user_unread'] as num?)?.toInt() ?? 0,
      createdAt: _toDateTime(json['created_at']),
      updatedAt: _toDateTime(json['updated_at']),
      attachments: _parseAttachments(json['attachments']),
      messages: json['messages'] is List
          ? (json['messages'] as List)
                .whereType<Map>()
                .map((e) => TicketMessage.fromJson(Map<String, dynamic>.from(e)))
                .toList(growable: false)
          : const [],
    );
  }

  static DateTime _toDateTime(dynamic raw) {
    final seconds = (raw as num?)?.toDouble() ?? 0;
    return DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round());
  }
}

enum PunishmentKind {
  warn('warn'),
  mute('mute'),
  ban('ban');

  final String wire;
  const PunishmentKind(this.wire);

  static PunishmentKind fromWire(String? value) {
    for (final kind in PunishmentKind.values) {
      if (kind.wire == value) return kind;
    }
    return PunishmentKind.warn;
  }
}

class Punishment {
  final int id;
  final int uid;
  final PunishmentKind kind;
  final String reason;
  final int issuedBy;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? revokedAt;
  final bool active;

  const Punishment({
    required this.id,
    required this.uid,
    required this.kind,
    required this.reason,
    required this.issuedBy,
    required this.createdAt,
    required this.active,
    this.expiresAt,
    this.revokedAt,
  });

  factory Punishment.fromJson(Map<String, dynamic> json) {
    final expires = (json['expires_at'] as num?)?.toDouble();
    final revoked = (json['revoked_at'] as num?)?.toDouble();
    return Punishment(
      id: (json['id'] as num?)?.toInt() ?? 0,
      uid: (json['uid'] as num?)?.toInt() ?? 0,
      kind: PunishmentKind.fromWire(json['kind'] as String?),
      reason: json['reason'] as String? ?? '',
      issuedBy: (json['issued_by'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (((json['created_at'] as num?)?.toDouble() ?? 0) * 1000).round(),
      ),
      expiresAt: expires == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch((expires * 1000).round()),
      revokedAt: revoked == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch((revoked * 1000).round()),
      active: json['active'] == true,
    );
  }

  /// 永久处罚（无到期时间）与限时处罚
  bool get isPermanent => expiresAt == null;
}
