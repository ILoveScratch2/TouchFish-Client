import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/app_notification.dart';
import '../utils/talker.dart';
import 'api/tf_api_client.dart';
import 'auth_state.dart';

class InlineReplyService {
  InlineReplyService._();

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _notificationsInitialized = false;

  static Future<void> _ensureNotificationsInitialized() async {
    if (_notificationsInitialized) return;
    await _notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
    );
    _notificationsInitialized = true;
  }

  /// 解析快捷回复所需的凭据；null 表示这个 isolate 里没有可用凭据。
  ///
  /// 通知栏动作可能跑在后台 isolate（见 `onNotificationActionBackground`），
  /// 那里不会执行 `main()`，[AuthState] 必须自己初始化一次；
  /// 而且 `init()` 只填 `rememberedUid` / `rememberedPassword`，
  /// `uid` / `password` 仍是空的（后者是已登录会话才有的运行时值）。
  @visibleForTesting
  static Future<({int uid, String password})?> resolveCredentials() async {
    final auth = AuthState.instance;
    if (auth.uid == null && auth.rememberedUid == null) {
      try {
        await auth.init();
      } catch (e) {
        talker.warning('InlineReplyService: AuthState.init failed: $e');
        return null;
      }
    }
    final uid = auth.uid ?? auth.rememberedUid;
    if (uid == null) return null;
    final password = auth.password ?? auth.rememberedPassword ?? '';
    // JWT 模式拿不到密码是正常的：请求会走 token，不该被拦
    if (!auth.isJwtMode && password.isEmpty) return null;
    return (uid: uid, password: password);
  }

  static Future<bool> handle(NotificationResponse response) async {
    final input = response.input?.trim();
    final payload = response.payload;
    if (response.actionId != 'reply' ||
        input == null ||
        input.isEmpty ||
        payload == null) {
      return false;
    }

    final target = AppNotification.parsePayload(payload);
    final roomId = target.roomId;
    if (roomId == null ||
        !(roomId.startsWith('U') || roomId.startsWith('G'))) {
      return false;
    }

    final credentials = await resolveCredentials();
    if (credentials == null) return false;

    final result = await TfApiClient.instance.sendMessage(
      credentials.uid,
      credentials.password,
      recipient: roomId,
      content: input,
      clientMid: 'c${DateTime.now().microsecondsSinceEpoch}',
    );
    if (result == null) return false;

    final notificationId = response.id;
    if (notificationId != null) {
      await _ensureNotificationsInitialized();
      await _notifications.cancel(notificationId);
    }
    return true;
  }
}
