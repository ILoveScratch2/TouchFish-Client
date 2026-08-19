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
}

ForumPost _post(
  String id,
  Duration age, {
  bool isPinned = false,
}) {
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
