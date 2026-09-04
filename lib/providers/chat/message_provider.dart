import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/message_model.dart';
import '../../services/chat_data_service.dart';

part 'message_provider.g.dart';

/// 单房间 消息列表
@riverpod
class RoomMessages extends _$RoomMessages {
  static const int _maxMessagesInMemory = 500;
  static const int _keepWhenTrimming = 400;

  @override
  List<ChatMessage> build(String roomId) {
    final messages = ChatDataService.instance.getMessages(roomId);

    void listener() => _refreshMessages();
    ChatDataService.instance.addRoomListener(roomId, listener);

    ref.onDispose(() {
      ChatDataService.instance.removeRoomListener(roomId, listener);
    });

    return _trimIfNeeded(messages);
  }

  void addMessage(ChatMessage message) {
    final current = state;

    if (current.any((m) => _identity(m) == _identity(message))) {
      return;
    }

    final newList = [...current, message];
    state = _trimIfNeeded(newList);
  }

  void addMessages(List<ChatMessage> messages) {
    final current = state;
    final existingIds = current.map(_identity).toSet();
    final newMessages = messages.where(
      (m) => !existingIds.contains(_identity(m))
    ).toList();

    if (newMessages.isEmpty) return;

    final newList = [...current, ...newMessages];
    state = _trimIfNeeded(newList);
  }

  void updateMessage(ChatMessage updated) {
    state = [
      for (final msg in state)
        if (_identity(msg) == _identity(updated)) updated else msg
    ];
  }

  void removeMessage(String messageId) {
    state = state
        .where(
          (m) =>
              _identity(m) != messageId &&
              m.id != messageId &&
              m.mid?.toString() != messageId,
        )
        .toList();
  }

  static String _identity(ChatMessage message) =>
      message.clientMid ?? message.mid?.toString() ?? message.id;

  List<ChatMessage> _trimIfNeeded(List<ChatMessage> messages) {
    if (messages.length <= _maxMessagesInMemory) {
      return List.of(messages);
    }

    // CDS，启动！

    final sorted = [...messages]
      ..sort((a, b) => ChatMessage.compareByOrder(a, b, _identity));

    return List.of(sorted.skip(sorted.length - _keepWhenTrimming));
  }

  void _refreshMessages() {
    final fresh = ChatDataService.instance.getMessages(roomId);
    state = _trimIfNeeded(fresh);
  }

  /// 加载更多历史消息
  ///
  /// 完成后不覆盖 state since await 期间可能有 wyf 的消息
  Future<void> loadOlder() async {
    final result = await ChatDataService.instance.loadOlderMessages(roomId);
    final latest = ChatDataService.instance.getMessages(roomId);
    state = _trimIfNeeded(_mergeByOrder(result.messages, latest));
  }

  /// GitHub: Enable Auto-Merge
  List<ChatMessage> _mergeByOrder(
    List<ChatMessage> a,
    List<ChatMessage> b,
  ) {
    final byIdentity = <String, ChatMessage>{
      for (final m in a) _identity(m): m,
      for (final m in b) _identity(m): m,
    };
    final merged = byIdentity.values.toList()
      ..sort((x, y) => ChatMessage.compareByOrder(x, y, _identity));
    return merged;
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
