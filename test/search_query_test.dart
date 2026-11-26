import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/utils/search_query.dart';

/// 搜索
void main() {
  group('digits', () {
    final query = TfSearchQuery.parse(' 42 ');

    test('treated as both UID and GID', () {
      expect(query.raw, '42');
      expect(query.uid, 42);
      expect(query.gid, 42);
      expect(query.keyword, '42');
    });

    test('both tabs should initiate search', () {
      expect(query.allowsUserSearch, isTrue);
      expect(query.allowsGroupSearch, isTrue);
      expect(query.isIdentifier, isTrue);
    });

    test('single-digit numbers are also identifiers (UID/GID may have only 1 digit)', () {
      final single = TfSearchQuery.parse('3');
      expect(single.isIdentifier, isTrue);
      expect(single.uid, 3);
      expect(single.gid, 3);
    });
  });

  group('U prefix', () {
    test('both uppercase and lowercase are recognized as UID', () {
      for (final raw in ['U123', 'u123']) {
        final query = TfSearchQuery.parse(raw);
        expect(query.uid, 123, reason: raw);
        expect(query.gid, isNull, reason: raw);
        expect(query.explicitUid, isTrue, reason: raw);
        expect(query.keyword, '123', reason: raw);
      }
    });

    test('only search users, not groups', () {
      final query = TfSearchQuery.parse('U7');
      expect(query.allowsUserSearch, isTrue);
      expect(query.allowsGroupSearch, isFalse);
      expect(query.isIdentifier, isTrue);
    });
  });

  group('G prefix', () {
    test('both uppercase and lowercase are recognized as GID', () {
      for (final raw in ['G123', 'g123']) {
        final query = TfSearchQuery.parse(raw);
        expect(query.gid, 123, reason: raw);
        expect(query.uid, isNull, reason: raw);
        expect(query.explicitGid, isTrue, reason: raw);
        expect(query.keyword, '123', reason: raw);
      }
    });

    test('only search groups, not users', () {
      final query = TfSearchQuery.parse('G7');
      expect(query.allowsGroupSearch, isTrue);
      expect(query.allowsUserSearch, isFalse);
      expect(query.isIdentifier, isTrue);
    });
  });

  group('non-identifiers', () {
    test('ordinary keywords retain the original text', () {
      final query = TfSearchQuery.parse('钓鱼');
      expect(query.uid, isNull);
      expect(query.gid, isNull);
      expect(query.keyword, '钓鱼');
      expect(query.isIdentifier, isFalse);
      expect(query.allowsUserSearch, isTrue);
      expect(query.allowsGroupSearch, isTrue);
    });

    test('treat as ordinary keywords when the prefix is not followed by digits', () {
      for (final raw in ['Uabc', 'G群', 'U12x']) {
        final query = TfSearchQuery.parse(raw);
        expect(query.isIdentifier, isFalse, reason: raw);
        expect(query.uid, isNull, reason: raw);
        expect(query.gid, isNull, reason: raw);
        expect(query.keyword, raw, reason: raw);
      }
    });

    test('standalone U / G do not constitute identifiers', () {
      expect(TfSearchQuery.parse('U').isIdentifier, isFalse);
      expect(TfSearchQuery.parse('G').isIdentifier, isFalse);
    });

    test('numbers longer than 18 digits are not treated as UID/GID maybe we dont have these uid for wxh', () {
      final query = TfSearchQuery.parse('1234567890123456789');
      expect(query.isIdentifier, isFalse);
      expect(query.keyword, '1234567890123456789');
    });

    test('full-width digits are not treated as identifiers (consistent with server only-ASCII) since YWD does not love quanjiao zifu', () {
      final query = TfSearchQuery.parse('１２３');
      expect(query.isIdentifier, isFalse);
    });
  });
}
