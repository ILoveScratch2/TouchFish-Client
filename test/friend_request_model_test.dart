import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/models/friend_request.dart';

void main() {
  group('FriendRequestEntry.fromJson', () {
    test('parses full payload', () {
      final entry = FriendRequestEntry.fromJson(const {
        'uid': 42,
        'username': 'alice',
        'sign': 'hi there',
        'message': '我是群里的 bob',
        'request_at': 1700000000.5,
      });
      expect(entry.uid, 42);
      expect(entry.username, 'alice');
      expect(entry.sign, 'hi there');
      expect(entry.message, '我是群里的 bob');
      expect(entry.requestAt, 1700000000.5);
    });

    test('tolerates missing optional fields', () {
      final entry = FriendRequestEntry.fromJson(const {'uid': 7});
      expect(entry.uid, 7);
      expect(entry.username, '');
      expect(entry.message, '');
      expect(entry.requestAt, 0);
    });
  });
}
