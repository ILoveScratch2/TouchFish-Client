import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';
import 'package:http/http.dart' as http;

import '../models/app_notification.dart';
import '../models/notification_level.dart';
import '../models/settings_service.dart';
import '../utils/notification_avatar_attachment.dart';
import '../utils/talker.dart';
import 'inline_reply_service.dart';

const appNotificationBaseDuration = Duration(seconds: 5);

const androidInlineReplyActions = [
  AndroidNotificationAction(
    'reply',
    '回复',
    inputs: [AndroidNotificationActionInput(label: '输入回复')],
    allowGeneratedReplies: true,
    cancelNotification: false,
    semanticAction: SemanticAction.reply,
  ),
];

@pragma('vm:entry-point')
void onNotificationActionBackground(NotificationResponse response) {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(InlineReplyService.handle(response));
}

class AppNotificationItem {
  final AppNotification notification;
  final int index;
  final Duration duration;
  final bool dismissed;

  const AppNotificationItem({
    required this.notification,
    required this.index,
    required this.duration,
    this.dismissed = false,
  });

  AppNotificationItem copyWith({bool? dismissed}) => AppNotificationItem(
    notification: notification,
    index: index,
    duration: duration,
    dismissed: dismissed ?? this.dismissed,
  );
}

/// 通知分级状态。
///
/// 用于在应用内维护每个联系人的最新一条待展示消息，
/// 以及联系人总数与消息总数（一级通知/二级通知需要）。
class NotificationLevelState {
  /// senderKey -> 最近一条消息通知
  final Map<String, AppNotification> latestBySender = {};

  /// senderKey -> 消息条数（重复消息不计）
  final Map<String, int> countBySender = {};

  /// 有未读消息的联系人数
  int get senderCount => latestBySender.length;

  /// 消息总条数
  int get messageCount =>
      countBySender.values.fold(0, (sum, count) => sum + count);

  void add(AppNotification notification) {
    final senderKey = notification.senderKey;
    if (senderKey == null || senderKey.isEmpty) return;
    if (countBySender.containsKey(senderKey)) {
      countBySender[senderKey] = countBySender[senderKey]! + 1;
    } else {
      countBySender[senderKey] = 1;
    }
    latestBySender[senderKey] = notification;
  }

  void clear() {
    latestBySender.clear();
    countBySender.clear();
  }
}

