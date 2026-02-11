// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'TouchFish';

  @override
  String get appSubtitle => '现代化的即时通讯';

  @override
  String get welcomeStart => '开始使用';

  @override
  String get welcomeFeatureLightweightTitle => '轻量级';

  @override
  String get welcomeFeatureLightweightDesc => '高效且节省资源的设计';

  @override
  String get welcomeFeatureMultiplatformTitle => '多平台';

  @override
  String get welcomeFeatureMultiplatformDesc =>
      '支持 Windows、macOS、Linux、Android 和 Web';

  @override
  String get welcomeFeatureLanTitle => '无公网';

  @override
  String get welcomeFeatureLanDesc => '无需 Internet 连接,局域网内畅通无阻';

  @override
  String get loginUsername => '用户名';

  @override
  String get loginPassword => '密码';

  @override
  String get loginLogin => '登录';

  @override
  String get loginRegister => '注册';

  @override
  String get loginMsgLoginNotImpl => '暂时无登录功能实现';

  @override
  String get loginMsgRegisterNotImpl => '暂时无注册功能实现';

  @override
  String get registerTitle => '注册';

  @override
  String get registerCreateAccount => '创建新账户';

  @override
  String get registerAccountInfo => '设置账户信息';

  @override
  String get registerEmailInfo => '输入邮箱地址';

  @override
  String get registerVerifyInfo => '输入验证码';

  @override
  String get registerUsername => '用户名';

  @override
  String get registerPassword => '密码';

  @override
  String get registerConfirmPassword => '确认密码';

  @override
  String get registerEmail => 'Email';

  @override
  String get registerVerificationCode => '验证码（6位数字）';

  @override
  String get registerNextStep => '下一步';

  @override
  String get registerPreviousStep => '上一步';

  @override
  String get registerComplete => '完成注册';

  @override
  String get registerHaveAccount => '已有账户？返回登录';

  @override
  String get registerSuccess => '注册成功！';

  @override
  String get registerSuccessMessage => '您的账户已成功创建';

  @override
  String get registerBackToLogin => '返回登录页面';

  @override
  String get registerErrorUsernameRequired => '请输入用户名';

  @override
  String get registerErrorUsernameMinLength => '用户名至少需要3个字符';

  @override
  String get registerErrorPasswordRequired => '请输入密码';

  @override
  String get registerErrorConfirmPasswordRequired => '请再次输入密码';

  @override
  String get registerErrorPasswordMismatch => '两次输入的密码不一致';

  @override
  String get registerErrorVerificationCodeRequired => '请输入验证码';

  @override
  String get registerErrorVerificationCodeInvalid => '验证码必须是6位数字';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsTooltip => '设置';

  @override
  String get settingsEmpty => '设置暂无';

  @override
  String get settingsCategoryAppearance => '界面';

  @override
  String get settingsCategoryNotifications => '通知';

  @override
  String get settingsCategoryAbout => '关于';

  @override
  String get settingsLanguageTitle => '语言';

  @override
  String get settingsLanguageDesc => '应用的语言';

  @override
  String get settingsLanguageSystem => '跟随系统';

  @override
  String get settingsLanguageZh => '简体中文';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get settingsThemeTitle => '主题';

  @override
  String get settingsThemeDesc => '应用的外观主题';

  @override
  String get settingsThemeSystem => '跟随系统';

  @override
  String get settingsThemeLight => '浅色';

  @override
  String get settingsThemeDark => '深色';

  @override
  String get settingsThemeColorTitle => '主题颜色';

  @override
  String get settingsThemeColorDesc => '应用内使用的主颜色';

  @override
  String get settingsColorDefault => '默认';

  @override
  String get settingsColorRed => '红色';

  @override
  String get settingsColorGreen => '绿色';

  @override
  String get settingsColorPurple => '紫色';

  @override
  String get settingsColorOrange => '橙色';

  @override
  String get settingsSendModeTitle => '发送模式';

  @override
  String get settingsSendModeDesc => '发送使用的快捷键';

  @override
  String get settingsSendModeEnter => '按 Enter 发送';

  @override
  String get settingsSendModeCtrlEnter => '按 Ctrl+Enter 发送';

  @override
  String get settingsEnableMarkdownTitle => '渲染Markdown/LaTeX内容';

  @override
  String get settingsEnableMarkdownDesc => '将可渲染的Markdown/LaTeX文本进行渲染';

  @override
  String get settingsSystemNotificationsTitle => '系统通知';

  @override
  String get settingsSystemNotificationsDesc => '使用操作系统通知进行消息通知';

  @override
  String get settingsInAppNotificationsTitle => '应用内通知';

  @override
  String get settingsInAppNotificationsDesc => '在应用内进行消息通知';

  @override
  String get settingsNotificationSoundTitle => '通知声音';

  @override
  String get settingsNotificationSoundDesc => '应用内通知时播放声音';

  @override
  String get settingsChatNotificationsTitle => '对话通知';

  @override
  String get settingsChatNotificationsDesc => '配置私聊和群组的通知设置';

  @override
  String get settingsPrivateChatTitle => '私聊通知';

  @override
  String get settingsGroupChatTitle => '群组通知';

  @override
  String get settingsAboutAppTitle => '关于应用';

  @override
  String get serverTitle => '服务器';

  @override
  String get serverAdd => '添加服务器';

  @override
  String get serverEdit => '编辑服务器';

  @override
  String get serverDelete => '删除服务器';

  @override
  String get serverSelect => '选择服务器';

  @override
  String get serverUrlLabel => '服务器地址';

  @override
  String get serverUrlHint => '例如：touchfish.xin';

  @override
  String get serverCannotDeleteLast => '不能删除最后一个服务器';

  @override
  String get serverInvalidUrl => '无效的服务器地址';

  @override
  String get serverAddServer => '添加';

  @override
  String get serverCancel => '取消';

  @override
  String get serverDisplayName => '显示名称';

  @override
  String get serverDisplayNameHint => '例如：我的服务器';

  @override
  String get serverAddress => '服务器地址';

  @override
  String get serverAddressHint => '例如：touchfish.xin';

  @override
  String get serverApiPort => 'API服务端口';

  @override
  String get serverApiPortHint => '例如：8080';

  @override
  String get serverTcpPort => 'TCP服务端口';

  @override
  String get serverTcpPortHint => '例如：9090';

  @override
  String get serverErrorInvalidAddress => '地址无效';

  @override
  String get serverErrorInvalidPort => '端口需为0到65535间的整数';

  @override
  String get serverErrorDuplicatePort => '端口不能重复';

  @override
  String get navChat => '聊天';

  @override
  String get navAnnouncement => '公告';

  @override
  String get navForum => '论坛';

  @override
  String get navAccount => '账户';

  @override
  String get chatTabMessages => '聊天';

  @override
  String get chatTabContacts => '联系人';

  @override
  String get chatInvites => '邀请';

  @override
  String get chatNoInvites => '没有邀请';

  @override
  String get chatPinned => '置顶会话';

  @override
  String get chatDirectMessage => '私聊';

  @override
  String get chatGroupMessage => '群组';

  @override
  String get chatOnline => '在线';

  @override
  String get chatOffline => '离线';

  @override
  String get chatAway => '离开';

  @override
  String get chatYesterday => '昨天';

  @override
  String get chatDetailLoading => '加载中...';

  @override
  String get chatDetailUnknownUser => '未知用户';

  @override
  String get chatDetailOther => '对方';

  @override
  String get chatDetailGroupChat => '群聊';

  @override
  String get chatDetailNoMessages => '暂无消息\n发送一条消息开始聊天吧';

  @override
  String get chatInputCollapse => '收起';

  @override
  String get chatInputExpand => '更多';

  @override
  String get chatInputAttachment => '附件';

  @override
  String get chatInputTakePhoto => '拍摄照片';

  @override
  String get chatInputTakeVideo => '拍摄视频';

  @override
  String get chatInputUploadFile => '上传文件';

  @override
  String get chatInputRecordAudio => '录制语音';

  @override
  String get chatInputPlaceholder => '输入消息...';

  @override
  String get chatInputFeatureArea => '功能区域';

  @override
  String get networkStatusTitle => '网络状态';

  @override
  String get networkStatusConnected => '已连接到互联网';

  @override
  String get networkStatusConnectedDesc => '您已连接到互联网，可以连接公共网络上的 TouchFish 服务器';

  @override
  String get networkStatusDisconnected => '已断开互联网连接';

  @override
  String get networkStatusDisconnectedDesc => '您已断开互联网连接，仅能连接内网服务器';

  @override
  String get networkStatusCheckingConnection => '正在检查网络连接...';

  @override
  String get messageActions => '消息操作';

  @override
  String get messageActionReply => '回复';

  @override
  String get messageActionForward => '转发';

  @override
  String get messageActionDelete => '删除';

  @override
  String get chatRoomSettings => '聊天设置';

  @override
  String get chatRoomMembers => '聊天成员';

  @override
  String get chatRoomEdit => '编辑聊天';

  @override
  String get chatRoomEditName => '编辑名称';

  @override
  String get chatRoomPin => '置顶聊天';

  @override
  String get chatRoomPinDescription => '将此聊天固定在列表顶部';

  @override
  String get chatRoomPinned => '已置顶聊天';

  @override
  String get chatRoomUnpinned => '已取消置顶';

  @override
  String get chatRoomName => '聊天名称';

  @override
  String get chatRoomContactName => '联系人备注名';

  @override
  String get chatRoomNameHelp => '仅当您有权限时可修改';

  @override
  String get chatRoomAlias => '聊天别名';

  @override
  String get chatRoomAliasHelp => '仅您可见的自定义名称';

  @override
  String get chatRoomDescription => '聊天描述';

  @override
  String get chatRoomDescriptionHelp => '仅您可见的自定义描述';

  @override
  String get chatRoomNoDescription => '暂无描述';

  @override
  String get chatRoomNameUpdated => '聊天名称已更新';

  @override
  String get chatRoomUpdated => '聊天信息已更新';

  @override
  String get chatNotifyLevel => '通知级别';

  @override
  String get chatNotifyLevelAll => '全部消息';

  @override
  String get chatNotifyLevelAllDescription => '接收所有消息的通知';

  @override
  String get chatNotifyLevelMention => '仅提及';

  @override
  String get chatNotifyLevelMentionDescription => '仅当有人提及您时接收通知';

  @override
  String get chatNotifyLevelNone => '静音';

  @override
  String get chatNotifyLevelNoneDescription => '不接收任何通知';

  @override
  String get chatSearchMessages => '搜索消息';

  @override
  String get chatSearchMessagesDescription => '在此聊天中搜索消息';

  @override
  String get chatSearchMessagesPlaceholder => '搜索消息内容...';

  @override
  String get chatSearchMessagesHint => '输入关键词搜索消息';

  @override
  String get chatSearchMessagesNoResults => '未找到相关消息';

  @override
  String get chatLeaveRoom => '退出聊天';

  @override
  String get chatLeaveRoomDescription => '离开此聊天室';

  @override
  String get chatLeaveRoomConfirm => '确定要退出此聊天吗？';

  @override
  String get chatRoomLeft => '已退出聊天室';

  @override
  String get cancel => '取消';

  @override
  String get save => '保存';

  @override
  String get leave => '退出';

  @override
  String get mediaPickImage => '选择图片';

  @override
  String get mediaPickVideo => '选择视频';

  @override
  String get mediaPickAudio => '选择音频';

  @override
  String get mediaPickFile => '选择文件';

  @override
  String get mediaImageMessage => '[图片]';

  @override
  String get mediaVideoMessage => '[视频]';

  @override
  String get mediaAudioMessage => '[音频]';

  @override
  String get mediaFileMessage => '[文件]';

  @override
  String get mediaUnknown => '未知';

  @override
  String get mediaPlayAudio => '播放音频';

  @override
  String get mediaPauseAudio => '暂停音频';

  @override
  String get userProfileTitle => '用户资料';

  @override
  String get userProfileUsername => '用户名';

  @override
  String get userProfileEmail => '邮箱';

  @override
  String get userProfileUid => '用户ID';

  @override
  String get userProfileJoinedAt => '加入时间';

  @override
  String get userProfilePermission => '权限';

  @override
  String get userProfilePermissionAdmin => '管理员';

  @override
  String get userProfilePermissionModerator => '版主';

  @override
  String get userProfilePermissionUser => '用户';

  @override
  String get userProfilePersonalSign => '个性签名';

  @override
  String get userProfileIntroduction => '自我介绍';

  @override
  String get userProfileNoPersonalSign => '暂无个性签名';

  @override
  String get userProfileNoIntroduction => '暂无自我介绍';

  @override
  String get userProfileCopyUid => '复制用户ID';

  @override
  String get userProfileUidCopied => '用户ID已复制';

  @override
  String get userProfileSendMessage => '发送消息';

  @override
  String get userProfileLoading => '加载用户资料中...';

  @override
  String get userProfileAddFriend => '添加好友';

  @override
  String get userProfileUnknownEmail => '未知';

  @override
  String get markdownCopyCode => '复制代码';

  @override
  String get markdownCodeCopied => '代码已复制到剪贴板';
}
