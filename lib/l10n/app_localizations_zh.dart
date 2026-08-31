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
  String get loginErrorEmptyFields => '请输入用户名和密码';

  @override
  String get loginErrorUserNotFound => '用户不存在';

  @override
  String get loginErrorInvalidCredentials => '密码错误';

  @override
  String get loginErrorNetwork => '网络错误，请重试';

  @override
  String get loginErrorSessionLimit => '登录设备数量已达上限';

  @override
  String get loginDegradedToLegacy =>
      '该服务器不支持 JWT 认证，已自动降级为兼容登录（UID + PASSWORD）';

  @override
  String get sessionExpiredMessage => '登录已过期，请重新登录';

  @override
  String get savedSessionRestoreConnectingTitle => '正在连接';

  @override
  String get savedSessionRestoreConnectingMessage => '正在恢复已保存的会话并验证登录状态，请稍候。';

  @override
  String get savedSessionRestoreFailedTitle => '无法使用已保存会话';

  @override
  String get savedSessionRestoreFailedMessage => '无法在服务器使用该会话，请检查网络连接或登录凭据';

  @override
  String get sessionDevicesTitle => '设备管理';

  @override
  String get sessionDevicesUnsupported => '当前服务器不支持 JWT 认证，无法管理设备';

  @override
  String get sessionDevicesCountLabel => '已登录';

  @override
  String get sessionDevicesUnlimited => '不限';

  @override
  String get sessionDevicesUnknownDevice => '未知设备';

  @override
  String get sessionDevicesEmpty => '暂无已登录设备';

  @override
  String get sessionDevicesLoadFailed => '加载设备列表失败';

  @override
  String get sessionDevicesCurrent => '当前设备';

  @override
  String get sessionDevicesIpLabel => 'IP:';

  @override
  String get sessionDevicesIssuedAtLabel => '签发于';

  @override
  String get sessionDevicesExpiresAtLabel => '过期于';

  @override
  String get sessionDevicesRemove => '移除设备';

  @override
  String get sessionDevicesRemoveConfirmTitle => '移除设备？';

  @override
  String get sessionDevicesRemoveConfirmMessage => '该设备的登录状态将立即失效，如需恢复需重新登录。';

  @override
  String get sessionDevicesRemoveSuccess => '设备已移除';

  @override
  String get sessionDevicesRemoveFailed => '移除失败，请重试';

  @override
  String get sessionRestoreNetworkError => '网络连接失败，请检查网络后重试';

  @override
  String get registerErrorCaptchaRequired => '请输入验证码';

  @override
  String get registerCaptchaLoad => '正在加载验证码...';

  @override
  String get registerCaptchaCode => '验证码';

  @override
  String get registerCaptchaRefresh => '刷新';

  @override
  String get registerErrorFailed => '注册失败，请重试';

  @override
  String get registerConfirmInfo => '确认注册信息';

  @override
  String get registerActivateFailed => '激活失败，请检查激活码';

  @override
  String get forumLoadFailed => '加载论坛失败';

  @override
  String get forumPostLoadFailed => '加载帖子失败';

  @override
  String get forumCommentFailed => '评论发送失败';

  @override
  String get forumPostFailed => '发布帖子失败';

  @override
  String get userProfileNotFound => '用户不存在';

  @override
  String get retry => '重试';

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
  String get settingsCategoryDrafts => '草稿';

  @override
  String get settingsSaveChatDraftsTitle => '保存聊天草稿';

  @override
  String get settingsSaveChatDraftsDesc =>
      '自动保存每个聊天会话中未发送的文字。关闭后会清除当前服务器和账户的聊天草稿。';

  @override
  String get settingsSaveForumDraftsTitle => '保存论坛草稿';

  @override
  String get settingsSaveForumDraftsDesc =>
      '自动保存论坛创建、发帖、评论和附件草稿。关闭后会清除当前服务器和账户的论坛草稿。';

  @override
  String get settingsCategoryAbout => '关于';

  @override
  String get settingsCategorySecurity => '安全';

  @override
  String get settingsSecurityMasterPasswordTitle => '主密码';

  @override
  String get settingsSecurityMasterPasswordDesc => '锁定应用需要输入主密码';

  @override
  String get settingsSecuritySetPassword => '设置主密码';

  @override
  String get settingsSecurityChangePassword => '修改主密码';

  @override
  String get settingsSecurityCurrentPassword => '当前主密码';

  @override
  String get settingsSecurityConfirmPassword => '确认主密码';

  @override
  String get settingsSecurityPasswordTooShort => '主密码至少需要 4 个字符';

  @override
  String get settingsSecurityPasswordMismatch => '两次输入的主密码不一致';

  @override
  String get settingsSecurityPasswordSet => '主密码已设置';

  @override
  String get settingsSecurityPasswordChanged => '主密码已修改';

  @override
  String get settingsSecurityPasswordDisabled => '主密码已关闭';

  @override
  String get settingsSecurityPasswordIncorrect => '主密码错误';

  @override
  String get settingsSecurityDisablePassword => '关闭主密码';

  @override
  String get settingsSecurityDisablePasswordConfirm =>
      '确定要关闭主密码吗？关闭后将同时关闭生物识别解锁，应用不再锁定。';

  @override
  String get settingsSecurityBiometricTitle => '生物识别解锁';

  @override
  String get settingsSecurityBiometricDesc => '在支持的设备上使用指纹或面容解锁应用';

  @override
  String get settingsSecurityBiometricUnavailable => '当前设备不支持生物识别';

  @override
  String get settingsSecurityBiometricCancelled => '生物识别验证已取消';

  @override
  String get settingsSecurityBiometricFailed => '启用生物识别失败';

  @override
  String get settingsSecurityLockNowTitle => '立即锁定';

  @override
  String get settingsSecurityLockNowDesc => '立即锁定应用，需要主密码或生物识别才能解锁';

  @override
  String get settingsShowOnLockScreenTitle => '显示在锁屏上层';

  @override
  String get settingsShowOnLockScreenDesc =>
      '开启后应用可显示在 Android 锁屏之上，即使未解锁也能查看和使用内容（系统可能限制输入字符或安全操作）';

  @override
  String get settingsBuiltInKeyboardTitle => '使用应用内置软键盘';

  @override
  String get settingsBuiltInKeyboardDesc =>
      '使用 TouchFish-Client 提供的内置软键盘输入文本，仅支持 English 输入';

  @override
  String get settingsBuiltInKeyboardNever => '完全不使用';

  @override
  String get settingsBuiltInKeyboardLock => '仅锁屏时';

  @override
  String get settingsBuiltInKeyboardAlways => '一直使用';

  @override
  String get settingsLinkOpenModeTitle => '打开链接方式';

  @override
  String get settingsLinkOpenModeDesc => '选择 Android 上链接的打开方式：内置浏览器或外部浏览器';

  @override
  String get settingsLinkOpenModeInapp => '内置浏览器';

  @override
  String get settingsLinkOpenModeExternal => '外部浏览器';

  @override
  String get settingsBrowserSearchEngineTitle => '搜索引擎';

  @override
  String get settingsBrowserSearchEngineDesc => '在浏览器地址栏输入搜索词时使用的搜索引擎';

  @override
  String get settingsBrowserSearchEngineBing => 'Bing';

  @override
  String get settingsBrowserSearchEngineDuckduckgo => 'DuckDuckGo';

  @override
  String get settingsBrowserSearchEngineBaidu => '百度';

  @override
  String get browserNewTab => '新建标签页';

  @override
  String get browserCloseTab => '关闭标签页';

  @override
  String get browserAddressHint => '输入网址或搜索内容';

  @override
  String get browserGo => '前往';

  @override
  String get browserBack => '后退';

  @override
  String get browserForward => '前进';

  @override
  String get browserRefresh => '刷新';

  @override
  String get browserStop => '停止';

  @override
  String get browserOpenInExternal => '在外部浏览器打开';

  @override
  String get browserOpenInNewTab => '在新标签页打开';

  @override
  String get browserCopyLink => '复制链接';

  @override
  String get browserCopied => '已复制链接';

  @override
  String get browserOpenFailed => '没有可打开此链接的应用';

  @override
  String get browserFindOnPage => '网页内查找';

  @override
  String get browserFindHint => '查找网页内容';

  @override
  String get browserNoResults => '无结果';

  @override
  String get browserShare => '分享';

  @override
  String get browserLoadingFailed => '页面加载失败';

  @override
  String get browserRetry => '重试';

  @override
  String get browserTabLimitReached => '标签页数量已达上限，请先关闭部分标签页';

  @override
  String get browserRememberDomainTitle => '在外部浏览器打开？';

  @override
  String browserRememberDomainMessage(Object domain) {
    return '将 $domain 的链接始终用外部浏览器打开，并加入信任域？';
  }

  @override
  String get browserOpenAnyway => '仍要打开';

  @override
  String get browserDownloadTitle => '下载文件';

  @override
  String get browserDownloadMessage => '此链接会下载文件。是否在外部浏览器中打开以完成下载？';

  @override
  String get browserDownloadOpen => '在浏览器中打开';

  @override
  String get browserAddBookmark => '添加书签';

  @override
  String get browserRemoveBookmark => '移除书签';

  @override
  String get browserBookmarkAdded => '已添加书签';

  @override
  String get browserBookmarkRemoved => '已移除书签';

  @override
  String get browserBookmarks => '书签';

  @override
  String get browserBookmarksEmpty => '暂无书签';

  @override
  String get browserHistory => '历史记录';

  @override
  String get browserHistoryEmpty => '暂无历史记录';

  @override
  String get browserHistoryClear => '清空历史';

  @override
  String get browserExitBrowser => '退出浏览器';

  @override
  String get browserClearDataTitle => '清除浏览数据';

  @override
  String get browserClearDataDesc => '选择时间范围与要清除的数据类型';

  @override
  String get browserClearDataRangeHour => '最近 1 小时';

  @override
  String get browserClearDataRangeDay => '最近 24 小时';

  @override
  String get browserClearDataRangeWeek => '最近 7 天';

  @override
  String get browserClearDataRangeAll => '全部时间';

  @override
  String get browserClearDataTypeHistory => '浏览历史';

  @override
  String get browserClearDataTypeCookies => 'Cookie 与站点数据';

  @override
  String get browserClearDataTypeCache => '缓存文件';

  @override
  String get browserClearDataCookiesWarning => '清除 Cookie 会使部分网站退出登录';

  @override
  String get browserClearDataConfirm => '清除';

  @override
  String get browserClearDataDone => '已清除浏览数据';

  @override
  String get browserHistorySearchHint => '搜索历史';

  @override
  String get browserBookmarksSearchHint => '搜索书签';

  @override
  String get browserNoSearchResults => '未找到结果';

  @override
  String get browserDeleteEntry => '删除';

  @override
  String get browserHistoryToday => '今天';

  @override
  String get browserHistoryYesterday => '昨天';

  @override
  String get browserNewTabRecent => '最近访问';

  @override
  String get browserNewTabOpenBookmarks => '书签';

  @override
  String get browserNewTabOpenHistory => '历史记录';

  @override
  String get browserNewTabSearchPlaceholder => '搜索或输入网址';

  @override
  String get settingsBrowserUserAgentTitle => '自定义 User-Agent';

  @override
  String get settingsBrowserUserAgentDesc =>
      '留空使用默认值。可填入自定义 User-Agent（例如桌面版 Chrome）';

  @override
  String get settingsBrowserUserAgentHint => '自定义 User-Agent 字符串';

  @override
  String get settingsBrowserUserAgentDefault => '默认（自动）';

  @override
  String get settingsBrowserMixedContentTitle => '混合内容';

  @override
  String get settingsBrowserMixedContentDesc => '允许安全页面在内置浏览器中加载不安全的 http 资源';

  @override
  String get settingsBrowserMixedContentBlock => '阻止（默认）';

  @override
  String get settingsBrowserMixedContentAllow => '允许';

  @override
  String get settingsBrowserSearchEnginePrivacy => '隐私政策';

  @override
  String get settingsLaunchBrowserTitle => '启动应用内浏览器';

  @override
  String get settingsLaunchBrowserDesc => '打开内置浏览器页面，便于测试';

  @override
  String get browserImageMenuDownload => '下载图片';

  @override
  String get browserDownloading => '正在下载图片…';

  @override
  String get browserDownloadFailed => '图片下载失败';

  @override
  String get browserRendererGoneTitle => '页面崩溃';

  @override
  String get browserRendererGoneMessage => '网页渲染进程已崩溃。请重新加载页面或关闭该标签页。';

  @override
  String get browserCancelAlwaysExternalTitle => '取消始终外部打开？';

  @override
  String browserCancelAlwaysExternalMessage(Object domain) {
    return '$domain 的链接当前始终在外部浏览器打开，是否取消？';
  }

  @override
  String browserAlwaysExternalEnabled(Object domain) {
    return '已设置 $domain 的链接始终在外部浏览器打开';
  }

  @override
  String browserAlwaysExternalDisabled(Object domain) {
    return '已取消 $domain 的链接始终在外部浏览器打开';
  }

  @override
  String get lockTitle => 'TouchFish 已锁定';

  @override
  String get lockSubtitle => '输入主密码以解锁应用';

  @override
  String get lockPasswordLabel => '主密码';

  @override
  String get lockPasswordRequired => '请输入主密码';

  @override
  String get lockUnlock => '解锁';

  @override
  String get lockBiometricAction => '使用生物识别解锁';

  @override
  String get lockErrorInvalidPassword => '主密码错误';

  @override
  String get lockErrorBiometricUnavailable => '当前设备不支持生物识别';

  @override
  String get lockErrorBiometricCancelled => '生物识别验证已取消';

  @override
  String get lockErrorBiometricNotEnabled => '未启用生物识别解锁';

  @override
  String get lockErrorUnknown => '解锁失败，请重试';

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
  String get settingsLanguageCc => '文言（華夏）';

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
  String get settingsColorCustom => '自定义';

  @override
  String get settingsCardOpacityTitle => '卡片不透明度';

  @override
  String get settingsCardOpacityDesc => '调整卡片背景的不透明度';

  @override
  String get settingsWindowOpacityTitle => '窗口透明度';

  @override
  String get settingsWindowOpacityDesc => '调整应用窗口的透明度（仅桌面平台）';

  @override
  String get settingsBackgroundImageTitle => '背景图片';

  @override
  String get settingsBackgroundImageDesc => '选择应用的背景图片';

  @override
  String get settingsBackgroundImageSelect => '选择背景图片';

  @override
  String get settingsBackgroundImageClear => '清除背景图片';

  @override
  String get settingsBackgroundImageGenColor => '从背景生成主题色';

  @override
  String get settingsBackgroundImageGenColorDesc => '从背景图片提取主色调作为应用主题色';

  @override
  String get settingsBackgroundImageSelectSuccess => '已选择背景图片';

  @override
  String get settingsBackgroundImageClearSuccess => '已清除背景图片';

  @override
  String get settingsBackgroundImageGenColorSuccess => '已从背景图片提取主题色';

  @override
  String settingsBackgroundImageGenColorError(String error) {
    return '提取颜色失败: $error';
  }

  @override
  String get settingsCustomThemeTitle => '自定义主题颜色';

  @override
  String get settingsCustomThemeDesc => '自定义应用的各种主题颜色';

  @override
  String get settingsCustomThemeSeedColor => '种子颜色';

  @override
  String get settingsCustomThemePrimary => '主要颜色';

  @override
  String get settingsCustomThemeSecondary => '次要颜色';

  @override
  String get settingsCustomThemeTertiary => '第三颜色';

  @override
  String get settingsCustomThemeSurface => '表面颜色';

  @override
  String get settingsCustomThemeBackground => '背景颜色';

  @override
  String get settingsCustomThemeError => '错误颜色';

  @override
  String get settingsCustomThemeReset => '重置自定义颜色';

  @override
  String get settingsCustomThemeResetConfirm => '确定要重置所有自定义颜色吗？';

  @override
  String get settingsFontFamilyTitle => '字体';

  @override
  String get settingsFontFamilyDesc => '应用使用的字体';

  @override
  String get settingsFontHarmonyOS => 'HarmonyOS Sans SC (默认,推荐)';

  @override
  String get settingsFontSystem => '系统默认';

  @override
  String get settingsFontCustomOption => '自定义';

  @override
  String get settingsCustomFontTitle => '自定义字体';

  @override
  String get settingsCustomFontDesc => '输入要使用的系统字体名称';

  @override
  String get settingsCustomFontHint => '例如：LXGW WenKai Screen';

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
  String get settingsCloseToTrayTitle => '关闭时最小化到托盘';

  @override
  String get settingsCloseToTrayDesc => '关闭窗口时在后台继续运行，而不是退出应用（仅桌面平台）';

  @override
  String get trayShowApp => '打开 TouchFish';

  @override
  String get trayHideWindow => '隐藏窗口';

  @override
  String get trayQuit => '退出';

  @override
  String get trayLock => '锁定';

  @override
  String get trayTooltip => 'TouchFish 客户端';

  @override
  String get titleBarMinimize => '最小化';

  @override
  String get titleBarMaximize => '最大化';

  @override
  String get titleBarRestore => '还原';

  @override
  String get titleBarClose => '关闭';

  @override
  String get imageZoomIn => '放大';

  @override
  String get imageZoomOut => '缩小';

  @override
  String get imageRotateLeft => '向左旋转';

  @override
  String get imageRotateRight => '向右旋转';

  @override
  String get imageExif => '查看 EXIF 信息';

  @override
  String get announcementEdit => '编辑公告';

  @override
  String get announcementDelete => '删除公告';

  @override
  String get chatSelectPlaceholder => '选择一个聊天开始对话';

  @override
  String get settingsSystemNotificationsTitle => '系统通知';

  @override
  String get settingsSystemNotificationsDesc => '使用操作系统通知进行消息通知';

  @override
  String get settingsNotificationLevelTitle => '通知分级';

  @override
  String get settingsNotificationLevelDesc => '选择横幅通知的显示方式，通知列表不受影响';

  @override
  String get settingsNotificationLevelMinimal => '一级：仅汇总';

  @override
  String get settingsNotificationLevelPerSender => '二级：按联系人（默认）';

  @override
  String get settingsNotificationLevelFull => '三级：全部展示';

  @override
  String notificationLevelSummary(int contacts, int messages) {
    return '$contacts 个联系人发来 $messages 条消息';
  }

  @override
  String get notificationReplyAction => '回复';

  @override
  String get notificationReplyInputHint => '输入回复';

  @override
  String get notificationSummaryTitle => 'TouchFish 消息';

  @override
  String get notificationSummarySubtitle => '新聊天消息';

  @override
  String get notificationChannelName => 'TouchFish 通知';

  @override
  String get notificationChannelDesc => '来自 TouchFish 的消息与动态';

  @override
  String get notificationOpenAction => '打开通知';

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
  String get serverUseHttps => 'HTTPS';

  @override
  String get serverUseHttpsOn => '尝试加密连接（失败时回退 HTTP）';

  @override
  String get serverUseHttpsOff => '使用非加密连接';

  @override
  String get serverSave => '保存';

  @override
  String get serverTryWss => 'WSS';

  @override
  String get serverTryWssOn => '尝试加密 WebSocket（失败时回退 WS）';

  @override
  String get serverTryWssOff => '使用非加密 WebSocket';

  @override
  String get serverAutoDetectTcpPort => '自动检测TCP端口';

  @override
  String get serverAutoDetectTcpPortDesc => '自动从服务器获取TCP端口';

  @override
  String get navChat => '聊天';

  @override
  String get navAnnouncement => '公告';

  @override
  String get navForum => '论坛';

  @override
  String get navAccount => '账户';

  @override
  String get navAdmin => '管理员';

  @override
  String get adminTitle => '管理员';

  @override
  String get adminDescription => '管理 TouchFish 服务器';

  @override
  String get adminAccessDenied => '您当前没有管理员权限。';

  @override
  String get adminRootOnly => '只有 root 账户可以管理服务器配置。';

  @override
  String get adminDefaultAssets => '默认图片';

  @override
  String get adminDefaultAssetsDescription => '上传服务器使用的 logo 和默认头像图片。';

  @override
  String get adminDefaultAssetsLoadFailed => '加载默认图片失败';

  @override
  String get adminDefaultAssetChangeAction => '上传 PNG';

  @override
  String get adminDefaultAssetPngHint => '服务端只接受 PNG 文件。';

  @override
  String get adminDefaultAssetPreviewUnavailable => '预览不可用';

  @override
  String get adminDefaultAssetLogo => '服务器 Logo';

  @override
  String get adminDefaultAssetLogoDescription => '用于应用标题区域和服务器品牌展示。';

  @override
  String get adminDefaultAssetForum => '默认论坛图片';

  @override
  String get adminDefaultAssetForumDescription => '论坛没有自定义图片时使用。';

  @override
  String get adminDefaultAssetUser => '默认用户头像';

  @override
  String get adminDefaultAssetUserDescription => '用户未上传头像时使用。';

  @override
  String get adminDefaultAssetGroup => '默认群组头像';

  @override
  String get adminDefaultAssetGroupDescription => '群组没有自定义头像时使用。';

  @override
  String adminDefaultAssetUploadSuccess(String assetName) {
    return '已更新 $assetName。';
  }

  @override
  String adminDefaultAssetUploadFailed(String assetName) {
    return '更新 $assetName 失败。';
  }

  @override
  String get adminServerSettings => '服务器设置';

  @override
  String get adminServerSettingsDescription => '更新服务器名称、注册验证码以及关键限制项。';

  @override
  String get adminServerSettingsLoadFailed => '加载服务器设置失败';

  @override
  String get adminServerSettingsSaveSuccess => '服务器设置已更新';

  @override
  String get adminServerSettingsSaveFailed => '更新服务器设置失败';

  @override
  String get adminServerSettingsInvalidInput => '请检查服务器设置表单后重试。';

  @override
  String get adminServerSettingsCaptchaDescription => '注册时要求输入图片验证码。';

  @override
  String get adminServerReadOnlyDescription => '这些值由服务端返回，当前页面仅供查看。';

  @override
  String get adminServerFieldServerName => '服务器名称';

  @override
  String get adminServerFieldCaptcha => '注册验证码';

  @override
  String get adminServerFieldFileLastTime => '文件保留时长（小时）';

  @override
  String get adminServerFileLastTimeDescription => '必须大于或等于 0。';

  @override
  String get adminServerFieldGroupsLimit => '群组数量限制';

  @override
  String get adminServerFieldSingleGroupMaxPeople => '单群最大人数';

  @override
  String get adminServerFieldDefaultJoinTargets => '默认好友和群组';

  @override
  String get adminServerFieldDefaultJoinTargetsDescription =>
      '新用户会自动与 U 目标成为好友并加入 G 目标。多个值可用空格、逗号或换行分隔，例如：U1 U2 G1。';

  @override
  String get adminServerFieldMaxFileSize => '最大文件大小';

  @override
  String get adminServerFieldMaxMessageLength => '最大消息长度';

  @override
  String get adminServerFieldMaxMessageLengthDescription =>
      '每条消息的最大字符数（最小值为 1）。';

  @override
  String get adminServerSectionGeneral => '常规';

  @override
  String get adminServerSectionMessages => '消息';

  @override
  String get adminServerSectionFiles => '文件';

  @override
  String get adminServerSectionGroups => '群组';

  @override
  String get adminServerSectionStickers => '贴图';

  @override
  String get adminServerFieldMaxStickerPacks => '每用户贴图包上限';

  @override
  String get adminServerFieldMaxStickersPerPack => '每贴图包贴图上限';

  @override
  String get adminServerFieldMaxStickerSize => '贴图最大大小（字节，-1 不限）';

  @override
  String get adminServerFieldDailyStickerPackLimit => '每日创建贴图包上限';

  @override
  String get adminServerFieldApiPort => 'API 端口';

  @override
  String get adminServerFieldTcpPort => 'TCP 端口';

  @override
  String get adminServerFieldEmailActivation => '邮箱激活';

  @override
  String get adminServerFieldVerifyEmail => '验证邮箱';

  @override
  String get adminServerUnlimitedHint => '输入 -1 表示不限制。';

  @override
  String get adminServerSectionAdvanced => '高级配置';

  @override
  String get adminServerSectionEmailService => '邮箱验证服务';

  @override
  String get adminServerEmailDescription => '开启后，新用户注册需要填写邮箱并通过验证码激活账号。';

  @override
  String get adminServerEmailEnableDescription => '注册时向用户邮箱发送验证码。';

  @override
  String get adminServerFieldSmtpHost => 'SMTP 服务器地址';

  @override
  String get adminServerSmtpHostDescription => '留空时按邮箱域名自动检测。';

  @override
  String get adminServerFieldSmtpPort => 'SMTP 端口';

  @override
  String get adminServerFieldSmtpUseSsl => '使用 SSL 直连';

  @override
  String get adminServerSmtpUseSslDescription =>
      '开启为 SSL 直连（默认 465），关闭为 STARTTLS（默认 587）。';

  @override
  String get adminServerFieldEmailPassword => '邮箱密码或授权码';

  @override
  String get adminServerSectionReverseProxy => '反向代理';

  @override
  String get adminServerReverseProxyDescription =>
      '服务器运行在 Nginx 等反向代理后方时开启，以正确识别客户端 IP 和 HTTPS。';

  @override
  String get adminServerFieldReverseProxy => '启用反向代理';

  @override
  String get adminServerFieldProxyCount => '信任的代理层数';

  @override
  String get adminServerSectionAuth => '认证';

  @override
  String get adminServerAuthDescription => '控制客户端登录认证方式。';

  @override
  String get adminServerFieldLegacyAuth => '允许旧版 UID+PASSWORD 登录';

  @override
  String get adminServerLegacyAuthDescription => '关闭后仅接受 JWT 认证，旧版客户端将无法登录。';

  @override
  String get adminServerFieldJwtExpires => 'JWT 有效期（秒）';

  @override
  String get adminServerJwtExpiresDescription => '默认 604800（7 天），最小 60。';

  @override
  String get adminServerFieldJwtMaxPerUser => '每用户最大 Token 数';

  @override
  String get adminServerJwtMaxPerUserDescription => '0 或 -1 表示不限制。';

  @override
  String get adminServerEmailPasswordRequired => '启用邮箱验证需要填写验证邮箱和邮箱密码。';

  @override
  String get adminPendingForums => '待审论坛';

  @override
  String get adminPendingForumsDescription => '审核新创建的论坛并决定是否通过。';

  @override
  String get adminPendingForumsEmpty => '当前没有待审批的论坛。';

  @override
  String get adminPendingForumsLoadFailed => '加载待审论坛失败';

  @override
  String adminPendingForumQueueId(int queueId) {
    return '队列 #$queueId';
  }

  @override
  String adminPendingForumCreator(String uid) {
    return '创建者 UID：$uid';
  }

  @override
  String get adminPendingForumNoIntroduction => '暂无论坛简介。';

  @override
  String get adminApproveForumAction => '通过论坛';

  @override
  String get adminApproveForumConfirmTitle => '通过论坛审核';

  @override
  String adminApproveForumConfirmMessage(String forumName) {
    return '确认将“$forumName”通过审核并发布到论坛列表吗？';
  }

  @override
  String adminApproveForumSuccess(String forumName) {
    return '已通过“$forumName”的审核。';
  }

  @override
  String get adminApproveForumFailed => '论坛审核通过失败。';

  @override
  String get adminRejectForumAction => '拒绝论坛';

  @override
  String get adminRejectForumConfirmTitle => '拒绝论坛审核';

  @override
  String adminRejectForumConfirmMessage(String forumName) {
    return '确认拒绝“$forumName”的论坛创建申请吗？';
  }

  @override
  String adminRejectForumSuccess(String forumName) {
    return '已拒绝“$forumName”的创建申请。';
  }

  @override
  String get adminRejectForumFailed => '论坛审核拒绝失败。';

  @override
  String get account => '账户';

  @override
  String get accountUnauthorized => '未登录';

  @override
  String get accountLogin => '登录';

  @override
  String get accountCreateAccount => '创建账户';

  @override
  String get accountCreateAccountDescription => '注册一个新账户';

  @override
  String get accountLoginDescription => '登录到您的账户';

  @override
  String get accountNotifications => '通知';

  @override
  String get accountSettings => '设置';

  @override
  String get accountEditProfile => '编辑资料';

  @override
  String get accountProfile => '个人资料';

  @override
  String get accountAbout => '关于';

  @override
  String get accountDebugOptions => '调试选项';

  @override
  String get accountLogout => '退出登录';

  @override
  String get accountLogoutConfirm => '确定要退出登录吗？';

  @override
  String get accountDescriptionNone => '暂无签名';

  @override
  String get accountSignature => '个性签名';

  @override
  String get accountEditSignature => '编辑签名';

  @override
  String get accountCreateSignature => '创建签名';

  @override
  String get accountUpdateSignature => '更新签名';

  @override
  String get accountSignaturePlaceholder => '输入您的个性签名...';

  @override
  String get accountAppSettings => '应用设置';

  @override
  String get accountSessionDevices => '设备管理';

  @override
  String get accountLockNow => '立即锁定';

  @override
  String get accountUpdateYourProfile => '编辑个人资料';

  @override
  String get profileEditTitle => '编辑资料';

  @override
  String get profileEditAvatar => '头像';

  @override
  String get profileEditBasicInfo => '基本信息';

  @override
  String get profileEditUsername => '用户名';

  @override
  String get profileEditEmail => '邮箱';

  @override
  String get profileEditBio => '个性签名';

  @override
  String get profileEditBioPlaceholder => '介绍一下自己...';

  @override
  String get profileEditIntroduction => '个人简介';

  @override
  String get profileEditIntroductionPlaceholder => '写一段关于你自己的介绍...';

  @override
  String get profileEditSaveChanges => '保存更改';

  @override
  String get profileEditChangeAvatar => '更改头像';

  @override
  String get profileEditRemoveAvatar => '移除头像';

  @override
  String get profileEditUpdated => '资料已更新';

  @override
  String get profileEditSaveFailed => '部分修改保存失败';

  @override
  String get profileEditUsernameCannotChange => '用户名不可更改';

  @override
  String get chatTabMessages => '聊天';

  @override
  String get chatTabContacts => '联系人';

  @override
  String get chatInvites => '邀请';

  @override
  String get chatNoInvites => '没有邀请';

  @override
  String get chatInviteAccept => '接受';

  @override
  String get chatInviteReject => '拒绝';

  @override
  String get notificationTitle => '通知';

  @override
  String get notificationEmpty => '暂无通知';

  @override
  String get notificationClearAll => '清除全部';

  @override
  String get notificationTabAnnouncements => '公告';

  @override
  String get notificationTabNotifications => '通知';

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
  String get chatBackToBottom => '回到底部';

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
  String get chatListExpand => '展开';

  @override
  String get chatListCollapse => '折叠';

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
  String get connectionBannerConnecting => '正在连接';

  @override
  String get connectionBannerDisconnected => '已断开';

  @override
  String get connectionBannerConnected => '已连接';

  @override
  String get connectionBannerTapToRetry => '点击重试';

  @override
  String get messageActions => '消息操作';

  @override
  String get messageActionReply => '回复';

  @override
  String get messageActionForward => '转发';

  @override
  String get messageActionDelete => '删除';

  @override
  String get messageActionRecall => '撤回';

  @override
  String get messageActionCopy => '复制';

  @override
  String get messageActionPin => '置顶';

  @override
  String get messageActionUnpin => '取消置顶';

  @override
  String get pinnedMessageLabel => '已置顶';

  @override
  String get pinnedMessagesTitle => '置顶消息';

  @override
  String get noPinnedMessages => '暂无置顶消息';

  @override
  String get viewAllPinned => '查看全部';

  @override
  String pinnedMessageCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条置顶消息',
    );
    return '$_temp0';
  }

  @override
  String essenceLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条精华消息',
    );
    return '$_temp0';
  }

  @override
  String get essenceName => '精华';

  @override
  String get essenceAdd => '设为精华';

  @override
  String get essenceRemove => '移除精华';

  @override
  String get messageRecallConfirmTitle => '撤回消息？';

  @override
  String get messageRecallConfirmBody => '消息内容将对所有人移除，且无法恢复。';

  @override
  String get messageRecallFailed => '消息撤回失败';

  @override
  String get messageRecalled => '消息已撤回';

  @override
  String get messageQuoteRecalled => '已撤回的消息';

  @override
  String get messageQuoteMissing => '原消息不可用';

  @override
  String messageReplyingTo(String name) {
    return '回复 $name';
  }

  @override
  String get messageReplyDismiss => '取消回复';

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
  String get confirm => '确认';

  @override
  String get clear => '清除';

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
  String get filePreview => '预览';

  @override
  String get filePreviewFailed => '无法预览文件';

  @override
  String get fileDownload => '下载';

  @override
  String get fileDownloading => '正在下载...';

  @override
  String get fileDownloadStarted => '已开始下载';

  @override
  String fileDownloadSaved(String path) {
    return '已保存到 $path';
  }

  @override
  String get fileDownloadFailed => '下载失败';

  @override
  String get forumAttachments => '附件';

  @override
  String get forumAttachmentRemove => '移除附件';

  @override
  String get forumAttachmentFailed => '附件上传失败';

  @override
  String get settingsAutomaticPreviewTitle => '自动预览文件';

  @override
  String get settingsAutomaticPreviewDesc => '自动预览不超过所选大小的受支持文件';

  @override
  String get settingsAutomaticPreviewDisabled => '关闭';

  @override
  String settingsAutomaticPreviewSize(int size) {
    return '$size MiB';
  }

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
  String get aboutTitle => '关于';

  @override
  String aboutVersionInfo(String version, String buildNumber) {
    return '版本 $version ($buildNumber)';
  }

  @override
  String get aboutAppInfoSection => '应用信息';

  @override
  String get aboutPackageName => '包名';

  @override
  String get aboutVersion => '版本';

  @override
  String get aboutBuildNumber => '构建号';

  @override
  String get aboutLinksSection => '链接';

  @override
  String get aboutDocumentation => '文档';

  @override
  String get aboutServerRepository => '后端服务器';

  @override
  String get aboutFontLicense => '字体许可';

  @override
  String get aboutFontLicenseDialogTitle => '字体许可';

  @override
  String get aboutFontLicenseDescription =>
      '本应用使用 HarmonyOS Sans SC 与 LXGW WenKai 字体，由华为终端有限公司根据 HarmonyOS Sans Fonts License Agreement 提供和 LXGW 根据 SIL Open Font License 1.1 提供。这些字体的使用遵循各自的许可证协议。';

  @override
  String get aboutFontLicenseFullText => '完整许可证文本';

  @override
  String get aboutFontLicenseClose => '关闭';

  @override
  String get aboutOpenSourceLicenses => '开源许可证';

  @override
  String get aboutDeveloperSection => '开发者信息';

  @override
  String get aboutContactUs => '联系作者';

  @override
  String get aboutSourceCode => '源代码';

  @override
  String get aboutLicense => '许可证';

  @override
  String get aboutLicenseContent => '本项目基于 AGPLv3 许可证开源';

  @override
  String get aboutLicenseDialogTitle => '软件许可证';

  @override
  String get aboutLicenseDescription =>
      'TouchFish Client 是 Copyleft 的自由软件：您可以随时使用、研究、共享和改进它。您可以根据自由软件基金会发布的 GNU Affero 通用公共许可证 3.0 (AGPLv3) 重新分发或修改。';

  @override
  String get aboutLicenseFullText => '完整许可证文本';

  @override
  String get aboutLicenseClose => '关闭';

  @override
  String aboutCopyright(String year) {
    return '© $year ILoveScratch2。保留所有权利。';
  }

  @override
  String get aboutMadeWith => 'By ILoveScratch2 & TouchFish Dev Team';

  @override
  String get aboutCopiedToClipboard => '已复制到剪贴板';

  @override
  String get aboutCopyToClipboard => '复制到剪贴板';

  @override
  String get aboutEasterEggFound => '恭喜你发现了彩蛋！';

  @override
  String get aboutEasterEggMessage0 => '这是一个彩蛋！';

  @override
  String get aboutEasterEggMessage1 => 'TouchFish v5！重新设计，焕然一新！';

  @override
  String get aboutEasterEggMessage2 => 'TouchFish 的作者是 XSFX！';

  @override
  String get aboutEasterEggMessage3 => 'TouchFish 不是让你摸鱼！';

  @override
  String get aboutEasterEggMessage4 => 'TouchFish Client 是自由且开源的！';

  @override
  String get aboutEasterEggMessage5 => '感谢你对 TouchFish 的支持！';

  @override
  String get aboutEasterEggMessage6 => '你好中国！';

  @override
  String get aboutEasterEggMessage7 => 'TouchFish，启动！';

  @override
  String get aboutEasterEggMessage8 => '摸鱼快乐！';

  @override
  String get aboutEasterEggMessage9 =>
      'TouchFish Client 支持Windows、macOS、Linux 以及 Android！';

  @override
  String get aboutEasterEggMessage10 =>
      'TouchFish 由：细数繁星、035966_L3、Piaoztsdy、JohnChiao75 和其他许多贡献者开发！';

  @override
  String get aboutEasterEggMessage11 =>
      '台湾及其附属岛屿自古以来就是中国不可分割的神圣领土，坚持一个中国原则不动摇是最基本的。任何外部势力以及反动分子最终只会被历史唾弃。台湾回归是不可逆转，不可停止的历史进程。任何企图分裂国家的行为都是对中华民族根本利益和全体中国人民共同意志的严重挑战。我们坚决维护国家主权和领土完整，坚持一个中国原则，反对任何形式的“台独”分裂图谋。';

  @override
  String get aboutEasterEggMessage12 =>
      'TouchFish Client 使用 AGPLv3 许可证开源，TouchFish 服务器使用 MIT 许可证开源，欢迎 Contribute！';

  @override
  String get aboutEasterEggMessage13 => 'TouchFish v5加入了论坛、公告、多聊天会话等新功能！';

  @override
  String get aboutEasterEggMessage14 => '龙踏祥云传讯去，骏马奔驰 TouchFish 来';

  @override
  String get aboutEasterEggMessage15 =>
      'TouchFish 的官方服务器地址是 touchfish.xin，欢迎访问！';

  @override
  String get aboutEasterEggMessage16 => 'TouchFish 将信息传递到每一个角落！';

  @override
  String get aboutEasterEggMessage17 => '是时候摸鱼了！';

  @override
  String get aboutEasterEggMessage18 => '摸鱼摸到 TouchFish！';

  @override
  String get aboutEasterEggMessage19 => '你这么能点吗？？';

  @override
  String get aboutEasterEggLevel => 'TouchFisher 等级';

  @override
  String aboutEasterEggProgress(int nextLevel, int remaining) {
    return '距离 Lv.$nextLevel: $remaining次';
  }

  @override
  String get aboutEasterEggCompleted => '恭喜通关！你已达到最高等级！';

  @override
  String get aboutEasterEggLevelName0 => '其实这是个永远不会显示的等级，你发现了吗？恭喜你！';

  @override
  String get aboutEasterEggLevelName1 => 'TouchFish v1';

  @override
  String get aboutEasterEggLevelName2 => 'TouchFish v3';

  @override
  String get aboutEasterEggLevelName3 => 'TouchFish v4';

  @override
  String get aboutEasterEggLevelName4 => 'TouchFish LTS';

  @override
  String get aboutEasterEggLevelName5 => 'TouchFish Plus';

  @override
  String get aboutEasterEggLevelName6 => 'TouchFish Pro';

  @override
  String get aboutEasterEggLevelName7 => 'TouchFish More';

  @override
  String get aboutEasterEggLevelName8 => 'TouchFish UI Remake';

  @override
  String get aboutEasterEggLevelName9 => 'TouchFish Astra';

  @override
  String get aboutEasterEggLevelName10 => 'TouchFish v5';

  @override
  String get aboutEasterEggLevelName11 => 'TouchFish Client';

  @override
  String get aboutEasterEggLevelName12 => 'TouchFish UI Remake 2';

  @override
  String get aboutEasterEggLevelName13 => 'TouchFish CLI';

  @override
  String get aboutEasterEggLevelName14 => 'Xi Shu Fan Xing';

  @override
  String get aboutEasterEggLevelName15 => 'TouchFisher!';

  @override
  String get aboutEasterEggReset => '清除进度';

  @override
  String get aboutEasterEggResetConfirmTitle => '确认清除进度';

  @override
  String get aboutEasterEggResetConfirmMessage => '确定要清除所有彩蛋进度吗？这将重置你的等级和点击次数。';

  @override
  String get aboutEasterEggResetSuccess => '进度已清除';

  @override
  String get aboutEasterEggResetCancel => '取消';

  @override
  String get aboutEasterEggResetConfirm => '确认清除';

  @override
  String get licensesTitle => '开源许可证';

  @override
  String get licensesSearchHint => '搜索包...';

  @override
  String licensesPackageCount(int count) {
    return '$count 个包';
  }

  @override
  String get licensesNoResults => '未找到包';

  @override
  String get licensesVersion => '版本';

  @override
  String get licensesDescription => '描述';

  @override
  String get licensesLicenseType => '许可证类型';

  @override
  String get licensesLinks => '链接';

  @override
  String get licensesHomepage => '主页';

  @override
  String get licensesRepository => '仓库';

  @override
  String get licensesLicenseText => '许可证文本';

  @override
  String get licensesLicenseCopied => '许可证文本已复制到剪贴板';

  @override
  String get markdownCopyCode => '复制代码';

  @override
  String get markdownCodeCopied => '代码已复制到剪贴板';

  @override
  String get markdownSpoilerHidden => '已隐藏';

  @override
  String get settingsCorruptedResetNotice => '本地设置似乎损坏，已重置';

  @override
  String get debugLogs => '调试日志';

  @override
  String get debugLogsDescription => '查看应用运行日志';

  @override
  String get debugNotificationTester => '通知测试';

  @override
  String get debugNotificationTesterDescription => '触发各种应用内通知和系统通知';

  @override
  String get debugNotificationTypePrivateMessage => '私聊消息';

  @override
  String get debugNotificationTypeGroupMessage => '群聊消息';

  @override
  String get debugNotificationTypeAnnouncement => '公告通知';

  @override
  String get debugNotificationTypeForum => '论坛通知';

  @override
  String get debugNotificationTypeInvite => '邀请通知';

  @override
  String get debugNotificationTypeGeneral => '通用通知';

  @override
  String get debugNotificationTestBody => '这是一条用于验证通知显示、队列和点击路由的测试通知。';

  @override
  String get debugNotificationTestInApp => '触发应用内通知';

  @override
  String get debugNotificationTestSystem => '触发系统通知';

  @override
  String get debugNotificationSystemUnavailable => '系统通知尚未初始化或当前平台不支持。';

  @override
  String get debugClearMessageDatabase => '清空消息数据库';

  @override
  String get debugClearMessageDatabaseDescription => '删除此客户端本地缓存的所有消息。';

  @override
  String get debugClearMessageDatabaseConfirmTitle => '清空消息数据库？';

  @override
  String get debugClearMessageDatabaseConfirmMessage =>
      '所有本地缓存的消息都会被删除，服务器上的消息不受影响。';

  @override
  String get debugClearMessageDatabaseSuccess => '消息数据库已清空。';

  @override
  String get debugCustomInfoDialog => '自定义信息框';

  @override
  String get debugCustomInfoDialogDescription => '预览支持调用方自定义按钮的可复用信息框';

  @override
  String get debugCustomErrorDialog => '自定义错误框';

  @override
  String get debugCustomErrorDialogDescription => '预览支持调用方自定义按钮的可复用错误框';

  @override
  String get debugInfoDialogDemoTitle => '服务器配置已更新';

  @override
  String get debugInfoDialogDemoMessage => '检测到新的服务器配置，请选择下一步操作。';

  @override
  String get debugErrorDialogDemoTitle => '消息同步失败';

  @override
  String get debugErrorDialogDemoMessage => '当前同步任务未成功完成，你可以立即重试，或打开设置检查连接状态。';

  @override
  String debugDialogSelectedAction(String action) {
    return '已选择操作：$action';
  }

  @override
  String get debugMarkdownTester => 'Markdown 测试';

  @override
  String get debugMarkdownTesterDescription => '输入 Markdown 并实时预览渲染结果';

  @override
  String get debugMarkdownTesterEditorTitle => 'Markdown 输入';

  @override
  String get debugMarkdownTesterHint => '在这里输入 Markdown';

  @override
  String get debugMarkdownTesterPreviewTitle => '渲染预览';

  @override
  String get debugMarkdownTesterPreviewDescription =>
      '预览会随着 Markdown 内容变更实时更新。';

  @override
  String get debugMarkdownTesterEmptyPreview => '渲染结果会显示在这里。';

  @override
  String get debugApiTester => 'API 测试';

  @override
  String get debugApiTesterDescription => '直接向服务器发送 API 请求，查看请求和响应的详细信息。';

  @override
  String get debugApiTesterEndpoint => '端点';

  @override
  String get debugApiTesterEndpointHint => '例如：/auth/login';

  @override
  String get debugApiTesterMethod => '请求方法';

  @override
  String get debugApiTesterMethodGet => 'GET';

  @override
  String get debugApiTesterMethodPost => 'POST';

  @override
  String get debugApiTesterUseCredentials => '附带当前登录凭据';

  @override
  String get debugApiTesterUseCredentialsDescription =>
      '会把当前 uid 和 password 追加到本次提交的参数中。';

  @override
  String get debugApiTesterNoCredentials => '当前没有可用的登录凭据。';

  @override
  String get debugApiTesterUseToken => '携带 JWT Token';

  @override
  String get debugApiTesterUseTokenDescription =>
      'JWT 会话中自动携带 token；关闭后可用于测试登录等免认证请求。';

  @override
  String get debugApiTesterUseTokenUnavailable => '仅在 JWT 会话中可用。';

  @override
  String get debugApiTesterEncryptRequest => '加密请求体';

  @override
  String get debugApiTesterEncryptRequestDescription =>
      '开启后，POST 请求会使用 TouchFish 的加密载荷格式发送。';

  @override
  String get debugApiTesterEncryptRequestUnavailableForGet => 'GET 请求不会启用加密。';

  @override
  String get debugApiTesterQueryParameters => '查询参数';

  @override
  String get debugApiTesterQueryParametersHint => '请输入作为 GET 查询参数的 JSON 对象';

  @override
  String get debugApiTesterRequestBody => '请求体';

  @override
  String get debugApiTesterRequestBodyHint => '请输入作为 POST 请求体的 JSON 对象';

  @override
  String get debugApiTesterSendRequest => '发送请求';

  @override
  String get debugApiTesterResultTitle => '返回结果';

  @override
  String get debugApiTesterResultDescription => '查看本次提交的参数以及服务器返回。';

  @override
  String get debugApiTesterAwaitingResult => '发送请求后，这里会显示提交参数和返回值。';

  @override
  String get debugApiTesterStatus => '状态';

  @override
  String get debugApiTesterStatusUnavailable => '不可用';

  @override
  String get debugApiTesterRequestUrl => '请求地址';

  @override
  String get debugApiTesterRequestPayload => '请求载荷';

  @override
  String get debugApiTesterEncodedBody => '编码后的请求体';

  @override
  String get debugApiTesterDecryptedResponse => '解密后的返回值';

  @override
  String get debugApiTesterRawResponse => '原始返回值';

  @override
  String get debugApiTesterError => '错误信息';

  @override
  String get debugApiTesterInvalidEndpoint => '请输入端点。';

  @override
  String get debugApiTesterInvalidBody => '请求体必须是 JSON 对象。';

  @override
  String get debugApiTesterCredentialsUnavailable => '未找到当前登录凭据。';

  @override
  String get forumTitle => '论坛';

  @override
  String get forumNotFound => '论坛未找到';

  @override
  String get forumDescription => '简介';

  @override
  String get forumJoin => '加入论坛';

  @override
  String get forumJoinSuccess => '成功加入论坛';

  @override
  String get forumLeave => '退出论坛';

  @override
  String get forumLeaveHint => '确定要退出此论坛吗？退出后将无法访问论坛内容。';

  @override
  String get forumEdit => '编辑论坛';

  @override
  String get forumDelete => '删除论坛';

  @override
  String get forumDeleteHint => '确定要删除此论坛吗？这将同时删除该论坛下的所有帖子。';

  @override
  String get forumPinnedPosts => '置顶帖子';

  @override
  String get forumNoPosts => '暂无帖子';

  @override
  String get forumPostDetail => '帖子详情';

  @override
  String get forumPostNotFound => '帖子未找到';

  @override
  String get forumReply => '回复';

  @override
  String forumReplies(int count) {
    return '$count 条回复';
  }

  @override
  String forumComments(int count) {
    return '$count 条评论';
  }

  @override
  String get forumNoComments => '暂无评论';

  @override
  String get forumCommentPlaceholder => '写下你的评论…';

  @override
  String get forumCommentSuccess => '评论发布成功';

  @override
  String get forumShare => '分享';

  @override
  String get forumPublish => '发布';

  @override
  String get forumComposePost => '发帖';

  @override
  String get forumComposeReply => '回复帖子';

  @override
  String get forumPostTitle => '标题';

  @override
  String get forumPostTitleRequired => '请输入标题';

  @override
  String get forumPostContent => '内容';

  @override
  String get forumPostContentRequired => '请输入内容';

  @override
  String get forumPostContentMarkdown => '支持 Markdown 格式';

  @override
  String get forumPostSuccess => '帖子发布成功';

  @override
  String get forumReplySuccess => '回复发布成功';

  @override
  String forumMembersCount(int count) {
    return '$count 位成员';
  }

  @override
  String get forumInviteMember => '邀请成员';

  @override
  String get forumRemoveMember => '移除成员';

  @override
  String get forumRemoveMemberHint => '确定要移除此成员吗？';

  @override
  String forumMemberRoleEdit(String name) {
    return '编辑 $name 的角色';
  }

  @override
  String get forumMemberRole => '角色';

  @override
  String get forumMemberRoleHint => '0=成员, 50=管理员, 100=所有者';

  @override
  String get forumRoleOwner => '所有者';

  @override
  String get forumRoleAdmin => '管理员';

  @override
  String get forumRoleMember => '成员';

  @override
  String get forumTabJoined => '我加入的';

  @override
  String get forumTabExplore => '探索';

  @override
  String get forumNoJoined => '你还没有加入任何论坛';

  @override
  String get forumPostDescription => '描述（可选）';

  @override
  String get forumComposeAttachImage => '添加图片';

  @override
  String get forumComposeAttachFile => '添加附件';

  @override
  String get forumCopyLink => '复制链接';

  @override
  String get forumCommentSend => '发送';

  @override
  String get forumExpandEditor => '展开编辑器';

  @override
  String get forumMdBold => '加粗';

  @override
  String get forumMdItalic => '斜体';

  @override
  String get forumMdStrikethrough => '删除线';

  @override
  String get forumMdHeading => '标题';

  @override
  String get forumMdList => '列表';

  @override
  String get forumMdQuote => '引用';

  @override
  String get forumMdCode => '代码';

  @override
  String get forumMdLink => '链接';

  @override
  String get forumCreateTitle => '创建论坛';

  @override
  String get forumCreateTitleHint => '论坛名称';

  @override
  String get forumCreateDescriptionHint => '简介（可选）';

  @override
  String get forumCreateSuccess => '论坛已提交审核';

  @override
  String get forumCreateFailed => '创建论坛失败';

  @override
  String get forumPinPost => '置顶帖子';

  @override
  String get forumUnpinPost => '取消置顶';

  @override
  String get forumDeleteSuccess => '论坛已删除';

  @override
  String get forumDeleteFailed => '删除论坛失败';

  @override
  String get forumPostDelete => '删除帖子';

  @override
  String get forumPostDeleteHint => '确定要删除此帖子吗？相关评论也会被删除。';

  @override
  String get forumPostDeleteSuccess => '帖子已删除';

  @override
  String get forumPostDeleteFailed => '删除帖子失败';

  @override
  String get forumCommentDelete => '删除评论';

  @override
  String get forumCommentDeleteHint => '确定要删除此评论吗？';

  @override
  String get forumCommentDeleteSuccess => '评论已删除';

  @override
  String get forumCommentDeleteFailed => '删除评论失败';

  @override
  String get announcementTitle => '公告';

  @override
  String get announcementNoAnnouncements => '暂无公告';

  @override
  String get announcementCreate => '新建公告';

  @override
  String get announcementCreateHint => '输入公告内容...';

  @override
  String get announcementCreateEmpty => '内容不能为空';

  @override
  String get announcementCreateSuccess => '公告已发布';

  @override
  String get announcementCreateFailed => '发布公告失败';

  @override
  String get announcementEditHint => '编辑公告内容...';

  @override
  String get announcementEditSuccess => '公告已更新';

  @override
  String get announcementEditFailed => '更新公告失败';

  @override
  String get announcementEditEmpty => '内容不能为空';

  @override
  String get announcementDeleteConfirm => '确认删除此公告？';

  @override
  String get announcementDeleteSuccess => '公告已删除';

  @override
  String get announcementDeleteFailed => '删除公告失败';

  @override
  String get adminAnnouncements => '公告管理';

  @override
  String get adminAnnouncementsDescription => '创建和管理系统公告';

  @override
  String get adminAccountManagement => '账户管理';

  @override
  String get adminAccountManagementDescription => '查看和管理用户账户';

  @override
  String get adminAccountSearch => '搜索用户名、邮箱或 UID';

  @override
  String get adminAccountCreate => '创建账户';

  @override
  String get adminAccountCreateDescription => '由管理员直接创建服务器账户';

  @override
  String get adminAccountUsername => '用户名';

  @override
  String get adminAccountPassword => '密码';

  @override
  String get adminAccountConfirmPassword => '确认密码';

  @override
  String get adminAccountEmail => '邮箱（可选）';

  @override
  String get adminAccountRole => '账户角色';

  @override
  String get adminAccountSign => '个性签名（可选）';

  @override
  String get adminAccountIntroduction => '个人介绍（可选）';

  @override
  String get adminAccountRequired => '此项不能为空';

  @override
  String get adminAccountPasswordMismatch => '两次输入的密码不一致';

  @override
  String get adminAccountCreateSuccess => '账户已创建';

  @override
  String get adminAccountCreateFailed => '创建账户失败，请检查用户名是否已存在或当前账户权限';

  @override
  String get adminAccountLoadFailed => '加载用户列表失败';

  @override
  String get adminAccountEmpty => '暂无用户';

  @override
  String adminAccountCreated(String date) {
    return '创建时间：$date';
  }

  @override
  String get adminAccountChangeRole => '更改角色';

  @override
  String get adminAccountViewDevices => '查看设备';

  @override
  String adminAccountChangeRoleTitle(String name) {
    return '更改 $name 的角色';
  }

  @override
  String get adminAccountCurrentRole => '当前角色';

  @override
  String get adminAccountRoleRoot => 'Root';

  @override
  String get adminAccountRoleAdmin => '管理员';

  @override
  String get adminAccountRoleUser => '用户';

  @override
  String get adminAccountRoleBanned => '已封禁';

  @override
  String get adminAccountRoleChangeFailed => '更改角色失败';

  @override
  String adminAccountRoleChangeSuccess(String name, String role) {
    return '$name 的角色已更改为 $role';
  }

  @override
  String get adminAccountBanTitle => '封禁用户';

  @override
  String get adminAccountBanAction => '封禁';

  @override
  String adminAccountBanConfirm(String name) {
    return '确认封禁 $name？该用户将无法登录。';
  }

  @override
  String adminAccountBanSuccess(String name) {
    return '$name 已被封禁';
  }

  @override
  String get adminAccountBanFailed => '封禁用户失败';

  @override
  String get adminAccountUnbanTitle => '解封用户';

  @override
  String get adminAccountUnbanAction => '解封';

  @override
  String adminAccountUnbanConfirm(String name) {
    return '确认解封 $name？';
  }

  @override
  String adminAccountUnbanSuccess(String name) {
    return '$name 已解封';
  }

  @override
  String get adminAccountUnbanFailed => '解封用户失败';

  @override
  String get adminAccountDeleteTitle => '删除用户';

  @override
  String get adminAccountDeleteAction => '删除';

  @override
  String adminAccountDeleteConfirm(String name) {
    return '永久删除 $name？此操作不可撤销。';
  }

  @override
  String adminAccountDeleteSuccess(String name) {
    return '$name 已被删除';
  }

  @override
  String get adminAccountDeleteFailed => '删除用户失败';

  @override
  String get adminAccountTotalUsers => '位用户';

  @override
  String get storageTitle => '存储管理';

  @override
  String get storageUploadFile => '上传文件';

  @override
  String get storageRefresh => '刷新';

  @override
  String get storageNotLoggedIn => '未登录';

  @override
  String get storageNoFiles => '暂无文件';

  @override
  String get storageDeleteFile => '删除文件';

  @override
  String storageDeleteConfirm(String fileName) {
    return '确定删除 \"$fileName\"？此操作不可撤销。';
  }

  @override
  String storageDeleted(String fileName) {
    return '已删除：$fileName';
  }

  @override
  String get storageDeleteFailed => '删除失败';

  @override
  String storageUploaded(String fileName) {
    return '已上传：$fileName';
  }

  @override
  String get storageUploadFailed => '上传失败';

  @override
  String get storageUploadError => '上传错误';

  @override
  String get storageCouldNotReadFile => '无法读取文件';

  @override
  String storageFileTooLarge(int size) {
    return '文件过大，最大支持 $size MB';
  }

  @override
  String get storageUsed => '已用';

  @override
  String get storageUnlimited => '无限制';

  @override
  String get storageRetry => '重试';

  @override
  String get adminFileManagement => '文件管理';

  @override
  String get adminFileManagementDescription => '查看所有上传文件，按用户筛选，强制删除文件。';

  @override
  String get adminFileFilterUid => '按用户ID筛选...';

  @override
  String get adminFileFilter => '筛选';

  @override
  String get adminFileFilterClear => '清除';

  @override
  String get adminFileForceDelete => '强制删除';

  @override
  String get adminFileForceDeleteTitle => '强制删除文件';

  @override
  String adminFileForceDeleteConfirm(String fileName, String owner) {
    return '永久删除 \"$fileName\"（所有者：$owner）？\n\n此操作将从磁盘和数据库中移除该文件，忽略所有引用。';
  }

  @override
  String adminFileForceDeleted(String fileName) {
    return '已强制删除：$fileName';
  }

  @override
  String get adminFileForceDeleteFailed => '强制删除失败';

  @override
  String get adminFileNoFiles => '服务器上暂无文件';

  @override
  String adminFileNoFilesForUid(String uid) {
    return '未找到 UID $uid 的文件';
  }

  @override
  String get adminFileSummaryFiles => '文件';

  @override
  String get adminFileSummaryUsers => '用户';

  @override
  String get adminFileSummaryTotal => '总计';

  @override
  String get chatFunctionTabFiles => '文件';

  @override
  String get chatFunctionTabEmoji => '表情';

  @override
  String get chatFunctionTabSpecial => '特别消息';

  @override
  String get chatFunctionTabFilesHint => '选择要发送的文件';

  @override
  String get chatFunctionTabEmojiHint => '表情选择器即将推出';

  @override
  String get chatFunctionTabSpecialHint => '特别消息即将推出';

  @override
  String get chatFunctionPickFile => '选择文件';

  @override
  String get chatInputPickServerFile => '从服务器选择';

  @override
  String get chatSyncHistory => '正在同步聊天记录...';

  @override
  String chatSyncHistoryProgress(int count, int round) {
    return '正在同步历史消息：第 $round 轮，共 $count 条';
  }

  @override
  String chatSyncComplete(int count) {
    return '同步完成：共 $count 条消息';
  }

  @override
  String get serverFilePickerSearch => '搜索文件...';

  @override
  String get serverFilePickerEmpty => '还没有上传过的文件';

  @override
  String get serverFilePickerNoMatch => '没有匹配的文件';

  @override
  String get serverFilePickerError => '加载文件失败';

  @override
  String get chatSendFailed => '发送失败';

  @override
  String get chatCreateGroup => '创建群组';

  @override
  String get chatAddFriend => '添加好友';

  @override
  String get chatAddFriendHint => '输入用户名或 UID';

  @override
  String get chatSendFailedBanned => '你已被封禁，无法发送消息';

  @override
  String get chatSendFailedRateLimited => '发送消息过快，请稍后再试';

  @override
  String get chatSendFailedNotFriends => '你与该用户不是好友';

  @override
  String get chatSendFailedNotGroupMember => '你不是该群成员';

  @override
  String get chatSendFailedTooLong => '消息过长';

  @override
  String get groupNameLabel => '群组名称';

  @override
  String get groupIntroLabel => '群组简介';

  @override
  String get groupEnterHintLabel => '入群提示';

  @override
  String get groupEnterHintHelp => '成员入群后显示在聊天顶部';

  @override
  String get groupEnterHintUpdated => '入群提示已更新';

  @override
  String get groupManagement => '群组管理';

  @override
  String get groupOpen => '打开群聊';

  @override
  String get groupCreateNameEmpty => '群组名称不能为空';

  @override
  String groupCreateNameLength(int minLen, int maxLen) {
    return '群组名称长度需在 $minLen 到 $maxLen 个字符之间';
  }

  @override
  String get groupCreateFailedLimit => '创建失败，请检查群组数量限制';

  @override
  String get groupSettingsSection => '群组设置';

  @override
  String get groupMembersSection => '成员';

  @override
  String get groupJoinRequestsSection => '入群申请';

  @override
  String get groupAllowDirectJoin => '允许直接加入';

  @override
  String get groupAllowDirectJoinDesc => '非群成员可以自行申请加入';

  @override
  String get groupRequireReview => '需要审核';

  @override
  String get groupRequireReviewDesc => '加入或邀请需群主审核';

  @override
  String get groupFeaturesSection => '群功能';

  @override
  String get groupEssenceFeature => '精华消息';

  @override
  String get groupEssenceFeatureDesc => '允许管理员标记精华消息';

  @override
  String get groupTransferOwner => '转让群主';

  @override
  String get groupTransferOwnerConfirm => '转让后你将失去群主权限，确定继续吗？';

  @override
  String get groupTransferOwnerConfirmAction => '确认转让';

  @override
  String get groupSelectNewOwner => '选择新群主';

  @override
  String get groupLeave => '退出群组';

  @override
  String get groupLeaveConfirm => '确定要退出该群组吗？';

  @override
  String get groupLeaveOwnerHint => '群主需要先转让群主后才能退出';

  @override
  String get groupInviteMember => '邀请成员';

  @override
  String get groupInviteMemberHint => '输入好友的用户名或 UID';

  @override
  String get groupInvitePendingReview => '已发送邀请，等待审核';

  @override
  String get groupInviteJoined => '已邀请加入群组';

  @override
  String get groupInviteFailed => '邀请失败，请确认对方存在且已是你的好友';

  @override
  String get groupAvatarPermissionDenied => '只有群主或管理员可以修改群头像';

  @override
  String get groupAvatarUpdateSuccess => '群头像已更新';

  @override
  String get groupAvatarUploadFailedSize => '上传失败，请检查文件大小';

  @override
  String get groupJoinDirectRequest => '直接申请加入';

  @override
  String groupJoinInvitedBy(String name) {
    return '由 $name 邀请';
  }

  @override
  String get groupRemoveAdmin => '取消管理员';

  @override
  String get groupSetAdmin => '设为管理员';

  @override
  String get groupRemoveMemberAction => '移出群组';

  @override
  String get roleOwner => '群主';

  @override
  String get roleAdmin => '管理员';

  @override
  String get commonCancel => '取消';

  @override
  String get commonMe => '（我）';

  @override
  String get commonOk => '确定';

  @override
  String get commonFailedOperation => '操作失败，请重试';

  @override
  String get commonUserNotFound => '未找到该用户';

  @override
  String get commonFileReadError => '无法读取文件';

  @override
  String get chatLoading => '加载中...';

  @override
  String get chatInputNotConnected => '未连接到聊天服务器';

  @override
  String get chatInviteAcceptFailed => '接受好友请求失败';

  @override
  String get chatInviteRejectFailed => '拒绝好友请求失败';

  @override
  String get userProfileFriendRequestHint => '打个招呼...';

  @override
  String userProfileFriendRequestSent(String username) {
    return '已向 $username 发送好友请求';
  }

  @override
  String get userProfileFriendRequestFailed => '发送好友请求失败';

  @override
  String get settingsCategoryConnection => '连接';

  @override
  String get settingsCategoryStorage => '存储';

  @override
  String get settingsNotifyWithHaptic => '通知触感反馈';

  @override
  String get settingsNotifyWithHapticDescription => '收到应用内新通知时触发触感反馈';

  @override
  String get settingsLockscreenReplyTitle => '锁屏快捷回复';

  @override
  String get settingsLockscreenReplyDesc => '锁屏状态下可直接通过通知回复消息，消息内容将在锁屏可见';

  @override
  String get settingsMediaProxy => '媒体代理';

  @override
  String get settingsMediaProxyDescription =>
      '在本机运行 HTTP 代理以缓存和流式播放媒体文件，提供更流畅的播放体验';

  @override
  String get settingsMediaProxyUnsupported => '当前平台不支持此功能';

  @override
  String get settingsForceExplicitSyncTitle => '进入聊天时强制显式同步';

  @override
  String get settingsForceExplicitSyncDesc => '打开聊天时始终显示同步指示器并拉取更新（原行为）';

  @override
  String get settingsExplicitSyncCooldownTitle => '显式同步间隔';

  @override
  String get settingsExplicitSyncCooldownDesc =>
      '距上次进入聊天触发的同步超过该时间后，下次进入将再次显示同步指示器';

  @override
  String get settingsSeconds10 => '10 秒';

  @override
  String get settingsSeconds30 => '30 秒';

  @override
  String get settingsSeconds60 => '1 分钟';

  @override
  String get settingsSeconds120 => '2 分钟';

  @override
  String get settingsSeconds300 => '5 分钟';

  @override
  String get settingsStorageUsed => '已用空间';

  @override
  String get settingsStorageFree => '可用空间';

  @override
  String get settingsStorageUnavailable => '当前平台不支持查看磁盘信息';

  @override
  String get settingsChatStorage => '聊天消息存储';

  @override
  String get settingsChatStorageDescription => '查看和管理本地缓存的聊天消息';

  @override
  String get settingsCloudFiles => '云端文件';

  @override
  String get settingsCloudFilesDescription => '管理上传到服务器的文件';

  @override
  String get settingsAppCache => '应用缓存';

  @override
  String get settingsMediaCache => '媒体代理缓存';

  @override
  String get settingsFlutterCache => 'Flutter 缓存';

  @override
  String get settingsClearAllCache => '清除全部缓存';

  @override
  String get settingsClearCache => '清除';

  @override
  String get settingsCacheCleared => '缓存已清除';

  @override
  String get settingsEnableAnimationsTitle => '界面动画';

  @override
  String get settingsEnableAnimationsDesc => '启用页面和界面动画';

  @override
  String get settingsLayoutModeTitle => '布局模式';

  @override
  String get settingsLayoutModeDesc => '选择宽屏或窄屏布局方式';

  @override
  String get settingsLayoutModeAuto => '自动';

  @override
  String get settingsLayoutModeForceWide => '强制宽屏';

  @override
  String get settingsLayoutModeForceNarrow => '强制窄屏';

  @override
  String get settingsWideThresholdTitle => '宽屏切换阈值';

  @override
  String get settingsWideThresholdDesc => '窗口宽度达到该值时切换为宽屏布局（仅自动模式生效）';

  @override
  String settingsWideThresholdValue(Object px) {
    return '$px px';
  }

  @override
  String get settingsWeakNetworkTitle => '弱网模式';

  @override
  String get settingsWeakNetworkDesc => '网络不稳定时使用定时同步';

  @override
  String get settingsDataSavingTitle => '省流量模式';

  @override
  String get settingsDataSavingDesc => '点击后才加载媒体内容';

  @override
  String get settingsIpOverrideTitle => 'IP 覆盖模式';

  @override
  String get settingsIpOverrideDesc => '连接指定 IP，同时保留原域名用于 TLS';

  @override
  String get settingsIpOverrideOff => '关闭';

  @override
  String get settingsIpOverrideMixed => '指定域名';

  @override
  String get settingsIpOverrideComplete => '全部连接';

  @override
  String get settingsIpOverrideDomainsTitle => '覆盖域名';

  @override
  String get settingsIpOverrideDomainsDesc => '每行一个域名';

  @override
  String get settingsIpOverrideEntriesTitle => '覆盖 IP';

  @override
  String get settingsIpOverrideEntriesDesc => '每行一个 IP 或 IP:端口';

  @override
  String get settingsIpOverrideNoEntry => '尚未配置覆盖 IP';

  @override
  String get settingsConnectionStatusTitle => '连接状态';

  @override
  String get settingsConnectionStatusDesc => '查看连接状态并运行自检';

  @override
  String get settingsConnectivitySelfCheckTitle => '连通性自检';

  @override
  String get settingsConnectivitySelfCheckDesc => '测试服务器和已配置的 IP 节点';

  @override
  String get settingsConnectivityFailed => '连接失败';

  @override
  String get chatSearchAllMessages => '搜索所有聊天';

  @override
  String get chatExportTitle => '导出聊天记录';

  @override
  String get chatExportJson => '导出 JSON';

  @override
  String get chatExportCsv => '导出 CSV';

  @override
  String get chatExportSuccess => '聊天记录已导出';

  @override
  String get chatExportEmpty => '暂无消息可导出';

  @override
  String get settingsResetStatsRooms => '房间数';

  @override
  String get settingsResetStatsMessages => '消息数';

  @override
  String get settingsResetStatsSize => '数据库大小';

  @override
  String get settingsDatabaseExport => '导出本地数据库';

  @override
  String get settingsDatabaseImport => '导入本地数据库';

  @override
  String get settingsDatabaseExportSuccess => '本地数据库已导出';

  @override
  String settingsDatabaseImportSuccess(int count) {
    return '已导入 $count 条消息';
  }

  @override
  String get settingsLocalDatabase => '本地数据库';

  @override
  String get settingsOpenDatabaseFolder => '打开数据库目录';

  @override
  String get settingsLocalDatabaseSize => '本地消息数据库';

  @override
  String get settingsResetLocalMessages => '重置本地消息';

  @override
  String get settingsResetLocalMessagesConfirm =>
      '将删除此客户端的所有本地缓存消息，服务器上的消息不受影响。';

  @override
  String get settingsNoLocalMessages => '暂无本地存储的消息';

  @override
  String settingsLocalMessageCount(int count, String size) {
    return '$count 条消息 · $size';
  }

  @override
  String get maxCachedRooms => '消息缓存房间数';

  @override
  String get maxCachedRoomsDesc => '内存中保留的最大聊天房间数，超出后驱逐最久未使用的记录';

  @override
  String maxCachedRoomsCount(Object count) {
    return '$count 个';
  }

  @override
  String get settingsAutoLoadStickersTitle => '自动加载贴图和表情';

  @override
  String get settingsAutoLoadStickersDesc => '自动下载并缓存贴图。关闭后需手动点击贴图才会加载。';

  @override
  String get settingsClearStickerCache => '清除贴图缓存';

  @override
  String get settingsClearStickerCacheDescription => '删除本地缓存的贴图文件。';

  @override
  String get settingsClearLocalMessages => '清除';

  @override
  String get stickerMarketTitle => '贴图';

  @override
  String get stickerSortByDate => '按时间排序';

  @override
  String get stickerSortByUsage => '按热度排序';

  @override
  String get stickerMarketTab => '贴图市场';

  @override
  String get stickerOwnedTab => '已收藏';

  @override
  String get stickerSearchHint => '搜索贴图包';

  @override
  String get stickerRemovePack => '移除贴图包';

  @override
  String get stickerAddPack => '添加贴图包';

  @override
  String get stickerMyPacks => '我的贴图包';

  @override
  String get stickerCreatePack => '创建贴图包';

  @override
  String get stickerPackName => '名称';

  @override
  String get stickerPackPrefix => '前缀';

  @override
  String get stickerPackDescription => '简介';

  @override
  String get stickerPackCreate => '创建';

  @override
  String get stickerAddSticker => '添加贴图';

  @override
  String get stickerSlugLabel => '代码';

  @override
  String get stickerAdd => '添加';

  @override
  String get stickerDeletePack => '删除贴图包';

  @override
  String get forumSearchTitle => '搜索论坛';

  @override
  String get forumSearchPostsTitle => '搜索帖子';

  @override
  String get forumSearchHint => '搜索论坛或帖子';

  @override
  String get forumSearchCurrentForumHint => '搜索当前论坛帖子';

  @override
  String get forumSearchForumsHeader => '论坛';

  @override
  String get forumSearchPostsHeader => '帖子';

  @override
  String get stickerNoPacks => '暂无已收藏贴图包';

  @override
  String get commonUnknown => '未知';

  @override
  String get groupSearchTitle => '搜索群聊';

  @override
  String get groupSearchHint => '搜索群聊';

  @override
  String get groupSearchTooltip => '搜索群聊';

  @override
  String get groupSearchStartHint => '请开始搜索群聊';

  @override
  String get groupSearchNotFound => '未找到群聊';

  @override
  String get groupProfileTitle => '群聊详情';

  @override
  String get groupProfileIntroduction => '群聊介绍';

  @override
  String get groupProfileEnterHint => '入群提示';

  @override
  String get groupProfileGroupId => '群聊 ID';

  @override
  String get groupProfileGroupIdCopied => '群聊 ID 已复制';

  @override
  String groupProfileMembers(int count) {
    return '群成员数量：$count';
  }

  @override
  String get groupProfileRequireReview => '需要群管理员通过申请';

  @override
  String get groupProfileRequireReviewNo => '无需群管理员通过申请';

  @override
  String get groupProfileJoin => '加入群聊';

  @override
  String get groupProfileJoinSuccess => '已加入群聊';

  @override
  String get groupProfileJoinPending => '已提交入群申请，等待管理员审核';

  @override
  String get groupProfileJoinFailed => '加入群聊失败';

  @override
  String get groupProfileAlreadyMember => '已在群中';

  @override
  String get groupProfileNotFound => '群聊未找到';

  @override
  String get groupProfileCreator => '群主';

  @override
  String get forwardSearchTitle => '转发';

  @override
  String get forwardSearchHint => '请搜索用户和群聊';

  @override
  String get forwardSearchNotFound => '未搜索到符合项';

  @override
  String get forwardConfirmTitle => '确认转发这条消息？';

  @override
  String forwardConfirmContent(String name) {
    return '将这条消息转发给 $name？';
  }

  @override
  String get forwardWhereTitle => '转发后到达哪里？';

  @override
  String get forwardGoToTarget => '到达转发位置的聊天框';

  @override
  String get forwardStay => '停留在原位置的聊天框';

  @override
  String get forwardSending => '正在转发...';

  @override
  String get forwardSuccess => '转发成功';

  @override
  String get forwardFailed => '转发失败';

  @override
  String get updateAvailableTitle => '发现新版本';

  @override
  String updateAvailableMessage(String currentVersion, String remoteVersion) {
    return '当前版本：$currentVersion\n最新版本：$remoteVersion\n是否立即更新？';
  }

  @override
  String get updateNow => '立即更新';

  @override
  String get updateLater => '稍后';

  @override
  String get updateDownloading => '正在下载更新...';

  @override
  String get updateChangelogTitle => '更新日志';

  @override
  String get updateDownloadedTitle => '下载完成';

  @override
  String get updateExtractHint => '更新包已下载。请手动解压并替换应用后完成更新。';

  @override
  String get updateDownloadFailedTitle => '下载失败';

  @override
  String get updateDownloadFailedMessage => '更新下载失败，请检查网络后重试。';

  @override
  String get updateDownloadStartTitle => '开始下载更新';

  @override
  String updateApkSaveHint(String apkPath) {
    return 'APK 将保存到以下位置：\n$apkPath';
  }

  @override
  String get domainTrustLinkWarningTitle => '链接跳转确认';

  @override
  String get domainTrustLinkUntrustedMessage => '此链接来自未经受信任的域名，请确认链接安全后再打开。';

  @override
  String get domainTrustLinkHttpWarning =>
      '此链接使用不安全的 HTTP 协议（非 HTTPS），数据可能被窃听或篡改。';

  @override
  String get domainTrustOpenAnyway => '仍然打开';

  @override
  String get domainTrustCopyLink => '复制链接';

  @override
  String get domainTrustAddToTrustedDomains => '将该域加入信任域名';

  @override
  String get domainTrustImageBlockedTitle => '已阻止来自未经受信任域名的图片';

  @override
  String get domainTrustImageBlockedDesc => '为保护隐私，未加载来自未经受信任域名的图片。';

  @override
  String get domainTrustLoadImage => '加载图片';

  @override
  String get domainTrustInfoTitle => '域名保护说明';

  @override
  String get domainTrustInfoBody =>
      '第三方站点可能记录/泄露您的访问数据（如 IP 地址）并进行违规行为，它们不受 TouchFish 管理。\n\n即使您不主动访问链接，TouchFish Client 的自动加载仍然可能产生网络请求。\n\n为了保护您的数据安全，从 0.0.2 版本开始，TouchFish Client 不再默认加载外部图片并直接打开外部链接。\n\n如果您信任该站点，可在 设置-连接 中配置该站点为受信任的域，以允许 TouchFish Client 自动加载。\n\n如果您不需要该安全功能，可在 设置-连接 中关闭本安全防护功能。';

  @override
  String get settingsDomainTrustImageBlockTitle => '图片加载保护';

  @override
  String get settingsDomainTrustImageBlockDesc => '阻止加载来自未经受信任域名的图片';

  @override
  String get settingsDomainTrustLinkWarningTitle => '链接跳转保护';

  @override
  String get settingsDomainTrustLinkWarningDesc => '打开未经受信任域名的链接前进行警告';

  @override
  String get settingsTrustedDomainsTitle => '信任域名';

  @override
  String get settingsTrustedDomainsDesc =>
      '每行一个域名，如 example.com 或 *.example.com。当前服务器域名始终受信任。';

  @override
  String get settingsTrustedDomainsReset => '恢复默认';

  @override
  String get settingsRsaKeysTitle => 'RSA 密钥管理';

  @override
  String get settingsRsaKeysDesc => '管理已保存的服务器 RSA 公钥，查看当前服务器的密钥 SHA';

  @override
  String get settingsLegacyAuthTitle => '兼容性：使用 UID 和 PASSWORD 作为登录选项（不推荐）';

  @override
  String get settingsLegacyAuthDesc =>
      '开启后使用旧版认证方式登录与请求，仅在与旧版服务器或不支持 JWT 的服务器连接时使用';

  @override
  String get rsaKeyManagement => 'RSA 密钥管理';

  @override
  String get rsaKeyManagementDescription =>
      '管理已保存的服务器 RSA 公钥与密钥 SHA。首次连接时建议保存服务器密钥，之后每次连接都会校验密钥是否一致，防止中间人攻击。';

  @override
  String get rsaCurrentServerSection => '当前服务器';

  @override
  String get rsaSavedKeysSection => '已保存的密钥';

  @override
  String get rsaUnknownServer => '未知服务器';

  @override
  String get rsaSavedKeySha => '已保存密钥 SHA';

  @override
  String get rsaViewCurrentSha => '查看当前密钥 SHA';

  @override
  String get rsaSaveCurrentKey => '保存当前密钥';

  @override
  String rsaSaveCurrentKeySuccess(String sha) {
    return '已保存当前服务器密钥。SHA: $sha';
  }

  @override
  String get rsaFetchFailed => '获取服务器 RSA 密钥失败，请检查网络连接';

  @override
  String get rsaNoSavedKeys => '尚未保存任何 RSA 密钥';

  @override
  String get rsaViewPublicKey => '查看公钥';

  @override
  String get rsaCopySha => '复制 SHA';

  @override
  String get rsaCopyPublicKey => '复制公钥';

  @override
  String get rsaDeleteKey => '删除密钥';

  @override
  String rsaDeleteKeyConfirm(String authority) {
    return '确定要删除服务器 $authority 的已保存 RSA 密钥吗？删除后将不再校验该服务器的密钥。';
  }

  @override
  String get rsaCopied => '已复制';

  @override
  String get rsaPublicKey => '公钥';

  @override
  String get rsaKeySha => '密钥 SHA';

  @override
  String get rsaSaveKey => '保存密钥';

  @override
  String get rsaDontSave => '不保存';

  @override
  String get rsaDisconnectServer => '断开服务器连接';

  @override
  String get rsaFirstConnectTitle => '这似乎是你初次连接到该服务器，是否保存 RSA 加密密钥？';

  @override
  String get rsaFirstConnectMessage => '保存后，客户端将在每次连接时校验服务器密钥是否一致，防止中间人攻击。';

  @override
  String get rsaKeyChangedTitle => '警告：服务器 RSA 加密密钥变更';

  @override
  String get rsaNewKeySha => '新的 RSA 密钥的 SHA';

  @override
  String get rsaOldKeySha => '旧的 RSA 密钥的 SHA';

  @override
  String get rsaKeyChangedMessage =>
      '请注意：MitM 攻击者可能通过篡改 RSA 密钥获取您与服务器间的通信，请向服务器管理员确认密钥变更！';

  @override
  String get rsaReplaceKey => '使用新密钥替换旧的';

  @override
  String get rsaInvalidPem => '无效的 RSA 公钥（PEM 格式）';

  @override
  String get rsaPemFieldLabel => 'RSA 公钥 (PEM)';

  @override
  String get rsaPemFieldHint => '粘贴服务器 RSA 公钥（可选）。绑定后客户端将使用该密钥加密通信，不再从服务器拉取。';
}