class AppNotificationService extends ChangeNotifier
    with WidgetsBindingObserver {
  static final AppNotificationService instance = AppNotificationService._();
  AppNotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final Map<String, Timer> _timers = {};
  final List<AppNotificationItem> _items = [];
  final NotificationLevelState _levelState = NotificationLevelState();
  GoRouter? _router;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  bool _initialized = false;
  bool _observersRegistered = false;
  bool _localNotificationsReady = false;
  bool _permissionRequested = false;
  bool _suppressInAppBanners = false;
  Timer? _bannerSuppressionTimer;

  List<AppNotificationItem> get items => List.unmodifiable(_items);

  @visibleForTesting
  void attachRouterForTesting(GoRouter? router) {
    _router = router;
  }

  /// 当前生效的通知分级。
  ///
  /// 分级只影响横幅展示逻辑，通知中心数据不变。
  /// 仅 Android 支持分级；其他平台始终为 [NotificationLevel.full]（原行为）。
  NotificationLevel get notificationLevel {
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        Platform.isAndroid) {
      return NotificationLevel.fromSetting(
        SettingsService.instance.getValue<String>('notificationLevel', '2'),
      );
    }
    return NotificationLevel.full;
  }

  /// 当前是否仅在收集聊天通知（一级/二级），
  /// 非聊天通知（公告/论坛/系统事件）应始终以完整方式展示。
  bool _isChatNotification(AppNotification notification) =>
      notification.topic == 'message.private' ||
      notification.topic == 'message.group';

  /// 抑制应用内横幅一段时间（例如应用刚启动/登录恢复历史通知时），
  /// 期间新到达的事件只累计到各栏目的角标，不弹横幅轰炸用户；
  /// 窗口结束后恢复正常横幅提醒。
  void suppressInAppBanners(Duration duration) {
    _suppressInAppBanners = true;
    _bannerSuppressionTimer?.cancel();
    _bannerSuppressionTimer = Timer(duration, () {
      _suppressInAppBanners = false;
    });
  }

  Future<void> initialize(GoRouter router) async {
    _router = router;
    if (_initialized) return;
    _initialized = true;
    // 观察者只注册一次，避免初始化失败重试时重复注册导致回调重复触发。
    if (!_observersRegistered) {
      _observersRegistered = true;
      WidgetsBinding.instance.addObserver(this);
      SettingsService.instance.addListener(_onSettingsChanged);
    }
    if (kIsWeb) return;

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: LinuxInitializationSettings(
        defaultActionName: 'Open notification',
      ),
      windows: WindowsInitializationSettings(
        appName: 'TouchFish',
        appUserModelId: 'TouchFish.Client',
        guid: '9784cc11-fda8-4a30-9e8f-d3da56d097cc',
      ),
    );
    try {
      await _localNotifications.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
        onDidReceiveBackgroundNotificationResponse:
            onNotificationActionBackground,
      );
      _localNotificationsReady = true;
      await _requestPermissionIfEnabled();
      final launchDetails = await _localNotifications
          .getNotificationAppLaunchDetails();
      final payload = launchDetails?.notificationResponse?.payload;
      if (launchDetails?.didNotificationLaunchApp == true && payload != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => openRoute(
            AppNotification.parsePayload(payload).route,
            replace: true,
          ),
        );
      }
    } catch (error, stackTrace) {
      talker.error(
        'Local notification initialization failed',
        error,
        stackTrace,
      );
      // 初始化失败时重置标志，允许后续通过设置变更等时机重试。
      // 例如 release 构建中 smallIcon 资源被资源收缩器移除时，
      // 初始化会抛出 invalid_icon 异常，若不重置则通知功能永久失效。
      _initialized = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
  }

  Future<void> present(AppNotification notification) async {
    final settings = SettingsService.instance;
    if (!_isNotificationTypeEnabled(notification)) return;

    final level = notificationLevel;
    final isChat = _isChatNotification(notification);
    final isAggregating = isChat &&
        level != NotificationLevel.full;

    // 非三级/非聊天通知：始终以完整方式走原逻辑
    if (!isAggregating) {
      await _presentOne(notification);
      return;
    }

    // 三级以外的前台/后台：聊天通知按分级聚合展示
    if (isAggregating) {
      _levelState.add(notification);
      if (await _shouldShowInApp()) {
        if (_suppressInAppBanners) return;
        if (!settings.getValue<bool>('inAppNotifications', true)) return;
        _playNotificationFeedback();
        _rebuildAggregatedBanners();
      } else {
        if (!settings.getValue<bool>('systemNotifications', true)) return;
        await _showAggregatedSystemNotification();
      }
    }
  }

  Future<void> _presentOne(AppNotification notification) async {
    final settings = SettingsService.instance;
    if (await _shouldShowInApp()) {
      if (_suppressInAppBanners) return;
      if (!settings.getValue<bool>('inAppNotifications', true)) return;
      _playNotificationFeedback();
      add(notification);
      return;
    }

    if (!settings.getValue<bool>('systemNotifications', true)) return;
    await _showSystemNotification(notification);
  }

  void _playNotificationFeedback() {
    final settings = SettingsService.instance;
    if (settings.getValue<bool>('notificationSound', true)) {
      unawaited(SystemSound.play(SystemSoundType.alert));
    }
    if (!kIsWeb && settings.getValue<bool>('notifyWithHaptic', true)) {
      unawaited(HapticFeedback.lightImpact());
    }
  }

  /// 根据当前通知分级重建聚合后的应用内横幅列表。
  ///
  /// 一级：只保留一条汇总横幅（始终最多一条）。
  /// 二级：每个联系人保留一条，显示该联系人的最后一条消息。
  void _rebuildAggregatedBanners() {
    final level = notificationLevel;
    final newItems = <AppNotificationItem>[];
    final newTimers = <String, Timer>{};

    // 一级：只显示一条汇总横幅。
    if (level == NotificationLevel.minimal) {
      if (_levelState.senderCount > 0) {
        final summary = _buildSummaryNotification();
        newItems.add(
          AppNotificationItem(
            notification: summary,
            index: 0,
            duration: appNotificationBaseDuration,
          ),
        );
        newTimers[summary.id] = Timer(
          appNotificationBaseDuration,
          () => dismiss(summary.id),
        );
      }
    } else {
      // 二级：每个联系人一条横幅。
      final entries = _levelState.latestBySender.entries.toList();
      for (var i = 0; i < entries.length; i++) {
        final notification = entries[i].value;
        final item = AppNotificationItem(
          notification: notification,
          index: i,
          duration:
              appNotificationBaseDuration + Duration(seconds: i),
        );
        newItems.add(item);
        newTimers[notification.id] = Timer(
          item.duration,
          () => dismiss(notification.id),
        );
      }
    }

    // 清除旧 items 的 timer
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _items
      ..clear()
      ..addAll(newItems);
    _timers
      ..clear()
      ..addAll(newTimers);
    notifyListeners();
  }

  AppNotification _buildSummaryNotification() {
    final contacts = _levelState.senderCount;
    final messages = _levelState.messageCount;
    return AppNotification(
      id: 'level_summary',
      title: 'TouchFish Messages',
      body: '$contacts contacts · $messages messages',
      route: '/chat',
      topic: 'message.summary',
      subtitle: 'New chat messages',
    );
  }

  /// 聚合模式下的系统通知：将聚合状态直接显示为一条系统通知。
  Future<void> _showAggregatedSystemNotification() async {
    if (_levelState.senderCount == 0) return;
    final level = notificationLevel;
    final summary = _buildSummaryNotification();
    final lastEntry = _levelState.latestBySender.entries.last;
    final notification = lastEntry.value;

    final body = level == NotificationLevel.minimal
        ? '${summary.body}\n${notification.body}'
        : notification.body;

    final androidDetails = AndroidNotificationDetails(
      'touchfish_notifications',
      'TouchFish notifications',
      channelDescription: 'Messages and activity from TouchFish',
      importance: Importance.max,
      priority: Priority.high,
      playSound: SettingsService.instance.getValue<bool>(
        'notificationSound',
        true,
      ),
      actions:
          level == NotificationLevel.perSender && notification.canReply
              ? androidInlineReplyActions
              : null,
    );

    final details = NotificationDetails(android: androidDetails);

    try {
      await _localNotifications.show(
        _stableId('level_aggregate'),
        notification.title,
        body,
        details,
        payload: notification.payload,
      );
    } catch (error, stackTrace) {
      talker.error('Failed to show aggregated system notification', error, stackTrace);
    }
  }

  Future<bool> _shouldShowInApp() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux)) {
      try {
        if (await windowManager.isFocused()) return true;
      } catch (error) {
        talker.warning('Failed to read desktop window focus state: $error');
      }
    }
    return _lifecycleState == AppLifecycleState.resumed;
  }

  bool canShowInApp(AppNotification notification) {
    return SettingsService.instance.getValue<bool>(
          'inAppNotifications',
          true,
        ) &&
        _isNotificationTypeEnabled(notification);
  }

  bool canShowSystem(AppNotification notification) {
    return !kIsWeb &&
        _localNotificationsReady &&
        SettingsService.instance.getValue<bool>('systemNotifications', true) &&
        _isNotificationTypeEnabled(notification);
  }

  void showInAppTest(AppNotification notification) {
    if (!canShowInApp(notification)) return;
    if (SettingsService.instance.getValue<bool>('notificationSound', true)) {
      unawaited(SystemSound.play(SystemSoundType.alert));
    }
    add(notification);
  }

  Future<bool> showSystemTest(AppNotification notification) async {
    if (!canShowSystem(notification)) return false;
    return _showSystemNotification(notification);
  }

  bool _isNotificationTypeEnabled(AppNotification notification) {
    final settings = SettingsService.instance;
    if (notification.topic == 'message.private') {
      return settings.getValue<bool>('privateChat', true);
    }
    if (notification.topic == 'message.group') {
      return settings.getValue<bool>('groupChat', true);
    }
    if (notification.topic == 'message.summary') return true;
    return true;
  }

  void add(AppNotification notification, {Duration? duration}) {
    if (_items.any(
      (item) => item.notification.id == notification.id && !item.dismissed,
    )) {
      return;
    }
    final item = AppNotificationItem(
      notification: notification,
      index: _items.length,
      duration:
          duration ??
          appNotificationBaseDuration + Duration(seconds: _items.length),
    );
    _items.add(item);
    _timers[item.notification.id] = Timer(
      item.duration,
      () => dismiss(item.notification.id),
    );
    notifyListeners();
  }

  void dismiss(String id) {
    _timers.remove(id)?.cancel();
    final index = _items.indexWhere((item) => item.notification.id == id);
    if (index < 0 || _items[index].dismissed) return;
    _items[index] = _items[index].copyWith(dismissed: true);
    notifyListeners();
  }

  void remove(String id) {
    _items.removeWhere((item) => item.notification.id == id);
    notifyListeners();
  }

  void clear() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _items.clear();
    _levelState.clear();
    notifyListeners();
  }

  void open(AppNotification notification) {
    dismiss(notification.id);
    openRoute(notification.route, replace: true);
  }

  void openRoute(String route, {bool replace = false}) {
    if (!route.startsWith('/')) return;
    final router = _router;
    if (router == null) return;
    if (router.routerDelegate.currentConfiguration.uri.toString() == route) {
      return;
    }
    if (replace) {
      router.go(route);
    } else {
      router.push(route);
    }
  }

  Future<bool> _showSystemNotification(AppNotification notification) async {
    AndroidBitmap<Object>? senderAvatar;
    List<DarwinNotificationAttachment>? darwinAttachments;
    List<WindowsImage> windowsImages = const [];
    LinuxNotificationIcon? linuxIcon;
    if (notification.avatarUrl != null && notification.avatarUrl!.startsWith('http')) {
      try {
        final response = await http.get(Uri.parse(notification.avatarUrl!)).timeout(const Duration(seconds: 3));
        if (response.statusCode >= 200 && response.statusCode < 300 && response.bodyBytes.isNotEmpty) {
          senderAvatar = ByteArrayAndroidBitmap(Uint8List.fromList(response.bodyBytes));
        }
      } catch (_) {
        // 发送头像下载失败继续显示通知
      }
    }
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux)) {
      final avatarPath = await cacheNotificationAvatarAttachment(
        notification.avatarUrl,
      );
      if (avatarPath != null) {
        if (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS) {
          darwinAttachments = [DarwinNotificationAttachment(avatarPath)];
        } else if (defaultTargetPlatform == TargetPlatform.windows) {
          windowsImages = [
            WindowsImage(
              Uri.file(avatarPath, windows: true),
              altText: notification.title,
              placement: WindowsImagePlacement.appLogoOverride,
              crop: WindowsImageCrop.circle,
            ),
          ];
        } else if (defaultTargetPlatform == TargetPlatform.linux) {
          linuxIcon = FilePathLinuxIcon(avatarPath);
        }
      }
    }
    const androidDetails = AndroidNotificationDetails(
      'touchfish_notifications',
      'TouchFish notifications',
      channelDescription: 'Messages and activity from TouchFish',
      importance: Importance.max,
      priority: Priority.high,
    );
    final playSound = SettingsService.instance.getValue<bool>(
      'notificationSound',
      true,
    );
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        androidDetails.channelId,
        androidDetails.channelName,
        channelDescription: androidDetails.channelDescription,
        importance: androidDetails.importance,
        priority: androidDetails.priority,
        playSound: playSound,
        largeIcon: senderAvatar,
        actions: notification.canReply
            ? androidInlineReplyActions
            : null,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: playSound,
        threadIdentifier: notification.topic,
        attachments: darwinAttachments,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: playSound,
        threadIdentifier: notification.topic,
        attachments: darwinAttachments,
      ),
      linux: LinuxNotificationDetails(
        suppressSound: !playSound,
        icon: linuxIcon,
      ),
      windows: WindowsNotificationDetails(
        subtitle: notification.subtitle,
        audio: playSound ? null : WindowsNotificationAudio.silent(),
        images: windowsImages,
      ),
    );
    try {
      await _localNotifications.show(
        _stableId(notification.id),
        notification.title,
        notification.body,
        details,
        payload: notification.payload,
      );
      return true;
    } catch (error, stackTrace) {
      talker.error('Failed to show system notification', error, stackTrace);
      return false;
    }
  }

  int _stableId(String value) {
    var hash = 0;
    for (final unit in value.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }

  void _onNotificationResponse(NotificationResponse response) {
    if (response.actionId == 'reply') {
      unawaited(InlineReplyService.handle(response));
      return;
    }
    final payload = response.payload;
    if (payload != null) openRoute(AppNotification.parsePayload(payload).route);
  }

  void _onSettingsChanged() {
    if (!SettingsService.instance.getValue<bool>('inAppNotifications', true)) {
      clear();
    }
    // 分级设置变更时清空聚合并重建横幅
    _levelState.clear();
    _rebuildAggregatedBanners();
    if (!_localNotificationsReady &&
        SettingsService.instance.getValue<bool>('systemNotifications', true)) {
      // 通知系统尚未就绪（例如初始化曾失败），利用设置变更时机重试初始化。
      final router = _router;
      if (router != null) {
        unawaited(initialize(router));
      }
    }
    unawaited(_requestPermissionIfEnabled());
  }

  Future<void> _requestPermissionIfEnabled() async {
    if (_permissionRequested ||
        !SettingsService.instance.getValue<bool>('systemNotifications', true)) {
      return;
    }
    _permissionRequested = true;
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }
}
