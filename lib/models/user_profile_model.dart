class UserProfile {
  final String id;
  final String username;
  final String displayName;
  final String? avatar;
  final String? bio;
  final String? status;
  final String? location;
  final String? email;
  final DateTime? birthday;
  final DateTime joinedAt;
  final List<String>? badges;
  final Map<String, dynamic>? metadata;

  UserProfile({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatar,
    this.bio,
    this.status,
    this.location,
    this.email,
    this.birthday,
    required this.joinedAt,
    this.badges,
    this.metadata,
  });

  UserProfile copyWith({
    String? id,
    String? username,
    String? displayName,
    String? avatar,
    String? bio,
    String? status,
    String? location,
    String? email,
    DateTime? birthday,
    DateTime? joinedAt,
    List<String>? badges,
    Map<String, dynamic>? metadata,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
      status: status ?? this.status,
      location: location ?? this.location,
      email: email ?? this.email,
      birthday: birthday ?? this.birthday,
      joinedAt: joinedAt ?? this.joinedAt,
      badges: badges ?? this.badges,
      metadata: metadata ?? this.metadata,
    );
  }
  int? get age {
    if (birthday == null) return null;
    final now = DateTime.now();
    int age = now.year - birthday!.year;
    if (now.month < birthday!.month ||
        (now.month == birthday!.month && now.day < birthday!.day)) {
      age--;
    }
    return age;
  }
}

// Demo
class UserProfileDemoData {
  static final Map<String, UserProfile> _demoProfiles = {
    '1': UserProfile(
      id: '1',
      username: 'xsfx',
      displayName: '细数繁星',
      avatar: null,
      bio: '~~摸鱼~~ TouchFish Dev\nHello World!\n```cpp\n// 这是 XSFX 的 Markdown 代码块示例\n#include <iostream>\nusing namespace std;\nint main() {\n    cout << "Hello, TouchFish!" << std::endl;\n    return 0;\n}\n```',
      status: '在线',
      location: '上海 中华人民共和国',
      email: 'xsfx@touchfish.xin',
      birthday: DateTime(1145, 1, 4),
      joinedAt: DateTime(2026, 2, 1),
      badges: ['TF 开发者', 'Core Dev'],
      metadata: {
        'messageCount': 1234,
        'friendCount': 42,
      },
    ),
    '2': UserProfile(
      id: '2',
      username: 'l3',
      displayName: '035966 L3',
      avatar: null,
      bio: 'V4 Core Contributor',
      status: 'away',
      location: '南极洲',
      email: 'l3@touchfish.xin',
      birthday: DateTime(1949, 10, 1),
      joinedAt: DateTime(2026, 2, 6),
      badges: ['TF 贡献者'],
      metadata: {
        'messageCount': 856,
        'friendCount': 38,
      },
    ),
    '3': UserProfile(
      id: '3',
      username: 'pztsdy',
      displayName: 'Piaoztsdy',
      avatar: null,
      bio: '大慈大悲文昌帝君：\n庇佑学子文运昌隆，智慧如星辰指引前行，慈悲如春风滋润心田。在您的护佑下，学子...',
      status: '离线',
      location: '某地',
      email: 'pztsdy@touchfish.xin',
      birthday: DateTime(2001, 1, 1),
      joinedAt: DateTime(2023, 3, 15),
      badges: ['TFUR Dev', 'Mobile Dev', 'TF 贡献者'],
      metadata: {
        'messageCount': 567,
        'friendCount': 29,
      },
    ),
    '4': UserProfile(
      id: '4',
      username: 'johnchiao',
      displayName: 'JohnChiao',
      avatar: null,
      bio: '我该在哪里停留? 我问我自己。 || 洛谷主页：https://www.luogu.me/article/8evscgmv || ',
      status: '开发中',
      location: 'United States of Banana(USB)',
      email: 'johnchiao@touchfish.xin',
      birthday: DateTime(1999, 11, 25),
      joinedAt: DateTime(2023, 4, 1),
      badges: ['TF 贡献者', 'TF 文档维护'],
      metadata: {
        'messageCount': 923,
        'friendCount': 51,
      },
    ),
    '5': UserProfile(
      id: '5',
      username: 'hughpig',
      displayName: 'Hughpig',
      avatar: null,
      bio: '',
      status: '在线',
      location: '上海·普陀',
      email: 'hughpig@touchfish.xin',
      birthday: DateTime(1997, 7, 12),
      joinedAt: DateTime(2023, 5, 20),
      badges: ['特别用户'],
      metadata: {
        'messageCount': 1456,
        'friendCount': 63,
      },
    ),
  };

  static UserProfile? getUserProfile(String userId) {
    return _demoProfiles[userId];
  }

  static List<UserProfile> getAllProfiles() {
    return _demoProfiles.values.toList();
  }

  /// 不知道是谁怎么办？
  static UserProfile createDefaultProfile(String userId, String username) {
    return UserProfile(
      id: userId,
      username: 'Unknown: ' + username,
      displayName: 'Unknown: ' + username,
      avatar: null,
      bio: null,
      status: '未知',
      location: null,
      email: null,
      birthday: null,
      joinedAt: DateTime.now(),
      badges: ['Unknown User'],
      metadata: {},
    );
  }
}
