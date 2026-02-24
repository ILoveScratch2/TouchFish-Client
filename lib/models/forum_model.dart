class Forum {
  final String id;
  final String name;
  final String description;
  final bool isPublic;
  final bool isCommunity;
  final String createdByUid;
  final DateTime createdAt;
  final DateTime updatedAt;

  Forum({
    required this.id,
    required this.name,
    required this.description,
    required this.isPublic,
    required this.isCommunity,
    required this.createdByUid,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Forum.fromJson(Map<String, dynamic> json) {
    return Forum(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      isPublic: json['is_public'] as bool,
      isCommunity: json['is_community'] as bool,
      createdByUid: json['created_by_uid'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'is_public': isPublic,
      'is_community': isCommunity,
      'created_by_uid': createdByUid,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class ForumMember {
  final String forumId;
  final String accountUid;
  final int role;
  final DateTime? joinedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  ForumMember({
    required this.forumId,
    required this.accountUid,
    required this.role,
    this.joinedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ForumMember.fromJson(Map<String, dynamic> json) {
    return ForumMember(
      forumId: json['forum_id'] as String,
      accountUid: json['account_uid'] as String,
      role: json['role'] as int,
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'forum_id': forumId,
      'account_uid': accountUid,
      'role': role,
      if (joinedAt != null) 'joined_at': joinedAt!.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class ForumPost {
  final String id;
  final String forumId;
  final String authorUid;
  final String title;
  final String content;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  ForumPost({
    required this.id,
    required this.forumId,
    required this.authorUid,
    required this.title,
    required this.content,
    required this.isPinned,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ForumPost.fromJson(Map<String, dynamic> json) {
    return ForumPost(
      id: json['id'] as String,
      forumId: json['forum_id'] as String,
      authorUid: json['author_uid'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      isPinned: json['is_pinned'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'forum_id': forumId,
      'author_uid': authorUid,
      'title': title,
      'content': content,
      'is_pinned': isPinned,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ForumPost copyWith({
    String? id,
    String? forumId,
    String? authorUid,
    String? title,
    String? content,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ForumPost(
      id: id ?? this.id,
      forumId: forumId ?? this.forumId,
      authorUid: authorUid ?? this.authorUid,
      title: title ?? this.title,
      content: content ?? this.content,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ForumComment {
  final String id;
  final String postId;
  final String authorUid;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  ForumComment({
    required this.id,
    required this.postId,
    required this.authorUid,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ForumComment.fromJson(Map<String, dynamic> json) {
    return ForumComment(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      authorUid: json['author_uid'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'post_id': postId,
      'author_uid': authorUid,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class ForumDemoData {
  static List<Forum> getDemoForums() {
    return [
      Forum(
        id: 'forum-1',
        name: 'TouchFish Devs',
        description: 'TouchFish 开发！',
        isPublic: true,
        isCommunity: true,
        createdByUid: '1',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 6, 15),
      ),
      Forum(
        id: 'forum-2',
        name: 'General',
        description: '通用讨论区，欢迎任何话题！',
        isPublic: true,
        isCommunity: true,
        createdByUid: '1',
        createdAt: DateTime(2025, 2, 1),
        updatedAt: DateTime(2025, 7, 20),
      ),
      Forum(
        id: 'forum-3',
        name: '学术版',
        description: '进行计算机科学学术内容交流的地方，而并不是发布水贴的地方！',
        isPublic: true,
        isCommunity: true,
        createdByUid: '4',
        createdAt: DateTime(2025, 3, 10),
        updatedAt: DateTime(2025, 8, 1),
      ),
      Forum(
        id: 'forum-4',
        name: '灌水专用',
        description: '摸鱼专用灌水，爱写啥写啥…… ~~Owned by XSFX~~',
        isPublic: true,
        isCommunity: false,
        createdByUid: '1',
        createdAt: DateTime(2025, 4, 5),
        updatedAt: DateTime(2025, 9, 10),
      ),
    ];
  }

  static List<ForumMember> getDemoMembers(String forumId) {
    final now = DateTime.now();
    switch (forumId) {
      case 'forum-1':
        return [
          ForumMember(forumId: forumId, accountUid: '1', role: 100, joinedAt: DateTime(2025, 1, 1), createdAt: DateTime(2025, 1, 1), updatedAt: now),
          ForumMember(forumId: forumId, accountUid: '2', role: 0, joinedAt: DateTime(2025, 1, 5), createdAt: DateTime(2025, 1, 5), updatedAt: now),
          ForumMember(forumId: forumId, accountUid: '3', role: 0, joinedAt: DateTime(2025, 2, 1), createdAt: DateTime(2025, 2, 1), updatedAt: now),
          ForumMember(forumId: forumId, accountUid: '4', role: 50, joinedAt: DateTime(2025, 1, 10), createdAt: DateTime(2025, 1, 10), updatedAt: now),
          ForumMember(forumId: forumId, accountUid: '5', role: 0, joinedAt: DateTime(2025, 3, 1), createdAt: DateTime(2025, 3, 1), updatedAt: now),
        ];
      case 'forum-2':
        return [
          ForumMember(forumId: forumId, accountUid: '1', role: 100, joinedAt: DateTime(2025, 2, 1), createdAt: DateTime(2025, 2, 1), updatedAt: now),
          ForumMember(forumId: forumId, accountUid: '2', role: 0, joinedAt: DateTime(2025, 2, 5), createdAt: DateTime(2025, 2, 5), updatedAt: now),
          ForumMember(forumId: forumId, accountUid: '5', role: 0, joinedAt: DateTime(2025, 2, 10), createdAt: DateTime(2025, 2, 10), updatedAt: now),
        ];
      case 'forum-3':
        return [
          ForumMember(forumId: forumId, accountUid: '4', role: 100, joinedAt: DateTime(2025, 3, 10), createdAt: DateTime(2025, 3, 10), updatedAt: now),
          ForumMember(forumId: forumId, accountUid: '1', role: 50, joinedAt: DateTime(2025, 3, 15), createdAt: DateTime(2025, 3, 15), updatedAt: now),
          ForumMember(forumId: forumId, accountUid: '2', role: 0, joinedAt: DateTime(2025, 4, 1), createdAt: DateTime(2025, 4, 1), updatedAt: now),
        ];
      case 'forum-4':
        return [
          ForumMember(forumId: forumId, accountUid: '1', role: 100, joinedAt: DateTime(2025, 4, 5), createdAt: DateTime(2025, 4, 5), updatedAt: now),
          ForumMember(forumId: forumId, accountUid: '4', role: 50, joinedAt: DateTime(2025, 4, 10), createdAt: DateTime(2025, 4, 10), updatedAt: now),
        ];
      default:
        return [];
    }
  }

  static ForumMember? getDemoIdentity(String forumId, String currentUid) {
    final members = getDemoMembers(forumId);
    try {
      return members.firstWhere((m) => m.accountUid == currentUid);
    } catch (_) {
      return null;
    }
  }

  static List<ForumPost> getDemoPosts(String forumId) {
    switch (forumId) {
      case 'forum-1':
        return [
          ForumPost(
            id: 'post-1',
            forumId: forumId,
            authorUid: '1',
            title: 'Welcome to TouchFish Devs!',
            content: '欢迎来到 TouchFish Devs！专门为 TouchFish 开发者准备的讨论区，可以交流 TF 相关的话题！\n\n在这里你可以：\n- 晶石后刃\n- 申请发行版\n- 报告 bug\n- 提出建议\n\n**期待大家的积极参与**！',
            isPinned: true,
            createdAt: DateTime(2025, 1, 2),
            updatedAt: DateTime(2025, 1, 2),
          ),
          ForumPost(
            id: 'post-2',
            forumId: forumId,
            authorUid: '4',
            title: 'TouchFish TODO',
            content: '- [ ] Chat 系统\n - [ ] 表情包系统\n - [ ] 公告文档\n- [x] README\n',
            isPinned: false,
            createdAt: DateTime(2025, 2, 10),
            updatedAt: DateTime(2025, 2, 10),
          ),
          ForumPost(
            id: 'post-3',
            forumId: forumId,
            authorUid: '2',
            title: 'UI 优化',
            content: 'TouchFish Client 应该加一些更个性化的设置选项吧？',
            isPinned: false,
            createdAt: DateTime(2025, 3, 5),
            updatedAt: DateTime(2025, 3, 5),
          ),
        ];
      case 'forum-2':
        return [
          ForumPost(
            id: 'post-4',
            forumId: forumId,
            authorUid: '1',
            title: '社区准则',
            content: '社区准则：\n\n1. 尊重他人，禁止人身攻击\n2. 禁止发布违法违规内容\n3. 推荐进行积极分享和建设性讨论\n4.本区管理员 xsfx 有权删除违规内容并对违规用户进行处理\n\n**让我们一起营造一个友好、积极的社区环境！**',
            isPinned: true,
            createdAt: DateTime(2025, 2, 2),
            updatedAt: DateTime(2025, 2, 2),
          ),
          ForumPost(
            id: 'post-5',
            forumId: forumId,
            authorUid: '5',
            title: '大家好！',
            content: '期待与大家交流，刚注册TF，感觉这个社区很有潜力！',
            isPinned: false,
            createdAt: DateTime(2025, 4, 1),
            updatedAt: DateTime(2025, 4, 1),
          ),
        ];
      case 'forum-3':
        return [
          ForumPost(
            id: 'post-6',
            forumId: forumId,
            authorUid: '4',
            title: 'TouchFish 宣传',
            content: 'TouchFish：\n\n- 使用 \$Python\$ 编写，性能~~不太优越但是很可靠就对了~~\n- 支持论坛聊天公告等板块\n- 内置功能丰富\n\n欢迎大家讨论和提建议！',
            isPinned: true,
            createdAt: DateTime(2025, 3, 15),
            updatedAt: DateTime(2025, 3, 15),
          ),
          ForumPost(
            id: 'post-7',
            forumId: forumId,
            authorUid: '2',
            title: '补药 xsfx',
            content: '西西爱抚：xsfx 兴奋作用过强，禁止在比赛前食用 xsfx，比赛前食用 xsfx 可能会导致过度兴奋，影响发挥，甚至属于作弊行为。请大家合理安排 xsfx 的食用时间，避免在比赛前食用，以确保最佳表现和安全。',
            isPinned: false,
            createdAt: DateTime(2025, 5, 20),
            updatedAt: DateTime(2025, 5, 20),
          ),
        ];
      case 'forum-4':
        return [
          ForumPost(
            id: 'post-8',
            forumId: forumId,
            authorUid: '4',
            title: 'qp',
            content: 'qp',
            isPinned: false,
            createdAt: DateTime(2025, 5, 1),
            updatedAt: DateTime(2025, 5, 1),
          ),
        ];
      default:
        return [];
    }
  }

  static List<ForumComment> getDemoComments(String postId) {
    switch (postId) {
      case 'post-1':
        return [
          ForumComment(
            id: 'comment-1',
            postId: postId,
            authorUid: '2',
            content: '是的，我来 qp 了',
            createdAt: DateTime(2025, 1, 3),
            updatedAt: DateTime(2025, 1, 3),
          ),
          ForumComment(
            id: 'comment-2',
            postId: postId,
            authorUid: '4',
            content: 'qp',
            createdAt: DateTime(2025, 1, 4),
            updatedAt: DateTime(2025, 1, 4),
          ),
        ];
      case 'post-2':
        return [
          ForumComment(
            id: 'comment-3',
            postId: postId,
            authorUid: '1',
            content: '经济系统先不加了，专注做好核心功能吧！',
            createdAt: DateTime(2025, 2, 11),
            updatedAt: DateTime(2025, 2, 11),
          ),
          ForumComment(
            id: 'comment-4',
            postId: postId,
            authorUid: '2',
            content: 'README 链接打不开了，快修！',
            createdAt: DateTime(2025, 2, 12),
            updatedAt: DateTime(2025, 2, 12),
          ),
          ForumComment(
            id: 'comment-5',
            postId: postId,
            authorUid: '5',
            content: '表情包怎么搞？',
            createdAt: DateTime(2025, 2, 13),
            updatedAt: DateTime(2025, 2, 13),
          ),
        ];
      case 'post-3':
        return [
          ForumComment(
            id: 'comment-6',
            postId: postId,
            authorUid: '1',
            content: '加个窗口透明？不知道 Flutter 支不支持……',
            createdAt: DateTime(2025, 3, 6),
            updatedAt: DateTime(2025, 3, 6),
          ),
          ForumComment(
            id: 'comment-7',
            postId: postId,
            authorUid: '4',
            content: 'TFUR 貌似好看些？也加个背景图片设置？',
            createdAt: DateTime(2025, 3, 7),
            updatedAt: DateTime(2025, 3, 7),
          ),
        ];
      case 'post-6':
        return [
          ForumComment(
            id: 'comment-8',
            postId: postId,
            authorUid: '1',
            content: 'TF 创始人 到此一游',
            createdAt: DateTime(2025, 3, 16),
            updatedAt: DateTime(2025, 3, 16),
          ),
        ];
      case 'post-8':
        return [
          ForumComment(
            id: 'comment-9',
            postId: postId,
            authorUid: '1',
            content: 'qp qp qp qp pqpqpqpqpqpqpqpqpq',
            createdAt: DateTime(2025, 5, 2),
            updatedAt: DateTime(2025, 5, 2),
          ),
          ForumComment(
            id: 'comment-10',
            postId: postId,
            authorUid: '4',
            content: '冒泡',
            createdAt: DateTime(2025, 5, 3),
            updatedAt: DateTime(2025, 5, 3),
          ),
        ];
      default:
        return [];
    }
  }

  static int getCommentCount(String postId) {
    return getDemoComments(postId).length;
  }

  /// Returns the most recent comment for a post (featured comment preview).
  static ForumComment? getFeaturedComment(String postId) {
    final comments = getDemoComments(postId);
    if (comments.isEmpty) return null;
    return comments.last;
  }

  /// Returns forums the given user has joined.
  static List<Forum> getJoinedForums(String uid) {
    final allForums = getDemoForums();
    return allForums.where((forum) {
      final members = getDemoMembers(forum.id);
      return members.any((m) => m.accountUid == uid);
    }).toList();
  }
}
