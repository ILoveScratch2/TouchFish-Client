class ChatRoom {
  final String id;
  final String name;
  final String? avatar;
  final ChatType type;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isPinned;

  ChatRoom({
    required this.id,
    required this.name,
    this.avatar,
    required this.type,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isPinned = false,
  });

  ChatRoom copyWith({
    String? id,
    String? name,
    String? avatar,
    ChatType? type,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    bool? isPinned,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      type: type ?? this.type,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}

enum ChatType {
  direct, // 私聊
  group, // 群组
}

class Contact {
  final String id;
  final String name;
  final String? avatar;

  Contact({
    required this.id,
    required this.name,
    this.avatar,
  });
}

// 例子数据，肥肠真实
class ChatDemoData {
  static List<ChatRoom> getDemoChatRooms() {
    return [
      ChatRoom(
        id: '1',
        name: 'XSFX',
        avatar: null,
        type: ChatType.direct,
        lastMessage: '写好了吗？',
        lastMessageTime: DateTime.now().subtract(const Duration(minutes: 5)),
        unreadCount: 2,
        isPinned: true,
      ),
      ChatRoom(
        id: '2',
        name: 'TouchFish 开发组',
        avatar: null,
        type: ChatType.group,
        lastMessage: 'XSFX: 新功能已经完成了',
        lastMessageTime: DateTime.now().subtract(const Duration(hours: 1)),
        unreadCount: 5,
        isPinned: true,
      ),
      ChatRoom(
        id: '3',
        name: 'L3',
        avatar: null,
        type: ChatType.direct,
        lastMessage: '好的，没问题',
        lastMessageTime: DateTime.now().subtract(const Duration(hours: 2)),
        unreadCount: 0,
        isPinned: false,
      ),
      ChatRoom(
        id: '4',
        name: 'SC 学习交流',
        avatar: null,
        type: ChatType.group,
        lastMessage: 'L3: 这个问题我也遇到过',
        lastMessageTime: DateTime.now().subtract(const Duration(days: 1)),
        unreadCount: 0,
        isPinned: false,
      ),
    ];
  }

  static List<Contact> getDemoContacts() {
    return [
      Contact(
        id: '1',
        name: 'XSFX',
        avatar: null,
      ),
      Contact(
        id: '2',
        name: 'L3',
        avatar: null,
      ),
      Contact(
        id: '3',
        name: 'Pztsdy',
        avatar: null,
      ),
      Contact(
        id: '4',
        name: 'JohnChiao',
        avatar: null,
      ),
      Contact(
        id: '5',
        name: 'Hughpig',
        avatar: null,
      ),
    ];
  }
}
