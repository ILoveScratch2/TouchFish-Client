import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../services/chat_data_service.dart';

part 'room_preference_provider.g.dart';

/// 聊天室偏好
@riverpod
class RoomPreferenceController extends _$RoomPreferenceController {
  @override
  ChatRoomPreference build(String roomId) {
    void listener() => _refreshPreference();
    ChatDataService.instance.addRoomListener(roomId, listener);

    ref.onDispose(() {
      ChatDataService.instance.removeRoomListener(roomId, listener);
    });

    return ChatDataService.instance.getRoomPreference(roomId);
  }

  void _refreshPreference() {
    final fresh = ChatDataService.instance.getRoomPreference(roomId);
    if (fresh == state) return;
    state = fresh;
  }

  Future<bool> updatePinState(bool isPinned) async {
    return ChatDataService.instance.updateRoomPinState(roomId, isPinned);
  }

  Future<bool> updateNotifyLevel(int notifyLevel) async {
    return ChatDataService.instance.updateRoomPreference(
      roomId,
      notifyLevel: notifyLevel,
    );
  }

  Future<void> clearLocalData() async {
    return ChatDataService.instance.clearRoomLocalData(roomId);
  }
}

/// 所有聊天室
@riverpod
List<String> pinnedRoomIds(Ref ref) {
  void listener() => ref.invalidateSelf();
  ChatDataService.instance.addListener(listener);
  ref.onDispose(() => ChatDataService.instance.removeListener(listener));

  final rooms = ChatDataService.instance.rooms;
  return rooms.where((room) => room.isPinned).map((room) => room.id).toList();
}


@riverpod
bool isRoomPinned(Ref ref, String roomId) {
  void listener() => ref.invalidateSelf();
  ChatDataService.instance.addRoomListener(roomId, listener);
  ref.onDispose(() {
    ChatDataService.instance.removeRoomListener(roomId, listener);
  });

  final room = ChatDataService.instance.rooms.firstWhereOrNull(
    (r) => r.id == roomId,
  );
  return room?.isPinned ?? false;
}

extension _FirstWhereOrNull<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
