import 'group_join_policy.dart';
import 'message_model.dart';

/// 用户搜索命中项（/user/search
class UserSearchEntry {
  final int uid;
  final String username;
  final String sign;

  const UserSearchEntry({
    required this.uid,
    required this.username,
    this.sign = '',
  });

  factory UserSearchEntry.fromJson(Map<String, dynamic> json) {
    return UserSearchEntry(
      uid: (json['uid'] as num?)?.toInt() ?? 0,
      username: json['username'] as String? ?? '',
      sign: json['sign'] as String? ?? '',
    );
  }
}

/// 群组搜索命中项（/group/search 返回
class GroupSearchEntry {
  final int gid;
  final String groupname;
  final String introduction;
  final int memberCount;
  final bool allowDirectJoin;
  final bool requireReview;
  final bool publicMessages;

  /// 加入策略
  final String joinPolicy;

  /// 是否可被搜索（其实搜索接口本身已过滤
  final bool searchable;

  const GroupSearchEntry({
    required this.gid,
    required this.groupname,
    this.introduction = '',
    this.memberCount = 0,
    this.allowDirectJoin = false,
    this.requireReview = true,
    this.publicMessages = false,
    this.joinPolicy = 'approval',
    this.searchable = true,
  });

  factory GroupSearchEntry.fromJson(Map<String, dynamic> json) {
    final allowDirectJoin = json['allow_direct_join'] == true;
    final requireReview = json['require_review'] == true;
    return GroupSearchEntry(
      gid: (json['gid'] as num?)?.toInt() ?? 0,
      groupname: json['groupname'] as String? ?? '',
      introduction: json['introduction'] as String? ?? '',
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      allowDirectJoin: allowDirectJoin,
      requireReview: requireReview,
      publicMessages: json['public_messages'] == true,
      joinPolicy: TfJoinPolicy.resolve(
        json['join_policy'] as String?,
        allowDirectJoin: allowDirectJoin,
        requireReview: requireReview,
      ),
      searchable: json['searchable'] != false,
    );
  }
}

/// 群组搜索分页
class GroupSearchPage {
  final List<GroupSearchEntry> groups;
  final bool hasMore;

  const GroupSearchPage({required this.groups, required this.hasMore});

  factory GroupSearchPage.fromJson(Map<String, dynamic> json) {
    final raw = json['groups'];
    final groups = raw is List
        ? raw
              .whereType<Map>()
              .map((e) => GroupSearchEntry.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : <GroupSearchEntry>[];
    return GroupSearchPage(groups: groups, hasMore: json['has_more'] == true);
  }
}

/// 会话内消息搜索分页
class MessageSearchPage {
  final List<ChatMessage> messages;
  final bool hasMore;

  const MessageSearchPage({required this.messages, required this.hasMore});

  static const MessageSearchPage empty = MessageSearchPage(
    messages: <ChatMessage>[],
    hasMore: false,
  );
}

