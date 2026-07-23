import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import '../models/app_notification.dart';
import '../models/settings_service.dart';
import '../utils/talker.dart';

const appNotificationBaseDuration = Duration(seconds: 5);

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

class AppNotificationService extends ChangeNotifier
    with WidgetsBindingObserver {
  static final AppNotificationService instance = AppNotificationService._();
  AppNotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final Map<String, Timer> _timers = {};
  final List<AppNotificationItem> _items = [];
  GoRouter? _router;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  bool _initialized = false;
  bool _localNotificationsReady = false;
  bool _permissionRequested = false;

  List<AppNotificationItem> get items => List.unmodifiable(_items);

  Future<void> initialize(GoRouter router) async {
    _router = router;
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    SettingsService.instance.addListener(_onSettingsChanged);
    if (kIsWeb) return;

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_launcher'),
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
      );
      _localNotificationsReady = true;
      await _requestPermissionIfEnabled();
      final launchDetails = await _localNotifications
          .getNotificationAppLaunchDetails();
      final payload = launchDetails?.notificationResponse?.payload;
      if (launchDetails?.didNotificationLaunchApp == true && payload != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => openRoute(payload));
      }
    } catch (error, stackTrace) {
      talker.error(
        'Local notification initialization failed',
        error,
        stackTrace,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
  }

  Future<void> present(AppNotification notification) async {
    final settings = SettingsService.instance;
    if (!_isNotificationTypeEnabled(notification)) return;
    if (await _shouldShowInApp()) {
      if (!settings.getValue<bool>('inAppNotifications', true)) return;
      if (settings.getValue<bool>('notificationSound', true)) {
        unawaited(SystemSound.play(SystemSoundType.alert));
      }
      add(notification);
      return;
    }

    if (!settings.getValue<bool>('systemNotifications', true)) return;
    await _showSystemNotification(notification);
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
    notifyListeners();
  }

  void open(AppNotification notification) {
    dismiss(notification.id);
    openRoute(notification.route);
  }

  void openRoute(String route) {
    if (!route.startsWith('/')) return;
    _router?.go(route);
  }

  Future<bool> _showSystemNotification(AppNotification notification) async {
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
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: playSound,
        threadIdentifier: notification.topic,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: playSound,
        threadIdentifier: notification.topic,
      ),
      linux: LinuxNotificationDetails(suppressSound: !playSound),
      windows: WindowsNotificationDetails(
        subtitle: notification.subtitle,
        audio: playSound ? null : WindowsNotificationAudio.silent(),
      ),
    );
    try {
      await _localNotifications.show(
        _stableId(notification.id),
        notification.title,
        notification.body,
        details,
        payload: notification.route,
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
    final payload = response.payload;
    if (payload != null) openRoute(payload);
  }

  void _onSettingsChanged() {
    if (!SettingsService.instance.getValue<bool>('inAppNotifications', true)) {
      clear();
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
