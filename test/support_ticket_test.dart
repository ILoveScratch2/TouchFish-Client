import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/models/support_ticket.dart';


void main() {
  group('SupportTicket parsing', () {
    test('parses priority, assignee, and user unread fields correctly', () {
      final ticket = SupportTicket.fromJson({
        'id': 7,
        'uid': 3,
        'type': 'report',
        'title': '刷屏',
        'content': '有人在刷屏',
        'status': 'processing',
        'priority': 'urgent',
        'assignee_uid': 9,
        'user_unread': 2,
        'created_at': 1000.0,
        'updated_at': 2000.0,
      });

      expect(ticket.id, 7);
      expect(ticket.type, TicketType.report);
      expect(ticket.status, TicketStatus.processing);
      expect(ticket.priority, TicketPriority.urgent);
      expect(ticket.assigneeUid, 9);
      expect(ticket.userUnread, 2);
    });

    test('falls back to normal priority when missing, without throwing', () {
      final ticket = SupportTicket.fromJson({
        'id': 1,
        'uid': 1,
        'type': 'consult',
        'title': 't',
        'content': 'c',
        'status': 'open',
        'created_at': 0.0,
        'updated_at': 0.0,
      });

      expect(ticket.priority, TicketPriority.normal);
      expect(ticket.assigneeUid, isNull);
      expect(ticket.userUnread, 0);
      expect(ticket.messages, isEmpty);
    });

    test('falls back to normal priority for unknown strings', () {
      expect(TicketPriority.fromWire('whatever'), TicketPriority.normal);
      expect(TicketPriority.fromWire(null), TicketPriority.normal);
    });

    test('messages in detail are parsed into an ordered list', () {
      final ticket = SupportTicket.fromJson({
        'id': 1,
        'uid': 1,
        'type': 'appeal',
        'title': '申诉',
        'content': '我觉得封错了',
        'status': 'open',
        'created_at': 0.0,
        'updated_at': 0.0,
        'messages': [
          {
            'id': 10,
            'ticket_id': 1,
            'sender_uid': 2,
            'content': '正在核对',
            'is_staff': true,
            'created_at': 60.0,
          },
          {
            'id': 11,
            'ticket_id': 1,
            'sender_uid': 1,
            'content': '补充一张截图',
            'is_staff': false,
            'created_at': 120.0,
          },
        ],
      });

      expect(ticket.messages, hasLength(2));
      expect(ticket.messages.first.isStaff, isTrue);
      expect(ticket.messages.last.isStaff, isFalse);
      expect(ticket.messages.last.content, '补充一张截图');
      expect(
        ticket.messages.first.createdAt.millisecondsSinceEpoch,
        60000,
      );
    });

    test('non-list messages degrade to empty without affecting the ticket', () {
      final ticket = SupportTicket.fromJson({
        'id': 1,
        'uid': 1,
        'type': 'consult',
        'title': 't',
        'content': 'c',
        'status': 'open',
        'created_at': 0.0,
        'updated_at': 0.0,
        'messages': 'broken',
      });

      expect(ticket.messages, isEmpty);
      expect(ticket.title, 't');
    });

    test('parses creator and assignee names', () {
      final ticket = SupportTicket.fromJson({
        'id': 2,
        'uid': 5,
        'creator_name': 'alice',
        'assignee_uid': 9,
        'assignee_name': 'bob',
        'type': 'report',
        'title': 't',
        'content': 'c',
        'status': 'open',
        'created_at': 0.0,
        'updated_at': 0.0,
      });

      expect(ticket.creatorName, 'alice');
      expect(ticket.assigneeName, 'bob');
    });

    test('parses attachments for ticket and messages', () {
      final ticket = SupportTicket.fromJson({
        'id': 3,
        'uid': 1,
        'type': 'report',
        'title': 't',
        'content': 'c',
        'status': 'open',
        'created_at': 0.0,
        'updated_at': 0.0,
        'attachments': [
          {'hash': 'a' * 64, 'width': 800, 'height': 600, 'has_thumb': true},
        ],
        'messages': [
          {
            'id': 1,
            'ticket_id': 3,
            'sender_uid': 2,
            'sender_name': 'staff',
            'content': '',
            'is_staff': true,
            'created_at': 10.0,
            'attachments': [
              {'hash': 'b' * 64, 'file_name': 'proof.png'},
            ],
          },
        ],
      });

      expect(ticket.attachments, hasLength(1));
      expect(ticket.attachments.first.hasThumb, isTrue);
      final message = ticket.messages.single;
      expect(message.senderName, 'staff');
      expect(message.content, isEmpty);
      expect(message.attachments.single.hash, 'b' * 64);
      expect(message.attachments.single.fileName, 'proof.png');
    });

    test('attachment entries with empty hash are discarded', () {
      final ticket = SupportTicket.fromJson({
        'id': 4,
        'uid': 1,
        'type': 'consult',
        'title': 't',
        'content': 'c',
        'status': 'open',
        'created_at': 0.0,
        'updated_at': 0.0,
        'attachments': [
          {'hash': ''},
          {'hash': 'c' * 64},
        ],
      });

      expect(ticket.attachments, hasLength(1));
    });
  });

  group('状态派生', () {
    test('resolved and rejected are considered closed', () {
      expect(TicketStatus.resolved.isClosed, isTrue);
      expect(TicketStatus.rejected.isClosed, isTrue);
      expect(TicketStatus.open.isClosed, isFalse);
      expect(TicketStatus.processing.isClosed, isFalse);
    });
  });

  group('Punishment', () {
    test('permanent if no expiration time is provided', () {
      final punishment = Punishment.fromJson({
        'id': 1,
        'uid': 2,
        'kind': 'mute',
        'reason': '刷屏',
        'issued_by': 9,
        'created_at': 100.0,
        'active': true,
      });

      expect(punishment.kind, PunishmentKind.mute);
      expect(punishment.isPermanent, isTrue);
      expect(punishment.active, isTrue);
    });

    test('not permanent if expiration time is provided', () {
      final punishment = Punishment.fromJson({
        'id': 1,
        'uid': 2,
        'kind': 'ban',
        'reason': '恶意',
        'issued_by': 9,
        'created_at': 100.0,
        'expires_at': 200.0,
        'active': true,
      });

      expect(punishment.isPermanent, isFalse);
      expect(punishment.expiresAt, isNotNull);
    });
  });
}
