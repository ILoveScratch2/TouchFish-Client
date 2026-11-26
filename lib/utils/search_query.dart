/// 搜索框输入解析

class TfSearchQuery {
  final String raw;

  /// 解析 UID
  final int? uid;

  /// 解析 GID
  final int? gid;

  /// 输入带 U 前缀
  final bool explicitUid;

  /// 输入带 G 前缀
  final bool explicitGid;

  const TfSearchQuery._({
    required this.raw,
    required this.uid,
    required this.gid,
    required this.explicitUid,
    required this.explicitGid,
  });

  factory TfSearchQuery.parse(String input) {
    final raw = input.trim();
    var token = raw;
    var explicitUid = false;
    var explicitGid = false;

    if (raw.length > 1) {
      final head = raw[0];
      final rest = raw.substring(1);
      if (_isAsciiDigits(rest)) {
        if (head == 'U' || head == 'u') {
          explicitUid = true;
          token = rest;
        } else if (head == 'G' || head == 'g') {
          explicitGid = true;
          token = rest;
        }
      }
    }

    int? number;
    if (_isAsciiDigits(token)) number = int.tryParse(token);

    return TfSearchQuery._(
      raw: raw,
      uid: explicitGid ? null : number,
      gid: explicitUid ? null : number,
      explicitUid: explicitUid,
      explicitGid: explicitGid,
    );
  }

  /// 输入是否标识符
  bool get isIdentifier => uid != null || gid != null;

  /// 用户是否应发起搜索
  bool get allowsUserSearch => !explicitGid;

  /// 群组是否应发起搜索
  bool get allowsGroupSearch => !explicitUid;

  String get keyword {
    if (explicitUid || explicitGid) return raw.substring(1);
    return raw;
  }

  static bool _isAsciiDigits(String value) {
    if (value.isEmpty || value.length > 18) return false;
    for (final unit in value.codeUnits) {
      if (unit < 0x30 || unit > 0x39) return false;
    }
    return true;
  }
}
