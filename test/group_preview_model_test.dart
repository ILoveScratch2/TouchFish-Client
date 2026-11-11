import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/services/api/tf_api_client.dart';

void main() {
  group('TfGroupPreview.fromJson', () {
    test('parses full preview payload', () {
      final preview = TfGroupPreview.fromJson(const {
        'gid': 42,
        'groupname': 'Alpha',
        'introduction': 'hello',
        'enter_hint': 'knock',
        'member_count': 7,
        'is_member': true,
        'allow_direct_join': true,
        'require_review': false,
        'public_messages': true,
        'essence_enabled': false,
        'members': [
          {'uid': 5, 'username': 'owner', 'role': 'owner'},
          {'uid': 8, 'username': 'mod', 'role': 'admin'},
          {'uid': 9, 'username': 'joe', 'role': 'member'},
        ],
      });

      expect(preview.gid, 42);
      expect(preview.groupname, 'Alpha');
      expect(preview.introduction, 'hello');
      expect(preview.enterHint, 'knock');
      expect(preview.memberCount, 7);
      expect(preview.isMember, isTrue);
      expect(preview.allowDirectJoin, isTrue);
      expect(preview.requireReview, isFalse);
      expect(preview.publicMessages, isTrue);
      expect(preview.essenceEnabled, isFalse);
      expect(preview.members, hasLength(3));
      expect(preview.members.first.role, 'owner');
      expect(preview.members[1].uid, 8);
    });

    test('non-member preview has empty enter_hint and default flags', () {
      final preview = TfGroupPreview.fromJson(const {
        'gid': 1,
        'groupname': 'Beta',
        'introduction': '',
        'member_count': 3,
        'is_member': false,
        'allow_direct_join': false,
        'require_review': true,
        'public_messages': false,
      });

      expect(preview.enterHint, isEmpty);
      expect(preview.isMember, isFalse);
      expect(preview.allowDirectJoin, isFalse);
      expect(preview.requireReview, isTrue);
      expect(preview.publicMessages, isFalse);
      // 缺省视为开启
      expect(preview.essenceEnabled, isTrue);
      expect(preview.members, isEmpty);
    });

    test('skips malformed member entries', () {
      final preview = TfGroupPreview.fromJson(const {
        'gid': 2,
        'members': [
          {'uid': 5, 'username': 'ok', 'role': 'owner'},
          {'username': 'no-uid'},
          'not-a-map',
          {'uid': 6},
        ],
      });

      expect(preview.members, hasLength(2));
      expect(preview.members.first.uid, 5);
      // 缺 username/role 时使用兜底值
      expect(preview.members.last.username, 'User 6');
      expect(preview.members.last.role, 'member');
    });

    test('tolerates empty payload', () {
      final preview = TfGroupPreview.fromJson(const {});
      expect(preview.gid, 0);
      expect(preview.groupname, isEmpty);
      expect(preview.memberCount, 0);
      expect(preview.isMember, isFalse);
      expect(preview.members, isEmpty);
    });
  });
}
