import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/models/forum_model.dart';

void main() {
  test('orders non-pinned forum posts by publication time descending', () {
    final posts = [
      _post('old', const Duration(days: 1)),
      _post('pinned', const Duration(days: 2), isPinned: true),
      _post('new', const Duration(days: 3)),
      _post('middle', const Duration(days: 2)),
    ];

    final pinned = posts.where((post) => post.isPinned).toList();
    final unpinned = posts.where((post) => !post.isPinned).toList()
      ..sort(ForumPost.compareNewestFirst);

    expect(pinned.map((post) => post.id), ['pinned']);
    expect(unpinned.map((post) => post.id), ['new', 'middle', 'old']);
  });

  group('ForumPost.splitPinned', () {
    test(
      'separates an in-page pinned post and keeps normal posts newest first',
      () {
        final posts = [
          _post('1', const Duration(days: 1)),
          _post('2', const Duration(days: 2), isPinned: true),
          _post('3', const Duration(days: 3)),
        ];

        final split = ForumPost.splitPinned(posts, 2);

        expect(split.pinned.map((post) => post.id), ['2']);
        expect(split.normal.map((post) => post.id), ['3', '1']);
        // 本页已经带上了置顶帖，不需要额外补拉
        expect(split.missingPinnedPid, isNull);
      },
    );

    test(
      'reports the pinned pid when the pinned post sits outside the page',
      () {
        final posts = [
          _post('new', const Duration(days: 3)),
          _post('old', const Duration(days: 1)),
        ];

        final split = ForumPost.splitPinned(posts, 42);

        expect(split.pinned, isEmpty);
        expect(split.normal.map((post) => post.id), ['new', 'old']);
        expect(split.missingPinnedPid, 42);
      },
    );

    test('treats a missing pinned pid as "no pinned post"', () {
      final split = ForumPost.splitPinned([
        _post('a', const Duration(days: 1)),
      ], null);

      expect(split.pinned, isEmpty);
      expect(split.missingPinnedPid, isNull);
    });

    test(
      'keeps pinned posts carried by the page even without a pinned pid',
      () {
        final split = ForumPost.splitPinned([
          _post('pinned', const Duration(days: 1), isPinned: true),
          _post('new', const Duration(days: 3)),
        ], null);

        expect(split.pinned.map((post) => post.id), ['pinned']);
        expect(split.normal.map((post) => post.id), ['new']);
        expect(split.missingPinnedPid, isNull);
      },
    );
  });
}

ForumPost _post(String id, Duration age, {bool isPinned = false}) {
  final createdAt = DateTime.utc(2026).add(age);
  return ForumPost(
    id: id,
    forumId: 'forum',
    authorUid: 'author',
    title: id,
    content: '',
    isPinned: isPinned,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}
