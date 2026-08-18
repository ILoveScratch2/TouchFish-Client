/// 通知分级（横幅显示逻辑）。
///
/// 分级只影响"横幅"的展示方式，通知中心的数据保持不变。
enum NotificationLevel {
  /// 一级：只显示聊天通知的汇总横幅。
  ///
  /// 只显示"多少个联系人发了多少条消息"，永远最多只有一条横幅。
  minimal(1),

  /// 二级：只显示聊天通知，每个联系人一条横幅。
  ///
  /// 横幅条数 = 有未读消息的联系人数，每条横幅显示该联系人的最后一条消息。
  perSender(2),

  /// 三级：显示所有通知，每有一条通知就打一条横幅（原来的样子）。
  full(3);

  final int value;
  const NotificationLevel(this.value);

  static NotificationLevel fromValue(int? value) =>
      NotificationLevel.values.firstWhere(
        (level) => level.value == value,
        orElse: () => NotificationLevel.perSender,
      );

  static NotificationLevel fromSetting(String? value) =>
      fromValue(int.tryParse(value ?? '') ?? 2);

  String get storageValue => '$value';

  bool get isMinimal => this == NotificationLevel.minimal;
  bool get isPerSender => this == NotificationLevel.perSender;
  bool get isFull => this == NotificationLevel.full;
}