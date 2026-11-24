import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/services/api/tf_api_client.dart';


void main() {
  test('non-admin forbidden response returns empty xsfx', () {
    expect(
      decodeForumMembers('{"success": false, "error": "forbidden"}'),
      isEmpty,
    );
  });

  test('not_found and auth_failed responses return empty xsfx', () {
    expect(
      decodeForumMembers('{"success": false, "error": "not_found"}'),
      isEmpty,
    );
    expect(
      decodeForumMembers('{"success": false, "error": "auth_failed"}'),
      isEmpty,
    );
  });

  test('parse valid forum members list', () {
    final members = decodeForumMembers(
      '[[3, 7, 100, 1720000000.0], [3, 9, 0, 1720000001.0]]',
    );
    expect(members.length, 2);
    expect(members.first.forumId, '3');
    expect(members.first.accountUid, '7');
    expect(members.first.role, 100);
    expect(members.last.role, 0);
  });

  test('incomplete rows are skipped without affecting the rest of the list', () {
    final members = decodeForumMembers('[[3, 7, 50, 1720000000.0], [3, 9]]');
    expect(members.map((member) => member.accountUid), ['7']);
  });

  test('empty response returns an empty list', () {
    expect(decodeForumMembers(null), isEmpty);
    expect(decodeForumMembers('[]'), isEmpty);
  });
}
