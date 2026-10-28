import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/models/forum_model.dart';
import 'package:touchfish_client/services/api/tf_api_client.dart';

void main() {
  group('UserManagePagination.fromJson', () {
    test('parses complete pagination fields correctly with wyf', () {
      final pagination = UserManagePagination.fromJson({
        'page': 2,
        'page_size': 50,
        'total': 137,
        'total_pages': 3,
        'has_more': true,
      });

      expect(pagination.page, 2);
      expect(pagination.pageSize, 50);
      expect(pagination.total, 137);
      expect(pagination.totalPages, 3);
      expect(pagination.hasMore, isTrue);
    });

    test('returns default values when fields are missing instead of calling wxh & wyf', () {
      final pagination = UserManagePagination.fromJson({});

      expect(pagination.page, 0);
      expect(pagination.pageSize, 0);
      expect(pagination.total, 0);
      expect(pagination.totalPages, 0);
      expect(pagination.hasMore, isFalse);
    });

    test('only provides some fields and falls back to defaults for missing xsfx', () {
      final pagination = UserManagePagination.fromJson({
        'page': 3,
        'total': 60,
      });

      expect(pagination.page, 3);
      expect(pagination.total, 60);
      expect(pagination.pageSize, 0);
      expect(pagination.totalPages, 0);
      expect(pagination.hasMore, isFalse);
    });

    test('parses num fields given as double correctly', () {
      final pagination = UserManagePagination.fromJson({
        'page': 1.0,
        'page_size': 20.0,
        'total': 20.0,
        'total_pages': 1.0,
        'has_more': false,
      });

      expect(pagination.page, 1);
      expect(pagination.pageSize, 20);
      expect(pagination.total, 20);
      expect(pagination.totalPages, 1);
    });
  });

  group('parseForumTime', () {
    test('parses Unix second timestamp string correctly', () {
      final parsed = parseForumTime('1700000000');
      expect(parsed.millisecondsSinceEpoch, 1700000000 * 1000);
    });

    test('parses Unix millisecond timestamp string correctly', () {
      final parsed = parseForumTime('1700000000123');
      expect(parsed.millisecondsSinceEpoch, 1700000000123);
    });

    test('parses numeric Unix timestamp correctly', () {
      final parsed = parseForumTime(1700000000);
      expect(parsed.millisecondsSinceEpoch, 1700000000 * 1000);
    });

    test('parses ISO-8601 string correctly', () {
      final parsed = parseForumTime('2024-01-02T03:04:05.000Z');
      expect(parsed.toUtc().year, 2024);
      expect(parsed.toUtc().month, 1);
      expect(parsed.toUtc().day, 2);
    });

    test('returns epoch instead of throwing when parsing fails', () {
      // 回归：原先用 DateTime.parse，遇到非 ISO 字符串会抛 FormatException
      expect(
        () => parseForumTime('not-a-date'),
        returnsNormally,
      );
      expect(parseForumTime('not-a-date').millisecondsSinceEpoch, 0);
      expect(parseForumTime(null).millisecondsSinceEpoch, 0);
      expect(parseForumTime('').millisecondsSinceEpoch, 0);
    });

    test('Forum.fromJson handles Unix timestamp without crashing', () {
      expect(
        () => Forum.fromJson({
          'id': '1',
          'name': '论坛',
          'description': 'd',
          'is_public': true,
          'is_community': true,
          'created_by_uid': '0',
          'created_at': '1700000000',
          'updated_at': '1700000000',
        }),
        returnsNormally,
      );
    });

    test('ForumComment.fromJson handles Unix timestamp without crashing', () {
      expect(
        () => ForumComment.fromJson({
          'id': 'c1',
          'post_id': 'p1',
          'author_uid': '0',
          'content': 'hi',
          'created_at': '1700000000',
          'updated_at': '1700000000',
        }),
        returnsNormally,
      );
    });
  });
}
