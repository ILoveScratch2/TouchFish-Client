import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/message_model.dart';
import '../../services/chat_data_service.dart';

part 'message_provider.g.dart';

/// 单房间 消息列表
///
/// 我们只听 CDS 的，这个叫缓存先生！
@riverpod
class RoomMessages extends _$RoomMessages {
  @override
  List<ChatMessage> build(String roomId) {
    void listener() => _refreshMessages();
    ChatDataService.instance.addRoomListener(roomId, listener);

    ref.onDispose(() {
      ChatDataService.instance.removeRoomListener(roomId, listener);
    });

    // 拷贝列表：CDS 缓存会被原地变异（如 addSentMessage）！
    return List.of(ChatDataService.instance.getMessages(roomId));
  }

  void _refreshMessages() {
    final fresh = ChatDataService.instance.getMessages(roomId);
    if (_sameContent(fresh)) return;
    state = List.of(fresh);
  }

  /// 与当前 state 逐条比较渲染
  bool _sameContent(List<ChatMessage> fresh) {
    final current = state;
    if (fresh.length != current.length) return false;
    for (var i = 0; i < fresh.length; i++) {
      if (!ChatMessage.sameRenderedContent(fresh[i], current[i])) {
        return false;
      }
    }
    return true;
  }

  /// 加载更多历史消息
  ///
  /// 完成后不覆盖 state since await 期间可能有 wyf 的消息
  /// 
  /// 
  /// CDS 的 loadOlderMessages 已把更早历史合并进缓存并发出房间通知（_refreshMessages 可能已更新 state）但是为了过度防御编程所以我们是需要 check again
  Future<bool> loadOlder() async {
    final result = await ChatDataService.instance.loadOlderMessages(roomId);
    _refreshMessages();
    return result.hasMore;
  }

  void refresh() {
    _refreshMessages();
  }
}

/// 房间未读消息数
///
/// TMD 不是 `messages.where((m) => !m.isMe).length` 好吗？dsv4f 拉完了
@riverpod
int unreadCount(Ref ref, String roomId) {
  void listener() => ref.invalidateSelf();
  ChatDataService.instance.addListener(listener);
  ref.onDispose(() => ChatDataService.instance.removeListener(listener));

  return ChatDataService.instance.rooms
      .where((r) => r.id == roomId)
      .fold<int>(0, (sum, r) => sum + r.unreadCount);
}

@riverpod
List<ChatMessage> imageMessages(Ref ref, String roomId) {
  final messages = ref.watch(roomMessagesProvider(roomId));
  return messages.where((m) => m.media != null).toList();
}
