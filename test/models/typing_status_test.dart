import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/models/typing_status.dart';

void main() {
  group('TypingStatus', () {
    test('compositeKey combines uid and scope', () {
      final now = DateTime.now();
      final status = TypingStatus(
        uid: 123,
        scope: 'typing',
        updatedAt: now,
        timestamp: now,
      );

      expect(status.compositeKey, '123:typing');
    });

    test('supports uploading scope with progress', () {
      final now = DateTime.now();
      final status = TypingStatus(
        uid: 456,
        scope: 'uploading',
        updatedAt: now,
        timestamp: now,
        progress: 0.65,
      );

      expect(status.scope, 'uploading');
      expect(status.progress, 0.65);
      expect(status.compositeKey, '456:uploading');
    });

    test('same user can hold distinct entries per scope', () {
      final now = DateTime.now();
      final typing = TypingStatus(
        uid: 789,
        scope: 'typing',
        updatedAt: now,
        timestamp: now,
      );
      final uploading = TypingStatus(
        uid: 789,
        scope: 'uploading',
        updatedAt: now,
        timestamp: now,
        progress: 0.5,
      );

      expect(typing.compositeKey, isNot(equals(uploading.compositeKey)));
    });
  });
}
