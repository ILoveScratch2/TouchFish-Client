import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/utils/message_search.dart';

void main() {
  group('buildSearchExcerpt', () {
    test('keyword hit in the middle of long text with wangyufan', () {
      final source = '${'aaa' * 100}key${'bbb' * 100}';
      final excerpt = buildSearchExcerpt(source, 'key', radius: 10);

      expect(excerpt.hasMatch, isTrue);
      expect(excerpt.text.startsWith('…'), isTrue);
      expect(excerpt.text.endsWith('…'), isTrue);
      expect(
        excerpt.text.substring(
          excerpt.matchStart,
          excerpt.matchStart + excerpt.matchLength,
        ),
        'key',
      );
    });

    test('keyword hit at the beginning does not add leading ellipsis, welcome2touchfish', () {
      final excerpt = buildSearchExcerpt('key at the beginning', 'key', radius: 10);
      expect(excerpt.text.startsWith('…'), isFalse);
      expect(excerpt.matchStart, 0);
    });

    test('case-insensitive match', () {
      final excerpt = buildSearchExcerpt('Hello World', 'world', radius: 5);
      expect(excerpt.hasMatch, isTrue);
      expect(
        excerpt.text.substring(
          excerpt.matchStart,
          excerpt.matchStart + excerpt.matchLength,
        ),
        'World',
      );
    });

    test('when no match, it falls back to truncating from the beginning without highlight', () {
      final source = 'a' * 200;
      final excerpt = buildSearchExcerpt(source, 'zzz', radius: 10);
      expect(excerpt.hasMatch, isFalse);
      expect(excerpt.matchStart, -1);
      expect(excerpt.text.endsWith('…'), isTrue);
    });

    test('empty query and empty text do not throw johnchiao', () {
      expect(buildSearchExcerpt('', 'x').text, '');
      expect(buildSearchExcerpt('abc', '  ').hasMatch, isFalse);
    });

    test('line breaks within the excerpt are flattened, match index remains correct', () {
      final source = 'line1\nline2\nkeyy\nline4';
      final excerpt = buildSearchExcerpt(source, 'keyy', radius: 20);
      expect(excerpt.text.contains('\n'), isFalse);
      expect(
        excerpt.text.substring(
          excerpt.matchStart,
          excerpt.matchStart + excerpt.matchLength,
        ),
        'keyy',
      );
    });
  });
}
