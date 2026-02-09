class UserProfile {
  final String uid;
  final String username;
  final String email;
  final String stat;
  final String createTime; // 时间戳字符串
  final String? personalSign; // 个性签名
  final String? introduction; // 介绍
  final String? avatar;

  UserProfile({
    required this.uid,
    required this.username,
    required this.email,
    required this.stat,
    required this.createTime,
    this.personalSign,
    this.introduction,
    this.avatar,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['uid'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      stat: json['stat'] as String,
      createTime: json['create_time'] as String,
      personalSign: json['personal_sign'] as String?,
      introduction: json['introduction'] as String?,
      avatar: json['avatar'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'username': username,
      'email': email,
      'stat': stat,
      'create_time': createTime,
      if (personalSign != null) 'personal_sign': personalSign,
      if (introduction != null) 'introduction': introduction,
      if (avatar != null) 'avatar': avatar,
    };
  }
}

// Demo 数据
class UserProfileDemoData {
  static UserProfile getDemoProfile(String userId) {
    // 预设的 demo 用户
    final demoUsers = {
      '1': UserProfile(
        uid: '1',
        username: 'XSFX',
        email: 'xsfx@example.com',
        stat: 'admin',
        createTime: '1640000000', // 2021-12-20
        personalSign: '摸鱼开发者 🐟',
        introduction: '# 关于我\n\n热爱编程，喜欢摸鱼。\n\n## 技能\n\n- Flutter 开发\n- Python 后端\n- 摸鱼',
        avatar: null,
      ),
      '2': UserProfile(
        uid: '2',
        username: 'L3',
        email: 'l3@example.com',
        stat: 'user',
        createTime: '1645000000', // 2022-02-16
        personalSign: '代码即艺术',
        introduction: '## Hello World\n\n我是L3，一名开发者。',
        avatar: null,
      ),
      '3': UserProfile(
        uid: '3',
        username: 'Pztsdy',
        email: '',
        stat: 'user',
        createTime: '1650000000',
        personalSign: null,
        introduction: null,
        avatar: null,
      ),
      '4': UserProfile(
        uid: '4',
        username: 'JohnChiao',
        email: 'johnchiao@example.com',
        stat: 'moderator',
        createTime: '1655000000', // 2022-06-12
        personalSign: 'Developing the future',
        introduction: '# Developer & Designer\n\nBuilding amazing apps with Flutter.',
        avatar: null,
      ),
      '5': UserProfile(
        uid: '5',
        username: 'Hughpig',
        email: 'hughpig@example.com',
        stat: 'user',
        createTime: '1660000000', // 2022-08-09
        personalSign: '快乐摸鱼人',
        introduction: null,
        avatar: null,
      ),
    };

    return demoUsers[userId] ?? UserProfile(
      uid: userId,
      username: 'Unknown User',
      email: 'unknown@example.com',
      stat: 'user',
      createTime: DateTime.now().millisecondsSinceEpoch.toString(),
      personalSign: null,
      introduction: null,
      avatar: null,
    );
  }
}
