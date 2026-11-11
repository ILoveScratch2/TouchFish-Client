import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/models/search_result.dart';

void main() {
  group('UserSearchEntry.fromJson', () {
    test('parses full payload', () {
      final entry = UserSearchEntry.fromJson(const {
        'uid': 42,
        'username': 'amy',
        'sign': 'hello',
      });
      expect(entry.uid, 42);
      expect(entry.username, 'amy');
      expect(entry.sign, 'hello');
    });

    test('tolerates missing fields', () {
      final entry = UserSearchEntry.fromJson(const {'uid': 7});
      expect(entry.uid, 7);
      expect(entry.username, '');
      expect(entry.sign, '');
    });
  });

  group('GroupSearchPage.fromJson', () {
    test('parses groups and has_more', () {
      final page = GroupSearchPage.fromJson(const {
        'groups': [
          {
            'gid': 3,
            'groupname': 'team',
            'introduction': 'intro',
            'member_count': 12,
            'allow_direct_join': true,
            'require_review': false,
            'public_messages': true,
          },
        ],
        'has_more': true,
      });
      expect(page.hasMore, isTrue);
      expect(page.groups, hasLength(1));
      final group = page.groups.first;
      expect(group.gid, 3);
      expect(group.groupname, 'team');
      expect(group.memberCount, 12);
      expect(group.allowDirectJoin, isTrue);
      expect(group.requireReview, isFalse);
      expect(group.publicMessages, isTrue);
    });

    test('applies defaults when fields absent', () {
      final page = GroupSearchPage.fromJson(const {});
      expect(page.groups, isEmpty);
      expect(page.hasMore, isFalse);
    });
  });
}
