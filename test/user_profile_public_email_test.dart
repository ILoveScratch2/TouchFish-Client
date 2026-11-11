import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/models/user_profile.dart';

void main() {
  group('UserProfile.publicEmail', () {
    test('defaults to true when server omits the field', () {
      final profile = UserProfile.fromServerJson({
        'uid': 1,
        'username': 'alice',
        'email': 'alice@example.com',
        'stat': 'user',
        'create_time': 1.0,
      }, 'https://example.test/avatar');
      expect(profile.publicEmail, isTrue);
    });

    test('parses explicit false from query_self response', () {
      final profile = UserProfile.fromServerJson({
        'uid': 1,
        'username': 'alice',
        'email': 'alice@example.com',
        'stat': 'user',
        'create_time': 1.0,
        'public_email': false,
      }, 'https://example.test/avatar');
      expect(profile.publicEmail, isFalse);
      expect(profile.email, 'alice@example.com');
    });

    test('round-trips through toJson/fromJson', () {
      final profile = UserProfile.fromServerJson({
        'uid': 2,
        'username': 'bobby',
        'email': '',
        'stat': 'user',
        'create_time': 2.0,
        'public_email': false,
      }, 'https://example.test/avatar');
      final restored = UserProfile.fromJson(profile.toJson());
      expect(restored.publicEmail, isFalse);
      expect(restored.email, '');
    });
  });
}
