import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/models/app_notification.dart';
import 'package:touchfish_client/models/settings_service.dart';
import 'package:touchfish_client/services/app_notification_service.dart';

/// 回归测试：实体机（release 构建）上 flutter_local_notifications 初始化
/// 因 smallIcon 资源被资源收缩器移除而抛出 invalid_icon 异常后，
/// AppNotificationService 必须允许在后续时机重试初始化，
/// 否则系统通知功能会永久失效（_localNotificationsReady 永远为 false）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const localNotificationsChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );

  const testNotification = AppNotification(
    id: 'retry-test',
    title: 'Retry',
    body: 'Body',
    route: '/account',
    topic: 'test',
  );

  setUpAll(() async {
    // 测试环境默认 targetPlatform 为 android，需注册 Android 插件实现，
    // 否则 FlutterLocalNotificationsPlatform.instance 的 late 字段未初始化，
    // 会在 resolvePlatformSpecificImplementation 时抛出 LateInitializationError。
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });

  testWidgets(
    'notification init retries after invalid_icon failure via settings change',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var shouldFail = true;

      messenger.setMockMethodCallHandler(
        localNotificationsChannel,
        (call) async {
          switch (call.method) {
            case 'initialize':
              if (shouldFail) {
                throw PlatformException(
                  code: 'invalid_icon',
                  message:
                      'The resource ic_notification could not be found. '
                      'Please make sure it has been added as a drawable '
                      'resource to your Android head project.',
                );
              }
              // AndroidFlutterLocalNotificationsPlugin.initialize 内部将
              // invokeMethod 的结果推断为 bool，因此成功时必须返回 true，
              // 返回 null 会抛 "Null is not a subtype of FutureOr<bool>"。
              return true;
            case 'requestNotificationsPermission':
              return true;
            case 'getNotificationAppLaunchDetails':
              return null;
            default:
              return null;
          }
        },
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(localNotificationsChannel, null),
      );

      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (context, state) => const SizedBox()),
        ],
      );

      // 第一次初始化失败（模拟 release 构建中 ic_notification 被移除）。
      await AppNotificationService.instance.initialize(router);
      expect(
        AppNotificationService.instance.canShowSystem(testNotification),
        isFalse,
        reason: '初始化失败后系统通知不应可用',
      );

      // 修复资源问题（模拟 release 构建保留资源/重装修复后的 APK）。
      shouldFail = false;
      await SettingsService.instance.setValue('systemNotifications', true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        AppNotificationService.instance.canShowSystem(testNotification),
        isTrue,
        reason: '设置变更应触发重试初始化并恢复系统通知能力',
      );
    },
  );
}