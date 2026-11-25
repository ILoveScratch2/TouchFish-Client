/// 群加入策略（四档互斥）。
///
/// 与「可被搜索」(`searchable`) 是两件独立的事：
/// - `searchable` 只决定群能否被搜到，不影响已有邀请与群号直达；
/// - 本枚举决定谁能进群。
///
/// 服务端以此为准，同时把结果派生回旧的 `allow_direct_join` /
/// `require_review` 两个布尔值供老客户端使用。
class TfJoinPolicy {
  /// 允许自由加入：任何人直接进群
  static const String open = 'open';

  /// 允许审批加入：任何人可申请，群主/管理员审批
  static const String approval = 'approval';

  /// 仅允许邀请：任一成员可邀请，邀请即入群
  static const String invite = 'invite';

  /// 仅允许管理员邀请
  static const String adminInvite = 'admin_invite';

  static const List<String> values = [open, approval, invite, adminInvite];

  /// 老服务器不返回 `join_policy`，用两个布尔值反推（与服务端迁移规则一致）。
  static String resolve(
    String? raw, {
    required bool allowDirectJoin,
    required bool requireReview,
  }) {
    final value = (raw ?? '').trim();
    if (values.contains(value)) return value;
    if (allowDirectJoin) return requireReview ? approval : open;
    return requireReview ? adminInvite : invite;
  }

  /// 能否自己发起加入（open / approval）
  static bool allowsSelfJoin(String policy) =>
      policy == open || policy == approval;

  /// 是否需要审批（仅 approval 档；管理员邀请除外）
  static bool needsApproval(String policy) => policy == approval;

  /// 普通成员能否邀请
  static bool allowsMemberInvite(String policy) => policy != adminInvite;
}
