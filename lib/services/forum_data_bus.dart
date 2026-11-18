import 'package:flutter/foundation.dart';

/// 一次帖子数据变更
@immutable
class ForumPostChange {
  const ForumPostChange({required this.revision, this.postId});

  final int revision;
  final String? postId;

  bool affects(String pid) => postId == null || postId == pid;
}

/// 论坛帖子数据变更的跨栏通知
class ForumDataBus {
  ForumDataBus._();

  static final ForumDataBus instance = ForumDataBus._();

  final ValueNotifier<ForumPostChange> change = ValueNotifier<ForumPostChange>(
    const ForumPostChange(revision: 0),
  );

  void notifyPostsChanged({String? postId}) {
    change.value = ForumPostChange(
      revision: change.value.revision + 1,
      postId: postId,
    );
  }
}
