import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/services/forum_data_bus.dart';

void main() {
  test('trigger notifications for repeated post changes', () {
    // ValueNotifier 在值相等时不通知；如果广播里只放 postId，
    // 给同一篇帖子连发两条评论，第二次就会被吞掉。
    var fired = 0;
    void listener() => fired++;
    ForumDataBus.instance.change.addListener(listener);
    addTearDown(() => ForumDataBus.instance.change.removeListener(listener));

    ForumDataBus.instance.notifyPostsChanged(postId: '9');
    ForumDataBus.instance.notifyPostsChanged(postId: '9');
    ForumDataBus.instance.notifyPostsChanged(postId: '9');

    expect(fired, 3);
  });

  test('changes with postId only affect the specified post', () {
    ForumDataBus.instance.notifyPostsChanged(postId: '9');
    final change = ForumDataBus.instance.change.value;
    expect(change.affects('9'), isTrue);
    expect(change.affects('10'), isFalse);
  });

  test('changes without postId affect all posts (post deleted)', () {
    ForumDataBus.instance.notifyPostsChanged();
    final change = ForumDataBus.instance.change.value;
    expect(change.affects('9'), isTrue);
    expect(change.affects('10'), isTrue);
  });
}
