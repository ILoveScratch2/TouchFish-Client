import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_notification.dart';
import 'api/tf_api_client.dart';

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

    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('auth_uid');
    final password = prefs.getString('auth_password');
    if (uid == null || password == null || password.isEmpty) return false;

    final result = await TfApiClient.instance.sendMessage(
      uid,
      password,
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
