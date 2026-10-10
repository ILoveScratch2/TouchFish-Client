/// 用户搜索命中项（/user/search 返回项）。不含 email。
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

/// 群组搜索命中项（/group/search 返回项）。仅公开字段。
class GroupSearchEntry {
  final int gid;
  final String groupname;
  final String introduction;
  final int memberCount;
  final bool allowDirectJoin;
  final bool requireReview;
  final bool publicMessages;

  const GroupSearchEntry({
    required this.gid,
    required this.groupname,
    this.introduction = '',
    this.memberCount = 0,
    this.allowDirectJoin = false,
    this.requireReview = true,
    this.publicMessages = false,
  });

  factory GroupSearchEntry.fromJson(Map<String, dynamic> json) {
    return GroupSearchEntry(
      gid: (json['gid'] as num?)?.toInt() ?? 0,
      groupname: json['groupname'] as String? ?? '',
      introduction: json['introduction'] as String? ?? '',
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      allowDirectJoin: json['allow_direct_join'] == true,
      requireReview: json['require_review'] == true,
      publicMessages: json['public_messages'] == true,
    );
  }
}

/// 群组搜索分页（/group/search 响应）。
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
